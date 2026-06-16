//! Async trace ingestion: the proxy hot path enqueues captured outcomes while
//! a background worker performs blocking SQLite persistence.

use std::sync::{Arc, Mutex};

use rusqlite::Connection;
use tokio::sync::mpsc;

use super::capture::TraceCapture;
use super::store::{record_response, record_upstream_error};

/// Default bounded channel size for in-process trace ingestion.
pub(crate) const DEFAULT_TRACE_CHANNEL_CAPACITY: usize = 1_024;

/// Shared handle to the session new traffic is currently being routed into.
/// `None` means "fall back to the most recent session".
pub(crate) type ActiveSession = Arc<Mutex<Option<String>>>;

/// Non-blocking sink used by the proxy path to hand trace work to the worker.
#[derive(Clone)]
pub(crate) struct TraceSink {
    tx: mpsc::Sender<TraceEvent>,
}

/// Owned response outcome queued after an upstream or cache response completes.
pub(crate) struct TraceResponse {
    pub(crate) status_code: u16,
    pub(crate) content_type: String,
    pub(crate) header_request_id: Option<String>,
    pub(crate) body: Vec<u8>,
    pub(crate) cache_status: &'static str,
    pub(crate) latency_ms: i64,
}

impl TraceSink {
    /// Creates a bounded sink plus the receiver consumed by the ingestion worker.
    pub(crate) fn bounded(capacity: usize) -> (Self, mpsc::Receiver<TraceEvent>) {
        let (tx, rx) = mpsc::channel(capacity);
        (Self { tx }, rx)
    }

    /// Enqueues a completed upstream or cached response without awaiting SQLite.
    pub(crate) fn record_response(&self, capture: TraceCapture, response: TraceResponse) {
        self.enqueue(TraceEvent::Response { capture, response }, "trace response");
    }

    /// Enqueues a network or stream failure without blocking the caller.
    pub(crate) fn record_upstream_error(
        &self,
        capture: TraceCapture,
        message: String,
        latency_ms: i64,
    ) {
        self.enqueue(
            TraceEvent::UpstreamError {
                capture,
                message,
                latency_ms,
            },
            "trace error",
        );
    }

    /// Drops trace events on overload; forwarding must never wait for tracing.
    fn enqueue(&self, event: TraceEvent, label: &str) {
        if let Err(error) = self.tx.try_send(event) {
            eprintln!("  dropped {label}: trace ingestion channel {error}");
        }
    }
}

/// Spawns the background task that persists trace events in receive order.
pub(crate) fn spawn_ingest_worker(
    db: Arc<Mutex<Connection>>,
    active_session: ActiveSession,
    mut rx: mpsc::Receiver<TraceEvent>,
) -> tokio::task::JoinHandle<()> {
    tokio::spawn(async move {
        while let Some(event) = rx.recv().await {
            let db = db.clone();
            // Snapshot the active session per event so a mid-stream switch routes
            // the next call without blocking the persistence worker on the lock.
            let active = active_session.lock().ok().and_then(|guard| guard.clone());
            let active_snapshot = active.clone();
            match tokio::task::spawn_blocking(move || event.persist(&db, active.as_deref())).await {
                Ok(Some(persisted_session_id)) => {
                    if let Ok(mut guard) = active_session.lock()
                        && *guard == active_snapshot
                    {
                        *guard = Some(persisted_session_id);
                    }
                }
                Ok(None) => {}
                Err(error) => eprintln!("  trace ingestion worker failed: {error}"),
            }
        }
    })
}

/// An owned trace persistence command sent across the bounded channel.
pub(crate) enum TraceEvent {
    Response {
        capture: TraceCapture,
        response: TraceResponse,
    },
    UpstreamError {
        capture: TraceCapture,
        message: String,
        latency_ms: i64,
    },
}

impl TraceEvent {
    /// Persists one queued event using the existing blocking store functions,
    /// routing it into `active_session` when one is set.
    fn persist(self, db: &Arc<Mutex<Connection>>, active_session: Option<&str>) -> Option<String> {
        match self {
            Self::Response { capture, response } => {
                record_response(db, &capture, &response, active_session)
            }
            Self::UpstreamError {
                capture,
                message,
                latency_ms,
            } => record_upstream_error(db, &capture, &message, latency_ms, active_session),
        }
    }
}
