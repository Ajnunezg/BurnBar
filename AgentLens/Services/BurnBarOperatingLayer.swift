import Foundation
import SwiftUI

// MARK: - Note
//
// This file is intentionally excluded from the `BurnBar.app` Xcode build target
// via `project.yml` (excludes: ["Services/BurnBarOperatingLayer.swift"]).
// The compiled operating layer lives in `Services/BurnBarOperating/BurnBarOperatingLayer.swift`.
// This file is kept in the repo for reference, diffing, and future potential integration.
// Do not add it back to the build without removing its twin.

// MARK: - Operating Layer Models

enum BurnBarOperatingAvailability: String, Equatable, Sendable {
    case available
    case sparse
    case missing

    var isRenderable: Bool {
        self != .missing
    }
}

enum BurnBarMissionLifecycle: String, Codable, Equatable, Sendable {
    case planned
    case running
    case partial
    case blocked
    case completed

    var label: String {
        switch self {
        case .planned: return "Planned"
        case .running: return "Running"
        case .partial: return "Partial"
        case .blocked: return "Blocked"
        case .completed: return "Completed"
        }
    }

    var color: Color {
        switch self {
        case .planned: return DesignSystem.Colors.textSecondary
        case .running: return DesignSystem.Colors.blaze
        case .partial: return DesignSystem.Colors.amber
        case .blocked: return DesignSystem.Colors.error
        case .completed: return DesignSystem.Colors.success
        }
    }
}

enum BurnBarMissionApprovalState: String, Codable, Equatable, Sendable {
    case pending
    case approved

    var label: String {
        switch self {
        case .pending: return "Needs approval"
        case .approved: return "Approved"
        }
    }

    var color: Color {
        switch self {
        case .pending: return DesignSystem.Colors.amber
        case .approved: return DesignSystem.Colors.success
        }
    }
}

enum BurnBarDirectionAssessment: String, Equatable, CaseIterable, Codable, Sendable {
    case aligned
    case drifting
    case ambiguous
    case notEnoughSignal = "not_enough_signal"

    var label: String {
        switch self {
        case .aligned: return "Aligned"
        case .drifting: return "Drifting"
        case .ambiguous: return "Ambiguous"
        case .notEnoughSignal: return "Not enough signal"
        }
    }

    var color: Color {
        switch self {
        case .aligned: return DesignSystem.Colors.success
        case .drifting: return DesignSystem.Colors.warning
        case .ambiguous: return DesignSystem.Colors.blaze
        case .notEnoughSignal: return DesignSystem.Colors.textSecondary
        }
    }
}

enum BurnBarDirectionMode: String, Equatable, Sendable {
    case inferred
    case sparse
    case overrideAnnotating = "override_annotating"
    case overrideSuperseding = "override_superseding"

    var label: String {
        switch self {
        case .inferred: return "Inferred"
        case .sparse: return "Sparse"
        case .overrideAnnotating: return "Annotated"
        case .overrideSuperseding: return "Overridden"
        }
    }
}

enum BurnBarFreshnessKind: String, Equatable, Sendable {
    case live
    case provisional
    case stale
    case missing

    var label: String {
        switch self {
        case .live: return "Fresh local signal"
        case .provisional: return "Provisional"
        case .stale: return "Stale"
        case .missing: return "Awaiting first scan"
        }
    }

    var color: Color {
        switch self {
        case .live: return DesignSystem.Colors.success
        case .provisional: return DesignSystem.Colors.amber
        case .stale: return DesignSystem.Colors.warning
        case .missing: return DesignSystem.Colors.textSecondary
        }
    }
}

enum BurnBarEvidenceFreshness: String, Equatable, Sendable {
    case fresh
    case stale
    case unknown

    var label: String {
        switch self {
        case .fresh: return "Fresh"
        case .stale: return "Stale"
        case .unknown: return "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .fresh: return DesignSystem.Colors.success
        case .stale: return DesignSystem.Colors.warning
        case .unknown: return DesignSystem.Colors.textSecondary
        }
    }
}

enum BurnBarActionKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case missionApproval = "mission_approval"
    case directionOverride = "direction_override"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .missionApproval: return "Approve Mission"
        case .directionOverride: return "Override Direction"
        }
    }

    var icon: String {
        switch self {
        case .missionApproval: return "checkmark.seal.fill"
        case .directionOverride: return "flag.fill"
        }
    }
}

enum BurnBarActionTone: Equatable, Sendable {
    case success
    case error
    case neutral

    var color: Color {
        switch self {
        case .success: return DesignSystem.Colors.success
        case .error: return DesignSystem.Colors.error
        case .neutral: return DesignSystem.Colors.textSecondary
        }
    }
}

enum BurnBarDirectionOverrideModeKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case annotate
    case supersedeStatus = "supersede_status"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .annotate: return "Annotate"
        case .supersedeStatus: return "Force status"
        }
    }
}

struct BurnBarMissionSummary: Equatable, Sendable {
    let availability: BurnBarOperatingAvailability
    let missionID: String
    let projectName: String
    let title: String
    let subtitle: String
    let state: BurnBarMissionLifecycle
    let approval: BurnBarMissionApprovalState
    let sessionCount: Int
    let summarizedSessionCount: Int
    let burnRecordCount: Int
    let totalTokens: Int
    let estimatedCostUSD: Double
    let recommendationSummary: String
    let approvalNote: String?
}

struct BurnBarDirectionSummary: Equatable, Sendable {
    let availability: BurnBarOperatingAvailability
    let projectName: String
    let title: String
    let status: BurnBarDirectionAssessment
    let summary: String
    let scopeLabel: String
    let freshness: BurnBarEvidenceFreshness
    let mode: BurnBarDirectionMode
    let sparseReason: String?
    let nextActions: [String]
    let overrideSummary: String?
}

struct BurnBarBurnSummary: Equatable, Sendable {
    let availability: BurnBarOperatingAvailability
    let projectName: String
    let sessionCount: Int
    let burnRecordCount: Int
    let totalTokens: Int
    let estimatedCostUSD: Double
    let latestSource: String?
    let dominantModel: String?
    let windowLabel: String
}

struct BurnBarFreshnessSummary: Equatable, Sendable {
    let status: BurnBarFreshnessKind
    let provisional: Bool
    let updatedAt: Date?
    let reasons: [String]

    var headline: String {
        status.label
    }
}

struct BurnBarEvidenceEntry: Identifiable, Equatable, Sendable {
    let id: String
    let sourceLabel: String
    let summary: String
    let detail: String
    let includedReason: String
    let freshness: BurnBarEvidenceFreshness
}

struct BurnBarEvidenceJudgment: Identifiable, Equatable, Sendable {
    let id: String
    let summary: String
    let detail: String
}

struct BurnBarEvidenceSummary: Equatable, Sendable {
    let availability: BurnBarOperatingAvailability
    let projectName: String
    let freshness: BurnBarEvidenceFreshness
    let summary: String
    let sparseReason: String?
    let entries: [BurnBarEvidenceEntry]
    let inclusionReasons: [String]
    let majorExclusions: [String]
    let support: [BurnBarEvidenceJudgment]
    let contradictions: [BurnBarEvidenceJudgment]
}

struct BurnBarActionAvailability: Identifiable, Equatable, Sendable {
    let kind: BurnBarActionKind
    let available: Bool
    let reason: String
    let title: String

    var id: String { kind.id }
}

struct BurnBarActionFeedback: Identifiable, Equatable, Sendable {
    let kind: BurnBarActionKind
    let tone: BurnBarActionTone
    let message: String
    let detail: String?

    var id: String { "\(kind.rawValue)-\(message)" }
}

struct BurnBarOperatingHistoryEntry: Identifiable, Equatable, Sendable {
    let id: String
    let kind: BurnBarActionKind
    let title: String
    let summary: String
    let detail: String?
    let createdAt: Date

    var tint: Color {
        switch kind {
        case .missionApproval: return DesignSystem.Colors.success
        case .directionOverride: return DesignSystem.Colors.whimsy
        }
    }

    var icon: String {
        switch kind {
        case .missionApproval: return "checkmark.seal.fill"
        case .directionOverride: return "flag.fill"
        }
    }
}

enum BurnBarControllerRuntimeSource: String, Codable, Equatable, Sendable {
    case daemon
    case mirrored
    case inferred

    var label: String {
        switch self {
        case .daemon: return "Daemon-backed"
        case .mirrored: return "Mirrored"
        case .inferred: return "Local inference"
        }
    }
}

enum BurnBarControllerQuestionState: String, Codable, Equatable, Sendable {
    case pending
    case answered
    case dismissed
}

enum BurnBarControllerQuestionPriority: String, Codable, Equatable, Sendable {
    case high
    case medium
    case low

    var color: Color {
        switch self {
        case .high: return DesignSystem.Colors.error
        case .medium: return DesignSystem.Colors.amber
        case .low: return DesignSystem.Colors.textSecondary
        }
    }
}

enum BurnBarControllerQuestionDeepLinkKind: String, Codable, Equatable, Sendable {
    case sessionLog = "session_log"
    case dashboard
    case project
    case settings
}

enum BurnBarControllerFollowupState: String, Codable, Equatable, Sendable {
    case open
    case done
    case snoozed
}

enum BurnBarControllerFollowupKind: String, Codable, Equatable, Sendable {
    case pendingQuestion = "pending_question"
    case completedAction = "completed_action"
    case missionWork = "mission_work"
    case setup
}

enum BurnBarControllerTakeoverState: String, Codable, Equatable, Sendable {
    case monitoring
    case launched
    case completed
    case failed
    case skipped

    var label: String {
        switch self {
        case .monitoring: return "Monitoring"
        case .launched: return "Takeover live"
        case .completed: return "Takeover done"
        case .failed: return "Takeover failed"
        case .skipped: return "Takeover skipped"
        }
    }

    var color: Color {
        switch self {
        case .monitoring: return DesignSystem.Colors.textSecondary
        case .launched: return DesignSystem.Colors.blaze
        case .completed: return DesignSystem.Colors.success
        case .failed: return DesignSystem.Colors.error
        case .skipped: return DesignSystem.Colors.textMuted
        }
    }
}

enum BurnBarControllerEventCategory: String, Codable, Equatable, Sendable {
    case controller
    case question
    case followup
    case mission
    case notification
    case replay
    case governance

    var icon: String {
        switch self {
        case .controller: return "dial.medium"
        case .question: return "questionmark.bubble"
        case .followup: return "list.bullet.clipboard"
        case .mission: return "flag.2.crossed"
        case .notification: return "bell.badge"
        case .replay: return "play.square.stack"
        case .governance: return "checkmark.seal"
        }
    }

    var color: Color {
        switch self {
        case .controller: return DesignSystem.Colors.blaze
        case .question: return DesignSystem.Colors.amber
        case .followup: return DesignSystem.Colors.whimsy
        case .mission: return DesignSystem.Colors.hermesAureate
        case .notification: return DesignSystem.Colors.teal
        case .replay: return DesignSystem.Colors.textSecondary
        case .governance: return DesignSystem.Colors.success
        }
    }
}

struct BurnBarControllerQuestionOption: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String?
    let answer: String
}

struct BurnBarControllerQuestionDeepLink: Codable, Equatable, Sendable {
    let kind: BurnBarControllerQuestionDeepLinkKind
    let targetID: String?
    let title: String
    let subtitle: String?
}

struct BurnBarControllerQuestion: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let projectName: String
    let sessionID: String?
    let title: String
    let prompt: String
    let stageLabel: String?
    let evidenceHint: String?
    let state: BurnBarControllerQuestionState
    let priority: BurnBarControllerQuestionPriority
    let sourceLabel: String
    let createdAt: Date
    let answeredAt: Date?
    let answer: String?
    let selectedOptionID: String?
    let answerPlaceholder: String?
    let suggestedOptions: [BurnBarControllerQuestionOption]
    let deepLink: BurnBarControllerQuestionDeepLink?
    let isUnread: Bool
    let notificationCount: Int

    init(
        id: String = UUID().uuidString,
        projectName: String,
        sessionID: String? = nil,
        title: String,
        prompt: String,
        stageLabel: String? = nil,
        evidenceHint: String? = nil,
        state: BurnBarControllerQuestionState = .pending,
        priority: BurnBarControllerQuestionPriority = .medium,
        sourceLabel: String = "Local runtime",
        createdAt: Date = Date(),
        answeredAt: Date? = nil,
        answer: String? = nil,
        selectedOptionID: String? = nil,
        answerPlaceholder: String? = nil,
        suggestedOptions: [BurnBarControllerQuestionOption] = [],
        deepLink: BurnBarControllerQuestionDeepLink? = nil,
        isUnread: Bool = true,
        notificationCount: Int = 0
    ) {
        self.id = id
        self.projectName = projectName
        self.sessionID = sessionID
        self.title = title
        self.prompt = prompt
        self.stageLabel = stageLabel
        self.evidenceHint = evidenceHint
        self.state = state
        self.priority = priority
        self.sourceLabel = sourceLabel
        self.createdAt = createdAt
        self.answeredAt = answeredAt
        self.answer = answer
        self.selectedOptionID = selectedOptionID
        self.answerPlaceholder = answerPlaceholder
        self.suggestedOptions = suggestedOptions
        self.deepLink = deepLink
        self.isUnread = isUnread
        self.notificationCount = notificationCount
    }
}

struct BurnBarControllerFollowup: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let projectName: String
    let title: String
    let summary: String
    let stageLabel: String?
    let detail: String?
    let state: BurnBarControllerFollowupState
    let kind: BurnBarControllerFollowupKind
    let linkedQuestionID: String?
    let deepLink: BurnBarControllerQuestionDeepLink?
    let createdAt: Date
    let updatedAt: Date
    let dueAt: Date?
    let snoozedUntil: Date?
    let calendarTitle: String?
    let calendarStart: Date?
    let calendarEnd: Date?

    init(
        id: String = UUID().uuidString,
        projectName: String,
        title: String,
        summary: String,
        stageLabel: String? = nil,
        detail: String? = nil,
        state: BurnBarControllerFollowupState = .open,
        kind: BurnBarControllerFollowupKind,
        linkedQuestionID: String? = nil,
        deepLink: BurnBarControllerQuestionDeepLink? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        dueAt: Date? = nil,
        snoozedUntil: Date? = nil,
        calendarTitle: String? = nil,
        calendarStart: Date? = nil,
        calendarEnd: Date? = nil
    ) {
        self.id = id
        self.projectName = projectName
        self.title = title
        self.summary = summary
        self.stageLabel = stageLabel
        self.detail = detail
        self.state = state
        self.kind = kind
        self.linkedQuestionID = linkedQuestionID
        self.deepLink = deepLink
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dueAt = dueAt
        self.snoozedUntil = snoozedUntil
        self.calendarTitle = calendarTitle
        self.calendarStart = calendarStart
        self.calendarEnd = calendarEnd
    }

    func updating(
        state: BurnBarControllerFollowupState? = nil,
        snoozedUntil: Date? = nil,
        calendarTitle: String? = nil,
        calendarStart: Date? = nil,
        calendarEnd: Date? = nil,
        updatedAt: Date
    ) -> BurnBarControllerFollowup {
        BurnBarControllerFollowup(
            id: id,
            projectName: projectName,
            title: title,
            summary: summary,
            stageLabel: stageLabel,
            detail: detail,
            state: state ?? self.state,
            kind: kind,
            linkedQuestionID: linkedQuestionID,
            deepLink: deepLink,
            createdAt: createdAt,
            updatedAt: updatedAt,
            dueAt: dueAt,
            snoozedUntil: snoozedUntil ?? self.snoozedUntil,
            calendarTitle: calendarTitle ?? self.calendarTitle,
            calendarStart: calendarStart ?? self.calendarStart,
            calendarEnd: calendarEnd ?? self.calendarEnd
        )
    }
}

struct BurnBarControllerMissionRecord: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let projectName: String
    let title: String
    let summary: String
    let state: BurnBarMissionLifecycle
    let approval: BurnBarMissionApprovalState
    let packetSummary: String?
    let latestResultSummary: String?
    let latestResultDetail: String?
    let latestResultRunID: String?
    let activeWorkerName: String?
    let activeRunID: String?
    let packetRunCount: Int
    let latestTakeoverState: BurnBarControllerTakeoverState?
    let latestTakeoverReason: String?
    let latestTakeoverRunID: String?
    let takeoverCount: Int
    let burnCostUSD: Double
    let burnTokens: Int
    let updatedAt: Date
}

struct BurnBarControllerEvent: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let projectName: String?
    let category: BurnBarControllerEventCategory
    let title: String
    let summary: String
    let detail: String?
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        projectName: String? = nil,
        category: BurnBarControllerEventCategory,
        title: String,
        summary: String,
        detail: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.projectName = projectName
        self.category = category
        self.title = title
        self.summary = summary
        self.detail = detail
        self.createdAt = createdAt
    }
}

struct BurnBarControllerSummary: Codable, Equatable, Sendable {
    let headline: String
    let detail: String
    let pendingQuestions: Int
    let unresolvedFollowups: Int
    let openMissions: Int
    let replayLabel: String
    let notificationLabel: String

    static let empty = BurnBarControllerSummary(
        headline: "Controller runtime is quiet.",
        detail: "BurnBar will mirror followups, questions, missions, and replay state here once the daemon or local operating layer has signal.",
        pendingQuestions: 0,
        unresolvedFollowups: 0,
        openMissions: 0,
        replayLabel: "Replay idle",
        notificationLabel: "Notifications optional"
    )

    func recounted(
        pendingQuestions: Int,
        unresolvedFollowups: Int,
        openMissions: Int
    ) -> BurnBarControllerSummary {
        BurnBarControllerSummary(
            headline: headline,
            detail: detail,
            pendingQuestions: pendingQuestions,
            unresolvedFollowups: unresolvedFollowups,
            openMissions: openMissions,
            replayLabel: replayLabel,
            notificationLabel: notificationLabel
        )
    }
}

struct BurnBarControllerRuntimeSnapshot: Codable, Equatable, Sendable {
    var source: BurnBarControllerRuntimeSource
    var updatedAt: Date
    var summary: BurnBarControllerSummary
    var questions: [BurnBarControllerQuestion]
    var followups: [BurnBarControllerFollowup]
    var missions: [BurnBarControllerMissionRecord]
    var recentEvents: [BurnBarControllerEvent]

    static let empty = BurnBarControllerRuntimeSnapshot(
        source: .inferred,
        updatedAt: .distantPast,
        summary: .empty,
        questions: [],
        followups: [],
        missions: [],
        recentEvents: []
    )

    var pendingQuestions: [BurnBarControllerQuestion] {
        questions.filter { $0.state == .pending }
    }

    var openFollowups: [BurnBarControllerFollowup] {
        followups.filter { $0.state == .open }
    }

    var unresolvedCount: Int {
        pendingQuestions.count + openFollowups.count
    }

    var compactHighlight: String? {
        if let question = pendingQuestions.first {
            return question.title
        }
        if let followup = openFollowups.first {
            return followup.title
        }
        if let mission = missions.first {
            if let takeoverReason = mission.latestTakeoverReason?.nonEmpty {
                return takeoverReason
            }
            if let result = mission.latestResultSummary?.nonEmpty {
                return result
            }
        }
        return nil
    }
}

struct BurnBarControllerFeedback: Identifiable, Equatable, Sendable {
    enum Tone: Equatable, Sendable {
        case success
        case error

        var color: Color {
            switch self {
            case .success: return DesignSystem.Colors.success
            case .error: return DesignSystem.Colors.error
            }
        }
    }

    let id = UUID()
    let tone: Tone
    let message: String
}

struct BurnBarOperatingSnapshot: Equatable, Sendable {
    let updatedAt: Date
    let projectName: String?
    let secondaryProjectName: String?
    let mission: BurnBarMissionSummary
    let direction: BurnBarDirectionSummary
    let burn: BurnBarBurnSummary
    let freshness: BurnBarFreshnessSummary
    let evidence: BurnBarEvidenceSummary
    let availableActions: [BurnBarActionAvailability]
    let recentHistory: [BurnBarOperatingHistoryEntry]
    let controllerRuntime: BurnBarControllerRuntimeSnapshot
    let compactSummary: String
    let pendingHighlight: String?
}

// MARK: - Operating Layer Persistence

struct BurnBarMissionApprovalRecord: Codable, Equatable, Sendable {
    let projectName: String
    let missionFingerprint: String
    let note: String
    let approvedAt: Date
}

struct BurnBarDirectionOverrideRecord: Codable, Equatable, Sendable {
    let projectName: String
    let mode: BurnBarDirectionOverrideModeKind
    let forcedStatus: BurnBarDirectionAssessment?
    let summary: String
    let rationale: String
    let createdAt: Date
}

struct BurnBarOperatingDecisionState: Codable, Equatable, Sendable {
    var missionApprovalsByProject: [String: BurnBarMissionApprovalRecord] = [:]
    var directionOverridesByProject: [String: BurnBarDirectionOverrideRecord] = [:]
}

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

    private var stateRevision: Int = 0

    private(set) var actionFeedback: BurnBarActionFeedback?
    private(set) var controllerFeedback: BurnBarControllerFeedback?

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

    func approveMission(note: String = "") {
        let current = snapshot
        guard let action = current.availableActions.first(where: { $0.kind == .missionApproval }) else {
            actionFeedback = BurnBarActionFeedback(
                kind: .missionApproval,
                tone: .error,
                message: "Mission approval is unavailable.",
                detail: nil
            )
            return
        }
        guard action.available else {
            actionFeedback = BurnBarActionFeedback(
                kind: .missionApproval,
                tone: .error,
                message: "Mission approval is unavailable.",
                detail: action.reason
            )
            return
        }
        guard let projectName = current.projectName else {
            actionFeedback = BurnBarActionFeedback(
                kind: .missionApproval,
                tone: .error,
                message: "BurnBar could not resolve a project to approve.",
                detail: nil
            )
            return
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try dataStore.appendOperatingActionRecord(
                BurnBarOperatingActionRecord(
                    projectName: projectName,
                    missionFingerprint: current.mission.missionID,
                    actionKind: .missionApproval,
                    summary: "Mission approved",
                    detail: trimmedNote.isEmpty ? current.mission.recommendationSummary : trimmedNote
                )
            )
        } catch {
            actionFeedback = BurnBarActionFeedback(
                kind: .missionApproval,
                tone: .error,
                message: "Mission approval could not be recorded.",
                detail: error.localizedDescription
            )
            return
        }
        stateRevision += 1
        actionFeedback = BurnBarActionFeedback(
            kind: .missionApproval,
            tone: .success,
            message: "Mission approved for \(projectName).",
            detail: trimmedNote.isEmpty ? "BurnBar will treat this mission as operator-approved until the checkpoint changes." : trimmedNote
        )
    }

    /// Approve a specific mission by ID — used when multiple missions are pending in the Queue tab.
    func approveMission(id: String, projectName: String, note: String = "") {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try dataStore.appendOperatingActionRecord(
                BurnBarOperatingActionRecord(
                    projectName: projectName,
                    missionFingerprint: id,
                    actionKind: .missionApproval,
                    summary: "Mission approved",
                    detail: trimmedNote.isEmpty ? nil : trimmedNote
                )
            )
        } catch {
            actionFeedback = BurnBarActionFeedback(
                kind: .missionApproval,
                tone: .error,
                message: "Mission approval could not be recorded.",
                detail: error.localizedDescription
            )
            return
        }
        stateRevision += 1
        actionFeedback = BurnBarActionFeedback(
            kind: .missionApproval,
            tone: .success,
            message: "Mission approved for \(projectName).",
            detail: trimmedNote.isEmpty ? "BurnBar will treat this mission as operator-approved until the checkpoint changes." : trimmedNote
        )
    }

    func saveDirectionOverride(
        mode: BurnBarDirectionOverrideModeKind,
        forcedStatus: BurnBarDirectionAssessment?,
        summary: String,
        rationale: String
    ) {
        let current = snapshot
        guard let action = current.availableActions.first(where: { $0.kind == .directionOverride }) else {
            actionFeedback = BurnBarActionFeedback(
                kind: .directionOverride,
                tone: .error,
                message: "Direction override is unavailable.",
                detail: nil
            )
            return
        }
        guard action.available else {
            actionFeedback = BurnBarActionFeedback(
                kind: .directionOverride,
                tone: .error,
                message: "Direction override is unavailable.",
                detail: action.reason
            )
            return
        }
        guard let projectName = current.projectName else {
            actionFeedback = BurnBarActionFeedback(
                kind: .directionOverride,
                tone: .error,
                message: "BurnBar could not resolve a project to steer.",
                detail: nil
            )
            return
        }

        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRationale = rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSummary.isEmpty == false, trimmedRationale.isEmpty == false else {
            actionFeedback = BurnBarActionFeedback(
                kind: .directionOverride,
                tone: .error,
                message: "Direction override needs both a summary and a rationale.",
                detail: nil
            )
            return
        }
        if mode == .supersedeStatus, forcedStatus == nil {
            actionFeedback = BurnBarActionFeedback(
                kind: .directionOverride,
                tone: .error,
                message: "Choose the status you want BurnBar to force.",
                detail: nil
            )
            return
        }

        do {
            try dataStore.appendOperatingActionRecord(
                BurnBarOperatingActionRecord(
                    projectName: projectName,
                    actionKind: .directionOverride,
                    summary: trimmedSummary,
                    detail: trimmedRationale,
                    overrideMode: mode,
                    forcedDirectionStatus: forcedStatus
                )
            )
        } catch {
            actionFeedback = BurnBarActionFeedback(
                kind: .directionOverride,
                tone: .error,
                message: "Direction override could not be recorded.",
                detail: error.localizedDescription
            )
            return
        }
        stateRevision += 1

        let detail: String
        if mode == .annotate {
            detail = "BurnBar will keep showing the inferred status, but it will carry your note alongside it."
        } else {
            detail = "BurnBar will surface \(forcedStatus?.label ?? "your override") until you update it."
        }
        actionFeedback = BurnBarActionFeedback(
            kind: .directionOverride,
            tone: .success,
            message: "Direction override saved for \(projectName).",
            detail: detail
        )
    }

    func refreshControllerRuntime() async {
        guard settingsManager.controllerRuntimeEnabled else {
            stateRevision += 1
            return
        }

        do {
            if case .healthy = daemonManager.status {
                try await daemonManager.syncControllerNotificationConfiguration(from: settingsManager)
                let snapshot = try await daemonManager.fetchControllerRuntimeSnapshot()
                try dataStore.saveControllerRuntimeMirror(snapshot)
            }
            controllerFeedback = nil
        } catch {
            controllerFeedback = BurnBarControllerFeedback(
                tone: .error,
                message: "Controller runtime refresh fell back to the local mirror: \(error.localizedDescription)"
            )
        }
        stateRevision += 1
    }

    func answerPendingQuestion(id: String, answer: String, selectedOptionID: String? = nil) async {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            controllerFeedback = BurnBarControllerFeedback(tone: .error, message: "Write an answer before sending it to BurnBar.")
            return
        }

        do {
            if case .healthy = daemonManager.status {
                if let snapshot = try await daemonManager.answerControllerQuestion(
                    questionID: id,
                    answer: trimmed,
                    selectedOptionID: selectedOptionID
                ) {
                    try dataStore.saveControllerRuntimeMirror(snapshot)
                } else {
                    try dataStore.saveControllerRuntimeMirror(self.snapshot.controllerRuntime)
                    _ = try dataStore.answerControllerQuestion(id: id, answer: trimmed, selectedOptionID: selectedOptionID)
                }
            } else {
                try dataStore.saveControllerRuntimeMirror(self.snapshot.controllerRuntime)
                _ = try dataStore.answerControllerQuestion(id: id, answer: trimmed, selectedOptionID: selectedOptionID)
            }
            controllerFeedback = BurnBarControllerFeedback(tone: .success, message: "Answer recorded in BurnBar’s controller history.")
            stateRevision += 1
        } catch {
            controllerFeedback = BurnBarControllerFeedback(tone: .error, message: "BurnBar could not record that answer: \(error.localizedDescription)")
        }
    }

    func completeFollowup(id: String) async {
        do {
            if case .healthy = daemonManager.status {
                if let snapshot = try await daemonManager.completeControllerFollowup(followupID: id) {
                    try dataStore.saveControllerRuntimeMirror(snapshot)
                } else {
                    try dataStore.saveControllerRuntimeMirror(self.snapshot.controllerRuntime)
                    _ = try dataStore.completeControllerFollowup(id: id)
                }
            } else {
                try dataStore.saveControllerRuntimeMirror(self.snapshot.controllerRuntime)
                _ = try dataStore.completeControllerFollowup(id: id)
            }
            controllerFeedback = BurnBarControllerFeedback(tone: .success, message: "Followup completed.")
            stateRevision += 1
        } catch {
            controllerFeedback = BurnBarControllerFeedback(tone: .error, message: "BurnBar could not complete that followup: \(error.localizedDescription)")
        }
    }

    func snoozeFollowup(id: String, until: Date) async {
        do {
            if case .healthy = daemonManager.status {
                if let snapshot = try await daemonManager.snoozeControllerFollowup(followupID: id, until: until) {
                    try dataStore.saveControllerRuntimeMirror(snapshot)
                } else {
                    try dataStore.saveControllerRuntimeMirror(self.snapshot.controllerRuntime)
                    _ = try dataStore.snoozeControllerFollowup(id: id, until: until)
                }
            } else {
                try dataStore.saveControllerRuntimeMirror(self.snapshot.controllerRuntime)
                _ = try dataStore.snoozeControllerFollowup(id: id, until: until)
            }
            controllerFeedback = BurnBarControllerFeedback(tone: .success, message: "Followup snoozed until \(until.formatted(date: .abbreviated, time: .shortened)).")
            stateRevision += 1
        } catch {
            controllerFeedback = BurnBarControllerFeedback(tone: .error, message: "BurnBar could not snooze that followup: \(error.localizedDescription)")
        }
    }

    func scheduleFollowupCalendar(id: String, title: String? = nil) async {
        let start = Date().addingTimeInterval(60 * 30)
        let duration = settingsManager.controllerCalendarDefaultMinutes
        do {
            if case .healthy = daemonManager.status {
                if let snapshot = try await daemonManager.scheduleControllerFollowupCalendar(
                    followupID: id,
                    title: title,
                    start: start,
                    durationMinutes: duration
                ) {
                    try dataStore.saveControllerRuntimeMirror(snapshot)
                } else {
                    try dataStore.saveControllerRuntimeMirror(self.snapshot.controllerRuntime)
                    _ = try dataStore.scheduleControllerFollowupCalendar(
                        id: id,
                        title: title,
                        start: start,
                        durationMinutes: duration
                    )
                }
            } else {
                try dataStore.saveControllerRuntimeMirror(self.snapshot.controllerRuntime)
                _ = try dataStore.scheduleControllerFollowupCalendar(
                    id: id,
                    title: title,
                    start: start,
                    durationMinutes: duration
                )
            }
            controllerFeedback = BurnBarControllerFeedback(
                tone: .success,
                message: "Calendar hold added for \(start.formatted(date: .abbreviated, time: .shortened))."
            )
            stateRevision += 1
        } catch {
            controllerFeedback = BurnBarControllerFeedback(tone: .error, message: "BurnBar could not add that calendar hold: \(error.localizedDescription)")
        }
    }
}

// MARK: - Operating Layer Composition

@MainActor
private enum BurnBarOperatingComposer {
    static func build(
        dataStore: DataStore,
        settingsManager: SettingsManager,
        accountManager: AccountManager,
        daemonStatus: BurnBarDaemonStatus,
        aggregator: UsageAggregator?,
        chatController: ChatSessionController?,
        actionRecords: [BurnBarOperatingActionRecord],
        cachedControllerRuntime: BurnBarControllerRuntimeSnapshot?
    ) -> BurnBarOperatingSnapshot {
        let searchService = SearchService.makeConversationSearchService(
            dataStore: dataStore,
            settingsManager: settingsManager
        )
        let rollupService = WorkflowInsightRollupService(dataStore: dataStore)
        let insightBrief = InsightBriefSnapshot.build(
            from: dataStore,
            intelligenceService: searchService,
            rollupService: rollupService
        )
        let retrievalHealth = RetrievalHealthService(dataStore: dataStore).snapshot(
            indexingEnabled: settingsManager.conversationIndexingEnabled,
            sharedFeaturesAvailable: accountManager.isSignedIn
        )

        let recentConversations = searchService
            .recentConversations(limit: 120)
            .filter { $0.sourceType == .providerLog }
        let focus = selectProjectFocus(
            conversations: recentConversations,
            usages: dataStore.usages
        )

        let projectConversations = recentConversations.filter {
            guard let focusProject = focus.primaryProject else { return false }
            return normalizeProjectName($0.projectName) == focusProject
        }
        let decisions = decisionState(from: actionRecords)
        let history = historyEntries(
            from: actionRecords,
            focusProject: focus.primaryProject
        )
        let latestConversation = searchService.latestConversation(in: projectConversations)
        let projectUsages = dataStore.usages.filter {
            guard let focusProject = focus.primaryProject else { return false }
            return normalizeProjectName($0.projectName) == focusProject
        }
        let recentProjectUsages = projectUsages.filter { $0.startTime >= Date().addingTimeInterval(-7 * 24 * 60 * 60) }
        let activeUsages = recentProjectUsages.isEmpty ? projectUsages : recentProjectUsages

        let mission = buildMissionSummary(
            focusProject: focus.primaryProject,
            latestConversation: latestConversation,
            projectConversations: projectConversations,
            projectUsages: activeUsages,
            insightBrief: insightBrief,
            aggregator: aggregator,
            chatController: chatController,
            decisions: decisions
        )
        let direction = buildDirectionSummary(
            focus: focus,
            latestConversation: latestConversation,
            projectConversations: projectConversations,
            insightBrief: insightBrief,
            rollupFreshness: insightBrief.rollupFreshness,
            rollupStatusMessage: insightBrief.rollupStatusMessage,
            retrievalHealth: retrievalHealth,
            settingsManager: settingsManager,
            decisions: decisions
        )
        let burn = buildBurnSummary(
            focusProject: focus.primaryProject,
            projectUsages: activeUsages
        )
        let freshness = buildFreshnessSummary(
            focus: focus,
            dataStore: dataStore,
            settingsManager: settingsManager,
            aggregator: aggregator,
            rollupFreshness: insightBrief.rollupFreshness,
            rollupStatusMessage: insightBrief.rollupStatusMessage,
            retrievalHealth: retrievalHealth
        )
        let evidence = buildEvidenceSummary(
            focusProject: focus.primaryProject,
            projectConversations: projectConversations,
            latestConversation: latestConversation,
            settingsManager: settingsManager,
            insightBrief: insightBrief,
            direction: direction,
            freshness: freshness
        )
        let actions = buildActions(
            projectName: focus.primaryProject,
            mission: mission,
            direction: direction
        )
        let controllerRuntime = buildControllerRuntime(
            cached: cachedControllerRuntime,
            daemonStatus: daemonStatus,
            projectName: focus.primaryProject,
            latestConversation: latestConversation,
            projectConversations: projectConversations,
            mission: mission,
            direction: direction,
            burn: burn,
            freshness: freshness,
            settingsManager: settingsManager,
            history: history
        )

        let compactSummary = buildCompactSummary(
            projectName: focus.primaryProject,
            mission: mission,
            direction: direction,
            burn: burn
        )
        let pendingHighlight = controllerRuntime.compactHighlight
            ?? actions.first(where: { $0.available })?.reason

        return BurnBarOperatingSnapshot(
            updatedAt: freshness.updatedAt ?? Date(),
            projectName: focus.primaryProject,
            secondaryProjectName: focus.secondaryProject,
            mission: mission,
            direction: direction,
            burn: burn,
            freshness: freshness,
            evidence: evidence,
            availableActions: actions,
            recentHistory: history,
            controllerRuntime: controllerRuntime,
            compactSummary: compactSummary,
            pendingHighlight: pendingHighlight
        )
    }

    private static func decisionState(
        from actionRecords: [BurnBarOperatingActionRecord]
    ) -> BurnBarOperatingDecisionState {
        var state = BurnBarOperatingDecisionState()

        for record in actionRecords {
            switch record.actionKind {
            case .missionApproval:
                guard let missionFingerprint = record.missionFingerprint else { continue }
                if state.missionApprovalsByProject[record.projectName] == nil {
                    state.missionApprovalsByProject[record.projectName] = BurnBarMissionApprovalRecord(
                        projectName: record.projectName,
                        missionFingerprint: missionFingerprint,
                        note: record.detail ?? "",
                        approvedAt: record.createdAt
                    )
                }
            case .directionOverride:
                if state.directionOverridesByProject[record.projectName] == nil {
                    state.directionOverridesByProject[record.projectName] = BurnBarDirectionOverrideRecord(
                        projectName: record.projectName,
                        mode: record.overrideMode ?? .annotate,
                        forcedStatus: record.forcedDirectionStatus,
                        summary: record.summary,
                        rationale: record.detail ?? "",
                        createdAt: record.createdAt
                    )
                }
            }
        }

        return state
    }

    private static func historyEntries(
        from actionRecords: [BurnBarOperatingActionRecord],
        focusProject: String?
    ) -> [BurnBarOperatingHistoryEntry] {
        let scoped = actionRecords.filter { record in
            guard let focusProject else { return true }
            return record.projectName == focusProject
        }
        return scoped.prefix(6).map { record in
            BurnBarOperatingHistoryEntry(
                id: record.id,
                kind: record.actionKind,
                title: historyTitle(for: record),
                summary: record.summary,
                detail: record.detail,
                createdAt: record.createdAt
            )
        }
    }

    private static func buildControllerRuntime(
        cached: BurnBarControllerRuntimeSnapshot?,
        daemonStatus: BurnBarDaemonStatus,
        projectName: String?,
        latestConversation: ConversationRecord?,
        projectConversations: [ConversationRecord],
        mission: BurnBarMissionSummary,
        direction: BurnBarDirectionSummary,
        burn: BurnBarBurnSummary,
        freshness: BurnBarFreshnessSummary,
        settingsManager: SettingsManager,
        history: [BurnBarOperatingHistoryEntry]
    ) -> BurnBarControllerRuntimeSnapshot {
        let inferred = inferredControllerRuntime(
            daemonStatus: daemonStatus,
            projectName: projectName,
            latestConversation: latestConversation,
            projectConversations: projectConversations,
            mission: mission,
            direction: direction,
            burn: burn,
            freshness: freshness,
            settingsManager: settingsManager,
            history: history
        )

        guard let cached else { return inferred }

        let mergedQuestions = mergeQuestions(
            primary: cached.questions.filter { $0.sourceLabel != "Inferred from the latest local session" },
            fallback: inferred.questions
        )
        let mergedFollowups = mergeFollowups(primary: cached.followups, fallback: inferred.followups)
        let mergedMissions = mergeMissions(primary: cached.missions, fallback: inferred.missions)
        let mergedEvents = mergeEvents(primary: cached.recentEvents, fallback: inferred.recentEvents)

        return BurnBarControllerRuntimeSnapshot(
            source: cached.source,
            updatedAt: max(cached.updatedAt, inferred.updatedAt),
            summary: BurnBarControllerSummary(
                headline: cached.summary.headline.nonEmpty ?? inferred.summary.headline,
                detail: cached.summary.detail.nonEmpty ?? inferred.summary.detail,
                pendingQuestions: mergedQuestions.filter { $0.state == .pending }.count,
                unresolvedFollowups: mergedFollowups.filter { $0.state == .open }.count,
                openMissions: mergedMissions.filter { $0.state != .completed }.count,
                replayLabel: cached.summary.replayLabel.nonEmpty ?? inferred.summary.replayLabel,
                notificationLabel: cached.summary.notificationLabel.nonEmpty ?? inferred.summary.notificationLabel
            ),
            questions: mergedQuestions,
            followups: mergedFollowups,
            missions: mergedMissions,
            recentEvents: Array(mergedEvents.prefix(10))
        )
    }

    private static func inferredControllerRuntime(
        daemonStatus: BurnBarDaemonStatus,
        projectName: String?,
        latestConversation: ConversationRecord?,
        projectConversations: [ConversationRecord],
        mission: BurnBarMissionSummary,
        direction: BurnBarDirectionSummary,
        burn: BurnBarBurnSummary,
        freshness: BurnBarFreshnessSummary,
        settingsManager: SettingsManager,
        history: [BurnBarOperatingHistoryEntry]
    ) -> BurnBarControllerRuntimeSnapshot {
        let now = Date()
        let project = projectName ?? mission.projectName.nonEmpty ?? "BurnBar"

        let questions: [BurnBarControllerQuestion] = []

        var followups: [BurnBarControllerFollowup] = []
        if mission.approval == .pending, let reason = mission.approvalNote?.nonEmpty ?? mission.recommendationSummary.nonEmpty {
            followups.append(
                BurnBarControllerFollowup(
                    projectName: project,
                    title: "Review mission approval",
                    summary: reason,
                    detail: "The current mission is still waiting on operator sign-off.",
                    kind: .missionWork,
                    dueAt: now.addingTimeInterval(60 * 60)
                )
            )
        }
        if settingsManager.conversationIndexingEnabled == false {
            followups.append(
                BurnBarControllerFollowup(
                    projectName: project,
                    title: "Turn on transcript indexing",
                    summary: "Direction and evidence are still sparse without indexed local transcripts.",
                    detail: "Enable local indexing when you want grounded question tracking, evidence previews, and better drift detection.",
                    kind: .setup
                )
            )
        }
        if direction.status == .drifting || freshness.provisional {
            followups.append(
                BurnBarControllerFollowup(
                    projectName: project,
                    title: "Resolve the latest direction call",
                    summary: direction.summary,
                    detail: direction.sparseReason ?? freshness.reasons.first,
                    kind: .completedAction,
                    dueAt: now.addingTimeInterval(2 * 60 * 60)
                )
            )
        }

        let missions = [
            BurnBarControllerMissionRecord(
                id: mission.missionID.nonEmpty ?? UUID().uuidString,
                projectName: project,
                title: mission.title,
                summary: mission.subtitle,
                state: mission.state,
                approval: mission.approval,
                packetSummary: "BurnBar is watching \(mission.summarizedSessionCount) summarized session\(mission.summarizedSessionCount == 1 ? "" : "s") for this mission.",
                latestResultSummary: mission.recommendationSummary,
                latestResultDetail: mission.approvalNote,
                latestResultRunID: nil,
                activeWorkerName: nil,
                activeRunID: nil,
                packetRunCount: 0,
                latestTakeoverState: nil,
                latestTakeoverReason: nil,
                latestTakeoverRunID: nil,
                takeoverCount: 0,
                burnCostUSD: burn.estimatedCostUSD,
                burnTokens: burn.totalTokens,
                updatedAt: freshness.updatedAt ?? now
            )
        ]

        var events = history.map {
            BurnBarControllerEvent(
                id: $0.id,
                projectName: projectName,
                category: .governance,
                title: $0.title,
                summary: $0.summary,
                detail: $0.detail,
                createdAt: $0.createdAt
            )
        }
        if case .healthy = daemonStatus {
            events.insert(
                BurnBarControllerEvent(
                    projectName: projectName,
                    category: .controller,
                    title: "Controller runtime reachable",
                    summary: "AgentLens can pull daemon-backed controller state when it is available.",
                    detail: nil,
                    createdAt: now
                ),
                at: 0
            )
        }

        let daemonDetail: String = {
            switch daemonStatus {
            case .healthy:
                return "Daemon-backed control plane is healthy."
            case .checking:
                return "BurnBar is checking the local daemon."
            case .notInstalled:
                return "Install the local daemon when you want long-lived notifications, Telegram, and replay workflows."
            case .unhealthy(let message):
                return "Daemon runtime needs repair: \(message)"
            }
        }()

        let summary = BurnBarControllerSummary(
            headline: summaryHeadline(questionCount: questions.count, followupCount: followups.filter { $0.state == .open }.count),
            detail: daemonDetail,
            pendingQuestions: questions.filter { $0.state == .pending }.count,
            unresolvedFollowups: followups.filter { $0.state == .open }.count,
            openMissions: missions.filter { $0.state != .completed }.count,
            replayLabel: settingsManager.controllerSimulatorToolsEnabled ? "Replay tools visible" : "Replay tools hidden",
            notificationLabel: notificationLabel(from: settingsManager)
        )

        return BurnBarControllerRuntimeSnapshot(
            source: .inferred,
            updatedAt: freshness.updatedAt ?? now,
            summary: summary,
            questions: questions,
            followups: followups,
            missions: missions,
            recentEvents: Array(events.prefix(10))
        )
    }

    private static func summaryHeadline(questionCount: Int, followupCount: Int) -> String {
        if questionCount > 0 && followupCount > 0 {
            return "\(questionCount) pending question\(questionCount == 1 ? "" : "s") and \(followupCount) followup\(followupCount == 1 ? "" : "s") need attention."
        }
        if questionCount > 0 {
            return "\(questionCount) pending question\(questionCount == 1 ? "" : "s") need an answer."
        }
        if followupCount > 0 {
            return "\(followupCount) followup\(followupCount == 1 ? "" : "s") are still open."
        }
        return "Controller runtime is quiet."
    }

    private static func notificationLabel(from settingsManager: SettingsManager) -> String {
        if settingsManager.controllerTelegramEnabled,
           settingsManager.controllerTelegramChatID.nonEmpty != nil {
            return "Telegram and local notifications armed"
        }
        if settingsManager.controllerLocalNotificationsEnabled {
            return "Local notifications armed"
        }
        return "Notifications optional"
    }

    private static func mergeQuestions(
        primary: [BurnBarControllerQuestion],
        fallback: [BurnBarControllerQuestion]
    ) -> [BurnBarControllerQuestion] {
        var seenIDs = Set<String>()
        var seenSemanticKeys = Set<String>()
        return (primary + fallback).filter { question in
            guard seenIDs.insert(question.id).inserted else {
                return false
            }
            let semanticKey = questionSemanticKey(question)
            guard seenSemanticKeys.insert(semanticKey).inserted else {
                return false
            }
            return true
        }
    }

    private static func mergeFollowups(
        primary: [BurnBarControllerFollowup],
        fallback: [BurnBarControllerFollowup]
    ) -> [BurnBarControllerFollowup] {
        var seen = Set<String>()
        return (primary + fallback).filter { seen.insert($0.id).inserted }
    }

    private static func mergeMissions(
        primary: [BurnBarControllerMissionRecord],
        fallback: [BurnBarControllerMissionRecord]
    ) -> [BurnBarControllerMissionRecord] {
        var seen = Set<String>()
        return (primary + fallback).filter { seen.insert($0.id).inserted }
    }

    private static func mergeEvents(
        primary: [BurnBarControllerEvent],
        fallback: [BurnBarControllerEvent]
    ) -> [BurnBarControllerEvent] {
        let merged = primary + fallback.filter { candidate in
            primary.contains(where: { $0.id == candidate.id }) == false
        }
        return merged.sorted { $0.createdAt > $1.createdAt }
    }

    private static func questionSemanticKey(_ question: BurnBarControllerQuestion) -> String {
        if let sessionID = question.sessionID?.nonEmpty {
            return "session|\(sessionID)"
        }
        let normalizedProject = question.projectName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPrompt = question.prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "project|\(normalizedProject)|\(normalizedPrompt)"
    }

    private static func buildMissionSummary(
        focusProject: String?,
        latestConversation: ConversationRecord?,
        projectConversations: [ConversationRecord],
        projectUsages: [TokenUsage],
        insightBrief: InsightBriefSnapshot,
        aggregator: UsageAggregator?,
        chatController: ChatSessionController?,
        decisions: BurnBarOperatingDecisionState
    ) -> BurnBarMissionSummary {
        guard let focusProject else {
            return BurnBarMissionSummary(
                availability: .missing,
                missionID: "",
                projectName: "",
                title: "No active mission yet",
                subtitle: "BurnBar needs a recent local project conversation before it can name the current mission.",
                state: .planned,
                approval: .pending,
                sessionCount: 0,
                summarizedSessionCount: 0,
                burnRecordCount: 0,
                totalTokens: 0,
                estimatedCostUSD: 0,
                recommendationSummary: "Run a local scan or index a recent project conversation to make the mission legible.",
                approvalNote: nil
            )
        }

        let latestText = joinedMissionText(from: latestConversation, insightBrief: insightBrief)
        let title = latestConversation?.summaryTitle
            ?? latestConversation?.inferredTaskTitle
            ?? insightBrief.heaviestTaskTitle
            ?? "Recent work in \(focusProject)"
        let subtitle = latestConversation?.summary
            ?? insightBrief.whereLeftOff
            ?? latestConversation?.lastAssistantMessage
            ?? "BurnBar is watching the most recent indexed checkpoint for \(focusProject)."
        let state = inferMissionState(
            latestText: latestText,
            isRefreshing: aggregator?.isRefreshing == true,
            isStreaming: chatController?.isStreaming == true,
            conversationCount: projectConversations.count
        )
        let missionID = missionFingerprint(
            projectName: focusProject,
            conversation: latestConversation,
            conversationCount: projectConversations.count
        )
        let approvalRecord = decisions.missionApprovalsByProject[focusProject]
        let approval: BurnBarMissionApprovalState = approvalRecord?.missionFingerprint == missionID ? .approved : .pending
        let recommendation = buildMissionRecommendation(
            state: state,
            latestConversation: latestConversation,
            insightBrief: insightBrief,
            focusProject: focusProject,
            approval: approval
        )

        return BurnBarMissionSummary(
            availability: .available,
            missionID: missionID,
            projectName: focusProject,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Recent work in \(focusProject)",
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "BurnBar has a lightweight read of the latest checkpoint.",
            state: state,
            approval: approval,
            sessionCount: projectConversations.count,
            summarizedSessionCount: projectConversations.filter { ($0.summary?.isEmpty == false) || ($0.summaryTitle?.isEmpty == false) }.count,
            burnRecordCount: projectUsages.count,
            totalTokens: projectUsages.reduce(0) { $0 + $1.totalTokens },
            estimatedCostUSD: projectUsages.reduce(0) { $0 + $1.cost },
            recommendationSummary: recommendation,
            approvalNote: approvalRecord?.note.nonEmpty
        )
    }

    private static func buildDirectionSummary(
        focus: ProjectFocus,
        latestConversation: ConversationRecord?,
        projectConversations: [ConversationRecord],
        insightBrief: InsightBriefSnapshot,
        rollupFreshness: InsightRollupFreshness,
        rollupStatusMessage: String?,
        retrievalHealth: RetrievalSystemHealthSnapshot,
        settingsManager: SettingsManager,
        decisions: BurnBarOperatingDecisionState
    ) -> BurnBarDirectionSummary {
        guard let focusProject = focus.primaryProject else {
            return BurnBarDirectionSummary(
                availability: .missing,
                projectName: "",
                title: "No direction signal yet",
                status: .notEnoughSignal,
                summary: "BurnBar needs recent local work before it can tell whether execution still matches intent.",
                scopeLabel: "Workspace",
                freshness: .unknown,
                mode: .sparse,
                sparseReason: "No active project could be inferred from the local index.",
                nextActions: ["Run a scan or point BurnBar at your agent log folders."],
                overrideSummary: nil
            )
        }

        let overrideRecord = decisions.directionOverridesByProject[focusProject]
        let freshness = freshnessForEvidence(
            rollupFreshness: rollupFreshness,
            latestConversation: latestConversation
        )

        if settingsManager.conversationIndexingEnabled == false {
            return BurnBarDirectionSummary(
                availability: .sparse,
                projectName: focusProject,
                title: "Direction is inferred from metadata",
                status: .notEnoughSignal,
                summary: "Direction is provisional because transcript indexing is off. BurnBar can see project activity and burn, but not grounded evidence.",
                scopeLabel: focus.scopeLabel,
                freshness: freshness,
                mode: .sparse,
                sparseReason: "Turn on local indexing to let BurnBar quote indexed sessions and explain drift with evidence.",
                nextActions: ["Enable conversation indexing in Settings.", "Run another local scan once indexing is on."],
                overrideSummary: overrideRecord?.summary
            )
        }

        if projectConversations.count < 2 {
            return BurnBarDirectionSummary(
                availability: .sparse,
                projectName: focusProject,
                title: "Direction signal is still sparse",
                status: .notEnoughSignal,
                summary: "BurnBar can name the active project, but there are not enough indexed checkpoints to judge alignment with confidence.",
                scopeLabel: focus.scopeLabel,
                freshness: freshness,
                mode: .sparse,
                sparseReason: "Only \(projectConversations.count) indexed session\(projectConversations.count == 1 ? "" : "s") exists for \(focusProject).",
                nextActions: ["Let BurnBar ingest a couple more sessions.", "Add a note or direction override if you already know the call."],
                overrideSummary: overrideRecord?.summary
            )
        }

        if let overrideRecord {
            let forced = overrideRecord.forcedStatus ?? inferDirectionStatus(
                focus: focus,
                latestConversation: latestConversation,
                insightBrief: insightBrief,
                retrievalHealth: retrievalHealth
            )
            let mode: BurnBarDirectionMode = overrideRecord.mode == .annotate ? .overrideAnnotating : .overrideSuperseding
            return BurnBarDirectionSummary(
                availability: .available,
                projectName: focusProject,
                title: "Operator override",
                status: forced,
                summary: overrideRecord.summary,
                scopeLabel: focus.scopeLabel,
                freshness: freshness,
                mode: mode,
                sparseReason: nil,
                nextActions: [overrideRecord.rationale],
                overrideSummary: overrideRecord.summary
            )
        }

        let status = inferDirectionStatus(
            focus: focus,
            latestConversation: latestConversation,
            insightBrief: insightBrief,
            retrievalHealth: retrievalHealth
        )
        let summary = directionSummaryText(
            status: status,
            focusProject: focusProject,
            latestConversation: latestConversation,
            insightBrief: insightBrief,
            rollupStatusMessage: rollupStatusMessage,
            retrievalHealth: retrievalHealth
        )
        let nextActions = directionNextActions(
            status: status,
            latestConversation: latestConversation,
            insightBrief: insightBrief,
            retrievalHealth: retrievalHealth
        )

        return BurnBarDirectionSummary(
            availability: .available,
            projectName: focusProject,
            title: "Current read on \(focusProject)",
            status: status,
            summary: summary,
            scopeLabel: focus.scopeLabel,
            freshness: freshness,
            mode: .inferred,
            sparseReason: nil,
            nextActions: nextActions,
            overrideSummary: nil
        )
    }

    private static func buildBurnSummary(
        focusProject: String?,
        projectUsages: [TokenUsage]
    ) -> BurnBarBurnSummary {
        guard let focusProject else {
            return BurnBarBurnSummary(
                availability: .missing,
                projectName: "",
                sessionCount: 0,
                burnRecordCount: 0,
                totalTokens: 0,
                estimatedCostUSD: 0,
                latestSource: nil,
                dominantModel: nil,
                windowLabel: "No burn signal yet"
            )
        }

        guard projectUsages.isEmpty == false else {
            return BurnBarBurnSummary(
                availability: .sparse,
                projectName: focusProject,
                sessionCount: 0,
                burnRecordCount: 0,
                totalTokens: 0,
                estimatedCostUSD: 0,
                latestSource: nil,
                dominantModel: nil,
                windowLabel: "No recent usage rows have been attributed to this project yet."
            )
        }

        let latestUsage = projectUsages.sorted(by: { $0.endTime > $1.endTime }).first
        let dominantModel = Dictionary(grouping: projectUsages, by: \.model)
            .mapValues { entries in entries.reduce(0) { $0 + $1.cost } }
            .max(by: { $0.value < $1.value })?
            .key

        return BurnBarBurnSummary(
            availability: .available,
            projectName: focusProject,
            sessionCount: Set(projectUsages.map { "\($0.provider.rawValue):\($0.sessionId)" }).count,
            burnRecordCount: projectUsages.count,
            totalTokens: projectUsages.reduce(0) { $0 + $1.totalTokens },
            estimatedCostUSD: projectUsages.reduce(0) { $0 + $1.cost },
            latestSource: latestUsage?.provider.displayName,
            dominantModel: dominantModel,
            windowLabel: projectUsages.count == 1 ? "Latest indexed session" : "Recent indexed work"
        )
    }

    private static func buildFreshnessSummary(
        focus: ProjectFocus,
        dataStore: DataStore,
        settingsManager: SettingsManager,
        aggregator: UsageAggregator?,
        rollupFreshness: InsightRollupFreshness,
        rollupStatusMessage: String?,
        retrievalHealth: RetrievalSystemHealthSnapshot
    ) -> BurnBarFreshnessSummary {
        var reasons = retrievalHealth.degradedModes.map(\.message)

        if settingsManager.conversationIndexingEnabled == false {
            reasons.append("Direction and evidence are being inferred from scan metadata only.")
        }
        if let secondary = focus.secondaryProject {
            reasons.append("Recent work is split between \(focus.primaryProject ?? "multiple projects") and \(secondary), so BurnBar is treating direction as provisional.")
        }
        switch rollupFreshness {
        case .fresh:
            break
        case .stale:
            reasons.append(rollupStatusMessage ?? "Workflow insights are stale.")
        case .rebuilding:
            reasons.append(rollupStatusMessage ?? "Workflow insights are rebuilding.")
        case .unavailable:
            reasons.append(rollupStatusMessage ?? "Workflow insights are unavailable.")
        }

        let updatedAt = maxDate([
            dataStore.lastRefresh,
            retrievalHealth.observedAt == .distantPast ? nil : retrievalHealth.observedAt
        ])

        if dataStore.lastRefresh == nil {
            return BurnBarFreshnessSummary(
                status: .missing,
                provisional: true,
                updatedAt: updatedAt,
                reasons: ["BurnBar has not completed its first local scan yet."]
            )
        }

        if aggregator?.isRefreshing == true {
            return BurnBarFreshnessSummary(
                status: .live,
                provisional: true,
                updatedAt: updatedAt,
                reasons: ["BurnBar is actively refreshing local logs right now."]
            )
        }

        let age = Date().timeIntervalSince(dataStore.lastRefresh ?? .distantPast)
        if reasons.isEmpty {
            let status: BurnBarFreshnessKind = age > 30 * 60 ? .stale : .live
            let ageReason = age > 30 * 60 ? ["The last local scan is older than thirty minutes."] : []
            return BurnBarFreshnessSummary(
                status: status,
                provisional: false,
                updatedAt: updatedAt,
                reasons: ageReason
            )
        }

        let status: BurnBarFreshnessKind = age > 30 * 60 ? .stale : .provisional
        return BurnBarFreshnessSummary(
            status: status,
            provisional: true,
            updatedAt: updatedAt,
            reasons: reasons
        )
    }

    private static func buildEvidenceSummary(
        focusProject: String?,
        projectConversations: [ConversationRecord],
        latestConversation: ConversationRecord?,
        settingsManager: SettingsManager,
        insightBrief: InsightBriefSnapshot,
        direction: BurnBarDirectionSummary,
        freshness: BurnBarFreshnessSummary
    ) -> BurnBarEvidenceSummary {
        guard let focusProject else {
            return BurnBarEvidenceSummary(
                availability: .missing,
                projectName: "",
                freshness: .unknown,
                summary: "No evidence is available yet.",
                sparseReason: "BurnBar has not resolved an active project.",
                entries: [],
                inclusionReasons: [],
                majorExclusions: [],
                support: [],
                contradictions: []
            )
        }

        guard settingsManager.conversationIndexingEnabled else {
            return BurnBarEvidenceSummary(
                availability: .sparse,
                projectName: focusProject,
                freshness: .unknown,
                summary: "Evidence is limited to metadata until transcript indexing is enabled.",
                sparseReason: "Turn on local indexing to see transcript-grounded evidence previews.",
                entries: [],
                inclusionReasons: [],
                majorExclusions: ["Transcript excerpts are excluded because local indexing is currently off."],
                support: [],
                contradictions: []
            )
        }

        guard projectConversations.isEmpty == false else {
            return BurnBarEvidenceSummary(
                availability: .missing,
                projectName: focusProject,
                freshness: .unknown,
                summary: "BurnBar does not have indexed sessions for this project yet.",
                sparseReason: nil,
                entries: [],
                inclusionReasons: [],
                majorExclusions: ["No indexed sessions were available for \(focusProject)."],
                support: [],
                contradictions: []
            )
        }

        let entries = Array(projectConversations.prefix(3).enumerated()).map { index, conversation in
            BurnBarEvidenceEntry(
                id: conversation.id,
                sourceLabel: conversation.summaryTitle?.nonEmpty
                    ?? conversation.inferredTaskTitle.nonEmpty
                    ?? conversation.provider.displayName,
                summary: conversation.summary?.nonEmpty
                    ?? truncated(conversation.lastAssistantMessage, limit: 140),
                detail: [
                    conversation.provider.displayName,
                    conversation.endTime?.formatted(date: .abbreviated, time: .shortened)
                        ?? conversation.indexedAt.formatted(date: .abbreviated, time: .shortened),
                    truncated(conversation.lastAssistantMessage, limit: 160),
                ]
                .compactMap { $0?.nonEmpty }
                .joined(separator: " · "),
                includedReason: evidenceReason(index: index, latestConversation: latestConversation, conversation: conversation),
                freshness: freshnessForConversation(conversation)
            )
        }

        let support = buildSupportJudgments(
            focusProject: focusProject,
            direction: direction,
            insightBrief: insightBrief,
            entries: entries
        )
        let contradictions = buildContradictionJudgments(
            latestConversation: latestConversation,
            direction: direction,
            freshness: freshness,
            insightBrief: insightBrief
        )

        let majorExclusions: [String] = {
            var exclusions: [String] = []
            if projectConversations.count < 3 {
                exclusions.append("Only \(projectConversations.count) recent indexed session\(projectConversations.count == 1 ? "" : "s") were available for \(focusProject).")
            }
            if freshness.provisional {
                exclusions.append("Some supporting signals are provisional because the local index is still catching up.")
            }
            return exclusions
        }()

        return BurnBarEvidenceSummary(
            availability: projectConversations.count < 2 ? .sparse : .available,
            projectName: focusProject,
            freshness: entries.contains(where: { $0.freshness == .stale }) ? .stale : .fresh,
            summary: "\(entries.count) recent indexed checkpoint\(entries.count == 1 ? "" : "s") ground BurnBar's read of \(focusProject).",
            sparseReason: projectConversations.count < 2 ? "Only one grounded checkpoint is available right now." : nil,
            entries: entries,
            inclusionReasons: [
                "Most recent indexed sessions for \(focusProject).",
                "Latest assistant checkpoints with project-specific burn attached."
            ],
            majorExclusions: majorExclusions,
            support: support,
            contradictions: contradictions
        )
    }

    private static func buildActions(
        projectName: String?,
        mission: BurnBarMissionSummary,
        direction: BurnBarDirectionSummary
    ) -> [BurnBarActionAvailability] {
        let missionApproval: BurnBarActionAvailability = {
            guard mission.availability == .available, mission.missionID.isEmpty == false else {
                return BurnBarActionAvailability(
                    kind: .missionApproval,
                    available: false,
                    reason: "BurnBar has not resolved a local mission to approve yet.",
                    title: BurnBarActionKind.missionApproval.label
                )
            }
            if mission.approval == .approved {
                return BurnBarActionAvailability(
                    kind: .missionApproval,
                    available: false,
                    reason: "The current mission checkpoint is already approved.",
                    title: "Mission Approved"
                )
            }
            return BurnBarActionAvailability(
                kind: .missionApproval,
                available: true,
                reason: "Operator sign-off is still pending for the current mission.",
                title: BurnBarActionKind.missionApproval.label
            )
        }()

        let directionOverride: BurnBarActionAvailability = {
            guard let projectName, direction.availability != .missing else {
                return BurnBarActionAvailability(
                    kind: .directionOverride,
                    available: false,
                    reason: "BurnBar needs an active project before you can steer direction.",
                    title: BurnBarActionKind.directionOverride.label
                )
            }
            return BurnBarActionAvailability(
                kind: .directionOverride,
                available: true,
                reason: "You can record an explicit direction call for \(projectName).",
                title: direction.mode == .overrideAnnotating || direction.mode == .overrideSuperseding
                    ? "Update Override"
                    : BurnBarActionKind.directionOverride.label
            )
        }()

        return [missionApproval, directionOverride]
    }

    private static func buildCompactSummary(
        projectName: String?,
        mission: BurnBarMissionSummary,
        direction: BurnBarDirectionSummary,
        burn: BurnBarBurnSummary
    ) -> String {
        let project = projectName ?? "workspace"
        if mission.availability == .missing {
            return "BurnBar is waiting on a first live project checkpoint."
        }
        return "\(project): \(mission.title) • \(direction.status.label.lowercased()) • \(burn.estimatedCostUSD.formatAsCost())"
    }

    private static func directionSummaryText(
        status: BurnBarDirectionAssessment,
        focusProject: String,
        latestConversation: ConversationRecord?,
        insightBrief: InsightBriefSnapshot,
        rollupStatusMessage: String?,
        retrievalHealth: RetrievalSystemHealthSnapshot
    ) -> String {
        switch status {
        case .aligned:
            return latestConversation?.summary?.nonEmpty
                ?? "Recent indexed checkpoints still cluster around \(focusProject), and BurnBar does not see a strong contradiction yet."
        case .drifting:
            return insightBrief.incompleteHint?.nonEmpty
                ?? "The latest checkpoint ends with open follow-ups, so BurnBar thinks the work needs steering before it drifts further."
        case .ambiguous:
            return rollupStatusMessage?.nonEmpty
                ?? retrievalHealth.degradedModes.first?.message
                ?? "BurnBar can see activity in \(focusProject), but the signal is mixed across recency, evidence freshness, or burn."
        case .notEnoughSignal:
            return "BurnBar does not have enough grounded evidence yet to call alignment for \(focusProject)."
        }
    }

    private static func directionNextActions(
        status: BurnBarDirectionAssessment,
        latestConversation: ConversationRecord?,
        insightBrief: InsightBriefSnapshot,
        retrievalHealth: RetrievalSystemHealthSnapshot
    ) -> [String] {
        switch status {
        case .aligned:
            return [
                "Keep importing sessions so BurnBar can catch the next inflection point.",
                "Approve the mission when the current checkpoint looks right."
            ]
        case .drifting:
            return [
                insightBrief.incompleteHint?.nonEmpty
                    ?? "Write down the next step BurnBar should optimize for.",
                "Use a direction override if you want to force the call instead of waiting on more evidence."
            ]
        case .ambiguous:
            return retrievalHealth.degradedModes.prefix(2).map(\.message).nonEmptyArray
                ?? ["Let BurnBar finish refreshing the local index before you trust the direction call."]
        case .notEnoughSignal:
            return [
                latestConversation?.summaryTitle?.nonEmpty.map { "Summarize and continue \($0)." }
                    ?? "Let BurnBar ingest another checkpoint for this project.",
                "Record an override if you already know the intended direction."
            ]
        }
    }

    private static func buildMissionRecommendation(
        state: BurnBarMissionLifecycle,
        latestConversation: ConversationRecord?,
        insightBrief: InsightBriefSnapshot,
        focusProject: String,
        approval: BurnBarMissionApprovalState
    ) -> String {
        if approval == .approved {
            return "BurnBar is carrying this checkpoint as the operator-approved mission for \(focusProject)."
        }
        switch state {
        case .blocked:
            return "The latest checkpoint reads blocked. BurnBar is waiting for an explicit unblock or a new plan."
        case .partial:
            return insightBrief.incompleteHint?.nonEmpty
                ?? "The mission still looks open-loop. BurnBar expects a next-step decision."
        case .completed:
            return "The latest checkpoint looks finished. Approve it if this is the mission you want BurnBar to carry forward."
        case .running:
            return latestConversation?.summary?.nonEmpty
                ?? "BurnBar sees active execution against the current mission."
        case .planned:
            return "BurnBar can name the current work, but it still needs more concrete execution before the mission feels locked."
        }
    }

    private static func historyTitle(for record: BurnBarOperatingActionRecord) -> String {
        switch record.actionKind {
        case .missionApproval:
            return "Mission approved"
        case .directionOverride:
            if record.overrideMode == .supersedeStatus {
                return "Direction overridden"
            }
            return "Direction annotated"
        }
    }

    private static func buildSupportJudgments(
        focusProject: String,
        direction: BurnBarDirectionSummary,
        insightBrief: InsightBriefSnapshot,
        entries: [BurnBarEvidenceEntry]
    ) -> [BurnBarEvidenceJudgment] {
        var judgments: [BurnBarEvidenceJudgment] = []
        if entries.isEmpty == false {
            judgments.append(
                BurnBarEvidenceJudgment(
                    id: "support-recency",
                    summary: "Recent work still clusters on \(focusProject).",
                    detail: "BurnBar is grounding direction against the newest indexed checkpoints instead of a stale aggregate."
                )
            )
        }
        if let modelShift = insightBrief.modelShiftHeadline?.nonEmpty {
            judgments.append(
                BurnBarEvidenceJudgment(
                    id: "support-model-shift",
                    summary: modelShift,
                    detail: "BurnBar kept the current model-shift rollup in view while judging direction."
                )
            )
        }
        if direction.status == .aligned {
            judgments.append(
                BurnBarEvidenceJudgment(
                    id: "support-aligned",
                    summary: "The latest checkpoint still sounds coherent with the active project.",
                    detail: entries.first?.summary ?? direction.summary
                )
            )
        }
        return judgments
    }

    private static func buildContradictionJudgments(
        latestConversation: ConversationRecord?,
        direction: BurnBarDirectionSummary,
        freshness: BurnBarFreshnessSummary,
        insightBrief: InsightBriefSnapshot
    ) -> [BurnBarEvidenceJudgment] {
        var judgments: [BurnBarEvidenceJudgment] = []
        if let incompleteHint = insightBrief.incompleteHint?.nonEmpty {
            judgments.append(
                BurnBarEvidenceJudgment(
                    id: "contradiction-open-loop",
                    summary: "The latest checkpoint still looks unfinished.",
                    detail: incompleteHint
                )
            )
        }
        if freshness.provisional, let reason = freshness.reasons.first {
            judgments.append(
                BurnBarEvidenceJudgment(
                    id: "contradiction-freshness",
                    summary: "Some of the evidence is still provisional.",
                    detail: reason
                )
            )
        }
        if direction.status == .drifting {
            judgments.append(
                BurnBarEvidenceJudgment(
                    id: "contradiction-drift",
                    summary: "BurnBar thinks the current work needs steering.",
                    detail: latestConversation?.summary?.nonEmpty
                        ?? latestConversation?.lastAssistantMessage.nonEmpty
                        ?? direction.summary
                )
            )
        }
        return judgments
    }

    private static func inferMissionState(
        latestText: String,
        isRefreshing: Bool,
        isStreaming: Bool,
        conversationCount: Int
    ) -> BurnBarMissionLifecycle {
        let lowered = latestText.lowercased()
        if isRefreshing || isStreaming {
            return .running
        }
        if containsAny(lowered, needles: ["blocked", "stuck", "unable", "permission denied", "failed", "error"]) {
            return .blocked
        }
        if containsAny(lowered, needles: ["shipped", "done", "completed", "resolved", "finished", "merged"]) {
            return .completed
        }
        if lowered.hasSuffix("?")
            || containsAny(lowered, needles: ["next step", "next steps", "follow up", "todo", "to-do", "need to"]) {
            return .partial
        }
        if conversationCount >= 2 {
            return .running
        }
        return .planned
    }

    private static func inferDirectionStatus(
        focus: ProjectFocus,
        latestConversation: ConversationRecord?,
        insightBrief: InsightBriefSnapshot,
        retrievalHealth: RetrievalSystemHealthSnapshot
    ) -> BurnBarDirectionAssessment {
        if focus.secondaryProject != nil {
            return .ambiguous
        }
        if retrievalHealth.degradedModes.contains(where: { $0.mode == .indexStale || $0.mode == .rebuildInProgress }) {
            return .ambiguous
        }
        if insightBrief.incompleteHint?.nonEmpty != nil {
            return .drifting
        }
        let lowered = [
            latestConversation?.summary,
            latestConversation?.lastAssistantMessage,
            insightBrief.whereLeftOff
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: "\n")
        if containsAny(lowered, needles: ["blocked", "stuck", "redo", "rethink", "unclear"]) {
            return .drifting
        }
        return .aligned
    }

    private static func selectProjectFocus(
        conversations: [ConversationRecord],
        usages: [TokenUsage]
    ) -> ProjectFocus {
        var scores: [String: Double] = [:]
        for (index, conversation) in conversations.prefix(12).enumerated() {
            let project = normalizeProjectName(conversation.projectName)
            guard project.isEmpty == false else { continue }
            scores[project, default: 0] += Double(max(12 - index, 1))
        }
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        for usage in usages where usage.startTime >= oneWeekAgo {
            let project = normalizeProjectName(usage.projectName)
            guard project.isEmpty == false else { continue }
            let weight = max(1, min(usage.cost * 8, Double(usage.totalTokens) / 50_000))
            scores[project, default: 0] += weight
        }
        let sorted = scores.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        let primary = sorted.first?.key
        let secondary: String?
        if sorted.count >= 2, let top = sorted.first, let next = sorted.dropFirst().first, next.value >= top.value * 0.8 {
            secondary = next.key
        } else {
            secondary = nil
        }
        return ProjectFocus(primaryProject: primary, secondaryProject: secondary)
    }

    private static func joinedMissionText(
        from latestConversation: ConversationRecord?,
        insightBrief: InsightBriefSnapshot
    ) -> String {
        [
            latestConversation?.summary,
            latestConversation?.summaryTitle,
            latestConversation?.lastAssistantMessage,
            insightBrief.whereLeftOff,
            insightBrief.incompleteHint,
        ]
        .compactMap { $0?.nonEmpty }
        .joined(separator: "\n")
    }

    private static func directionSummaryKeyText(
        _ conversation: ConversationRecord?
    ) -> String {
        [
            conversation?.summary,
            conversation?.lastAssistantMessage,
            conversation?.summaryTitle,
            conversation?.inferredTaskTitle,
        ]
        .compactMap { $0?.nonEmpty }
        .joined(separator: "\n")
    }

    private static func missionFingerprint(
        projectName: String,
        conversation: ConversationRecord?,
        conversationCount: Int
    ) -> String {
        let parts = [
            projectName,
            conversation?.id ?? "none",
            conversation?.indexedAt.ISO8601Format() ?? "never",
            "\(conversationCount)",
            conversation?.summaryUpdatedAt?.ISO8601Format() ?? "",
        ]
        return parts.joined(separator: "|")
    }

    private static func freshnessForEvidence(
        rollupFreshness: InsightRollupFreshness,
        latestConversation: ConversationRecord?
    ) -> BurnBarEvidenceFreshness {
        if rollupFreshness == .stale || rollupFreshness == .rebuilding {
            return .stale
        }
        guard let latestConversation else { return .unknown }
        return freshnessForConversation(latestConversation)
    }

    private static func freshnessForConversation(_ conversation: ConversationRecord) -> BurnBarEvidenceFreshness {
        let age = Date().timeIntervalSince(conversation.indexedAt)
        if age < 24 * 60 * 60 {
            return .fresh
        }
        if age.isFinite {
            return .stale
        }
        return .unknown
    }

    private static func evidenceReason(
        index: Int,
        latestConversation: ConversationRecord?,
        conversation: ConversationRecord
    ) -> String {
        if conversation.id == latestConversation?.id {
            return "Latest indexed checkpoint"
        }
        if index == 1 {
            return "Corroborating recent session"
        }
        return "Recent project context"
    }

    private static func normalizeProjectName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsAny(_ text: String, needles: [String]) -> Bool {
        needles.contains(where: text.contains)
    }

    private static func truncated(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func maxDate(_ dates: [Date?]) -> Date? {
        dates.compactMap { $0 }.max()
    }
}

private struct ProjectFocus: Equatable {
    let primaryProject: String?
    let secondaryProject: String?

    var scopeLabel: String {
        if secondaryProject != nil {
            return "Cross-project"
        }
        return primaryProject ?? "Workspace"
    }
}

// MARK: - Setup Guide

struct BurnBarSetupGuideSnapshot: Equatable, Sendable {
    let headline: String
    let localTitle: String
    let localDetail: String
    let cloudTitle: String
    let cloudDetail: String
    let runtimeTitle: String
    let runtimeDetail: String
    let providerHealthTitle: String
    let providerHealthDetail: String
}

enum BurnBarSetupGuideBuilder {
    static func build(
        detection: [AgentProvider: Bool],
        indexingEnabled: Bool,
        isSignedIn: Bool,
        conversationCloudEnabled: Bool,
        iCloudMirrorEnabled: Bool,
        hermesAvailable: Bool? = nil,
        openClawAvailable: Bool? = nil
    ) -> BurnBarSetupGuideSnapshot {
        let detectedCount = detection.values.filter { $0 }.count
        let gatewayParts: [String] = [
            statusLabel(name: "Hermes", ok: hermesAvailable),
            statusLabel(name: "OpenClaw", ok: openClawAvailable),
        ]
        .compactMap { $0 }

        let providerHealthDetail: String = {
            if gatewayParts.isEmpty {
                return "BurnBar can scan \(detectedCount) provider source\(detectedCount == 1 ? "" : "s") from disk. Chat gateways stay optional until you want live companion models."
            }
            return gatewayParts.joined(separator: " · ")
        }()

        let runtimeTitle = detectedCount > 0 ? "Live local state" : "Static setup mode"
        let runtimeDetail = detectedCount > 0
            ? "BurnBar can already see \(detectedCount) provider source\(detectedCount == 1 ? "" : "s") on this Mac. Your first scan turns the UI into live mission, direction, and burn state."
            : "BurnBar can explain setup and safety right away, but mission and direction stay provisional until it sees local logs."

        let cloudDetail: String = {
            if isSignedIn {
                if conversationCloudEnabled || iCloudMirrorEnabled {
                    return "Authenticated features are on. BurnBar can sync metadata across devices, and any iCloud mirror stays in your Apple account instead of BurnBar's servers."
                }
                return "You are signed in, but cloud features are still optional. Local scans, burn, and indexed evidence work without turning sync on."
            }
            return "Cloud is optional. Sign in only if you want cross-device recall or shared artifacts. BurnBar's local scans, burn, and index continue to work without auth."
        }()

        return BurnBarSetupGuideSnapshot(
            headline: "BurnBar is local-first: it reads your agent logs, builds a private operating picture on your Mac, and only uses auth when you explicitly turn on shared or cross-device features.",
            localTitle: "Local by default",
            localDetail: indexingEnabled
                ? "Scans, burn accounting, local search, evidence previews, and mission/direction summaries stay on this Mac."
                : "Scans and burn accounting stay local. Turn on local indexing when you want transcript-grounded evidence and better direction reads.",
            cloudTitle: "Cloud is optional",
            cloudDetail: cloudDetail,
            runtimeTitle: runtimeTitle,
            runtimeDetail: runtimeDetail,
            providerHealthTitle: "Provider setup health",
            providerHealthDetail: providerHealthDetail
        )
    }

    private static func statusLabel(name: String, ok: Bool?) -> String? {
        guard let ok else { return nil }
        return "\(name) \(ok ? "reachable" : "offline")"
    }
}

struct BurnBarOperatingModelGuideCard: View {
    let guide: BurnBarSetupGuideSnapshot
    var compact: Bool = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: compact ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md) {
                Text(compact ? guide.runtimeTitle : "How BurnBar Works")
                    .font(compact ? DesignSystem.Typography.headline : DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(guide.headline)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                guideRow(title: guide.localTitle, detail: guide.localDetail, icon: "macwindow")
                guideRow(title: guide.cloudTitle, detail: guide.cloudDetail, icon: "cloud")
                guideRow(title: guide.runtimeTitle, detail: guide.runtimeDetail, icon: "waveform.path.ecg")
                guideRow(title: guide.providerHealthTitle, detail: guide.providerHealthDetail, icon: "checkmark.shield")
            }
            .padding(compact ? DesignSystem.Spacing.md : DesignSystem.Spacing.lg)
        }
    }

    private func guideRow(title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.amber)
                .frame(width: 18, alignment: .top)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(detail)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct BurnBarControllerRuntimeGuideCard: View {
    @Bindable var settingsManager: SettingsManager
    @Bindable var daemonManager: BurnBarDaemonManager
    var compact: Bool = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: compact ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Controller Runtime")
                            .font(compact ? DesignSystem.Typography.headline : DesignSystem.Typography.title)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text("BurnBar’s review controller is local-first: the daemon owns live runtime state, while this app mirrors enough context to stay useful offline.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    BurnBarStatusBadge(
                        title: daemonManager.status.label,
                        color: {
                            switch daemonManager.status {
                            case .healthy: return DesignSystem.Colors.success
                            case .checking: return DesignSystem.Colors.warning
                            case .notInstalled: return DesignSystem.Colors.textMuted
                            case .unhealthy: return DesignSystem.Colors.error
                            }
                        }()
                    )
                }

                runtimeGuideRow(
                    title: settingsManager.controllerLocalNotificationsEnabled ? "Notifications on" : "Notifications off",
                    detail: settingsManager.controllerLocalNotificationsEnabled
                        ? "Local nudges can fire even when the BurnBar window is closed."
                        : "BurnBar will stay quiet until you opt into local nudges.",
                    icon: "bell.badge"
                )
                runtimeGuideRow(
                    title: settingsManager.controllerTelegramEnabled ? "Telegram armed" : "Telegram optional",
                    detail: settingsManager.controllerTelegramEnabled
                        ? "Use Telegram for pending, followups, answer, snooze, and status commands once the daemon is configured."
                        : "Leave Telegram off if you want BurnBar to stay on-device only.",
                    icon: "paperplane"
                )
                runtimeGuideRow(
                    title: settingsManager.controllerCalendarIntegrationEnabled ? "Calendar holds ready" : "Calendar stays manual",
                    detail: settingsManager.controllerCalendarIntegrationEnabled
                        ? "Open followups can drop local calendar placeholders without exposing transcripts."
                        : "BurnBar will keep followups in-app until you opt into calendar holds.",
                    icon: "calendar.badge.plus"
                )
                runtimeGuideRow(
                    title: settingsManager.controllerSimulatorToolsEnabled ? "Replay visible" : "Replay hidden",
                    detail: settingsManager.controllerSimulatorToolsEnabled
                        ? "Simulator and replay affordances stay visible for operator testing."
                        : "Replay tooling is hidden from the main product flow until you need it.",
                    icon: "play.square.stack"
                )
            }
            .padding(compact ? DesignSystem.Spacing.md : DesignSystem.Spacing.lg)
        }
    }

    private func runtimeGuideRow(title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.teal)
                .frame(width: 18, alignment: .top)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(detail)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Shared Summary Views

struct BurnBarDashboardOperatingSection: View {
    @Bindable var layer: BurnBarOperatingLayer

    var body: some View {
        let snapshot = layer.snapshot

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            BurnBarOperatingFreshnessStrip(summary: snapshot.freshness, compact: false)

            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                BurnBarMissionSummaryCard(summary: snapshot.mission)
                BurnBarDirectionSummaryCard(summary: snapshot.direction)
                BurnBarBurnSummaryCard(summary: snapshot.burn)
            }

            BurnBarEvidencePanel(summary: snapshot.evidence)
            BurnBarOperatingActionBar(layer: layer, compact: false)
            BurnBarControllerWorkbenchPanel(layer: layer, condensed: false)
            BurnBarOperatingHistoryPanel(entries: snapshot.recentHistory)
        }
    }
}

struct BurnBarCompactOperatingHomeCard: View {
    @Bindable var layer: BurnBarOperatingLayer
    let onOpenDashboard: () -> Void

    var body: some View {
        let snapshot = layer.snapshot

        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.projectName ?? "Awaiting first scan")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text(snapshot.compactSummary)
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    BurnBarStatusBadge(
                        title: snapshot.direction.status.label,
                        color: snapshot.direction.status.color
                    )
                }

                BurnBarOperatingFreshnessStrip(summary: snapshot.freshness, compact: true)

                HStack(spacing: DesignSystem.Spacing.md) {
                    compactMetric(title: "Mission", value: snapshot.mission.approval.label)
                    compactMetric(title: "Burn", value: snapshot.burn.estimatedCostUSD.formatAsCost())
                    compactMetric(title: "Tokens", value: snapshot.burn.totalTokens.formatAsTokenVolume())
                }

                BurnBarControllerCompactSummary(runtime: snapshot.controllerRuntime)

                if let pendingHighlight = snapshot.pendingHighlight?.nonEmpty {
                    Text(pendingHighlight)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.amber)
                }

                BurnBarOperatingActionBar(layer: layer, compact: true)

                Button(action: onOpenDashboard) {
                    HStack(spacing: 4) {
                        Text("Open Dashboard")
                            .font(DesignSystem.Typography.tiny)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(DesignSystem.Colors.blaze)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignSystem.Spacing.md)
        }
    }

    private func compactMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
            Text(value)
                .font(DesignSystem.Typography.monoSmall)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
    }
}

private enum HermesOperatingStripPage: Int, CaseIterable {
    case mission
    case quotas

    var title: String {
        switch self {
        case .mission: return "Mission"
        case .quotas: return "Quotas"
        }
    }

    var next: Self {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self) else { return self }
        return all[(i + 1) % all.count]
    }

    var previous: Self {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self) else { return self }
        return all[(i + all.count - 1) % all.count]
    }
}

struct BurnBarHermesOperatingStrip: View {
    @Bindable var layer: BurnBarOperatingLayer
    @State private var isExpanded = false
    @State private var stripPage: HermesOperatingStripPage = .mission

    var body: some View {
        let snapshot = layer.snapshot

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            stripNavigationRow(snapshot: snapshot)

            if isExpanded {
                Group {
                    switch stripPage {
                    case .mission:
                        missionExpandedBody(snapshot: snapshot)
                    case .quotas:
                        quotasExpandedBody
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Group {
                    switch stripPage {
                    case .mission:
                        missionCollapsedSummary(snapshot: snapshot)
                    case .quotas:
                        quotasCollapsedSummary(runtime: snapshot.controllerRuntime)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm + 2)
        .padding(.vertical, DesignSystem.Spacing.xs + 2)
        .background(DesignSystem.Colors.surfaceElevated.opacity(0.7))
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .animation(.easeInOut(duration: 0.2), value: stripPage)
    }

    // MARK: - Navigation

    private func stripNavigationRow(snapshot: BurnBarOperatingSnapshot) -> some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.xs) {
            Button {
                stripPage = stripPage.previous
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.hermesAureate)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("Previous operating view")

            Text(stripPage.title)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textMuted)
                .textCase(.uppercase)
                .lineLimit(1)

            Button {
                stripPage = stripPage.next
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.hermesAureate)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("Next operating view")

            Spacer(minLength: 0)

            // Keep collapsed nav lightweight; expanded page already contains detailed badges.

            Button {
                isExpanded.toggle()
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel(isExpanded ? "Collapse mission panel" : "Expand mission panel")
        }
    }

    // MARK: - Mission

    private func missionCollapsedSummary(snapshot: BurnBarOperatingSnapshot) -> some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.projectName ?? "BurnBar home")
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .textCase(.uppercase)
                Text(snapshot.mission.title)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(snapshot.burn.estimatedCostUSD.formatAsCost())
                .font(DesignSystem.Typography.monoSmall)
                .foregroundStyle(DesignSystem.Colors.hermesAureate)
        }
    }

    private func quotasCollapsedSummary(runtime: BurnBarControllerRuntimeSnapshot) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            quotaChip(
                title: "Q",
                value: "\(runtime.pendingQuestions.count)",
                color: DesignSystem.Colors.amber
            )
            quotaChip(
                title: "F",
                value: "\(runtime.openFollowups.count)",
                color: DesignSystem.Colors.whimsy
            )
            if let mission = runtime.missions.first {
                quotaChip(
                    title: "M",
                    value: mission.state.label,
                    color: mission.state.color
                )
            }
            Spacer(minLength: 0)
            Text(runtime.source.label)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .lineLimit(1)
        }
    }

    private func quotaChip(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
            Text(value)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }

    private func missionExpandedBody(snapshot: BurnBarOperatingSnapshot) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.projectName ?? "BurnBar home")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .textCase(.uppercase)
                    Text(snapshot.mission.title)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                    Text(snapshot.direction.summary)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    BurnBarStatusBadge(title: snapshot.direction.status.label, color: snapshot.direction.status.color)
                    Text(snapshot.burn.estimatedCostUSD.formatAsCost())
                        .font(DesignSystem.Typography.monoSmall)
                        .foregroundStyle(DesignSystem.Colors.hermesAureate)
                }
            }

            BurnBarOperatingFreshnessStrip(summary: snapshot.freshness, compact: true)
            BurnBarOperatingActionBar(layer: layer, compact: true)
        }
    }

    // MARK: - Quotas

    private var quotasExpandedBody: some View {
        BurnBarControllerCompactSummary(runtime: layer.snapshot.controllerRuntime, compact: true)
    }
}

private struct BurnBarOperatingFreshnessStrip: View {
    let summary: BurnBarFreshnessSummary
    var compact: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(summary.status.color)
                .frame(width: compact ? 6 : 8, height: compact ? 6 : 8)

            Text(summary.headline)
                .font(compact ? DesignSystem.Typography.tiny : DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            if let updatedAt = summary.updatedAt {
                Text(relativeTime(from: updatedAt))
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
            }

            Spacer()

            if compact == false, let reason = summary.reasons.first?.nonEmpty {
                Text(reason)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct BurnBarMissionSummaryCard: View {
    let summary: BurnBarMissionSummary

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .top) {
                    header(title: "Mission")
                    Spacer()
                    BurnBarStatusBadge(title: summary.state.label, color: summary.state.color)
                }

                Text(summary.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)

                Text(summary.subtitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(3)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    BurnBarStatusBadge(title: summary.approval.label, color: summary.approval.color)
                    if let note = summary.approvalNote?.nonEmpty {
                        Text(note)
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                            .lineLimit(1)
                    }
                }

                Divider().background(DesignSystem.Colors.border)

                HStack(spacing: DesignSystem.Spacing.lg) {
                    metric(title: "Sessions", value: "\(summary.sessionCount)")
                    metric(title: "Burn", value: summary.estimatedCostUSD.formatAsCost())
                    metric(title: "Tokens", value: summary.totalTokens.formatAsTokenVolume())
                }

                Text(summary.recommendationSummary)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct BurnBarDirectionSummaryCard: View {
    let summary: BurnBarDirectionSummary

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .top) {
                    header(title: "Direction")
                    Spacer()
                    BurnBarStatusBadge(title: summary.status.label, color: summary.status.color)
                }

                Text(summary.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)

                Text(summary.summary)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(4)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    BurnBarStatusBadge(title: summary.mode.label, color: badgeColor(for: summary.mode))
                    BurnBarStatusBadge(title: summary.freshness.label, color: summary.freshness.color)
                }

                if let sparseReason = summary.sparseReason?.nonEmpty {
                    Text(sparseReason)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if summary.nextActions.isEmpty == false {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Next")
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                            .textCase(.uppercase)
                        ForEach(summary.nextActions.prefix(2), id: \.self) { action in
                            Text("• \(action)")
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func badgeColor(for mode: BurnBarDirectionMode) -> Color {
        switch mode {
        case .inferred: return DesignSystem.Colors.blaze
        case .sparse: return DesignSystem.Colors.textSecondary
        case .overrideAnnotating, .overrideSuperseding: return DesignSystem.Colors.whimsy
        }
    }
}

private struct BurnBarBurnSummaryCard: View {
    let summary: BurnBarBurnSummary

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                header(title: "Burn")

                Text(summary.estimatedCostUSD.formatAsCost())
                    .font(DesignSystem.Typography.monoLarge)
                    .foregroundStyle(DesignSystem.Colors.primaryGradient)

                Text(summary.windowLabel)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                HStack(spacing: DesignSystem.Spacing.lg) {
                    metric(title: "Sessions", value: "\(summary.sessionCount)")
                    metric(title: "Tokens", value: summary.totalTokens.formatAsTokenVolume())
                }

                if let latestSource = summary.latestSource?.nonEmpty {
                    Text("Latest source: \(latestSource)")
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                if let dominantModel = summary.dominantModel?.nonEmpty {
                    Text("Dominant model: \(dominantModel)")
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .lineLimit(1)
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .frame(width: 250, alignment: .topLeading)
    }
}

private struct BurnBarEvidencePanel: View {
    let summary: BurnBarEvidenceSummary

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    header(title: "Evidence")
                    Spacer()
                    BurnBarStatusBadge(title: summary.freshness.label, color: summary.freshness.color)
                }

                Text(summary.summary)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let sparseReason = summary.sparseReason?.nonEmpty {
                    Text(sparseReason)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.amber)
                }

                if summary.entries.isEmpty == false {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(summary.entries) { entry in
                            BurnBarEvidenceEntryRow(entry: entry)
                        }
                    }
                }

                if summary.support.isEmpty == false || summary.contradictions.isEmpty == false {
                    Divider().background(DesignSystem.Colors.border)

                    HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
                        if summary.support.isEmpty == false {
                            judgmentColumn(title: "Support", color: DesignSystem.Colors.success, entries: summary.support)
                        }
                        if summary.contradictions.isEmpty == false {
                            judgmentColumn(title: "Contradictions", color: DesignSystem.Colors.warning, entries: summary.contradictions)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }

    private func judgmentColumn(
        title: String,
        color: Color,
        entries: [BurnBarEvidenceJudgment]
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(color)
                .textCase(.uppercase)
            ForEach(entries.prefix(2)) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.summary)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(entry.detail)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct BurnBarEvidenceEntryRow: View {
    let entry: BurnBarEvidenceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.sourceLabel)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(entry.summary)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                }

                Spacer()

                BurnBarStatusBadge(title: entry.freshness.label, color: entry.freshness.color)
            }

            Text(entry.detail)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(entry.includedReason)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                .stroke(DesignSystem.Colors.border.opacity(0.45), lineWidth: 0.5)
        )
    }
}

private struct BurnBarOperatingActionBar: View {
    @Bindable var layer: BurnBarOperatingLayer
    var compact: Bool
    @State private var showingDirectionOverride = false

    var body: some View {
        let snapshot = layer.snapshot
        let missionAction = snapshot.availableActions.first(where: { $0.kind == .missionApproval })
        let directionAction = snapshot.availableActions.first(where: { $0.kind == .directionOverride })

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                BurnBarActionButton(
                    title: missionAction?.title ?? BurnBarActionKind.missionApproval.label,
                    icon: BurnBarActionKind.missionApproval.icon,
                    compact: compact,
                    enabled: missionAction?.available == true,
                    emphasized: missionAction?.available == true
                ) {
                    layer.approveMission()
                }

                BurnBarActionButton(
                    title: directionAction?.title ?? BurnBarActionKind.directionOverride.label,
                    icon: BurnBarActionKind.directionOverride.icon,
                    compact: compact,
                    enabled: directionAction?.available == true,
                    emphasized: directionAction?.available == true
                ) {
                    showingDirectionOverride = true
                }
            }

            if compact == false {
                if let missionReason = missionAction?.reason.nonEmpty {
                    Text(missionReason)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            } else if let pending = snapshot.pendingHighlight?.nonEmpty {
                Text(pending)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }

            if let feedback = layer.actionFeedback {
                Text(feedback.detail?.nonEmpty ?? feedback.message)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(feedback.tone.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(isPresented: $showingDirectionOverride) {
            BurnBarDirectionOverrideSheet(layer: layer)
                .presentationBackground(Material.ultraThinMaterial)
        }
    }
}

private struct BurnBarControllerCompactSummary: View {
    let runtime: BurnBarControllerRuntimeSnapshot
    var compact: Bool = false

    var body: some View {
        let mission = runtime.missions.first

        HStack(spacing: compact ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md) {
            compactPill(
                title: "Questions",
                value: "\(runtime.pendingQuestions.count)",
                color: DesignSystem.Colors.amber
            )
            compactPill(
                title: "Followups",
                value: "\(runtime.openFollowups.count)",
                color: DesignSystem.Colors.whimsy
            )
            if let mission {
                compactPill(
                    title: "Mission",
                    value: mission.state.label,
                    color: mission.state.color
                )
            }
            compactPill(
                title: mission?.latestTakeoverState == nil ? "Runtime" : "Takeover",
                value: mission?.latestTakeoverState?.label ?? runtime.source.label,
                color: mission?.latestTakeoverState?.color ?? DesignSystem.Colors.blaze
            )
            Spacer(minLength: 0)
        }
    }

    private func compactPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
            Text(value)
                .font(compact ? DesignSystem.Typography.tiny : DesignSystem.Typography.caption)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}

private struct BurnBarControllerWorkbenchPanel: View {
    @Bindable var layer: BurnBarOperatingLayer
    var condensed: Bool

    var body: some View {
        let runtime = layer.snapshot.controllerRuntime

        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        header(title: condensed ? "Controller" : "Controller Inbox")
                        Text(runtime.summary.headline)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text(runtime.summary.detail)
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        BurnBarStatusBadge(title: runtime.source.label, color: DesignSystem.Colors.blaze)
                        Text(runtime.updatedAt == .distantPast ? "Awaiting runtime" : runtime.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                    }
                }

                BurnBarControllerCompactSummary(runtime: runtime)

                if runtime.pendingQuestions.isEmpty == false {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Pending Questions")
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                            .textCase(.uppercase)
                        ForEach(runtime.pendingQuestions.prefix(condensed ? 1 : 3)) { question in
                            BurnBarQuestionRow(layer: layer, question: question, condensed: condensed)
                        }
                    }
                }

                if runtime.openFollowups.isEmpty == false {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Followups")
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                            .textCase(.uppercase)
                        ForEach(runtime.openFollowups.prefix(condensed ? 1 : 3)) { followup in
                            BurnBarFollowupRow(layer: layer, followup: followup)
                        }
                    }
                }

                if let mission = runtime.missions.first {
                    Divider().background(DesignSystem.Colors.border)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Mission Runtime")
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                            .textCase(.uppercase)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mission.title)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    Text(mission.packetSummary?.nonEmpty ?? mission.summary)
                                        .font(DesignSystem.Typography.tiny)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 6) {
                                    BurnBarStatusBadge(title: mission.state.label, color: mission.state.color)
                                    BurnBarStatusBadge(title: mission.approval.label, color: mission.approval.color)
                                }
                            }

                            HStack(spacing: DesignSystem.Spacing.xs) {
                                missionChip(title: "Burn", value: mission.burnCostUSD.formatAsCost(), color: DesignSystem.Colors.hermesAureate)
                                if mission.packetRunCount > 0 {
                                    missionChip(title: "Runs", value: "\(mission.packetRunCount)", color: DesignSystem.Colors.blaze)
                                }
                                if mission.takeoverCount > 0 {
                                    missionChip(
                                        title: "Takeovers",
                                        value: "\(mission.takeoverCount)",
                                        color: mission.latestTakeoverState?.color ?? DesignSystem.Colors.blaze
                                    )
                                }
                            }

                            if let activeWorkerName = mission.activeWorkerName?.nonEmpty
                                ?? mission.packetSummary?.nonEmpty {
                                missionFactRow(
                                    icon: "bolt.horizontal.circle.fill",
                                    title: "Active packet",
                                    value: activeWorkerName
                                )
                            }
                            if let activeRunID = mission.activeRunID?.nonEmpty {
                                missionFactRow(
                                    icon: "point.3.filled.connected.trianglepath.dotted",
                                    title: "Run provenance",
                                    value: activeRunID
                                )
                            }
                            if let latestResult = mission.latestResultSummary?.nonEmpty {
                                missionFactRow(
                                    icon: "checklist.checked",
                                    title: "Latest result",
                                    value: latestResult
                                )
                            }
                            if let takeoverState = mission.latestTakeoverState,
                               let takeoverReason = mission.latestTakeoverReason?.nonEmpty {
                                missionFactRow(
                                    icon: "arrow.triangle.branch",
                                    title: takeoverState.label,
                                    value: takeoverReason,
                                    accent: takeoverState.color
                                )
                            }
                            if let takeoverRunID = mission.latestTakeoverRunID?.nonEmpty {
                                missionFactRow(
                                    icon: "figure.run",
                                    title: "Takeover run",
                                    value: takeoverRunID
                                )
                            }
                        }
                    }
                }

                if runtime.recentEvents.isEmpty == false {
                    Divider().background(DesignSystem.Colors.border)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Recent Controller Events")
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                            .textCase(.uppercase)
                        ForEach(runtime.recentEvents.prefix(condensed ? 2 : 4)) { event in
                            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: event.category.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(event.category.color)
                                    .frame(width: 16, alignment: .top)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    Text(event.summary)
                                        .font(DesignSystem.Typography.tiny)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let detail = event.detail?.nonEmpty {
                                        Text(detail)
                                            .font(DesignSystem.Typography.tiny)
                                            .foregroundStyle(DesignSystem.Colors.textMuted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer()
                                Text(relativeTime(from: event.createdAt))
                                    .font(DesignSystem.Typography.tiny)
                                    .foregroundStyle(DesignSystem.Colors.textMuted)
                            }
                        }
                    }
                }

                if let feedback = layer.controllerFeedback {
                    Text(feedback.message)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(feedback.tone.color)
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }

    @ViewBuilder
    private func missionChip(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
            Text(value)
                .font(DesignSystem.Typography.monoSmall)
                .foregroundStyle(color)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                .fill(DesignSystem.Colors.surfaceElevated.opacity(0.7))
        )
    }

    @ViewBuilder
    private func missionFactRow(
        icon: String,
        title: String,
        value: String,
        accent: Color = DesignSystem.Colors.textPrimary
    ) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 16, alignment: .top)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .textCase(.uppercase)
                Text(value)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct BurnBarQuestionRow: View {
    @Bindable var layer: BurnBarOperatingLayer
    let question: BurnBarControllerQuestion
    let condensed: Bool

    init(layer: BurnBarOperatingLayer, question: BurnBarControllerQuestion, condensed: Bool = false) {
        self._layer = Bindable(layer)
        self.question = question
        self.condensed = condensed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if question.isUnread {
                            Circle()
                                .fill(DesignSystem.Colors.ember)
                                .frame(width: 7, height: 7)
                        }
                        Text(question.title)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        if let stageLabel = question.stageLabel?.nonEmpty {
                            Text(stageLabel)
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(DesignSystem.Colors.blaze)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(DesignSystem.Colors.blaze.opacity(0.12))
                                )
                        }
                    }
                    if let deepLink = question.deepLink {
                        HStack(spacing: 4) {
                            Image(systemName: icon(for: deepLink.kind))
                                .font(.system(size: 9, weight: .semibold))
                            Text(deepLink.title)
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    BurnBarStatusBadge(title: question.priority.rawValue.capitalized, color: question.priority.color)
                    if question.notificationCount > 0 {
                        Text("Nudged \(question.notificationCount)x")
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                    }
                }
            }
            Text(question.prompt)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let evidenceHint = question.evidenceHint?.nonEmpty {
                Text(evidenceHint)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
            }
            if condensed == false, question.suggestedOptions.isEmpty == false {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(question.suggestedOptions.prefix(2)) { option in
                        Button {
                            Task {
                                await layer.answerPendingQuestion(
                                    id: question.id,
                                    answer: option.answer,
                                    selectedOptionID: option.id
                                )
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(DesignSystem.Typography.tiny)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                if let detail = option.detail?.nonEmpty {
                                    Text(detail)
                                        .font(DesignSystem.Typography.tiny)
                                        .foregroundStyle(DesignSystem.Colors.textMuted)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                    .fill(DesignSystem.Colors.surfaceElevated.opacity(0.9))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, DesignSystem.Spacing.xxs)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.surface.opacity(0.82),
                    question.isUnread ? DesignSystem.Colors.ember.opacity(0.08) : DesignSystem.Colors.surfaceElevated.opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                .stroke(DesignSystem.Colors.border.opacity(0.45), lineWidth: 0.5)
        )
    }

    private func icon(for kind: BurnBarControllerQuestionDeepLinkKind) -> String {
        switch kind {
        case .sessionLog: return "doc.text.magnifyingglass"
        case .dashboard: return "square.grid.2x2"
        case .project: return "folder"
        case .settings: return "gearshape"
        }
    }
}

private struct BurnBarFollowupRow: View {
    @Bindable var layer: BurnBarOperatingLayer
    let followup: BurnBarControllerFollowup

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                Text(followup.title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                if let dueAt = followup.dueAt {
                    Text(dueAt.formatted(date: .omitted, time: .shortened))
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
            }

            Text(followup.summary)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button("Done") {
                    Task { await layer.completeFollowup(id: followup.id) }
                }
                .buttonStyle(.plain)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.success)

                Button("Snooze") {
                    let until = Date().addingTimeInterval(Double(SettingsManager.shared.controllerDefaultSnoozeMinutes) * 60)
                    Task { await layer.snoozeFollowup(id: followup.id, until: until) }
                }
                .buttonStyle(.plain)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.amber)

                if SettingsManager.shared.controllerCalendarIntegrationEnabled {
                    Button("Calendar") {
                        Task { await layer.scheduleFollowupCalendar(id: followup.id, title: followup.title) }
                    }
                    .buttonStyle(.plain)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.teal)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                .stroke(DesignSystem.Colors.border.opacity(0.45), lineWidth: 0.5)
        )
    }
}

private struct BurnBarOperatingHistoryPanel: View {
    let entries: [BurnBarOperatingHistoryEntry]

    var body: some View {
        guard entries.isEmpty == false else { return AnyView(EmptyView()) }

        return AnyView(
            GlassCard {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        header(title: "Governance")
                        Spacer()
                        Text("Local history")
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                    }

                    ForEach(entries.prefix(4)) { entry in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: entry.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(entry.tint)
                                .frame(width: 18, alignment: .top)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(entry.title)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    Spacer()
                                    Text(relativeTime(from: entry.createdAt))
                                        .font(DesignSystem.Typography.tiny)
                                        .foregroundStyle(DesignSystem.Colors.textMuted)
                                }

                                Text(entry.summary)
                                    .font(DesignSystem.Typography.tiny)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                if let detail = entry.detail?.nonEmpty {
                                    Text(detail)
                                        .font(DesignSystem.Typography.tiny)
                                        .foregroundStyle(DesignSystem.Colors.textMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
        )
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct BurnBarDirectionOverrideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var layer: BurnBarOperatingLayer

    @State private var mode: BurnBarDirectionOverrideModeKind = .supersedeStatus
    @State private var forcedStatus: BurnBarDirectionAssessment = .aligned
    @State private var summary: String = ""
    @State private var rationale: String = ""

    var body: some View {
        let snapshot = layer.snapshot

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Direction Override")
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("Record an operator call for \(snapshot.projectName ?? "this project"). BurnBar will carry it across dashboard, popover, and Hermes.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Mode", selection: $mode) {
                ForEach(BurnBarDirectionOverrideModeKind.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if mode == .supersedeStatus {
                Picker("Status", selection: $forcedStatus) {
                    ForEach(BurnBarDirectionAssessment.allCases, id: \.self) { status in
                        Text(status.label).tag(status)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Summary")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                TextField("What should BurnBar carry forward?", text: $summary)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Rationale")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                TextEditor(text: $rationale)
                    .frame(minHeight: 120)
                    .padding(6)
                    .background(DesignSystem.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                            .stroke(DesignSystem.Colors.border.opacity(0.55), lineWidth: 0.5)
                    )
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Spacer()

                Button("Save Override") {
                    layer.saveDirectionOverride(
                        mode: mode,
                        forcedStatus: mode == .supersedeStatus ? forcedStatus : nil,
                        summary: summary,
                        rationale: rationale
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.blaze)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(minWidth: 420, idealWidth: 460)
        .onAppear {
            if let projectName = snapshot.projectName {
                summary = snapshot.direction.overrideSummary?.nonEmpty
                    ?? "BurnBar should carry my latest call for \(projectName)."
            }
            rationale = snapshot.direction.sparseReason?.nonEmpty
                ?? snapshot.direction.summary
        }
    }
}

private struct BurnBarActionButton: View {
    let title: String
    let icon: String
    let compact: Bool
    let enabled: Bool
    let emphasized: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 10 : 12, weight: .semibold))
                Text(title)
                    .font(compact ? DesignSystem.Typography.tiny : DesignSystem.Typography.caption)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, compact ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md)
            .padding(.vertical, compact ? DesignSystem.Spacing.xs + 2 : DesignSystem.Spacing.sm)
            .background(backgroundShape)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var foregroundColor: Color {
        guard enabled else { return DesignSystem.Colors.textMuted }
        return emphasized ? DesignSystem.Colors.blaze : DesignSystem.Colors.textPrimary
    }

    @ViewBuilder
    private var backgroundShape: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill((enabled ? DesignSystem.Colors.surfaceElevated : DesignSystem.Colors.surface).opacity(emphasized ? 0.7 : 0.45))
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(enabled ? DesignSystem.Colors.blaze.opacity(0.25) : DesignSystem.Colors.border.opacity(0.25), lineWidth: 0.6)
        }
    }
}

private struct BurnBarStatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(DesignSystem.Typography.tiny)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

private func header(title: String) -> some View {
    Text(title)
        .font(DesignSystem.Typography.tiny)
        .foregroundStyle(DesignSystem.Colors.textMuted)
        .textCase(.uppercase)
}

private func metric(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(title)
            .font(DesignSystem.Typography.tiny)
            .foregroundStyle(DesignSystem.Colors.textMuted)
        Text(value)
            .font(DesignSystem.Typography.monoSmall)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Array where Element == String {
    var nonEmptyArray: [String]? {
        isEmpty ? nil : self
    }
}
