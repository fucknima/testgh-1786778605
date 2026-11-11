import Foundation
import PiAgent
import PiAI

/// One message of a conversation as the chat shows it: what the user sent, one agent response (its text with its
/// thinking and tool calls), or a notice such as an error. The chat screen maps these to chat kit messages.
public struct ChatEntry: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case user
        case agent
        case notice
    }

    public var id: String
    public var kind: Kind
    public var text: String?
    public var thinking: [String]
    public var toolCalls: [ToolCallItem]
    public var timestamp: Date
    /// A user message the agent hasn't taken in yet.
    public var isSending: Bool
    /// An agent response still streaming.
    public var isStreaming: Bool
    /// A notice for a failed response, which can be retried.
    public var isError: Bool
}

public struct ToolCallItem: Hashable, Sendable {
    public enum Status: Hashable, Sendable {
        /// The model is still writing the arguments.
        case preparing
        case running
        case succeeded
        case failed
        /// The run ended before the tool reported a result.
        case interrupted
    }

    public var id: String
    public var name: String
    /// What the call works on, such as the path a file tool uses.
    public var summary: String
    public var arguments: JSONObject
    public var status: Status
    public var output: String?

    /// "Read notes.md"
    public var title: String {
        let verb = switch name {
        case "read": "Read"
        case "write": "Write"
        case "edit": "Edit"
        case "ls": "List"
        case "find": "Find"
        case "grep": "Search"
        case "web_search": "Search the web for"
        case "web_fetch": "Fetch"
        case "javascript": "Run JavaScript"
        default: name
        }
        return summary.isEmpty ? verb : "\(verb) \(summary)"
    }
}

/// The entries for a transcript, the response streaming now, and the messages still queued.
public func chatEntries(messages: [AgentMessage], streaming: AssistantMessage?, runningToolCalls: Set<String>, isRunning: Bool, queued: [QueuedMessage] = []) -> [ChatEntry] {
    var results: [String: ToolResultMessage] = [:]
    for case let .llm(.toolResult(result)) in messages {
        results[result.toolCallId] = result
    }

    var entries: [ChatEntry] = []
    func date(_ timestamp: Timestamp) -> Date {
        Date(timeIntervalSince1970: Double(timestamp) / 1000)
    }

    func appendAssistant(_ message: AssistantMessage, id: String, streaming: Bool) {
        var thinking: [String] = []
        var texts: [String] = []
        var toolCalls: [ToolCallItem] = []
        for block in message.content {
            switch block {
            case let .thinking(block):
                let text = block.thinking.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { thinking.append(text) }
            case let .text(block):
                let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { texts.append(text) }
            case let .toolCall(call):
                let result = results[call.id]
                let status: ToolCallItem.Status = if let result {
                    result.isError ? .failed : .succeeded
                } else if streaming {
                    .preparing
                } else if runningToolCalls.contains(call.id) || isRunning {
                    .running
                } else {
                    .interrupted
                }
                toolCalls.append(ToolCallItem(
                    id: call.id,
                    name: call.name,
                    summary: toolSummary(name: call.name, arguments: call.arguments),
                    arguments: call.arguments,
                    status: status,
                    output: result.map { contentText($0.content) }
                ))
            }
        }
        if !thinking.isEmpty || !texts.isEmpty || !toolCalls.isEmpty {
            entries.append(ChatEntry(
                id: id,
                kind: .agent,
                text: texts.isEmpty ? nil : texts.joined(separator: "\n\n"),
                thinking: thinking,
                toolCalls: toolCalls,
                timestamp: date(message.timestamp),
                isSending: false,
                isStreaming: streaming,
                isError: false
            ))
        }
        if message.stopReason == .error {
            entries.append(ChatEntry(id: id + "-error", kind: .notice, text: message.errorMessage ?? "The response failed.", thinking: [], toolCalls: [], timestamp: date(message.timestamp), isSending: false, isStreaming: false, isError: true))
        } else if message.stopReason == .aborted {
            entries.append(ChatEntry(id: id + "-stopped", kind: .notice, text: "Stopped", thinking: [], toolCalls: [], timestamp: date(message.timestamp), isSending: false, isStreaming: false, isError: false))
        }
    }

    for (index, message) in messages.enumerated() {
        switch message {
        case let .llm(.user(user)):
            let text = contentText(user.content).trimmingCharacters(in: .whitespacesAndNewlines)
            entries.append(ChatEntry(id: "u\(index)-\(user.timestamp)", kind: .user, text: text, thinking: [], toolCalls: [], timestamp: date(user.timestamp), isSending: false, isStreaming: false, isError: false))
        case let .llm(.assistant(assistant)):
            appendAssistant(assistant, id: "a\(index)-\(assistant.timestamp)", streaming: false)
        default:
            break
        }
    }
    if let streaming {
        appendAssistant(streaming, id: "a\(messages.count)-\(streaming.timestamp)", streaming: true)
    }
    for message in queued {
        entries.append(ChatEntry(id: "q-\(message.id)", kind: .user, text: message.text, thinking: [], toolCalls: [], timestamp: message.date, isSending: true, isStreaming: false, isError: false))
    }
    return entries
}

/// A message the user sent that the agent hasn't taken in yet: a new prompt about to start, or one steering a run
/// that waits for the current tool calls.
public struct QueuedMessage: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let text: String
    public let date: Date

    public init(id: UUID = UUID(), text: String, date: Date = Date()) {
        self.id = id
        self.text = text
        self.date = date
    }
}

/// What a tool call works on, in a few words.
public func toolSummary(name: String, arguments: JSONObject) -> String {
    switch name {
    case "read", "write", "edit": arguments["path"]?.stringValue ?? ""
    // The workspace root needs no name: "List", not "List .".
    case "ls": arguments["path"]?.stringValue.flatMap { [".", "./", ""].contains($0) ? nil : $0 } ?? ""
    case "find": arguments["pattern"]?.stringValue ?? ""
    case "grep": [arguments["pattern"]?.stringValue, arguments["path"]?.stringValue].compactMap(\.self).joined(separator: " in ")
    case "web_search": arguments["query"]?.stringValue ?? ""
    // The host and path read better than the whole URL.
    case "web_fetch": arguments["url"]?.stringValue.map { raw in
            guard let url = URL(string: raw), let host = url.host() else { return raw }
            return host + (url.path() == "/" ? "" : url.path())
        } ?? ""
    // The code is the call's content, not its name; the result shows below.
    case "javascript": ""
    default: arguments.keys.sorted().first.flatMap { arguments[$0]?.stringValue } ?? ""
    }
}
