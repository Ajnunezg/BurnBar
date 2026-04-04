import Foundation

// MARK: - Codex rollout / rate-limit wire models (used by ProviderQuotaService)

extension ProviderQuotaService {
    struct CodexRateLimitEvent: Codable, Equatable, Sendable {
        let timestamp: Date
        let planType: String?
        let primary: CodexRateLimitWindow?
        let secondary: CodexRateLimitWindow?
    }

    struct CodexRateLimitWindow: Codable, Equatable, Sendable {
        let usedPercent: Double?
        let windowMinutes: Int?
        let resetsAt: Date?
    }

    struct CodexRolloutFileSignature: Codable, Equatable, Sendable {
        let modifiedAt: TimeInterval
        let sizeBytes: Int64
    }

    struct CodexRolloutFileCacheEntry: Codable, Equatable, Sendable {
        let signature: CodexRolloutFileSignature
        let latestRateLimitEvent: CodexRateLimitEvent?
    }

    struct CodexRolloutScanCache: Codable, Equatable, Sendable {
        var schemaVersion: Int
        var fileEntries: [String: CodexRolloutFileCacheEntry]
        var latestRateLimitEvent: CodexRateLimitEvent?
        var lastUpdatedAt: Date?

        static let empty = CodexRolloutScanCache(
            schemaVersion: 1,
            fileEntries: [:],
            latestRateLimitEvent: nil,
            lastUpdatedAt: nil
        )
    }

    struct CodexRateLimitScanResult: Sendable {
        let latestEvent: CodexRateLimitEvent?
        let cache: CodexRolloutScanCache
        let didChangeCache: Bool
    }

    struct CodexRolloutEnvelope: Decodable {
        let timestamp: Date
        let type: String
        let payload: Payload

        struct Payload: Decodable {
            let type: String
            let rateLimits: RateLimits

            enum CodingKeys: String, CodingKey {
                case type
                case rateLimits = "rate_limits"
            }

            struct RateLimits: Decodable {
                let primary: Window?
                let secondary: Window?
                let planType: String?

                enum CodingKeys: String, CodingKey {
                    case primary
                    case secondary
                    case planType = "plan_type"
                }
            }

            struct Window: Decodable {
                let usedPercent: Double?
                let windowMinutes: Int?
                let resetsAt: Date?

                enum CodingKeys: String, CodingKey {
                    case usedPercent = "used_percent"
                    case windowMinutes = "window_minutes"
                    case resetsAt = "resets_at"
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    usedPercent = try container.decodeIfPresent(Double.self, forKey: .usedPercent)
                    windowMinutes = try container.decodeIfPresent(Int.self, forKey: .windowMinutes)

                    if let unixSeconds = try container.decodeIfPresent(Double.self, forKey: .resetsAt) {
                        resetsAt = Date(timeIntervalSince1970: unixSeconds)
                    } else if let stringValue = try container.decodeIfPresent(String.self, forKey: .resetsAt),
                              let parsed = Self.parseDateValue(stringValue) {
                        resetsAt = parsed
                    } else {
                        resetsAt = nil
                    }
                }

                private static func parseDateValue(_ value: String) -> Date? {
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let isoDate = isoFormatter.date(from: value) {
                        return isoDate
                    }
                    let isoFormatterWithoutFractionalSeconds = ISO8601DateFormatter()
                    isoFormatterWithoutFractionalSeconds.formatOptions = [.withInternetDateTime]
                    if let isoDate = isoFormatterWithoutFractionalSeconds.date(from: value) {
                        return isoDate
                    }
                    if let numeric = Double(value), numeric > 1_000_000_000_000 {
                        return Date(timeIntervalSince1970: numeric / 1000)
                    }
                    if let numeric = Double(value), numeric > 1_000_000_000 {
                        return Date(timeIntervalSince1970: numeric)
                    }
                    return nil
                }
            }
        }
    }
}
