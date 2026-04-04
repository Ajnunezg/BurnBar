import Foundation
import SwiftUI

// Runtime operating layer: models and composition live alongside this type in `BurnBarOperating/`
// (`BurnBarOperatingModels`, `OpenBurnBarOperatingComposer`, `OpenBurnBarOperatingLayer+MissionActions`, …).
// `Services/OpenBurnBarOperatingLayer.swift` is excluded from the app target (reference-only twin); do not
// add it back without deleting that duplicate.

// MARK: - Operating Layer Store

@MainActor
@Observable
final class OpenBurnBarOperatingLayer {
    let dataStore: DataStore
    let settingsManager: SettingsManager
    let accountManager: AccountManager
    let daemonManager: OpenBurnBarDaemonManager

    var aggregator: UsageAggregator?
    var chatController: ChatSessionController?

    var stateRevision: Int = 0

    var actionFeedback: OpenBurnBarActionFeedback?
    var controllerFeedback: OpenBurnBarControllerFeedback?

    init(
        dataStore: DataStore,
        settingsManager: SettingsManager = .shared,
        accountManager: AccountManager = .shared,
        daemonManager: OpenBurnBarDaemonManager = .shared,
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

    var snapshot: OpenBurnBarOperatingSnapshot {
        _ = stateRevision
        let actionRecords = (try? dataStore.fetchOperatingActionRecords(limit: 200)) ?? []
        let cachedControllerRuntime = (try? dataStore.fetchControllerRuntimeMirror()) ?? nil
        return OpenBurnBarOperatingComposer.build(
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
