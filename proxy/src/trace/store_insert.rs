//! Insert and lineage helpers for trace persistence.

use std::sync::{Arc, Mutex};

use rusqlite::{Connection, OptionalExtension, params};

use super::sessions::{name_session_from_prompt, resolve_target_session, session_call_count};
use super::store_row::TraceRow;

/// Inserts a row under the active session (falling back to the most recent one).
/// Best-effort: logs and returns on failure.
pub(super) fn insert_trace_row(
    db: &Arc<Mutex<Connection>>,
    row: TraceRow,
    status: &str,
    active_session: Option<&str>,
) -> Option<String> {
    if let Ok(conn) = db.lock() {
        let session = match resolve_target_session(&conn, active_session) {
            Ok(session) => session,
            Err(error) => {
                eprintln!("  cannot resolve trace session: {error}");
                return None;
            }
        };

        // Capture whether this is the session's opening call before inserting, so
        // a fresh session can be renamed after its first user prompt lands.
        let is_first_call = session_call_count(&conn, &session.id).unwrap_or(1) == 0;
        let prompt_user = row.prompt_user.clone();

        let (trace_id, parent_span_id) = resolve_lineage(&conn, &row.id, &row.tool_result_ids);
        insert_row(&conn, row, &session.id, trace_id, parent_span_id);

        if is_first_call
            && let Err(error) = name_session_from_prompt(&conn, &session.id, &prompt_user)
        {
            eprintln!("  cannot name session from prompt: {error}");
        }
        println!("  captured trace node: {status}");
        return Some(session.id);
    }

    None
}

/// Writes one trace row into SQLite.
fn insert_row(
    conn: &Connection,
    row: TraceRow,
    session_id: &str,
    trace_id: String,
    parent_span_id: Option<String>,
) {
    let _ = conn.execute(
        "INSERT OR REPLACE INTO trace_calls
            (id, session_id, created_at, provider, method, path, model, status_code, cache_status,
             latency_ms, request_id, prompt_system, prompt_user, response_text,
             response_language, error_code, error_message, error_detail, tokens_in,
             tokens_out, cost, temperature, trace_id, parent_span_id, tool_use_ids,
             context_inputs, input_hash, stale, request_body, request_target)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14,
                 ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22, ?23, ?24, ?25, ?26,
                 ?27, ?28, ?29, ?30)",
        params![
            row.id,
            session_id,
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
            trace_id,
            parent_span_id,
            row.tool_use_ids,
            row.context_inputs,
            row.input_hash,
            row.stale as i64,
            row.request_body,
            row.request_target,
        ],
    );
}

/// Finds parent span lineage from request-side tool result ids.
fn resolve_lineage(
    conn: &Connection,
    own_id: &str,
    tool_result_ids: &[String],
) -> (String, Option<String>) {
    for tool_use_id in tool_result_ids {
        if let Some((parent_id, parent_trace_id)) = find_parent_span(conn, tool_use_id) {
            let trace_id = if parent_trace_id.is_empty() {
                parent_id.clone()
            } else {
                parent_trace_id
            };
            return (trace_id, Some(parent_id));
        }
    }
    (own_id.to_string(), None)
}

/// Finds a prior response span that emitted the given tool use id.
fn find_parent_span(conn: &Connection, tool_use_id: &str) -> Option<(String, String)> {
    conn.query_row(
        "SELECT id, COALESCE(trace_id, '')
         FROM trace_calls
         WHERE tool_use_ids LIKE ?1
         ORDER BY created_at DESC
         LIMIT 1",
        [format!("%\"{tool_use_id}\"%")],
        |row| Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?)),
    )
    .optional()
    .ok()
    .flatten()
}
