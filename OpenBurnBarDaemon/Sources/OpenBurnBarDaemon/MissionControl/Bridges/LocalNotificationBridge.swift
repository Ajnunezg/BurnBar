import Foundation
import UserNotifications

actor BurnBarLocalNotificationBridge {
    static let shared = BurnBarLocalNotificationBridge()

    func deliver(title: String, body: String) async throws {
        guard Self.shouldUseUserNotificationCenter else {
            return
        }

        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else {
            throw NSError(
                domain: "BurnBarMissionControlTransport",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Notification authorization denied for OpenBurnBar daemon."]
            )
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// `UNUserNotificationCenter` raises if the process has no usable app bundle (SwiftPM test runner, bare tools).
    private static var shouldUseUserNotificationCenter: Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return false
        }
        let path = Bundle.main.bundleURL.path
        if path.contains("/Developer/usr/bin") { return false }
        if path.contains("/Developer/Toolchains/") { return false }
        if Bundle.main.bundleIdentifier == nil { return false }
        return true
    }
}
