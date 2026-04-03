import Foundation
import GRDB
import SwiftUI
import BurnBarCore

// MARK: - Local Search Store

struct LocalSearchStore {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func upsertDocument(_ document: SearchDocumentRecord) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO search_documents (
                    id, sourceKind, sourceID, sourceVersionID, provider, projectName, title, subtitle,
                    bodyPreview, sourceUpdatedAt, indexedAt, contentHash, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    sourceKind = excluded.sourceKind,
                    sourceID = excluded.sourceID,
                    sourceVersionID = excluded.sourceVersionID,
                    provider = excluded.provider,
                    projectName = excluded.projectName,
                    title = excluded.title,
                    subtitle = excluded.subtitle,
                    bodyPreview = excluded.bodyPreview,
                    sourceUpdatedAt = excluded.sourceUpdatedAt,
                    indexedAt = excluded.indexedAt,
                    contentHash = excluded.contentHash,
                    updatedAt = excluded.updatedAt
                """,
                arguments: [
                    document.id,
                    document.sourceKind.rawValue,
                    document.sourceID,
                    document.sourceVersionID,
                    document.provider,
                    document.projectName,
                    document.title,
                    document.subtitle,
                    document.bodyPreview,
                    document.sourceUpdatedAt,
                    document.indexedAt,
                    document.contentHash,
                    document.createdAt,
                    document.updatedAt
                ]
            )
        }
    }

    func fetchDocuments(limit: Int) throws -> [SearchDocumentRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM search_documents
                ORDER BY indexedAt DESC, createdAt DESC
                LIMIT ?
                """,
                arguments: [limit]
            )
            return rows.compactMap(Self.document(from:))
        }
    }

    func fetchDocuments(
        limit: Int,
        provider: String?,
        projectName: String?,
        sourceKinds: [SearchSourceKind]?,
        dateRange: ClosedRange<Date>?
    ) throws -> [SearchDocumentRecord] {
        let (whereSQL, args) = Self.filteredDocumentClause(
            provider: provider,
            projectName: projectName,
            sourceKinds: sourceKinds,
            dateRange: dateRange
        )
        var queryArgs = args
        queryArgs.append(max(1, limit))

        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM search_documents
                \(whereSQL)
                ORDER BY COALESCE(sourceUpdatedAt, indexedAt) DESC, indexedAt DESC, createdAt DESC
                LIMIT ?
                """,
                arguments: StatementArguments(queryArgs)
            )
            return rows.compactMap(Self.document(from:))
        }
    }

    func fetchDocuments(ids: [String]) throws -> [SearchDocumentRecord] {
        let uniqueIDs = Array(Set(ids)).sorted()
        guard uniqueIDs.isEmpty == false else { return [] }

        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM search_documents
                WHERE id IN (\(Self.sqlPlaceholders(count: uniqueIDs.count)))
                ORDER BY indexedAt DESC, createdAt DESC
                """,
                arguments: StatementArguments(uniqueIDs)
            )
            return rows.compactMap(Self.document(from:))
        }
    }

    func fetchDocument(id: String) throws -> SearchDocumentRecord? {
        try fetchDocuments(ids: [id]).first
    }

    func fetchDocuments(sourceKind: SearchSourceKind, sourceID: String) throws -> [SearchDocumentRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM search_documents
                WHERE sourceKind = ? AND sourceID = ?
                ORDER BY indexedAt DESC, createdAt DESC
                """,
                arguments: [sourceKind.rawValue, sourceID]
            )
            return rows.compactMap(Self.document(from:))
        }
    }

    func countDocuments(
        provider: String?,
        projectName: String?,
        sourceKinds: [SearchSourceKind]?,
        dateRange: ClosedRange<Date>?
    ) throws -> Int {
        let (whereSQL, args) = Self.filteredDocumentClause(
            provider: provider,
            projectName: projectName,
            sourceKinds: sourceKinds,
            dateRange: dateRange
        )

        return try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM search_documents
                \(whereSQL)
                """,
                arguments: StatementArguments(args)
            ) ?? 0
        }
    }

    func countChunks(
        sourceKinds: [SearchSourceKind]?,
        dateRange: ClosedRange<Date>?
    ) throws -> Int {
        let normalizedSourceKinds = Array(Set(sourceKinds ?? [])).sorted { $0.rawValue < $1.rawValue }
        var clauses: [String] = []
        var args: [any DatabaseValueConvertible] = []

        if normalizedSourceKinds.isEmpty == false {
            clauses.append("d.sourceKind IN (\(Self.sqlPlaceholders(count: normalizedSourceKinds.count)))")
            args.append(contentsOf: normalizedSourceKinds.map(\.rawValue))
        }

        if let dateRange {
            clauses.append("COALESCE(d.sourceUpdatedAt, d.indexedAt) >= ?")
            clauses.append("COALESCE(d.sourceUpdatedAt, d.indexedAt) <= ?")
            args.append(dateRange.lowerBound)
            args.append(dateRange.upperBound)
        }

        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        return try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM search_chunks AS c
                JOIN search_documents AS d ON d.id = c.documentID
                \(whereSQL)
                """,
                arguments: StatementArguments(args)
            ) ?? 0
        }
    }

    func countChunks(documentID: String) throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM search_chunks
                WHERE documentID = ?
                """,
                arguments: [documentID]
            ) ?? 0
        }
    }

    func replaceChunks(documentID: String, title: String, chunks: [SearchChunkRecord]) throws {
        try dbQueue.write { db in
            // Look up the document to get projectName and provider for FTS
            let documentRow = try Row.fetchOne(
                db,
                sql: "SELECT projectName, provider FROM search_documents WHERE id = ?",
                arguments: [documentID]
            )
            let projectName = documentRow?["projectName"] as? String ?? ""
            let provider = documentRow?["provider"] as? String ?? ""

            try db.execute(
                sql: "DELETE FROM search_chunks_fts WHERE documentID = ?",
                arguments: [documentID]
            )
            try db.execute(
                sql: "DELETE FROM search_chunks WHERE documentID = ?",
                arguments: [documentID]
            )

            for chunk in chunks.sorted(by: { $0.ordinal < $1.ordinal }) {
                try db.execute(
                    sql: """
                    INSERT INTO search_chunks (
                        id, documentID, sourceKind, sourceID, sourceVersionID, ordinal,
                        startOffset, endOffset, messageStartOffset, messageEndOffset,
                        sectionPath, text, createdAt, updatedAt
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        chunk.id,
                        chunk.documentID,
                        chunk.sourceKind.rawValue,
                        chunk.sourceID,
                        chunk.sourceVersionID,
                        chunk.ordinal,
                        chunk.startOffset,
                        chunk.endOffset,
                        chunk.messageStartOffset,
                        chunk.messageEndOffset,
                        chunk.sectionPath,
                        chunk.text,
                        chunk.createdAt,
                        chunk.updatedAt
                    ]
                )

                // Insert with new multi-field FTS columns (projectName, provider)
                try db.execute(
                    sql: """
                    INSERT INTO search_chunks_fts (chunkID, documentID, title, chunkText, projectName, provider)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [chunk.id, chunk.documentID, title, chunk.text, projectName, provider]
                )
            }
        }
    }

    func fetchChunks(documentID: String) throws -> [SearchChunkRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM search_chunks
                WHERE documentID = ?
                ORDER BY ordinal ASC
                """,
                arguments: [documentID]
            )
            return rows.compactMap(Self.chunk(from:))
        }
    }

    func fetchChunks(ids: [String]) throws -> [SearchChunkRecord] {
        let uniqueIDs = Array(Set(ids)).sorted()
        guard uniqueIDs.isEmpty == false else { return [] }

        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM search_chunks
                WHERE id IN (\(Self.sqlPlaceholders(count: uniqueIDs.count)))
                ORDER BY documentID ASC, ordinal ASC
                """,
                arguments: StatementArguments(uniqueIDs)
            )
            return rows.compactMap(Self.chunk(from:))
        }
    }

    func fetchChunks(sourceKind: SearchSourceKind, sourceID: String) throws -> [SearchChunkRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM search_chunks
                WHERE sourceKind = ? AND sourceID = ?
                ORDER BY documentID ASC, ordinal ASC
                """,
                arguments: [sourceKind.rawValue, sourceID]
            )
            return rows.compactMap(Self.chunk(from:))
        }
    }

    func searchLexicalChunks(
        ftsQuery: String,
        provider: String?,
        projectName: String?,
        sourceKinds: [SearchSourceKind]?,
        dateRange: ClosedRange<Date>?,
        visibility: SearchVisibilityScope,
        sharedArtifactAccessContext: SharedArtifactAccessContext?,
        sourceIDs: [String]?,
        limit: Int
    ) throws -> [SearchChunkLexicalMatch] {
        guard ftsQuery.isEmpty == false, limit > 0 else { return [] }

        let normalizedSourceKinds = Array(Set(sourceKinds ?? [])).sorted { $0.rawValue < $1.rawValue }
        let normalizedSourceIDs = Array(Set((sourceIDs ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        let normalizedProject = projectName?.trimmingCharacters(in: .whitespacesAndNewlines)

        var clauses: [String] = ["search_chunks_fts MATCH ?"]
        var args: [any DatabaseValueConvertible] = [ftsQuery]

        if let provider, provider.isEmpty == false {
            clauses.append("d.provider = ?")
            args.append(provider)
        }

        if let normalizedProject, normalizedProject.isEmpty == false {
            clauses.append("d.projectName = ?")
            args.append(normalizedProject)
        }

        if normalizedSourceKinds.isEmpty == false {
            clauses.append("d.sourceKind IN (\(Self.sqlPlaceholders(count: normalizedSourceKinds.count)))")
            args.append(contentsOf: normalizedSourceKinds.map(\.rawValue))
        }

        if normalizedSourceIDs.isEmpty == false {
            clauses.append("d.sourceID IN (\(Self.sqlPlaceholders(count: normalizedSourceIDs.count)))")
            args.append(contentsOf: normalizedSourceIDs)
        }

        if let dateRange {
            clauses.append("COALESCE(d.sourceUpdatedAt, d.indexedAt) >= ?")
            clauses.append("COALESCE(d.sourceUpdatedAt, d.indexedAt) <= ?")
            args.append(dateRange.lowerBound)
            args.append(dateRange.upperBound)
        }

        switch visibility {
        case .all:
            break
        case .personalOnly:
            clauses.append("d.sourceKind != ?")
            args.append(SearchSourceKind.sharedArtifact.rawValue)
        case .sharedOnly:
            clauses.append("d.sourceKind = ?")
            args.append(SearchSourceKind.sharedArtifact.rawValue)
        }

        if visibility != .personalOnly {
            if let access = sharedArtifactAccessContext {
                clauses.append(
                    """
                    (
                        d.sourceKind != ?
                        OR EXISTS (
                            SELECT 1
                            FROM artifact_permissions AS ap
                            WHERE ap.sourceArtifactID = d.sourceID
                              AND ap.canRead = 1
                              AND ap.workspaceID = ?
                              AND (
                                  (ap.principalType = ? AND ap.principalID = ?)
                                  OR (ap.principalType = ? AND ap.principalID = ? AND ap.teamID = ?)
                                  OR (ap.principalType = ? AND ap.principalID = ?)
                              )
                        )
                        OR EXISTS (
                            SELECT 1
                            FROM shared_artifact_sync_state AS sas
                            WHERE sas.sourceArtifactID = d.sourceID
                              AND sas.workspaceID = ?
                              AND sas.teamID = ?
                              AND sas.ownerUserID = ?
                        )
                    )
                    """
                )
                args.append(SearchSourceKind.sharedArtifact.rawValue)
                args.append(access.workspaceID)
                args.append(SharedArtifactPrincipalType.user.rawValue)
                args.append(access.userID)
                args.append(SharedArtifactPrincipalType.team.rawValue)
                args.append(access.teamID)
                args.append(access.teamID)
                args.append(SharedArtifactPrincipalType.workspace.rawValue)
                args.append(access.workspaceID)
                args.append(access.workspaceID)
                args.append(access.teamID)
                args.append(access.userID)
            } else {
                clauses.append("d.sourceKind != ?")
                args.append(SearchSourceKind.sharedArtifact.rawValue)
            }
        }

        let whereSQL = clauses.joined(separator: " AND ")
        args.append(limit)

        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    search_chunks_fts.chunkID AS chunkID,
                    search_chunks_fts.documentID AS documentID,
                    bm25(search_chunks_fts) AS lexicalRank,
                    snippet(search_chunks_fts, 3, '<b>', '</b>', '…', 16) AS snippet,
                    d.sourceKind AS sourceKind,
                    d.sourceID AS sourceID,
                    d.sourceVersionID AS sourceVersionID,
                    d.provider AS provider,
                    d.projectName AS projectName,
                    d.title AS title,
                    d.subtitle AS subtitle,
                    d.bodyPreview AS bodyPreview,
                    d.sourceUpdatedAt AS sourceUpdatedAt,
                    d.indexedAt AS indexedAt,
                    c.ordinal AS chunkOrdinal,
                    c.startOffset AS startOffset,
                    c.endOffset AS endOffset,
                    c.sectionPath AS sectionPath,
                    c.text AS chunkText
                FROM search_chunks_fts
                JOIN search_chunks AS c ON c.id = search_chunks_fts.chunkID
                JOIN search_documents AS d ON d.id = search_chunks_fts.documentID
                WHERE \(whereSQL)
                ORDER BY lexicalRank ASC, d.indexedAt DESC, c.ordinal ASC
                LIMIT ?
                """,
                arguments: StatementArguments(args)
            )
            return rows.compactMap(Self.lexicalMatch(from:))
        }
    }

    func upsertSourceArtifact(_ artifact: SourceArtifactRecord) throws -> SourceArtifactWriteDisposition {
        guard artifact.sourceKind != .conversation else {
            throw NSError(
                domain: "DataStore.SourceArtifact",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "source_artifacts cannot store conversation sourceKind"]
            )
        }

        return try dbQueue.write { db in
            let existingRow = try Row.fetchOne(
                db,
                sql: "SELECT * FROM source_artifacts WHERE id = ?",
                arguments: [artifact.id]
            )
            let existing = existingRow.flatMap(Self.sourceArtifact(from:))
            let disposition: SourceArtifactWriteDisposition

            if let existing {
                let isUnchanged =
                    existing.status == .active
                    && existing.sourceKind == artifact.sourceKind
                    && existing.canonicalPath == artifact.canonicalPath
                    && existing.rootPath == artifact.rootPath
                    && existing.relativePath == artifact.relativePath
                    && existing.provenance == artifact.provenance
                    && existing.title == artifact.title
                    && existing.body == artifact.body
                    && existing.contentHash == artifact.contentHash
                    && existing.fileSizeBytes == artifact.fileSizeBytes
                    && existing.fileModifiedAt == artifact.fileModifiedAt

                if isUnchanged {
                    try db.execute(
                        sql: """
                        UPDATE source_artifacts
                        SET discoveredAt = ?, updatedAt = ?
                        WHERE id = ?
                        """,
                        arguments: [artifact.discoveredAt, artifact.updatedAt, artifact.id]
                    )
                    return .unchanged
                }
                disposition = existing.status == .deleted ? .restored : .updated
            } else {
                disposition = .inserted
            }

            try db.execute(
                sql: """
                INSERT INTO source_artifacts (
                    id, sourceKind, canonicalPath, rootPath, relativePath, provenance,
                    title, body, contentHash, fileSizeBytes, fileModifiedAt, status,
                    discoveredAt, deletedAt, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    sourceKind = excluded.sourceKind,
                    canonicalPath = excluded.canonicalPath,
                    rootPath = excluded.rootPath,
                    relativePath = excluded.relativePath,
                    provenance = excluded.provenance,
                    title = excluded.title,
                    body = excluded.body,
                    contentHash = excluded.contentHash,
                    fileSizeBytes = excluded.fileSizeBytes,
                    fileModifiedAt = excluded.fileModifiedAt,
                    status = excluded.status,
                    discoveredAt = excluded.discoveredAt,
                    deletedAt = excluded.deletedAt,
                    updatedAt = excluded.updatedAt
                """,
                arguments: [
                    artifact.id,
                    artifact.sourceKind.rawValue,
                    artifact.canonicalPath,
                    artifact.rootPath,
                    artifact.relativePath,
                    artifact.provenance,
                    artifact.title,
                    artifact.body,
                    artifact.contentHash,
                    artifact.fileSizeBytes,
                    artifact.fileModifiedAt,
                    SourceArtifactStatus.active.rawValue,
                    artifact.discoveredAt,
                    nil,
                    artifact.createdAt,
                    artifact.updatedAt
                ]
            )
            return disposition
        }
    }

    func fetchSourceArtifacts(
        includeDeleted: Bool,
        rootPaths: [String]?,
        sourceKinds: [SearchSourceKind]
    ) throws -> [SourceArtifactRecord] {
        guard sourceKinds.isEmpty == false else { return [] }
        let normalizedRoots = (rootPaths ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let kindValues = sourceKinds.map(\.rawValue)
        var clauses: [String] = []
        var args: [any DatabaseValueConvertible] = []

        if includeDeleted == false {
            clauses.append("status != ?")
            args.append(SourceArtifactStatus.deleted.rawValue)
        }

        clauses.append("sourceKind IN (\(Self.sqlPlaceholders(count: kindValues.count)))")
        args.append(contentsOf: kindValues)

        if normalizedRoots.isEmpty == false {
            clauses.append("rootPath IN (\(Self.sqlPlaceholders(count: normalizedRoots.count)))")
            args.append(contentsOf: normalizedRoots)
        }

        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM source_artifacts
                \(whereSQL)
                ORDER BY rootPath ASC, relativePath ASC
                """,
                arguments: StatementArguments(args)
            )
            return rows.compactMap(Self.sourceArtifact(from:))
        }
    }

    func countSourceArtifacts(
        includeDeleted: Bool,
        rootPaths: [String]?,
        sourceKinds: [SearchSourceKind]
    ) throws -> Int {
        guard sourceKinds.isEmpty == false else { return 0 }
        let normalizedRoots = (rootPaths ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let kindValues = sourceKinds.map(\.rawValue)
        var clauses: [String] = []
        var args: [any DatabaseValueConvertible] = []

        if includeDeleted == false {
            clauses.append("status != ?")
            args.append(SourceArtifactStatus.deleted.rawValue)
        }

        clauses.append("sourceKind IN (\(Self.sqlPlaceholders(count: kindValues.count)))")
        args.append(contentsOf: kindValues)

        if normalizedRoots.isEmpty == false {
            clauses.append("rootPath IN (\(Self.sqlPlaceholders(count: normalizedRoots.count)))")
            args.append(contentsOf: normalizedRoots)
        }

        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        return try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM source_artifacts
                \(whereSQL)
                """,
                arguments: StatementArguments(args)
            ) ?? 0
        }
    }

    func fetchSourceArtifact(id: String, includeDeleted: Bool) throws -> SourceArtifactRecord? {
        try dbQueue.read { db in
            guard
                let row = try Row.fetchOne(
                    db,
                    sql: "SELECT * FROM source_artifacts WHERE id = ?",
                    arguments: [id]
                ),
                let artifact = Self.sourceArtifact(from: row)
            else {
                return nil
            }
            if includeDeleted == false, artifact.status == .deleted {
                return nil
            }
            return artifact
        }
    }

    @discardableResult
    func markSourceArtifactDeleted(id: String, deletedAt: Date) throws -> Bool {
        try dbQueue.write { db in
            guard
                let row = try Row.fetchOne(db, sql: "SELECT * FROM source_artifacts WHERE id = ?", arguments: [id]),
                let existing = Self.sourceArtifact(from: row),
                existing.status != .deleted
            else {
                return false
            }
            try db.execute(
                sql: """
                UPDATE source_artifacts
                SET status = ?, deletedAt = ?, updatedAt = ?
                WHERE id = ?
                """,
                arguments: [SourceArtifactStatus.deleted.rawValue, deletedAt, deletedAt, id]
            )
            return true
        }
    }

    func upsertSharedArtifactSyncState(_ state: SharedArtifactSyncStateRecord) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO shared_artifact_sync_state (
                    sourceArtifactID, remoteArtifactID, workspaceID, teamID, ownerUserID,
                    revisionID, remoteContentHash, localContentHashAtSync, remoteUpdatedAt,
                    lastPulledAt, lastSyncedAt, syncStatus, lastErrorCode, lastErrorMessage,
                    createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(sourceArtifactID) DO UPDATE SET
                    remoteArtifactID = excluded.remoteArtifactID,
                    workspaceID = excluded.workspaceID,
                    teamID = excluded.teamID,
                    ownerUserID = excluded.ownerUserID,
                    revisionID = excluded.revisionID,
                    remoteContentHash = excluded.remoteContentHash,
                    localContentHashAtSync = excluded.localContentHashAtSync,
                    remoteUpdatedAt = excluded.remoteUpdatedAt,
                    lastPulledAt = excluded.lastPulledAt,
                    lastSyncedAt = excluded.lastSyncedAt,
                    syncStatus = excluded.syncStatus,
                    lastErrorCode = excluded.lastErrorCode,
                    lastErrorMessage = excluded.lastErrorMessage,
                    updatedAt = excluded.updatedAt
                """,
                arguments: [
                    state.sourceArtifactID,
                    state.remoteArtifactID,
                    state.workspaceID,
                    state.teamID,
                    state.ownerUserID,
                    state.revisionID,
                    state.remoteContentHash,
                    state.localContentHashAtSync,
                    state.remoteUpdatedAt,
                    state.lastPulledAt,
                    state.lastSyncedAt,
                    state.syncStatus.rawValue,
                    state.lastErrorCode,
                    state.lastErrorMessage,
                    state.createdAt,
                    state.updatedAt
                ]
            )
        }
    }

    func fetchSharedArtifactSyncState(sourceArtifactID: String) throws -> SharedArtifactSyncStateRecord? {
        try dbQueue.read { db in
            guard
                let row = try Row.fetchOne(
                    db,
                    sql: "SELECT * FROM shared_artifact_sync_state WHERE sourceArtifactID = ?",
                    arguments: [sourceArtifactID]
                )
            else {
                return nil
            }
            return Self.sharedArtifactSyncState(from: row)
        }
    }

    func fetchSharedArtifactSyncState(remoteArtifactID: String) throws -> SharedArtifactSyncStateRecord? {
        try dbQueue.read { db in
            guard
                let row = try Row.fetchOne(
                    db,
                    sql: "SELECT * FROM shared_artifact_sync_state WHERE remoteArtifactID = ?",
                    arguments: [remoteArtifactID]
                )
            else {
                return nil
            }
            return Self.sharedArtifactSyncState(from: row)
        }
    }

    func fetchSharedArtifactSyncStates(
        workspaceID: String?,
        teamID: String?,
        statuses: [SharedArtifactSyncStatus]?,
        limit: Int
    ) throws -> [SharedArtifactSyncStateRecord] {
        if let statuses, statuses.isEmpty {
            return []
        }

        let normalizedWorkspaceID = workspaceID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTeamID = teamID?.trimmingCharacters(in: .whitespacesAndNewlines)

        var clauses: [String] = []
        var args: [any DatabaseValueConvertible] = []

        if let normalizedWorkspaceID, normalizedWorkspaceID.isEmpty == false {
            clauses.append("workspaceID = ?")
            args.append(normalizedWorkspaceID)
        }

        if let normalizedTeamID, normalizedTeamID.isEmpty == false {
            clauses.append("teamID = ?")
            args.append(normalizedTeamID)
        }

        if let statuses, statuses.isEmpty == false {
            clauses.append("syncStatus IN (\(Self.sqlPlaceholders(count: statuses.count)))")
            args.append(contentsOf: statuses.map(\.rawValue))
        }

        args.append(max(1, limit))
        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")

        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM shared_artifact_sync_state
                \(whereSQL)
                ORDER BY updatedAt DESC, sourceArtifactID ASC
                LIMIT ?
                """,
                arguments: StatementArguments(args)
            )
            return rows.compactMap(Self.sharedArtifactSyncState(from:))
        }
    }

    func countSharedArtifactSyncStates(
        workspaceID: String?,
        teamID: String?,
        statuses: [SharedArtifactSyncStatus]?
    ) throws -> Int {
        if let statuses, statuses.isEmpty {
            return 0
        }

        let normalizedWorkspaceID = workspaceID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTeamID = teamID?.trimmingCharacters(in: .whitespacesAndNewlines)

        var clauses: [String] = []
        var args: [any DatabaseValueConvertible] = []

        if let normalizedWorkspaceID, normalizedWorkspaceID.isEmpty == false {
            clauses.append("workspaceID = ?")
            args.append(normalizedWorkspaceID)
        }

        if let normalizedTeamID, normalizedTeamID.isEmpty == false {
            clauses.append("teamID = ?")
            args.append(normalizedTeamID)
        }

        if let statuses, statuses.isEmpty == false {
            clauses.append("syncStatus IN (\(Self.sqlPlaceholders(count: statuses.count)))")
            args.append(contentsOf: statuses.map(\.rawValue))
        }

        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        return try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM shared_artifact_sync_state
                \(whereSQL)
                """,
                arguments: StatementArguments(args)
            ) ?? 0
        }
    }

    func upsertSharedArtifactPermission(_ permission: SharedArtifactPermissionRecord) throws -> SharedArtifactPermissionWriteDisposition {
        try dbQueue.write { db in
            let existingRow = try Row.fetchOne(
                db,
                sql: """
                SELECT * FROM artifact_permissions
                WHERE sourceArtifactID = ? AND principalType = ? AND principalID = ?
                """,
                arguments: [permission.sourceArtifactID, permission.principalType.rawValue, permission.principalID]
            )
            let existing = existingRow.flatMap(Self.sharedArtifactPermission(from:))
            if let existing, Self.permissionSemanticsEqual(existing, permission) {
                return .unchanged
            }

            let createdAt = existing?.createdAt ?? permission.createdAt
            try db.execute(
                sql: """
                INSERT INTO artifact_permissions (
                    sourceArtifactID, workspaceID, teamID, principalType, principalID,
                    role, visibility, canRead, canWrite, canShare, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(sourceArtifactID, principalType, principalID) DO UPDATE SET
                    workspaceID = excluded.workspaceID,
                    teamID = excluded.teamID,
                    role = excluded.role,
                    visibility = excluded.visibility,
                    canRead = excluded.canRead,
                    canWrite = excluded.canWrite,
                    canShare = excluded.canShare,
                    updatedAt = excluded.updatedAt
                """,
                arguments: [
                    permission.sourceArtifactID,
                    permission.workspaceID,
                    permission.teamID,
                    permission.principalType.rawValue,
                    permission.principalID,
                    permission.role.rawValue,
                    permission.visibility.rawValue,
                    permission.canRead,
                    permission.canWrite,
                    permission.canShare,
                    createdAt,
                    permission.updatedAt
                ]
            )
            return existing == nil ? .inserted : .updated
        }
    }

    func replaceSharedArtifactPermissions(
        sourceArtifactID: String,
        permissions: [SharedArtifactPermissionRecord]
    ) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM artifact_permissions WHERE sourceArtifactID = ?",
                arguments: [sourceArtifactID]
            )
            guard permissions.isEmpty == false else { return }

            for permission in permissions {
                guard permission.sourceArtifactID == sourceArtifactID else { continue }
                try db.execute(
                    sql: """
                    INSERT INTO artifact_permissions (
                        sourceArtifactID, workspaceID, teamID, principalType, principalID,
                        role, visibility, canRead, canWrite, canShare, createdAt, updatedAt
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        permission.sourceArtifactID,
                        permission.workspaceID,
                        permission.teamID,
                        permission.principalType.rawValue,
                        permission.principalID,
                        permission.role.rawValue,
                        permission.visibility.rawValue,
                        permission.canRead,
                        permission.canWrite,
                        permission.canShare,
                        permission.createdAt,
                        permission.updatedAt
                    ]
                )
            }
        }
    }

    func fetchSharedArtifactPermissions(
        sourceArtifactID: String?,
        workspaceID: String?,
        teamID: String?,
        principalType: SharedArtifactPrincipalType?,
        principalID: String?,
        limit: Int
    ) throws -> [SharedArtifactPermissionRecord] {
        var clauses: [String] = []
        var args: [any DatabaseValueConvertible] = []

        if let sourceArtifactID = sourceArtifactID?.trimmingCharacters(in: .whitespacesAndNewlines), sourceArtifactID.isEmpty == false {
            clauses.append("sourceArtifactID = ?")
            args.append(sourceArtifactID)
        }
        if let workspaceID = workspaceID?.trimmingCharacters(in: .whitespacesAndNewlines), workspaceID.isEmpty == false {
            clauses.append("workspaceID = ?")
            args.append(workspaceID)
        }
        if let teamID = teamID?.trimmingCharacters(in: .whitespacesAndNewlines), teamID.isEmpty == false {
            clauses.append("teamID = ?")
            args.append(teamID)
        }
        if let principalType {
            clauses.append("principalType = ?")
            args.append(principalType.rawValue)
        }
        if let principalID = principalID?.trimmingCharacters(in: .whitespacesAndNewlines), principalID.isEmpty == false {
            clauses.append("principalID = ?")
            args.append(principalID)
        }

        args.append(max(1, limit))
        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")

        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM artifact_permissions
                \(whereSQL)
                ORDER BY updatedAt DESC, sourceArtifactID ASC, principalType ASC, principalID ASC
                LIMIT ?
                """,
                arguments: StatementArguments(args)
            )
            return rows.compactMap(Self.sharedArtifactPermission(from:))
        }
    }

    func countSharedArtifactPermissions(
        sourceArtifactID: String?,
        workspaceID: String?,
        teamID: String?,
        principalType: SharedArtifactPrincipalType?,
        principalID: String?
    ) throws -> Int {
        var clauses: [String] = []
        var args: [any DatabaseValueConvertible] = []

        if let sourceArtifactID = sourceArtifactID?.trimmingCharacters(in: .whitespacesAndNewlines), sourceArtifactID.isEmpty == false {
            clauses.append("sourceArtifactID = ?")
            args.append(sourceArtifactID)
        }
        if let workspaceID = workspaceID?.trimmingCharacters(in: .whitespacesAndNewlines), workspaceID.isEmpty == false {
            clauses.append("workspaceID = ?")
            args.append(workspaceID)
        }
        if let teamID = teamID?.trimmingCharacters(in: .whitespacesAndNewlines), teamID.isEmpty == false {
            clauses.append("teamID = ?")
            args.append(teamID)
        }
        if let principalType {
            clauses.append("principalType = ?")
            args.append(principalType.rawValue)
        }
        if let principalID = principalID?.trimmingCharacters(in: .whitespacesAndNewlines), principalID.isEmpty == false {
            clauses.append("principalID = ?")
            args.append(principalID)
        }

        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        return try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM artifact_permissions
                \(whereSQL)
                """,
                arguments: StatementArguments(args)
            ) ?? 0
        }
    }

    func fetchReadableSharedArtifactSourceIDs(
        accessContext: SharedArtifactAccessContext,
        limit: Int
    ) throws -> [String] {
        guard limit > 0 else { return [] }

        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT DISTINCT s.id AS sourceArtifactID
                FROM source_artifacts AS s
                LEFT JOIN shared_artifact_sync_state AS sas
                    ON sas.sourceArtifactID = s.id
                WHERE s.sourceKind = ?
                  AND s.status = ?
                  AND (
                      EXISTS (
                          SELECT 1
                          FROM artifact_permissions AS ap
                          WHERE ap.sourceArtifactID = s.id
                            AND ap.canRead = 1
                            AND ap.workspaceID = ?
                            AND (
                                (ap.principalType = ? AND ap.principalID = ?)
                                OR (ap.principalType = ? AND ap.principalID = ? AND ap.teamID = ?)
                                OR (ap.principalType = ? AND ap.principalID = ?)
                            )
                      )
                      OR (
                          sas.workspaceID = ?
                          AND sas.teamID = ?
                          AND sas.ownerUserID = ?
                      )
                  )
                ORDER BY s.updatedAt DESC, s.id ASC
                LIMIT ?
                """,
                arguments: [
                    SearchSourceKind.sharedArtifact.rawValue,
                    SourceArtifactStatus.active.rawValue,
                    accessContext.workspaceID,
                    SharedArtifactPrincipalType.user.rawValue,
                    accessContext.userID,
                    SharedArtifactPrincipalType.team.rawValue,
                    accessContext.teamID,
                    accessContext.teamID,
                    SharedArtifactPrincipalType.workspace.rawValue,
                    accessContext.workspaceID,
                    accessContext.workspaceID,
                    accessContext.teamID,
                    accessContext.userID,
                    limit
                ]
            )
            return rows.compactMap { $0["sourceArtifactID"] as? String }
        }
    }

    func appendSharedArtifactAuditEvent(_ event: SharedArtifactAuditEventRecord) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO audit_events (
                    id, sourceArtifactID, remoteArtifactID, workspaceID, teamID,
                    actorUserID, actorRole, action, detailsJSON, occurredAt, createdAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO NOTHING
                """,
                arguments: [
                    event.id,
                    event.sourceArtifactID,
                    event.remoteArtifactID,
                    event.workspaceID,
                    event.teamID,
                    event.actorUserID,
                    event.actorRole?.rawValue,
                    event.action.rawValue,
                    event.detailsJSON,
                    event.occurredAt,
                    event.createdAt
                ]
            )
        }
    }

    func fetchSharedArtifactAuditEvents(
        sourceArtifactID: String?,
        workspaceID: String?,
        teamID: String?,
        actions: [SharedArtifactAuditAction]?,
        limit: Int
    ) throws -> [SharedArtifactAuditEventRecord] {
        if let actions, actions.isEmpty { return [] }

        var clauses: [String] = []
        var args: [any DatabaseValueConvertible] = []

        if let sourceArtifactID = sourceArtifactID?.trimmingCharacters(in: .whitespacesAndNewlines), sourceArtifactID.isEmpty == false {
            clauses.append("sourceArtifactID = ?")
            args.append(sourceArtifactID)
        }
        if let workspaceID = workspaceID?.trimmingCharacters(in: .whitespacesAndNewlines), workspaceID.isEmpty == false {
            clauses.append("workspaceID = ?")
            args.append(workspaceID)
        }
        if let teamID = teamID?.trimmingCharacters(in: .whitespacesAndNewlines), teamID.isEmpty == false {
            clauses.append("teamID = ?")
            args.append(teamID)
        }
        if let actions, actions.isEmpty == false {
            clauses.append("action IN (\(Self.sqlPlaceholders(count: actions.count)))")
            args.append(contentsOf: actions.map(\.rawValue))
        }

        args.append(max(1, limit))
        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")

        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM audit_events
                \(whereSQL)
                ORDER BY occurredAt DESC, id ASC
                LIMIT ?
                """,
                arguments: StatementArguments(args)
            )
            return rows.compactMap(Self.sharedArtifactAuditEvent(from:))
        }
    }

    func countSharedArtifactAuditEvents(
        sourceArtifactID: String?,
        workspaceID: String?,
        teamID: String?,
        actions: [SharedArtifactAuditAction]?
    ) throws -> Int {
        if let actions, actions.isEmpty { return 0 }

        var clauses: [String] = []
        var args: [any DatabaseValueConvertible] = []

        if let sourceArtifactID = sourceArtifactID?.trimmingCharacters(in: .whitespacesAndNewlines), sourceArtifactID.isEmpty == false {
            clauses.append("sourceArtifactID = ?")
            args.append(sourceArtifactID)
        }
        if let workspaceID = workspaceID?.trimmingCharacters(in: .whitespacesAndNewlines), workspaceID.isEmpty == false {
            clauses.append("workspaceID = ?")
            args.append(workspaceID)
        }
        if let teamID = teamID?.trimmingCharacters(in: .whitespacesAndNewlines), teamID.isEmpty == false {
            clauses.append("teamID = ?")
            args.append(teamID)
        }
        if let actions, actions.isEmpty == false {
            clauses.append("action IN (\(Self.sqlPlaceholders(count: actions.count)))")
            args.append(contentsOf: actions.map(\.rawValue))
        }

        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        return try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM audit_events
                \(whereSQL)
                """,
                arguments: StatementArguments(args)
            ) ?? 0
        }
    }

    func enqueueProjectionJob(_ job: ProjectionJobRecord) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO projection_jobs (
                    id, jobType, sourceKind, sourceID, sourceVersionID, status, priority, attempts,
                    maxAttempts, payloadJSON, lastErrorCode, lastErrorMessage, scheduledAt, availableAt,
                    startedAt, completedAt, leaseOwner, leaseExpiresAt, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    jobType = excluded.jobType,
                    sourceKind = excluded.sourceKind,
                    sourceID = excluded.sourceID,
                    sourceVersionID = excluded.sourceVersionID,
                    status = excluded.status,
                    priority = excluded.priority,
                    attempts = excluded.attempts,
                    maxAttempts = excluded.maxAttempts,
                    payloadJSON = excluded.payloadJSON,
                    lastErrorCode = excluded.lastErrorCode,
                    lastErrorMessage = excluded.lastErrorMessage,
                    scheduledAt = excluded.scheduledAt,
                    availableAt = excluded.availableAt,
                    startedAt = excluded.startedAt,
                    completedAt = excluded.completedAt,
                    leaseOwner = excluded.leaseOwner,
                    leaseExpiresAt = excluded.leaseExpiresAt,
                    updatedAt = excluded.updatedAt
                WHERE projection_jobs.status IN ('queued', 'failed', 'canceled')
                """,
                arguments: [
                    job.id,
                    job.jobType.rawValue,
                    job.sourceKind?.rawValue,
                    job.sourceID,
                    job.sourceVersionID,
                    job.status.rawValue,
                    job.priority,
                    job.attempts,
                    job.maxAttempts,
                    job.payloadJSON,
                    job.lastErrorCode,
                    job.lastErrorMessage,
                    job.scheduledAt,
                    job.availableAt,
                    job.startedAt,
                    job.completedAt,
                    job.leaseOwner,
                    job.leaseExpiresAt,
                    job.createdAt,
                    job.updatedAt
                ]
            )
        }
    }

    func fetchProjectionJobs(statuses: [ProjectionJobStatus], limit: Int) throws -> [ProjectionJobRecord] {
        guard statuses.isEmpty == false else { return [] }
        let placeholders = statuses.map { _ in "?" }.joined(separator: ", ")
        var args: [any DatabaseValueConvertible] = statuses.map { $0.rawValue }
        args.append(limit)
        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM projection_jobs
                WHERE status IN (\(placeholders))
                ORDER BY priority ASC, availableAt ASC, createdAt ASC
                LIMIT ?
                """,
                arguments: StatementArguments(args)
            )
            return rows.compactMap(Self.projectionJob(from:))
        }
    }

    func countProjectionJobs(statuses: [ProjectionJobStatus]?) throws -> Int {
        let normalizedStatuses = statuses ?? ProjectionJobStatus.allCases
        guard normalizedStatuses.isEmpty == false else { return 0 }
        let placeholders = normalizedStatuses.map { _ in "?" }.joined(separator: ", ")
        let args: [any DatabaseValueConvertible] = normalizedStatuses.map(\.rawValue)

        return try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM projection_jobs
                WHERE status IN (\(placeholders))
                """,
                arguments: StatementArguments(args)
            ) ?? 0
        }
    }

    func leaseNextJob(leaseOwner: String, leaseExpiresAt: Date, now: Date) throws -> ProjectionJobRecord? {
        try dbQueue.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT * FROM projection_jobs
                WHERE (
                    (
                        status IN (?, ?)
                        AND availableAt <= ?
                    )
                    OR (
                        status IN (?, ?)
                        AND leaseExpiresAt IS NOT NULL
                        AND leaseExpiresAt <= ?
                    )
                )
                AND attempts < maxAttempts
                ORDER BY priority ASC, availableAt ASC, createdAt ASC
                LIMIT 1
                """,
                arguments: [
                    ProjectionJobStatus.queued.rawValue,
                    ProjectionJobStatus.failed.rawValue,
                    now,
                    ProjectionJobStatus.leased.rawValue,
                    ProjectionJobStatus.running.rawValue,
                    now
                ]
            ) else {
                return nil
            }

            guard let job = Self.projectionJob(from: row) else { return nil }
            try db.execute(
                sql: """
                UPDATE projection_jobs
                SET status = ?, leaseOwner = ?, leaseExpiresAt = ?, startedAt = COALESCE(startedAt, ?), updatedAt = ?
                WHERE id = ?
                """,
                arguments: [
                    ProjectionJobStatus.running.rawValue,
                    leaseOwner,
                    leaseExpiresAt,
                    now,
                    now,
                    job.id
                ]
            )
            return try Row.fetchOne(
                db,
                sql: "SELECT * FROM projection_jobs WHERE id = ?",
                arguments: [job.id]
            ).flatMap(Self.projectionJob(from:))
        }
    }

    func markJobLeased(id: String, leaseOwner: String, leaseExpiresAt: Date, updatedAt: Date) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE projection_jobs
                SET status = ?, leaseOwner = ?, leaseExpiresAt = ?, startedAt = COALESCE(startedAt, ?), updatedAt = ?
                WHERE id = ?
                """,
                arguments: [ProjectionJobStatus.leased.rawValue, leaseOwner, leaseExpiresAt, updatedAt, updatedAt, id]
            )
        }
    }

    func markJobCompleted(id: String, completedAt: Date) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE projection_jobs
                SET status = ?, completedAt = ?, leaseOwner = NULL, leaseExpiresAt = NULL,
                    lastErrorCode = NULL, lastErrorMessage = NULL, updatedAt = ?
                WHERE id = ?
                """,
                arguments: [ProjectionJobStatus.completed.rawValue, completedAt, completedAt, id]
            )
        }
    }

    func markJobFailed(
        id: String,
        errorCode: String?,
        errorMessage: String?,
        retryAt: Date?,
        updatedAt: Date
    ) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE projection_jobs
                SET status = ?, attempts = attempts + 1, leaseOwner = NULL, leaseExpiresAt = NULL,
                    lastErrorCode = ?, lastErrorMessage = ?, availableAt = COALESCE(?, availableAt), updatedAt = ?
                WHERE id = ?
                """,
                arguments: [ProjectionJobStatus.failed.rawValue, errorCode, errorMessage, retryAt, updatedAt, id]
            )
        }
    }

    func markJobCanceled(
        id: String,
        errorCode: String?,
        errorMessage: String?,
        updatedAt: Date
    ) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE projection_jobs
                SET status = ?, leaseOwner = NULL, leaseExpiresAt = NULL,
                    lastErrorCode = ?, lastErrorMessage = ?, updatedAt = ?
                WHERE id = ?
                """,
                arguments: [ProjectionJobStatus.canceled.rawValue, errorCode, errorMessage, updatedAt, id]
            )
        }
    }

    func deleteDocuments(sourceKind: SearchSourceKind, sourceID: String) throws {
        try dbQueue.write { db in
            let documentIDs = try String.fetchAll(
                db,
                sql: """
                SELECT id
                FROM search_documents
                WHERE sourceKind = ? AND sourceID = ?
                """,
                arguments: [sourceKind.rawValue, sourceID]
            )

            for documentID in documentIDs {
                try db.execute(
                    sql: "DELETE FROM search_chunks_fts WHERE documentID = ?",
                    arguments: [documentID]
                )
            }

            try db.execute(
                sql: """
                DELETE FROM search_documents
                WHERE sourceKind = ? AND sourceID = ?
                """,
                arguments: [sourceKind.rawValue, sourceID]
            )
        }
    }

    func upsertEmbeddingModel(_ model: EmbeddingModelRecord) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO embedding_models (
                    id, provider, modelName, dimensions, distanceMetric, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    provider = excluded.provider,
                    modelName = excluded.modelName,
                    dimensions = excluded.dimensions,
                    distanceMetric = excluded.distanceMetric,
                    updatedAt = excluded.updatedAt
                """,
                arguments: [
                    model.id,
                    model.provider,
                    model.modelName,
                    model.dimensions,
                    model.distanceMetric.rawValue,
                    model.createdAt,
                    model.updatedAt
                ]
            )
        }
    }

    func fetchEmbeddingModels() throws -> [EmbeddingModelRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM embedding_models
                ORDER BY provider ASC, modelName ASC
                """
            )
            return rows.compactMap(Self.embeddingModel(from:))
        }
    }

    func countEmbeddingModels() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM embedding_models"
            ) ?? 0
        }
    }

    func upsertEmbeddingVersion(_ version: EmbeddingVersionRecord) throws {
        try dbQueue.write { db in
            if version.isActive {
                try db.execute(
                    sql: "UPDATE embedding_versions SET isActive = 0, updatedAt = ? WHERE modelID = ?",
                    arguments: [version.updatedAt, version.modelID]
                )
            }

            try db.execute(
                sql: """
                INSERT INTO embedding_versions (
                    id, modelID, versionTag, chunkerVersion, normalizationVersion,
                    promptVersion, isActive, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    modelID = excluded.modelID,
                    versionTag = excluded.versionTag,
                    chunkerVersion = excluded.chunkerVersion,
                    normalizationVersion = excluded.normalizationVersion,
                    promptVersion = excluded.promptVersion,
                    isActive = excluded.isActive,
                    updatedAt = excluded.updatedAt
                """,
                arguments: [
                    version.id,
                    version.modelID,
                    version.versionTag,
                    version.chunkerVersion,
                    version.normalizationVersion,
                    version.promptVersion,
                    version.isActive,
                    version.createdAt,
                    version.updatedAt
                ]
            )
        }
    }

    func fetchEmbeddingVersions(modelID: String?) throws -> [EmbeddingVersionRecord] {
        try dbQueue.read { db in
            let rows: [Row]
            if let modelID {
                rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT * FROM embedding_versions
                    WHERE modelID = ?
                    ORDER BY isActive DESC, createdAt DESC
                    """,
                    arguments: [modelID]
                )
            } else {
                rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT * FROM embedding_versions
                    ORDER BY modelID ASC, isActive DESC, createdAt DESC
                    """
                )
            }
            return rows.compactMap(Self.embeddingVersion(from:))
        }
    }

    func countEmbeddingVersions(modelID: String?) throws -> Int {
        try dbQueue.read { db in
            if let modelID {
                return try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM embedding_versions WHERE modelID = ?",
                    arguments: [modelID]
                ) ?? 0
            }

            return try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM embedding_versions"
            ) ?? 0
        }
    }

    func upsertChunkEmbedding(_ embedding: ChunkEmbeddingRecord) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO chunk_embeddings (
                    chunkID, embeddingVersionID, vectorBlob, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(chunkID, embeddingVersionID) DO UPDATE SET
                    vectorBlob = excluded.vectorBlob,
                    updatedAt = excluded.updatedAt
                """,
                arguments: [
                    embedding.chunkID,
                    embedding.embeddingVersionID,
                    embedding.vectorBlob,
                    embedding.createdAt,
                    embedding.updatedAt
                ]
            )
        }
    }

    func fetchChunkEmbeddings(chunkID: String?) throws -> [ChunkEmbeddingRecord] {
        try dbQueue.read { db in
            let rows: [Row]
            if let chunkID {
                rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT * FROM chunk_embeddings
                    WHERE chunkID = ?
                    ORDER BY embeddingVersionID ASC
                    """,
                    arguments: [chunkID]
                )
            } else {
                rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT * FROM chunk_embeddings
                    ORDER BY chunkID ASC, embeddingVersionID ASC
                    """
                )
            }
            return rows.compactMap(Self.chunkEmbedding(from:))
        }
    }

    func fetchChunkEmbeddings(embeddingVersionID: String) throws -> [ChunkEmbeddingRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM chunk_embeddings
                WHERE embeddingVersionID = ?
                ORDER BY chunkID ASC
                """,
                arguments: [embeddingVersionID]
            )
            return rows.compactMap(Self.chunkEmbedding(from:))
        }
    }

    func countChunkEmbeddings(
        chunkID: String?,
        embeddingVersionID: String?
    ) throws -> Int {
        var clauses: [String] = []
        var args: [any DatabaseValueConvertible] = []

        if let chunkID, chunkID.isEmpty == false {
            clauses.append("chunkID = ?")
            args.append(chunkID)
        }
        if let embeddingVersionID, embeddingVersionID.isEmpty == false {
            clauses.append("embeddingVersionID = ?")
            args.append(embeddingVersionID)
        }

        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        return try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM chunk_embeddings
                \(whereSQL)
                """,
                arguments: StatementArguments(args)
            ) ?? 0
        }
    }

    func countChunkEmbeddings(
        documentID: String,
        embeddingVersionID: String?
    ) throws -> Int {
        var clauses: [String] = ["c.documentID = ?"]
        var args: [any DatabaseValueConvertible] = [documentID]

        if let embeddingVersionID, embeddingVersionID.isEmpty == false {
            clauses.append("e.embeddingVersionID = ?")
            args.append(embeddingVersionID)
        }

        return try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM chunk_embeddings AS e
                JOIN search_chunks AS c ON c.id = e.chunkID
                WHERE \(clauses.joined(separator: " AND "))
                """,
                arguments: StatementArguments(args)
            ) ?? 0
        }
    }

    func upsertRetrievalHealth(_ health: RetrievalHealthRecord) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO retrieval_health (
                    subsystem, status, errorCode, errorMessage, detailsJSON, observedAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(subsystem) DO UPDATE SET
                    status = excluded.status,
                    errorCode = excluded.errorCode,
                    errorMessage = excluded.errorMessage,
                    detailsJSON = excluded.detailsJSON,
                    observedAt = excluded.observedAt,
                    updatedAt = excluded.updatedAt
                """,
                arguments: [
                    health.subsystem.rawValue,
                    health.status.rawValue,
                    health.errorCode,
                    health.errorMessage,
                    health.detailsJSON,
                    health.observedAt,
                    health.updatedAt
                ]
            )
        }
    }

    func fetchRetrievalHealth() throws -> [RetrievalHealthRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM retrieval_health
                ORDER BY subsystem ASC
                """
            )
            return rows.compactMap(Self.retrievalHealth(from:))
        }
    }

    func schemaInventory() throws -> LocalSearchSchemaInventory {
        let expectedTables = [
            "controller_runtime_cache",
            "search_documents",
            "search_chunks",
            "search_chunks_fts",
            "search_documents_fts",
            "projection_jobs",
            "embedding_models",
            "embedding_versions",
            "chunk_embeddings",
            "retrieval_health",
            "artifact_permissions",
            "audit_events",
            "operating_action_history",
        ]
        let expectedIndexes = [
            "controller_runtime_cache_updated_idx",
            "search_documents_source_lookup_idx",
            "search_documents_project_provider_idx",
            "search_chunks_unique_document_ordinal_idx",
            "search_chunks_document_offset_idx",
            "search_chunks_source_lookup_idx",
            "projection_jobs_poll_idx",
            "projection_jobs_source_lookup_idx",
            "embedding_models_provider_model_idx",
            "embedding_versions_identity_idx",
            "embedding_versions_active_idx",
            "chunk_embeddings_version_lookup_idx",
            "artifact_permissions_principal_lookup_idx",
            "artifact_permissions_source_lookup_idx",
            "audit_events_source_time_idx",
            "audit_events_scope_time_idx",
            "audit_events_action_time_idx",
            "operating_action_history_project_time_idx",
            "operating_action_history_kind_time_idx",
            "operating_action_history_mission_time_idx",
        ]

        return try dbQueue.read { db in
            let tables = try String.fetchAll(
                db,
                sql: """
                SELECT name
                FROM sqlite_master
                WHERE type = 'table' AND name IN (\(Self.sqlPlaceholders(count: expectedTables.count)))
                ORDER BY name ASC
                """,
                arguments: StatementArguments(expectedTables)
            )
            let indexes = try String.fetchAll(
                db,
                sql: """
                SELECT name
                FROM sqlite_master
                WHERE type = 'index' AND name IN (\(Self.sqlPlaceholders(count: expectedIndexes.count)))
                ORDER BY name ASC
                """,
                arguments: StatementArguments(expectedIndexes)
            )
            return LocalSearchSchemaInventory(tables: tables, indexes: indexes)
        }
    }

    private static func document(from row: Row) -> SearchDocumentRecord? {
        guard
            let id = row["id"] as? String,
            let sourceKindRaw = row["sourceKind"] as? String,
            let sourceKind = SearchSourceKind(rawValue: sourceKindRaw),
            let sourceID = row["sourceID"] as? String,
            let title = row["title"] as? String
        else {
            return nil
        }
        let indexedAt = parseDateValue(row["indexedAt"]) ?? Date()
        let createdAt = parseDateValue(row["createdAt"]) ?? indexedAt
        let updatedAt = parseDateValue(row["updatedAt"]) ?? createdAt
        return SearchDocumentRecord(
            id: id,
            sourceKind: sourceKind,
            sourceID: sourceID,
            sourceVersionID: (row["sourceVersionID"] as? String) ?? "",
            provider: row["provider"] as? String,
            projectName: row["projectName"] as? String,
            title: title,
            subtitle: row["subtitle"] as? String,
            bodyPreview: row["bodyPreview"] as? String,
            sourceUpdatedAt: parseDateValue(row["sourceUpdatedAt"]),
            indexedAt: indexedAt,
            contentHash: row["contentHash"] as? String,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func filteredDocumentClause(
        provider: String?,
        projectName: String?,
        sourceKinds: [SearchSourceKind]?,
        dateRange: ClosedRange<Date>?
    ) -> (String, [any DatabaseValueConvertible]) {
        let trimmedProjectName = projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedProjectName = (trimmedProjectName?.isEmpty == false) ? trimmedProjectName : nil
        let normalizedSourceKinds = Array(Set(sourceKinds ?? []))
            .sorted { $0.rawValue < $1.rawValue }

        var clauses: [String] = []
        var args: [any DatabaseValueConvertible] = []

        if let provider, provider.isEmpty == false {
            clauses.append("provider = ?")
            args.append(provider)
        }

        if let normalizedProjectName {
            clauses.append("projectName = ?")
            args.append(normalizedProjectName)
        }

        if normalizedSourceKinds.isEmpty == false {
            clauses.append("sourceKind IN (\(Self.sqlPlaceholders(count: normalizedSourceKinds.count)))")
            args.append(contentsOf: normalizedSourceKinds.map(\.rawValue))
        }

        if let dateRange {
            clauses.append("COALESCE(sourceUpdatedAt, indexedAt) >= ?")
            clauses.append("COALESCE(sourceUpdatedAt, indexedAt) <= ?")
            args.append(dateRange.lowerBound)
            args.append(dateRange.upperBound)
        }

        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        return (whereSQL, args)
    }

    private static func matchSnippet(text: NSString, matchRange: NSRange, radius: Int = 120) -> String {
        let start = max(0, matchRange.location - radius)
        let end = min(text.length, matchRange.location + matchRange.length + radius)
        let snippetRange = NSRange(location: start, length: max(0, end - start))
        let raw = text.substring(with: snippetRange)
        let compact = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var prefix = ""
        var suffix = ""
        if start > 0 { prefix = "..." }
        if end < text.length { suffix = "..." }
        return prefix + compact + suffix
    }

    private static func chunk(from row: Row) -> SearchChunkRecord? {
        guard
            let id = row["id"] as? String,
            let documentID = row["documentID"] as? String,
            let sourceKindRaw = row["sourceKind"] as? String,
            let sourceKind = SearchSourceKind(rawValue: sourceKindRaw),
            let sourceID = row["sourceID"] as? String
        else {
            return nil
        }

        let ordinal = (row["ordinal"] as? Int) ?? Int(row["ordinal"] as? Int64 ?? 0)
        let startOffset = (row["startOffset"] as? Int) ?? Int(row["startOffset"] as? Int64 ?? 0)
        let endOffset = (row["endOffset"] as? Int) ?? Int(row["endOffset"] as? Int64 ?? 0)
        let messageStartOffset = (row["messageStartOffset"] as? Int) ?? Int(row["messageStartOffset"] as? Int64 ?? -1)
        let messageEndOffset = (row["messageEndOffset"] as? Int) ?? Int(row["messageEndOffset"] as? Int64 ?? -1)
        let createdAt = parseDateValue(row["createdAt"]) ?? Date.distantPast
        let updatedAt = parseDateValue(row["updatedAt"]) ?? createdAt
        let text = (row["text"] as? String) ?? ""
        return SearchChunkRecord(
            id: id,
            documentID: documentID,
            sourceKind: sourceKind,
            sourceID: sourceID,
            sourceVersionID: (row["sourceVersionID"] as? String) ?? "",
            ordinal: ordinal,
            startOffset: startOffset,
            endOffset: endOffset,
            messageStartOffset: messageStartOffset >= 0 ? messageStartOffset : nil,
            messageEndOffset: messageEndOffset >= 0 ? messageEndOffset : nil,
            sectionPath: row["sectionPath"] as? String,
            text: text,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func lexicalMatch(from row: Row) -> SearchChunkLexicalMatch? {
        guard
            let chunkID = row["chunkID"] as? String,
            let documentID = row["documentID"] as? String,
            let sourceKindRaw = row["sourceKind"] as? String,
            let sourceKind = SearchSourceKind(rawValue: sourceKindRaw),
            let sourceID = row["sourceID"] as? String,
            let title = row["title"] as? String
        else {
            return nil
        }

        let lexicalRankRaw = (row["lexicalRank"] as? Double) ?? Double(row["lexicalRank"] as? Int64 ?? 0)
        let chunkOrdinal = (row["chunkOrdinal"] as? Int) ?? Int(row["chunkOrdinal"] as? Int64 ?? 0)
        let startOffset = (row["startOffset"] as? Int) ?? Int(row["startOffset"] as? Int64 ?? 0)
        let endOffset = (row["endOffset"] as? Int) ?? Int(row["endOffset"] as? Int64 ?? 0)

        return SearchChunkLexicalMatch(
            chunkID: chunkID,
            documentID: documentID,
            sourceKind: sourceKind,
            sourceID: sourceID,
            sourceVersionID: (row["sourceVersionID"] as? String) ?? "",
            provider: row["provider"] as? String,
            projectName: row["projectName"] as? String,
            title: title,
            subtitle: row["subtitle"] as? String,
            bodyPreview: row["bodyPreview"] as? String,
            sourceUpdatedAt: parseDateValue(row["sourceUpdatedAt"]),
            indexedAt: parseDateValue(row["indexedAt"]) ?? Date.distantPast,
            chunkOrdinal: chunkOrdinal,
            startOffset: startOffset,
            endOffset: endOffset,
            sectionPath: row["sectionPath"] as? String,
            chunkText: (row["chunkText"] as? String) ?? "",
            snippet: (row["snippet"] as? String) ?? "",
            lexicalRank: lexicalRankRaw
        )
    }

    private static func sourceArtifact(from row: Row) -> SourceArtifactRecord? {
        guard
            let id = row["id"] as? String,
            let sourceKindRaw = row["sourceKind"] as? String,
            let sourceKind = SearchSourceKind(rawValue: sourceKindRaw),
            let canonicalPath = row["canonicalPath"] as? String,
            let rootPath = row["rootPath"] as? String,
            let relativePath = row["relativePath"] as? String,
            let provenance = row["provenance"] as? String,
            let title = row["title"] as? String,
            let body = row["body"] as? String,
            let contentHash = row["contentHash"] as? String
        else {
            return nil
        }
        let fileSizeBytes = (row["fileSizeBytes"] as? Int) ?? Int(row["fileSizeBytes"] as? Int64 ?? 0)
        let discoveredAt = parseDateValue(row["discoveredAt"]) ?? Date()
        let createdAt = parseDateValue(row["createdAt"]) ?? discoveredAt
        let updatedAt = parseDateValue(row["updatedAt"]) ?? createdAt
        let deletedAt = parseDateValue(row["deletedAt"])
        let statusRaw = (row["status"] as? String) ?? SourceArtifactStatus.active.rawValue
        let status = SourceArtifactStatus(rawValue: statusRaw) ?? .active

        return SourceArtifactRecord(
            id: id,
            sourceKind: sourceKind,
            canonicalPath: canonicalPath,
            rootPath: rootPath,
            relativePath: relativePath,
            provenance: provenance,
            title: title,
            body: body,
            contentHash: contentHash,
            fileSizeBytes: fileSizeBytes,
            fileModifiedAt: parseDateValue(row["fileModifiedAt"]),
            status: status,
            discoveredAt: discoveredAt,
            deletedAt: deletedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func sharedArtifactSyncState(from row: Row) -> SharedArtifactSyncStateRecord? {
        guard
            let sourceArtifactID = row["sourceArtifactID"] as? String,
            let remoteArtifactID = row["remoteArtifactID"] as? String,
            let workspaceID = row["workspaceID"] as? String,
            let teamID = row["teamID"] as? String,
            let revisionID = row["revisionID"] as? String
        else {
            return nil
        }

        let statusRaw = (row["syncStatus"] as? String) ?? SharedArtifactSyncStatus.pendingPull.rawValue
        let syncStatus = SharedArtifactSyncStatus(rawValue: statusRaw) ?? .pendingPull
        let createdAt = parseDateValue(row["createdAt"]) ?? Date()
        let updatedAt = parseDateValue(row["updatedAt"]) ?? createdAt

        return SharedArtifactSyncStateRecord(
            sourceArtifactID: sourceArtifactID,
            remoteArtifactID: remoteArtifactID,
            workspaceID: workspaceID,
            teamID: teamID,
            ownerUserID: row["ownerUserID"] as? String,
            revisionID: revisionID,
            remoteContentHash: row["remoteContentHash"] as? String,
            localContentHashAtSync: row["localContentHashAtSync"] as? String,
            remoteUpdatedAt: parseDateValue(row["remoteUpdatedAt"]),
            lastPulledAt: parseDateValue(row["lastPulledAt"]),
            lastSyncedAt: parseDateValue(row["lastSyncedAt"]),
            syncStatus: syncStatus,
            lastErrorCode: row["lastErrorCode"] as? String,
            lastErrorMessage: row["lastErrorMessage"] as? String,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func sharedArtifactPermission(from row: Row) -> SharedArtifactPermissionRecord? {
        guard
            let sourceArtifactID = row["sourceArtifactID"] as? String,
            let workspaceID = row["workspaceID"] as? String,
            let teamID = row["teamID"] as? String,
            let principalTypeRaw = row["principalType"] as? String,
            let principalType = SharedArtifactPrincipalType(rawValue: principalTypeRaw),
            let principalID = row["principalID"] as? String,
            let roleRaw = row["role"] as? String,
            let role = SharedArtifactRole(rawValue: roleRaw),
            let visibilityRaw = row["visibility"] as? String,
            let visibility = SharedArtifactVisibility(rawValue: visibilityRaw)
        else {
            return nil
        }

        let createdAt = parseDateValue(row["createdAt"]) ?? Date()
        let updatedAt = parseDateValue(row["updatedAt"]) ?? createdAt

        return SharedArtifactPermissionRecord(
            sourceArtifactID: sourceArtifactID,
            workspaceID: workspaceID,
            teamID: teamID,
            principalType: principalType,
            principalID: principalID,
            role: role,
            visibility: visibility,
            canRead: parseBoolValue(row["canRead"]) ?? true,
            canWrite: parseBoolValue(row["canWrite"]) ?? false,
            canShare: parseBoolValue(row["canShare"]) ?? false,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func sharedArtifactAuditEvent(from row: Row) -> SharedArtifactAuditEventRecord? {
        guard
            let id = row["id"] as? String,
            let workspaceID = row["workspaceID"] as? String,
            let teamID = row["teamID"] as? String,
            let actionRaw = row["action"] as? String,
            let action = SharedArtifactAuditAction(rawValue: actionRaw)
        else {
            return nil
        }
        let occurredAt = parseDateValue(row["occurredAt"]) ?? Date()
        let createdAt = parseDateValue(row["createdAt"]) ?? occurredAt
        let actorRole = (row["actorRole"] as? String).flatMap(SharedArtifactRole.init(rawValue:))

        return SharedArtifactAuditEventRecord(
            id: id,
            sourceArtifactID: row["sourceArtifactID"] as? String,
            remoteArtifactID: row["remoteArtifactID"] as? String,
            workspaceID: workspaceID,
            teamID: teamID,
            actorUserID: row["actorUserID"] as? String,
            actorRole: actorRole,
            action: action,
            detailsJSON: row["detailsJSON"] as? String,
            occurredAt: occurredAt,
            createdAt: createdAt
        )
    }

    private static func operatingActionRecord(from row: Row) -> BurnBarOperatingActionRecord? {
        guard
            let id = row["id"] as? String,
            let projectName = row["projectName"] as? String,
            let actionKindRaw = row["actionKind"] as? String,
            let actionKind = BurnBarActionKind(rawValue: actionKindRaw),
            let summary = row["summary"] as? String
        else {
            return nil
        }

        return BurnBarOperatingActionRecord(
            id: id,
            projectName: projectName,
            missionFingerprint: row["missionFingerprint"] as? String,
            actionKind: actionKind,
            summary: summary,
            detail: row["detail"] as? String,
            overrideMode: (row["overrideMode"] as? String).flatMap(BurnBarDirectionOverrideModeKind.init(rawValue:)),
            forcedDirectionStatus: (row["forcedDirectionStatus"] as? String).flatMap(BurnBarDirectionAssessment.init(rawValue:)),
            createdAt: parseDateValue(row["createdAt"]) ?? Date()
        )
    }

    private static func permissionSemanticsEqual(
        _ lhs: SharedArtifactPermissionRecord,
        _ rhs: SharedArtifactPermissionRecord
    ) -> Bool {
        lhs.sourceArtifactID == rhs.sourceArtifactID
            && lhs.workspaceID == rhs.workspaceID
            && lhs.teamID == rhs.teamID
            && lhs.principalType == rhs.principalType
            && lhs.principalID == rhs.principalID
            && lhs.role == rhs.role
            && lhs.visibility == rhs.visibility
            && lhs.canRead == rhs.canRead
            && lhs.canWrite == rhs.canWrite
            && lhs.canShare == rhs.canShare
    }

    private static func projectionJob(from row: Row) -> ProjectionJobRecord? {
        guard
            let id = row["id"] as? String,
            let jobTypeRaw = row["jobType"] as? String,
            let jobType = ProjectionJobType(rawValue: jobTypeRaw),
            let statusRaw = row["status"] as? String,
            let status = ProjectionJobStatus(rawValue: statusRaw)
        else {
            return nil
        }

        let priority = (row["priority"] as? Int) ?? Int(row["priority"] as? Int64 ?? 0)
        let attempts = (row["attempts"] as? Int) ?? Int(row["attempts"] as? Int64 ?? 0)
        let maxAttempts = (row["maxAttempts"] as? Int) ?? Int(row["maxAttempts"] as? Int64 ?? 0)
        let scheduledAt = parseDateValue(row["scheduledAt"]) ?? Date()
        let availableAt = parseDateValue(row["availableAt"]) ?? scheduledAt
        let createdAt = parseDateValue(row["createdAt"]) ?? scheduledAt
        let updatedAt = parseDateValue(row["updatedAt"]) ?? createdAt
        let sourceKind = (row["sourceKind"] as? String).flatMap(SearchSourceKind.init(rawValue:))

        return ProjectionJobRecord(
            id: id,
            jobType: jobType,
            sourceKind: sourceKind,
            sourceID: row["sourceID"] as? String,
            sourceVersionID: (row["sourceVersionID"] as? String) ?? "",
            status: status,
            priority: priority,
            attempts: attempts,
            maxAttempts: maxAttempts,
            payloadJSON: row["payloadJSON"] as? String,
            lastErrorCode: row["lastErrorCode"] as? String,
            lastErrorMessage: row["lastErrorMessage"] as? String,
            scheduledAt: scheduledAt,
            availableAt: availableAt,
            startedAt: parseDateValue(row["startedAt"]),
            completedAt: parseDateValue(row["completedAt"]),
            leaseOwner: row["leaseOwner"] as? String,
            leaseExpiresAt: parseDateValue(row["leaseExpiresAt"]),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func embeddingModel(from row: Row) -> EmbeddingModelRecord? {
        guard
            let id = row["id"] as? String,
            let provider = row["provider"] as? String,
            let modelName = row["modelName"] as? String,
            let distanceMetricRaw = row["distanceMetric"] as? String,
            let distanceMetric = EmbeddingDistanceMetric(rawValue: distanceMetricRaw)
        else {
            return nil
        }
        let dimensions = (row["dimensions"] as? Int) ?? Int(row["dimensions"] as? Int64 ?? 0)
        let createdAt = parseDateValue(row["createdAt"]) ?? Date()
        let updatedAt = parseDateValue(row["updatedAt"]) ?? createdAt
        return EmbeddingModelRecord(
            id: id,
            provider: provider,
            modelName: modelName,
            dimensions: dimensions,
            distanceMetric: distanceMetric,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func embeddingVersion(from row: Row) -> EmbeddingVersionRecord? {
        guard
            let id = row["id"] as? String,
            let modelID = row["modelID"] as? String,
            let versionTag = row["versionTag"] as? String,
            let chunkerVersion = row["chunkerVersion"] as? String,
            let normalizationVersion = row["normalizationVersion"] as? String,
            let promptVersion = row["promptVersion"] as? String
        else {
            return nil
        }
        let isActiveRaw: Bool
        if let boolValue = row["isActive"] as? Bool {
            isActiveRaw = boolValue
        } else if let intValue = row["isActive"] as? Int {
            isActiveRaw = intValue == 1
        } else if let int64Value = row["isActive"] as? Int64 {
            isActiveRaw = int64Value == 1
        } else {
            isActiveRaw = false
        }
        let createdAt = parseDateValue(row["createdAt"]) ?? Date()
        let updatedAt = parseDateValue(row["updatedAt"]) ?? createdAt
        return EmbeddingVersionRecord(
            id: id,
            modelID: modelID,
            versionTag: versionTag,
            chunkerVersion: chunkerVersion,
            normalizationVersion: normalizationVersion,
            promptVersion: promptVersion,
            isActive: isActiveRaw,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func chunkEmbedding(from row: Row) -> ChunkEmbeddingRecord? {
        guard
            let chunkID = row["chunkID"] as? String,
            let embeddingVersionID = row["embeddingVersionID"] as? String,
            let vectorBlob = row["vectorBlob"] as? Data
        else {
            return nil
        }
        let createdAt = parseDateValue(row["createdAt"]) ?? Date()
        let updatedAt = parseDateValue(row["updatedAt"]) ?? createdAt
        return ChunkEmbeddingRecord(
            chunkID: chunkID,
            embeddingVersionID: embeddingVersionID,
            vectorBlob: vectorBlob,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func retrievalHealth(from row: Row) -> RetrievalHealthRecord? {
        guard
            let subsystemRaw = row["subsystem"] as? String,
            let subsystem = RetrievalSubsystem(rawValue: subsystemRaw),
            let statusRaw = row["status"] as? String,
            let status = RetrievalHealthStatus(rawValue: statusRaw)
        else {
            return nil
        }
        let observedAt = parseDateValue(row["observedAt"]) ?? Date()
        let updatedAt = parseDateValue(row["updatedAt"]) ?? observedAt
        return RetrievalHealthRecord(
            subsystem: subsystem,
            status: status,
            errorCode: row["errorCode"] as? String,
            errorMessage: row["errorMessage"] as? String,
            detailsJSON: row["detailsJSON"] as? String,
            observedAt: observedAt,
            updatedAt: updatedAt
        )
    }

    private static func sqlPlaceholders(count: Int) -> String {
        Array(repeating: "?", count: max(0, count)).joined(separator: ", ")
    }

    private static func parseDateValue(_ value: Any?) -> Date? {
        if let date = value as? Date { return date }
        if let timeInterval = value as? TimeInterval {
            return Date(timeIntervalSince1970: timeInterval)
        }
        if let intValue = value as? Int {
            return Date(timeIntervalSince1970: TimeInterval(intValue))
        }
        if let int64Value = value as? Int64 {
            return Date(timeIntervalSince1970: TimeInterval(int64Value))
        }
        if let number = value as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }
        if let string = value as? String {
            if let parsed = sqliteDateFormatter.date(from: string) { return parsed }
            return ISO8601DateFormatter().date(from: string)
        }
        return nil
    }

    private static func parseBoolValue(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? Int { return value != 0 }
        if let value = value as? Int64 { return value != 0 }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String {
            switch value.lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    private static let sqliteDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
