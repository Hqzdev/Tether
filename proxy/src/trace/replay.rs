//! Trace replay and invalidation endpoints.

use axum::{
    Json,
    extract::{Path, State},
    http::{HeaderMap, StatusCode, header::CONTENT_TYPE},
};
use serde_json::Value;
use uuid::Uuid;

use super::cost::estimate_cost;
use super::replay_headers::{filtered_replay_headers, inject_replay_credentials};
use super::replay_store::{
    downstream_result, edit_output_result, insert_replay_with_result, load_replay_spec,
    load_replay_with_spec, map_node_error, persist_replay_result,
};
use super::replay_types::{
    EditOutputRequest, ReplayResult, ReplayUpdate, ReplayWithInsert, ReplayWithRequest,
    ReplayWithResult,
};
use super::routes::response_request_id;
use super::summarize::summarize_response;
use super::text::now_millis;
use crate::{AppState, settings::cometapi::load_cometapi_key};

const COMETAPI_CHAT_COMPLETIONS_URL: &str = "https://api.cometapi.com/v1/chat/completions";

/// Edits a span's output and marks transitive descendants stale.
pub(super) async fn edit_output(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(payload): Json<EditOutputRequest>,
) -> Result<Json<super::replay_types::InvalidationResult>, (StatusCode, String)> {
    let db = state.db.clone();
    let result = tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| "trace database lock poisoned".to_string())?;
        edit_output_result(&conn, id, payload.output)
    })
    .await
    .map_err(worker_error)?
    .map_err(map_node_error)?;

    Ok(Json(result))
}

/// Returns the spans that would be invalidated if this node changed.
pub(super) async fn list_downstream(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<super::replay_types::DownstreamResult>, (StatusCode, String)> {
    let db = state.db.clone();
    let result = tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| "trace database lock poisoned".to_string())?;
        downstream_result(&conn, id)
    })
    .await
    .map_err(worker_error)?
    .map_err(map_node_error)?;

    Ok(Json(result))
}

/// Re-runs a retained request body against the original provider target.
pub(super) async fn replay_node(
    State(state): State<AppState>,
    Path(id): Path<String>,
    headers: HeaderMap,
) -> Result<Json<ReplayResult>, (StatusCode, String)> {
    let spec = load_spec_for_node(&state, &id).await?;
    if spec.body.is_empty() {
        return Err((
            StatusCode::CONFLICT,
            "node is not replayable (request body was not retained)".to_string(),
        ));
    }

    let mut forward_headers = filtered_replay_headers(&headers);
    inject_replay_credentials(&mut forward_headers, &spec.provider, &state);

    let url = format!("{}{}", replay_base_url(&state, &spec.provider), spec.target);
    let method =
        reqwest::Method::from_bytes(spec.method.as_bytes()).unwrap_or(reqwest::Method::POST);
    let started = now_millis();
    let response = state
        .client
        .request(method, &url)
        .headers(forward_headers)
        .body(spec.body)
        .send()
        .await
        .map_err(|error| {
            (
                StatusCode::BAD_GATEWAY,
                format!("replay upstream error: {error}"),
            )
        })?;

    let status_code = response.status().as_u16();
    let content_type = response_content_type(response.headers());
    let header_request_id = response_request_id(response.headers());
    let body = response.bytes().await.map_err(|error| {
        (
            StatusCode::BAD_GATEWAY,
            format!("replay read error: {error}"),
        )
    })?;
    let latency_ms = (now_millis() - started).max(0);

    let summary = summarize_response(&content_type, &body);
    let cost = estimate_cost(
        &spec.provider,
        &spec.model,
        summary.tokens_in,
        summary.tokens_out,
    );
    let request_id = replay_request_id(header_request_id, summary.request_id.clone());
    let result = persist_replay_update(
        &state,
        ReplayUpdate::from_summary(id, status_code, latency_ms, cost, request_id, summary),
    )
    .await?;

    Ok(Json(result))
}

/// Re-runs a retained request through CometAPI using a different model.
pub(super) async fn replay_with_model(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(payload): Json<ReplayWithRequest>,
) -> Result<Json<ReplayWithResult>, (StatusCode, String)> {
    let model = payload.model.trim().to_string();
    if model.is_empty() {
        return Err((StatusCode::BAD_REQUEST, "model is required".to_string()));
    }

    let api_key = match payload
        .provider_key
        .as_deref()
        .map(str::trim)
        .filter(|key| !key.is_empty())
    {
        Some(key) => key.to_string(),
        None => load_cometapi_key(&state)
            .await
            .map_err(|error| (error.status, error.message))?
            .ok_or_else(|| {
                (
                    StatusCode::UNAUTHORIZED,
                    "CometAPI key is not configured".to_string(),
                )
            })?,
    };

    let source = load_replay_with_source(&state, &id).await?;
    if source.body.is_empty() {
        return Err((
            StatusCode::CONFLICT,
            "node is not replayable (request body was not retained)".to_string(),
        ));
    }

    let request_body = cometapi_request_body(&source.body, &model)?;
    let started = now_millis();
    let response = state
        .client
        .post(COMETAPI_CHAT_COMPLETIONS_URL)
        .bearer_auth(api_key)
        .header(CONTENT_TYPE, "application/json")
        .body(request_body.clone())
        .send()
        .await
        .map_err(|error| {
            (
                StatusCode::BAD_GATEWAY,
                format!("CometAPI replay upstream error: {error}"),
            )
        })?;

    let status_code = response.status().as_u16();
    let response_status = response.status();
    let content_type = response_content_type(response.headers());
    let header_request_id = response_request_id(response.headers());
    let body = response.bytes().await.map_err(|error| {
        (
            StatusCode::BAD_GATEWAY,
            format!("CometAPI replay read error: {error}"),
        )
    })?;
    if !response_status.is_success() {
        return Err((
            response_status,
            format!("CometAPI replay error: {}", String::from_utf8_lossy(&body)),
        ));
    }

    let latency_ms = (now_millis() - started).max(0);
    let summary = summarize_response(&content_type, &body);
    let cost = estimate_cost("", &model, summary.tokens_in, summary.tokens_out);
    let request_id = replay_request_id(header_request_id, summary.request_id.clone());
    let tool_use_ids =
        serde_json::to_string(&summary.tool_use_ids).unwrap_or_else(|_| "[]".to_string());
    let insert = ReplayWithInsert {
        id: Uuid::new_v4().to_string(),
        source_node_id: source.id,
        trace_id: source.trace_id,
        parent_span_id: source.parent_span_id,
        model,
        status_code,
        latency_ms,
        request_id,
        prompt_system: source.prompt_system,
        prompt_user: source.prompt_user,
        response_text: summary.text,
        response_language: summary.language,
        tokens_in: summary.tokens_in,
        tokens_out: summary.tokens_out,
        cost,
        temperature: source.temperature,
        tool_use_ids,
        context_inputs: source.context_inputs,
        input_hash: source.input_hash,
        request_body,
    };
    let result = persist_replay_with_insert(&state, insert).await?;
    Ok(Json(result))
}

/// Loads replay metadata for a node on a blocking SQLite worker.
async fn load_spec_for_node(
    state: &AppState,
    id: &str,
) -> Result<super::replay_types::ReplaySpec, (StatusCode, String)> {
    let db = state.db.clone();
    let lookup_id = id.to_string();
    tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| "trace database lock poisoned".to_string())?;
        load_replay_spec(&conn, &lookup_id)
    })
    .await
    .map_err(worker_error)?
    .map_err(map_node_error)
}

async fn load_replay_with_source(
    state: &AppState,
    id: &str,
) -> Result<super::replay_types::ReplayWithSpec, (StatusCode, String)> {
    let db = state.db.clone();
    let lookup_id = id.to_string();
    tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| "trace database lock poisoned".to_string())?;
        load_replay_with_spec(&conn, &lookup_id)
    })
    .await
    .map_err(worker_error)?
    .map_err(map_node_error)
}

/// Persists replay output on a blocking SQLite worker.
async fn persist_replay_update(
    state: &AppState,
    update: ReplayUpdate,
) -> Result<ReplayResult, (StatusCode, String)> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| "trace database lock poisoned".to_string())?;
        persist_replay_result(&conn, update)
    })
    .await
    .map_err(worker_error)?
    .map_err(map_node_error)
}

async fn persist_replay_with_insert(
    state: &AppState,
    insert: ReplayWithInsert,
) -> Result<ReplayWithResult, (StatusCode, String)> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| "trace database lock poisoned".to_string())?;
        insert_replay_with_result(&conn, insert)
    })
    .await
    .map_err(worker_error)?
    .map_err(map_node_error)
}

/// Maps blocking worker join errors into API errors.
fn worker_error(error: tokio::task::JoinError) -> (StatusCode, String) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        format!("worker failed: {error}"),
    )
}

/// Returns the configured upstream base URL for a replay provider.
fn replay_base_url(state: &AppState, provider: &str) -> String {
    if provider == "anthropic" {
        state.anthropic_upstream.to_string()
    } else {
        state.openai_upstream.to_string()
    }
}

/// Extracts the content type from an upstream response header map.
fn response_content_type(headers: &HeaderMap) -> String {
    headers
        .get(CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .unwrap_or("")
        .to_string()
}

/// Picks the replay request id from headers, body summary, or a placeholder.
fn replay_request_id(
    header_request_id: Option<String>,
    summary_request_id: Option<String>,
) -> String {
    header_request_id
        .or(summary_request_id)
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "-".to_string())
}

fn cometapi_request_body(body: &[u8], model: &str) -> Result<Vec<u8>, (StatusCode, String)> {
    let mut value = serde_json::from_slice::<Value>(body).map_err(|error| {
        (
            StatusCode::CONFLICT,
            format!("stored request body is not JSON: {error}"),
        )
    })?;
    let Some(object) = value.as_object_mut() else {
        return Err((
            StatusCode::CONFLICT,
            "stored request body is not a JSON object".to_string(),
        ));
    };
    object.insert("model".to_string(), Value::String(model.to_string()));
    object.remove("stream");
    serde_json::to_vec(&value).map_err(|error| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("cannot encode CometAPI replay request: {error}"),
        )
    })
}
