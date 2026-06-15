import Foundation

extension CodexLogObserver {
    /// Loads the newest non-archived Codex thread from the state database.
    nonisolated static func latestThread(from databasePath: String) throws -> CodexThreadRow? {
        let query = """
        SELECT
            id,
            NULLIF(title, '') AS title,
            NULLIF(first_user_message, '') AS first_user_message,
            NULLIF(preview, '') AS preview,
            NULLIF(model, '') AS model,
            NULLIF(model_provider, '') AS model_provider,
            NULLIF(source, '') AS source,
            created_at,
            updated_at
        FROM threads
        WHERE archived = 0
        ORDER BY updated_at_ms DESC, updated_at DESC
        LIMIT 1;
        """

        return try CodexDatabase.runJSON(databasePath: databasePath, query: query, as: [CodexThreadRow].self).first
    }

    /// Loads recent Codex response websocket events for a thread.
    nonisolated static func responseEvents(
        for threadId: String,
        from databasePath: String,
        afterLogId baselineLogId: Int?
    ) throws -> [CodexResponseEventRow] {
        let baselineClause = baselineLogId.map { "AND id > \($0)" } ?? ""
        let query = """
        WITH raw_events AS (
            SELECT
                id,
                ts,
                substr(
                    feedback_log_body,
                    instr(feedback_log_body, 'websocket event: ') + length('websocket event: ')
                ) AS body
            FROM logs
            WHERE thread_id = \(sqlQuote(threadId))
              \(baselineClause)
              AND feedback_log_body LIKE '%websocket event: {"type":"response.%'
              AND json_valid(substr(
                    feedback_log_body,
                    instr(feedback_log_body, 'websocket event: ') + length('websocket event: ')
              ))
            ORDER BY id DESC
            LIMIT 1000
        ),
        parsed_events AS (
            SELECT
                id,
                ts,
                json_extract(body, '$.type') AS event_type,
                json_extract(body, '$.response.id') AS response_id,
                json_extract(body, '$.response.model') AS model,
                json_extract(body, '$.response.status') AS response_status,
                json_extract(body, '$.response.created_at') AS response_created_at,
                json_extract(body, '$.response.completed_at') AS response_completed_at,
                json_extract(body, '$.response.usage.input_tokens') AS input_tokens,
                json_extract(body, '$.response.usage.output_tokens') AS output_tokens,
                json_extract(body, '$.response.error.message') AS error_message,
                json_extract(body, '$.text') AS output_text,
                json_extract(body, '$.item.type') AS item_type,
                json_extract(body, '$.item.id') AS item_id,
                json_extract(body, '$.item.name') AS item_name,
                json_extract(body, '$.item.arguments') AS item_arguments,
                json_extract(body, '$.item.content[0].text') AS item_text
            FROM raw_events
        )
        SELECT *
        FROM parsed_events
        WHERE event_type IN (
            'response.created',
            'response.output_text.done',
            'response.output_item.done',
            'response.completed'
        )
        ORDER BY id ASC;
        """

        return try CodexDatabase.runJSON(databasePath: databasePath, query: query, as: [CodexResponseEventRow].self)
    }

    /// Loads the newest Codex response event id from the feedback log database.
    nonisolated static func latestResponseLogId(from databasePath: String) throws -> Int? {
        let query = """
        SELECT id
        FROM logs
        WHERE feedback_log_body LIKE '%websocket event: {"type":"response.%'
        ORDER BY id DESC
        LIMIT 1;
        """

        return try CodexDatabase.runJSON(databasePath: databasePath, query: query, as: [CodexLogWatermarkRow].self).first?.id
    }
}
