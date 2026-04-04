import Foundation

// MARK: - Thread-Safe Date Formatter

/// A thread-safe wrapper around ISO8601DateFormatter instances.
///
/// `ISO8601DateFormatter` is documented as not being thread-safe. This actor
/// provides safe concurrent access to formatter instances by serializing
/// access through actor isolation.
///
/// Usage:
/// ```swift
/// let date = await ThreadSafeISO8601DateFormatter.shared.parseFractionalOrBasic(string)
/// ```
public actor ThreadSafeISO8601DateFormatter {

    // MARK: - Singleton Access

    /// Shared singleton instance for convenience.
    public static let shared = ThreadSafeISO8601DateFormatter()

    // MARK: - Formatter Instances

    /// ISO8601 formatter with fractional seconds support.
    private let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// ISO8601 formatter without fractional seconds.
    private let basicFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Parsing

    /// Parses an ISO8601 string, trying fractional seconds first, then basic format.
    /// - Parameter string: The ISO8601-formatted date string.
    /// - Returns: A `Date` if parsing succeeds, `nil` otherwise.
    public func parseFractionalOrBasic(_ string: String) -> Date? {
        if let date = fractionalFormatter.date(from: string) {
            return date
        }
        return basicFormatter.date(from: string)
    }

    /// Parses an ISO8601 string with fractional seconds.
    /// - Parameter string: The ISO8601-formatted date string with fractional seconds.
    /// - Returns: A `Date` if parsing succeeds, `nil` otherwise.
    public func parseFractional(_ string: String) -> Date? {
        fractionalFormatter.date(from: string)
    }

    /// Parses an ISO8601 string without fractional seconds.
    /// - Parameter string: The ISO8601-formatted date string without fractional seconds.
    /// - Returns: A `Date` if parsing succeeds, `nil` otherwise.
    public func parseBasic(_ string: String) -> Date? {
        basicFormatter.date(from: string)
    }

    // MARK: - Formatting

    /// Formats a date as an ISO8601 string with fractional seconds.
    /// - Parameter date: The date to format.
    /// - Returns: An ISO8601-formatted string with fractional seconds.
    public func formatFractional(_ date: Date) -> String {
        fractionalFormatter.string(from: date)
    }

    /// Formats a date as an ISO8601 string without fractional seconds.
    /// - Parameter date: The date to format.
    /// - Returns: An ISO8601-formatted string without fractional seconds.
    public func formatBasic(_ date: Date) -> String {
        basicFormatter.string(from: date)
    }
}

// MARK: - Synchronous Convenience Methods

/// Extension providing non-isolated, synchronous access to thread-safe date parsing.
///
/// These methods create temporary formatter instances for one-off use.
/// They are thread-safe but less efficient than using the actor directly for batch operations.
extension ThreadSafeISO8601DateFormatter {

    /// Synchronously parses an ISO8601 string, trying fractional first then basic.
    /// Creates a temporary formatter for this operation.
    ///
    /// - Parameter string: The ISO8601-formatted date string.
    /// - Returns: A `Date` if parsing succeeds, `nil` otherwise.
    public static func parse(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
