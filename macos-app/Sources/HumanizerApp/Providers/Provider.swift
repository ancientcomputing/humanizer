import Foundation

enum ProviderError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

protocol Provider: Sendable {
    func complete(system: String, user: String, maxTokens: Int) async throws -> String
}

func formatHTTPError(providerName: String, statusCode: Int, detail: String) -> String {
    var message: String?
    if let data = detail.data(using: .utf8),
       let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let errorObj = parsed["error"] as? [String: Any] {
            message = errorObj["message"] as? String
        } else {
            message = parsed["message"] as? String
        }
    }

    switch statusCode {
    case 401:
        return "\(providerName) rejected the API key. Check it in the Settings tab."
    case 404:
        return "\(providerName) could not find the configured model. Check it in the Settings tab."
    case 429:
        return "\(providerName) rate-limited this request. Try again in a moment."
    default:
        return "\(providerName) API error \(statusCode): \(message ?? "No details provided.")"
    }
}
