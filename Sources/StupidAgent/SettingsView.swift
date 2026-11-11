// The app is iOS-only; the guard lets `swift test` build the package on macOS for the core tests.
#if os(iOS)
import PiAI
import PiTools
import StupidAgentCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var settings = ModelSettings()
    @State private var apiKey = ""
    @State private var availableModels: [String] = []
    @State private var loadingModels = false
    @State private var modelListError: String?
    @State private var saveError: String?
    /// The form loads the saved settings once; `onAppear` runs again when the model picker pops back.
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Provider", selection: Binding(get: { settings.preset }, set: choose)) {
                        Text("OpenAI").tag(ProviderPreset.openAI)
                        Text("OpenCode Go").tag(ProviderPreset.openCodeGo)
                        Text("OpenRouter").tag(ProviderPreset.openRouter)
                        Text("Groq").tag(ProviderPreset.groq)
                        Text("DeepSeek").tag(ProviderPreset.deepSeek)
                        Text("Ollama").tag(ProviderPreset.ollama)
                        Text("LM Studio").tag(ProviderPreset.lmStudio)
                        Text("Custom").tag(ProviderPreset.custom)
                    }
                    TextField("Base URL", text: $settings.baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField(settings.preset.needsAPIKey ? "API Key" : "API Key (optional)", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Server")
                } footer: {
                    if settings.preset == .ollama || settings.preset == .lmStudio {
                        Text("On a phone, replace localhost with your computer's address on the local network.")
                    } else if settings.preset == .openCodeGo {
                        Text("Enter your OpenCode Go subscription key. Every conversation gets a stable session ID, including its title requests.")
                    } else {
                        Text("Any server that speaks the OpenAI Chat Completions API. The key is stored in the Keychain on this device.")
                    }
                }

                Section {
                    TextField("Model ID", text: $settings.modelId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !availableModels.isEmpty {
                        Picker("Available Models", selection: $settings.modelId) {
                            ForEach(availableModels, id: \.self) { id in
                                Text(id).tag(id)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                    Button(loadingModels ? "Loading Models…" : "Load Models") { loadModels() }
                        .disabled(loadingModels || settings.baseURL.isEmpty)
                    Toggle("Reasoning Model", isOn: $settings.reasoning)
                    if settings.reasoning {
                        Picker("Thinking", selection: $settings.thinkingLevel) {
                            ForEach(ThinkingLevel.allCases.filter { $0 != .off }, id: \.self) { level in
                                Text(level.rawValue.capitalized).tag(level)
                            }
                        }
                    }
                    Toggle("Accepts Images", isOn: $settings.acceptsImages)
                } header: {
                    Text("Model")
                } footer: {
                    if let modelListError {
                        Text(modelListError).foregroundStyle(.red)
                    }
                }

                Section {
                    Toggle("Ask Before Changing Files", isOn: $settings.confirmFileChanges)
                    Toggle("Access Other Apps", isOn: $settings.allowOtherApps)
                } header: {
                    Text("Workspace")
                } footer: {
                    Text("The agent works in this app's folder, which you can open in the Files app under On My iPhone → stupid agent.")
                    if settings.allowOtherApps {
                        Text("The agent can also read and write files in other apps' containers. Requires iOS 26 or later on a real device.")
                    }
                }

                if settings.allowOtherApps, model.containerIndex.isAvailable {
                    appIndexSection
                }

                Section {
                    Picker("Web Search", selection: $settings.webSearchProvider) {
                        ForEach(WebSearchProvider.allCases, id: \.self) { provider in
                            Text(provider.name).tag(provider)
                        }
                    }
                } header: {
                    Text("Tools")
                } footer: {
                    Text("The agent can search the web, read pages and run JavaScript. Searches go to the provider chosen here; neither needs an API key.")
                }

                if let saveError {
                    Section {
                        Text(saveError).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!settings.isComplete(apiKey: apiKey))
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                settings = model.settings
                apiKey = model.apiKey ?? ""
            }
        }
    }

    /// Progress and controls for the background index of other apps' containers.
    @ViewBuilder private var appIndexSection: some View {
        let index = model.containerIndex
        Section {
            switch index.status {
            case .unavailable:
                Text("Not available on this device.")
                    .foregroundStyle(.secondary)
            case let .indexing(found, _, _):
                // Apps cluster in low inodes, so nearly all are found in the first moments; the rest of the scan is a
                // background sweep of empty inode space to catch any recently-installed app. Lead with the found count
                // (the value, delivered fast) and present the sweep as a secondary completeness check.
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(found) apps found")
                    if let fraction = index.fractionComplete {
                        ProgressView(value: fraction) {
                            Text("Checking for recently-installed apps…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Starting…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            case .ready:
                if let lastIndexed = index.lastIndexed {
                    Text("Last indexed \(lastIndexed.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not indexed yet.")
                        .foregroundStyle(.secondary)
                }
                Button("Reindex Apps") { index.reindex() }
            }
            if let error = index.errorMessage {
                Text(error).foregroundStyle(.red)
            }
        } header: {
            Text("App Index")
        } footer: {
            Text("The agent finds other apps by scanning once in the background; this can take a few minutes the first time. Later launches are instant and pick up newly installed apps automatically.")
        }
    }

    /// A picked provider brings its base URL; loading saved settings doesn't go through here.
    private func choose(_ preset: ProviderPreset) {
        guard preset != settings.preset else { return }
        let previous = settings.preset
        settings.preset = preset
        settings.baseURL = preset.baseURL
        if preset == .openCodeGo {
            settings.modelId = "glm-5.3-flash"
        } else if previous == .openCodeGo {
            settings.modelId = ""
        }
        availableModels = []
    }

    private func loadModels() {
        loadingModels = true
        modelListError = nil
        let baseURL = settings.baseURL
        let key = apiKey
        let preset = settings.preset
        Task {
            do {
                availableModels = try await fetchModelIds(baseURL: baseURL, apiKey: key, preset: preset)
                if availableModels.isEmpty { modelListError = "The server listed no models." }
            } catch {
                modelListError = error.localizedDescription
            }
            loadingModels = false
        }
    }

    private func save() {
        do {
            try model.save(settings: settings, apiKey: apiKey.isEmpty ? nil : apiKey)
            dismiss()
        } catch {
            saveError = "Couldn't save: \(error.localizedDescription)"
        }
    }
}

#endif
