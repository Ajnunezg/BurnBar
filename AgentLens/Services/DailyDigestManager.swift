import Foundation
import UserNotifications

@MainActor
protocol BurnBarUserNotificationCentering {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

@MainActor
private final class BurnBarUserNotificationCenterAdapter: BurnBarUserNotificationCentering {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func add(_ request: UNNotificationRequest) {
        center.add(request, withCompletionHandler: nil)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

@MainActor
final class DailyDigestManager {
    static let shared = DailyDigestManager()

    private let notificationCenter: any BurnBarUserNotificationCentering

    init(notificationCenter: any BurnBarUserNotificationCentering = BurnBarUserNotificationCenterAdapter()) {
        self.notificationCenter = notificationCenter
    }

    func requestAuthorization() async {
        _ = try? await notificationCenter.requestAuthorization(options: [.alert, .sound])
    }

    func scheduleDigest(from dataStore: DataStore, at hour: Int = 18) {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [BurnBarIdentity.dailyDigestNotificationIdentifier] + BurnBarIdentity.legacyDailyDigestNotificationIdentifiers
        )
        let narrative = InsightEngine.generateNarrative(from: dataStore)
        let content = UNMutableNotificationContent()
        content.title = "\(BurnBarIdentity.productName) Daily Digest"
        content.body = [narrative.headline, narrative.detail].compactMap { $0 }.joined(separator: " ")
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: BurnBarIdentity.dailyDigestNotificationIdentifier,
            content: content,
            trigger: trigger
        )
        notificationCenter.add(request)
    }

    func cancelDigest() {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [BurnBarIdentity.dailyDigestNotificationIdentifier] + BurnBarIdentity.legacyDailyDigestNotificationIdentifiers
        )
    }
}
