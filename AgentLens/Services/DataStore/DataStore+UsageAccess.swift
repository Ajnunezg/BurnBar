import Foundation
import OpenBurnBarCore

extension DataStore {
    func insert(_ usage: TokenUsage) throws {
        try usageStore.insert(usage)
    }

    func insert(_ newUsages: [TokenUsage]) throws {
        try usageStore.insert(newUsages)
    }

    func deleteAll() throws {
        try usageStore.deleteAll()
        refresh()
    }

    func deleteUsage(sessionIDPrefix: String) throws {
        try usageStore.deleteUsage(sessionIDPrefix: sessionIDPrefix)
    }

    func fetchUnsynced() throws -> [TokenUsage] {
        try usageStore.fetchUnsynced()
    }

    func markSynced(ids: [UUID]) throws {
        try usageStore.markSynced(ids: ids)
    }

    func sessionModelMap() throws -> [String: String] {
        try usageStore.sessionModelMap()
    }

    func insertRemoteUsage(_ usage: TokenUsage) throws {
        try usageStore.insertRemoteUsage(usage)
    }
}
