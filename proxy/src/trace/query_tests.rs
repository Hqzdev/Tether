//! Tests for trace snapshot query assembly.

use std::sync::{Arc, Mutex};

use rusqlite::Connection;

use super::{
    query::{fetch_node_detail, fetch_sessions, fetch_snapshot, fetch_snapshot_summary},
    schema, sessions, store_insert,
    store_row::TraceRow,
};

/// Verifies snapshot readback order and latency bar normalization.
#[test]
fn fetch_snapshot_orders_nodes_and_normalizes_latency() {
    let db = Arc::new(Mutex::new(Connection::open_in_memory().unwrap()));
    let session_id = {
        let conn = db.lock().unwrap();
        schema::init_schema(&conn).unwrap();
        let session = sessions::ensure_current_session(&conn).unwrap();
        insert_row(&conn, &session.id, "a", 1_000, 100, "miss");
        insert_row(&conn, &session.id, "b", 2_000, 200, "hit");
        session.id
    };

    let snapshot = fetch_snapshot(&db, None).unwrap();

    assert_eq!(snapshot.session.as_ref().map(|s| &s.id), Some(&session_id));
    assert_eq!(snapshot.nodes.len(), 2);
    assert_eq!(snapshot.nodes[0].id, "a");
    assert_eq!(snapshot.nodes[0].bar_percent, 0.5);
    assert_eq!(snapshot.nodes[1].id, "b");
    assert_eq!(snapshot.nodes[1].status, "cached");
    assert_eq!(snapshot.nodes[1].bar_percent, 1.0);
}

/// Verifies the summary read path preserves graph fields while omitting heavy payloads.
#[test]
fn fetch_snapshot_summary_omits_prompt_and_response_payloads() {
    let db = Arc::new(Mutex::new(Connection::open_in_memory().unwrap()));
    {
        let conn = db.lock().unwrap();
        schema::init_schema(&conn).unwrap();
        let session = sessions::ensure_current_session(&conn).unwrap();
        insert_row(&conn, &session.id, "a", 1_000, 100, "miss");
    }

    let snapshot = fetch_snapshot_summary(&db, None).unwrap();

    assert_eq!(snapshot.nodes.len(), 1);
    assert_eq!(snapshot.nodes[0].id, "a");
    assert_eq!(snapshot.nodes[0].prompt.user, "");
    assert_eq!(snapshot.nodes[0].response.text, "");
}

/// Verifies a selected node can be hydrated with full inspector payloads.
#[test]
fn fetch_node_detail_returns_full_payload_for_selected_node() {
    let db = Arc::new(Mutex::new(Connection::open_in_memory().unwrap()));
    {
        let conn = db.lock().unwrap();
        schema::init_schema(&conn).unwrap();
        let session = sessions::ensure_current_session(&conn).unwrap();
        insert_row(&conn, &session.id, "a", 1_000, 100, "miss");
    }

    let node = fetch_node_detail(&db, "a".to_string()).unwrap().unwrap();

    assert_eq!(node.prompt.user, "hello");
    assert_eq!(node.response.text, "world");
}

/// Verifies explicit session reads fail instead of falling back to another session.
#[test]
fn fetch_snapshot_missing_session_returns_not_found_error() {
    let db = Arc::new(Mutex::new(Connection::open_in_memory().unwrap()));
    {
        let conn = db.lock().unwrap();
        schema::init_schema(&conn).unwrap();
    }

    let error = match fetch_snapshot(&db, Some("missing-session".to_string())) {
        Ok(_) => panic!("missing session should not fall back to another snapshot"),
        Err(error) => error,
    };

    assert!(matches!(error, rusqlite::Error::QueryReturnedNoRows));
}

/// Verifies traffic without an active session creates a fresh target and names it.
#[test]
fn insert_without_active_session_creates_and_names_fresh_session() {
    let db = Arc::new(Mutex::new(Connection::open_in_memory().unwrap()));
    let original_session_id = {
        let conn = db.lock().unwrap();
        schema::init_schema(&conn).unwrap();
        sessions::ensure_current_session(&conn).unwrap().id
    };

    let created_session_id = store_insert::insert_trace_row(
        &db,
        trace_row(
            "new-call",
            "Summarize the quarterly roadmap before standup starts",
        ),
        "success",
        None,
    )
    .unwrap();

    assert_ne!(created_session_id, original_session_id);

    let conn = db.lock().unwrap();
    let name: String = conn
        .query_row(
            "SELECT name FROM sessions WHERE id = ?1",
            [created_session_id.as_str()],
            |row| row.get(0),
        )
        .unwrap();
    let call_count: i64 = conn
        .query_row(
            "SELECT COUNT(*) FROM trace_calls WHERE session_id = ?1",
            [created_session_id.as_str()],
            |row| row.get(0),
        )
        .unwrap();

    assert_eq!(name, "Summarize the quarterly roadmap before standup…");
    assert_eq!(call_count, 1);
}

/// Verifies the session-list DTO reports the app-level active session, not newest.
#[test]
fn fetch_sessions_reports_active_session_id() {
    let db = Arc::new(Mutex::new(Connection::open_in_memory().unwrap()));
    let older_id = {
        let conn = db.lock().unwrap();
        schema::init_schema(&conn).unwrap();
        let older = sessions::create_session(&conn, Some("Older")).unwrap();
        sessions::create_session(&conn, Some("Newer")).unwrap();
        older.id
    };

    let list = fetch_sessions(&db, Some(older_id.clone())).unwrap();

    assert_eq!(list.current_session_id.as_deref(), Some(older_id.as_str()));
    assert_eq!(list.sessions.len(), 2);
}

/// Inserts one complete trace row for query-path tests.
fn insert_row(
    conn: &Connection,
    session_id: &str,
    id: &str,
    created_at: i64,
    latency_ms: i64,
    cache_status: &str,
) {
    conn.execute(
        "INSERT INTO trace_calls
            (id, session_id, created_at, provider, method, path, model, status_code,
             cache_status, latency_ms, request_id, prompt_system, prompt_user,
             response_text, response_language, tokens_in, tokens_out, cost)
         VALUES (?1, ?2, ?3, 'openai', 'POST', '/v1/responses', 'gpt-5.5', 200,
                 ?4, ?5, 'req', '', 'hello', 'world', 'text', 3, 4, '$0.0001')",
        (id, session_id, created_at, cache_status, latency_ms),
    )
    .unwrap();
}

/// Builds one complete trace row for write-path tests.
fn trace_row(id: &str, prompt_user: &str) -> TraceRow {
    TraceRow {
        id: id.to_string(),
        created_at: 1_000,
        provider: "openai".to_string(),
        method: "POST".to_string(),
        path: "/v1/responses".to_string(),
        model: "gpt-5.5".to_string(),
        status_code: 200,
        cache_status: "miss".to_string(),
        latency_ms: 100,
        request_id: "req".to_string(),
        prompt_system: String::new(),
        prompt_user: prompt_user.to_string(),
        response_text: "world".to_string(),
        response_language: "text".to_string(),
        error_code: None,
        error_message: None,
        error_detail: None,
        tokens_in: 3,
        tokens_out: 4,
        cost: "$0.0001".to_string(),
        temperature: None,
        trace_id: String::new(),
        parent_span_id: None,
        tool_use_ids: "[]".to_string(),
        context_inputs: "{}".to_string(),
        input_hash: "input".to_string(),
        stale: false,
        request_body: Vec::new(),
        request_target: "https://api.openai.com/v1/responses".to_string(),
        tool_result_ids: Vec::new(),
    }
}
