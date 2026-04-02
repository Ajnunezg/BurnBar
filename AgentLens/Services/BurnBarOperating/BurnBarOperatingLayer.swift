import Foundation
import SwiftUI

// MARK: - Operating Layer Store

@MainActor
@Observable
final class BurnBarOperatingLayer {
    let dataStore: DataStore
    let settingsManager: SettingsManager
    let accountManager: AccountManager
    let daemonManager: BurnBarDaemonManager

    var aggregator: UsageAggregator?
    var chatController: ChatSessionController?

    var stateRevision: Int = 0

    internal(set) var actionFeedback: BurnBarActionFeedback?
    internal(set) var controllerFeedback: BurnBarControllerFeedback?

    init(
        dataStore: DataStore,
        settingsManager: SettingsManager = .shared,
        accountManager: AccountManager = .shared,
        daemonManager: BurnBarDaemonManager = .shared,
        aggregator: UsageAggregator? = nil,
        chatController: ChatSessionController? = nil
    ) {
        self.dataStore = dataStore
        self.settingsManager = settingsManager
        self.accountManager = accountManager
        self.daemonManager = daemonManager
        self.aggregator = aggregator
        self.chatController = chatController
    }

    var snapshot: BurnBarOperatingSnapshot {
        _ = stateRevision
        let actionRecords = (try? dataStore.fetchOperatingActionRecords(limit: 200)) ?? []
        let cachedControllerRuntime = (try? dataStore.fetchControllerRuntimeMirror()) ?? nil
        return BurnBarOperatingComposer.build(
            dataStore: dataStore,
            settingsManager: settingsManager,
            accountManager: accountManager,
            daemonStatus: daemonManager.status,
            aggregator: aggregator,
            chatController: chatController,
            actionRecords: actionRecords,
            cachedControllerRuntime: cachedControllerRuntime
        )
    }

    func clearActionFeedback() {
        actionFeedback = nil
    }

    func clearControllerFeedback() {
        controllerFeedback = nil
    }
}
