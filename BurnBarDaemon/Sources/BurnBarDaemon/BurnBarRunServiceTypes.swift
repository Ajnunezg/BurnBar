import BurnBarCore
import Foundation

// Public error surface for `BurnBarRunService` (actor + execution state remain in BurnBarRunService.swift).

public enum BurnBarRunServiceError: Error, LocalizedError {
    case runNotFound(BurnBarRunID)
    case retryRequiresFailedRun(BurnBarRunID)
    case approvalNotFound(BurnBarApprovalID)
    case approvalAlreadyResolved(BurnBarApprovalID)
    case routeFailed(String)
    case invalidToolResult(BurnBarRunID, String)
    case missingWorkflowInput(BurnBarRunID, String)

    public var errorDescription: String? {
        switch self {
        case .runNotFound(let runID):
            return "Run '\(runID.rawValue)' was not found."
        case .retryRequiresFailedRun(let runID):
            return "Run '\(runID.rawValue)' is not in a failed state and cannot be retried."
        case .approvalNotFound(let approvalID):
            return "Approval '\(approvalID.rawValue)' was not found."
        case .approvalAlreadyResolved(let approvalID):
            return "Approval '\(approvalID.rawValue)' has already been resolved."
        case .routeFailed(let message):
            return "BurnBar could not route the requested run: \(message)"
        case .invalidToolResult(let runID, let message):
            return "BurnBar received an invalid tool result for run '\(runID.rawValue)': \(message)"
        case .missingWorkflowInput(let runID, let message):
            return "BurnBar could not continue workflow for run '\(runID.rawValue)': \(message)"
        }
    }
}
