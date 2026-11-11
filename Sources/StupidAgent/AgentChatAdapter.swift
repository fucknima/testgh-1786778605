// The app is iOS-only; the guard lets `swift test` build the package on macOS for the core tests.
#if os(iOS)
import Foundation
import Observation
import StupidAgentCore
import StupidChatKit

extension ChatNetwork {
    static let agent = ChatNetwork(rawValue: "agent")
}

/// One agent conversation as a stupid chatkit chat: translates the session's entries to chat messages and sends
/// through the session. The session pushes changes, so there is no polling.
@MainActor
final class AgentChatAdapter: ChatAdapter, ChatLiveUpdating, ChatTyping, ChatButtonPressing, ChatComposerMenus, ChatStoppable {
    let session: AgentSession
    let app: AppModel
    /// Opens the list of every model the server has.
    let chooseModel: () -> Void
    let network = ChatNetwork.agent
    let canReply = false
    let acceptsAttachments = false
    let pollInterval: Duration? = nil
    var onChange: (() -> Void)?
    var onConnectionLost: ((Error?) -> Void)?
    var onError: ((Error) -> Void)?
    var onCatchUp: (() -> Void)?
    let reactions: [String: [ChatReaction]] = [:]
    let hasEarlierMessages = false
    private(set) var messages: [ChatMessage] = []
    private var following = false

    static let agentUser = ChatUser(id: "agent", name: "stupid agent", avatarURL: nil)
    static let user = ChatUser(id: "you", name: "You", avatarURL: nil)
    static let system = ChatUser(id: "system", name: nil, avatarURL: nil, isSystem: true)
    static let retryButton = ChatMessageButton(id: "retry", title: "Retry", action: .press)

    init(session: AgentSession, app: AppModel, chooseModel: @escaping () -> Void) {
        self.session = session
        self.app = app
        self.chooseModel = chooseModel
        refresh()
    }

    var key: String { "agent:\(session.conversation.id.uuidString)" }

    var info: ChatInfo {
        ChatInfo(title: session.conversation.title, subtitle: app.settings.modelId, showsSenderNames: false)
    }

    private static let chooseItemId = "choose"
    private static let modelItemPrefix = "model:"

    /// The model the agent answers with: the recent ones, then the server's full list.
    var composerMenu: ChatComposerMenu? {
        let settings = app.settings
        guard !settings.modelId.isEmpty else { return nil }
        let models = settings.menuModelIds.map { id in
            let name = shortModelName(id)
            return ChatComposerMenuItem(id: Self.modelItemPrefix + id, title: name, subtitle: name == id ? nil : id, isSelected: id == settings.modelId)
        }
        let choose = ChatComposerMenuItem(id: Self.chooseItemId, title: "Choose Model…", systemImage: "magnifyingglass")
        // A brain at the end of the text row; the menu is headed by the full model id.
        return ChatComposerMenu(title: settings.modelId, accessibilityLabel: "Model", systemImage: "brain", sections: [models, [choose]])
    }

    func selectComposerMenuItem(_ itemId: String) {
        if itemId == Self.chooseItemId {
            chooseModel()
        } else if itemId.hasPrefix(Self.modelItemPrefix) {
            do {
                try app.selectModel(String(itemId.dropFirst(Self.modelItemPrefix.count)))
            } catch {
                session.notice = "Couldn't switch models: \(error.localizedDescription)"
            }
        }
    }

    var typingNames: [String] {
        // The agent "types" while it works and nothing of its reply shows yet.
        guard session.isRunning, session.streamingMessage == nil, session.runningToolCalls.isEmpty else { return [] }
        return [Self.agentUser.name ?? "stupid agent"]
    }

    /// While the agent is working, the composer's send button becomes a stop button. `observe()` already tracks
    /// `session.isRunning`, so a change here reaches the composer through `onChange`.
    var isBusy: Bool { session.isRunning }

    func stop() { session.stop() }

    func draftDidChange(_: String) {}

    func loadNewest() async throws {
        refresh()
    }

    func loadEarlier() async throws {}

    func send(_ message: ChatOutgoing) async throws -> String? {
        session.send(message.text)
        refresh()
        // The session shows the message as sending until the agent takes it in; nothing to wait for here.
        return nil
    }

    func isAfterReadPosition(_: ChatMessage) -> Bool { false }
    func markRead(upTo _: ChatMessage) -> (@MainActor () async throws -> Void)? { nil }
    func reactors(of _: String, on _: String) -> [ChatReactor] { [] }
    func snapshot() -> Data? { nil }
    func restore(snapshot _: Data) {}

    func startFollowing() async {
        following = true
        observe()
    }

    func stopFollowing() {
        following = false
    }

    func press(_ button: ChatMessageButton, on _: String) async throws -> ChatButtonAnswer? {
        if button.id == Self.retryButton.id { session.retry() }
        return nil
    }

    /// Re-reads the session whenever what the chat shows of it changes.
    private func observe() {
        guard following else { return }
        withObservationTracking {
            _ = session.entries
            _ = session.isRunning
            _ = session.conversation.title
            _ = app.settings
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh()
                self?.observe()
            }
        }
    }

    private func refresh() {
        let entries = session.entries
        let lastErrorId = session.canRetry ? entries.last(where: \.isError)?.id : nil
        messages = entries.flatMap { messages(for: $0, offersRetry: $0.id == lastErrorId) }
        onChange?()
    }

    /// One bubble per entry, except a response whose thinking came before its text: the kit draws embeds after a
    /// bubble's text, so the thinking gets a bubble of its own ahead of it.
    private func messages(for entry: ChatEntry, offersRetry: Bool) -> [ChatMessage] {
        guard entry.kind == .agent, entry.text != nil, !entry.thinking.isEmpty else {
            return [message(for: entry, offersRetry: offersRetry)]
        }
        var thinking = entry
        thinking.id = entry.id + "-thinking"
        thinking.text = nil
        thinking.toolCalls = []
        var reply = entry
        reply.thinking = []
        return [message(for: thinking, offersRetry: false), message(for: reply, offersRetry: offersRetry)]
    }

    private func message(for entry: ChatEntry, offersRetry: Bool) -> ChatMessage {
        switch entry.kind {
        case .user:
            return ChatMessage(id: entry.id, sender: Self.user, timestamp: entry.timestamp, text: entry.text, isOwn: true, isSending: entry.isSending)
        case .agent:
            let thinking = entry.thinking.map { ChatEmbed.message(title: entry.isStreaming && entry.text == nil && entry.toolCalls.isEmpty ? "Thinking…" : "Thought", text: $0, link: nil) }
            let tools = entry.toolCalls.map { ChatEmbed.message(title: Self.title(for: $0), text: Self.body(for: $0), link: nil) }
            return ChatMessage(id: entry.id, sender: Self.agentUser, timestamp: entry.timestamp, text: entry.text, isMarkdown: true, embeds: thinking + tools, isOwn: false)
        case .notice where entry.isError:
            // A bubble from the agent, since the kit draws system captions without their buttons.
            return ChatMessage(id: entry.id, sender: Self.agentUser, timestamp: entry.timestamp, text: entry.text, isOwn: false, isNotice: true, buttons: offersRetry ? [[Self.retryButton]] : [])
        case .notice:
            return ChatMessage(id: entry.id, sender: Self.system, timestamp: entry.timestamp, text: entry.text, isOwn: false, isNotice: true)
        }
    }

    private static func title(for call: ToolCallItem) -> String {
        switch call.status {
        case .preparing, .running, .succeeded: call.title
        case .failed: "\(call.title) · Failed"
        case .interrupted: "\(call.title) · Stopped"
        }
    }

    private static func body(for call: ToolCallItem) -> String {
        switch call.status {
        case .preparing: return "Preparing…"
        case .running: return "Running…"
        case .succeeded, .failed, .interrupted:
            let output = (call.output ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if output.isEmpty { return call.status == .interrupted ? "The run ended before this finished." : "No output" }
            return output.count > 4000 ? String(output.prefix(4000)) + "…" : output
        }
    }
}
#endif
