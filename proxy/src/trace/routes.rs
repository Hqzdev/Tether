//! HTTP surface for traces: the `/api/sessions`, `/api/traces/current`, and
//! `/api/cache` routes plus their async handlers. Handlers stay thin — they hop
//! to a blocking worker and translate errors into HTTP responses.

use axum::{
    Json, Router,
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    routing::{delete, get, patch, post},
};
use serde::Deserialize;

use tether_domain::{AgentNodeDto, SessionListDto, TraceSessionDto, TraceSnapshot};

use super::query::{fetch_node_detail, fetch_sessions, fetch_snapshot, fetch_snapshot_summary};
use super::replay::{edit_output, list_downstream, replay_node};
use super::sessions::{create_session, find_session, rename_session, soft_delete_session};
use crate::AppState;

#[derive(Deserialize)]
struct TraceQuery {
    session_id: Option<String>,
}

/// Request body for renaming a session.
#[derive(Deserialize)]
struct RenameSessionBody {
    name: String,
}

/// Mounts the trace/session/cache routes onto the proxy router.
pub(crate) fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/sessions",
            get(list_sessions).post(create_session_endpoint),
        )
        .route(
            "/api/sessions/{id}",
            patch(rename_session_endpoint).delete(delete_session_endpoint),
        )
        .route("/api/sessions/{id}/traces", get(session_traces))
        .route(
            "/api/sessions/{id}/activate",
            post(activate_session_endpoint),
        )
        .route(
            "/api/traces/current",
            get(current_trace).delete(clear_trace),
        )
        .route("/api/traces/current/summary", get(current_trace_summary))
        .route("/api/traces/{id}", get(trace_node_detail))
        .route("/api/traces/{id}/output", patch(edit_output))
        .route("/api/traces/{id}/downstream", get(list_downstream))
        .route("/api/traces/{id}/replay", post(replay_node))
        .route("/api/cache", delete(clear_cache))
}

/// Extracts the upstream request id from any of the known provider headers.
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

async fn current_trace(
    State(state): State<AppState>,
    Query(query): Query<TraceQuery>,
) -> Result<Json<TraceSnapshot>, (StatusCode, String)> {
    let db = state.db.clone();
    let session_id = query.session_id.or_else(|| active_session_id(&state));
    let snapshot = tokio::task::spawn_blocking(move || fetch_snapshot(&db, session_id))
        .await
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("trace worker failed: {error}"),
            )
        })?
        .map_err(|error| trace_query_error("cannot load trace calls", error))?;

    Ok(Json(snapshot))
}

async fn current_trace_summary(
    State(state): State<AppState>,
    Query(query): Query<TraceQuery>,
) -> Result<Json<TraceSnapshot>, (StatusCode, String)> {
    let db = state.db.clone();
    let session_id = query.session_id.or_else(|| active_session_id(&state));
    let snapshot = tokio::task::spawn_blocking(move || fetch_snapshot_summary(&db, session_id))
        .await
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("trace summary worker failed: {error}"),
            )
        })?
        .map_err(|error| trace_query_error("cannot load trace summary", error))?;

    Ok(Json(snapshot))
}

async fn trace_node_detail(
    State(state): State<AppState>,
    axum::extract::Path(node_id): axum::extract::Path<String>,
) -> Result<Json<AgentNodeDto>, (StatusCode, String)> {
    let db = state.db.clone();
    let node = tokio::task::spawn_blocking(move || fetch_node_detail(&db, node_id))
        .await
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("trace detail worker failed: {error}"),
            )
        })?
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("cannot load trace node detail: {error}"),
            )
        })?
        .ok_or_else(|| (StatusCode::NOT_FOUND, "trace node not found".to_string()))?;

    Ok(Json(node))
}

async fn list_sessions(
    State(state): State<AppState>,
) -> Result<Json<SessionListDto>, (StatusCode, String)> {
    let db = state.db.clone();
    let active_session_id = active_session_id(&state);
    let response = tokio::task::spawn_blocking(move || fetch_sessions(&db, active_session_id))
        .await
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("session worker failed: {error}"),
            )
        })?
        .map_err(|error| trace_query_error("cannot load sessions", error))?;

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

    // A freshly created session becomes the active one so the next calls land in it.
    set_active_session(&state, Some(session.id.clone()));

    Ok((StatusCode::CREATED, Json(session)))
}

/// Returns every trace node for one session, ordered oldest-first.
async fn session_traces(
    State(state): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<Json<TraceSnapshot>, (StatusCode, String)> {
    let db = state.db.clone();
    let snapshot = tokio::task::spawn_blocking(move || fetch_snapshot(&db, Some(session_id)))
        .await
        .map_err(|error| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("session traces worker failed: {error}"),
            )
        })?
        .map_err(|error| trace_query_error("cannot load session traces", error))?;

    Ok(Json(snapshot))
}

/// Renames a session, returning the updated metadata.
async fn rename_session_endpoint(
    State(state): State<AppState>,
    Path(session_id): Path<String>,
    Json(body): Json<RenameSessionBody>,
) -> Result<Json<TraceSessionDto>, (StatusCode, String)> {
    let name = body.name.trim().to_string();
    if name.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            "session name cannot be empty".to_string(),
        ));
    }

    let db = state.db.clone();
    let session = tokio::task::spawn_blocking(move || {
        let conn = db.lock().expect("trace database lock poisoned");
        rename_session(&conn, &session_id, &name)
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
            format!("cannot rename session: {error}"),
        )
    })?
    .ok_or_else(|| (StatusCode::NOT_FOUND, "session not found".to_string()))?;

    Ok(Json(session))
}

/// Soft-deletes a session and clears it from the active slot when needed.
async fn delete_session_endpoint(
    State(state): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<StatusCode, (StatusCode, String)> {
    let db = state.db.clone();
    let target = session_id.clone();
    let deleted = tokio::task::spawn_blocking(move || {
        let conn = db.lock().expect("trace database lock poisoned");
        soft_delete_session(&conn, &target)
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
            format!("cannot delete session: {error}"),
        )
    })?;

    if !deleted {
        return Err((StatusCode::NOT_FOUND, "session not found".to_string()));
    }

    if let Ok(mut guard) = state.current_session_id.lock()
        && guard.as_deref() == Some(session_id.as_str())
    {
        *guard = None;
    }

    Ok(StatusCode::NO_CONTENT)
}

/// Routes subsequent traffic into an existing session.
async fn activate_session_endpoint(
    State(state): State<AppState>,
    Path(session_id): Path<String>,
) -> Result<Json<TraceSessionDto>, (StatusCode, String)> {
    let db = state.db.clone();
    let lookup_id = session_id.clone();
    let session = tokio::task::spawn_blocking(move || {
        let conn = db.lock().expect("trace database lock poisoned");
        find_session(&conn, &lookup_id)
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
            format!("cannot load session: {error}"),
        )
    })?
    .ok_or_else(|| (StatusCode::NOT_FOUND, "session not found".to_string()))?;

    set_active_session(&state, Some(session.id.clone()));

    Ok(Json(session))
}

/// Stores the active session id, ignoring a poisoned lock (best-effort routing).
fn set_active_session(state: &AppState, session_id: Option<String>) {
    if let Ok(mut guard) = state.current_session_id.lock() {
        *guard = session_id;
    }
}

/// Reads the currently active session id without holding the lock across work.
fn active_session_id(state: &AppState) -> Option<String> {
    state
        .current_session_id
        .lock()
        .ok()
        .and_then(|guard| guard.clone())
}

/// Converts query errors into the HTTP surface; missing sessions are 404s.
fn trace_query_error(context: &str, error: rusqlite::Error) -> (StatusCode, String) {
    if matches!(error, rusqlite::Error::QueryReturnedNoRows) {
        return (StatusCode::NOT_FOUND, "session not found".to_string());
    }

    (
        StatusCode::INTERNAL_SERVER_ERROR,
        format!("{context}: {error}"),
    )
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

    // The previously active session id was just deleted; fall back to the fresh one.
    set_active_session(&state, None);

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
