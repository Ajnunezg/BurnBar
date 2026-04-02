import BurnBarCore
import Darwin
import Foundation

public protocol BurnBarCLIClient: Sendable {
    func health() throws -> BurnBarHealthResponse
    func controllerSummary(projectSlug: String?) throws -> BurnBarControllerSummary
    func questions(projectSlug: String?) throws -> [BurnBarPendingQuestionSnapshot]
    func followups(projectSlug: String?) throws -> [BurnBarFollowupSnapshot]
    func missions(projectSlug: String?) throws -> [BurnBarMissionSnapshot]
    func approveMission(id: BurnBarMissionID, note: String?) throws -> BurnBarMissionSnapshot
    func simulatorRuns(projectSlug: String?) throws -> [BurnBarSimulatorRunSnapshot]
    func simulatorReplay(runID: BurnBarSimulatorRunID) throws -> BurnBarSimulatorRunSnapshot
}

public struct BurnBarCLISocketClient: BurnBarCLIClient, Sendable {
    public let socketURL: URL

    public init(socketURL: URL = BurnBarDaemonPaths.defaultSocketURL) {
        self.socketURL = socketURL
    }

    public func health() throws -> BurnBarHealthResponse {
        let envelope: BurnBarRPCResponseEnvelope<BurnBarHealthResponse> = try send(
            BurnBarRPCRequestEnvelope(method: .health)
        )
        return try unwrap(envelope)
    }

    public func controllerSummary(projectSlug: String?) throws -> BurnBarControllerSummary {
        let response: BurnBarControllerSummaryResponse = try requestResult(
            BurnBarRPCRequestEnvelopeWithParams(
                method: .controllerSummary,
                params: BurnBarControllerSummaryRequest(projectSlug: projectSlug)
            )
        )
        return response.summary
    }

    public func questions(projectSlug: String?) throws -> [BurnBarPendingQuestionSnapshot] {
        let response: BurnBarQuestionsListResponse = try requestResult(
            BurnBarRPCRequestEnvelopeWithParams(
                method: .questionsList,
                params: BurnBarQuestionsListRequest(
                    projectSlug: projectSlug,
                    statuses: BurnBarPendingQuestionStatus.allCases,
                    limit: 100
                )
            )
        )
        return response.questions
    }

    public func followups(projectSlug: String?) throws -> [BurnBarFollowupSnapshot] {
        let response: BurnBarFollowupsListResponse = try requestResult(
            BurnBarRPCRequestEnvelopeWithParams(
                method: .followupsList,
                params: BurnBarFollowupsListRequest(
                    projectSlug: projectSlug,
                    statuses: BurnBarFollowupStatus.allCases,
                    limit: 100
                )
            )
        )
        return response.followups
    }

    public func missions(projectSlug: String?) throws -> [BurnBarMissionSnapshot] {
        let response: BurnBarMissionListResponse = try requestResult(
            BurnBarRPCRequestEnvelopeWithParams(
                method: .missionsList,
                params: BurnBarMissionListRequest(
                    projectSlug: projectSlug,
                    statuses: BurnBarMissionStatus.allCases,
                    limit: 100
                )
            )
        )
        return response.missions
    }

    public func approveMission(id: BurnBarMissionID, note: String?) throws -> BurnBarMissionSnapshot {
        let response: BurnBarMissionMutationResponse = try requestResult(
            BurnBarRPCRequestEnvelopeWithParams(
                method: .missionApprove,
                params: BurnBarMissionApproveRequest(
                    missionID: id,
                    actor: "burnbar-cli",
                    note: note
                )
            )
        )
        return response.mission
    }

    public func simulatorRuns(projectSlug: String?) throws -> [BurnBarSimulatorRunSnapshot] {
        let response: BurnBarSimulatorListResponse = try requestResult(
            BurnBarRPCRequestEnvelopeWithParams(
                method: .simulatorList,
                params: BurnBarSimulatorListRequest(projectSlug: projectSlug, limit: 100)
            )
        )
        return response.runs
    }

    public func simulatorReplay(runID: BurnBarSimulatorRunID) throws -> BurnBarSimulatorRunSnapshot {
        let response: BurnBarSimulatorRunResponse = try requestResult(
            BurnBarRPCRequestEnvelopeWithParams(
                method: .simulatorReplay,
                params: BurnBarSimulatorReplayRequest(runID: runID, includeEvents: true)
            )
        )
        return response.run
    }

    private func unwrap<Response>(_ envelope: BurnBarRPCResponseEnvelope<Response>) throws -> Response {
        if let error = envelope.error {
            throw NSError(domain: "BurnBarCLI", code: error.code, userInfo: [NSLocalizedDescriptionKey: error.message])
        }
        guard let result = envelope.result else {
            throw NSError(domain: "BurnBarCLI", code: -1, userInfo: [NSLocalizedDescriptionKey: "BurnBar daemon returned an empty response."])
        }
        return result
    }

    private func requestResult<Params: Codable & Sendable, Response: Codable & Sendable>(
        _ request: BurnBarRPCRequestEnvelopeWithParams<Params>
    ) throws -> Response {
        let envelope: BurnBarRPCResponseEnvelope<Response> = try send(request)
        return try unwrap(envelope)
    }

    private func send<Request: Encodable, Response: Codable & Sendable>(
        _ request: Request
    ) throws -> BurnBarRPCResponseEnvelope<Response> {
        let fileDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fileDescriptor != -1 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        defer { close(fileDescriptor) }

        var noSigPipe: Int32 = 1
        setsockopt(
            fileDescriptor,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &noSigPipe,
            socklen_t(MemoryLayout<Int32>.size)
        )

        var address = try socketAddress(for: socketURL.path)
        let connectResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { reboundPointer in
                connect(fileDescriptor, reboundPointer, socklen_t(MemoryLayout<sockaddr_un>.stride))
            }
        }
        guard connectResult == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .ECONNREFUSED)
        }

        let payload = try JSONEncoder().encode(request) + Data([0x0A])
        try payload.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var remaining = rawBuffer.count
            var offset = 0
            while remaining > 0 {
                let wrote = write(fileDescriptor, baseAddress.advanced(by: offset), remaining)
                guard wrote > 0 else {
                    throw POSIXError(.init(rawValue: errno) ?? .EIO)
                }
                remaining -= wrote
                offset += wrote
            }
        }

        var response = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let bytesRead = read(fileDescriptor, &buffer, buffer.count)
            guard bytesRead >= 0 else {
                throw POSIXError(.init(rawValue: errno) ?? .EIO)
            }
            if bytesRead == 0 { break }
            response.append(contentsOf: buffer.prefix(bytesRead))
            if response.last == 0x0A { break }
        }

        while response.last == 0x0A || response.last == 0x0D {
            response.removeLast()
        }

        return try JSONDecoder().decode(BurnBarRPCResponseEnvelope<Response>.self, from: response)
    }

    private func socketAddress(for socketPath: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.stride)

        let pathBytes = Array(socketPath.utf8)
        guard pathBytes.count < MemoryLayout.size(ofValue: address.sun_path) else {
            throw POSIXError(.ENAMETOOLONG)
        }

        withUnsafeMutableBytes(of: &address.sun_path) { rawBuffer in
            rawBuffer.initializeMemory(as: UInt8.self, repeating: 0)
            for (index, byte) in pathBytes.enumerated() {
                rawBuffer[index] = byte
            }
        }
        return address
    }
}

public enum BurnBarCLIError: LocalizedError {
    case invalidCommand(String)
    case missingArgument(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCommand(let command):
            return "Unsupported BurnBar CLI command '\(command)'."
        case .missingArgument(let usage):
            return usage
        }
    }
}

public struct BurnBarCLIRunner {
    public let client: any BurnBarCLIClient

    public init(client: any BurnBarCLIClient) {
        self.client = client
    }

    public func run(arguments: [String]) throws -> String {
        let effectiveArguments = arguments.first == "--" ? Array(arguments.dropFirst()) : arguments
        guard let command = effectiveArguments.first else {
            return Self.usageText
        }

        switch command {
        case "help", "--help", "-h":
            return Self.usageText
        case "health":
            return formatHealth(try client.health())
        case "controller", "status":
            return formatControllerSummary(try client.controllerSummary(projectSlug: effectiveArguments.dropFirst().first))
        case "questions":
            return formatQuestions(try client.questions(projectSlug: effectiveArguments.dropFirst().first))
        case "followups":
            return formatFollowups(try client.followups(projectSlug: effectiveArguments.dropFirst().first))
        case "missions":
            return formatMissions(try client.missions(projectSlug: effectiveArguments.dropFirst().first))
        case "mission-approve":
            guard effectiveArguments.count >= 2 else {
                throw BurnBarCLIError.missingArgument("Usage: burnbar-cli mission-approve <missionID> [note]")
            }
            let mission = try client.approveMission(
                id: BurnBarMissionID(rawValue: effectiveArguments[1]),
                note: effectiveArguments.count > 2 ? effectiveArguments.dropFirst(2).joined(separator: " ") : nil
            )
            return "Approved \(mission.title) (\(mission.id.rawValue))."
        case "simulator-runs":
            return formatSimulatorRuns(try client.simulatorRuns(projectSlug: effectiveArguments.dropFirst().first))
        case "simulator-replay":
            guard effectiveArguments.count >= 2 else {
                throw BurnBarCLIError.missingArgument("Usage: burnbar-cli simulator-replay <runID>")
            }
            let run = try client.simulatorReplay(runID: BurnBarSimulatorRunID(rawValue: effectiveArguments[1]))
            return "Replayed \(run.scenarioName) (\(run.id.rawValue)) with \(run.emittedEvents.count) event(s)."
        default:
            throw BurnBarCLIError.invalidCommand(command)
        }
    }

    public static let usageText = """
    burnbar-cli <command> [args]

    Commands:
      health
      controller [projectSlug]
      questions [projectSlug]
      followups [projectSlug]
      missions [projectSlug]
      mission-approve <missionID> [note]
      simulator-runs [projectSlug]
      simulator-replay <runID>
    """

    private func formatHealth(_ response: BurnBarHealthResponse) -> String {
        "Daemon \(response.daemonVersion) | protocol \(response.protocolVersion) | socket \(response.socketPath ?? "n/a") | ok=\(response.ok)"
    }

    private func formatControllerSummary(_ summary: BurnBarControllerSummary) -> String {
        [
            "Updated: \(summary.updatedAt.formatted(date: .abbreviated, time: .shortened))",
            "Projects: \(summary.counts.projectCount)",
            "Pending questions: \(summary.counts.pendingQuestionCount)",
            "Open followups: \(summary.counts.openFollowupCount)",
            "Active missions: \(summary.counts.activeMissionCount)",
            "Freshness: \(summary.freshness.rawValue)"
        ].joined(separator: "\n")
    }

    private func formatQuestions(_ questions: [BurnBarPendingQuestionSnapshot]) -> String {
        guard questions.isEmpty == false else { return "No questions." }
        return questions.map { question in
            let stage = question.stageLabel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? " [\(question.stageLabel!)]"
                : ""
            return "\(question.id.rawValue)\(stage) \(question.title)"
        }.joined(separator: "\n")
    }

    private func formatFollowups(_ followups: [BurnBarFollowupSnapshot]) -> String {
        guard followups.isEmpty == false else { return "No followups." }
        return followups.map { followup in
            "\(followup.id.rawValue) [\(followup.status.rawValue)] \(followup.title)"
        }.joined(separator: "\n")
    }

    private func formatMissions(_ missions: [BurnBarMissionSnapshot]) -> String {
        guard missions.isEmpty == false else { return "No missions." }
        return missions.map { mission in
            "\(mission.id.rawValue) [\(mission.status.rawValue)] \(mission.title)"
        }.joined(separator: "\n")
    }

    private func formatSimulatorRuns(_ runs: [BurnBarSimulatorRunSnapshot]) -> String {
        guard runs.isEmpty == false else { return "No simulator runs." }
        return runs.map { run in
            "\(run.id.rawValue) [\(run.status.rawValue)] \(run.scenarioName)"
        }.joined(separator: "\n")
    }
}
