// The app is iOS-only; the guard lets `swift test` build the package on macOS for the core tests.
#if os(iOS)
import StupidAgentCore
import StupidChatKit
import SwiftUI

/// A conversation with the agent: stupid chatkit's chat screen, with Stop while the agent works and the alert that
/// asks before a file changes.
struct AgentChatView: View {
    @Bindable var session: AgentSession
    @Environment(AppModel.self) private var app
    @State private var choosingModel = false

    var body: some View {
        // The adapter is made once for the chat; the state it sets lives as long as this view does.
        NetworkChatView(viewModel: AdapterChatViewModel(adapter: AgentChatAdapter(session: session, app: app, chooseModel: { choosingModel = true }), accountId: "local"))
            .id(session.conversation.id)
            .sheet(isPresented: $choosingModel) {
                ModelPickerView()
            }
            .alert(
                session.pendingFileChange?.title ?? "",
                isPresented: Binding(get: { session.pendingFileChange != nil }, set: { if !$0 { session.resolveFileChange(allowed: false) } })
            ) {
                Button("Don't Allow", role: .cancel) { session.resolveFileChange(allowed: false) }
                Button("Allow") { session.resolveFileChange(allowed: true) }
            } message: {
                Text(session.pendingFileChange?.message ?? "")
            }
            .alert("Couldn't Send", isPresented: Binding(get: { session.notice != nil }, set: { if !$0 { session.notice = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(session.notice ?? "")
            }
    }
}
#endif
