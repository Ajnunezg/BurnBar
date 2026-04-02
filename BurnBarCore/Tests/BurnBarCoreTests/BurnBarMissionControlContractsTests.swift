import XCTest
@testable import BurnBarCore

final class BurnBarMissionControlContractsTests: XCTestCase {
    func testRPCMethods_includeMissionControlSurface() {
        XCTAssertEqual(BurnBarRPCMethod.controllerSummary.rawValue, "daemon.controller.summary")
        XCTAssertEqual(BurnBarRPCMethod.controllerProjectsList.rawValue, "daemon.controller.project.list")
        XCTAssertEqual(BurnBarRPCMethod.controllerProjectGet.rawValue, "daemon.controller.project.get")
        XCTAssertEqual(BurnBarRPCMethod.questionAnswer.rawValue, "daemon.question.answer")
        XCTAssertEqual(BurnBarRPCMethod.followupCalendar.rawValue, "daemon.followup.calendar")
        XCTAssertEqual(BurnBarRPCMethod.missionDispatchPacket.rawValue, "daemon.mission.packet.dispatch")
        XCTAssertEqual(BurnBarRPCMethod.simulatorReplay.rawValue, "daemon.simulator.replay")
        XCTAssertEqual(BurnBarRPCMethod.notificationConfigUpdate.rawValue, "daemon.notification.config.update")
        XCTAssertEqual(BurnBarRPCMethod.notificationHealth.rawValue, "daemon.notification.health")
        XCTAssertEqual(BurnBarRPCMethod.projectionRebuild.rawValue, "daemon.projection.rebuild")
    }

    func testControllerSummaryRoundTrip_includesEventsAndProjections() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let checkpoint = BurnBarReplayCheckpoint(
            id: BurnBarProjectionCheckpointID(rawValue: "checkpoint-1"),
            projectionName: "conversation_home",
            eventSequence: 42,
            recordedAt: now
        )
        let projection = BurnBarProjectionStatusSnapshot(
            projectionName: "conversation_home",
            status: .upToDate,
            freshness: .fresh,
            lastMaterializedAt: now,
            lastEventSequence: 42,
            checkpoint: checkpoint
        )
        let event = BurnBarControllerEvent(
            id: BurnBarControllerEventID(rawValue: "event-1"),
            family: .controller,
            eventType: "review_run_completed",
            projectSlug: "burnbar",
            recordedAt: now,
            sequence: 42,
            summary: "Daily review completed",
            metadata: ["cadence": .string("daily")]
        )
        let response = BurnBarControllerSummaryResponse(
            summary: BurnBarControllerSummary(
                updatedAt: now,
                activeProjectSlug: "burnbar",
                counts: BurnBarControllerCounts(
                    projectCount: 3,
                    pendingQuestionCount: 2,
                    openFollowupCount: 4,
                    activeMissionCount: 1,
                    staleProjectCount: 1
                ),
                nextSuggestedCadence: .daily,
                latestReviewAt: now,
                freshness: .fresh,
                projectionStatus: [projection],
                recentEvents: [event]
            )
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(BurnBarControllerSummaryResponse.self, from: data)

        XCTAssertEqual(decoded.summary.counts.pendingQuestionCount, 2)
        XCTAssertEqual(decoded.summary.projectionStatus.first?.checkpoint?.eventSequence, 42)
        XCTAssertEqual(decoded.summary.recentEvents.first?.metadata["cadence"], .string("daily"))
    }

    func testProjectAndReviewRunContracts_roundTrip() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_050)
        let project = BurnBarReviewProjectSnapshot(
            id: "project-1",
            projectSlug: "burnbar",
            displayName: "BurnBar",
            summary: "Primary product repo",
            status: .needsAttention,
            preferredCadence: .daily,
            aliases: ["burn-bar", "bb"],
            automationMode: .scheduled,
            reviewModelID: "glm-5",
            scheduleHourLocal: 9,
            scheduleWeekdayLocal: 2,
            freshness: .aging,
            latestDailyReviewAt: now,
            latestWeeklyReviewAt: now,
            nextScheduledReviewAt: now.addingTimeInterval(86_400),
            pendingQuestionCount: 2,
            openFollowupCount: 1,
            activeMissionCount: 1,
            activeMissionID: BurnBarMissionID(rawValue: "mission-1"),
            needsOperatorAttention: true,
            ingestionSource: .appActivity
        )
        let run = BurnBarReviewRunSnapshot(
            id: "run-1",
            projectSlug: "burnbar",
            cadence: .daily,
            recordedAt: now,
            summary: "Queued one question and one mission.",
            questionCount: 1,
            followupCount: 1,
            missionCount: 1,
            origin: .dashboard,
            triggeredBy: "operator",
            launchedRunID: BurnBarRunID(rawValue: "run-live-1")
        )
        let response = BurnBarControllerReviewRunRecordResponse(
            run: run,
            summary: BurnBarControllerSummary(
                updatedAt: now,
                activeProjectSlug: "burnbar",
                counts: BurnBarControllerCounts(
                    projectCount: 1,
                    pendingQuestionCount: 1,
                    openFollowupCount: 1,
                    activeMissionCount: 1,
                    staleProjectCount: 0
                ),
                nextSuggestedCadence: .weekly,
                latestReviewAt: now,
                freshness: .aging
            )
        )

        let projectData = try JSONEncoder().encode(BurnBarControllerProjectResponse(project: project))
        let runData = try JSONEncoder().encode(response)

        let decodedProject = try JSONDecoder().decode(BurnBarControllerProjectResponse.self, from: projectData)
        let decodedRun = try JSONDecoder().decode(BurnBarControllerReviewRunRecordResponse.self, from: runData)

        XCTAssertEqual(decodedProject.project?.status, .needsAttention)
        XCTAssertEqual(decodedProject.project?.activeMissionID, BurnBarMissionID(rawValue: "mission-1"))
        XCTAssertEqual(decodedProject.project?.aliases, ["burn-bar", "bb"])
        XCTAssertEqual(decodedProject.project?.automationMode, .scheduled)
        XCTAssertEqual(decodedProject.project?.reviewModelID, "glm-5")
        XCTAssertEqual(decodedProject.project?.scheduleHourLocal, 9)
        XCTAssertEqual(decodedProject.project?.scheduleWeekdayLocal, 2)
        XCTAssertEqual(decodedProject.project?.ingestionSource, .appActivity)
        XCTAssertEqual(decodedRun.run.cadence, .daily)
        XCTAssertEqual(decodedRun.run.origin, .dashboard)
        XCTAssertEqual(decodedRun.run.triggeredBy, "operator")
        XCTAssertEqual(decodedRun.run.launchedRunID, BurnBarRunID(rawValue: "run-live-1"))
        XCTAssertEqual(decodedRun.summary.counts.openFollowupCount, 1)
    }

    func testLegacyProjectAndReviewRunPayloads_decodeWithWaveOneDefaults() throws {
        let legacyProjectData = """
        {
          "project": {
            "id": "project-legacy",
            "projectSlug": "burnbar",
            "displayName": "BurnBar",
            "summary": "Legacy payload",
            "status": "healthy",
            "preferredCadence": "daily",
            "freshness": "fresh",
            "pendingQuestionCount": 0,
            "openFollowupCount": 0,
            "activeMissionCount": 0,
            "needsOperatorAttention": false,
            "metadata": {}
          }
        }
        """.data(using: .utf8)!
        let legacyRunData = """
        {
          "run": {
            "id": "run-legacy",
            "projectSlug": "burnbar",
            "cadence": "weekly",
            "recordedAt": 1710000050,
            "summary": "Legacy review",
            "questionCount": 0,
            "followupCount": 0,
            "missionCount": 0,
            "metadata": {}
          },
          "summary": {
            "updatedAt": 1710000050,
            "activeProjectSlug": "burnbar",
            "counts": {
              "projectCount": 1,
              "pendingQuestionCount": 0,
              "openFollowupCount": 0,
              "activeMissionCount": 0,
              "staleProjectCount": 0
            },
            "freshness": "fresh",
            "projectionStatus": [],
            "recentEvents": []
          }
        }
        """.data(using: .utf8)!

        let decodedProject = try JSONDecoder().decode(BurnBarControllerProjectResponse.self, from: legacyProjectData)
        let decodedRun = try JSONDecoder().decode(BurnBarControllerReviewRunRecordResponse.self, from: legacyRunData)

        XCTAssertEqual(decodedProject.project?.aliases, [])
        XCTAssertEqual(decodedProject.project?.automationMode, .manual)
        XCTAssertNil(decodedProject.project?.reviewModelID)
        XCTAssertEqual(decodedProject.project?.ingestionSource, .manual)
        XCTAssertEqual(decodedRun.run.origin, .manual)
        XCTAssertNil(decodedRun.run.triggeredBy)
        XCTAssertNil(decodedRun.run.launchedRunID)
    }

    func testQuestionAndFollowupRoundTrip_preservesAnswerAndCalendarData() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_100)
        let questionID = BurnBarQuestionID(rawValue: "question-1")
        let followupID = BurnBarFollowupID(rawValue: "followup-1")
        let question = BurnBarPendingQuestionSnapshot(
            id: questionID,
            projectSlug: "burnbar",
            sessionID: BurnBarSessionID(rawValue: "session-1"),
            title: "Approve burn delta?",
            prompt: "Is the increased burn intentional?",
            stageLabel: "Operator Decision",
            status: .answered,
            priority: .high,
            askedAt: now,
            dueAt: now.addingTimeInterval(3_600),
            latestAnswer: BurnBarAnswerRecord(
                answeredAt: now.addingTimeInterval(120),
                answeredBy: "operator",
                answer: "Yes, this is expected during rollout.",
                selectedOptionID: "proceed"
            ),
            answerPlaceholder: "Record BurnBar's operator call…",
            contextSummary: "Burn spiked after deployment.",
            evidenceRefs: ["event-42"],
            suggestedOptions: [
                BurnBarQuestionOptionSnapshot(
                    id: "proceed",
                    title: "Proceed",
                    detail: "Keep the current rollout moving.",
                    answer: "Proceed with the rollout."
                ),
                BurnBarQuestionOptionSnapshot(
                    id: "pause",
                    title: "Pause",
                    detail: "Reset direction before continuing.",
                    answer: "Pause and reset the rollout."
                )
            ],
            deepLink: BurnBarQuestionDeepLinkSnapshot(
                kind: .sessionLog,
                targetID: "session-1",
                title: "Open rollout session log",
                subtitle: "Review the latest checkpoint"
            ),
            tracker: BurnBarQuestionTrackerSnapshot(
                isUnread: true,
                surfacedAt: now,
                firstNotifiedAt: now,
                lastNotifiedAt: now,
                notificationCount: 1
            )
        )
        let followup = BurnBarFollowupSnapshot(
            id: followupID,
            projectSlug: "burnbar",
            questionID: questionID,
            title: "Confirm rollout notes",
            summary: "Attach operator rationale to the mission log.",
            stageLabel: "Operator Decision",
            status: .snoozed,
            kind: .pendingQuestion,
            createdAt: now,
            nextNudgeAt: now.addingTimeInterval(7_200),
            snoozeUntil: now.addingTimeInterval(10_800),
            calendarEntry: BurnBarCalendarEntrySnapshot(
                externalID: "cal-1",
                title: "Review rollout notes",
                startAt: now.addingTimeInterval(3_600),
                endAt: now.addingTimeInterval(5_400),
                notes: "Bring deployment metrics."
            ),
            deepLink: BurnBarQuestionDeepLinkSnapshot(
                kind: .sessionLog,
                targetID: "session-1",
                title: "Open rollout session log"
            )
        )
        let response = BurnBarQuestionAnswerResponse(question: question, followup: followup)

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(BurnBarQuestionAnswerResponse.self, from: data)

        XCTAssertEqual(decoded.question.latestAnswer?.answeredBy, "operator")
        XCTAssertEqual(decoded.question.latestAnswer?.selectedOptionID, "proceed")
        XCTAssertEqual(decoded.question.stageLabel, "Operator Decision")
        XCTAssertEqual(decoded.question.answerPlaceholder, "Record BurnBar's operator call…")
        XCTAssertEqual(decoded.question.suggestedOptions.count, 2)
        XCTAssertEqual(decoded.question.deepLink?.kind, .sessionLog)
        XCTAssertEqual(decoded.question.tracker?.notificationCount, 1)
        XCTAssertEqual(decoded.followup?.questionID, questionID)
        XCTAssertEqual(decoded.followup?.status, .snoozed)
        XCTAssertEqual(decoded.followup?.calendarEntry?.externalID, "cal-1")
        XCTAssertEqual(decoded.followup?.stageLabel, "Operator Decision")
        XCTAssertEqual(decoded.followup?.deepLink?.targetID, "session-1")
    }

    func testLegacyQuestionPayload_decodesWithWaveTwoDefaults() throws {
        let legacyQuestionData = """
        {
          "question": {
            "id": "question-legacy",
            "projectSlug": "burnbar",
            "sessionID": "session-legacy",
            "title": "Legacy",
            "prompt": "Should BurnBar keep the current scope?",
            "status": "pending",
            "priority": "medium",
            "askedAt": 1710000100,
            "evidenceRefs": [],
            "metadata": {}
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(BurnBarQuestionResponse.self, from: legacyQuestionData)

        XCTAssertNil(decoded.question?.stageLabel)
        XCTAssertNil(decoded.question?.answerPlaceholder)
        XCTAssertEqual(decoded.question?.suggestedOptions, [])
        XCTAssertNil(decoded.question?.deepLink)
        XCTAssertNil(decoded.question?.tracker)
    }

    func testMissionMutationRoundTrip_preservesPacketsResultsAndBurn() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_200)
        let missionID = BurnBarMissionID(rawValue: "mission-1")
        let packet = BurnBarMissionPacketSnapshot(
            id: BurnBarMissionPacketID(rawValue: "packet-1"),
            missionID: missionID,
            workerName: "planner",
            objective: "Draft operator plan",
            status: .completed,
            runID: BurnBarRunID(rawValue: "run-1"),
            dispatchedAt: now,
            completedAt: now.addingTimeInterval(30)
        )
        let result = BurnBarMissionResultSnapshot(
            id: BurnBarMissionResultID(rawValue: "result-1"),
            missionID: missionID,
            packetID: packet.id,
            runID: BurnBarRunID(rawValue: "run-1"),
            status: .partial,
            summary: "Plan drafted with one unresolved dependency.",
            detail: "Waiting on provider quota confirmation.",
            burnDelta: 2.5,
            createdAt: now.addingTimeInterval(30),
            evidenceRefs: ["event-99"]
        )
        let mission = BurnBarMissionSnapshot(
            id: missionID,
            projectSlug: "burnbar",
            title: "Stabilize review controller",
            summary: "Move pending work into daemon-owned mission control.",
            status: .partiallyCompleted,
            recommendation: .review,
            createdAt: now,
            updatedAt: now.addingTimeInterval(30),
            approval: BurnBarMissionApprovalSnapshot(
                approved: true,
                approvedAt: now.addingTimeInterval(5),
                approvedBy: "dewclaw",
                note: "Proceed, but keep rollout observable."
            ),
            packets: [packet],
            results: [result],
            burnRecords: [
                BurnBarMissionBurnRecord(
                    id: "burn-1",
                    label: "Operator review",
                    amount: 2.5,
                    unit: "points",
                    recordedAt: now.addingTimeInterval(30)
                )
            ],
            takeoverHistory: [
                BurnBarAutoTakeoverRecord(
                    id: "takeover-1",
                    projectSlug: "burnbar",
                    missionID: missionID,
                    sourceRunID: BurnBarRunID(rawValue: "run-stuck"),
                    takeoverRunID: BurnBarRunID(rawValue: "run-1"),
                    status: .completed,
                    reason: "Original run stalled in awaiting approval.",
                    createdAt: now.addingTimeInterval(10),
                    updatedAt: now.addingTimeInterval(30)
                )
            ],
            metadata: ["cadence": .string("daily")]
        )
        let response = BurnBarMissionMutationResponse(
            mission: mission,
            emittedEvent: BurnBarControllerEvent(
                id: BurnBarControllerEventID(rawValue: "event-2"),
                family: .mission,
                eventType: "mission_result_recorded",
                projectSlug: "burnbar",
                recordedAt: now.addingTimeInterval(30),
                sequence: 100,
                summary: "Mission result recorded"
            )
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(BurnBarMissionMutationResponse.self, from: data)

        XCTAssertEqual(decoded.mission.status, .partiallyCompleted)
        XCTAssertEqual(decoded.mission.packets.first?.runID, BurnBarRunID(rawValue: "run-1"))
        XCTAssertEqual(decoded.mission.packets.first?.workerName, "planner")
        XCTAssertEqual(decoded.mission.results.first?.runID, BurnBarRunID(rawValue: "run-1"))
        XCTAssertEqual(decoded.mission.results.first?.burnDelta, 2.5)
        XCTAssertEqual(decoded.mission.takeoverHistory?.first?.status, .completed)
        XCTAssertEqual(decoded.emittedEvent?.family, .mission)
    }

    func testNotificationAndSimulatorContracts_roundTrip() throws {
        let config = BurnBarNotificationConfig(
            defaultSnoozeMinutes: 90,
            nudgeHoursLocal: [9, 13, 17],
            local: BurnBarLocalNotificationConfig(isEnabled: true, quietHoursStart: 22, quietHoursEnd: 7),
            telegram: BurnBarTelegramNotificationConfig(
                isEnabled: true,
                botTokenConfigured: true,
                botToken: "123456:secret-token",
                botTokenHint: "1234…abcd",
                chatID: "chat-1",
                supportedCommands: [.help, .pending, .answer, .runDaily]
            ),
            calendar: BurnBarCalendarNotificationConfig(
                isEnabled: true,
                defaultDurationMinutes: 30,
                defaultCalendarName: "BurnBar Ops"
            )
        )
        let health = BurnBarNotificationHealthResponse(
            health: BurnBarNotificationHealthSnapshot(
                checkedAt: Date(timeIntervalSince1970: 1_710_000_300),
                channels: [
                    BurnBarNotificationChannelHealth(
                        channel: .telegram,
                        status: .healthy,
                        detail: "Webhook responding",
                        checkedAt: Date(timeIntervalSince1970: 1_710_000_300)
                    )
                ]
            )
        )
        let command = BurnBarNotificationCommandResponse(
            command: .pending,
            ok: true,
            message: "1 pending question, 2 open followups."
        )
        let now = Date(timeIntervalSince1970: 1_710_000_400)
        let simEvent = BurnBarControllerEvent(
            id: BurnBarControllerEventID(rawValue: "event-3"),
            family: .simulator,
            eventType: "scenario_step",
            projectSlug: "burnbar",
            recordedAt: now,
            sequence: 5,
            summary: "Injected a duplicate event",
            isReplay: true
        )
        let simulator = BurnBarSimulatorRunResponse(
            run: BurnBarSimulatorRunSnapshot(
                id: BurnBarSimulatorRunID(rawValue: "sim-1"),
                projectSlug: "burnbar",
                scenarioName: "duplicate-events",
                status: .completed,
                seed: 7,
                startedAt: now,
                completedAt: now.addingTimeInterval(3),
                emittedEvents: [simEvent],
                projectionStatus: [
                    BurnBarProjectionStatusSnapshot(
                        projectionName: "controller_summary",
                        status: .rebuilding,
                        freshness: .provisional,
                        lastMaterializedAt: nil,
                        lastEventSequence: 5,
                        checkpoint: BurnBarReplayCheckpoint(
                            id: BurnBarProjectionCheckpointID(rawValue: "checkpoint-2"),
                            projectionName: "controller_summary",
                            eventSequence: 5,
                            recordedAt: now.addingTimeInterval(3)
                        )
                    )
                ],
                summary: "Replay completed with duplicate/out-of-order coverage."
            )
        )

        let configData = try JSONEncoder().encode(BurnBarNotificationConfigResponse(config: config))
        let healthData = try JSONEncoder().encode(health)
        let commandData = try JSONEncoder().encode(command)
        let simulatorData = try JSONEncoder().encode(simulator)

        let decodedConfig = try JSONDecoder().decode(BurnBarNotificationConfigResponse.self, from: configData)
        let decodedHealth = try JSONDecoder().decode(BurnBarNotificationHealthResponse.self, from: healthData)
        let decodedCommand = try JSONDecoder().decode(BurnBarNotificationCommandResponse.self, from: commandData)
        let decodedSimulator = try JSONDecoder().decode(BurnBarSimulatorRunResponse.self, from: simulatorData)

        XCTAssertEqual(decodedConfig.config.telegram.supportedCommands, [.help, .pending, .answer, .runDaily])
        XCTAssertEqual(decodedConfig.config.telegram.botToken, "123456:secret-token")
        XCTAssertEqual(decodedHealth.health.channels.first?.status, .healthy)
        XCTAssertEqual(decodedCommand.command, .pending)
        XCTAssertEqual(decodedSimulator.run.emittedEvents.first?.isReplay, true)
        XCTAssertEqual(decodedSimulator.run.projectionStatus.first?.status, .rebuilding)
    }

    func testControllerActivitySnapshot_roundTripsProjectActivityShape() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_900)
        let snapshot = BurnBarControllerActivitySnapshot(
            generatedAt: now,
            activeProjectSlug: "burnbar",
            projects: [
                BurnBarControllerActivityProject(
                    projectSlug: "burnbar",
                    displayName: "BurnBar",
                    summary: "Latest indexed checkpoint looks healthy.",
                    latestActivityAt: now,
                    latestConversationID: "conversation-1",
                    latestConversationSessionID: BurnBarSessionID(rawValue: "session-1"),
                    latestConversationTitle: "Checkpoint summary",
                    latestConversationSummary: "Shipped the daemon-backed path.",
                    latestQuestionPrompt: "Should BurnBar keep the current review cadence?",
                    sessionCountLast7Days: 4,
                    totalCostLast7Days: 5.25,
                    totalTokensLast7Days: 12_500,
                    aliases: ["bb"],
                    preferredCadence: .daily,
                    automationMode: .scheduled,
                    reviewModelID: "glm-5",
                    scheduleHourLocal: 9,
                    scheduleWeekdayLocal: 2
                )
            ]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(BurnBarControllerActivitySnapshot.self, from: data)

        XCTAssertEqual(decoded.activeProjectSlug, "burnbar")
        XCTAssertEqual(decoded.projects.first?.latestConversationSessionID, BurnBarSessionID(rawValue: "session-1"))
        XCTAssertEqual(decoded.projects.first?.automationMode, .scheduled)
        XCTAssertEqual(decoded.projects.first?.reviewModelID, "glm-5")
    }
}
