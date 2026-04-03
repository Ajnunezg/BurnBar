import Foundation

enum ProviderQuotaPersistenceTarget: String, CaseIterable, Sendable {
    case snapshots
    case codexRolloutScanCache

    var label: String {
        switch self {
        case .snapshots:
            return "provider quota snapshot store"
        case .codexRolloutScanCache:
            return "Codex rollout scan cache"
        }
    }
}

enum ProviderQuotaPersistenceLoadResult<Value> {
    case missing
    case loaded(Value)
    case failed(target: ProviderQuotaPersistenceTarget, message: String)
}

struct ProviderQuotaSnapshotStore {
    let appPaths: BurnBarAppPaths
    let fileManager: FileManager

    func loadPersistedSnapshots() -> ProviderQuotaPersistenceLoadResult<(snapshots: [AgentProvider: ProviderQuotaSnapshot], lastFetch: Date?)> {
        guard fileManager.fileExists(atPath: appPaths.providerQuotaSnapshotsURL.path) else {
            return .missing
        }
        do {
            let data = try Data(contentsOf: appPaths.providerQuotaSnapshotsURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshots = try decoder.decode([ProviderQuotaSnapshot].self, from: data)
            let dict = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.provider, $0) })
            let lastFetch = snapshots.map(\.fetchedAt).max()
            return .loaded((dict, lastFetch))
        } catch {
            return .failed(
                target: .snapshots,
                message: "BurnBar could not load the persisted \(ProviderQuotaPersistenceTarget.snapshots.label): \(error.localizedDescription)"
            )
        }
    }

    func persistSnapshots(_ snapshotsByProvider: [AgentProvider: ProviderQuotaSnapshot]) {
        do {
            try ensureParentDirectory(for: appPaths.providerQuotaSnapshotsURL)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(
                snapshotsByProvider.values.sorted { $0.provider.displayName < $1.provider.displayName }
            )
            try data.write(to: appPaths.providerQuotaSnapshotsURL, options: .atomic)
        } catch {
            AppLogger.dataStore.silentFailure("ProviderQuotaService: Failed to persist snapshots", error: error)
        }
    }

    func loadPersistedCodexRolloutScanCache() -> ProviderQuotaPersistenceLoadResult<CodexRolloutScanCache> {
        guard fileManager.fileExists(atPath: appPaths.codexRolloutScanCacheURL.path) else {
            return .missing
        }
        do {
            let data = try Data(contentsOf: appPaths.codexRolloutScanCacheURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return .loaded(try decoder.decode(CodexRolloutScanCache.self, from: data))
        } catch {
            return .failed(
                target: .codexRolloutScanCache,
                message: "BurnBar could not load the persisted \(ProviderQuotaPersistenceTarget.codexRolloutScanCache.label): \(error.localizedDescription)"
            )
        }
    }

    func persistCodexRolloutScanCache(_ cache: CodexRolloutScanCache) {
        do {
            try ensureParentDirectory(for: appPaths.codexRolloutScanCacheURL)
            var updatedCache = cache
            updatedCache.lastUpdatedAt = Date()

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(updatedCache)
            try data.write(to: appPaths.codexRolloutScanCacheURL, options: .atomic)
        } catch {
            AppLogger.dataStore.silentFailure("ProviderQuotaService: Failed to persist codex scan cache", error: error)
        }
    }

    func ensureParentDirectory(for url: URL) throws {
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    func readJSONObject(from url: URL) throws -> [String: Any]? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any]
    }

    func writeJSONObject(_ object: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    func modificationDate(for url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }
}
