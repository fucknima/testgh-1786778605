// The app is iOS-only; the guard lets `swift test` build the package on macOS for the core tests.
#if os(iOS)
import StupidAgentCore
import SwiftUI

/// Every model the server lists, searchable, for the composer's "Choose Model…". A typed id the list doesn't have
/// can be used as is.
struct ModelPickerView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var models: [String] = []
    @State private var query = ""
    @State private var loading = true
    @State private var loadError: String?
    @State private var selectError: String?

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matches: [String] {
        guard !trimmedQuery.isEmpty else { return models }
        return models.filter { $0.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !trimmedQuery.isEmpty, !models.contains(trimmedQuery) {
                    Section {
                        Button("Use \u{201C}\(trimmedQuery)\u{201D}") { select(trimmedQuery) }
                    }
                }
                if let loadError {
                    Section {
                        Text(loadError).foregroundStyle(.red)
                    }
                }
                if let selectError {
                    Section {
                        Text(selectError).foregroundStyle(.red)
                    }
                }
                Section {
                    ForEach(matches, id: \.self) { id in
                        Button {
                            select(id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    // Explicit colors: inside a button label, `.primary` takes the tint.
                                    Text(shortModelName(id))
                                        .foregroundStyle(Color.primary)
                                    if shortModelName(id) != id {
                                        Text(id)
                                            .font(.footnote)
                                            .foregroundStyle(Color.secondary)
                                    }
                                }
                                Spacer()
                                if id == app.settings.modelId {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if loading {
                    ProgressView()
                } else if matches.isEmpty, trimmedQuery.isEmpty, loadError == nil {
                    ContentUnavailableView("No Models", systemImage: "cpu", description: Text("The server listed no models. Type a model ID to use it."))
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search or Type a Model ID")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationTitle("Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            models = try await fetchModelIds(baseURL: app.settings.baseURL, apiKey: app.apiKey, preset: app.settings.preset)
        } catch {
            loadError = "Couldn't load the server's models: \(error.localizedDescription)"
        }
    }

    private func select(_ id: String) {
        do {
            try app.selectModel(id)
            dismiss()
        } catch {
            selectError = "Couldn't switch models: \(error.localizedDescription)"
        }
    }
}
#endif
