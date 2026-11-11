import Foundation
import PiAgent
import PiAI

/// One conversation: its transcript in pi's JSON shape.
public struct Conversation: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var messages: [AgentMessage]

    public init(id: UUID = UUID(), title: String = "New chat", createdAt: Date = Date(), updatedAt: Date = Date(), messages: [AgentMessage] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }

    /// The last thing said, on one line, for the conversation list: the agent's last reply, else the user's last
    /// message.
    public static func preview(for messages: [AgentMessage], limit: Int = 200) -> String? {
        for message in messages.reversed() {
            let text: String
            switch message {
            // Replies are Markdown: the preview shows what they read as, without the syntax.
            case let .llm(.assistant(assistant)): text = plainText(markdown: assistant.text)
            case let .llm(.user(user)): text = contentText(user.content, separator: " ")
            default: continue
            }
            let line = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            guard !line.isEmpty else { continue }
            return line.count > limit ? String(line.prefix(limit)) + "…" : line
        }
        return nil
    }

    /// A title from the first user message.
    public static func title(for messages: [AgentMessage]) -> String? {
        for case let .llm(.user(user)) in messages {
            let text = contentText(user.content, separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let line = text.split(separator: "\n").first.map(String.init) ?? text
            return line.count > 60 ? String(line.prefix(60)) + "…" : line
        }
        return nil
    }
}

/// Markdown as the plain text it reads as.
func plainText(markdown: String) -> String {
    guard let attributed = try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) else { return markdown }
    return String(attributed.characters)
}

/// What the conversation list shows, without loading transcripts.
public struct ConversationSummary: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var updatedAt: Date
    /// The last message, for the row under the title; nil in indexes saved before previews.
    public var preview: String?

    public init(id: UUID, title: String, updatedAt: Date, preview: String? = nil) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
        self.preview = preview
    }
}

/// Conversations as JSON files in Application Support, outside the workspace the agent can touch.
public struct ConversationStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func appDefault() -> ConversationStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ConversationStore(directory: support.appendingPathComponent("Conversations", isDirectory: true))
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private var indexURL: URL {
        directory.appendingPathComponent("index.json")
    }

    // Dates encode losslessly (seconds since 2001), so a conversation reads back exactly as saved.
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    /// Newest first.
    public func list() -> [ConversationSummary] {
        guard let data = try? Data(contentsOf: indexURL),
              var summaries = try? Self.decoder.decode([ConversationSummary].self, from: data) else { return [] }
        // Entries saved before previews get one from their conversation, once.
        var backfilled = false
        for index in summaries.indices where summaries[index].preview == nil {
            guard let conversation = try? load(summaries[index].id), let preview = Conversation.preview(for: conversation.messages) else { continue }
            summaries[index].preview = preview
            backfilled = true
        }
        if backfilled, let data = try? Self.encoder.encode(summaries) {
            try? data.write(to: indexURL, options: .atomic)
        }
        return summaries.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func load(_ id: UUID) throws -> Conversation {
        try Self.decoder.decode(Conversation.self, from: Data(contentsOf: url(for: id)))
    }

    public func save(_ conversation: Conversation) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.encoder.encode(conversation).write(to: url(for: conversation.id), options: .atomic)
        var summaries = list().filter { $0.id != conversation.id }
        summaries.append(ConversationSummary(id: conversation.id, title: conversation.title, updatedAt: conversation.updatedAt, preview: Conversation.preview(for: conversation.messages)))
        try Self.encoder.encode(summaries).write(to: indexURL, options: .atomic)
    }

    public func delete(_ id: UUID) throws {
        try? FileManager.default.removeItem(at: url(for: id))
        let summaries = list().filter { $0.id != id }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.encoder.encode(summaries).write(to: indexURL, options: .atomic)
    }
}
