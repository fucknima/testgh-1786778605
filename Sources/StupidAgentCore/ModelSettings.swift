import Foundation
import PiAI
import PiTools

/// A server people commonly bring their own key for. `custom` is any other OpenAI-compatible server.
public enum ProviderPreset: String, CaseIterable, Codable, Sendable, Identifiable {
    case openAI
    case openCodeGo
    case openRouter
    case groq
    case deepSeek
    case ollama
    case lmStudio
    case custom

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .openAI: "OpenAI"
        case .openCodeGo: "OpenCode Go"
        case .openRouter: "OpenRouter"
        case .groq: "Groq"
        case .deepSeek: "DeepSeek"
        case .ollama: "Ollama"
        case .lmStudio: "LM Studio"
        case .custom: "Custom"
        }
    }

    /// The default base URL; for local servers, the computer's address must replace `localhost` on a phone.
    public var baseURL: String {
        switch self {
        case .openAI: "https://api.openai.com/v1"
        case .openCodeGo: "https://opencode.ai/inference/go/openai/v1"
        case .openRouter: "https://openrouter.ai/api/v1"
        case .groq: "https://api.groq.com/openai/v1"
        case .deepSeek: "https://api.deepseek.com/v1"
        case .ollama: "http://localhost:11434/v1"
        case .lmStudio: "http://localhost:1234/v1"
        case .custom: ""
        }
    }

    /// The provider id swift pi uses for compatibility detection.
    public var providerId: String {
        switch self {
        case .openAI: "openai"
        case .openCodeGo: "opencode-go"
        case .openRouter: "openrouter"
        case .groq: "groq"
        case .deepSeek: "deepseek"
        case .ollama: "ollama"
        case .lmStudio: "lmstudio"
        case .custom: "custom"
        }
    }

    public var needsAPIKey: Bool {
        switch self {
        // A custom server may be local or keyless; it answers 401 if it wants one.
        case .ollama, .lmStudio, .custom: false
        default: true
        }
    }
}

/// The model the user brought: where it is and how to talk to it. The API key is stored apart, in the Keychain.
public struct ModelSettings: Codable, Hashable, Sendable {
    public var preset: ProviderPreset
    public var baseURL: String
    public var modelId: String
    /// Whether the model reasons, so a thinking level is sent.
    public var reasoning: Bool
    public var thinkingLevel: ThinkingLevel
    /// Whether the model takes images, so images the agent reads are attached.
    public var acceptsImages: Bool
    /// Whether the agent asks before it creates or changes a file.
    public var confirmFileChanges: Bool
    /// Whether the agent can read and write files in other apps' containers.
    public var allowOtherApps: Bool
    /// Models chosen before, most recent first, for the composer's model menu.
    public var recentModelIds: [String]
    /// Where the web_search tool searches.
    public var webSearchProvider: WebSearchProvider

    /// How many models the model menu keeps.
    public static let recentLimit = 6

    public init(
        preset: ProviderPreset = .openRouter,
        baseURL: String? = nil,
        modelId: String = "",
        reasoning: Bool = false,
        thinkingLevel: ThinkingLevel = .medium,
        acceptsImages: Bool = false,
        confirmFileChanges: Bool = true,
        allowOtherApps: Bool = false,
        recentModelIds: [String] = [],
        webSearchProvider: WebSearchProvider = .exa
    ) {
        self.preset = preset
        self.baseURL = baseURL ?? preset.baseURL
        self.modelId = modelId
        self.reasoning = reasoning
        self.thinkingLevel = thinkingLevel
        self.acceptsImages = acceptsImages
        self.confirmFileChanges = confirmFileChanges
        self.allowOtherApps = allowOtherApps
        self.recentModelIds = recentModelIds
        self.webSearchProvider = webSearchProvider
    }

    private enum CodingKeys: String, CodingKey {
        case preset, baseURL, modelId, reasoning, thinkingLevel, acceptsImages, confirmFileChanges, allowOtherApps, recentModelIds, webSearchProvider
    }

    // Settings saved before a field existed decode with its default, so an update keeps them.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let preset = try container.decode(ProviderPreset.self, forKey: .preset)
        self.init(
            preset: preset,
            baseURL: try container.decodeIfPresent(String.self, forKey: .baseURL),
            modelId: try container.decodeIfPresent(String.self, forKey: .modelId) ?? "",
            reasoning: try container.decodeIfPresent(Bool.self, forKey: .reasoning) ?? false,
            thinkingLevel: try container.decodeIfPresent(ThinkingLevel.self, forKey: .thinkingLevel) ?? .medium,
            acceptsImages: try container.decodeIfPresent(Bool.self, forKey: .acceptsImages) ?? false,
            confirmFileChanges: try container.decodeIfPresent(Bool.self, forKey: .confirmFileChanges) ?? true,
            allowOtherApps: try container.decodeIfPresent(Bool.self, forKey: .allowOtherApps) ?? false,
            recentModelIds: try container.decodeIfPresent([String].self, forKey: .recentModelIds) ?? [],
            webSearchProvider: try container.decodeIfPresent(WebSearchProvider.self, forKey: .webSearchProvider) ?? .exa
        )
    }

    /// Switches to a model and puts it first among the recent ones.
    public mutating func select(modelId: String) {
        let id = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        // The model being left stays in the menu, even when it was set before recent models were kept.
        rememberModel()
        self.modelId = id
        rememberModel()
    }

    /// Puts the current model first among the recent ones, such as after it was set in Settings.
    public mutating func rememberModel() {
        let id = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        recentModelIds = Array(([id] + recentModelIds.filter { $0 != id }).prefix(Self.recentLimit))
    }

    /// The recent models with the current one among them, most recent first.
    public var menuModelIds: [String] {
        let current = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !current.isEmpty, !recentModelIds.contains(current) else { return recentModelIds }
        return [current] + recentModelIds
    }

    /// Whether enough is set to send a request.
    public func isComplete(apiKey: String?) -> Bool {
        !modelId.trimmingCharacters(in: .whitespaces).isEmpty
            && URL(string: baseURL.trimmingCharacters(in: .whitespaces))?.scheme?.hasPrefix("http") == true
            && (!preset.needsAPIKey || !(apiKey ?? "").isEmpty)
    }

    public var model: Model {
        Model(
            id: modelId.trimmingCharacters(in: .whitespaces),
            provider: preset.providerId,
            baseURL: baseURL.trimmingCharacters(in: .whitespaces),
            reasoning: reasoning,
            input: acceptsImages ? [.text, .image] : [.text]
        )
    }
}

/// A model id's short name for tight spaces: what follows the vendor prefix (`openai/gpt-4o-mini` → `gpt-4o-mini`).
public func shortModelName(_ id: String) -> String {
    id.split(separator: "/").last.map(String.init) ?? id
}

/// Settings persisted in user defaults, the key in the Keychain.
public struct SettingsStore {
    private static let settingsKey = "modelSettings"
    private static let apiKeyAccount = "apiKey"

    private let defaults: UserDefaults
    private let keychain: Keychain

    public init(defaults: UserDefaults = .standard, keychain: Keychain = Keychain(service: "net.stupidtech.StupidAgent")) {
        self.defaults = defaults
        self.keychain = keychain
    }

    public func load() -> ModelSettings {
        guard let data = defaults.data(forKey: Self.settingsKey),
              let settings = try? JSONDecoder().decode(ModelSettings.self, from: data) else { return ModelSettings() }
        return settings
    }

    public func save(_ settings: ModelSettings) throws {
        defaults.set(try JSONEncoder().encode(settings), forKey: Self.settingsKey)
    }

    public func apiKey() -> String? {
        #if targetEnvironment(simulator)
        defaults.string(forKey: Self.simulatorAPIKeyKey)
        #else
        keychain.read(account: Self.apiKeyAccount)
        #endif
    }

    public func setAPIKey(_ key: String?) throws {
        #if targetEnvironment(simulator)
        // Simulator builds are ad-hoc signed without Keychain access (errSecMissingEntitlement), so the key lives in
        // user defaults there. Device builds only ever use the Keychain.
        defaults.set(key?.isEmpty == false ? key : nil, forKey: Self.simulatorAPIKeyKey)
        #else
        if let key, !key.isEmpty {
            try keychain.write(key, account: Self.apiKeyAccount)
        } else {
            try keychain.delete(account: Self.apiKeyAccount)
        }
        #endif
    }

    private static let simulatorAPIKeyKey = "simulatorAPIKey"
}

/// OpenCode Go publishes the model catalog separately from the chat-completions endpoint.
public func modelListURL(baseURL: String, preset: ProviderPreset? = nil) -> URL? {
    var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    while base.hasSuffix("/") { base.removeLast() }
    if preset == .openCodeGo || base.hasPrefix("https://opencode.ai/inference/go/") {
        return URL(string: "https://opencode.ai/inference/go/v1/models")
    }
    return URL(string: base + "/models")
}

/// The model ids advertised by the selected provider.
public func fetchModelIds(baseURL: String, apiKey: String?, preset: ProviderPreset? = nil, session: URLSession = .shared) async throws -> [String] {
    guard let url = modelListURL(baseURL: baseURL, preset: preset) else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.timeoutInterval = 20
    if preset == .openCodeGo { request.setValue("stupid-agent-ios/1.0", forHTTPHeaderField: "User-Agent") }
    if let apiKey, !apiKey.isEmpty {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }
    let (data, response) = try await session.data(for: request)
    if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
        throw ModelListError(status: http.statusCode)
    }
    let json = try JSONValue.parse(String(decoding: data, as: UTF8.self))
    let ids = (json["data"]?.arrayValue ?? json["models"]?.arrayValue ?? []).compactMap { $0["id"]?.stringValue }
    return ids.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
}

public struct ModelListError: Error, LocalizedError {
    public let status: Int
    public var errorDescription: String? { "The server answered \(status) when listing models." }
}
