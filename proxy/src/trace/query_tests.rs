//! Tests for trace snapshot query assembly.

use std::sync::{Arc, Mutex};

use rusqlite::Connection;

use super::{query::fetch_snapshot, schema, sessions};

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
