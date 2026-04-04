import OpenBurnBarCore
import Foundation

public enum BurnBarMissionControlError: Error, LocalizedError {
    case projectNotFound(String)
    case questionNotFound(BurnBarQuestionID)
    case followupNotFound(BurnBarFollowupID)
    case missionNotFound(BurnBarMissionID)
    case simulatorRunNotFound(BurnBarSimulatorRunID)
    case missingPayload(String)

    public var errorDescription: String? {
        switch self {
        case .projectNotFound(let slug):
            return "OpenBurnBar controller project '\(slug)' was not found."
        case .questionNotFound(let id):
            return "OpenBurnBar pending question '\(id.rawValue)' was not found."
        case .followupNotFound(let id):
            return "OpenBurnBar followup '\(id.rawValue)' was not found."
        case .missionNotFound(let id):
            return "OpenBurnBar mission '\(id.rawValue)' was not found."
        case .simulatorRunNotFound(let id):
            return "OpenBurnBar simulator run '\(id.rawValue)' was not found."
        case .missingPayload(let eventType):
            return "OpenBurnBar controller event '\(eventType)' is missing a payload."
        }
    }
}
