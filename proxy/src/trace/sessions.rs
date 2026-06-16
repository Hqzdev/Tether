//! Session lifecycle: resolve the current session, look sessions up, create
//! them, rename them from the first prompt, and soft-delete them.

use rusqlite::{Connection, OptionalExtension, params};
use uuid::Uuid;

use tether_domain::TraceSessionDto;

use super::text::{format_time_for_name, format_timestamp, now_millis, session_name_from_prompt};

/// Returns the most recent live session, creating a "Live Session" if none exist.
pub(super) fn ensure_current_session(conn: &Connection) -> rusqlite::Result<TraceSessionDto> {
    if let Some(session) = latest_session(conn)? {
        return Ok(session);
    }

    create_session(conn, Some("Live Session"))
}

/// Resolves where new traffic should land: the client's active session when it
/// still exists and is live, otherwise a fresh session for this new traffic.
pub(super) fn resolve_target_session(
    conn: &Connection,
    active_session_id: Option<&str>,
) -> rusqlite::Result<TraceSessionDto> {
    if let Some(id) = active_session_id
        && let Some(session) = find_session(conn, id)?
    {
        return Ok(session);
    }

    create_session(conn, Some("Live Session"))
}

/// The newest live session by creation time, or `None` when none exist.
pub(super) fn latest_session(conn: &Connection) -> rusqlite::Result<Option<TraceSessionDto>> {
    conn.query_row(
        "SELECT id, created_at, name
         FROM sessions
         WHERE deleted_at IS NULL
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

/// Looks up a live (non-deleted) session by id.
pub(super) fn find_session(
    conn: &Connection,
    id: &str,
) -> rusqlite::Result<Option<TraceSessionDto>> {
    conn.query_row(
        "SELECT id, created_at, name
         FROM sessions
         WHERE id = ?1 AND deleted_at IS NULL",
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

/// Creates a new session, defaulting its name to the current `HH:MM` time.
pub(super) fn create_session(
    conn: &Connection,
    name: Option<&str>,
) -> rusqlite::Result<TraceSessionDto> {
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

/// Renames a live session and stamps `updated_at`. Returns the updated session,
/// or `None` when the id is unknown or already deleted.
pub(super) fn rename_session(
    conn: &Connection,
    id: &str,
    name: &str,
) -> rusqlite::Result<Option<TraceSessionDto>> {
    let affected = conn.execute(
        "UPDATE sessions
         SET name = ?1, updated_at = ?2
         WHERE id = ?3 AND deleted_at IS NULL",
        params![name, now_millis(), id],
    )?;
    if affected == 0 {
        return Ok(None);
    }

    find_session(conn, id)
}

/// Names a freshly created session after its first user prompt, leaving
/// user-chosen names untouched. Best-effort: a blank prompt is a no-op.
pub(super) fn name_session_from_prompt(
    conn: &Connection,
    id: &str,
    prompt_user: &str,
) -> rusqlite::Result<()> {
    let Some(name) = session_name_from_prompt(prompt_user) else {
        return Ok(());
    };

    // Only overwrite the auto-generated placeholder names so an explicit rename
    // performed before the first call survives.
    conn.execute(
        "UPDATE sessions
         SET name = ?1, updated_at = ?2
         WHERE id = ?3
           AND deleted_at IS NULL
           AND (name = 'Live Session' OR name LIKE 'Session %')",
        params![name, now_millis(), id],
    )?;
    Ok(())
}

/// Soft-deletes a session by stamping `deleted_at`. Returns whether a live
/// session was actually marked deleted.
pub(super) fn soft_delete_session(conn: &Connection, id: &str) -> rusqlite::Result<bool> {
    let affected = conn.execute(
        "UPDATE sessions
         SET deleted_at = ?1
         WHERE id = ?2 AND deleted_at IS NULL",
        params![now_millis(), id],
    )?;
    Ok(affected > 0)
}

/// Counts the trace calls already recorded against a session.
pub(super) fn session_call_count(conn: &Connection, id: &str) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM trace_calls WHERE session_id = ?1",
        [id],
        |row| row.get(0),
    )
}

/// Assigns the current session to any legacy rows missing a `session_id`.
pub(super) fn backfill_missing_session_ids(conn: &Connection) -> rusqlite::Result<()> {
    let missing_count: i64 = conn.query_row(
        "SELECT COUNT(*) FROM trace_calls WHERE session_id IS NULL OR session_id = ''",
        [],
        |row| row.get(0),
    )?;
    if missing_count == 0 {
        return Ok(());
    }

    let session = ensure_current_session(conn)?;
    conn.execute(
        "UPDATE trace_calls
         SET session_id = ?1
         WHERE session_id IS NULL OR session_id = ''",
        [session.id],
    )?;
    Ok(())
}

/// Converts a persisted session row into the UI-facing session DTO.
///
/// `call_count` is left at 0 here; the session-list endpoint populates the real
/// count. `name` mirrors `title` for the session-history client.
pub(super) fn session_to_dto(id: String, created_at: i64, name: String) -> TraceSessionDto {
    TraceSessionDto {
        id,
        title: name.clone(),
        name,
        trigger: "AgentTrace proxy".to_string(),
        started_at: format_timestamp(created_at),
        created_at,
        call_count: 0,
    }
}
