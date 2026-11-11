import Foundation
import PiAgent
import PiAI
import PiTools
import SQLite3
@testable import StupidAgentCore
import Testing

@Suite struct ChatEntryTests {
    @Test func groupsAResponseWithItsThinkingAndTools() {
        let call = ToolCall(id: "c1", name: "read", arguments: ["path": "notes.md"])
        let messages: [AgentMessage] = [
            .llm(.system(SystemMessage(content: "prompt", timestamp: 0))),
            .user("hi"),
            .llm(.assistant(AssistantMessage(content: [.thinking(ThinkingContent(thinking: "hmm")), .text(TextContent(text: "Looking")), .toolCall(call)], api: "x", provider: "x", model: "x", stopReason: .toolUse, timestamp: 1))),
            .llm(.toolResult(ToolResultMessage(toolCallId: "c1", toolName: "read", content: [.text(TextContent(text: "contents"))], isError: false))),
            .llm(.assistant(AssistantMessage(content: [.text(TextContent(text: "Done"))], api: "x", provider: "x", model: "x", stopReason: .stop, timestamp: 2))),
        ]
        let entries = chatEntries(messages: messages, streaming: nil, runningToolCalls: [], isRunning: false)
        #expect(entries.map(\.kind) == [.user, .agent, .agent])
        #expect(entries[1].text == "Looking")
        #expect(entries[1].thinking == ["hmm"])
        #expect(entries[1].toolCalls.first?.status == .succeeded)
        #expect(entries[1].toolCalls.first?.title == "Read notes.md")
        #expect(entries[1].toolCalls.first?.output == "contents")
        #expect(entries[2].text == "Done")
    }

    @Test func namesWhatToolCallsWorkOn() {
        #expect(toolSummary(name: "ls", arguments: ["path": "."]) == "")
        #expect(toolSummary(name: "ls", arguments: ["path": "notes"]) == "notes")
        #expect(ToolCallItem(id: "1", name: "ls", summary: "", arguments: [:], status: .succeeded).title == "List")
        #expect(toolSummary(name: "grep", arguments: ["pattern": "todo", "path": "notes"]) == "todo in notes")
        #expect(ToolCallItem(id: "1", name: "web_search", summary: toolSummary(name: "web_search", arguments: ["query": "swift 6"]), arguments: [:], status: .succeeded).title == "Search the web for swift 6")
        #expect(toolSummary(name: "web_fetch", arguments: ["url": "https://www.swift.org/blog/?x=1"]) == "www.swift.org/blog/")
        #expect(ToolCallItem(id: "1", name: "javascript", summary: toolSummary(name: "javascript", arguments: ["code": "return 1"]), arguments: [:], status: .succeeded).title == "Run JavaScript")
    }

    @Test func marksUnfinishedToolCalls() {
        let call = ToolCall(id: "c1", name: "write", arguments: ["path": "a.txt"])
        let messages: [AgentMessage] = [.llm(.assistant(AssistantMessage(content: [.toolCall(call)], api: "x", provider: "x", model: "x", stopReason: .toolUse)))]
        #expect(chatEntries(messages: messages, streaming: nil, runningToolCalls: ["c1"], isRunning: true).first?.toolCalls.first?.status == .running)
        #expect(chatEntries(messages: messages, streaming: nil, runningToolCalls: [], isRunning: false).first?.toolCalls.first?.status == .interrupted)
    }

    @Test func showsErrorsAndQueuedMessages() {
        var failed = AssistantMessage(api: "x", provider: "x", model: "x", stopReason: .error)
        failed.errorMessage = "401 Invalid API key"
        let entries = chatEntries(messages: [.llm(.assistant(failed))], streaming: nil, runningToolCalls: [], isRunning: false, queued: [QueuedMessage(text: "next")])
        #expect(entries.map(\.kind) == [.notice, .user])
        #expect(entries[0].isError)
        #expect(entries[0].text == "401 Invalid API key")
        #expect(entries[1].isSending)
    }
}

@Suite struct StorageTests {
    @Test func savesListsAndDeletesConversations() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("conversations-\(UUID().uuidString)")
        let store = ConversationStore(directory: directory)
        var conversation = Conversation(messages: [.user("Plan my week\nwith details")])
        conversation.title = Conversation.title(for: conversation.messages) ?? "New chat"
        try store.save(conversation)
        #expect(store.list().map(\.title) == ["Plan my week"])
        #expect(try store.load(conversation.id) == conversation)
        try store.delete(conversation.id)
        #expect(store.list().isEmpty)
    }

    @Test func settingsRequireWhatTheProviderNeeds() {
        var settings = ModelSettings(preset: .openRouter, modelId: "openai/gpt-4o-mini")
        #expect(!settings.isComplete(apiKey: nil))
        #expect(settings.isComplete(apiKey: "sk"))
        settings = ModelSettings(preset: .ollama, modelId: "llama3.2")
        #expect(settings.isComplete(apiKey: nil))
        #expect(settings.model.baseURL == "http://localhost:11434/v1")
    }

    @Test func supportsOpenCodeGoModelAndCatalog() {
        let preset = ProviderPreset.openCodeGo
        #expect(preset.name == "OpenCode Go")
        #expect(preset.providerId == "opencode-go")
        #expect(preset.needsAPIKey)
        #expect(preset.baseURL == "https://opencode.ai/inference/go/openai/v1")
        let settings = ModelSettings(preset: preset, modelId: "glm-5.3-flash")
        #expect(!settings.isComplete(apiKey: nil))
        #expect(settings.isComplete(apiKey: "test-key"))
        #expect(settings.model.api == "openai-completions")
        #expect(settings.model.provider == "opencode-go")
        #expect(modelListURL(baseURL: preset.baseURL, preset: preset)?.absoluteString == "https://opencode.ai/inference/go/v1/models")
        #expect(modelListURL(baseURL: "https://api.openai.com/v1")?.absoluteString == "https://api.openai.com/v1/models")
    }

    @Test func openCodeGoSessionHeadersStayStableForConversation() {
        let first = UUID()
        let second = UUID()
        let a = providerHeaders(preset: .openCodeGo, conversationID: first)
        let resumed = providerHeaders(preset: .openCodeGo, conversationID: first)
        let other = providerHeaders(preset: .openCodeGo, conversationID: second)
        #expect(a?["x-opencode-session"] == first.uuidString.lowercased())
        #expect(a?["User-Agent"] == "stupid-agent-ios/1.0")
        #expect(a == resumed)
        #expect(a?["x-opencode-session"] != other?["x-opencode-session"])
        #expect(providerHeaders(preset: .openRouter, conversationID: first)?["X-Title"] == "stupid agent")
        #expect(providerHeaders(preset: .custom, conversationID: first) == nil)
    }

    @Test func remembersRecentModels() throws {
        var settings = ModelSettings(preset: .openRouter, modelId: "openrouter/free")
        #expect(settings.menuModelIds == ["openrouter/free"])
        settings.select(modelId: "openai/gpt-4o-mini")
        // The model it switched from stays in the menu.
        #expect(settings.recentModelIds == ["openai/gpt-4o-mini", "openrouter/free"])
        settings.select(modelId: "openrouter/free")
        #expect(settings.modelId == "openrouter/free")
        #expect(settings.recentModelIds == ["openrouter/free", "openai/gpt-4o-mini"])
        for index in 0 ..< 10 { settings.select(modelId: "m\(index)") }
        #expect(settings.recentModelIds.count == ModelSettings.recentLimit)
        #expect(shortModelName("openai/gpt-4o-mini") == "gpt-4o-mini")
        #expect(shortModelName("llama3.2") == "llama3.2")
    }

    @Test func decodesSettingsSavedBeforeRecentModels() throws {
        let saved = #"{"preset":"openRouter","baseURL":"https://openrouter.ai/api/v1","modelId":"openrouter/free","reasoning":false,"thinkingLevel":"medium","acceptsImages":false,"confirmFileChanges":true}"#
        let settings = try JSONDecoder().decode(ModelSettings.self, from: Data(saved.utf8))
        #expect(settings.modelId == "openrouter/free")
        #expect(settings.recentModelIds.isEmpty)
        #expect(settings.webSearchProvider == .exa)
    }

    @Test func cleansGeneratedTitles() {
        #expect(TitleGenerator.clean("\"Plan My Week.\"\n\nmore") == "Plan My Week")
        #expect(TitleGenerator.clean("Title: **Swift Release Dates**") == "Swift Release Dates")
        #expect(TitleGenerator.clean("  \n ") == nil)
        #expect(TitleGenerator.clean(String(repeating: "a", count: 80))?.count == 61)
    }

    @Test func previewsTheLastMessage() {
        let messages: [AgentMessage] = [
            .user("first"),
            .llm(.assistant(AssistantMessage(content: [.text(TextContent(text: "Here is\n\nthe answer"))], api: "x", provider: "x", model: "x", stopReason: .stop))),
            .llm(.assistant(AssistantMessage(content: [.toolCall(ToolCall(id: "1", name: "ls", arguments: [:]))], api: "x", provider: "x", model: "x", stopReason: .toolUse))),
        ]
        #expect(Conversation.preview(for: messages) == "Here is the answer")
        #expect(Conversation.preview(for: [.user("only you")]) == "only you")
        let markdown = AgentMessage.llm(.assistant(AssistantMessage(content: [.text(TextContent(text: "Wrote `notes/hello.md` with **two** lines, see [docs](https://x.test)"))], api: "x", provider: "x", model: "x", stopReason: .stop)))
        #expect(Conversation.preview(for: [markdown]) == "Wrote notes/hello.md with two lines, see docs")
        #expect(Conversation.preview(for: []) == nil)
    }

    @Test func backfillsPreviewsFromConversations() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("conversations-\(UUID().uuidString)")
        let store = ConversationStore(directory: directory)
        let conversation = Conversation(title: "Old", messages: [.user("hello there")])
        try store.save(conversation)
        // An index from before previews.
        let index = directory.appendingPathComponent("index.json")
        try JSONEncoder().encode([ConversationSummary(id: conversation.id, title: "Old", updatedAt: conversation.updatedAt)]).write(to: index)
        #expect(store.list().first?.preview == "hello there")
        #expect(try JSONDecoder().decode([ConversationSummary].self, from: Data(contentsOf: index)).first?.preview == "hello there")
    }

    @Test func readsIndexesSavedBeforePreviews() throws {
        let saved = #"[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"Old","updatedAt":0}]"#
        let summaries = try JSONDecoder().decode([ConversationSummary].self, from: Data(saved.utf8))
        #expect(summaries.first?.preview == nil)
    }

    @Test func retryDropsFailedResponses() {
        let failed = AgentMessage.llm(.assistant(AssistantMessage(api: "x", provider: "x", model: "x", stopReason: .error)))
        #expect(retryTranscript([.user("a"), failed, failed]).map(\.role) == ["user"])
    }
}

/// A provider that writes a file, then answers; title requests get `title`.
private func scriptedStream(path: String, title: String = "Writing Out A File") -> StreamFunction {
    let calls = Counter()
    return { model, context, _ in
        let stream = AssistantMessageEventStream()
        if getCurrentSystemPrompt(context.messages) == TitleGenerator.instructions {
            stream.push(.done(reason: .stop, message: AssistantMessage(content: [.text(TextContent(text: "\"\(title).\""))], api: model.api, provider: model.provider, model: model.id, stopReason: .stop)))
            stream.end()
            return stream
        }
        let turn = await calls.next()
        let message = turn == 0
            ? AssistantMessage(content: [.toolCall(ToolCall(id: "w1", name: "write", arguments: ["path": .string(path), "content": "hello"]))], api: model.api, provider: model.provider, model: model.id, stopReason: .toolUse)
            : AssistantMessage(content: [.text(TextContent(text: "Wrote it"))], api: model.api, provider: model.provider, model: model.id, stopReason: .stop)
        stream.push(.start(partial: AssistantMessage(api: model.api, provider: model.provider, model: model.id, stopReason: .pending)))
        stream.push(.done(reason: message.stopReason, message: message))
        stream.end()
        return stream
    }
}

private actor Counter {
    private var value = 0

    func next() -> Int {
        defer { value += 1 }
        return value
    }
}

@Suite(.serialized) @MainActor struct AgentSessionTests {
    func makeSession(confirm: Bool) throws -> (AgentSession, Workspace, ConversationStore) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("workspace-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let workspace = Workspace(root: root)
        let store = ConversationStore(directory: root.appendingPathComponent(".conversations"))
        let settings = ModelSettings(preset: .custom, baseURL: "https://example.test/v1", modelId: "m", confirmFileChanges: confirm)
        let session = AgentSession(conversation: Conversation(), settings: settings, apiKey: nil, workspace: workspace, store: store, streamFunction: scriptedStream(path: "out.txt"))
        return (session, workspace, store)
    }

    func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0 ..< 200 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func runsToolsAndSaves() async throws {
        let (session, workspace, store) = try makeSession(confirm: false)
        session.send("write a file")
        // Titled as soon as it's sent.
        #expect(session.conversation.title == "write a file")
        try await waitUntil { !session.isRunning && session.messages.contains { $0.assistant?.text == "Wrote it" } && session.conversation.title != "write a file" }
        #expect(try String(contentsOf: workspace.root.appendingPathComponent("out.txt"), encoding: .utf8) == "hello")
        // Then the model's title, cleaned of quotes and the period, replaces it and is saved.
        #expect(session.conversation.title == "Writing Out A File")
        #expect(store.list().first?.title == "Writing Out A File")
        #expect(store.list().first?.preview == "Wrote it")
        #expect(session.queued.isEmpty)
        // Each message once: events are the only source of the transcript.
        #expect(session.messages.filter { $0.role != "system" }.map(\.role) == ["user", "assistant", "toolResult", "assistant"])
        let saved = try store.load(session.conversation.id)
        #expect(saved.messages == session.messages)
    }

    @Test func asksBeforeWritingAndHonorsDenial() async throws {
        let (session, workspace, _) = try makeSession(confirm: true)
        session.send("write a file")
        try await waitUntil { session.pendingFileChange != nil }
        #expect(session.pendingFileChange?.title == "Create out.txt?")
        session.resolveFileChange(allowed: false)
        try await waitUntil { !session.isRunning && session.messages.contains { $0.assistant?.text == "Wrote it" } }
        #expect(!FileManager.default.fileExists(atPath: workspace.root.appendingPathComponent("out.txt").path))
        let result = session.messages.compactMap { if case let .llm(.toolResult(result)) = $0 { result } else { nil } }.first
        #expect(result?.isError == true)
    }
}

private struct FakeContainers: AppContainerAccess {
    let root: URL

    var isAvailable: Bool { true }

    func containers() async throws -> [AppContainer] {
        [
            AppContainer(kind: .app, identifier: "com.example.notes", path: root.path),
            AppContainer(kind: .group, identifier: "group.com.example", path: root.path),
        ]
    }

    func root(for container: AppContainer) async throws -> URL { root }
}

private func text(of result: AgentToolResult) -> String {
    result.content.compactMap { content in
        if case let .text(text) = content { text.text } else { nil }
    }.joined(separator: "\n")
}

@Suite struct ContainerToolTests {
    func makeTools() throws -> (workspace: Workspace, tools: [AgentTool], containerRoot: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("containers-\(UUID().uuidString)")
        let workspace = Workspace(root: root.appendingPathComponent("workspace"))
        let containerRoot = root.appendingPathComponent("container")
        try FileManager.default.createDirectory(at: workspace.root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: containerRoot, withIntermediateDirectories: true)
        return (workspace, agentFileTools(workspace: workspace, containers: FakeContainers(root: containerRoot)), containerRoot)
    }

    @Test func parsesContainerPaths() {
        #expect(ContainerPath.parse("/apps/com.example.notes/Documents/a.txt") == ContainerPath(kind: .app, identifier: "com.example.notes", relativePath: "Documents/a.txt"))
        #expect(ContainerPath.parse("apps/com.example.notes")?.relativePath == ".")
        #expect(ContainerPath.parse("/app-groups/group.com.example/") == ContainerPath(kind: .group, identifier: "group.com.example", relativePath: "."))
        #expect(ContainerPath.parse("/other/com.example.notes/x") == nil)
        #expect(ContainerPath.parse("/apps/../etc/passwd") == nil)
        #expect(ContainerPath.parse("notes.md") == nil)
    }

    @Test func listsContainers() async throws {
        let (_, tools, _) = try makeTools()
        let apps = try #require(tools.first { $0.name == "apps" })
        let output = text(of: try await apps.execute("1", [:], { _ in }))
        #expect(output.contains("/apps/com.example.notes"))
        #expect(output.contains("/app-groups/group.com.example"))
    }

    @Test func readsAndWritesInAContainer() async throws {
        let (workspace, tools, containerRoot) = try makeTools()
        try "hello".write(to: containerRoot.appendingPathComponent("note.txt"), atomically: true, encoding: .utf8)

        let read = try #require(tools.first { $0.name == "read" })
        let readResult = text(of: try await read.execute("1", ["path": "/apps/com.example.notes/note.txt"], { _ in }))
        #expect(readResult.contains("hello"))

        let write = try #require(tools.first { $0.name == "write" })
        _ = try await write.execute("2", ["path": "/app-groups/group.com.example/new.txt", "content": "written"], { _ in })
        #expect(try String(contentsOf: containerRoot.appendingPathComponent("new.txt"), encoding: .utf8) == "written")

        let ls = try #require(tools.first { $0.name == "ls" })
        let listing = text(of: try await ls.execute("3", ["path": "/apps/com.example.notes"], { _ in }))
        #expect(listing.contains("note.txt"))

        // Workspace paths still go to the workspace.
        try "in workspace".write(to: workspace.root.appendingPathComponent("mine.txt"), atomically: true, encoding: .utf8)
        let workspaceRead = text(of: try await read.execute("4", ["path": "mine.txt"], { _ in }))
        #expect(workspaceRead.contains("in workspace"))
    }

    @Test func rejectsUnknownContainers() async throws {
        let (_, tools, _) = try makeTools()
        let read = try #require(tools.first { $0.name == "read" })
        await #expect(throws: WorkspaceError.self) {
            try await read.execute("1", ["path": "/apps/com.example.other/note.txt"], { _ in })
        }
    }

    @Test func disabledAccessKeepsTheWorkspaceTools() throws {
        let (workspace, _, _) = try makeTools()
        let tools = agentFileTools(workspace: workspace, containers: nil)
        #expect(!tools.contains { $0.name == "apps" })
        #expect(tools.map(\.name) == ["read", "write", "edit", "ls", "find", "grep", "sqlite"])
    }
}

private func makeDatabase(in directory: URL) throws -> URL {
    let url = directory.appendingPathComponent("data.sqlite")
    var database: OpaquePointer?
    guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
        throw WorkspaceError("Could not create a test database.")
    }
    defer { sqlite3_close(database) }
    let sql = """
    CREATE TABLE notes (id INTEGER PRIMARY KEY, title TEXT);
    INSERT INTO notes (title) VALUES ('alpha'), ('beta');
    """
    guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
        throw WorkspaceError("Could not fill the test database.")
    }
    return url
}

@Suite struct SQLiteToolTests {
    func makeWorkspace() throws -> (Workspace, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sqlite-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let workspace = Workspace(root: root)
        _ = try makeDatabase(in: root)
        return (workspace, root)
    }

    @Test func listsTablesWhenNoQueryIsGiven() async throws {
        let (workspace, _) = try makeWorkspace()
        let tool = sqliteTool(workspace: workspace)
        let output = text(of: try await tool.execute("1", ["path": "data.sqlite"], { _ in }))
        #expect(output.contains("\"name\":\"notes\""))
        #expect(output.contains("\"type\":\"table\""))
    }

    @Test func readsRowsAndTruncates() async throws {
        let (workspace, _) = try makeWorkspace()
        let tool = sqliteTool(workspace: workspace)
        let output = text(of: try await tool.execute("1", ["path": "data.sqlite", "query": "SELECT * FROM notes ORDER BY id"], { _ in }))
        #expect(output.contains("\"title\":\"alpha\""))
        #expect(output.contains("\"title\":\"beta\""))

        let limited = text(of: try await tool.execute("2", ["path": "data.sqlite", "query": "SELECT * FROM notes", "limit": 1], { _ in }))
        #expect(limited.contains("Truncated to 1 row"))
    }

    @Test func refusesWrites() async throws {
        let (workspace, _) = try makeWorkspace()
        let tool = sqliteTool(workspace: workspace)
        await #expect(throws: WorkspaceError.self) {
            try await tool.execute("1", ["path": "data.sqlite", "query": "INSERT INTO notes (title) VALUES ('gamma')"], { _ in })
        }
        let output = text(of: try await tool.execute("2", ["path": "data.sqlite", "query": "SELECT COUNT(*) AS count FROM notes"], { _ in }))
        #expect(output.contains("\"count\":2"))
    }

    @Test func readsAContainerDatabase() async throws {
        let (workspace, tools, containerRoot) = try ContainerToolTests().makeTools()
        _ = try makeDatabase(in: containerRoot)
        let sqlite = try #require(tools.first { $0.name == "sqlite" })
        let output = text(of: try await sqlite.execute("1", ["path": "/apps/com.example.notes/data.sqlite", "query": "SELECT title FROM notes ORDER BY id"], { _ in }))
        #expect(output.contains("\"title\":\"alpha\""))
        #expect(workspace.root.path.isEmpty == false)
    }
}
