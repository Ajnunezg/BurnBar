import Foundation

extension BurnBarOperatingLayer {
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
}
