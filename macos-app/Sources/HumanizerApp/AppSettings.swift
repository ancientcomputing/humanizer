import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    @Published var provider: LLMProvider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: Keys.provider) }
    }
    @Published var anthropicModel: String {
        didSet { UserDefaults.standard.set(anthropicModel, forKey: Keys.anthropicModel) }
    }
    @Published var openAIModel: String {
        didSet { UserDefaults.standard.set(openAIModel, forKey: Keys.openAIModel) }
    }
    @Published var maxTokens: Int {
        didSet { UserDefaults.standard.set(maxTokens, forKey: Keys.maxTokens) }
    }
    @Published var mismatchThreshold: Double {
        didSet { UserDefaults.standard.set(mismatchThreshold, forKey: Keys.mismatchThreshold) }
    }

    // API keys live only in the Keychain, never in UserDefaults.
    var anthropicAPIKey: String {
        get { KeychainStore.get(account: "anthropic") ?? "" }
        set { _ = setAnthropicAPIKey(newValue) }
    }

    var openAIAPIKey: String {
        get { KeychainStore.get(account: "openai") ?? "" }
        set { _ = setOpenAIAPIKey(newValue) }
    }

    /// Returns false if the Keychain write failed, so the caller can tell the user
    /// the key was NOT actually saved instead of assuming success.
    @discardableResult
    func setAnthropicAPIKey(_ value: String) -> Bool {
        let ok = value.isEmpty ? KeychainStore.remove(account: "anthropic") : KeychainStore.set(value, account: "anthropic")
        objectWillChange.send()
        return ok
    }

    @discardableResult
    func setOpenAIAPIKey(_ value: String) -> Bool {
        let ok = value.isEmpty ? KeychainStore.remove(account: "openai") : KeychainStore.set(value, account: "openai")
        objectWillChange.send()
        return ok
    }

    var anthropicKeySet: Bool { !anthropicAPIKey.isEmpty }
    var openAIKeySet: Bool { !openAIAPIKey.isEmpty }

    private enum Keys {
        static let provider = "humanizer.provider"
        static let anthropicModel = "humanizer.anthropicModel"
        static let openAIModel = "humanizer.openAIModel"
        static let maxTokens = "humanizer.maxTokens"
        static let mismatchThreshold = "humanizer.mismatchThreshold"
    }

    init() {
        let defaults = UserDefaults.standard
        provider = LLMProvider(rawValue: defaults.string(forKey: Keys.provider) ?? "") ?? .anthropic
        anthropicModel = defaults.string(forKey: Keys.anthropicModel) ?? "claude-sonnet-4-5"
        openAIModel = defaults.string(forKey: Keys.openAIModel) ?? "gpt-4o"
        let storedMaxTokens = defaults.integer(forKey: Keys.maxTokens)
        maxTokens = storedMaxTokens > 0 ? storedMaxTokens : 4000
        let storedThreshold = defaults.double(forKey: Keys.mismatchThreshold)
        mismatchThreshold = storedThreshold > 0 ? storedThreshold : 0.35
    }

    var hasAnyKeySet: Bool { anthropicKeySet || openAIKeySet }

    func makeProvider() -> Provider {
        switch provider {
        case .anthropic:
            return AnthropicProvider(apiKey: anthropicAPIKey, model: anthropicModel)
        case .openai:
            return OpenAIProvider(apiKey: openAIAPIKey, model: openAIModel)
        }
    }
}
