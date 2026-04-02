import Foundation
import SwiftUI

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
