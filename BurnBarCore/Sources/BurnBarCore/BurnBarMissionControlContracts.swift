import Foundation

public typealias BurnBarMetadata = [String: BurnBarJSONValue]

public enum BurnBarControllerReviewCadence: String, Codable, CaseIterable, Hashable, Sendable {
    case daily
    case weekly
    case adHoc = "ad_hoc"
}

public enum BurnBarControllerFreshnessState: String, Codable, CaseIterable, Hashable, Sendable {
    case fresh
    case aging
    case stale
    case provisional
    case missing
}

public enum BurnBarReviewProjectStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case healthy
    case needsAttention = "needs_attention"
    case stale
    case onboarding
    case paused
}

public enum BurnBarControllerProjectAutomationMode: String, Codable, CaseIterable, Hashable, Sendable {
    case manual
    case suggested
    case scheduled
}

public enum BurnBarControllerProjectIngestionSource: String, Codable, CaseIterable, Hashable, Sendable {
    case manual
    case appActivity = "app_activity"
}

public enum BurnBarPendingQuestionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case pending
    case answered
    case dismissed
    case expired
}

public enum BurnBarPendingQuestionPriority: String, Codable, CaseIterable, Hashable, Sendable {
    case low
    case medium
    case high
    case critical
}

public enum BurnBarQuestionDeepLinkKind: String, Codable, CaseIterable, Hashable, Sendable {
    case sessionLog = "session_log"
    case dashboard
    case project
    case settings
}

public enum BurnBarFollowupStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case open
    case done
    case snoozed
}

public enum BurnBarFollowupKind: String, Codable, CaseIterable, Hashable, Sendable {
    case pendingQuestion = "pending_question"
    case completedAction = "completed_action"
    case missionReview = "mission_review"
    case controllerNudge = "controller_nudge"
}

public enum BurnBarMissionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case draft
    case awaitingApproval = "awaiting_approval"
    case approved
    case dispatching
    case inProgress = "in_progress"
    case partiallyCompleted = "partially_completed"
    case completed
    case failed
    case cancelled
}

public enum BurnBarMissionRecommendation: String, Codable, CaseIterable, Hashable, Sendable {
    case proceed
    case review
    case pause
    case escalate
}

public enum BurnBarMissionPacketStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case queued
    case dispatched
    case running
    case completed
    case failed
    case cancelled
}

public enum BurnBarMissionResultStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case succeeded
    case partial
    case failed
    case replayed
}

public enum BurnBarAutoTakeoverStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case monitoring
    case launched
    case completed
    case failed
    case skipped
}

public enum BurnBarNotificationChannel: String, Codable, CaseIterable, Hashable, Sendable {
    case local
    case telegram
    case calendar
}

public enum BurnBarNotificationHealthStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case healthy
    case degraded
    case disabled
    case unauthorized
}

public enum BurnBarProjectionStatusKind: String, Codable, CaseIterable, Hashable, Sendable {
    case upToDate = "up_to_date"
    case stale
    case rebuilding
    case failed
}

public enum BurnBarReplayStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case idle
    case queued
    case running
    case completed
    case failed
}

public enum BurnBarControllerReviewRunOrigin: String, Codable, CaseIterable, Hashable, Sendable {
    case manual
    case scheduled
    case telegram
    case dashboard
    case projects
    case ingestion
}

public enum BurnBarControllerEventFamily: String, Codable, CaseIterable, Hashable, Sendable {
    case controller
    case question
    case followup
    case mission
    case notification
    case simulator
    case projection
    case governance
}

public enum BurnBarTelegramCommand: String, Codable, CaseIterable, Hashable, Sendable {
    case help
    case pending
    case followups
    case done
    case snooze
    case calendar
    case answer
    case latest
    case status
    case runDaily = "run_daily"
    case runWeekly = "run_weekly"
}

public enum BurnBarCalendarAction: String, Codable, CaseIterable, Hashable, Sendable {
    case create
    case update
    case remove
}

public struct BurnBarControllerCounts: Codable, Hashable, Sendable {
    public let projectCount: Int
    public let pendingQuestionCount: Int
    public let openFollowupCount: Int
    public let activeMissionCount: Int
    public let staleProjectCount: Int

    public init(
        projectCount: Int,
        pendingQuestionCount: Int,
        openFollowupCount: Int,
        activeMissionCount: Int,
        staleProjectCount: Int
    ) {
        self.projectCount = projectCount
        self.pendingQuestionCount = pendingQuestionCount
        self.openFollowupCount = openFollowupCount
        self.activeMissionCount = activeMissionCount
        self.staleProjectCount = staleProjectCount
    }
}

public struct BurnBarReplayCheckpoint: Codable, Hashable, Identifiable, Sendable {
    public let id: BurnBarProjectionCheckpointID
    public let projectionName: String
    public let eventSequence: Int
    public let recordedAt: Date

    public init(
        id: BurnBarProjectionCheckpointID,
        projectionName: String,
        eventSequence: Int,
        recordedAt: Date
    ) {
        self.id = id
        self.projectionName = projectionName
        self.eventSequence = eventSequence
        self.recordedAt = recordedAt
    }
}

public struct BurnBarProjectionStatusSnapshot: Codable, Hashable, Sendable {
    public let projectionName: String
    public let status: BurnBarProjectionStatusKind
    public let freshness: BurnBarControllerFreshnessState
    public let lastMaterializedAt: Date?
    public let lastEventSequence: Int
    public let lastError: String?
    public let checkpoint: BurnBarReplayCheckpoint?

    public init(
        projectionName: String,
        status: BurnBarProjectionStatusKind,
        freshness: BurnBarControllerFreshnessState,
        lastMaterializedAt: Date? = nil,
        lastEventSequence: Int,
        lastError: String? = nil,
        checkpoint: BurnBarReplayCheckpoint? = nil
    ) {
        self.projectionName = projectionName
        self.status = status
        self.freshness = freshness
        self.lastMaterializedAt = lastMaterializedAt
        self.lastEventSequence = lastEventSequence
        self.lastError = lastError
        self.checkpoint = checkpoint
    }
}

public struct BurnBarControllerEvent: Codable, Hashable, Identifiable, Sendable {
    public let id: BurnBarControllerEventID
    public let family: BurnBarControllerEventFamily
    public let eventType: String
    public let projectSlug: String
    public let recordedAt: Date
    public let sequence: Int
    public let summary: String
    public let detail: String?
    public let metadata: BurnBarMetadata
    public let isReplay: Bool

    public init(
        id: BurnBarControllerEventID,
        family: BurnBarControllerEventFamily,
        eventType: String,
        projectSlug: String,
        recordedAt: Date,
        sequence: Int,
        summary: String,
        detail: String? = nil,
        metadata: BurnBarMetadata = [:],
        isReplay: Bool = false
    ) {
        self.id = id
        self.family = family
        self.eventType = eventType
        self.projectSlug = projectSlug
        self.recordedAt = recordedAt
        self.sequence = sequence
        self.summary = summary
        self.detail = detail
        self.metadata = metadata
        self.isReplay = isReplay
    }
}

public struct BurnBarControllerSummary: Codable, Hashable, Sendable {
    public let updatedAt: Date
    public let activeProjectSlug: String?
    public let counts: BurnBarControllerCounts
    public let nextSuggestedCadence: BurnBarControllerReviewCadence?
    public let latestReviewAt: Date?
    public let freshness: BurnBarControllerFreshnessState
    public let projectionStatus: [BurnBarProjectionStatusSnapshot]
    public let recentEvents: [BurnBarControllerEvent]

    public init(
        updatedAt: Date,
        activeProjectSlug: String? = nil,
        counts: BurnBarControllerCounts,
        nextSuggestedCadence: BurnBarControllerReviewCadence? = nil,
        latestReviewAt: Date? = nil,
        freshness: BurnBarControllerFreshnessState,
        projectionStatus: [BurnBarProjectionStatusSnapshot] = [],
        recentEvents: [BurnBarControllerEvent] = []
    ) {
        self.updatedAt = updatedAt
        self.activeProjectSlug = activeProjectSlug
        self.counts = counts
        self.nextSuggestedCadence = nextSuggestedCadence
        self.latestReviewAt = latestReviewAt
        self.freshness = freshness
        self.projectionStatus = projectionStatus
        self.recentEvents = recentEvents
    }
}

public struct BurnBarReviewProjectSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let projectSlug: String
    public let displayName: String
    public let summary: String
    public let status: BurnBarReviewProjectStatus
    public let preferredCadence: BurnBarControllerReviewCadence
    public let aliases: [String]
    public let automationMode: BurnBarControllerProjectAutomationMode
    public let reviewModelID: String?
    public let scheduleHourLocal: Int?
    public let scheduleWeekdayLocal: Int?
    public let freshness: BurnBarControllerFreshnessState
    public let latestDailyReviewAt: Date?
    public let latestWeeklyReviewAt: Date?
    public let nextScheduledReviewAt: Date?
    public let pendingQuestionCount: Int
    public let openFollowupCount: Int
    public let activeMissionCount: Int
    public let activeMissionID: BurnBarMissionID?
    public let needsOperatorAttention: Bool
    public let ingestionSource: BurnBarControllerProjectIngestionSource
    public let metadata: BurnBarMetadata

    public init(
        id: String,
        projectSlug: String,
        displayName: String,
        summary: String,
        status: BurnBarReviewProjectStatus,
        preferredCadence: BurnBarControllerReviewCadence,
        aliases: [String] = [],
        automationMode: BurnBarControllerProjectAutomationMode = .manual,
        reviewModelID: String? = nil,
        scheduleHourLocal: Int? = nil,
        scheduleWeekdayLocal: Int? = nil,
        freshness: BurnBarControllerFreshnessState,
        latestDailyReviewAt: Date? = nil,
        latestWeeklyReviewAt: Date? = nil,
        nextScheduledReviewAt: Date? = nil,
        pendingQuestionCount: Int,
        openFollowupCount: Int,
        activeMissionCount: Int,
        activeMissionID: BurnBarMissionID? = nil,
        needsOperatorAttention: Bool,
        ingestionSource: BurnBarControllerProjectIngestionSource = .manual,
        metadata: BurnBarMetadata = [:]
    ) {
        self.id = id
        self.projectSlug = projectSlug
        self.displayName = displayName
        self.summary = summary
        self.status = status
        self.preferredCadence = preferredCadence
        self.aliases = aliases
        self.automationMode = automationMode
        self.reviewModelID = reviewModelID
        self.scheduleHourLocal = scheduleHourLocal
        self.scheduleWeekdayLocal = scheduleWeekdayLocal
        self.freshness = freshness
        self.latestDailyReviewAt = latestDailyReviewAt
        self.latestWeeklyReviewAt = latestWeeklyReviewAt
        self.nextScheduledReviewAt = nextScheduledReviewAt
        self.pendingQuestionCount = pendingQuestionCount
        self.openFollowupCount = openFollowupCount
        self.activeMissionCount = activeMissionCount
        self.activeMissionID = activeMissionID
        self.needsOperatorAttention = needsOperatorAttention
        self.ingestionSource = ingestionSource
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case projectSlug
        case displayName
        case summary
        case status
        case preferredCadence
        case aliases
        case automationMode
        case reviewModelID
        case scheduleHourLocal
        case scheduleWeekdayLocal
        case freshness
        case latestDailyReviewAt
        case latestWeeklyReviewAt
        case nextScheduledReviewAt
        case pendingQuestionCount
        case openFollowupCount
        case activeMissionCount
        case activeMissionID
        case needsOperatorAttention
        case ingestionSource
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        projectSlug = try container.decode(String.self, forKey: .projectSlug)
        displayName = try container.decode(String.self, forKey: .displayName)
        summary = try container.decode(String.self, forKey: .summary)
        status = try container.decode(BurnBarReviewProjectStatus.self, forKey: .status)
        preferredCadence = try container.decode(BurnBarControllerReviewCadence.self, forKey: .preferredCadence)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        automationMode = try container.decodeIfPresent(BurnBarControllerProjectAutomationMode.self, forKey: .automationMode) ?? .manual
        reviewModelID = try container.decodeIfPresent(String.self, forKey: .reviewModelID)
        scheduleHourLocal = try container.decodeIfPresent(Int.self, forKey: .scheduleHourLocal)
        scheduleWeekdayLocal = try container.decodeIfPresent(Int.self, forKey: .scheduleWeekdayLocal)
        freshness = try container.decode(BurnBarControllerFreshnessState.self, forKey: .freshness)
        latestDailyReviewAt = try container.decodeIfPresent(Date.self, forKey: .latestDailyReviewAt)
        latestWeeklyReviewAt = try container.decodeIfPresent(Date.self, forKey: .latestWeeklyReviewAt)
        nextScheduledReviewAt = try container.decodeIfPresent(Date.self, forKey: .nextScheduledReviewAt)
        pendingQuestionCount = try container.decode(Int.self, forKey: .pendingQuestionCount)
        openFollowupCount = try container.decode(Int.self, forKey: .openFollowupCount)
        activeMissionCount = try container.decode(Int.self, forKey: .activeMissionCount)
        activeMissionID = try container.decodeIfPresent(BurnBarMissionID.self, forKey: .activeMissionID)
        needsOperatorAttention = try container.decode(Bool.self, forKey: .needsOperatorAttention)
        ingestionSource = try container.decodeIfPresent(BurnBarControllerProjectIngestionSource.self, forKey: .ingestionSource) ?? .manual
        metadata = try container.decodeIfPresent(BurnBarMetadata.self, forKey: .metadata) ?? [:]
    }
}

public struct BurnBarReviewRunSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let projectSlug: String
    public let cadence: BurnBarControllerReviewCadence
    public let recordedAt: Date
    public let summary: String
    public let questionCount: Int
    public let followupCount: Int
    public let missionCount: Int
    public let origin: BurnBarControllerReviewRunOrigin
    public let triggeredBy: String?
    public let launchedRunID: BurnBarRunID?
    public let metadata: BurnBarMetadata

    public init(
        id: String,
        projectSlug: String,
        cadence: BurnBarControllerReviewCadence,
        recordedAt: Date,
        summary: String,
        questionCount: Int,
        followupCount: Int,
        missionCount: Int,
        origin: BurnBarControllerReviewRunOrigin = .manual,
        triggeredBy: String? = nil,
        launchedRunID: BurnBarRunID? = nil,
        metadata: BurnBarMetadata = [:]
    ) {
        self.id = id
        self.projectSlug = projectSlug
        self.cadence = cadence
        self.recordedAt = recordedAt
        self.summary = summary
        self.questionCount = questionCount
        self.followupCount = followupCount
        self.missionCount = missionCount
        self.origin = origin
        self.triggeredBy = triggeredBy
        self.launchedRunID = launchedRunID
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case projectSlug
        case cadence
        case recordedAt
        case summary
        case questionCount
        case followupCount
        case missionCount
        case origin
        case triggeredBy
        case launchedRunID
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        projectSlug = try container.decode(String.self, forKey: .projectSlug)
        cadence = try container.decode(BurnBarControllerReviewCadence.self, forKey: .cadence)
        recordedAt = try container.decode(Date.self, forKey: .recordedAt)
        summary = try container.decode(String.self, forKey: .summary)
        questionCount = try container.decode(Int.self, forKey: .questionCount)
        followupCount = try container.decode(Int.self, forKey: .followupCount)
        missionCount = try container.decode(Int.self, forKey: .missionCount)
        origin = try container.decodeIfPresent(BurnBarControllerReviewRunOrigin.self, forKey: .origin) ?? .manual
        triggeredBy = try container.decodeIfPresent(String.self, forKey: .triggeredBy)
        launchedRunID = try container.decodeIfPresent(BurnBarRunID.self, forKey: .launchedRunID)
        metadata = try container.decodeIfPresent(BurnBarMetadata.self, forKey: .metadata) ?? [:]
    }
}

public struct BurnBarControllerActivitySnapshot: Codable, Hashable, Sendable {
    public let generatedAt: Date
    public let activeProjectSlug: String?
    public let projects: [BurnBarControllerActivityProject]

    public init(
        generatedAt: Date,
        activeProjectSlug: String? = nil,
        projects: [BurnBarControllerActivityProject]
    ) {
        self.generatedAt = generatedAt
        self.activeProjectSlug = activeProjectSlug
        self.projects = projects
    }
}

public struct BurnBarControllerActivityProject: Codable, Hashable, Identifiable, Sendable {
    public var id: String { projectSlug }

    public let projectSlug: String
    public let displayName: String
    public let summary: String
    public let latestActivityAt: Date?
    public let latestConversationID: String?
    public let latestConversationSessionID: BurnBarSessionID?
    public let latestConversationTitle: String?
    public let latestConversationSummary: String?
    public let latestQuestionPrompt: String?
    public let sessionCountLast7Days: Int
    public let totalCostLast7Days: Double
    public let totalTokensLast7Days: Int
    public let aliases: [String]
    public let preferredCadence: BurnBarControllerReviewCadence?
    public let automationMode: BurnBarControllerProjectAutomationMode?
    public let reviewModelID: String?
    public let scheduleHourLocal: Int?
    public let scheduleWeekdayLocal: Int?

    public init(
        projectSlug: String,
        displayName: String,
        summary: String,
        latestActivityAt: Date? = nil,
        latestConversationID: String? = nil,
        latestConversationSessionID: BurnBarSessionID? = nil,
        latestConversationTitle: String? = nil,
        latestConversationSummary: String? = nil,
        latestQuestionPrompt: String? = nil,
        sessionCountLast7Days: Int,
        totalCostLast7Days: Double,
        totalTokensLast7Days: Int,
        aliases: [String] = [],
        preferredCadence: BurnBarControllerReviewCadence? = nil,
        automationMode: BurnBarControllerProjectAutomationMode? = nil,
        reviewModelID: String? = nil,
        scheduleHourLocal: Int? = nil,
        scheduleWeekdayLocal: Int? = nil
    ) {
        self.projectSlug = projectSlug
        self.displayName = displayName
        self.summary = summary
        self.latestActivityAt = latestActivityAt
        self.latestConversationID = latestConversationID
        self.latestConversationSessionID = latestConversationSessionID
        self.latestConversationTitle = latestConversationTitle
        self.latestConversationSummary = latestConversationSummary
        self.latestQuestionPrompt = latestQuestionPrompt
        self.sessionCountLast7Days = sessionCountLast7Days
        self.totalCostLast7Days = totalCostLast7Days
        self.totalTokensLast7Days = totalTokensLast7Days
        self.aliases = aliases
        self.preferredCadence = preferredCadence
        self.automationMode = automationMode
        self.reviewModelID = reviewModelID
        self.scheduleHourLocal = scheduleHourLocal
        self.scheduleWeekdayLocal = scheduleWeekdayLocal
    }
}

public struct BurnBarAnswerRecord: Codable, Hashable, Sendable {
    public let answeredAt: Date
    public let answeredBy: String
    public let answer: String
    public let selectedOptionID: String?
    public let metadata: BurnBarMetadata

    public init(
        answeredAt: Date,
        answeredBy: String,
        answer: String,
        selectedOptionID: String? = nil,
        metadata: BurnBarMetadata = [:]
    ) {
        self.answeredAt = answeredAt
        self.answeredBy = answeredBy
        self.answer = answer
        self.selectedOptionID = selectedOptionID
        self.metadata = metadata
    }
}

public struct BurnBarQuestionOptionSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String?
    public let answer: String
    public let metadata: BurnBarMetadata

    public init(
        id: String,
        title: String,
        detail: String? = nil,
        answer: String,
        metadata: BurnBarMetadata = [:]
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.answer = answer
        self.metadata = metadata
    }
}

public struct BurnBarQuestionDeepLinkSnapshot: Codable, Hashable, Sendable {
    public let kind: BurnBarQuestionDeepLinkKind
    public let targetID: String?
    public let title: String
    public let subtitle: String?
    public let metadata: BurnBarMetadata

    public init(
        kind: BurnBarQuestionDeepLinkKind,
        targetID: String? = nil,
        title: String,
        subtitle: String? = nil,
        metadata: BurnBarMetadata = [:]
    ) {
        self.kind = kind
        self.targetID = targetID
        self.title = title
        self.subtitle = subtitle
        self.metadata = metadata
    }
}

public struct BurnBarQuestionTrackerSnapshot: Codable, Hashable, Sendable {
    public let isUnread: Bool
    public let surfacedAt: Date?
    public let firstNotifiedAt: Date?
    public let lastNotifiedAt: Date?
    public let notificationCount: Int
    public let metadata: BurnBarMetadata

    public init(
        isUnread: Bool = true,
        surfacedAt: Date? = nil,
        firstNotifiedAt: Date? = nil,
        lastNotifiedAt: Date? = nil,
        notificationCount: Int = 0,
        metadata: BurnBarMetadata = [:]
    ) {
        self.isUnread = isUnread
        self.surfacedAt = surfacedAt
        self.firstNotifiedAt = firstNotifiedAt
        self.lastNotifiedAt = lastNotifiedAt
        self.notificationCount = notificationCount
        self.metadata = metadata
    }
}

public struct BurnBarPendingQuestionSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: BurnBarQuestionID
    public let projectSlug: String
    public let sessionID: BurnBarSessionID?
    public let title: String
    public let prompt: String
    public let stageLabel: String?
    public let status: BurnBarPendingQuestionStatus
    public let priority: BurnBarPendingQuestionPriority
    public let askedAt: Date
    public let dueAt: Date?
    public let latestAnswer: BurnBarAnswerRecord?
    public let answerPlaceholder: String?
    public let contextSummary: String?
    public let evidenceRefs: [String]
    public let suggestedOptions: [BurnBarQuestionOptionSnapshot]
    public let deepLink: BurnBarQuestionDeepLinkSnapshot?
    public let tracker: BurnBarQuestionTrackerSnapshot?
    public let metadata: BurnBarMetadata

    public init(
        id: BurnBarQuestionID,
        projectSlug: String,
        sessionID: BurnBarSessionID? = nil,
        title: String,
        prompt: String,
        stageLabel: String? = nil,
        status: BurnBarPendingQuestionStatus,
        priority: BurnBarPendingQuestionPriority,
        askedAt: Date,
        dueAt: Date? = nil,
        latestAnswer: BurnBarAnswerRecord? = nil,
        answerPlaceholder: String? = nil,
        contextSummary: String? = nil,
        evidenceRefs: [String] = [],
        suggestedOptions: [BurnBarQuestionOptionSnapshot] = [],
        deepLink: BurnBarQuestionDeepLinkSnapshot? = nil,
        tracker: BurnBarQuestionTrackerSnapshot? = nil,
        metadata: BurnBarMetadata = [:]
    ) {
        self.id = id
        self.projectSlug = projectSlug
        self.sessionID = sessionID
        self.title = title
        self.prompt = prompt
        self.stageLabel = stageLabel
        self.status = status
        self.priority = priority
        self.askedAt = askedAt
        self.dueAt = dueAt
        self.latestAnswer = latestAnswer
        self.answerPlaceholder = answerPlaceholder
        self.contextSummary = contextSummary
        self.evidenceRefs = evidenceRefs
        self.suggestedOptions = suggestedOptions
        self.deepLink = deepLink
        self.tracker = tracker
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case projectSlug
        case sessionID
        case title
        case prompt
        case stageLabel
        case status
        case priority
        case askedAt
        case dueAt
        case latestAnswer
        case answerPlaceholder
        case contextSummary
        case evidenceRefs
        case suggestedOptions
        case deepLink
        case tracker
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(BurnBarQuestionID.self, forKey: .id)
        projectSlug = try container.decode(String.self, forKey: .projectSlug)
        sessionID = try container.decodeIfPresent(BurnBarSessionID.self, forKey: .sessionID)
        title = try container.decode(String.self, forKey: .title)
        prompt = try container.decode(String.self, forKey: .prompt)
        stageLabel = try container.decodeIfPresent(String.self, forKey: .stageLabel)
        status = try container.decode(BurnBarPendingQuestionStatus.self, forKey: .status)
        priority = try container.decode(BurnBarPendingQuestionPriority.self, forKey: .priority)
        askedAt = try container.decode(Date.self, forKey: .askedAt)
        dueAt = try container.decodeIfPresent(Date.self, forKey: .dueAt)
        latestAnswer = try container.decodeIfPresent(BurnBarAnswerRecord.self, forKey: .latestAnswer)
        answerPlaceholder = try container.decodeIfPresent(String.self, forKey: .answerPlaceholder)
        contextSummary = try container.decodeIfPresent(String.self, forKey: .contextSummary)
        evidenceRefs = try container.decodeIfPresent([String].self, forKey: .evidenceRefs) ?? []
        suggestedOptions = try container.decodeIfPresent([BurnBarQuestionOptionSnapshot].self, forKey: .suggestedOptions) ?? []
        deepLink = try container.decodeIfPresent(BurnBarQuestionDeepLinkSnapshot.self, forKey: .deepLink)
        tracker = try container.decodeIfPresent(BurnBarQuestionTrackerSnapshot.self, forKey: .tracker)
        metadata = try container.decodeIfPresent(BurnBarMetadata.self, forKey: .metadata) ?? [:]
    }
}

public struct BurnBarCalendarEntrySnapshot: Codable, Hashable, Sendable {
    public let externalID: String?
    public let title: String
    public let startAt: Date?
    public let endAt: Date?
    public let notes: String?

    public init(
        externalID: String? = nil,
        title: String,
        startAt: Date? = nil,
        endAt: Date? = nil,
        notes: String? = nil
    ) {
        self.externalID = externalID
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
        self.notes = notes
    }
}

public struct BurnBarFollowupSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: BurnBarFollowupID
    public let projectSlug: String
    public let questionID: BurnBarQuestionID?
    public let title: String
    public let summary: String
    public let stageLabel: String?
    public let status: BurnBarFollowupStatus
    public let kind: BurnBarFollowupKind
    public let createdAt: Date
    public let nextNudgeAt: Date?
    public let snoozeUntil: Date?
    public let calendarEntry: BurnBarCalendarEntrySnapshot?
    public let deepLink: BurnBarQuestionDeepLinkSnapshot?
    public let metadata: BurnBarMetadata

    public init(
        id: BurnBarFollowupID,
        projectSlug: String,
        questionID: BurnBarQuestionID? = nil,
        title: String,
        summary: String,
        stageLabel: String? = nil,
        status: BurnBarFollowupStatus,
        kind: BurnBarFollowupKind,
        createdAt: Date,
        nextNudgeAt: Date? = nil,
        snoozeUntil: Date? = nil,
        calendarEntry: BurnBarCalendarEntrySnapshot? = nil,
        deepLink: BurnBarQuestionDeepLinkSnapshot? = nil,
        metadata: BurnBarMetadata = [:]
    ) {
        self.id = id
        self.projectSlug = projectSlug
        self.questionID = questionID
        self.title = title
        self.summary = summary
        self.stageLabel = stageLabel
        self.status = status
        self.kind = kind
        self.createdAt = createdAt
        self.nextNudgeAt = nextNudgeAt
        self.snoozeUntil = snoozeUntil
        self.calendarEntry = calendarEntry
        self.deepLink = deepLink
        self.metadata = metadata
    }
}

public struct BurnBarMissionApprovalSnapshot: Codable, Hashable, Sendable {
    public let approved: Bool
    public let approvedAt: Date?
    public let approvedBy: String?
    public let note: String?

    public init(
        approved: Bool,
        approvedAt: Date? = nil,
        approvedBy: String? = nil,
        note: String? = nil
    ) {
        self.approved = approved
        self.approvedAt = approvedAt
        self.approvedBy = approvedBy
        self.note = note
    }
}

public struct BurnBarMissionBurnRecord: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let amount: Double
    public let unit: String
    public let recordedAt: Date

    public init(
        id: String,
        label: String,
        amount: Double,
        unit: String,
        recordedAt: Date
    ) {
        self.id = id
        self.label = label
        self.amount = amount
        self.unit = unit
        self.recordedAt = recordedAt
    }
}

public struct BurnBarMissionPacketSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: BurnBarMissionPacketID
    public let missionID: BurnBarMissionID
    public let workerName: String
    public let objective: String
    public let status: BurnBarMissionPacketStatus
    public let runID: BurnBarRunID?
    public let dispatchedAt: Date?
    public let completedAt: Date?
    public let metadata: BurnBarMetadata

    public init(
        id: BurnBarMissionPacketID,
        missionID: BurnBarMissionID,
        workerName: String,
        objective: String,
        status: BurnBarMissionPacketStatus,
        runID: BurnBarRunID? = nil,
        dispatchedAt: Date? = nil,
        completedAt: Date? = nil,
        metadata: BurnBarMetadata = [:]
    ) {
        self.id = id
        self.missionID = missionID
        self.workerName = workerName
        self.objective = objective
        self.status = status
        self.runID = runID
        self.dispatchedAt = dispatchedAt
        self.completedAt = completedAt
        self.metadata = metadata
    }
}

public struct BurnBarMissionResultSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: BurnBarMissionResultID
    public let missionID: BurnBarMissionID
    public let packetID: BurnBarMissionPacketID?
    public let runID: BurnBarRunID?
    public let status: BurnBarMissionResultStatus
    public let summary: String
    public let detail: String?
    public let burnDelta: Double
    public let createdAt: Date
    public let evidenceRefs: [String]
    public let metadata: BurnBarMetadata

    public init(
        id: BurnBarMissionResultID,
        missionID: BurnBarMissionID,
        packetID: BurnBarMissionPacketID? = nil,
        runID: BurnBarRunID? = nil,
        status: BurnBarMissionResultStatus,
        summary: String,
        detail: String? = nil,
        burnDelta: Double = 0,
        createdAt: Date,
        evidenceRefs: [String] = [],
        metadata: BurnBarMetadata = [:]
    ) {
        self.id = id
        self.missionID = missionID
        self.packetID = packetID
        self.runID = runID
        self.status = status
        self.summary = summary
        self.detail = detail
        self.burnDelta = burnDelta
        self.createdAt = createdAt
        self.evidenceRefs = evidenceRefs
        self.metadata = metadata
    }
}

public struct BurnBarAutoTakeoverRecord: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let projectSlug: String
    public let missionID: BurnBarMissionID?
    public let sourceRunID: BurnBarRunID?
    public let takeoverRunID: BurnBarRunID?
    public let status: BurnBarAutoTakeoverStatus
    public let reason: String
    public let createdAt: Date
    public let updatedAt: Date
    public let metadata: BurnBarMetadata

    public init(
        id: String,
        projectSlug: String,
        missionID: BurnBarMissionID? = nil,
        sourceRunID: BurnBarRunID? = nil,
        takeoverRunID: BurnBarRunID? = nil,
        status: BurnBarAutoTakeoverStatus,
        reason: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: BurnBarMetadata = [:]
    ) {
        self.id = id
        self.projectSlug = projectSlug
        self.missionID = missionID
        self.sourceRunID = sourceRunID
        self.takeoverRunID = takeoverRunID
        self.status = status
        self.reason = reason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
}

public struct BurnBarMissionSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: BurnBarMissionID
    public let projectSlug: String
    public let title: String
    public let summary: String
    public let status: BurnBarMissionStatus
    public let recommendation: BurnBarMissionRecommendation
    public let createdAt: Date
    public let updatedAt: Date
    public let approval: BurnBarMissionApprovalSnapshot
    public let packets: [BurnBarMissionPacketSnapshot]
    public let results: [BurnBarMissionResultSnapshot]
    public let burnRecords: [BurnBarMissionBurnRecord]
    public let takeoverHistory: [BurnBarAutoTakeoverRecord]?
    public let metadata: BurnBarMetadata

    public init(
        id: BurnBarMissionID,
        projectSlug: String,
        title: String,
        summary: String,
        status: BurnBarMissionStatus,
        recommendation: BurnBarMissionRecommendation,
        createdAt: Date,
        updatedAt: Date,
        approval: BurnBarMissionApprovalSnapshot,
        packets: [BurnBarMissionPacketSnapshot] = [],
        results: [BurnBarMissionResultSnapshot] = [],
        burnRecords: [BurnBarMissionBurnRecord] = [],
        takeoverHistory: [BurnBarAutoTakeoverRecord]? = nil,
        metadata: BurnBarMetadata = [:]
    ) {
        self.id = id
        self.projectSlug = projectSlug
        self.title = title
        self.summary = summary
        self.status = status
        self.recommendation = recommendation
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.approval = approval
        self.packets = packets
        self.results = results
        self.burnRecords = burnRecords
        self.takeoverHistory = takeoverHistory
        self.metadata = metadata
    }
}

public struct BurnBarNotificationChannelHealth: Codable, Hashable, Sendable {
    public let channel: BurnBarNotificationChannel
    public let status: BurnBarNotificationHealthStatus
    public let detail: String?
    public let checkedAt: Date

    public init(
        channel: BurnBarNotificationChannel,
        status: BurnBarNotificationHealthStatus,
        detail: String? = nil,
        checkedAt: Date
    ) {
        self.channel = channel
        self.status = status
        self.detail = detail
        self.checkedAt = checkedAt
    }
}

public struct BurnBarLocalNotificationConfig: Codable, Hashable, Sendable {
    public let isEnabled: Bool
    public let quietHoursStart: Int?
    public let quietHoursEnd: Int?

    public init(
        isEnabled: Bool,
        quietHoursStart: Int? = nil,
        quietHoursEnd: Int? = nil
    ) {
        self.isEnabled = isEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
    }
}

public struct BurnBarTelegramNotificationConfig: Codable, Hashable, Sendable {
    public let isEnabled: Bool
    public let botTokenConfigured: Bool
    public let botToken: String?
    public let botTokenHint: String?
    public let chatID: String?
    public let supportedCommands: [BurnBarTelegramCommand]

    public init(
        isEnabled: Bool,
        botTokenConfigured: Bool,
        botToken: String? = nil,
        botTokenHint: String? = nil,
        chatID: String? = nil,
        supportedCommands: [BurnBarTelegramCommand] = BurnBarTelegramCommand.allCases
    ) {
        self.isEnabled = isEnabled
        self.botTokenConfigured = botTokenConfigured
        self.botToken = botToken
        self.botTokenHint = botTokenHint
        self.chatID = chatID
        self.supportedCommands = supportedCommands
    }
}

public struct BurnBarCalendarNotificationConfig: Codable, Hashable, Sendable {
    public let isEnabled: Bool
    public let defaultDurationMinutes: Int
    public let defaultCalendarName: String?

    public init(
        isEnabled: Bool,
        defaultDurationMinutes: Int,
        defaultCalendarName: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.defaultDurationMinutes = defaultDurationMinutes
        self.defaultCalendarName = defaultCalendarName
    }
}

public struct BurnBarNotificationConfig: Codable, Hashable, Sendable {
    public let defaultSnoozeMinutes: Int
    public let nudgeHoursLocal: [Int]
    public let local: BurnBarLocalNotificationConfig
    public let telegram: BurnBarTelegramNotificationConfig
    public let calendar: BurnBarCalendarNotificationConfig

    public init(
        defaultSnoozeMinutes: Int,
        nudgeHoursLocal: [Int],
        local: BurnBarLocalNotificationConfig,
        telegram: BurnBarTelegramNotificationConfig,
        calendar: BurnBarCalendarNotificationConfig
    ) {
        self.defaultSnoozeMinutes = defaultSnoozeMinutes
        self.nudgeHoursLocal = nudgeHoursLocal
        self.local = local
        self.telegram = telegram
        self.calendar = calendar
    }
}

public struct BurnBarNotificationHealthSnapshot: Codable, Hashable, Sendable {
    public let checkedAt: Date
    public let channels: [BurnBarNotificationChannelHealth]

    public init(checkedAt: Date, channels: [BurnBarNotificationChannelHealth]) {
        self.checkedAt = checkedAt
        self.channels = channels
    }
}

public struct BurnBarNotificationCommandResponse: Codable, Hashable, Sendable {
    public let command: BurnBarTelegramCommand
    public let ok: Bool
    public let message: String
    public let followup: BurnBarFollowupSnapshot?
    public let question: BurnBarPendingQuestionSnapshot?
    public let mission: BurnBarMissionSnapshot?

    public init(
        command: BurnBarTelegramCommand,
        ok: Bool,
        message: String,
        followup: BurnBarFollowupSnapshot? = nil,
        question: BurnBarPendingQuestionSnapshot? = nil,
        mission: BurnBarMissionSnapshot? = nil
    ) {
        self.command = command
        self.ok = ok
        self.message = message
        self.followup = followup
        self.question = question
        self.mission = mission
    }
}

public struct BurnBarSimulatorRunSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: BurnBarSimulatorRunID
    public let projectSlug: String
    public let scenarioName: String
    public let status: BurnBarReplayStatus
    public let seed: Int
    public let startedAt: Date
    public let completedAt: Date?
    public let emittedEvents: [BurnBarControllerEvent]
    public let projectionStatus: [BurnBarProjectionStatusSnapshot]
    public let summary: String

    public init(
        id: BurnBarSimulatorRunID,
        projectSlug: String,
        scenarioName: String,
        status: BurnBarReplayStatus,
        seed: Int,
        startedAt: Date,
        completedAt: Date? = nil,
        emittedEvents: [BurnBarControllerEvent] = [],
        projectionStatus: [BurnBarProjectionStatusSnapshot] = [],
        summary: String
    ) {
        self.id = id
        self.projectSlug = projectSlug
        self.scenarioName = scenarioName
        self.status = status
        self.seed = seed
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.emittedEvents = emittedEvents
        self.projectionStatus = projectionStatus
        self.summary = summary
    }
}

public struct BurnBarControllerSummaryRequest: Codable, Hashable, Sendable {
    public let projectSlug: String?
    public let includeRecentEvents: Bool
    public let includeProjectionStatus: Bool

    public init(
        projectSlug: String? = nil,
        includeRecentEvents: Bool = true,
        includeProjectionStatus: Bool = true
    ) {
        self.projectSlug = projectSlug
        self.includeRecentEvents = includeRecentEvents
        self.includeProjectionStatus = includeProjectionStatus
    }
}

public struct BurnBarControllerSummaryResponse: Codable, Hashable, Sendable {
    public let summary: BurnBarControllerSummary

    public init(summary: BurnBarControllerSummary) {
        self.summary = summary
    }
}

public struct BurnBarControllerProjectsListRequest: Codable, Hashable, Sendable {
    public let includePaused: Bool
    public let limit: Int

    public init(includePaused: Bool = false, limit: Int = 100) {
        self.includePaused = includePaused
        self.limit = limit
    }
}

public struct BurnBarControllerProjectsListResponse: Codable, Hashable, Sendable {
    public let projects: [BurnBarReviewProjectSnapshot]

    public init(projects: [BurnBarReviewProjectSnapshot]) {
        self.projects = projects
    }
}

public struct BurnBarControllerProjectGetRequest: Codable, Hashable, Sendable {
    public let projectSlug: String

    public init(projectSlug: String) {
        self.projectSlug = projectSlug
    }
}

public struct BurnBarControllerProjectResponse: Codable, Hashable, Sendable {
    public let project: BurnBarReviewProjectSnapshot?

    public init(project: BurnBarReviewProjectSnapshot?) {
        self.project = project
    }
}

public struct BurnBarControllerProjectUpsertRequest: Codable, Hashable, Sendable {
    public let project: BurnBarReviewProjectSnapshot

    public init(project: BurnBarReviewProjectSnapshot) {
        self.project = project
    }
}

public struct BurnBarControllerReviewRunRecordRequest: Codable, Hashable, Sendable {
    public let run: BurnBarReviewRunSnapshot

    public init(run: BurnBarReviewRunSnapshot) {
        self.run = run
    }
}

public struct BurnBarControllerReviewRunRecordResponse: Codable, Hashable, Sendable {
    public let run: BurnBarReviewRunSnapshot
    public let summary: BurnBarControllerSummary

    public init(run: BurnBarReviewRunSnapshot, summary: BurnBarControllerSummary) {
        self.run = run
        self.summary = summary
    }
}

public struct BurnBarQuestionCreateRequest: Codable, Hashable, Sendable {
    public let question: BurnBarPendingQuestionSnapshot

    public init(question: BurnBarPendingQuestionSnapshot) {
        self.question = question
    }
}

public struct BurnBarQuestionResponse: Codable, Hashable, Sendable {
    public let question: BurnBarPendingQuestionSnapshot?

    public init(question: BurnBarPendingQuestionSnapshot?) {
        self.question = question
    }
}

public struct BurnBarQuestionsListRequest: Codable, Hashable, Sendable {
    public let projectSlug: String?
    public let statuses: [BurnBarPendingQuestionStatus]
    public let limit: Int

    public init(
        projectSlug: String? = nil,
        statuses: [BurnBarPendingQuestionStatus] = [.pending],
        limit: Int = 100
    ) {
        self.projectSlug = projectSlug
        self.statuses = statuses
        self.limit = limit
    }
}

public struct BurnBarQuestionsListResponse: Codable, Hashable, Sendable {
    public let questions: [BurnBarPendingQuestionSnapshot]

    public init(questions: [BurnBarPendingQuestionSnapshot]) {
        self.questions = questions
    }
}

public struct BurnBarQuestionGetRequest: Codable, Hashable, Sendable {
    public let questionID: BurnBarQuestionID

    public init(questionID: BurnBarQuestionID) {
        self.questionID = questionID
    }
}

public struct BurnBarQuestionAnswerRequest: Codable, Hashable, Sendable {
    public let questionID: BurnBarQuestionID
    public let answeredBy: String
    public let answer: String
    public let selectedOptionID: String?
    public let markFollowupDone: Bool
    public let metadata: BurnBarMetadata

    public init(
        questionID: BurnBarQuestionID,
        answeredBy: String,
        answer: String,
        selectedOptionID: String? = nil,
        markFollowupDone: Bool = true,
        metadata: BurnBarMetadata = [:]
    ) {
        self.questionID = questionID
        self.answeredBy = answeredBy
        self.answer = answer
        self.selectedOptionID = selectedOptionID
        self.markFollowupDone = markFollowupDone
        self.metadata = metadata
    }
}

public struct BurnBarQuestionAnswerResponse: Codable, Hashable, Sendable {
    public let question: BurnBarPendingQuestionSnapshot
    public let followup: BurnBarFollowupSnapshot?
    public let emittedEvent: BurnBarControllerEvent?

    public init(
        question: BurnBarPendingQuestionSnapshot,
        followup: BurnBarFollowupSnapshot? = nil,
        emittedEvent: BurnBarControllerEvent? = nil
    ) {
        self.question = question
        self.followup = followup
        self.emittedEvent = emittedEvent
    }
}

public struct BurnBarFollowupCreateRequest: Codable, Hashable, Sendable {
    public let followup: BurnBarFollowupSnapshot

    public init(followup: BurnBarFollowupSnapshot) {
        self.followup = followup
    }
}

public struct BurnBarFollowupsListRequest: Codable, Hashable, Sendable {
    public let projectSlug: String?
    public let statuses: [BurnBarFollowupStatus]
    public let limit: Int

    public init(
        projectSlug: String? = nil,
        statuses: [BurnBarFollowupStatus] = [.open, .snoozed],
        limit: Int = 100
    ) {
        self.projectSlug = projectSlug
        self.statuses = statuses
        self.limit = limit
    }
}

public struct BurnBarFollowupsListResponse: Codable, Hashable, Sendable {
    public let followups: [BurnBarFollowupSnapshot]

    public init(followups: [BurnBarFollowupSnapshot]) {
        self.followups = followups
    }
}

public struct BurnBarFollowupDoneRequest: Codable, Hashable, Sendable {
    public let followupID: BurnBarFollowupID
    public let actor: String
    public let note: String?

    public init(followupID: BurnBarFollowupID, actor: String, note: String? = nil) {
        self.followupID = followupID
        self.actor = actor
        self.note = note
    }
}

public struct BurnBarFollowupSnoozeRequest: Codable, Hashable, Sendable {
    public let followupID: BurnBarFollowupID
    public let actor: String
    public let snoozeUntil: Date
    public let note: String?

    public init(
        followupID: BurnBarFollowupID,
        actor: String,
        snoozeUntil: Date,
        note: String? = nil
    ) {
        self.followupID = followupID
        self.actor = actor
        self.snoozeUntil = snoozeUntil
        self.note = note
    }
}

public struct BurnBarFollowupCalendarRequest: Codable, Hashable, Sendable {
    public let followupID: BurnBarFollowupID
    public let actor: String
    public let action: BurnBarCalendarAction
    public let entry: BurnBarCalendarEntrySnapshot

    public init(
        followupID: BurnBarFollowupID,
        actor: String,
        action: BurnBarCalendarAction,
        entry: BurnBarCalendarEntrySnapshot
    ) {
        self.followupID = followupID
        self.actor = actor
        self.action = action
        self.entry = entry
    }
}

public struct BurnBarFollowupMutationResponse: Codable, Hashable, Sendable {
    public let followup: BurnBarFollowupSnapshot
    public let emittedEvent: BurnBarControllerEvent?

    public init(followup: BurnBarFollowupSnapshot, emittedEvent: BurnBarControllerEvent? = nil) {
        self.followup = followup
        self.emittedEvent = emittedEvent
    }
}

public struct BurnBarMissionCreateRequest: Codable, Hashable, Sendable {
    public let projectSlug: String
    public let title: String
    public let summary: String
    public let createdBy: String
    public let recommendation: BurnBarMissionRecommendation
    public let metadata: BurnBarMetadata

    public init(
        projectSlug: String,
        title: String,
        summary: String,
        createdBy: String,
        recommendation: BurnBarMissionRecommendation,
        metadata: BurnBarMetadata = [:]
    ) {
        self.projectSlug = projectSlug
        self.title = title
        self.summary = summary
        self.createdBy = createdBy
        self.recommendation = recommendation
        self.metadata = metadata
    }
}

public struct BurnBarMissionListRequest: Codable, Hashable, Sendable {
    public let projectSlug: String?
    public let statuses: [BurnBarMissionStatus]
    public let limit: Int

    public init(
        projectSlug: String? = nil,
        statuses: [BurnBarMissionStatus] = BurnBarMissionStatus.allCases,
        limit: Int = 100
    ) {
        self.projectSlug = projectSlug
        self.statuses = statuses
        self.limit = limit
    }
}

public struct BurnBarMissionListResponse: Codable, Hashable, Sendable {
    public let missions: [BurnBarMissionSnapshot]

    public init(missions: [BurnBarMissionSnapshot]) {
        self.missions = missions
    }
}

public struct BurnBarMissionGetRequest: Codable, Hashable, Sendable {
    public let missionID: BurnBarMissionID

    public init(missionID: BurnBarMissionID) {
        self.missionID = missionID
    }
}

public struct BurnBarMissionResponse: Codable, Hashable, Sendable {
    public let mission: BurnBarMissionSnapshot?

    public init(mission: BurnBarMissionSnapshot?) {
        self.mission = mission
    }
}

public struct BurnBarMissionApproveRequest: Codable, Hashable, Sendable {
    public let missionID: BurnBarMissionID
    public let actor: String
    public let note: String?

    public init(missionID: BurnBarMissionID, actor: String, note: String? = nil) {
        self.missionID = missionID
        self.actor = actor
        self.note = note
    }
}

public struct BurnBarMissionDispatchPacketRequest: Codable, Hashable, Sendable {
    public let missionID: BurnBarMissionID
    public let actor: String
    public let packet: BurnBarMissionPacketSnapshot

    public init(
        missionID: BurnBarMissionID,
        actor: String,
        packet: BurnBarMissionPacketSnapshot
    ) {
        self.missionID = missionID
        self.actor = actor
        self.packet = packet
    }
}

public struct BurnBarMissionRecordResultRequest: Codable, Hashable, Sendable {
    public let missionID: BurnBarMissionID
    public let result: BurnBarMissionResultSnapshot

    public init(missionID: BurnBarMissionID, result: BurnBarMissionResultSnapshot) {
        self.missionID = missionID
        self.result = result
    }
}

public struct BurnBarMissionMutationResponse: Codable, Hashable, Sendable {
    public let mission: BurnBarMissionSnapshot
    public let emittedEvent: BurnBarControllerEvent?

    public init(mission: BurnBarMissionSnapshot, emittedEvent: BurnBarControllerEvent? = nil) {
        self.mission = mission
        self.emittedEvent = emittedEvent
    }
}

public struct BurnBarNotificationConfigGetRequest: Codable, Hashable, Sendable {
    public init() {}
}

public struct BurnBarNotificationConfigUpdateRequest: Codable, Hashable, Sendable {
    public let config: BurnBarNotificationConfig

    public init(config: BurnBarNotificationConfig) {
        self.config = config
    }
}

public struct BurnBarNotificationConfigResponse: Codable, Hashable, Sendable {
    public let config: BurnBarNotificationConfig

    public init(config: BurnBarNotificationConfig) {
        self.config = config
    }
}

public struct BurnBarNotificationHealthRequest: Codable, Hashable, Sendable {
    public init() {}
}

public struct BurnBarNotificationHealthResponse: Codable, Hashable, Sendable {
    public let health: BurnBarNotificationHealthSnapshot

    public init(health: BurnBarNotificationHealthSnapshot) {
        self.health = health
    }
}

public struct BurnBarNotificationCommandRequest: Codable, Hashable, Sendable {
    public let command: BurnBarTelegramCommand
    public let arguments: [String]
    public let actor: String

    public init(command: BurnBarTelegramCommand, arguments: [String] = [], actor: String) {
        self.command = command
        self.arguments = arguments
        self.actor = actor
    }
}

public struct BurnBarSimulatorRunRequest: Codable, Hashable, Sendable {
    public let projectSlug: String
    public let scenarioName: String
    public let seed: Int
    public let injectedEvents: [BurnBarControllerEvent]
    public let metadata: BurnBarMetadata

    public init(
        projectSlug: String,
        scenarioName: String,
        seed: Int,
        injectedEvents: [BurnBarControllerEvent] = [],
        metadata: BurnBarMetadata = [:]
    ) {
        self.projectSlug = projectSlug
        self.scenarioName = scenarioName
        self.seed = seed
        self.injectedEvents = injectedEvents
        self.metadata = metadata
    }
}

public struct BurnBarSimulatorListRequest: Codable, Hashable, Sendable {
    public let projectSlug: String?
    public let limit: Int

    public init(projectSlug: String? = nil, limit: Int = 50) {
        self.projectSlug = projectSlug
        self.limit = limit
    }
}

public struct BurnBarSimulatorListResponse: Codable, Hashable, Sendable {
    public let runs: [BurnBarSimulatorRunSnapshot]

    public init(runs: [BurnBarSimulatorRunSnapshot]) {
        self.runs = runs
    }
}

public struct BurnBarSimulatorReplayRequest: Codable, Hashable, Sendable {
    public let runID: BurnBarSimulatorRunID
    public let fromCheckpointID: BurnBarProjectionCheckpointID?
    public let includeEvents: Bool

    public init(
        runID: BurnBarSimulatorRunID,
        fromCheckpointID: BurnBarProjectionCheckpointID? = nil,
        includeEvents: Bool = true
    ) {
        self.runID = runID
        self.fromCheckpointID = fromCheckpointID
        self.includeEvents = includeEvents
    }
}

public struct BurnBarSimulatorRunResponse: Codable, Hashable, Sendable {
    public let run: BurnBarSimulatorRunSnapshot

    public init(run: BurnBarSimulatorRunSnapshot) {
        self.run = run
    }
}

public struct BurnBarProjectionRebuildRequest: Codable, Hashable, Sendable {
    public let projectionNames: [String]
    public let fromCheckpointID: BurnBarProjectionCheckpointID?

    public init(projectionNames: [String], fromCheckpointID: BurnBarProjectionCheckpointID? = nil) {
        self.projectionNames = projectionNames
        self.fromCheckpointID = fromCheckpointID
    }
}

public struct BurnBarProjectionRebuildResponse: Codable, Hashable, Sendable {
    public let status: [BurnBarProjectionStatusSnapshot]

    public init(status: [BurnBarProjectionStatusSnapshot]) {
        self.status = status
    }
}
