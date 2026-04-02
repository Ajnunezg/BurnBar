import Foundation
import BurnBarCore

// MARK: - Vector Candidate Backend Protocol

/// Protocol for vector search backends that can find similar vectors.
protocol VectorCandidateBackend: AnyObject {
    /// Unique identifier for this backend.
    var id: String { get }

    /// Rebuilds the index with new entries.
    func rebuild(entries: [VectorIndexEntry], distanceMetric: EmbeddingDistanceMetric) throws

    /// Finds the top-k candidates most similar to the query vector.
    func candidates(for queryVector: [Float], limit: Int) throws -> [VectorIndexCandidate]
}

// MARK: - Exact Vector Backend

/// Exact k-NN search backend that scans all vectors.
/// Provides perfect accuracy but has O(n) time complexity.
final class ExactVectorCandidateBackend: VectorCandidateBackend {
    let id = "exact_scan_v1"
    private var entries: [VectorIndexEntry] = []
    private var distanceMetric: EmbeddingDistanceMetric = .cosine
    private var dimensions = 0

    func rebuild(entries: [VectorIndexEntry], distanceMetric: EmbeddingDistanceMetric) throws {
        self.entries = entries
        self.distanceMetric = distanceMetric
        self.dimensions = entries.first?.vector.count ?? 0
    }

    func candidates(for queryVector: [Float], limit: Int) throws -> [VectorIndexCandidate] {
        guard limit > 0, entries.isEmpty == false else { return [] }
        guard dimensions == 0 || queryVector.count == dimensions else {
            throw VectorIndexBackendError.dimensionMismatch(expected: dimensions, actual: queryVector.count)
        }

        var scored: [VectorIndexCandidate] = []
        scored.reserveCapacity(entries.count)
        for entry in entries {
            let score = VectorMath.similarity(lhs: queryVector, rhs: entry.vector, metric: distanceMetric)
            guard score.isFinite else { continue }
            scored.append(VectorIndexCandidate(chunkID: entry.chunkID, score: score))
        }

        scored.sort {
            if $0.score == $1.score {
                return $0.chunkID < $1.chunkID
            }
            return $0.score > $1.score
        }

        if scored.count > limit {
            return Array(scored.prefix(limit))
        }
        return scored
    }
}

// MARK: - Signpost ANN Backend

/// Approximate Nearest Neighbor backend using signpost (binary hashing) indexing.
/// Provides fast O(1) lookup with good accuracy for L2-normalized vectors.
final class SignpostANNVectorCandidateBackend: VectorCandidateBackend {
    let id = "ann_signpost_v1"

    private let bucketBits: Int
    private let candidateMultiplier: Int
    private let maxHammingDistance: Int
    private var distanceMetric: EmbeddingDistanceMetric = .cosine
    private var dimensions = 0
    private var buckets: [UInt64: [VectorIndexEntry]] = [:]
    private var allEntries: [VectorIndexEntry] = []

    init(
        bucketBits: Int = 12,
        candidateMultiplier: Int = 6,
        maxHammingDistance: Int = 1
    ) {
        self.bucketBits = max(4, min(bucketBits, 24))
        self.candidateMultiplier = max(2, candidateMultiplier)
        self.maxHammingDistance = max(0, min(maxHammingDistance, 2))
    }

    func rebuild(entries: [VectorIndexEntry], distanceMetric: EmbeddingDistanceMetric) throws {
        self.distanceMetric = distanceMetric
        self.dimensions = entries.first?.vector.count ?? 0
        self.buckets.removeAll(keepingCapacity: true)
        self.allEntries = entries.sorted { $0.chunkID < $1.chunkID }

        for entry in allEntries {
            guard dimensions == 0 || entry.vector.count == dimensions else { continue }
            let signature = signature(for: entry.vector)
            buckets[signature, default: []].append(entry)
        }
    }

    func candidates(for queryVector: [Float], limit: Int) throws -> [VectorIndexCandidate] {
        guard limit > 0, allEntries.isEmpty == false else { return [] }
        guard dimensions == 0 || queryVector.count == dimensions else {
            throw VectorIndexBackendError.dimensionMismatch(expected: dimensions, actual: queryVector.count)
        }

        let signature = signature(for: queryVector)
        let targetCount = min(allEntries.count, max(limit * candidateMultiplier, limit))
        var selectedIDs: [String] = []
        selectedIDs.reserveCapacity(targetCount)
        var seen = Set<String>()

        func appendBucket(_ key: UInt64) {
            guard let entries = buckets[key], entries.isEmpty == false else { return }
            for entry in entries {
                guard seen.insert(entry.chunkID).inserted else { continue }
                selectedIDs.append(entry.chunkID)
                if selectedIDs.count >= targetCount { break }
            }
        }

        appendBucket(signature)

        if selectedIDs.count < targetCount, maxHammingDistance > 0 {
            for distance in 1...maxHammingDistance {
                for neighbor in neighbors(of: signature, distance: distance).sorted() {
                    appendBucket(neighbor)
                    if selectedIDs.count >= targetCount { break }
                }
                if selectedIDs.count >= targetCount { break }
            }
        }

        if selectedIDs.count < limit {
            for entry in allEntries {
                guard seen.insert(entry.chunkID).inserted else { continue }
                selectedIDs.append(entry.chunkID)
                if selectedIDs.count >= targetCount { break }
            }
        }

        let selectedEntries = Dictionary(uniqueKeysWithValues: allEntries.map { ($0.chunkID, $0) })
        var scored: [VectorIndexCandidate] = []
        scored.reserveCapacity(selectedIDs.count)
        for chunkID in selectedIDs {
            guard let entry = selectedEntries[chunkID] else { continue }
            let score = VectorMath.similarity(lhs: queryVector, rhs: entry.vector, metric: distanceMetric)
            guard score.isFinite else { continue }
            scored.append(VectorIndexCandidate(chunkID: entry.chunkID, score: score))
        }

        scored.sort {
            if $0.score == $1.score {
                return $0.chunkID < $1.chunkID
            }
            return $0.score > $1.score
        }
        if scored.count > limit {
            return Array(scored.prefix(limit))
        }
        return scored
    }

    private func signature(for vector: [Float]) -> UInt64 {
        guard vector.isEmpty == false else { return 0 }
        var signature: UInt64 = 0
        for bit in 0..<bucketBits {
            let index = dimension(forBit: bit, dimensions: vector.count)
            if vector[index] >= 0 {
                signature |= (UInt64(1) << UInt64(bit))
            }
        }
        return signature
    }

    private func dimension(forBit bit: Int, dimensions: Int) -> Int {
        let prime = 2_147_483_647
        let raw = (bit * 73_856_093 + 19_349_663) % prime
        return raw % max(1, dimensions)
    }

    private func neighbors(of signature: UInt64, distance: Int) -> [UInt64] {
        guard distance > 0 else { return [signature] }
        if distance == 1 {
            return (0..<bucketBits).map { bit in
                signature ^ (UInt64(1) << UInt64(bit))
            }
        }

        guard distance == 2 else { return [signature] }
        var values: [UInt64] = []
        values.reserveCapacity(bucketBits * max(0, bucketBits - 1) / 2)
        for first in 0..<bucketBits {
            for second in (first + 1)..<bucketBits {
                values.append(signature ^ (UInt64(1) << UInt64(first)) ^ (UInt64(1) << UInt64(second)))
            }
        }
        return values
    }
}
