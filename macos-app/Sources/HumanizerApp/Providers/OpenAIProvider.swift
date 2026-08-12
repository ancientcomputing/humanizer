import Foundation

struct OpenAIProvider: Provider {
    let apiKey: String
    let model: String
    static let url = URL(string: "https://api.openai.com/v1/chat/completions")!

    func complete(system: String, user: String, maxTokens: Int) async throws -> String {
        guard !apiKey.isEmpty else {
            throw ProviderError.message("No OpenAI API key set. Add one in the Settings tab, then try again.")
        }

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]

        var request = URLRequest(url: Self.url, timeoutInterval: 180)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ProviderError.message("Could not reach the OpenAI API. Check your internet connection.")
        }

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.message("Could not reach the OpenAI API. Check your internet connection.")
        }
        guard http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw ProviderError.message(formatHTTPError(providerName: "OpenAI", statusCode: http.statusCode, detail: detail))
        }

        guard let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = body["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any] else {
            return ""
        }
        let text = (message["content"] as? String) ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
