//! Read path: assemble `TraceSnapshot` / `SessionListDto` from stored rows.

use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
};

use rusqlite::Connection;

use tether_domain::{AgentNodeDto, SessionListDto, TraceSnapshot};

use super::node::row_to_node;
use super::sessions::{ensure_current_session, find_session, session_to_dto};
use super::store_row::TraceRow;

/// Loads the latest 500 calls for a session (the current one when unspecified)
/// and lays them out as graph nodes, normalizing the latency bars.
pub(super) fn fetch_snapshot(
    db: &Arc<Mutex<Connection>>,
    requested_session_id: Option<String>,
) -> rusqlite::Result<TraceSnapshot> {
    fetch_snapshot_with_payload(db, requested_session_id, true)
}

/// Loads a lightweight snapshot for graph polling without large prompt/response payloads.
pub(super) fn fetch_snapshot_summary(
    db: &Arc<Mutex<Connection>>,
    requested_session_id: Option<String>,
) -> rusqlite::Result<TraceSnapshot> {
    fetch_snapshot_with_payload(db, requested_session_id, false)
}

fn fetch_snapshot_with_payload(
    db: &Arc<Mutex<Connection>>,
    requested_session_id: Option<String>,
    include_payload: bool,
) -> rusqlite::Result<TraceSnapshot> {
    let conn = db.lock().expect("trace database lock poisoned");
    let session = match requested_session_id {
        Some(session_id) => {
            find_session(&conn, &session_id)?.unwrap_or(ensure_current_session(&conn)?)
        }
        None => ensure_current_session(&conn)?,
    };
    let payload_columns = if include_payload {
        "prompt_system, prompt_user, response_text, response_language,
         error_code, error_message, error_detail, tool_use_ids, context_inputs"
    } else {
        "'' AS prompt_system, '' AS prompt_user, '' AS response_text, response_language,
         error_code, error_message, '' AS error_detail, '[]' AS tool_use_ids, '{}' AS context_inputs"
    };
    let sql = format!(
        "SELECT id, created_at, provider, method, path, model, status_code, cache_status,
                latency_ms, request_id, {payload_columns}, tokens_in, tokens_out,
                cost, temperature, trace_id, parent_span_id, input_hash, stale
         FROM trace_calls
         WHERE session_id = ?1
         ORDER BY created_at ASC
         LIMIT 500"
    );
    let mut stmt = conn.prepare(&sql)?;
    let rows = stmt
        .query_map([session.id.as_str()], trace_row_from_query)?
        .collect::<rusqlite::Result<Vec<_>>>()?;

    let max_latency = rows
        .iter()
        .map(|row| row.latency_ms)
        .max()
        .unwrap_or(1)
        .max(1);
    let depths = compute_depths(&rows);
    let stale_node_ids = rows
        .iter()
        .filter(|row| row.stale)
        .map(|row| row.id.clone())
        .collect();
    let nodes = rows
        .into_iter()
        .map(|row| {
            let depth = depths.get(&row.id).copied().unwrap_or(0);
            row_to_node(depth, row, max_latency)
        })
        .collect();

    Ok(TraceSnapshot {
        session: Some(session),
        nodes,
        stale_node_ids,
    })
}

/// Loads the full payload for a single node selected in the inspector.
pub(super) fn fetch_node_detail(
    db: &Arc<Mutex<Connection>>,
    node_id: String,
) -> rusqlite::Result<Option<AgentNodeDto>> {
    let conn = db.lock().expect("trace database lock poisoned");
    let mut stmt = conn.prepare(
        "SELECT id, created_at, provider, method, path, model, status_code, cache_status,
                latency_ms, request_id, prompt_system, prompt_user, response_text,
                response_language, error_code, error_message, error_detail, tool_use_ids,
                context_inputs, tokens_in, tokens_out, cost, temperature, trace_id,
                parent_span_id, input_hash, stale
         FROM trace_calls
         WHERE id = ?1
         LIMIT 1",
    )?;
    let mut rows = stmt.query([node_id.as_str()])?;
    let Some(row) = rows.next()? else {
        return Ok(None);
    };

    let trace_row = trace_row_from_query(row)?;
    let max_latency = trace_row.latency_ms.max(1);
    Ok(Some(row_to_node(0, trace_row, max_latency)))
}

fn trace_row_from_query(row: &rusqlite::Row<'_>) -> rusqlite::Result<TraceRow> {
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
        tool_use_ids: row
            .get::<_, Option<String>>(17)?
            .unwrap_or_else(|| "[]".to_string()),
        context_inputs: row
            .get::<_, Option<String>>(18)?
            .unwrap_or_else(|| "{}".to_string()),
        tokens_in: row.get(19)?,
        tokens_out: row.get(20)?,
        cost: row.get(21)?,
        temperature: row.get(22)?,
        trace_id: row.get::<_, Option<String>>(23)?.unwrap_or_default(),
        parent_span_id: row.get(24)?,
        input_hash: row.get::<_, Option<String>>(25)?.unwrap_or_default(),
        stale: row.get::<_, Option<i64>>(26)?.unwrap_or(0) != 0,
        request_body: Vec::new(),
        request_target: String::new(),
        tool_result_ids: Vec::new(),
    })
}

/// Walks parent links to assign a tree depth (root = 0) to every span.
fn compute_depths(rows: &[TraceRow]) -> HashMap<String, i64> {
    let parents: HashMap<&str, Option<&str>> = rows
        .iter()
        .map(|row| (row.id.as_str(), row.parent_span_id.as_deref()))
        .collect();
    let mut depths = HashMap::new();
    for row in rows {
        let mut depth = 0;
        let mut current = row.parent_span_id.as_deref();
        let mut guard = 0;
        while let Some(parent) = current {
            if guard > rows.len() {
                break;
            }
            depth += 1;
            guard += 1;
            current = parents.get(parent).copied().flatten();
        }
        depths.insert(row.id.clone(), depth);
    }
    depths
}

/// Lists all sessions (newest first) plus the id of the current one.
pub(super) fn fetch_sessions(db: &Arc<Mutex<Connection>>) -> rusqlite::Result<SessionListDto> {
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
