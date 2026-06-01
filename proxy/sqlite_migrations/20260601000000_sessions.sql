CREATE TABLE IF NOT EXISTS sessions (
    id         TEXT PRIMARY KEY,
    created_at INTEGER NOT NULL,
    name       TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_created_at
    ON sessions(created_at);

CREATE TABLE IF NOT EXISTS trace_calls (
    id                TEXT PRIMARY KEY,
    session_id        TEXT,
    created_at        INTEGER NOT NULL,
    provider          TEXT NOT NULL,
    method            TEXT NOT NULL,
    path              TEXT NOT NULL,
    model             TEXT NOT NULL DEFAULT '-',
    status_code       INTEGER NOT NULL,
    cache_status      TEXT NOT NULL,
    latency_ms        INTEGER NOT NULL,
    request_id        TEXT NOT NULL DEFAULT '-',
    prompt_system     TEXT NOT NULL DEFAULT '',
    prompt_user       TEXT NOT NULL DEFAULT '',
    response_text     TEXT NOT NULL DEFAULT '',
    response_language TEXT NOT NULL DEFAULT 'text',
    error_code        TEXT,
    error_message     TEXT,
    error_detail      TEXT,
    tokens_in         INTEGER NOT NULL DEFAULT 0,
    tokens_out        INTEGER NOT NULL DEFAULT 0,
    cost              TEXT NOT NULL DEFAULT '$0.0000',
    temperature       REAL
);

CREATE INDEX IF NOT EXISTS idx_trace_calls_created_at
    ON trace_calls(created_at);

CREATE INDEX IF NOT EXISTS idx_trace_calls_session_created_at
    ON trace_calls(session_id, created_at);
