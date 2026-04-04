import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

// Shared-artifact + memory sync boundary types and Firestore codecs used by `CloudSyncService`.

enum OpenBurnBarMemorySyncMode: String, Equatable, Sendable {
    case localFirstOptionalCloud = "local_first_optional_cloud"
    case cloudCanonical = "cloud_canonical"
}

enum OpenBurnBarMemoryAuthority: String, Equatable, Sendable {
    case localSQLite = "local_sqlite"
    case cloudReplica = "cloud_replica"
}

struct OpenBurnBarMemorySyncBoundarySnapshot: Equatable, Sendable {
    let mode: OpenBurnBarMemorySyncMode
    let canonicalAuthority: OpenBurnBarMemoryAuthority
    let cloudMetadataBackupEnabled: Bool
    let cloudSessionLogBackupEnabled: Bool
    let iCloudMirrorEnabled: Bool
    let collaborationUsesCloudHead: Bool
    let notes: [String]
}

struct SharedArtifactScope: Equatable, Sendable {
    let workspaceID: String
    let teamID: String
    let ownerUserID: String?

    static func defaultScope(for uid: String) -> SharedArtifactScope {
        SharedArtifactScope(
            workspaceID: "workspace-\(uid)",
            teamID: "team-default",
            ownerUserID: uid
        )
    }
}

struct SharedArtifactCloudRecord: Equatable, Sendable {
    let artifactID: String
    let workspaceID: String
    let teamID: String
    let ownerUserID: String?
    let visibility: SharedArtifactVisibility
    let revisionID: String
    let baseRevisionID: String?
    let title: String
    let body: String
    let contentHash: String
    let relativePath: String?
    let isDeleted: Bool
    let updatedByUserID: String?
    let updatedByDeviceID: String?
    let resolvedConflictRevisionID: String?
    let updatedAt: Date?

    init(
        artifactID: String,
        workspaceID: String,
        teamID: String,
        ownerUserID: String?,
        visibility: SharedArtifactVisibility = .team,
        revisionID: String,
        baseRevisionID: String? = nil,
        title: String,
        body: String,
        contentHash: String,
        relativePath: String?,
        isDeleted: Bool,
        updatedByUserID: String? = nil,
        updatedByDeviceID: String? = nil,
        resolvedConflictRevisionID: String? = nil,
        updatedAt: Date?
    ) {
        self.artifactID = artifactID
        self.workspaceID = workspaceID
        self.teamID = teamID
        self.ownerUserID = ownerUserID
        self.visibility = visibility
        self.revisionID = revisionID
        self.baseRevisionID = baseRevisionID
        self.title = title
        self.body = body
        self.contentHash = contentHash
        self.relativePath = relativePath
        self.isDeleted = isDeleted
        self.updatedByUserID = updatedByUserID
        self.updatedByDeviceID = updatedByDeviceID
        self.resolvedConflictRevisionID = resolvedConflictRevisionID
        self.updatedAt = updatedAt
    }
}

enum SharedArtifactCloudCodecError: LocalizedError {
    case missingField(String)
    case invalidFieldType(String)

    var errorDescription: String? {
        switch self {
        case .missingField(let field):
            return "Shared artifact cloud payload is missing required field: \(field)."
        case .invalidFieldType(let field):
            return "Shared artifact cloud payload has an invalid field type for: \(field)."
        }
    }
}

enum SharedArtifactMergeDecision: Equatable, Sendable {
    case noChange
    case pushLocal
    case pullRemote
    case conflict
}

enum SharedArtifactSyncResolver {
    static func mergeDecision(
        localContentHash: String?,
        syncedContentHash: String?,
        remoteContentHash: String?
    ) -> SharedArtifactMergeDecision {
        switch (localContentHash, remoteContentHash) {
        case (nil, nil):
            return .noChange
        case (let local?, nil):
            return local.isEmpty ? .noChange : .pushLocal
        case (nil, let remote?):
            return remote.isEmpty ? .noChange : .pullRemote
        case (let local?, let remote?):
            guard local != remote else { return .noChange }

            guard let baseline = syncedContentHash, baseline.isEmpty == false else {
                return .conflict
            }

            let localChanged = local != baseline
            let remoteChanged = remote != baseline

            if localChanged && remoteChanged {
                return .conflict
            }
            if localChanged {
                return .pushLocal
            }
            if remoteChanged {
                return .pullRemote
            }
            return .noChange
        }
    }
}

enum SharedArtifactCollaborationNoticeKind: String, Equatable, Sendable {
    case remoteUpdateArrived = "remote_update_arrived"
    case editConflicted = "edit_conflicted"
    case resolvedVersionSaved = "resolved_version_saved"

    var title: String {
        switch self {
        case .remoteUpdateArrived:
            return "Remote update arrived"
        case .editConflicted:
            return "Your edit conflicted"
        case .resolvedVersionSaved:
            return "Resolved version saved"
        }
    }
}

struct SharedArtifactCollaborationNotice: Identifiable, Equatable, Sendable {
    let kind: SharedArtifactCollaborationNoticeKind
    let sourceArtifactID: String
    let remoteArtifactID: String
    let message: String
    let occurredAt: Date

    var id: String {
        "\(kind.rawValue)|\(sourceArtifactID)|\(remoteArtifactID)|\(occurredAt.timeIntervalSince1970)"
    }
}

struct SharedArtifactOptimisticWriteConflict: Equatable, Sendable {
    let expectedRevisionID: String?
    let observedRevisionID: String?
}

enum SharedArtifactOptimisticWriteGate {
    static let errorDomain = "CloudSyncService.SharedArtifactOptimisticWrite"
    static let staleWriteCode = 409

    private static let expectedRevisionKey = "expectedRevisionID"
    private static let observedRevisionKey = "observedRevisionID"

    static func validate(expectedRevisionID: String?, observedRevisionID: String?) throws {
        let normalizedExpected = normalizedRevisionID(expectedRevisionID)
        let normalizedObserved = normalizedRevisionID(observedRevisionID)
        guard normalizedExpected == normalizedObserved else {
            throw staleWriteError(expectedRevisionID: normalizedExpected, observedRevisionID: normalizedObserved)
        }
    }

    static func conflict(from error: Error) -> SharedArtifactOptimisticWriteConflict? {
        let nsError = error as NSError
        guard nsError.domain == errorDomain, nsError.code == staleWriteCode else { return nil }

        let expected = normalizedRevisionID(nsError.userInfo[expectedRevisionKey] as? String)
        let observed = normalizedRevisionID(nsError.userInfo[observedRevisionKey] as? String)
        return SharedArtifactOptimisticWriteConflict(
            expectedRevisionID: expected,
            observedRevisionID: observed
        )
    }

    private static func staleWriteError(expectedRevisionID: String?, observedRevisionID: String?) -> NSError {
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey:
                "Shared artifact write was rejected because the remote head changed from \(expectedRevisionID ?? "nil") to \(observedRevisionID ?? "nil")."
        ]
        userInfo[expectedRevisionKey] = expectedRevisionID
        userInfo[observedRevisionKey] = observedRevisionID
        return NSError(domain: errorDomain, code: staleWriteCode, userInfo: userInfo)
    }

    private static func normalizedRevisionID(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum SharedArtifactCloudCodec {
    static let provenancePrefix = "shared-sync:"

    static func encode(_ record: SharedArtifactCloudRecord, useServerTimestamp: Bool) -> [String: Any] {
        var payload: [String: Any] = [
            "artifactID": record.artifactID,
            "workspaceID": record.workspaceID,
            "teamID": record.teamID,
            "visibility": record.visibility.rawValue,
            "revisionID": record.revisionID,
            "title": record.title,
            "body": record.body,
            "contentHash": record.contentHash,
            "isDeleted": record.isDeleted
        ]
        if let ownerUserID = record.ownerUserID {
            payload["ownerUserID"] = ownerUserID
        }
        if let baseRevisionID = record.baseRevisionID {
            payload["baseRevisionID"] = baseRevisionID
        }
        if let relativePath = record.relativePath {
            payload["relativePath"] = relativePath
        }
        if let updatedByUserID = record.updatedByUserID {
            payload["updatedByUserID"] = updatedByUserID
        }
        if let updatedByDeviceID = record.updatedByDeviceID {
            payload["updatedByDeviceID"] = updatedByDeviceID
        }
        if let resolvedConflictRevisionID = record.resolvedConflictRevisionID {
            payload["resolvedConflictRevisionID"] = resolvedConflictRevisionID
        }
        if useServerTimestamp {
            payload["updatedAt"] = FieldValue.serverTimestamp()
        } else if let updatedAt = record.updatedAt {
            payload["updatedAt"] = updatedAt
        }
        return payload
    }

    static func decode(documentID: String, data: [String: Any]) throws -> SharedArtifactCloudRecord {
        let artifactID = stringValue(data["artifactID"]) ?? stringValue(data["id"]) ?? documentID
        guard let workspaceID = stringValue(data["workspaceID"]) else {
            throw SharedArtifactCloudCodecError.missingField("workspaceID")
        }
        guard let teamID = stringValue(data["teamID"]) else {
            throw SharedArtifactCloudCodecError.missingField("teamID")
        }
        let visibility = stringValue(data["visibility"])
            .flatMap(SharedArtifactVisibility.init(rawValue:))
            ?? .team
        guard let revisionID = stringValue(data["revisionID"]) else {
            throw SharedArtifactCloudCodecError.missingField("revisionID")
        }
        guard let title = stringValue(data["title"]) else {
            throw SharedArtifactCloudCodecError.missingField("title")
        }
        guard let body = stringValue(data["body"]) else {
            throw SharedArtifactCloudCodecError.missingField("body")
        }
        guard let contentHash = stringValue(data["contentHash"]) else {
            throw SharedArtifactCloudCodecError.missingField("contentHash")
        }
        let isDeleted = boolValue(data["isDeleted"]) ?? false

        return SharedArtifactCloudRecord(
            artifactID: artifactID,
            workspaceID: workspaceID,
            teamID: teamID,
            ownerUserID: stringValue(data["ownerUserID"]),
            visibility: visibility,
            revisionID: revisionID,
            baseRevisionID: stringValue(data["baseRevisionID"]),
            title: title,
            body: body,
            contentHash: contentHash,
            relativePath: stringValue(data["relativePath"]),
            isDeleted: isDeleted,
            updatedByUserID: stringValue(data["updatedByUserID"]),
            updatedByDeviceID: stringValue(data["updatedByDeviceID"]),
            resolvedConflictRevisionID: stringValue(data["resolvedConflictRevisionID"]),
            updatedAt: dateValue(data["updatedAt"])
        )
    }

    static func encodeProvenance(
        workspaceID: String,
        teamID: String,
        remoteArtifactID: String,
        ownerUserID: String?
    ) -> String {
        let owner = ownerUserID ?? ""
        return "\(provenancePrefix)\(workspaceID)|\(teamID)|\(remoteArtifactID)|\(owner)"
    }

    static func decodeProvenance(_ provenance: String) -> (workspaceID: String, teamID: String, remoteArtifactID: String, ownerUserID: String?)? {
        guard provenance.hasPrefix(provenancePrefix) else { return nil }
        let raw = String(provenance.dropFirst(provenancePrefix.count))
        let pieces = raw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard pieces.count >= 3 else { return nil }
        let owner = pieces.count > 3 ? pieces[3] : ""
        return (
            workspaceID: pieces[0],
            teamID: pieces[1],
            remoteArtifactID: pieces[2],
            ownerUserID: owner.isEmpty ? nil : owner
        )
    }

    private static func stringValue(_ raw: Any?) -> String? {
        guard let value = raw as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func boolValue(_ raw: Any?) -> Bool? {
        if let value = raw as? Bool { return value }
        if let number = raw as? NSNumber { return number.boolValue }
        if let text = raw as? String {
            switch text.lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    private static func dateValue(_ raw: Any?) -> Date? {
        if let timestamp = raw as? Timestamp {
            return timestamp.dateValue()
        }
        if let date = raw as? Date {
            return date
        }
        if let number = raw as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }
        if let text = raw as? String, let value = Double(text) {
            return Date(timeIntervalSince1970: value)
        }
        return nil
    }
}
