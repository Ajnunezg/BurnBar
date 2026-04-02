import Foundation

enum QuotaServiceError: LocalizedError {
    case httpStatus(provider: AgentProvider, code: Int)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case let .httpStatus(provider, code):
            return "\(provider.displayName) quota request failed with HTTP \(code)."
        case let .invalidResponse(message):
            return message
        }
    }
}
