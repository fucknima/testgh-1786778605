// The app is iOS-only; the guard lets `swift test` build the package on macOS for the core tests.
#if os(iOS)
import Observation
import PiTools
import StupidAgentCore
import SwiftUI

@main
struct StupidAgentApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ConversationsView()
                .environment(model)
        }
    }
}

/// App-wide state: the model settings, the workspace and the conversation list.
@MainActor @Observable
final class AppModel {
    private(set) var settings: ModelSettings
    private(set) var apiKey: String?
    private(set) var conversations: [ConversationSummary]
    let workspace: Workspace
    let store: ConversationStore
    /// The background index of other apps' containers, and the access object the agent sessions read.
    let containerIndex = ContainerIndex()
    private var containers: SandboxContainers { containerIndex.access }
    private let settingsStore = SettingsStore()
    /// Open sessions, so a running conversation keeps going while the user looks elsewhere.
    private var sessions: [UUID: AgentSession] = [:]

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        workspace = Workspace(root: documents)
        store = ConversationStore.appDefault()
        settings = settingsStore.load()
        apiKey = settingsStore.apiKey()
        conversations = store.list()
        seedWorkspace(documents)
        // Index other apps' containers in the background so the list is ready (and up to date) when the agent asks.
        if settings.allowOtherApps { containerIndex.start() }
    }

    var isConfigured: Bool { settings.isComplete(apiKey: apiKey) }

    func save(settings: ModelSettings, apiKey: String?) throws {
        var settings = settings
        settings.rememberModel()
        // The key first: if it can't be stored, nothing changes.
        try settingsStore.setAPIKey(apiKey)
        try settingsStore.save(settings)
        self.settings = settings
        self.apiKey = apiKey
        for session in sessions.values {
            session.update(settings: settings, apiKey: apiKey)
        }
        // Begin indexing the first time the user turns the feature on.
        if settings.allowOtherApps { containerIndex.start() }
    }

    /// Switches every conversation to a model, as the composer's model menu does.
    func selectModel(_ modelId: String) throws {
        var settings = settings
        settings.select(modelId: modelId)
        try save(settings: settings, apiKey: apiKey)
    }

    func newConversation() -> UUID {
        let conversation = Conversation()
        sessions[conversation.id] = makeSession(conversation)
        return conversation.id
    }

    func session(for id: UUID) -> AgentSession? {
        if let session = sessions[id] { return session }
        guard let conversation = try? store.load(id) else { return nil }
        let session = makeSession(conversation)
        sessions[id] = session
        return session
    }

    func refresh() {
        conversations = store.list()
    }

    func delete(_ id: UUID) {
        sessions[id]?.stop()
        sessions[id] = nil
        try? store.delete(id)
        refresh()
    }

    private func makeSession(_ conversation: Conversation) -> AgentSession {
        AgentSession(conversation: conversation, settings: settings, apiKey: apiKey, workspace: workspace, store: store, containers: containers)
    }

    /// A first file, so the workspace folder shows in the Files app and the agent has something to read.
    private func seedWorkspace(_ documents: URL) {
        let marker = "workspaceSeeded"
        guard !UserDefaults.standard.bool(forKey: marker) else { return }
        let welcome = documents.appendingPathComponent("Welcome.md")
        let text = """
        # Welcome

        This folder is the agent's workspace. The agent can read, create and edit files here, and you can see \
        them in the Files app under On My iPhone → stupid agent.
        """
        try? Data(text.utf8).write(to: welcome, options: .withoutOverwriting)
        UserDefaults.standard.set(true, forKey: marker)
    }
}

#endif
