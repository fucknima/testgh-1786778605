import Foundation
import Observation
import PiAgent
import PiJavaScript
import PiAI
import PiTools

/// A file change the agent wants to make, waiting for the user.
public struct FileChangeRequest: Identifiable, Sendable {
    public let id = UUID()
    public let toolName: String
    public let path: String
    /// Whether the file exists, so the change overwrites or edits it rather than creating it.
    public let exists: Bool
    /// Whether the file is in the app's workspace, rather than another app's container.
    public let inWorkspace: Bool

    public var title: String {
        switch (toolName, exists) {
        case ("edit", _): "Edit \(path)?"
        case (_, true): "Overwrite \(path)?"
        default: "Create \(path)?"
        }
    }

    public var message: String {
        let place = inWorkspace ? "your workspace" : "another app's container"
        return switch (toolName, exists) {
        case ("edit", _): "The agent wants to change this file in \(place)."
        case (_, true): "The agent wants to replace this file's contents in \(place)."
        default: "The agent wants to create this file in \(place)."
        }
    }
}

/// The instructions every conversation starts with.
public func systemPrompt(workspaceName: String, date: Date = Date(), containerAccess: Bool = false) -> String {
    let day = date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    let appsTool = containerAccess ? "\n- apps: list other apps' containers you can read and write" : ""
    let containers = containerAccess
        ? """

    Paths that start with /apps/<bundle id>/ or /app-groups/<group id>/ reach another app's files. List the \
    containers with apps first. ls and find report paths relative to the container's root, so add that prefix \
    before using them in another call. Changing another app's files can affect that app, so prefer copying a file \
    into the workspace before editing it.
    """
        : ""
    return """
    You are stupid agent, an assistant that runs on the user's iPhone. You can work with files in the user's \
    workspace, a folder the user also sees in the Files app as "\(workspaceName)".

    Tools:
    - read: read a file (text or image)
    - write: create or overwrite a file
    - edit: change part of a file by exact text replacement
    - ls: list a directory
    - find: find files by glob pattern
    - grep: search file contents
    - sqlite: query a SQLite database read-only\(appsTool)
    - web_search: search the web for current information
    - web_fetch: read a web page or other URL
    - javascript: run JavaScript for calculations and data processing; it can read workspace files but not change them

    Paths are relative to the workspace root. There is no shell: you can't run programs, but javascript covers \
    calculations, parsing and transforming data. Search the web for anything recent or that you're unsure of. Read a \
    file before you edit it, and prefer edit over rewriting a whole file. Keep answers short; the user reads them on a phone. Today is \(day).\(containers)
    """
}

/// Per-provider headers. The saved conversation ID is stable across requests, retries,
/// app relaunches and auxiliary title-generation requests.
public func providerHeaders(preset: ProviderPreset, conversationID: UUID) -> [String: String]? {
    switch preset {
    case .openRouter:
        return ["HTTP-Referer": "https://stupidtech.net", "X-Title": "stupid agent"]
    case .openCodeGo:
        return [
            "User-Agent": "stupid-agent-ios/1.0",
            "x-opencode-session": conversationID.uuidString.lowercased(),
        ]
    default:
        return nil
    }
}

/// A conversation with the agent: its transcript, the run in progress, and approvals for file changes.
@MainActor @Observable
public final class AgentSession {
    public private(set) var conversation: Conversation
    public private(set) var messages: [AgentMessage]
    public private(set) var streamingMessage: AssistantMessage?
    public private(set) var runningToolCalls: Set<String> = []
    public private(set) var isRunning = false
    /// Why the last send failed before the agent started, such as missing settings.
    public var notice: String?
    /// A file change waiting for `resolveFileChange`.
    public private(set) var pendingFileChange: FileChangeRequest?

    @ObservationIgnored private let agent: Agent
    @ObservationIgnored private let store: ConversationStore
    @ObservationIgnored private let workspace: Workspace
    @ObservationIgnored private let containers: (any AppContainerAccess)?
    @ObservationIgnored private var eventsTask: Task<Void, Never>?
    @ObservationIgnored private var setupTask: Task<Void, Never>?
    @ObservationIgnored private var runTask: Task<Void, Never>?
    @ObservationIgnored private var fileChangeContinuation: CheckedContinuation<Bool, Never>?
    @ObservationIgnored private var settings: ModelSettings
    @ObservationIgnored private var apiKey: String?
    @ObservationIgnored private let streamFunction: StreamFunction
    @ObservationIgnored private var titleTask: Task<Void, Never>?

    /// The model this conversation talks to.
    public var modelId: String { settings.modelId }

    /// Messages sent that the agent hasn't taken in yet, shown as sending.
    public private(set) var queued: [QueuedMessage] = []

    public var entries: [ChatEntry] {
        chatEntries(messages: messages, streaming: streamingMessage, runningToolCalls: runningToolCalls, isRunning: isRunning, queued: queued)
    }

    public init(
        conversation: Conversation,
        settings: ModelSettings,
        apiKey: String?,
        workspace: Workspace,
        store: ConversationStore,
        workspaceName: String = "stupid agent",
        containers: (any AppContainerAccess)? = nil,
        streamFunction: @escaping StreamFunction = defaultStreamFunction
    ) {
        self.conversation = conversation
        self.settings = settings
        self.apiKey = apiKey
        self.streamFunction = streamFunction
        self.store = store
        self.workspace = workspace
        self.containers = containers
        messages = conversation.messages
        let containerAccess = settings.allowOtherApps && (containers?.isAvailable ?? false)
        agent = Agent(
            model: settings.model,
            systemPrompt: systemPrompt(workspaceName: workspaceName, containerAccess: containerAccess),
            tools: Self.tools(workspace: workspace, settings: settings, containers: containers),
            messages: conversation.messages,
            thinkingLevel: settings.reasoning ? settings.thinkingLevel : .off,
            streamOptions: StreamOptions(apiKey: apiKey, headers: providerHeaders(preset: settings.preset, conversationID: conversation.id)),
            streamFunction: streamFunction
        )
        let agent = agent
        let beforeToolCall: @Sendable (BeforeToolCallContext) async -> BeforeToolCallResult? = { [weak self] context in
            await self?.approve(context)
        }
        // Subscribe and install the approval hook before the first run.
        setupTask = Task { [weak self] in
            let events = await agent.events()
            await agent.configure { agent in
                agent.beforeToolCall = beforeToolCall
            }
            self?.eventsTask = Task { [weak self] in
                for await event in events {
                    self?.handle(event)
                }
            }
        }
    }

    // `deinit` can't touch main-actor state; the events task ends when the agent's stream does.


    /// Applies changed settings to later requests.
    public func update(settings: ModelSettings, apiKey: String?) {
        self.settings = settings
        self.apiKey = apiKey
        let containers = containers
        let workspace = workspace
        Task {
            await agent.setModel(settings.model)
            await agent.setThinkingLevel(settings.reasoning ? settings.thinkingLevel : .off)
            await agent.setStreamOptions(StreamOptions(apiKey: apiKey, headers: providerHeaders(preset: settings.preset, conversationID: conversation.id)))
            await agent.setTools(Self.tools(workspace: workspace, settings: settings, containers: containers))
        }
    }

    private static func tools(workspace: Workspace, settings: ModelSettings, containers: (any AppContainerAccess)?) -> [AgentTool] {
        agentFileTools(workspace: workspace, containers: settings.allowOtherApps ? containers : nil)
            + webTools(searchProvider: settings.webSearchProvider)
            + [javaScriptTool(workspace: workspace)]
    }

    /// Sends a message. While the agent works, the message steers it: it's read after the current tool calls.
    public func send(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        notice = nil
        // The first message names the chat right away, not when the run ends.
        if conversation.title == "New chat", let title = Conversation.title(for: [.user(text)]) {
            conversation.title = title
            generateTitle(firstMessage: text, fallback: title)
        }
        queued.append(QueuedMessage(text: text))
        if isRunning {
            Task { await agent.steer(.user(text)) }
            return
        }
        isRunning = true
        runTask = Task {
            await setupTask?.value
            // The previous run reports its end before the agent is idle.
            await agent.waitForIdle()
            do {
                try await agent.prompt(text)
            } catch {
                queued.removeAll { $0.text == text }
                notice = error.localizedDescription
                finishRun()
            }
        }
    }

    /// Asks the model for a short title, beside the run, and uses it unless the title changed meanwhile. A failure
    /// keeps the title taken from the first message.
    private func generateTitle(firstMessage: String, fallback: String) {
        let model = settings.model
        let options = StreamOptions(apiKey: apiKey, headers: providerHeaders(preset: settings.preset, conversationID: conversation.id))
        let streamFunction = streamFunction
        titleTask = Task { [weak self] in
            guard let title = await TitleGenerator.generate(firstMessage: firstMessage, model: model, options: options, streamFunction: streamFunction) else { return }
            guard let self, conversation.title == fallback else { return }
            conversation.title = title
            conversation.messages = messages
            do {
                try store.save(conversation)
            } catch {
                notice = "Couldn't save the conversation: \(error.localizedDescription)"
            }
        }
    }

    /// Retries after a failed response.
    public func retry() {
        guard !isRunning else { return }
        notice = nil
        isRunning = true
        messages = retryTranscript(messages)
        runTask = Task {
            await setupTask?.value
            await agent.waitForIdle()
            do {
                try await agent.setMessages(retryTranscript(await agent.state.messages))
                try await agent.continueRun()
            } catch {
                notice = error.localizedDescription
                finishRun()
            }
        }
    }

    /// Whether the last response failed, so it can be retried.
    public var canRetry: Bool {
        guard !isRunning, let last = messages.last?.assistant else { return false }
        return last.stopReason == .error
    }

    public func stop() {
        resolveFileChange(allowed: false)
        Task { await agent.abort() }
    }

    /// Answers the pending file change.
    public func resolveFileChange(allowed: Bool) {
        pendingFileChange = nil
        fileChangeContinuation?.resume(returning: allowed)
        fileChangeContinuation = nil
    }

    private func approve(_ context: BeforeToolCallContext) async -> BeforeToolCallResult? {
        guard settings.confirmFileChanges, context.toolCall.name == "write" || context.toolCall.name == "edit" else { return nil }
        let path = context.arguments["path"]?.stringValue ?? ""
        let isContainer = ContainerPath.parse(path) != nil
        let exists = await fileExists(at: path)
        // One request at a time: parallel calls queue behind the open one.
        while fileChangeContinuation != nil {
            try? await Task.sleep(for: .milliseconds(100))
            if Task.isCancelled { return BeforeToolCallResult(block: true, reason: "Operation aborted") }
        }
        let allowed = await withCheckedContinuation { continuation in
            fileChangeContinuation = continuation
            pendingFileChange = FileChangeRequest(toolName: context.toolCall.name, path: path, exists: exists, inWorkspace: !isContainer)
        }
        return allowed ? nil : BeforeToolCallResult(block: true, reason: "The user declined this change to \(path).")
    }

    /// Whether a path the agent named exists, in the workspace or in another app's container.
    private func fileExists(at path: String) async -> Bool {
        if let parsed = ContainerPath.parse(path) {
            guard let containers, containers.isAvailable else { return false }
            let all = (try? await containers.containers()) ?? []
            guard let container = all.first(where: { $0.kind == parsed.kind && $0.identifier == parsed.identifier }),
                  let root = try? await containers.root(for: container) else { return false }
            return FileManager.default.fileExists(atPath: root.appendingPathComponent(parsed.relativePath).path)
        }
        return (try? workspace.resolve(path)).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    private func handle(_ event: AgentEvent) {
        switch event {
        case let .messageStart(message), let .messageUpdate(message, _):
            streamingMessage = message.assistant
        case let .messageEnd(message):
            streamingMessage = nil
            messages.append(message)
            if case let .llm(.user(user)) = message, let index = queued.firstIndex(where: { $0.text == contentText(user.content) }) {
                queued.remove(at: index)
            }
        case let .toolExecutionStart(id, _, _):
            runningToolCalls.insert(id)
        case let .toolExecutionEnd(id, _, _, _, _):
            runningToolCalls.remove(id)
        case .agentEnd:
            finishRun()
        default:
            break
        }
    }

    /// Ends the run in the UI and saves. Runs as the `agentEnd` event is handled, so every message event of the run
    /// has been applied: the event stream is the only source of `messages`.
    private func finishRun() {
        isRunning = false
        streamingMessage = nil
        runningToolCalls = []
        conversation.messages = messages
        conversation.updatedAt = Date()
        if conversation.title == "New chat", let title = Conversation.title(for: messages) {
            conversation.title = title
        }
        do {
            try store.save(conversation)
        } catch {
            notice = "Couldn't save the conversation: \(error.localizedDescription)"
        }
        // A message sent after the agent last checked for steering starts the next run.
        if !queued.isEmpty {
            isRunning = true
            runTask = Task {
                await agent.waitForIdle()
                do {
                    try await agent.continueRun()
                } catch {
                    queued = []
                    notice = error.localizedDescription
                    finishRun()
                }
            }
        }
    }
}

/// The transcript to retry from: without the failed responses at its end.
func retryTranscript(_ messages: [AgentMessage]) -> [AgentMessage] {
    var messages = messages
    while let last = messages.last?.assistant, last.stopReason == .error || last.stopReason == .aborted {
        messages.removeLast()
    }
    return messages
}
