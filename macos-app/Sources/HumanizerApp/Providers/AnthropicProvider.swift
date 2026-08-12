import Foundation

struct AnthropicProvider: Provider {
    let apiKey: String
    let model: String
    static let url = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2023-06-01"

    func complete(system: String, user: String, maxTokens: Int) async throws -> String {
        guard !apiKey.isEmpty else {
            throw ProviderError.message("No Claude API key set. Add one in the Settings tab, then try again.")
        }

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": user]],
        ]

        var request = URLRequest(url: Self.url, timeoutInterval: 180)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ProviderError.message("Could not reach the Claude API. Check your internet connection.")
        }

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.message("Could not reach the Claude API. Check your internet connection.")
        }
        guard http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw ProviderError.message(formatHTTPError(providerName: "Claude", statusCode: http.statusCode, detail: detail))
        }

        guard let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = body["content"] as? [[String: Any]] else {
            return ""
        }
        let text = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
