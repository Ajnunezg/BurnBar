import Foundation
import UserNotifications

protocol BurnBarUserNotificationCentering {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: BurnBarUserNotificationCentering {}

@MainActor
final class DailyDigestManager {
    static let shared = DailyDigestManager()

    private let notificationCenter: any BurnBarUserNotificationCentering

    init(notificationCenter: any BurnBarUserNotificationCentering = UNUserNotificationCenter.current()) {
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
        notificationCenter.add(request, withCompletionHandler: nil)
    }

    func cancelDigest() {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [BurnBarIdentity.dailyDigestNotificationIdentifier] + BurnBarIdentity.legacyDailyDigestNotificationIdentifiers
        )
    }
}
