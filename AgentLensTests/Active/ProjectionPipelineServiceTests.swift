import XCTest
import GRDB
import OpenBurnBarCore
@testable import OpenBurnBar
@MainActor
final class ProjectionPipelineServiceTests: XCTestCase {
    func test_projectionWorker_recoversExpiredRunningJob_afterCrash() async throws {
        let store = try makeDiscoveryInMemoryStore()
        let service = ProjectionPipelineService(dataStore: store, leaseOwner: "worker-recovery")

        let conversation = makeConversation(
            id: "conv-crash",
            fullText: "Line 1\nLine 2\nLine 3",
            indexedAt: Date(timeIntervalSince1970: 1_742_200_000)
        )
        try store.upsertConversation(conversation)

        let sourceVersionID = ProjectionIdentity.conversationSourceVersionID(for: conversation)
        let expiredLeaseTime = Date(timeIntervalSince1970: 1_742_200_010)
        try store.enqueueProjectionJob(
            ProjectionJobRecord(
                id: ProjectionIdentity.jobID(
                    jobType: .project,
                    sourceKind: .conversation,
                    sourceID: conversation.id,
                    sourceVersionID: sourceVersionID
                ),
                jobType: .project,
                sourceKind: .conversation,
                sourceID: conversation.id,
                sourceVersionID: sourceVersionID,
                status: .running,
                priority: 5,
                attempts: 0,
                maxAttempts: 5,
                scheduledAt: expiredLeaseTime,
                availableAt: expiredLeaseTime,
                startedAt: expiredLeaseTime,
                leaseOwner: "stale-worker",
                leaseExpiresAt: expiredLeaseTime.addingTimeInterval(-30),
                createdAt: expiredLeaseTime,
                updatedAt: expiredLeaseTime
            )
        )

        let report = try await service.runSweep(maxJobs: 5)
        XCTAssertGreaterThanOrEqual(report.completedJobs, 1)

        let completed = try store.fetchProjectionJobs(statuses: [.completed], limit: 20)
        XCTAssertTrue(completed.contains(where: { $0.sourceID == conversation.id }))

        let documents = try store.fetchSearchDocuments(limit: 20)
        guard let projectedConversationDocument = documents.first(where: { $0.sourceID == conversation.id }) else {
            return XCTFail("Expected projected document for crash-recovered conversation.")
        }
        let chunks = try store.fetchSearchChunks(documentID: projectedConversationDocument.id)
        XCTAssertFalse(chunks.isEmpty)
    }

    func test_projectionJob_enqueueSuppression_preventsDuplicateRequeueAfterCompletion() async throws {
        let store = try makeDiscoveryInMemoryStore()
        let service = ProjectionPipelineService(dataStore: store, leaseOwner: "worker-duplicates")
        let now = Date(timeIntervalSince1970: 1_742_300_000)

        let conversation = makeConversation(id: "conv-dedupe", fullText: String(repeating: "abc ", count: 500), indexedAt: now)
        try store.upsertConversation(conversation)

        let sourceVersionID = ProjectionIdentity.conversationSourceVersionID(for: conversation)
        let job = ProjectionJobRecord(
            id: ProjectionIdentity.jobID(
                jobType: .project,
                sourceKind: .conversation,
                sourceID: conversation.id,
                sourceVersionID: sourceVersionID
            ),
            jobType: .project,
            sourceKind: .conversation,
            sourceID: conversation.id,
            sourceVersionID: sourceVersionID,
            status: .queued,
            priority: 5,
            attempts: 0,
            maxAttempts: 5,
            scheduledAt: now,
            availableAt: now,
            createdAt: now,
            updatedAt: now
        )

        try store.enqueueProjectionJob(job)
        try store.enqueueProjectionJob(job)
        _ = try await service.runSweep(maxJobs: 10)

        let documents = try store.fetchSearchDocuments(limit: 10)
        XCTAssertEqual(documents.count, 1)
        let chunkCount = try store.fetchSearchChunks(documentID: documents[0].id).count
        XCTAssertGreaterThan(chunkCount, 1)

        try store.enqueueProjectionJob(job)
        XCTAssertTrue(try store.fetchProjectionJobs(statuses: [.queued], limit: 10).isEmpty)

        let secondSweep = try await service.runSweep(maxJobs: 10)
        XCTAssertEqual(secondSweep.completedJobs, 0)
        let secondChunkCount = try store.fetchSearchChunks(documentID: documents[0].id).count
        XCTAssertEqual(secondChunkCount, chunkCount)
    }

    func test_projectionPipeline_handlesArtifactDeleteWithPurgeJob() async throws {
        let store = try makeDiscoveryInMemoryStore()
        let service = ProjectionPipelineService(dataStore: store, leaseOwner: "worker-purge")
        let base = Date(timeIntervalSince1970: 1_742_400_000)

        let artifact = SourceArtifactRecord(
            id: "artifact-delete",
            sourceKind: .agentDoc,
            canonicalPath: "/tmp/project/AGENTS.md",
            rootPath: "/tmp/project",
            relativePath: "AGENTS.md",
            provenance: "basename:AGENTS.MD",
            title: "Agent Guide",
            body: "# Agent Guide\nRun tests first.",
            contentHash: "hash-delete-v1",
            fileSizeBytes: 42,
            fileModifiedAt: base,
            status: .active,
            discoveredAt: base,
            deletedAt: nil,
            createdAt: base,
            updatedAt: base
        )
        _ = try store.upsertSourceArtifact(artifact)

        try service.enqueueSelectiveReproject(
            sourceKind: artifact.sourceKind,
            sourceID: artifact.id,
            sourceVersionID: ProjectionIdentity.artifactSourceVersionID(contentHash: artifact.contentHash),
            jobType: .project,
            priority: 5
        )
        _ = try await service.runSweep(maxJobs: 10)
        XCTAssertEqual(try store.fetchSearchDocuments(limit: 10).count, 1)

        XCTAssertTrue(try store.markSourceArtifactDeleted(id: artifact.id, deletedAt: base.addingTimeInterval(60)))
        try service.enqueueSelectiveReproject(
            sourceKind: artifact.sourceKind,
            sourceID: artifact.id,
            sourceVersionID: ProjectionIdentity.deletedSourceVersionID,
            jobType: .purge,
            priority: 2
        )
        _ = try await service.runSweep(maxJobs: 10)

        XCTAssertEqual(try store.fetchSearchDocuments(limit: 10).count, 0)
    }

    func test_rebuildJob_enqueuesReprojectAndPurgeCandidates() async throws {
        let store = try makeDiscoveryInMemoryStore()
        let service = ProjectionPipelineService(dataStore: store, leaseOwner: "worker-rebuild")
        let base = Date(timeIntervalSince1970: 1_742_500_000)

        let conversation = makeConversation(id: "conv-rebuild", fullText: "Need to rebuild projections.", indexedAt: base)
        try store.upsertConversation(conversation)

        let activeArtifact = SourceArtifactRecord(
            id: "artifact-active",
            sourceKind: .skillDoc,
            canonicalPath: "/tmp/repo/SKILL.md",
            rootPath: "/tmp/repo",
            relativePath: "SKILL.md",
            provenance: "basename:SKILL.MD",
            title: "Skill",
            body: "# Skill\nDo this.",
            contentHash: "hash-active",
            fileSizeBytes: 24,
            fileModifiedAt: base,
            status: .active,
            discoveredAt: base,
            deletedAt: nil,
            createdAt: base,
            updatedAt: base
        )
        _ = try store.upsertSourceArtifact(activeArtifact)

        let deletedArtifact = SourceArtifactRecord(
            id: "artifact-deleted",
            sourceKind: .agentDoc,
            canonicalPath: "/tmp/repo/AGENTS.md",
            rootPath: "/tmp/repo",
            relativePath: "AGENTS.md",
            provenance: "basename:AGENTS.MD",
            title: "Agents",
            body: "# Agents\nLegacy",
            contentHash: "hash-deleted",
            fileSizeBytes: 24,
            fileModifiedAt: base,
            status: .active,
            discoveredAt: base,
            deletedAt: nil,
            createdAt: base,
            updatedAt: base
        )
        _ = try store.upsertSourceArtifact(deletedArtifact)
        XCTAssertTrue(try store.markSourceArtifactDeleted(id: deletedArtifact.id, deletedAt: base.addingTimeInterval(120)))

        try service.enqueueRebuildJob(reason: "test-rebuild", priority: 1)
        let rebuildReport = try await service.runSweep(maxJobs: 1)
        XCTAssertEqual(rebuildReport.completedJobs, 1)

        let queued = try store.fetchProjectionJobs(statuses: [.queued], limit: 20)
        XCTAssertTrue(queued.contains(where: { $0.sourceKind == .conversation && $0.sourceID == conversation.id && $0.jobType == .reproject }))
        XCTAssertTrue(queued.contains(where: { $0.sourceKind == activeArtifact.sourceKind && $0.sourceID == activeArtifact.id && $0.jobType == .reproject }))
        XCTAssertTrue(queued.contains(where: { $0.sourceKind == deletedArtifact.sourceKind && $0.sourceID == deletedArtifact.id && $0.jobType == .purge }))
    }

    func test_projectionPipeline_indexesEmbeddings_withActiveVersionLineage() async throws {
        let store = try makeDiscoveryInMemoryStore()
        let embedder = DeterministicFakeEmbeddingProvider(versionTag: "projection-test-v1", seed: "projection-seed-v1")
        let service = ProjectionPipelineService(
            dataStore: store,
            leaseOwner: "worker-embedding-lineage",
            chunkEmbedder: embedder
        )
        let base = Date(timeIntervalSince1970: 1_742_510_000)

        let conversation = makeConversation(
            id: "conv-embedding-lineage",
            fullText: "Embedding lineage test for hybrid retrieval indexing.",
            indexedAt: base
        )
        try store.upsertConversation(conversation)
        try store.enqueueConversationProjectionJob(conversationID: conversation.id, jobType: .project, now: base)
        _ = try await service.runSweep(maxJobs: 20)

        let expectedModelID = EmbeddingIdentity.modelID(for: embedder.descriptor)
        let expectedVersionID = EmbeddingIdentity.versionID(for: embedder.descriptor)

        XCTAssertEqual(try store.fetchEmbeddingModels().map(\.id), [expectedModelID])
        XCTAssertEqual(try store.fetchEmbeddingVersions(modelID: expectedModelID).first?.id, expectedVersionID)
        XCTAssertEqual(try store.fetchEmbeddingVersions(modelID: expectedModelID).first?.isActive, true)

        guard
            let document = try store.fetchSearchDocuments(limit: 20).first(where: { $0.sourceID == conversation.id })
        else {
            return XCTFail("Expected projected conversation document for embedding lineage test.")
        }
        let chunks = try store.fetchSearchChunks(documentID: document.id)
        XCTAssertFalse(chunks.isEmpty)

        let indexedEmbeddings = try store.fetchChunkEmbeddings(embeddingVersionID: expectedVersionID)
        XCTAssertEqual(Set(indexedEmbeddings.map(\.chunkID)), Set(chunks.map(\.id)))
        if let firstVector = indexedEmbeddings.first?.vectorBlob, let decoded = VectorBlobCodec.decode(firstVector) {
            XCTAssertEqual(decoded.count, embedder.descriptor.dimensions)
        } else {
            XCTFail("Expected a decodable embedding vector.")
        }
    }

    func test_reembedJob_createsNewActiveEmbeddingVersion_withoutRemovingPreviousVersion() async throws {
        let store = try makeDiscoveryInMemoryStore()
        let embedderV1 = DeterministicFakeEmbeddingProvider(versionTag: "projection-test-v1", seed: "projection-seed-a")
        let serviceV1 = ProjectionPipelineService(
            dataStore: store,
            leaseOwner: "worker-reembed-v1",
            chunkEmbedder: embedderV1
        )
        let base = Date(timeIntervalSince1970: 1_742_520_000)
        let conversation = makeConversation(
            id: "conv-reembed",
            fullText: "Re-embed this conversation into the new embedding version.",
            indexedAt: base
        )
        try store.upsertConversation(conversation)
        try store.enqueueConversationProjectionJob(conversationID: conversation.id, jobType: .project, now: base)
        _ = try await serviceV1.runSweep(maxJobs: 20)

        guard
            let document = try store.fetchSearchDocuments(limit: 20).first(where: { $0.sourceID == conversation.id }),
            let chunk = try store.fetchSearchChunks(documentID: document.id).first
        else {
            return XCTFail("Expected projected chunk before re-embed.")
        }

        let versionV1ID = EmbeddingIdentity.versionID(for: embedderV1.descriptor)
        guard
            let blobV1 = try store.fetchChunkEmbeddings(chunkID: chunk.id).first(where: { $0.embeddingVersionID == versionV1ID })?.vectorBlob
        else {
            return XCTFail("Expected initial embedding for first version.")
        }

        let embedderV2 = DeterministicFakeEmbeddingProvider(versionTag: "projection-test-v2", seed: "projection-seed-b")
        let serviceV2 = ProjectionPipelineService(
            dataStore: store,
            leaseOwner: "worker-reembed-v2",
            chunkEmbedder: embedderV2
        )
        try serviceV2.enqueueReembedJob(
            reason: "test-reembed",
            sourceKind: .conversation,
            sourceID: conversation.id,
            priority: 1
        )
        _ = try await serviceV2.runSweep(maxJobs: 20)

        let versionV2ID = EmbeddingIdentity.versionID(for: embedderV2.descriptor)
        let chunkEmbeddings = try store.fetchChunkEmbeddings(chunkID: chunk.id)
        XCTAssertTrue(chunkEmbeddings.contains { $0.embeddingVersionID == versionV1ID })
        XCTAssertTrue(chunkEmbeddings.contains { $0.embeddingVersionID == versionV2ID })
        XCTAssertNotEqual(
            chunkEmbeddings.first(where: { $0.embeddingVersionID == versionV2ID })?.vectorBlob,
            blobV1
        )

        let modelID = EmbeddingIdentity.modelID(for: embedderV2.descriptor)
        XCTAssertEqual(try store.fetchEmbeddingVersions(modelID: modelID).first?.id, versionV2ID)
        XCTAssertEqual(try store.fetchEmbeddingVersions(modelID: modelID).first?.isActive, true)
    }

    func test_timestampNormalization_convertsMillisecondEpochToSeconds() {
        let milliseconds = 1_774_329_122_146.0
        let normalized = TimestampNormalizationUtility.normalizedEpochSeconds(milliseconds)

        XCTAssertNotNil(normalized)
        XCTAssertEqual(normalized ?? 0, milliseconds / 1000.0, accuracy: 0.0001)
    }

    func test_timestampNormalization_firestoreSafeDateRepairsMillisecondAsSecondDate() {
        let invalidDate = Date(timeIntervalSince1970: 1_774_329_122_146.0)
        let safeDate = TimestampNormalizationUtility.firestoreSafeDate(invalidDate)

        XCTAssertEqual(safeDate.timeIntervalSince1970, 1_774_329_122.146, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(
            safeDate.timeIntervalSince1970,
            TimestampNormalizationUtility.firestoreMaxEpochSeconds
        )
    }

    private func makeConversation(id: String, fullText: String, indexedAt: Date) -> ConversationRecord {
        ConversationRecord(
            id: id,
            provider: .claudeCode,
            sessionId: "session-\(id)",
            projectName: "OpenBurnBar",
            startTime: indexedAt.addingTimeInterval(-60),
            endTime: indexedAt,
            messageCount: 4,
            userWordCount: 20,
            assistantWordCount: 40,
            keyFiles: ["DataStore.swift"],
            keyCommands: ["swift test"],
            keyTools: ["Read"],
            inferredTaskTitle: "Projection Test",
            lastAssistantMessage: "Done.",
            fullText: fullText,
            indexedAt: indexedAt,
            fileModifiedAt: indexedAt,
            summary: nil,
            summaryTitle: nil,
            summaryUpdatedAt: nil,
            summaryProvider: nil,
            summaryModel: nil,
            sourceType: .providerLog
        )
    }
}
