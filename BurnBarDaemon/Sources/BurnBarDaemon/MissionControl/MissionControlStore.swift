import BurnBarCore
import Foundation

public actor BurnBarMissionControlStore {
    private let eventsFileURL: URL
    private let projectionFileURL: URL
    private let logger: BurnBarDaemonLogger
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var projection: BurnBarMissionControlProjectionFile?
    private var cachedEvents: [BurnBarControllerEvent]?
    private var seenEventIDs: Set<String> = []

    public init(
        eventsFileURL: URL = BurnBarDaemonPaths.defaultControllerEventJournalURL,
        projectionFileURL: URL = BurnBarDaemonPaths.defaultControllerProjectionURL,
        logger: BurnBarDaemonLogger = BurnBarDaemonLogger(category: "mission-control-store")
    ) {
        self.eventsFileURL = eventsFileURL
        self.projectionFileURL = projectionFileURL
        self.logger = logger
        encoder.outputFormatting = [.sortedKeys]
    }

    public func controllerSummary(_ request: BurnBarControllerSummaryRequest) throws -> BurnBarControllerSummaryResponse {
        try ensureLoaded()
        return BurnBarControllerSummaryResponse(summary: makeSummary(for: request))
    }

    public func project(slug: String) throws -> BurnBarReviewProjectSnapshot? {
        try ensureLoaded()
        return enrichedProjects()
            .first(where: { $0.projectSlug == slug })
    }

    public func projects(_ request: BurnBarControllerProjectsListRequest) throws -> [BurnBarReviewProjectSnapshot] {
        try ensureLoaded()
        return enrichedProjects()
            .filter { request.includePaused || $0.status != .paused }
            .prefix(request.limit)
            .map { $0 }
    }

    public func upsertProject(_ project: BurnBarReviewProjectSnapshot) throws -> (BurnBarReviewProjectSnapshot, BurnBarControllerEvent) {
        let event = try appendEvent(
            family: .controller,
            eventType: "project_upserted",
            projectSlug: project.projectSlug,
            summary: project.displayName,
            detail: project.summary,
            payload: try BurnBarJSONValue.fromEncodable(project)
        )
        return (try projectValue(project.projectSlug), event)
    }

    public func recordReviewRun(_ run: BurnBarReviewRunSnapshot) throws -> (BurnBarReviewRunSnapshot, BurnBarControllerEvent) {
        let event = try appendEvent(
            family: .controller,
            eventType: "review_run_recorded",
            projectSlug: run.projectSlug,
            summary: run.summary,
            detail: "\(run.cadence.rawValue) review",
            payload: try BurnBarJSONValue.fromEncodable(run)
        )
        return (try reviewRunValue(run.id), event)
    }

    public func question(id: BurnBarQuestionID) throws -> BurnBarPendingQuestionSnapshot? {
        try ensureLoaded()
        return projection?.questions[id.rawValue]
    }

    public func questions(_ request: BurnBarQuestionsListRequest) throws -> [BurnBarPendingQuestionSnapshot] {
        try ensureLoaded()
        return projection?.questions.values
            .filter { item in
                (request.projectSlug == nil || item.projectSlug == request.projectSlug)
                    && request.statuses.contains(item.status)
            }
            .sorted { $0.askedAt > $1.askedAt }
            .prefix(request.limit)
            .map { $0 } ?? []
    }

    public func createQuestion(_ question: BurnBarPendingQuestionSnapshot) throws -> (BurnBarPendingQuestionSnapshot, BurnBarControllerEvent) {
        let event = try appendEvent(
            family: .question,
            eventType: "question_created",
            projectSlug: question.projectSlug,
            summary: question.title,
            detail: question.prompt,
            payload: try BurnBarJSONValue.fromEncodable(question)
        )

        if followupForQuestion(question.id) == nil {
            let followup = BurnBarFollowupSnapshot(
                id: BurnBarFollowupID(rawValue: "followup-\(question.id.rawValue)"),
                projectSlug: question.projectSlug,
                questionID: question.id,
                title: question.title,
                summary: question.contextSummary ?? question.prompt,
                stageLabel: question.stageLabel,
                status: .open,
                kind: .pendingQuestion,
                createdAt: question.askedAt,
                nextNudgeAt: question.dueAt ?? Calendar.current.date(byAdding: .hour, value: 2, to: question.askedAt),
                deepLink: question.deepLink,
                metadata: question.metadata
            )
            _ = try appendEvent(
                family: .followup,
                eventType: "followup_created",
                projectSlug: followup.projectSlug,
                summary: followup.title,
                detail: followup.summary,
                payload: try BurnBarJSONValue.fromEncodable(followup)
            )
        }

        return (try questionValue(question.id), event)
    }

    public func answerQuestion(_ request: BurnBarQuestionAnswerRequest) throws -> BurnBarQuestionAnswerResponse {
        guard let existing = try question(id: request.questionID) else {
            throw BurnBarMissionControlError.questionNotFound(request.questionID)
        }

        let answeredAt = Date()
        let answer = BurnBarAnswerRecord(
            answeredAt: answeredAt,
            answeredBy: request.answeredBy,
            answer: request.answer,
            selectedOptionID: request.selectedOptionID,
            metadata: request.metadata
        )
        let updatedTracker = existing.tracker.map {
            BurnBarQuestionTrackerSnapshot(
                isUnread: false,
                surfacedAt: $0.surfacedAt ?? existing.askedAt,
                firstNotifiedAt: $0.firstNotifiedAt,
                lastNotifiedAt: $0.lastNotifiedAt,
                notificationCount: $0.notificationCount,
                metadata: $0.metadata
            )
        }
        let updated = BurnBarPendingQuestionSnapshot(
            id: existing.id,
            projectSlug: existing.projectSlug,
            sessionID: existing.sessionID,
            title: existing.title,
            prompt: existing.prompt,
            stageLabel: existing.stageLabel,
            status: .answered,
            priority: existing.priority,
            askedAt: existing.askedAt,
            dueAt: existing.dueAt,
            latestAnswer: answer,
            answerPlaceholder: existing.answerPlaceholder,
            contextSummary: existing.contextSummary,
            evidenceRefs: existing.evidenceRefs,
            suggestedOptions: existing.suggestedOptions,
            deepLink: existing.deepLink,
            tracker: updatedTracker,
            metadata: existing.metadata.merging(request.metadata) { _, new in new }
        )

        let event = try appendEvent(
            family: .question,
            eventType: "question_answered",
            projectSlug: updated.projectSlug,
            summary: updated.title,
            detail: request.answer,
            payload: try BurnBarJSONValue.fromEncodable(updated)
        )

        var resolvedFollowup: BurnBarFollowupSnapshot?
        if request.markFollowupDone, let followup = followupForQuestion(request.questionID) {
            resolvedFollowup = try markFollowupDone(
                BurnBarFollowupDoneRequest(
                    followupID: followup.id,
                    actor: request.answeredBy,
                    note: "Resolved when question \(request.questionID.rawValue) was answered."
                )
            ).followup
        }

        return BurnBarQuestionAnswerResponse(
            question: try questionValue(request.questionID),
            followup: resolvedFollowup,
            emittedEvent: event
        )
    }

    public func recordQuestionNotification(
        questionID: BurnBarQuestionID,
        channel: BurnBarNotificationChannel,
        notifiedAt: Date = Date()
    ) throws -> (BurnBarPendingQuestionSnapshot, BurnBarControllerEvent) {
        guard let existing = try question(id: questionID) else {
            throw BurnBarMissionControlError.questionNotFound(questionID)
        }

        let currentTracker = existing.tracker ?? BurnBarQuestionTrackerSnapshot(
            isUnread: true,
            surfacedAt: existing.askedAt
        )
        let updatedTracker = BurnBarQuestionTrackerSnapshot(
            isUnread: true,
            surfacedAt: currentTracker.surfacedAt ?? existing.askedAt,
            firstNotifiedAt: currentTracker.firstNotifiedAt ?? notifiedAt,
            lastNotifiedAt: notifiedAt,
            notificationCount: currentTracker.notificationCount + 1,
            metadata: currentTracker.metadata.merging([
                "last_channel": .string(channel.rawValue)
            ]) { _, new in new }
        )
        let updated = BurnBarPendingQuestionSnapshot(
            id: existing.id,
            projectSlug: existing.projectSlug,
            sessionID: existing.sessionID,
            title: existing.title,
            prompt: existing.prompt,
            stageLabel: existing.stageLabel,
            status: existing.status,
            priority: existing.priority,
            askedAt: existing.askedAt,
            dueAt: existing.dueAt,
            latestAnswer: existing.latestAnswer,
            answerPlaceholder: existing.answerPlaceholder,
            contextSummary: existing.contextSummary,
            evidenceRefs: existing.evidenceRefs,
            suggestedOptions: existing.suggestedOptions,
            deepLink: existing.deepLink,
            tracker: updatedTracker,
            metadata: existing.metadata
        )

        let event = try appendEvent(
            family: .question,
            eventType: "question_notified",
            projectSlug: updated.projectSlug,
            summary: updated.title,
            detail: "Delivered over \(channel.rawValue).",
            payload: try BurnBarJSONValue.fromEncodable(updated)
        )
        return (try questionValue(questionID), event)
    }

    public func followups(_ request: BurnBarFollowupsListRequest) throws -> [BurnBarFollowupSnapshot] {
        try ensureLoaded()
        return projection?.followups.values
            .filter { item in
                (request.projectSlug == nil || item.projectSlug == request.projectSlug)
                    && request.statuses.contains(item.status)
            }
            .sorted { ($0.nextNudgeAt ?? $0.createdAt) < ($1.nextNudgeAt ?? $1.createdAt) }
            .prefix(request.limit)
            .map { $0 } ?? []
    }

    public func createFollowup(_ request: BurnBarFollowupCreateRequest) throws -> BurnBarFollowupMutationResponse {
        let event = try appendEvent(
            family: .followup,
            eventType: "followup_created",
            projectSlug: request.followup.projectSlug,
            summary: request.followup.title,
            detail: request.followup.summary,
            payload: try BurnBarJSONValue.fromEncodable(request.followup)
        )
        return BurnBarFollowupMutationResponse(
            followup: try followupValue(request.followup.id),
            emittedEvent: event
        )
    }

    public func markFollowupDone(_ request: BurnBarFollowupDoneRequest) throws -> BurnBarFollowupMutationResponse {
        guard let existing = followup(id: request.followupID) else {
            throw BurnBarMissionControlError.followupNotFound(request.followupID)
        }

        let updated = BurnBarFollowupSnapshot(
            id: existing.id,
            projectSlug: existing.projectSlug,
            questionID: existing.questionID,
            title: existing.title,
            summary: request.note?.nonEmpty ?? existing.summary,
            stageLabel: existing.stageLabel,
            status: .done,
            kind: existing.kind,
            createdAt: existing.createdAt,
            nextNudgeAt: existing.nextNudgeAt,
            snoozeUntil: nil,
            calendarEntry: existing.calendarEntry,
            deepLink: existing.deepLink,
            metadata: existing.metadata.merging(["completed_by": .string(request.actor)]) { _, new in new }
        )

        let event = try appendEvent(
            family: .followup,
            eventType: "followup_done",
            projectSlug: updated.projectSlug,
            summary: updated.title,
            detail: updated.summary,
            payload: try BurnBarJSONValue.fromEncodable(updated)
        )

        return BurnBarFollowupMutationResponse(
            followup: try followupValue(updated.id),
            emittedEvent: event
        )
    }

    public func snoozeFollowup(_ request: BurnBarFollowupSnoozeRequest) throws -> BurnBarFollowupMutationResponse {
        guard let existing = followup(id: request.followupID) else {
            throw BurnBarMissionControlError.followupNotFound(request.followupID)
        }

        let updated = BurnBarFollowupSnapshot(
            id: existing.id,
            projectSlug: existing.projectSlug,
            questionID: existing.questionID,
            title: existing.title,
            summary: request.note?.nonEmpty ?? existing.summary,
            stageLabel: existing.stageLabel,
            status: .snoozed,
            kind: existing.kind,
            createdAt: existing.createdAt,
            nextNudgeAt: existing.nextNudgeAt,
            snoozeUntil: request.snoozeUntil,
            calendarEntry: existing.calendarEntry,
            deepLink: existing.deepLink,
            metadata: existing.metadata.merging(["snoozed_by": .string(request.actor)]) { _, new in new }
        )

        let event = try appendEvent(
            family: .followup,
            eventType: "followup_snoozed",
            projectSlug: updated.projectSlug,
            summary: updated.title,
            detail: "Snoozed until \(request.snoozeUntil.formatted(date: .abbreviated, time: .shortened)).",
            payload: try BurnBarJSONValue.fromEncodable(updated)
        )

        return BurnBarFollowupMutationResponse(
            followup: try followupValue(updated.id),
            emittedEvent: event
        )
    }

    public func scheduleFollowupCalendar(_ request: BurnBarFollowupCalendarRequest) throws -> BurnBarFollowupMutationResponse {
        guard let existing = followup(id: request.followupID) else {
            throw BurnBarMissionControlError.followupNotFound(request.followupID)
        }

        let calendarEntry: BurnBarCalendarEntrySnapshot?
        switch request.action {
        case .create, .update:
            calendarEntry = request.entry
        case .remove:
            calendarEntry = nil
        }

        let updated = BurnBarFollowupSnapshot(
            id: existing.id,
            projectSlug: existing.projectSlug,
            questionID: existing.questionID,
            title: existing.title,
            summary: existing.summary,
            stageLabel: existing.stageLabel,
            status: existing.status == .done ? .done : .open,
            kind: existing.kind,
            createdAt: existing.createdAt,
            nextNudgeAt: existing.nextNudgeAt,
            snoozeUntil: existing.snoozeUntil,
            calendarEntry: calendarEntry,
            deepLink: existing.deepLink,
            metadata: existing.metadata.merging(["calendar_actor": .string(request.actor)]) { _, new in new }
        )

        let event = try appendEvent(
            family: .followup,
            eventType: "followup_calendar_\(request.action.rawValue)",
            projectSlug: updated.projectSlug,
            summary: updated.title,
            detail: request.entry.title,
            payload: try BurnBarJSONValue.fromEncodable(updated)
        )

        return BurnBarFollowupMutationResponse(
            followup: try followupValue(updated.id),
            emittedEvent: event
        )
    }

    public func mission(id: BurnBarMissionID) throws -> BurnBarMissionSnapshot? {
        try ensureLoaded()
        return projection?.missions[id.rawValue]
    }

    public func missions(_ request: BurnBarMissionListRequest) throws -> [BurnBarMissionSnapshot] {
        try ensureLoaded()
        return projection?.missions.values
            .filter { item in
                (request.projectSlug == nil || item.projectSlug == request.projectSlug)
                    && request.statuses.contains(item.status)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(request.limit)
            .map { $0 } ?? []
    }

    public func createMission(_ request: BurnBarMissionCreateRequest) throws -> BurnBarMissionMutationResponse {
        let now = Date()
        let mission = BurnBarMissionSnapshot(
            id: BurnBarMissionID(rawValue: "mission-\(UUID().uuidString)"),
            projectSlug: request.projectSlug,
            title: request.title,
            summary: request.summary,
            status: .awaitingApproval,
            recommendation: request.recommendation,
            createdAt: now,
            updatedAt: now,
            approval: BurnBarMissionApprovalSnapshot(
                approved: false,
                approvedAt: nil,
                approvedBy: nil,
                note: nil
            ),
            takeoverHistory: nil,
            metadata: request.metadata.merging(["created_by": .string(request.createdBy)]) { _, new in new }
        )

        let event = try appendEvent(
            family: .mission,
            eventType: "mission_created",
            projectSlug: mission.projectSlug,
            summary: mission.title,
            detail: mission.summary,
            payload: try BurnBarJSONValue.fromEncodable(mission)
        )

        return BurnBarMissionMutationResponse(
            mission: try missionValue(mission.id),
            emittedEvent: event
        )
    }

    public func approveMission(_ request: BurnBarMissionApproveRequest) throws -> BurnBarMissionMutationResponse {
        guard let existing = try mission(id: request.missionID) else {
            throw BurnBarMissionControlError.missionNotFound(request.missionID)
        }

        let now = Date()
        let updated = BurnBarMissionSnapshot(
            id: existing.id,
            projectSlug: existing.projectSlug,
            title: existing.title,
            summary: existing.summary,
            status: existing.status == .cancelled ? .cancelled : .approved,
            recommendation: existing.recommendation,
            createdAt: existing.createdAt,
            updatedAt: now,
            approval: BurnBarMissionApprovalSnapshot(
                approved: true,
                approvedAt: now,
                approvedBy: request.actor,
                note: request.note
            ),
            packets: existing.packets,
            results: existing.results,
            burnRecords: existing.burnRecords,
            takeoverHistory: existing.takeoverHistory,
            metadata: existing.metadata
        )

        let event = try appendEvent(
            family: .mission,
            eventType: "mission_approved",
            projectSlug: updated.projectSlug,
            summary: updated.title,
            detail: request.note,
            payload: try BurnBarJSONValue.fromEncodable(updated)
        )

        return BurnBarMissionMutationResponse(
            mission: try missionValue(updated.id),
            emittedEvent: event
        )
    }

    public func dispatchMissionPacket(_ request: BurnBarMissionDispatchPacketRequest) throws -> BurnBarMissionMutationResponse {
        guard let existing = try mission(id: request.missionID) else {
            throw BurnBarMissionControlError.missionNotFound(request.missionID)
        }

        let packet = BurnBarMissionPacketSnapshot(
            id: request.packet.id,
            missionID: existing.id,
            workerName: request.packet.workerName,
            objective: request.packet.objective,
            status: request.packet.status,
            runID: request.packet.runID,
            dispatchedAt: request.packet.dispatchedAt ?? Date(),
            completedAt: request.packet.completedAt,
            metadata: request.packet.metadata.merging(["actor": .string(request.actor)]) { _, new in new }
        )
        let packets = mergePackets(existing.packets, packet)
        let updated = BurnBarMissionSnapshot(
            id: existing.id,
            projectSlug: existing.projectSlug,
            title: existing.title,
            summary: existing.summary,
            status: packet.status == .completed ? .inProgress : .dispatching,
            recommendation: existing.recommendation,
            createdAt: existing.createdAt,
            updatedAt: packet.dispatchedAt ?? Date(),
            approval: existing.approval,
            packets: packets,
            results: existing.results,
            burnRecords: existing.burnRecords,
            takeoverHistory: existing.takeoverHistory,
            metadata: existing.metadata
        )

        let event = try appendEvent(
            family: .mission,
            eventType: "mission_packet_dispatched",
            projectSlug: updated.projectSlug,
            summary: packet.workerName,
            detail: packet.objective,
            payload: try BurnBarJSONValue.fromEncodable(updated)
        )

        return BurnBarMissionMutationResponse(
            mission: try missionValue(updated.id),
            emittedEvent: event
        )
    }

    public func recordMissionResult(_ request: BurnBarMissionRecordResultRequest) throws -> BurnBarMissionMutationResponse {
        guard let existing = try mission(id: request.missionID) else {
            throw BurnBarMissionControlError.missionNotFound(request.missionID)
        }

        let result = BurnBarMissionResultSnapshot(
            id: request.result.id,
            missionID: existing.id,
            packetID: request.result.packetID,
            runID: request.result.runID,
            status: request.result.status,
            summary: request.result.summary,
            detail: request.result.detail,
            burnDelta: request.result.burnDelta,
            createdAt: request.result.createdAt,
            evidenceRefs: request.result.evidenceRefs,
            metadata: request.result.metadata
        )
        let burnRecord = BurnBarMissionBurnRecord(
            id: "burn-\(result.id.rawValue)",
            label: result.summary,
            amount: result.burnDelta,
            unit: "points",
            recordedAt: result.createdAt
        )
        let mergedResults = mergeResults(existing.results, result)
        let mergedBurnRecords = mergeBurnRecords(existing.burnRecords, burnRecord)
        var metadata = existing.metadata
        let totalTokens = mergedResults.reduce(0) { partial, result in
            partial
                + intValue(result.metadata["input_tokens"])
                + intValue(result.metadata["output_tokens"])
                + intValue(result.metadata["cache_read_tokens"])
        }
        metadata["total_tokens"] = .number(Double(totalTokens))
        metadata["result_count"] = .number(Double(mergedResults.count))
        metadata["burn_record_count"] = .number(Double(mergedBurnRecords.count))
        let updated = BurnBarMissionSnapshot(
            id: existing.id,
            projectSlug: existing.projectSlug,
            title: existing.title,
            summary: existing.summary,
            status: missionStatus(for: result.status),
            recommendation: existing.recommendation,
            createdAt: existing.createdAt,
            updatedAt: result.createdAt,
            approval: existing.approval,
            packets: existing.packets,
            results: mergedResults,
            burnRecords: mergedBurnRecords,
            takeoverHistory: existing.takeoverHistory,
            metadata: metadata
        )

        let event = try appendEvent(
            family: .mission,
            eventType: "mission_result_recorded",
            projectSlug: updated.projectSlug,
            summary: result.summary,
            detail: result.detail,
            payload: try BurnBarJSONValue.fromEncodable(updated)
        )

        return BurnBarMissionMutationResponse(
            mission: try missionValue(updated.id),
            emittedEvent: event
        )
    }

    public func persistMissionSnapshot(
        _ mission: BurnBarMissionSnapshot,
        eventType: String,
        summary: String,
        detail: String? = nil
    ) throws -> BurnBarMissionMutationResponse {
        let event = try appendEvent(
            family: .mission,
            eventType: eventType,
            projectSlug: mission.projectSlug,
            summary: summary,
            detail: detail,
            payload: try BurnBarJSONValue.fromEncodable(mission)
        )
        return BurnBarMissionMutationResponse(
            mission: try missionValue(mission.id),
            emittedEvent: event
        )
    }

    public func notificationConfig() throws -> BurnBarNotificationConfig {
        try ensureLoaded()
        return projection?.notificationConfig ?? BurnBarMissionControlProjectionFile.defaultNotificationConfig()
    }

    public func telegramUpdateOffset() throws -> Int? {
        try ensureLoaded()
        return projection?.telegramUpdateOffset
    }

    public func setTelegramUpdateOffset(_ offset: Int?) throws {
        try ensureLoaded()
        projection?.telegramUpdateOffset = offset
        try writeProjection()
    }

    public func recordTransportError(channel: BurnBarNotificationChannel, error: String?) throws {
        try ensureLoaded()
        if let error, error.isEmpty == false {
            projection?.transportErrors[channel.rawValue] = error
        } else {
            projection?.transportErrors.removeValue(forKey: channel.rawValue)
        }
        try writeProjection()
    }

    public func transportError(for channel: BurnBarNotificationChannel) throws -> String? {
        try ensureLoaded()
        return projection?.transportErrors[channel.rawValue]
    }

    public func recordNotificationCommand(
        _ request: BurnBarNotificationCommandRequest,
        responseSummary: String,
        projectSlug: String
    ) throws {
        _ = try appendEvent(
            family: .notification,
            eventType: "notification_command_\(request.command.rawValue)",
            projectSlug: projectSlug,
            summary: responseSummary,
            detail: nil,
            payload: try BurnBarJSONValue.fromEncodable(request)
        )
    }

    public func updateNotificationConfig(_ request: BurnBarNotificationConfigUpdateRequest) throws -> BurnBarNotificationConfigResponse {
        let event = try appendEvent(
            family: .notification,
            eventType: "notification_config_updated",
            projectSlug: "burnbar",
            summary: "Notification configuration updated",
            detail: nil,
            payload: try BurnBarJSONValue.fromEncodable(request.config)
        )
        _ = event
        return BurnBarNotificationConfigResponse(config: try notificationConfig())
    }

    public func notificationHealth() throws -> BurnBarNotificationHealthResponse {
        try ensureLoaded()
        return BurnBarNotificationHealthResponse(health: makeNotificationHealth())
    }

    public func handleNotificationCommand(_ request: BurnBarNotificationCommandRequest) throws -> BurnBarNotificationCommandResponse {
        let response: BurnBarNotificationCommandResponse

        switch request.command {
        case .help:
            response = BurnBarNotificationCommandResponse(
                command: .help,
                ok: true,
                message: "Commands: help, pending, followups, done <id>, snooze <id> [minutes], calendar <id> <ISO8601>, answer <id> <text>, latest, status, run_daily <project>, run_weekly <project>."
            )
        case .pending, .followups:
            let open = try followups(BurnBarFollowupsListRequest())
            if open.isEmpty {
                response = BurnBarNotificationCommandResponse(
                    command: request.command,
                    ok: true,
                    message: "No unresolved followups."
                )
            } else {
                let preview = open.prefix(5).map { "\($0.id.rawValue): \($0.title)" }.joined(separator: "\n")
                response = BurnBarNotificationCommandResponse(
                    command: request.command,
                    ok: true,
                    message: preview,
                    followup: open.first
                )
            }
        case .done:
            guard let rawID = request.arguments.first else {
                response = BurnBarNotificationCommandResponse(command: .done, ok: false, message: "Usage: done <followupID>")
                break
            }
            let mutation = try markFollowupDone(
                BurnBarFollowupDoneRequest(
                    followupID: BurnBarFollowupID(rawValue: rawID),
                    actor: request.actor
                )
            )
            response = BurnBarNotificationCommandResponse(
                command: .done,
                ok: true,
                message: "Marked \(mutation.followup.title) done.",
                followup: mutation.followup
            )
        case .snooze:
            guard let rawID = request.arguments.first else {
                response = BurnBarNotificationCommandResponse(command: .snooze, ok: false, message: "Usage: snooze <followupID> [minutes]")
                break
            }
            let minutes = request.arguments.count > 1 ? Int(request.arguments[1]) ?? 60 : 60
            let until = Date().addingTimeInterval(Double(minutes * 60))
            let mutation = try snoozeFollowup(
                BurnBarFollowupSnoozeRequest(
                    followupID: BurnBarFollowupID(rawValue: rawID),
                    actor: request.actor,
                    snoozeUntil: until
                )
            )
            response = BurnBarNotificationCommandResponse(
                command: .snooze,
                ok: true,
                message: "Snoozed \(mutation.followup.title) for \(minutes)m.",
                followup: mutation.followup
            )
        case .calendar:
            guard let rawID = request.arguments.first else {
                response = BurnBarNotificationCommandResponse(command: .calendar, ok: false, message: "Usage: calendar <followupID> <ISO8601>")
                break
            }
            let formatter = ISO8601DateFormatter()
            let start = request.arguments.count > 1
                ? (formatter.date(from: request.arguments[1]) ?? Date().addingTimeInterval(3600))
                : Date().addingTimeInterval(3600)
            let config = try notificationConfig()
            let end = start.addingTimeInterval(Double(config.calendar.defaultDurationMinutes) * 60)
            let mutation = try scheduleFollowupCalendar(
                BurnBarFollowupCalendarRequest(
                    followupID: BurnBarFollowupID(rawValue: rawID),
                    actor: request.actor,
                    action: .create,
                    entry: BurnBarCalendarEntrySnapshot(
                        externalID: nil,
                        title: "BurnBar followup \(rawID)",
                        startAt: start,
                        endAt: end,
                        notes: "Scheduled from notification command."
                    )
                )
            )
            response = BurnBarNotificationCommandResponse(
                command: .calendar,
                ok: true,
                message: "Scheduled \(mutation.followup.title) on the calendar.",
                followup: mutation.followup
            )
        case .answer:
            guard let rawID = request.arguments.first, request.arguments.count > 1 else {
                response = BurnBarNotificationCommandResponse(command: .answer, ok: false, message: "Usage: answer <questionID> <text>")
                break
            }
            let text = request.arguments.dropFirst().joined(separator: " ")
            let answered = try answerQuestion(
                BurnBarQuestionAnswerRequest(
                    questionID: BurnBarQuestionID(rawValue: rawID),
                    answeredBy: request.actor,
                    answer: text
                )
            )
            response = BurnBarNotificationCommandResponse(
                command: .answer,
                ok: true,
                message: "Answered \(answered.question.title).",
                followup: answered.followup,
                question: answered.question
            )
        case .latest, .status:
            let summary = try controllerSummary(BurnBarControllerSummaryRequest()).summary
            response = BurnBarNotificationCommandResponse(
                command: request.command,
                ok: true,
                message: "Projects: \(summary.counts.projectCount), pending questions: \(summary.counts.pendingQuestionCount), open followups: \(summary.counts.openFollowupCount), active missions: \(summary.counts.activeMissionCount)."
            )
        case .runDaily, .runWeekly:
            let fallbackSummary = try controllerSummary(BurnBarControllerSummaryRequest())
            let fallbackSlug = fallbackSummary.summary.activeProjectSlug ?? "burnbar"
            let slug = request.arguments.first ?? fallbackSlug
            let cadence: BurnBarControllerReviewCadence = request.command == .runDaily ? .daily : .weekly
            let run = BurnBarReviewRunSnapshot(
                id: "review-\(UUID().uuidString)",
                projectSlug: slug,
                cadence: cadence,
                recordedAt: Date(),
                summary: "Triggered from \(request.actor) notification command.",
                questionCount: try questions(BurnBarQuestionsListRequest(projectSlug: slug)).count,
                followupCount: try followups(BurnBarFollowupsListRequest(projectSlug: slug)).count,
                missionCount: try missions(BurnBarMissionListRequest(projectSlug: slug)).count
            )
            _ = try recordReviewRun(run)
            response = BurnBarNotificationCommandResponse(
                command: request.command,
                ok: true,
                message: "Recorded \(cadence.rawValue) review for \(slug)."
            )
        }

        _ = try appendEvent(
            family: .notification,
            eventType: "notification_command_\(request.command.rawValue)",
            projectSlug: response.followup?.projectSlug ?? response.question?.projectSlug ?? response.mission?.projectSlug ?? "burnbar",
            summary: response.message,
            detail: nil,
            payload: try BurnBarJSONValue.fromEncodable(request)
        )

        return response
    }

    public func recordSimulatorRun(_ request: BurnBarSimulatorRunRequest) throws -> BurnBarSimulatorRunResponse {
        let now = Date()
        let emittedEvents = request.injectedEvents.isEmpty
            ? try defaultSimulatorEvents(for: request, now: now)
            : request.injectedEvents
        let status = projectionStatusArray(sortedBySequence: projection?.lastSequence ?? 0, recordedAt: now)
        let run = BurnBarSimulatorRunSnapshot(
            id: BurnBarSimulatorRunID(rawValue: "simulator-\(UUID().uuidString)"),
            projectSlug: request.projectSlug,
            scenarioName: request.scenarioName,
            status: .queued,
            seed: request.seed,
            startedAt: now,
            completedAt: nil,
            emittedEvents: emittedEvents,
            projectionStatus: status,
            summary: "Prepared \(emittedEvents.count) replayable controller event\(emittedEvents.count == 1 ? "" : "s")."
        )

        _ = try appendEvent(
            family: .simulator,
            eventType: "simulator_run_recorded",
            projectSlug: run.projectSlug,
            summary: run.scenarioName,
            detail: run.summary,
            payload: try BurnBarJSONValue.fromEncodable(run)
        )

        return BurnBarSimulatorRunResponse(run: try simulatorRunValue(run.id))
    }

    public func simulatorRuns(_ request: BurnBarSimulatorListRequest) throws -> BurnBarSimulatorListResponse {
        try ensureLoaded()
        let runs = projection?.simulatorRuns.values
            .filter { request.projectSlug == nil || $0.projectSlug == request.projectSlug }
            .sorted { $0.startedAt > $1.startedAt }
            .prefix(request.limit)
            .map { $0 } ?? []
        return BurnBarSimulatorListResponse(runs: runs)
    }

    public func replaySimulator(_ request: BurnBarSimulatorReplayRequest) throws -> BurnBarSimulatorRunResponse {
        guard let existing = simulatorRun(id: request.runID) else {
            throw BurnBarMissionControlError.simulatorRunNotFound(request.runID)
        }

        for event in existing.emittedEvents {
            let payload = event.metadata["payload"]
            _ = try appendEvent(
                family: event.family,
                eventType: event.eventType,
                projectSlug: event.projectSlug,
                summary: event.summary,
                detail: event.detail,
                payload: payload,
                isReplay: true
            )
        }

        let completedAt = Date()
        let updated = BurnBarSimulatorRunSnapshot(
            id: existing.id,
            projectSlug: existing.projectSlug,
            scenarioName: existing.scenarioName,
            status: .completed,
            seed: existing.seed,
            startedAt: existing.startedAt,
            completedAt: completedAt,
            emittedEvents: request.includeEvents ? existing.emittedEvents : [],
            projectionStatus: projectionStatusArray(sortedBySequence: projection?.lastSequence ?? 0, recordedAt: completedAt),
            summary: "Replayed \(existing.emittedEvents.count) controller event\(existing.emittedEvents.count == 1 ? "" : "s")."
        )

        _ = try appendEvent(
            family: .simulator,
            eventType: "simulator_replayed",
            projectSlug: updated.projectSlug,
            summary: updated.scenarioName,
            detail: updated.summary,
            payload: try BurnBarJSONValue.fromEncodable(updated)
        )

        return BurnBarSimulatorRunResponse(run: try simulatorRunValue(updated.id))
    }

    public func rebuildProjection(_ request: BurnBarProjectionRebuildRequest) throws -> BurnBarProjectionRebuildResponse {
        let events = try loadEvents()
        projection = BurnBarMissionControlProjectionFile.empty(now: Date())
        seenEventIDs = []
        for event in events.sorted(by: eventSort) {
            try apply(event)
        }
        try writeProjection()

        _ = try appendEvent(
            family: .projection,
            eventType: "projection_rebuilt",
            projectSlug: request.projectionNames.first ?? "burnbar",
            summary: "Projection rebuild completed",
            detail: request.projectionNames.joined(separator: ", "),
            payload: BurnBarJSONValue.array(request.projectionNames.map(BurnBarJSONValue.string))
        )

        let names = request.projectionNames.isEmpty
            ? projectionStatusArray(sortedBySequence: projection?.lastSequence ?? 0, recordedAt: Date())
            : projectionStatusArray(sortedBySequence: projection?.lastSequence ?? 0, recordedAt: Date())
                .filter { request.projectionNames.contains($0.projectionName) }
        return BurnBarProjectionRebuildResponse(status: names)
    }

    public func evaluateDueNotifications(now: Date) throws -> [BurnBarFollowupSnapshot] {
        try ensureLoaded()

        let config = projection?.notificationConfig ?? BurnBarMissionControlProjectionFile.defaultNotificationConfig()
        let open = try followups(BurnBarFollowupsListRequest(statuses: [.open, .snoozed], limit: 500))
        for followup in open {
            if followup.status == .snoozed, let snoozeUntil = followup.snoozeUntil, snoozeUntil <= now {
                let reopened = BurnBarFollowupSnapshot(
                    id: followup.id,
                    projectSlug: followup.projectSlug,
                    questionID: followup.questionID,
                    title: followup.title,
                    summary: followup.summary,
                    stageLabel: followup.stageLabel,
                    status: .open,
                    kind: followup.kind,
                    createdAt: followup.createdAt,
                    nextNudgeAt: snoozeUntil,
                    snoozeUntil: nil,
                    calendarEntry: followup.calendarEntry,
                    deepLink: followup.deepLink,
                    metadata: followup.metadata
                )
                _ = try appendEvent(
                    family: .followup,
                    eventType: "followup_reopened",
                    projectSlug: reopened.projectSlug,
                    summary: reopened.title,
                    detail: "Snooze expired.",
                    payload: try BurnBarJSONValue.fromEncodable(reopened)
                )
            }
        }

        let ready = try followups(BurnBarFollowupsListRequest(statuses: [.open], limit: 500))
        var nudgedFollowups: [BurnBarFollowupSnapshot] = []
        for followup in ready {
            guard let nextNudgeAt = followup.nextNudgeAt ?? followup.calendarEntry?.startAt ?? followup.createdAt as Date? else {
                continue
            }
            if nextNudgeAt > now {
                continue
            }

            let rescheduled = BurnBarFollowupSnapshot(
                id: followup.id,
                projectSlug: followup.projectSlug,
                questionID: followup.questionID,
                title: followup.title,
                summary: followup.summary,
                stageLabel: followup.stageLabel,
                status: .open,
                kind: followup.kind,
                createdAt: followup.createdAt,
                nextNudgeAt: now.addingTimeInterval(Double(config.defaultSnoozeMinutes * 60)),
                snoozeUntil: followup.snoozeUntil,
                calendarEntry: followup.calendarEntry,
                deepLink: followup.deepLink,
                metadata: followup.metadata
            )
            _ = try appendEvent(
                family: .followup,
                eventType: "followup_nudged",
                projectSlug: rescheduled.projectSlug,
                summary: rescheduled.title,
                detail: "Nudged by BurnBar runtime.",
                payload: try BurnBarJSONValue.fromEncodable(rescheduled)
            )
            _ = try appendEvent(
                family: .notification,
                eventType: "notification_local_due",
                projectSlug: rescheduled.projectSlug,
                summary: rescheduled.title,
                detail: rescheduled.summary,
                payload: try BurnBarJSONValue.fromEncodable(rescheduled)
            )
            nudgedFollowups.append(rescheduled)
        }
        _ = config
        return nudgedFollowups
    }

    private func ensureLoaded() throws {
        if projection != nil {
            return
        }

        if FileManager.default.fileExists(atPath: projectionFileURL.path),
           let data = try? Data(contentsOf: projectionFileURL),
           let decoded = try? decoder.decode(BurnBarMissionControlProjectionFile.self, from: data) {
            projection = decoded
        } else {
            projection = BurnBarMissionControlProjectionFile.empty()
        }

        let events = try loadEvents()
        projection = BurnBarMissionControlProjectionFile.empty(now: projection?.rebuiltAt ?? Date())
        seenEventIDs = []
        for event in events.sorted(by: eventSort) {
            try apply(event)
        }
        try writeProjection()
    }

    private func loadEvents() throws -> [BurnBarControllerEvent] {
        if let cachedEvents {
            return cachedEvents
        }
        guard FileManager.default.fileExists(atPath: eventsFileURL.path) else {
            cachedEvents = []
            return []
        }

        let content = try String(contentsOf: eventsFileURL, encoding: .utf8)
        let events = content
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> BurnBarControllerEvent? in
                guard line.isEmpty == false else { return nil }
                do {
                    return try decoder.decode(BurnBarControllerEvent.self, from: Data(line.utf8))
                } catch {
                    logger.error(
                        "controller_event_skipped",
                        metadata: ["error": error.localizedDescription]
                    )
                    return nil
                }
            }
        cachedEvents = events
        return events
    }

    private func projectValue(_ slug: String) throws -> BurnBarReviewProjectSnapshot {
        guard let project = try project(slug: slug) else {
            throw BurnBarMissionControlError.projectNotFound(slug)
        }
        return project
    }

    private func reviewRunValue(_ id: String) throws -> BurnBarReviewRunSnapshot {
        try ensureLoaded()
        guard let run = projection?.reviewRuns[id] else {
            throw BurnBarMissionControlError.projectNotFound(id)
        }
        return run
    }

    private func questionValue(_ id: BurnBarQuestionID) throws -> BurnBarPendingQuestionSnapshot {
        guard let question = try question(id: id) else {
            throw BurnBarMissionControlError.questionNotFound(id)
        }
        return question
    }

    private func followup(id: BurnBarFollowupID) -> BurnBarFollowupSnapshot? {
        projection?.followups[id.rawValue]
    }

    private func followupValue(_ id: BurnBarFollowupID) throws -> BurnBarFollowupSnapshot {
        guard let followup = followup(id: id) else {
            throw BurnBarMissionControlError.followupNotFound(id)
        }
        return followup
    }

    private func followupForQuestion(_ questionID: BurnBarQuestionID) -> BurnBarFollowupSnapshot? {
        projection?.followups.values.first { $0.questionID == questionID && $0.status != .done }
    }

    private func missionValue(_ id: BurnBarMissionID) throws -> BurnBarMissionSnapshot {
        guard let mission = try mission(id: id) else {
            throw BurnBarMissionControlError.missionNotFound(id)
        }
        return mission
    }

    private func simulatorRun(id: BurnBarSimulatorRunID) -> BurnBarSimulatorRunSnapshot? {
        projection?.simulatorRuns[id.rawValue]
    }

    private func simulatorRunValue(_ id: BurnBarSimulatorRunID) throws -> BurnBarSimulatorRunSnapshot {
        guard let run = simulatorRun(id: id) else {
            throw BurnBarMissionControlError.simulatorRunNotFound(id)
        }
        return run
    }

    private func appendEvent(
        family: BurnBarControllerEventFamily,
        eventType: String,
        projectSlug: String,
        summary: String,
        detail: String?,
        payload: BurnBarJSONValue?,
        isReplay: Bool = false
    ) throws -> BurnBarControllerEvent {
        try ensureLoaded()
        let sequence = (projection?.lastSequence ?? 0) + 1
        var metadata: BurnBarMetadata = [:]
        if let payload {
            metadata["payload"] = payload
        }

        let event = BurnBarControllerEvent(
            id: BurnBarControllerEventID(rawValue: "controller-event-\(UUID().uuidString)"),
            family: family,
            eventType: eventType,
            projectSlug: projectSlug,
            recordedAt: Date(),
            sequence: sequence,
            summary: summary,
            detail: detail,
            metadata: metadata,
            isReplay: isReplay
        )

        try append(event)
        return event
    }

    private func append(_ event: BurnBarControllerEvent) throws {
        try ensureParentDirectory(for: eventsFileURL)
        let data = try encoder.encode(event) + Data([0x0A])
        if FileManager.default.fileExists(atPath: eventsFileURL.path) {
            let handle = try FileHandle(forWritingTo: eventsFileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: eventsFileURL, options: .atomic)
        }
        try apply(event)
        if cachedEvents == nil {
            cachedEvents = [event]
        } else {
            cachedEvents?.append(event)
        }
        try writeProjection()
    }

    private func apply(_ event: BurnBarControllerEvent) throws {
        guard seenEventIDs.insert(event.id.rawValue).inserted else {
            return
        }
        var state = projection ?? BurnBarMissionControlProjectionFile.empty(now: event.recordedAt)
        state.lastSequence = max(state.lastSequence, event.sequence)
        state.rebuiltAt = max(state.rebuiltAt, event.recordedAt)
        touchProjectionStatus(for: event, projection: &state)

        switch (event.family, event.eventType) {
        case (.controller, "project_upserted"):
            let project = try decodePayload(BurnBarReviewProjectSnapshot.self, from: event)
            state.projects[project.projectSlug] = project
        case (.controller, "review_run_recorded"):
            let run = try decodePayload(BurnBarReviewRunSnapshot.self, from: event)
            state.reviewRuns[run.id] = run
        case (.question, "question_created"),
             (.question, "question_answered"),
             (.question, "question_notified"):
            let question = try decodePayload(BurnBarPendingQuestionSnapshot.self, from: event)
            state.questions[question.id.rawValue] = question
        case (.followup, "followup_created"),
             (.followup, "followup_done"),
             (.followup, "followup_snoozed"),
             (.followup, "followup_reopened"),
             (.followup, "followup_nudged"),
             (.followup, "followup_calendar_create"),
             (.followup, "followup_calendar_update"),
             (.followup, "followup_calendar_remove"):
            let followup = try decodePayload(BurnBarFollowupSnapshot.self, from: event)
            state.followups[followup.id.rawValue] = followup
        case (.mission, _):
            let mission = try decodePayload(BurnBarMissionSnapshot.self, from: event)
            state.missions[mission.id.rawValue] = mission
        case (.notification, "notification_config_updated"):
            let config = try decodePayload(BurnBarNotificationConfig.self, from: event)
            state.notificationConfig = config
        case (.simulator, "simulator_run_recorded"), (.simulator, "simulator_replayed"):
            let run = try decodePayload(BurnBarSimulatorRunSnapshot.self, from: event)
            state.simulatorRuns[run.id.rawValue] = run
        case (.projection, "projection_rebuilt"):
            break
        default:
            break
        }
        projection = state
    }

    private func writeProjection() throws {
        try ensureParentDirectory(for: projectionFileURL)
        guard let projection else { return }
        let data = try encoder.encode(projection)
        try data.write(to: projectionFileURL, options: .atomic)
    }

    private func decodePayload<Value: Decodable>(_ type: Value.Type, from event: BurnBarControllerEvent) throws -> Value {
        guard let payload = event.metadata["payload"] else {
            throw BurnBarMissionControlError.missingPayload(event.eventType)
        }
        let data = try JSONEncoder().encode(payload)
        return try JSONDecoder().decode(Value.self, from: data)
    }

    private func ensureParentDirectory(for fileURL: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func touchProjectionStatus(
        for event: BurnBarControllerEvent,
        projection: inout BurnBarMissionControlProjectionFile
    ) {
        let names = projectionNames(for: event)
        for name in names {
            let checkpoint = BurnBarReplayCheckpoint(
                id: BurnBarProjectionCheckpointID(rawValue: "checkpoint-\(name)-\(event.sequence)"),
                projectionName: name,
                eventSequence: event.sequence,
                recordedAt: event.recordedAt
            )
            projection.projectionStatus[name] = BurnBarProjectionStatusSnapshot(
                projectionName: name,
                status: .upToDate,
                freshness: event.isReplay ? .provisional : .fresh,
                lastMaterializedAt: event.recordedAt,
                lastEventSequence: event.sequence,
                checkpoint: checkpoint
            )
        }
    }

    private func projectionNames(for event: BurnBarControllerEvent) -> [String] {
        switch event.family {
        case .controller:
            return ["controller_summary", "conversation_home", "governance_history"]
        case .question:
            return ["pending_questions", "controller_summary", "conversation_home"]
        case .followup:
            return ["followups", "controller_summary", "conversation_home"]
        case .mission:
            return ["missions", "controller_summary", "conversation_home"]
        case .notification:
            return ["controller_summary", "governance_history"]
        case .simulator:
            return ["controller_summary", "governance_history"]
        case .projection:
            return ["controller_summary", "conversation_home", "followups", "pending_questions", "missions", "governance_history"]
        case .governance:
            return ["governance_history", "controller_summary"]
        }
    }

    private func enrichedProjects() -> [BurnBarReviewProjectSnapshot] {
        let baseProjects = projection.map { Array($0.projects.values) } ?? []
        return baseProjects
            .map { base in
                let pendingQuestions = projection?.questions.values.filter {
                    $0.projectSlug == base.projectSlug && $0.status == .pending
                }.count ?? 0
                let openFollowups = projection?.followups.values.filter {
                    $0.projectSlug == base.projectSlug && $0.status == .open
                }.count ?? 0
                let activeMissions = projection?.missions.values.filter {
                    $0.projectSlug == base.projectSlug
                        && ![BurnBarMissionStatus.completed, .failed, .cancelled].contains($0.status)
                } ?? []
                let latestDaily = projection?.reviewRuns.values
                    .filter { $0.projectSlug == base.projectSlug && $0.cadence == .daily }
                    .sorted { $0.recordedAt > $1.recordedAt }
                    .first?.recordedAt
                let latestWeekly = projection?.reviewRuns.values
                    .filter { $0.projectSlug == base.projectSlug && $0.cadence == .weekly }
                    .sorted { $0.recordedAt > $1.recordedAt }
                    .first?.recordedAt
                let freshness = freshnessState(latestReviewAt: [latestDaily, latestWeekly].compactMap { $0 }.max())
                let nextScheduledReviewAt = nextScheduledReviewAt(
                    for: base,
                    latestDailyReviewAt: latestDaily,
                    latestWeeklyReviewAt: latestWeekly
                )
                let status: BurnBarReviewProjectStatus
                if base.status == .paused {
                    status = .paused
                } else if freshness == .stale {
                    status = .stale
                } else if pendingQuestions > 0 || openFollowups > 0 || activeMissions.count > 0 {
                    status = .needsAttention
                } else {
                    status = base.status == .onboarding ? .onboarding : .healthy
                }
                return BurnBarReviewProjectSnapshot(
                    id: base.id,
                    projectSlug: base.projectSlug,
                    displayName: base.displayName,
                    summary: base.summary,
                    status: status,
                    preferredCadence: base.preferredCadence,
                    aliases: base.aliases,
                    automationMode: base.automationMode,
                    reviewModelID: base.reviewModelID,
                    scheduleHourLocal: base.scheduleHourLocal,
                    scheduleWeekdayLocal: base.scheduleWeekdayLocal,
                    freshness: freshness,
                    latestDailyReviewAt: latestDaily,
                    latestWeeklyReviewAt: latestWeekly,
                    nextScheduledReviewAt: nextScheduledReviewAt,
                    pendingQuestionCount: pendingQuestions,
                    openFollowupCount: openFollowups,
                    activeMissionCount: activeMissions.count,
                    activeMissionID: activeMissions.sorted { $0.updatedAt > $1.updatedAt }.first?.id,
                    needsOperatorAttention: pendingQuestions > 0 || openFollowups > 0 || activeMissions.count > 0,
                    ingestionSource: base.ingestionSource,
                    metadata: base.metadata
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func makeSummary(for request: BurnBarControllerSummaryRequest) -> BurnBarControllerSummary {
        let projects = enrichedProjects().filter { request.projectSlug == nil || $0.projectSlug == request.projectSlug }
        let pendingQuestions = projection?.questions.values.filter {
            (request.projectSlug == nil || $0.projectSlug == request.projectSlug) && $0.status == .pending
        }.count ?? 0
        let openFollowups = projection?.followups.values.filter {
            (request.projectSlug == nil || $0.projectSlug == request.projectSlug) && $0.status == .open
        }.count ?? 0
        let activeMissions = projection?.missions.values.filter {
            (request.projectSlug == nil || $0.projectSlug == request.projectSlug)
                && ![BurnBarMissionStatus.completed, .failed, .cancelled].contains($0.status)
        }.count ?? 0
        let latestReviewAt = projects
            .flatMap { [$0.latestDailyReviewAt, $0.latestWeeklyReviewAt] }
            .compactMap { $0 }
            .max()
        let freshness = freshnessState(latestReviewAt: latestReviewAt)
        let recentEvents = request.includeRecentEvents
            ? (cachedEvents ?? [])
                .filter { request.projectSlug == nil || $0.projectSlug == request.projectSlug }
                .sorted(by: { lhs, rhs in
                    if lhs.sequence == rhs.sequence {
                        return lhs.recordedAt > rhs.recordedAt
                    }
                    return lhs.sequence > rhs.sequence
                })
                .prefix(20)
                .map { $0 }
            : []
        let projectionStatus = request.includeProjectionStatus
            ? projectionStatusArray(sortedBySequence: projection?.lastSequence ?? 0, recordedAt: projection?.rebuiltAt ?? Date())
            : []

        return BurnBarControllerSummary(
            updatedAt: projection?.rebuiltAt ?? Date(),
            activeProjectSlug: request.projectSlug ?? projects.first?.projectSlug,
            counts: BurnBarControllerCounts(
                projectCount: projects.count,
                pendingQuestionCount: pendingQuestions,
                openFollowupCount: openFollowups,
                activeMissionCount: activeMissions,
                staleProjectCount: projects.filter { $0.status == .stale }.count
            ),
            nextSuggestedCadence: nextSuggestedCadence(from: projects),
            latestReviewAt: latestReviewAt,
            freshness: freshness,
            projectionStatus: projectionStatus,
            recentEvents: recentEvents
        )
    }

    private func makeNotificationHealth() -> BurnBarNotificationHealthSnapshot {
        let config = projection?.notificationConfig ?? BurnBarMissionControlProjectionFile.defaultNotificationConfig()
        let now = Date()
        let localError = projection?.transportErrors[BurnBarNotificationChannel.local.rawValue]
        let telegramError = projection?.transportErrors[BurnBarNotificationChannel.telegram.rawValue]
        let calendarError = projection?.transportErrors[BurnBarNotificationChannel.calendar.rawValue]

        let local = BurnBarNotificationChannelHealth(
            channel: .local,
            status: config.local.isEnabled ? (localError == nil ? .healthy : .degraded) : .disabled,
            detail: config.local.isEnabled
                ? (localError ?? "Local notifications can nudge due followups.")
                : "Local notifications are turned off.",
            checkedAt: now
        )
        let telegramConfigured = ((config.telegram.botToken?.isEmpty == false) || config.telegram.botTokenConfigured)
            && config.telegram.chatID?.isEmpty == false
        let telegram = BurnBarNotificationChannelHealth(
            channel: .telegram,
            status: config.telegram.isEnabled
                ? (telegramConfigured ? (telegramError == nil ? .healthy : .degraded) : .unauthorized)
                : .disabled,
            detail: config.telegram.isEnabled
                ? (telegramConfigured ? (telegramError ?? "Telegram bot is configured.") : "Telegram needs a bot token and chat ID.")
                : "Telegram delivery is turned off.",
            checkedAt: now
        )
        let calendar = BurnBarNotificationChannelHealth(
            channel: .calendar,
            status: config.calendar.isEnabled ? (calendarError == nil ? .healthy : .degraded) : .disabled,
            detail: config.calendar.isEnabled
                ? (calendarError ?? "Calendar holds can be created from followups.")
                : "Calendar integration is off.",
            checkedAt: now
        )

        return BurnBarNotificationHealthSnapshot(
            checkedAt: now,
            channels: [local, telegram, calendar]
        )
    }

    private func projectionStatusArray(
        sortedBySequence eventSequence: Int,
        recordedAt: Date
    ) -> [BurnBarProjectionStatusSnapshot] {
        let statuses = projection?.projectionStatus.isEmpty == false
            ? projection?.projectionStatus ?? [:]
            : BurnBarMissionControlProjectionFile.defaultProjectionStatus(
                eventSequence: eventSequence,
                recordedAt: recordedAt
            )
        return statuses.values.sorted { $0.projectionName < $1.projectionName }
    }

    private func freshnessState(latestReviewAt: Date?) -> BurnBarControllerFreshnessState {
        guard let latestReviewAt else {
            return (projection?.projects.isEmpty ?? true) ? .missing : .provisional
        }

        let age = Date().timeIntervalSince(latestReviewAt)
        if age < Double(12 * 60 * 60) {
            return .fresh
        }
        if age < Double(48 * 60 * 60) {
            return .aging
        }
        return .stale
    }

    private func nextSuggestedCadence(from projects: [BurnBarReviewProjectSnapshot]) -> BurnBarControllerReviewCadence? {
        if projects.isEmpty {
            return nil
        }
        if projects.contains(where: { $0.preferredCadence == .daily && ($0.latestDailyReviewAt ?? .distantPast) < Date().addingTimeInterval(-24 * 60 * 60) }) {
            return .daily
        }
        if projects.contains(where: { $0.preferredCadence == .weekly && ($0.latestWeeklyReviewAt ?? .distantPast) < Date().addingTimeInterval(-7 * 24 * 60 * 60) }) {
            return .weekly
        }
        return projects.first?.preferredCadence
    }

    private func nextScheduledReviewAt(
        for project: BurnBarReviewProjectSnapshot,
        latestDailyReviewAt: Date?,
        latestWeeklyReviewAt: Date?
    ) -> Date? {
        guard project.automationMode == .scheduled else {
            return nil
        }

        let calendar = Calendar.current
        let hour = project.scheduleHourLocal ?? 9
        let reference = project.preferredCadence == .daily ? latestDailyReviewAt : latestWeeklyReviewAt
        let base = reference ?? Date()

        switch project.preferredCadence {
        case .daily, .adHoc:
            let startOfDay = calendar.startOfDay(for: base)
            let scheduledToday = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startOfDay) ?? startOfDay
            if reference == nil {
                return scheduledToday
            }
            return calendar.date(byAdding: .day, value: 1, to: scheduledToday)
        case .weekly:
            let weekday = project.scheduleWeekdayLocal ?? 2
            let nextDate = calendar.nextDate(
                after: base.addingTimeInterval(60),
                matching: DateComponents(hour: hour, minute: 0, weekday: weekday),
                matchingPolicy: .nextTime,
                direction: .forward
            )
            return nextDate
        }
    }

    private func defaultSimulatorEvents(
        for request: BurnBarSimulatorRunRequest,
        now: Date
    ) throws -> [BurnBarControllerEvent] {
        let project = BurnBarReviewProjectSnapshot(
            id: "project-\(request.projectSlug)",
            projectSlug: request.projectSlug,
            displayName: request.projectSlug.capitalized,
            summary: "Simulated controller project for \(request.scenarioName).",
            status: .needsAttention,
            preferredCadence: .daily,
            freshness: .provisional,
            pendingQuestionCount: 1,
            openFollowupCount: 1,
            activeMissionCount: 1,
            needsOperatorAttention: true,
            metadata: request.metadata
        )
        let question = BurnBarPendingQuestionSnapshot(
            id: BurnBarQuestionID(rawValue: "question-\(request.seed)"),
            projectSlug: request.projectSlug,
            title: "What should happen next?",
            prompt: "Scenario \(request.scenarioName) generated a pending operator question.",
            status: .pending,
            priority: .medium,
            askedAt: now,
            dueAt: now.addingTimeInterval(3600),
            contextSummary: "Generated from the deterministic simulator.",
            metadata: request.metadata
        )
        let mission = BurnBarMissionSnapshot(
            id: BurnBarMissionID(rawValue: "mission-\(request.seed)"),
            projectSlug: request.projectSlug,
            title: "Simulated mission",
            summary: "Exercise replay, followups, and operator review state.",
            status: .awaitingApproval,
            recommendation: .review,
            createdAt: now,
            updatedAt: now,
            approval: BurnBarMissionApprovalSnapshot(approved: false),
            metadata: request.metadata
        )

        let payloads: [(BurnBarControllerEventFamily, String, String, String?, BurnBarJSONValue)] = [
            (.controller, "project_upserted", project.displayName, project.summary, try BurnBarJSONValue.fromEncodable(project)),
            (.question, "question_created", question.title, question.prompt, try BurnBarJSONValue.fromEncodable(question)),
            (.mission, "mission_created", mission.title, mission.summary, try BurnBarJSONValue.fromEncodable(mission))
        ]

        return payloads.enumerated().map { index, item in
            BurnBarControllerEvent(
                id: BurnBarControllerEventID(rawValue: "sim-event-\(request.seed)-\(index)"),
                family: item.0,
                eventType: item.1,
                projectSlug: request.projectSlug,
                recordedAt: now.addingTimeInterval(Double(index)),
                sequence: index + 1,
                summary: item.2,
                detail: item.3,
                metadata: ["payload": item.4],
                isReplay: false
            )
        }
    }

    private func missionStatus(for resultStatus: BurnBarMissionResultStatus) -> BurnBarMissionStatus {
        switch resultStatus {
        case .succeeded, .replayed:
            return .completed
        case .partial:
            return .partiallyCompleted
        case .failed:
            return .failed
        }
    }

    private func mergePackets(
        _ existing: [BurnBarMissionPacketSnapshot],
        _ appended: BurnBarMissionPacketSnapshot
    ) -> [BurnBarMissionPacketSnapshot] {
        var merged: [String: BurnBarMissionPacketSnapshot] = [:]
        for packet in existing {
            merged[packet.id.rawValue] = packet
        }
        merged[appended.id.rawValue] = appended
        return merged.values.sorted {
            ($0.dispatchedAt ?? .distantPast) < ($1.dispatchedAt ?? .distantPast)
        }
    }

    private func mergeResults(
        _ existing: [BurnBarMissionResultSnapshot],
        _ appended: BurnBarMissionResultSnapshot
    ) -> [BurnBarMissionResultSnapshot] {
        var merged: [String: BurnBarMissionResultSnapshot] = [:]
        for result in existing {
            merged[result.id.rawValue] = result
        }
        merged[appended.id.rawValue] = appended
        return merged.values.sorted { $0.createdAt < $1.createdAt }
    }

    private func mergeBurnRecords(
        _ existing: [BurnBarMissionBurnRecord],
        _ appended: BurnBarMissionBurnRecord
    ) -> [BurnBarMissionBurnRecord] {
        var merged: [String: BurnBarMissionBurnRecord] = [:]
        for record in existing {
            merged[record.id] = record
        }
        merged[appended.id] = appended
        return merged.values.sorted { $0.recordedAt < $1.recordedAt }
    }

    private func eventSort(lhs: BurnBarControllerEvent, rhs: BurnBarControllerEvent) -> Bool {
        if lhs.sequence == rhs.sequence {
            return lhs.recordedAt < rhs.recordedAt
        }
        return lhs.sequence < rhs.sequence
    }
}
