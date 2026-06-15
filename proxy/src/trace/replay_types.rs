//! DTOs and persistence values for replay endpoints.

use serde::{Deserialize, Serialize};

use super::summarize::ResponseSummary;

#[derive(Deserialize)]
pub(super) struct EditOutputRequest {
    pub(super) output: String,
}

#[derive(Serialize)]
pub(super) struct InvalidationResult {
    pub(super) node_id: String,
    pub(super) invalidated: Vec<String>,
}

#[derive(Serialize)]
pub(super) struct DownstreamResult {
    pub(super) node_id: String,
    pub(super) downstream: Vec<String>,
}

#[derive(Serialize)]
pub(super) struct ReplayResult {
    pub(super) node_id: String,
    pub(super) status_code: u16,
    pub(super) cost: String,
    pub(super) tokens_in: i64,
    pub(super) tokens_out: i64,
    pub(super) invalidated: Vec<String>,
}

pub(super) struct ReplaySpec {
    pub(super) method: String,
    pub(super) provider: String,
    pub(super) target: String,
    pub(super) model: String,
    pub(super) session_id: String,
    pub(super) body: Vec<u8>,
}

pub(super) struct ReplayUpdate {
    pub(super) node_id: String,
    pub(super) session_id: String,
    pub(super) status_code: u16,
    pub(super) latency_ms: i64,
    pub(super) cost: String,
    pub(super) request_id: String,
    pub(super) response_text: String,
    pub(super) response_language: String,
    pub(super) tokens_in: i64,
    pub(super) tokens_out: i64,
    pub(super) tool_use_ids: String,
}

impl ReplayUpdate {
    /// Builds a database update payload from replay response summary fields.
    pub(super) fn from_summary(
        node_id: String,
        session_id: String,
        status_code: u16,
        latency_ms: i64,
        cost: String,
        request_id: String,
        summary: ResponseSummary,
    ) -> Self {
        let tool_use_ids =
            serde_json::to_string(&summary.tool_use_ids).unwrap_or_else(|_| "[]".to_string());

        Self {
            node_id,
            session_id,
            status_code,
            latency_ms,
            cost,
            request_id,
            response_text: summary.text,
            response_language: summary.language,
            tokens_in: summary.tokens_in,
            tokens_out: summary.tokens_out,
            tool_use_ids,
        }
    }
}
