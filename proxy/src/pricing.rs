//! Static, best-effort price table for estimating per-call cost from token
//! usage. Prices are USD per 1M tokens and are intentionally approximate —
//! they exist to give the trace UI a believable cost figure instead of a
//! hardcoded `$0.0000`. Update the table as provider pricing changes.

/// (input_per_mtok, output_per_mtok) in USD.
struct Price {
    input: f64,
    output: f64,
}

/// Longest matching prefix wins (see `estimate_cost`), so ordering here does
/// not affect correctness — entries are grouped by family for readability.
const TABLE: &[(&str, Price)] = &[
    // ---- Anthropic ----
    ("claude-opus-4", Price { input: 15.0, output: 75.0 }),
    ("claude-sonnet-4", Price { input: 3.0, output: 15.0 }),
    ("claude-haiku-4", Price { input: 1.0, output: 5.0 }),
    ("claude-3-5-haiku", Price { input: 0.80, output: 4.0 }),
    ("claude-3-5-sonnet", Price { input: 3.0, output: 15.0 }),
    ("claude-3-opus", Price { input: 15.0, output: 75.0 }),
    ("claude-3-haiku", Price { input: 0.25, output: 1.25 }),
    ("claude-", Price { input: 3.0, output: 15.0 }),
    // ---- OpenAI ----
    ("gpt-4o-mini", Price { input: 0.15, output: 0.60 }),
    ("gpt-4o", Price { input: 2.50, output: 10.0 }),
    ("gpt-4.1-mini", Price { input: 0.40, output: 1.60 }),
    ("gpt-4.1-nano", Price { input: 0.10, output: 0.40 }),
    ("gpt-4.1", Price { input: 2.0, output: 8.0 }),
    ("o4-mini", Price { input: 1.10, output: 4.40 }),
    ("o3-mini", Price { input: 1.10, output: 4.40 }),
    ("o3", Price { input: 2.0, output: 8.0 }),
    ("o1-mini", Price { input: 1.10, output: 4.40 }),
    ("o1", Price { input: 15.0, output: 60.0 }),
    ("gpt-5.5", Price { input: 2.0, output: 8.0 }),
    ("gpt-5", Price { input: 2.0, output: 8.0 }),
    ("gpt-4-turbo", Price { input: 10.0, output: 30.0 }),
    ("gpt-4", Price { input: 30.0, output: 60.0 }),
    ("gpt-3.5", Price { input: 0.50, output: 1.50 }),
    ("gpt-", Price { input: 2.50, output: 10.0 }),
];

/// Estimate a formatted dollar cost for a call. Returns `$0.0000` when the
/// model is unknown or no tokens were reported (e.g. streamed errors).
pub(crate) fn estimate_cost(model: &str, tokens_in: i64, tokens_out: i64) -> String {
    if tokens_in <= 0 && tokens_out <= 0 {
        return "$0.0000".to_string();
    }

    let needle = model.trim().to_ascii_lowercase();
    let price = TABLE
        .iter()
        .filter(|(prefix, _)| needle.starts_with(prefix))
        .max_by_key(|(prefix, _)| prefix.len())
        .map(|(_, price)| price);

    let Some(price) = price else {
        return "$0.0000".to_string();
    };

    let dollars = (tokens_in.max(0) as f64) / 1_000_000.0 * price.input
        + (tokens_out.max(0) as f64) / 1_000_000.0 * price.output;

    format!("${dollars:.4}")
}
