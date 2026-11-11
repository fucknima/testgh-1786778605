import Foundation
import PiAgent
import PiAI
import PiTools
import SQLite3

/// Reads rows from a SQLite database. The database is opened read-only, so the agent can inspect an app's data
/// without changing it.
public func sqliteTool(workspace: Workspace) -> AgentTool {
    let defaultLimit = 100
    let maximumLimit = 500
    let maximumBytes = 64 * 1024
    return AgentTool(
        name: "sqlite",
        label: "Query database",
        description: "Query a SQLite database. The file is opened read-only, so only read-only statements run. Omit query to list tables and views. Returns rows as JSON. Output is limited to \(defaultLimit) rows and \(maximumBytes / 1024)KB.",
        parameters: [
            "type": "object",
            "properties": .object([
                "path": ["type": "string", "description": .string("Path to the database file (workspace or /apps/… or /app-groups/…)")],
                "query": ["type": "string", "description": .string("One read-only SQL statement (SELECT, WITH, PRAGMA, EXPLAIN). Omit it to list tables and views.")],
                "limit": ["type": "number", "description": .string("Maximum rows to return (default \(defaultLimit), at most \(maximumLimit))")],
            ]),
            "required": .array(["path"]),
        ]
    ) { _, arguments, _ in
        let path = arguments["path"]?.stringValue ?? ""
        let url = try workspace.resolve(path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw WorkspaceError("File not found: \(path)")
        }
        guard !isDirectory.boolValue else { throw WorkspaceError("\(path) is a directory. Use ls to find the database file.") }

        let limit = min(max(1, arguments["limit"]?.intValue ?? defaultLimit), maximumLimit)
        let query = (arguments["query"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let result = try readDatabase(at: url, query: query.isEmpty ? nil : query, limit: limit, maximumBytes: maximumBytes)

        let data = try JSONSerialization.data(withJSONObject: result.rows, options: [.sortedKeys, .withoutEscapingSlashes])
        var output = "\(result.rows.count) row(s)\n\(String(decoding: data, as: UTF8.self))"
        if result.truncated {
            output += "\n\n[Truncated to \(limit) rows or \(maximumBytes / 1024)KB. Narrow the query or raise limit.]"
        }
        return AgentToolResult(text: output)
    }
}

private struct DatabaseRows {
    var rows: [[String: Any]]
    var truncated: Bool
}

/// Opens a database read-only and runs one statement. Falls back to SQLite's immutable mode for a WAL database whose
/// sidecar files can't be opened.
private func readDatabase(at url: URL, query: String?, limit: Int, maximumBytes: Int) throws -> DatabaseRows {
    let budget = QueryBudget(maximumSteps: 2_000_000)
    var database: OpaquePointer?
    defer { sqlite3_close(database) }

    var code = sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil)
    if code != SQLITE_OK {
        sqlite3_close(database)
        database = nil
        code = sqlite3_open_v2(url.absoluteString + "?immutable=1", &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil)
    }
    guard code == SQLITE_OK, let database else {
        throw WorkspaceError("Couldn't open \(url.lastPathComponent) as a SQLite database.")
    }

    sqlite3_busy_timeout(database, 1_000)
    // Even a read-only connection can run statements that change the file unless it is told not to.
    if sqlite3_exec(database, "PRAGMA query_only = 1", nil, nil, nil) != SQLITE_OK {
        throw WorkspaceError("Couldn't make \(url.lastPathComponent) read-only: \(sqliteError(database))")
    }

    sqlite3_progress_handler(database, 1_000, sqliteProgress, Unmanaged.passUnretained(budget).toOpaque())
    var statement: OpaquePointer?
    var tail: UnsafePointer<CChar>?
    let sql = query ?? "SELECT name, type FROM sqlite_master WHERE type IN ('table', 'view') ORDER BY name"
    let prepare = sqlite3_prepare_v2(database, sql, -1, &statement, &tail)
    guard prepare == SQLITE_OK, let statement else {
        throw WorkspaceError("SQLite error: \(sqliteError(database))")
    }
    defer { sqlite3_finalize(statement) }

    if let tail, !String(cString: tail).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw WorkspaceError("Only one statement can run at a time.")
    }

    guard sqlite3_stmt_readonly(statement) != 0 else {
        throw WorkspaceError("Only read-only statements are allowed. \(url.lastPathComponent) was opened read-only.")
    }

    var rows: [[String: Any]] = []
    var names: [String] = []
    var bytes = 0
    var truncated = false

    while true {
        let step = sqlite3_step(statement)
        if step == SQLITE_ROW {
            if rows.count >= limit {
                truncated = true
                break
            }
            let row = readRow(statement, names: &names, maximumValueBytes: 2_048)
            let rowBytes = row.reduce(0) { $0 + (($1.value as? String)?.utf8.count ?? 8) }
            if bytes + rowBytes > maximumBytes {
                truncated = true
                break
            }
            bytes += rowBytes
            rows.append(row)
        } else if step == SQLITE_DONE {
            break
        } else if step == SQLITE_INTERRUPT {
            throw WorkspaceError("The query took too long and was stopped.")
        } else {
            throw WorkspaceError("SQLite error: \(sqliteError(database))")
        }
    }

    return DatabaseRows(rows: rows, truncated: truncated)
}

/// One result row. Duplicate and empty column names get a stable suffix.
private func readRow(_ statement: OpaquePointer, names: inout [String], maximumValueBytes: Int) -> [String: Any] {
    var row: [String: Any] = [:]
    let count = Int(sqlite3_column_count(statement))
    if names.isEmpty {
        var used: Set<String> = []
        for index in 0 ..< Int32(count) {
            let raw = sqlite3_column_name(statement, index).map { String(cString: $0) } ?? ""
            var name = raw.isEmpty ? "column\(Int(index) + 1)" : raw
            var suffix = 2
            while used.contains(name) {
                name = "\(raw.isEmpty ? "column" : raw)_\(suffix)"
                suffix += 1
            }
            used.insert(name)
            names.append(name)
        }
    }

    for index in 0 ..< Int32(min(count, names.count)) {
        let value: Any
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER:
            value = sqlite3_column_int64(statement, index)
        case SQLITE_FLOAT:
            value = sqlite3_column_double(statement, index)
        case SQLITE_TEXT:
            if let text = sqlite3_column_text(statement, index) {
                let length = Int(sqlite3_column_bytes(statement, index))
                let buffer = UnsafeBufferPointer<UInt8>(start: text, count: length)
                var string = String(decoding: buffer, as: UTF8.self)
                if string.utf8.count > maximumValueBytes {
                    string = String(string.prefix(maximumValueBytes / 4)) + "…[truncated]"
                }
                value = string
            } else {
                value = ""
            }
        case SQLITE_BLOB:
            value = "<blob \(sqlite3_column_bytes(statement, index)) bytes>"
        default:
            value = NSNull()
        }
        row[names[Int(index)]] = value
    }
    return row
}

/// Stops a statement that runs away, such as a cartesian join.
private final class QueryBudget {
    var steps = 0
    let maximumSteps: Int

    init(maximumSteps: Int) {
        self.maximumSteps = maximumSteps
    }
}

private func sqliteProgress(_ context: UnsafeMutableRawPointer?) -> Int32 {
    guard let context else { return 1 }
    let budget = Unmanaged<QueryBudget>.fromOpaque(context).takeUnretainedValue()
    budget.steps += 1
    return budget.steps > budget.maximumSteps ? 1 : 0
}

private func sqliteError(_ database: OpaquePointer) -> String {
    sqlite3_errmsg(database).map { String(cString: $0) } ?? "Unknown SQLite error"
}
