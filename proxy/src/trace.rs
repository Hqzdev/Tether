use std::sync::{Arc, Mutex};

use axum::{
    Json, Router,
    extract::{Query, State},
    http::{HeaderMap, StatusCode},
    routing::get,
};
use chrono::{DateTime, Local, TimeZone};
use rusqlite::{Connection, OptionalExtension, params};
use serde::Deserialize;
use serde_json::Value;
use uuid::Uuid;

use crate::AppState;

pub(crate) const MAX_CAPTURE_BYTES: usize = 256 * 1024;

#[derive(Clone)]
pub(crate) struct TraceCapture {
    id: String,
    created_at: i64,
    provider: String,
    method: String,
    path: String,
    pub(crate) model: String,
    pub(crate) preview: String,
    prompt_system: String,
    prompt_user: String,
    request_id: String,
    temperature: Option<f64>,
}

// Wire DTOs live in loom-domain (the shared model crate). Only the request
// query type below is HTTP-specific and stays here.
use loom_domain::{
    AgentErrorDto, AgentNodeDto, AgentPromptDto, AgentResponseDto, SessionListDto, TraceSessionDto,
    TraceSnapshot,
};

#[derive(Deserialize)]
struct TraceQuery {
    session_id: Option<String>,
}

struct TraceRow {
    id: String,
    created_at: i64,
    provider: String,
    method: String,
    path: String,
    model: String,
    status_code: i64,
    cache_status: String,
    latency_ms: i64,
    request_id: String,
    prompt_system: String,
    prompt_user: String,
    response_text: String,
    response_language: String,
    error_code: Option<String>,
    error_message: Option<String>,
    error_detail: Option<String>,
    tokens_in: i64,
    tokens_out: i64,
    cost: String,
    temperature: Option<f64>,
}

struct ResponseSummary {
    request_id: Option<String>,
    text: String,
    language: String,
    tokens_in: i64,
    tokens_out: i64,
}

impl TraceCapture {
    pub(crate) fn from_request(method: &str, path: &str, provider: &str, body: &[u8]) -> Self {
        let parsed = serde_json::from_slice::<Value>(body).ok();
        let model = parsed
            .as_ref()
            .and_then(|value| value.get("model"))
            .and_then(Value::as_str)
            .unwrap_or("-")
            .to_string();
        let preview = parsed
            .as_ref()
            .and_then(extract_last_text)
            .unwrap_or_else(|| {
                if body.is_empty() {
                    "-".to_string()
                } else {
                    format!("<{} bytes, non-JSON>", body.len())
                }
            });
        let (prompt_system, prompt_user) = parsed
            .as_ref()
            .map(extract_prompt)
            .unwrap_or_else(|| ("".to_string(), truncate_one_line(&preview, 4_000)));
        let request_id = parsed
            .as_ref()
            .and_then(|value| value.get("id"))
            .and_then(Value::as_str)
            .unwrap_or("-")
            .to_string();
        let temperature = parsed
            .as_ref()
            .and_then(|value| value.get("temperature"))
            .and_then(Value::as_f64);

        Self {
            id: Uuid::new_v4().to_string(),
            created_at: now_millis(),
            provider: provider.to_string(),
            method: method.to_string(),
            path: path.to_string(),
            model,
            preview: truncate_one_line(&preview, 300),
            prompt_system,
            prompt_user,
            request_id,
            temperature,
        }
    }
}

pub(crate) fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/sessions",
            get(list_sessions).post(create_session_endpoint),
        )
        .route(
            "/api/traces/current",
            get(current_trace).delete(clear_trace),
        )
        .route("/api/cache", axum::routing::delete(clear_cache))
}

pub(crate) fn init_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(include_str!(
        "../sqlite_migrations/20260601000000_sessions.sql"
    ))?;
    if !table_has_column(conn, "trace_calls", "session_id")? {
        conn.execute("ALTER TABLE trace_calls ADD COLUMN session_id TEXT", [])?;
    }
    ensure_current_session(conn)?;
    backfill_missing_session_ids(conn)
}

pub(crate) fn response_request_id(headers: &HeaderMap) -> Option<String> {
    [
        "x-request-id",
        "request-id",
        "openai-request-id",
        "anthropic-request-id",
    ]
    .iter()
    .find_map(|name| {
        headers
            .get(*name)
            .and_then(|value| value.to_str().ok())
            .map(ToOwned::to_owned)
    })
}

pub(crate) fn record_response(
    db: &Arc<Mutex<Connection>>,
    capture: &TraceCapture,
    status_code: u16,
    content_type: &str,
    header_request_id: Option<&str>,
    body: &[u8],
    cache_status: &str,
    latency_ms: i64,
) {
    let summary = summarize_response(content_type, body);
    let is_error = !(200..=299).contains(&status_code);
    let status = if cache_status == "hit" {
        "cached"
    } else if is_error {
        "error"
    } else {
        "success"
    };
    let request_id = header_request_id
        .map(ToOwned::to_owned)
        .or(summary.request_id)
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| capture.request_id.clone());

    let row = TraceRow {
        id: capture.id.clone(),
        created_at: capture.created_at,
        provider: capture.provider.clone(),
        method: capture.method.clone(),
        path: capture.path.clone(),
        model: capture.model.clone(),
        status_code: i64::from(status_code),
        cache_status: cache_status.to_string(),
        latency_ms,
        request_id,
        prompt_system: capture.prompt_system.clone(),
        prompt_user: capture.prompt_user.clone(),
        response_text: summary.text,
        response_language: summary.language,
        error_code: is_error.then(|| status_code.to_string()),
        error_message: is_error.then(|| format!("Upstream returned HTTP {status_code}")),
        error_detail: is_error.then(|| utf8_preview(body)),
        tokens_in: summary.tokens_in,
        tokens_out: summary.tokens_out,
        cost: "$0.0000".to_string(),
        temperature: capture.temperature,
    };

    insert_trace_row(db, row, status);
}

pub(crate) fn record_upstream_error(
    db: &Arc<Mutex<Connection>>,
    capture: &TraceCapture,
    message: &str,
    latency_ms: i64,
) {
    let row = TraceRow {
        id: capture.id.clone(),
        created_at: capture.created_at,
        provider: capture.provider.clone(),
        method: capture.method.clone(),
        path: capture.path.clone(),
        model: capture.model.clone(),
        status_code: 502,
        cache_status: "miss".to_string(),
        latency_ms,
        request_id: capture.request_id.clone(),
        prompt_system: capture.prompt_system.clone(),
        prompt_user: capture.prompt_user.clone(),
        response_text: String::new(),
        response_language: "text".to_string(),
        error_code: Some("UPSTREAM_ERROR".to_string()),
        error_message: Some(message.to_string()),
        error_detail: Some(message.to_string()),
        tokens_in: 0,
        tokens_out: 0,
        cost: "$0.0000".to_string(),
        temperature: capture.temperature,
    };

    insert_trace_row(db, row, "error");
}

async fn current_trace(
    State(state): State<AppState>,
    Query(query): Query<TraceQuery>,
) -> Result<Json<TraceSnapshot>, (StatusCode, String)> {
    let db = state.db.clone();
    let session_id = query.session_id;
    let snapshot = tokio::task::spawn_blocking(move || fetch_snapshot(&db, session_id))
        .await
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("trace worker failed: {error}"),
            )
        })?
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("cannot load trace calls: {error}"),
            )
        })?;

    Ok(Json(snapshot))
}

async fn list_sessions(
    State(state): State<AppState>,
) -> Result<Json<SessionListDto>, (StatusCode, String)> {
    let db = state.db.clone();
    let response = tokio::task::spawn_blocking(move || fetch_sessions(&db))
        .await
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("session worker failed: {error}"),
            )
        })?
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("cannot load sessions: {error}"),
            )
        })?;

    Ok(Json(response))
}

async fn create_session_endpoint(
    State(state): State<AppState>,
) -> Result<(StatusCode, Json<TraceSessionDto>), (StatusCode, String)> {
    let db = state.db.clone();
    let session = tokio::task::spawn_blocking(move || {
        let conn = db.lock().expect("trace database lock poisoned");
        create_session(&conn, None)
    })
    .await
    .map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("session worker failed: {error}"),
        )
    })?
    .map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("cannot create session: {error}"),
        )
    })?;

    Ok((StatusCode::CREATED, Json(session)))
}

async fn clear_trace(State(state): State<AppState>) -> Result<StatusCode, (StatusCode, String)> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.lock().map_err(|_| "trace database lock poisoned")?;
        conn.execute("DELETE FROM trace_calls", [])
            .map_err(|_| "cannot clear trace calls")?;
        conn.execute("DELETE FROM sessions", [])
            .map_err(|_| "cannot clear sessions")?;
        create_session(&conn, Some("Live Session")).map_err(|_| "cannot reset session")?;
        Ok::<_, &'static str>(())
    })
    .await
    .map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("trace worker failed: {error}"),
        )
    })?
    .map_err(|error| (StatusCode::INTERNAL_SERVER_ERROR, error.to_string()))?;

    Ok(StatusCode::NO_CONTENT)
}

async fn clear_cache(State(state): State<AppState>) -> Result<StatusCode, (StatusCode, String)> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.lock().map_err(|_| "cache database lock poisoned")?;
        conn.execute("DELETE FROM cache", [])
            .map_err(|_| "cannot clear cache")?;
        Ok::<_, &'static str>(())
    })
    .await
    .map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("cache worker failed: {error}"),
        )
    })?
    .map_err(|error| (StatusCode::INTERNAL_SERVER_ERROR, error.to_string()))?;

    Ok(StatusCode::NO_CONTENT)
}

fn fetch_snapshot(
    db: &Arc<Mutex<Connection>>,
    requested_session_id: Option<String>,
) -> rusqlite::Result<TraceSnapshot> {
    let conn = db.lock().expect("trace database lock poisoned");
    let session = match requested_session_id {
        Some(session_id) => {
            find_session(&conn, &session_id)?.unwrap_or(ensure_current_session(&conn)?)
        }
        None => ensure_current_session(&conn)?,
    };
    let mut stmt = conn.prepare(
        "SELECT id, created_at, provider, method, path, model, status_code, cache_status,
                latency_ms, request_id, prompt_system, prompt_user, response_text,
                response_language, error_code, error_message, error_detail, tokens_in,
                tokens_out, cost, temperature
         FROM trace_calls
         WHERE session_id = ?1
         ORDER BY created_at ASC
         LIMIT 500",
    )?;
    let rows = stmt
        .query_map([session.id.as_str()], |row| {
            Ok(TraceRow {
                id: row.get(0)?,
                created_at: row.get(1)?,
                provider: row.get(2)?,
                method: row.get(3)?,
                path: row.get(4)?,
                model: row.get(5)?,
                status_code: row.get(6)?,
                cache_status: row.get(7)?,
                latency_ms: row.get(8)?,
                request_id: row.get(9)?,
                prompt_system: row.get(10)?,
                prompt_user: row.get(11)?,
                response_text: row.get(12)?,
                response_language: row.get(13)?,
                error_code: row.get(14)?,
                error_message: row.get(15)?,
                error_detail: row.get(16)?,
                tokens_in: row.get(17)?,
                tokens_out: row.get(18)?,
                cost: row.get(19)?,
                temperature: row.get(20)?,
            })
        })?
        .collect::<rusqlite::Result<Vec<_>>>()?;

    let max_latency = rows
        .iter()
        .map(|row| row.latency_ms)
        .max()
        .unwrap_or(1)
        .max(1);
    let nodes = rows
        .into_iter()
        .enumerate()
        .map(|(index, row)| row_to_node(index, row, max_latency))
        .collect();

    Ok(TraceSnapshot {
        session: Some(session),
        nodes,
    })
}

fn fetch_sessions(db: &Arc<Mutex<Connection>>) -> rusqlite::Result<SessionListDto> {
    let conn = db.lock().expect("trace database lock poisoned");
    let current = ensure_current_session(&conn)?;
    let mut stmt = conn.prepare(
        "SELECT id, created_at, name
         FROM sessions
         ORDER BY created_at DESC",
    )?;
    let sessions = stmt
        .query_map([], |row| {
            Ok(session_to_dto(
                row.get::<_, String>(0)?,
                row.get::<_, i64>(1)?,
                row.get::<_, String>(2)?,
            ))
        })?
        .collect::<rusqlite::Result<Vec<_>>>()?;

    Ok(SessionListDto {
        sessions,
        current_session_id: Some(current.id),
    })
}

fn ensure_current_session(conn: &Connection) -> rusqlite::Result<TraceSessionDto> {
    if let Some(session) = latest_session(conn)? {
        return Ok(session);
    }

    create_session(conn, Some("Live Session"))
}

fn latest_session(conn: &Connection) -> rusqlite::Result<Option<TraceSessionDto>> {
    conn.query_row(
        "SELECT id, created_at, name
         FROM sessions
         ORDER BY created_at DESC
         LIMIT 1",
        [],
        |row| {
            Ok(session_to_dto(
                row.get::<_, String>(0)?,
                row.get::<_, i64>(1)?,
                row.get::<_, String>(2)?,
            ))
        },
    )
    .optional()
}

fn find_session(conn: &Connection, id: &str) -> rusqlite::Result<Option<TraceSessionDto>> {
    conn.query_row(
        "SELECT id, created_at, name
         FROM sessions
         WHERE id = ?1",
        [id],
        |row| {
            Ok(session_to_dto(
                row.get::<_, String>(0)?,
                row.get::<_, i64>(1)?,
                row.get::<_, String>(2)?,
            ))
        },
    )
    .optional()
}

fn create_session(conn: &Connection, name: Option<&str>) -> rusqlite::Result<TraceSessionDto> {
    let created_at = now_millis();
    let id = Uuid::new_v4().to_string();
    let name = name
        .map(ToOwned::to_owned)
        .unwrap_or_else(|| format!("Session {}", format_time_for_name(created_at)));

    conn.execute(
        "INSERT INTO sessions (id, created_at, name)
         VALUES (?1, ?2, ?3)",
        params![id, created_at, name],
    )?;

    Ok(session_to_dto(id, created_at, name))
}

fn session_to_dto(id: String, created_at: i64, name: String) -> TraceSessionDto {
    TraceSessionDto {
        id,
        title: name,
        trigger: "AgentTrace proxy".to_string(),
        started_at: format_timestamp(created_at),
    }
}

fn backfill_missing_session_ids(conn: &Connection) -> rusqlite::Result<()> {
    let session = ensure_current_session(conn)?;
    conn.execute(
        "UPDATE trace_calls
         SET session_id = ?1
         WHERE session_id IS NULL OR session_id = ''",
        [session.id],
    )?;
    Ok(())
}

fn table_has_column(conn: &Connection, table: &str, column: &str) -> rusqlite::Result<bool> {
    let mut stmt = conn.prepare(&format!("PRAGMA table_info({table})"))?;
    let mut rows = stmt.query([])?;

    while let Some(row) = rows.next()? {
        let name: String = row.get(1)?;
        if name == column {
            return Ok(true);
        }
    }

    Ok(false)
}

fn row_to_node(index: usize, row: TraceRow, max_latency: i64) -> AgentNodeDto {
    let status = if row.cache_status == "hit" {
        "cached"
    } else if (200..=299).contains(&row.status_code) {
        "success"
    } else {
        "error"
    };
    let step_name = format!(
        "{} {}",
        row.provider.to_ascii_uppercase(),
        compact_path(&row.path)
    );
    let agent_name = agent_name_for(&row.provider, &row.model);

    AgentNodeDto {
        id: row.id,
        agent_name,
        depth: index as i64,
        step_name,
        timestamp: format_timestamp(row.created_at),
        model: row.model,
        cost: row.cost,
        latency: format_latency(row.latency_ms),
        latency_ms: row.latency_ms,
        bar_percent: (row.latency_ms as f64 / max_latency as f64).clamp(0.06, 1.0),
        tokens_in: row.tokens_in,
        tokens_out: row.tokens_out,
        request_id: row.request_id,
        cache_status: row.cache_status,
        temperature: row.temperature,
        status: status.to_string(),
        prompt: AgentPromptDto {
            system: row.prompt_system,
            user: row.prompt_user,
        },
        response: AgentResponseDto {
            language: row.response_language,
            text: row.response_text,
        },
        error: row.error_code.map(|code| AgentErrorDto {
            code,
            message: row.error_message.unwrap_or_default(),
            detail: row.error_detail.unwrap_or_default(),
        }),
    }
}

fn agent_name_for(provider: &str, model: &str) -> String {
    let provider = provider.to_ascii_lowercase();
    let model = model.to_ascii_lowercase();

    if provider == "anthropic" || model.contains("claude") {
        "Claude Code".to_string()
    } else if provider == "openai" {
        "Codex".to_string()
    } else {
        "Agent".to_string()
    }
}

fn insert_trace_row(db: &Arc<Mutex<Connection>>, row: TraceRow, status: &str) {
    if let Ok(conn) = db.lock() {
        let session = match ensure_current_session(&conn) {
            Ok(session) => session,
            Err(error) => {
                eprintln!("  cannot resolve trace session: {error}");
                return;
            }
        };

        let _ = conn.execute(
            "INSERT OR REPLACE INTO trace_calls
                (id, session_id, created_at, provider, method, path, model, status_code, cache_status,
                 latency_ms, request_id, prompt_system, prompt_user, response_text,
                 response_language, error_code, error_message, error_detail, tokens_in,
                 tokens_out, cost, temperature)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14,
                     ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22)",
            params![
                row.id,
                session.id,
                row.created_at,
                row.provider,
                row.method,
                row.path,
                row.model,
                row.status_code,
                row.cache_status,
                row.latency_ms,
                row.request_id,
                row.prompt_system,
                row.prompt_user,
                row.response_text,
                row.response_language,
                row.error_code,
                row.error_message,
                row.error_detail,
                row.tokens_in,
                row.tokens_out,
                row.cost,
                row.temperature,
            ],
        );
        println!("  captured trace node: {status}");
    }
}

fn summarize_response(content_type: &str, body: &[u8]) -> ResponseSummary {
    if let Ok(value) = serde_json::from_slice::<Value>(body) {
        let text = extract_response_text(&value).unwrap_or_else(|| pretty_json(&value));
        let usage = value.get("usage");
        let tokens_in = usage
            .and_then(|usage| {
                usage
                    .get("prompt_tokens")
                    .or_else(|| usage.get("input_tokens"))
                    .and_then(Value::as_i64)
            })
            .unwrap_or(0);
        let tokens_out = usage
            .and_then(|usage| {
                usage
                    .get("completion_tokens")
                    .or_else(|| usage.get("output_tokens"))
                    .and_then(Value::as_i64)
            })
            .unwrap_or(0);

        return ResponseSummary {
            request_id: value
                .get("id")
                .and_then(Value::as_str)
                .map(ToOwned::to_owned),
            text: cap_text(&text, 64_000),
            language: "json".to_string(),
            tokens_in,
            tokens_out,
        };
    }

    let text = utf8_preview(body);
    ResponseSummary {
        request_id: None,
        language: if content_type.contains("json") {
            "json".to_string()
        } else {
            "text".to_string()
        },
        text,
        tokens_in: 0,
        tokens_out: 0,
    }
}

fn extract_prompt(value: &Value) -> (String, String) {
    let system = value
        .get("system")
        .map(content_to_string)
        .or_else(|| {
            value
                .get("messages")
                .and_then(Value::as_array)
                .map(|messages| {
                    messages
                        .iter()
                        .filter(|message| {
                            matches!(
                                message.get("role").and_then(Value::as_str),
                                Some("system" | "developer")
                            )
                        })
                        .filter_map(|message| message.get("content"))
                        .map(content_to_string)
                        .collect::<Vec<_>>()
                        .join("\n\n")
                })
        })
        .unwrap_or_default();

    let user = value
        .get("messages")
        .and_then(Value::as_array)
        .and_then(|messages| {
            messages
                .iter()
                .rev()
                .find(|message| message.get("role").and_then(Value::as_str) == Some("user"))
                .and_then(|message| message.get("content"))
                .map(content_to_string)
        })
        .or_else(|| value.get("input").map(content_to_string))
        .or_else(|| {
            value
                .get("prompt")
                .and_then(Value::as_str)
                .map(ToOwned::to_owned)
        })
        .unwrap_or_default();

    (cap_text(&system, 16_000), cap_text(&user, 32_000))
}

fn extract_last_text(value: &Value) -> Option<String> {
    let arr = value
        .get("messages")
        .and_then(Value::as_array)
        .or_else(|| value.get("input").and_then(Value::as_array));
    if let Some(arr) = arr {
        return arr
            .last()
            .map(|last| content_to_string(last.get("content").unwrap_or(last)));
    }
    value.get("input").map(content_to_string).or_else(|| {
        value
            .get("prompt")
            .and_then(Value::as_str)
            .map(ToOwned::to_owned)
    })
}

fn extract_response_text(value: &Value) -> Option<String> {
    if let Some(text) = value.get("output_text").and_then(Value::as_str) {
        return Some(text.to_string());
    }

    if let Some(content) = value
        .get("choices")
        .and_then(Value::as_array)
        .and_then(|choices| choices.first())
        .and_then(|choice| choice.get("message"))
        .and_then(|message| message.get("content"))
    {
        return Some(content_to_string(content));
    }

    if let Some(content) = value.get("content").and_then(Value::as_array) {
        let text = content
            .iter()
            .filter_map(|item| item.get("text").and_then(Value::as_str))
            .collect::<Vec<_>>()
            .join("\n\n");
        if !text.is_empty() {
            return Some(text);
        }
    }

    if let Some(output) = value.get("output").and_then(Value::as_array) {
        let text = output
            .iter()
            .flat_map(|item| {
                item.get("content")
                    .and_then(Value::as_array)
                    .cloned()
                    .unwrap_or_default()
            })
            .filter_map(|item| {
                item.get("text")
                    .and_then(Value::as_str)
                    .map(ToOwned::to_owned)
            })
            .collect::<Vec<_>>()
            .join("\n\n");
        if !text.is_empty() {
            return Some(text);
        }
    }

    None
}

fn content_to_string(content: &Value) -> String {
    match content {
        Value::String(text) => text.clone(),
        Value::Array(items) => items
            .iter()
            .map(|item| {
                item.get("text")
                    .and_then(Value::as_str)
                    .map(ToOwned::to_owned)
                    .or_else(|| item.as_str().map(ToOwned::to_owned))
                    .unwrap_or_else(|| item.to_string())
            })
            .collect::<Vec<_>>()
            .join(" "),
        other => other.to_string(),
    }
}

fn pretty_json(value: &Value) -> String {
    serde_json::to_string_pretty(value).unwrap_or_else(|_| value.to_string())
}

fn utf8_preview(body: &[u8]) -> String {
    cap_text(&String::from_utf8_lossy(body), 64_000)
}

fn cap_text(text: &str, max_chars: usize) -> String {
    if text.chars().count() <= max_chars {
        return text.to_string();
    }

    let mut capped = text.chars().take(max_chars).collect::<String>();
    capped.push('…');
    capped
}

fn truncate_one_line(text: &str, max_chars: usize) -> String {
    let one_line = text.split_whitespace().collect::<Vec<_>>().join(" ");
    cap_text(&one_line, max_chars)
}

fn compact_path(path: &str) -> String {
    path.trim_start_matches('/')
        .rsplit('/')
        .next()
        .filter(|segment| !segment.is_empty())
        .unwrap_or(path)
        .to_string()
}

fn format_latency(milliseconds: i64) -> String {
    if milliseconds >= 1_000 {
        format!("{:.2}s", milliseconds as f64 / 1_000.0)
    } else {
        format!("{milliseconds}ms")
    }
}

fn format_timestamp(milliseconds: i64) -> String {
    let seconds = milliseconds.div_euclid(1_000);
    let millis = milliseconds.rem_euclid(1_000) as u32;
    let nanos = millis * 1_000_000;
    let local: DateTime<Local> = Local
        .timestamp_opt(seconds, nanos)
        .single()
        .unwrap_or_else(Local::now);

    local.format("%H:%M:%S").to_string()
}

fn format_time_for_name(milliseconds: i64) -> String {
    let seconds = milliseconds.div_euclid(1_000);
    let millis = milliseconds.rem_euclid(1_000) as u32;
    let nanos = millis * 1_000_000;
    let local: DateTime<Local> = Local
        .timestamp_opt(seconds, nanos)
        .single()
        .unwrap_or_else(Local::now);

    local.format("%H:%M").to_string()
}

fn now_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_millis() as i64)
        .unwrap_or(0)
}
