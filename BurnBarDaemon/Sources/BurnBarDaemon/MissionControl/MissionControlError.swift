import BurnBarCore
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
            return "BurnBar controller project '\(slug)' was not found."
        case .questionNotFound(let id):
            return "BurnBar pending question '\(id.rawValue)' was not found."
        case .followupNotFound(let id):
            return "BurnBar followup '\(id.rawValue)' was not found."
        case .missionNotFound(let id):
            return "BurnBar mission '\(id.rawValue)' was not found."
        case .simulatorRunNotFound(let id):
            return "BurnBar simulator run '\(id.rawValue)' was not found."
        case .missingPayload(let eventType):
            return "BurnBar controller event '\(eventType)' is missing a payload."
        }
    }
}
