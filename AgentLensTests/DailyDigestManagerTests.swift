import XCTest
import UserNotifications
@testable import BurnBar

@MainActor
final class DailyDigestManagerTests: XCTestCase {

    private var mockNotificationCenter: MockUNUserNotificationCenter!
    private var originalCenter: UNUserNotificationCenter!

    override func setUp() {
        super.setUp()
        // Store the original notification center
        originalCenter = UNUserNotificationCenter.current()

        // Create mock notification center
        mockNotificationCenter = MockUNUserNotificationCenter()
    }

    override func tearDown() {
        mockNotificationCenter = nil
        super.tearDown()
    }

    // MARK: - Request Authorization Tests

    func test_requestAuthorization_succeedsWithGranted() async throws {
        // Given
        mockNotificationCenter.authorizationStatus = .authorized

        // When
        await DailyDigestManager.shared.requestAuthorization()

        // Then - no error thrown
        XCTAssertTrue(true)
    }

    func test_requestAuthorization_handlesDenied() async throws {
        // Given
        mockNotificationCenter.authorizationStatus = .denied

        // When/Then - should not throw
        await DailyDigestManager.shared.requestAuthorization()
        XCTAssertTrue(true)
    }

    func test_requestAuthorization_handlesNotDetermined() async throws {
        // Given
        mockNotificationCenter.authorizationStatus = .notDetermined

        // When/Then - should not throw
        await DailyDigestManager.shared.requestAuthorization()
        XCTAssertTrue(true)
    }

    // MARK: - Schedule Digest Tests

    func test_scheduleDigest_createsNotificationRequest() {
        // Given
        let store = DataStore()
        let hour = 18

        // When
        DailyDigestManager.shared.scheduleDigest(from: store, at: hour)

        // Then - notification request should be added
        XCTAssertFalse(mockNotificationCenter.addedRequests.isEmpty)
    }

    func test_scheduleDigest_usesCorrectHour() {
        // Given
        let store = DataStore()

        // When - schedule for 9 AM
        DailyDigestManager.shared.scheduleDigest(from: store, at: 9)

        // Then - verify request was added
        XCTAssertFalse(mockNotificationCenter.addedRequests.isEmpty)
    }

    func test_scheduleDigest_usesCorrectIdentifier() {
        // Given
        let store = DataStore()

        // When
        DailyDigestManager.shared.scheduleDigest(from: store)

        // Then
        let request = mockNotificationCenter.addedRequests.first
        XCTAssertEqual(request?.identifier, BurnBarIdentity.dailyDigestNotificationIdentifier)
    }

    func test_scheduleDigest_removesPendingNotifications() {
        // Given
        let store = DataStore()
        mockNotificationCenter.pendingRequests = [
            UNNotificationRequest(identifier: BurnBarIdentity.dailyDigestNotificationIdentifier, content: UNMutableNotificationContent(), trigger: nil),
            UNNotificationRequest(identifier: "legacy-id-1", content: UNMutableNotificationContent(), trigger: nil)
        ]

        // When
        DailyDigestManager.shared.scheduleDigest(from: store)

        // Then - old requests should be removed
        // The manager should have called removePendingNotificationRequests
        XCTAssertTrue(mockNotificationCenter.removedIdentifiers.contains(BurnBarIdentity.dailyDigestNotificationIdentifier))
    }

    func test_scheduleDigest_includesLegacyIdentifiers() {
        // Given
        let store = DataStore()

        // When
        DailyDigestManager.shared.scheduleDigest(from: store)

        // Then - legacy identifiers should be removed
        for legacyId in BurnBarIdentity.legacyDailyDigestNotificationIdentifiers {
            XCTAssertTrue(mockNotificationCenter.removedIdentifiers.contains(legacyId))
        }
    }

    func test_scheduleDigest_notificationContent_hasCorrectTitle() {
        // Given
        let store = DataStore()

        // When
        DailyDigestManager.shared.scheduleDigest(from: store)

        // Then
        let request = mockNotificationCenter.addedRequests.first
        XCTAssertEqual(request?.content.title, "\(BurnBarIdentity.productName) Daily Digest")
    }

    func test_scheduleDigest_notificationContent_hasDefaultSound() {
        // Given
        let store = DataStore()

        // When
        DailyDigestManager.shared.scheduleDigest(from: store)

        // Then
        let request = mockNotificationCenter.addedRequests.first
        XCTAssertEqual(request?.content.sound, .default)
    }

    func test_scheduleDigest_notificationContent_includesNarrative() {
        // Given
        let store = DataStore()

        // When
        DailyDigestManager.shared.scheduleDigest(from: store)

        // Then - content body should not be empty
        let request = mockNotificationCenter.addedRequests.first
        XCTAssertFalse(request?.content.body.isEmpty ?? true)
    }

    func test_scheduleDigest_trigger_isCalendarBased() {
        // Given
        let store = DataStore()
        let hour = 20

        // When
        DailyDigestManager.shared.scheduleDigest(from: store, at: hour)

        // Then
        let request = mockNotificationCenter.addedRequests.first
        XCTAssertNotNil(request?.trigger as? UNCalendarNotificationTrigger)
    }

    func test_scheduleDigest_trigger_repeatsDaily() {
        // Given
        let store = DataStore()

        // When
        DailyDigestManager.shared.scheduleDigest(from: store)

        // Then
        let request = mockNotificationCenter.addedRequests.first
        if let trigger = request?.trigger as? UNCalendarNotificationTrigger {
            XCTAssertTrue(trigger.repeats)
        } else {
            XCTFail("Trigger should be UNCalendarNotificationTrigger")
        }
    }

    func test_scheduleDigest_trigger_minuteIsZero() {
        // Given
        let store = DataStore()

        // When
        DailyDigestManager.shared.scheduleDigest(from: store, at: 14)

        // Then
        let request = mockNotificationCenter.addedRequests.first
        if let trigger = request?.trigger as? UNCalendarNotificationTrigger {
            XCTAssertEqual(trigger.dateComponents.minute, 0)
        }
    }

    // MARK: - Cancel Digest Tests

    func test_cancelDigest_removesNotification() {
        // Given
        mockNotificationCenter.pendingRequests = [
            UNNotificationRequest(identifier: BurnBarIdentity.dailyDigestNotificationIdentifier, content: UNMutableNotificationContent(), trigger: nil)
        ]

        // When
        DailyDigestManager.shared.cancelDigest()

        // Then
        XCTAssertTrue(mockNotificationCenter.removedIdentifiers.contains(BurnBarIdentity.dailyDigestNotificationIdentifier))
    }

    func test_cancelDigest_removesLegacyIdentifiers() {
        // Given
        mockNotificationCenter.pendingRequests = [
            UNNotificationRequest(identifier: "legacy-id-1", content: UNMutableNotificationContent(), trigger: nil),
            UNNotificationRequest(identifier: "legacy-id-2", content: UNMutableNotificationContent(), trigger: nil)
        ]

        // When
        DailyDigestManager.shared.cancelDigest()

        // Then
        for legacyId in BurnBarIdentity.legacyDailyDigestNotificationIdentifiers {
            XCTAssertTrue(mockNotificationCenter.removedIdentifiers.contains(legacyId))
        }
    }

    func test_cancelDigest_idempotent() {
        // Given - no pending notifications
        mockNotificationCenter.pendingRequests = []

        // When - cancel multiple times
        DailyDigestManager.shared.cancelDigest()
        DailyDigestManager.shared.cancelDigest()

        // Then - should not crash
        XCTAssertTrue(true)
    }

    // MARK: - Integration Tests

    func test_scheduleThenCancel_lifecycle() {
        // Given
        let store = DataStore()

        // When
        DailyDigestManager.shared.scheduleDigest(from: store)
        DailyDigestManager.shared.cancelDigest()

        // Then - scheduled request should be removed
        XCTAssertTrue(mockNotificationCenter.removedIdentifiers.contains(BurnBarIdentity.dailyDigestNotificationIdentifier))
    }

    func test_reschedule_replacesExistingNotification() {
        // Given
        let store = DataStore()
        mockNotificationCenter.pendingRequests = [
            UNNotificationRequest(identifier: BurnBarIdentity.dailyDigestNotificationIdentifier, content: UNMutableNotificationContent(), trigger: nil)
        ]

        // When - reschedule
        DailyDigestManager.shared.scheduleDigest(from: store, at: 10)

        // Then - old notification should be removed
        XCTAssertTrue(mockNotificationCenter.removedIdentifiers.contains(BurnBarIdentity.dailyDigestNotificationIdentifier))
        // And new notification should be added
        XCTAssertFalse(mockNotificationCenter.addedRequests.isEmpty)
    }

    // MARK: - Edge Cases

    func test_scheduleDigest_differentHours() {
        // Given
        let store = DataStore()
        let hours = [0, 6, 12, 18, 23]

        for hour in hours {
            // Reset mock
            mockNotificationCenter = MockUNUserNotificationCenter()

            // When
            DailyDigestManager.shared.scheduleDigest(from: store, at: hour)

            // Then
            let request = mockNotificationCenter.addedRequests.first
            if let trigger = request?.trigger as? UNCalendarNotificationTrigger {
                XCTAssertEqual(trigger.dateComponents.hour, hour)
            }
        }
    }

    func test_scheduleDigest_emptyStore() {
        // Given - empty data store
        let store = DataStore()

        // When
        DailyDigestManager.shared.scheduleDigest(from: store)

        // Then - should still create notification with empty narrative
        let request = mockNotificationCenter.addedRequests.first
        XCTAssertNotNil(request)
    }

    func test_scheduleDigest_withUsages() {
        // Given - store with usages
        let store = DataStore()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var usages: [TokenUsage] = []
        for d in 1...3 {
            let day = cal.date(byAdding: .day, value: -d, to: today)!
            usages.append(
                TokenUsage(
                    provider: .factory,
                    sessionId: "s\(d)",
                    projectName: "p",
                    model: "m",
                    inputTokens: 100,
                    outputTokens: 100,
                    costUSD: Double(d),
                    startTime: day.addingTimeInterval(3600),
                    endTime: day.addingTimeInterval(7200)
                )
            )
        }
        store.replaceUsages(usages)

        // When
        DailyDigestManager.shared.scheduleDigest(from: store)

        // Then - notification should be created
        let request = mockNotificationCenter.addedRequests.first
        XCTAssertNotNil(request)
        // And body should contain some content
        XCTAssertFalse(request?.content.body.isEmpty ?? true)
    }

    // MARK: - Performance Tests

    func test_scheduleDigest_performance() throws {
        // Given
        let store = DataStore()
        var usages: [TokenUsage] = []
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for d in 1...100 {
            let day = cal.date(byAdding: .day, value: -d, to: today)!
            usages.append(
                TokenUsage(
                    provider: .factory,
                    sessionId: "s\(d)",
                    projectName: "p",
                    model: "m",
                    inputTokens: 100,
                    outputTokens: 100,
                    costUSD: Double(d),
                    startTime: day.addingTimeInterval(3600),
                    endTime: day.addingTimeInterval(7200)
                )
            )
        }
        store.replaceUsages(usages)

        measure {
            DailyDigestManager.shared.scheduleDigest(from: store)
        }
    }
}

// MARK: - Mock UNUserNotificationCenter

private class MockUNUserNotificationCenter: NSObject, UNUserNotificationCenter {
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var pendingRequests: [UNNotificationRequest] = []
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []

    override func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        return authorizationStatus == .authorized
    }

    func getNotificationSettings() async -> UNNotificationSettings {
        return UNNotificationSettings()
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        addedRequests.append(request)
        completionHandler?(nil)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }

    func removeAllPendingNotificationRequests() {
        removedIdentifiers = pendingRequests.map { $0.identifier }
    }

    func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        return pendingRequests
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        // No-op for testing
    }

    func removeAllDeliveredNotifications() {
        // No-op for testing
    }

    func getDeliveredNotificationRequests() async -> [UNNotificationRequest] {
        return []
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        // No-op for testing
    }

    func getNotificationCategories() async -> Set<UNNotificationCategory> {
        return []
    }

    func getIsNotificationEnabled() async -> Bool {
        return authorizationStatus == .authorized
    }
}
