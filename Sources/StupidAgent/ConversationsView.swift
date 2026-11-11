// The app is iOS-only; the guard lets `swift test` build the package on macOS for the core tests.
#if os(iOS)
import StupidAgentCore
import SwiftUI

struct ConversationsView: View {
    @Environment(AppModel.self) private var model
    @State private var path: [UUID] = []
    @State private var showSettings = false
    @State private var pendingDelete: ConversationSummary?
    @State private var query = ""

    /// The chats whose title or last message has the search text.
    private var shownConversations: [ConversationSummary] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return model.conversations }
        return model.conversations.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(query) || (conversation.preview ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !model.isConfigured {
                    Section {
                        Button("Set Up a Model") { showSettings = true }
                    } footer: {
                        Text("Bring your own model: an API key from OpenAI, OpenRouter or another OpenAI-compatible server, or a model running on your computer.")
                    }
                }
                ForEach(shownConversations) { conversation in
                    ConversationRow(conversation: conversation)
                        // The link without its chevron: the row draws one beside the time, as Messages does.
                        .background(NavigationLink(value: conversation.id) { EmptyView() }.opacity(0))
                        .alignmentGuide(.listRowSeparatorLeading) { dimensions in dimensions[.leading] + ConversationRow.textInset }
                        // Messages has no line above the first row.
                        .listRowSeparator(conversation.id == shownConversations.first?.id ? .hidden : .automatic, edges: .top)
                    .swipeActions {
                        Button("Delete", role: .destructive) { pendingDelete = conversation }
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSeparator(.hidden, edges: .top)
            .searchable(text: $query, prompt: "Search")
            .overlay {
                if !query.trimmingCharacters(in: .whitespaces).isEmpty, shownConversations.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else if model.conversations.isEmpty, model.isConfigured {
                    ContentUnavailableView("No Chats", systemImage: "bubble.left.and.text.bubble.right", description: Text("Start a chat to ask the agent to work with your files."))
                }
            }
            .navigationTitle("Chats")
            .navigationDestination(for: UUID.self) { id in
                if let session = model.session(for: id) {
                    AgentChatView(session: session)
                } else {
                    ContentUnavailableView("Chat Not Found", systemImage: "exclamationmark.bubble")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gear") { showSettings = true }
                }
                // As in Messages on iOS 26: the search field and the compose button share the bottom bar.
                if #available(iOS 26.0, *) {
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    ToolbarItem(placement: .bottomBar) { newChatButton }
                } else {
                    ToolbarItem(placement: .topBarTrailing) { newChatButton }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert(
                "Delete \u{201C}\(pendingDelete?.title ?? "")\u{201D}?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Chat", role: .destructive) {
                    if let id = pendingDelete?.id { model.delete(id) }
                }
            } message: {
                Text("This deletes the conversation. Files the agent made stay in your workspace.")
            }
            .onChange(of: path) { model.refresh() }
        }
    }

    private var newChatButton: some View {
        Button("New Chat", systemImage: "square.and.pencil") {
            path = [model.newConversation()]
        }
        .disabled(!model.isConfigured)
    }
}

/// A conversation in the list, laid out like a Messages row: avatar, title with the time and a chevron, and the last
/// message under it.
struct ConversationRow: View {
    let conversation: ConversationSummary

    static let avatarSize: CGFloat = 44
    static let textInset: CGFloat = avatarSize + 12

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "brain")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: Self.avatarSize, height: Self.avatarSize)
                .background(Circle().fill(Color.gray.gradient))
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(conversation.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(Self.shortDate(conversation.updatedAt))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .imageScale(.small)
                        .foregroundStyle(.tertiary)
                }
                Text(conversation.preview ?? "No messages yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    /// As Messages shows dates: the time today, "Yesterday", the weekday within a week, else the date.
    static func shortDate(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day, days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(date: .numeric, time: .omitted)
    }
}

#endif
