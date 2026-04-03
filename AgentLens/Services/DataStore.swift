import Foundation
import GRDB
import SwiftUI
import BurnBarCore

// MARK: - Device Record
enum DeviceHardwareIcon {
    /// All SF Symbols available for device icon customization.
    static let allIcons: [(symbol: String, label: String)] = [
        ("macbook", "MacBook"),
        ("macmini", "Mac mini"),
        ("macpro.gen3", "Mac Pro"),
        ("macstudio", "Mac Studio"),
        ("desktopcomputer", "iMac / Desktop"),
        ("display", "Display"),
        ("laptopcomputer", "Laptop"),
        ("server.rack", "Server"),
        ("cpu", "Workstation"),
        ("terminal", "Terminal"),
    ]

    // Apple Silicon Macs use generic "MacXX,YY" identifiers.
    // This table maps known model numbers to device types.
    private static let genericMacMap: [String: String] = [
        // Mac mini M4 / M4 Pro (2024)
        "mac16,1": "macmini", "mac16,2": "macmini", "mac16,3": "macmini",
        "mac16,4": "macmini", "mac16,5": "macmini", "mac16,10": "macmini",
        "mac16,11": "macmini", "mac16,12": "macmini",
        // MacBook Pro M4 (2024)
        "mac16,6": "macbook", "mac16,7": "macbook", "mac16,8": "macbook",
        "mac16,9": "macbook",
        // MacBook Air M4 (2025)
        "mac16,13": "macbook", "mac16,14": "macbook", "mac16,15": "macbook",
        // iMac M4 (2024)
        "mac16,16": "desktopcomputer", "mac16,17": "desktopcomputer",
        // Mac Studio M4 Max/Ultra (2025)
        "mac16,20": "macstudio", "mac16,21": "macstudio",
        // Mac Pro M2 Ultra
        "mac14,8": "macpro.gen3",
        // Mac Studio M2 Max/Ultra
        "mac14,13": "macstudio", "mac14,14": "macstudio",
        // Mac mini M2/M2 Pro
        "mac14,3": "macmini", "mac14,12": "macmini",
        // Mac Studio M1 Max/Ultra
        "mac13,1": "macstudio", "mac13,2": "macstudio",
        // Mac mini M1
        "mac14,1": "macmini",
        // MacBook Pro M3 (2023)
        "mac15,3": "macbook", "mac15,6": "macbook", "mac15,7": "macbook",
        "mac15,8": "macbook", "mac15,9": "macbook", "mac15,10": "macbook",
        "mac15,11": "macbook",
        // MacBook Air M3 (2024)
        "mac15,12": "macbook", "mac15,13": "macbook",
        // iMac M3 (2023)
        "mac15,4": "desktopcomputer", "mac15,5": "desktopcomputer",
    ]

    static func sfSymbol(for hardwareModel: String?) -> String {
        guard let hw = hardwareModel?.lowercased() else { return "desktopcomputer" }

        // Legacy-style identifiers (Intel era, some early AS)
        if hw.hasPrefix("macbookpro") || hw.hasPrefix("macbookair") || hw.hasPrefix("macbook") {
            return "macbook"
        }
        if hw.hasPrefix("macmini") {
            return "macmini"
        }
        if hw.hasPrefix("macpro") {
            return "macpro.gen3"
        }
        if hw.hasPrefix("imac") {
            return "desktopcomputer"
        }

        // Generic "MacXX,YY" identifiers — look up in table
        if let mapped = genericMacMap[hw] {
            return mapped
        }

        // Last resort: infer from Host.current().localizedName
        let hostName = (Host.current().localizedName ?? "").lowercased()
        if hostName.contains("macbook") || hostName.contains("laptop") { return "macbook" }
        if hostName.contains("mini") { return "macmini" }
        if hostName.contains("studio") { return "macstudio" }
        if hostName.contains("imac") { return "desktopcomputer" }
        if hostName.contains("pro") && !hostName.contains("book") { return "macpro.gen3" }

        return "desktopcomputer"
    }

    /// Reads the hardware model identifier from sysctl.
    static var localHardwareModel: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
}

// MARK: - DataStore

@Observable
@MainActor
final class DataStore {
    nonisolated static let legacyChatThreadID = "burnbar-chat-legacy"

    private let dbQueue: DatabaseQueue
    private let localSearchStore: LocalSearchStore
    private(set) var usages: [TokenUsage] = []
    private(set) var isLoading = false
    private(set) var lastRefresh: Date?

    private let sqliteDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    // MARK: - Computed Properties
    
    var totalCostToday: Double {
        let calendar = Calendar.current
        return usages
            .filter { calendar.isDateInToday($0.startTime) }
            .reduce(0) { $0 + $1.cost }
    }
    
    var totalCostThisWeek: Double {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return usages
            .filter { $0.startTime >= weekAgo }
            .reduce(0) { $0 + $1.cost }
    }
    
    var totalCostThisMonth: Double {
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return usages
            .filter { $0.startTime >= monthAgo }
            .reduce(0) { $0 + $1.cost }
    }
    
    var totalCostAllTime: Double {
        usages.reduce(0) { $0 + $1.cost }
    }

    var totalTokensToday: Int {
        let calendar = Calendar.current
        return usages
            .filter { calendar.isDateInToday($0.startTime) }
            .reduce(0) { $0 + $1.totalTokens }
    }

    var totalTokensThisWeek: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return usages
            .filter { $0.startTime >= weekAgo }
            .reduce(0) { $0 + $1.totalTokens }
    }

    var totalTokensThisMonth: Int {
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return usages
            .filter { $0.startTime >= monthAgo }
            .reduce(0) { $0 + $1.totalTokens }
    }

    var totalTokensAllTime: Int {
        usages.reduce(0) { $0 + $1.totalTokens }
    }

    /// 7-day rolling daily average (zero-fills missing days). Updated in `replaceUsages(_:)`.
    private(set) var rollingDailyAverage: Double = 0

    var moodBand: MoodBand {
        let calendar = Calendar.current
        let distinctDays = Set(usages.map { calendar.startOfDay(for: $0.startTime) })
        guard distinctDays.count >= 2 else { return .baseline }
        let today = totalCostToday
        guard today > 0 else { return .quiet }
        guard rollingDailyAverage > 0 else { return .onPace }
        let ratio = today / rollingDailyAverage
        switch ratio {
        case ..<0.8: return .light
        case 0.8..<1.2: return .onPace
        default: return .heavy
        }
    }

    var moodLabel: String {
        switch moodBand {
        case .light: return "Light day"
        case .onPace: return "On pace"
        case .heavy: return "Heavy day"
        case .baseline: return "Building baseline..."
        case .quiet: return "Quiet day"
        }
    }

    var moodColor: Color {
        switch moodBand {
        case .light: return DesignSystem.Colors.success
        case .onPace: return DesignSystem.Colors.textSecondary
        case .heavy: return DesignSystem.Colors.warning
        case .baseline, .quiet: return DesignSystem.Colors.textMuted
        }
    }

    /// Last 7 calendar days of daily cost, zero-filled, oldest first.
    var last7DayCosts: [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { offset -> Double in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let next = calendar.date(byAdding: .day, value: 1, to: day)!
            return usages
                .filter { $0.startTime >= day && $0.startTime < next }
                .reduce(0) { $0 + $1.cost }
        }
    }

    /// Last 7 calendar days of total tokens per day (for token-mode sparkline).
    var last7DayTokenTotals: [Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { offset -> Int in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let next = calendar.date(byAdding: .day, value: 1, to: day)!
            return usages
                .filter { $0.startTime >= day && $0.startTime < next }
                .reduce(0) { $0 + $1.totalTokens }
        }
    }

    /// All-time provider rollups (menu bar, etc.). Dashboard should use `providerSummaries(in:)`
    /// with the same window as the toolbar time picker.
    var providerSummaries: [ProviderSummary] {
        Self.makeProviderSummaries(from: usages)
    }

    var hasEstimatedProviders: Bool {
        providerSummaries.contains { $0.provider.dataConfidence != .exact }
    }

    /// Provider rollups for sessions whose span overlaps `dateRange`. Pass `nil` for all time.
    func providerSummaries(in dateRange: ClosedRange<Date>?) -> [ProviderSummary] {
        Self.makeProviderSummaries(from: usages(in: dateRange))
    }

    private static func makeProviderSummaries(from usages: [TokenUsage]) -> [ProviderSummary] {
        AgentProvider.allCases.compactMap { provider -> ProviderSummary? in
            let providerUsages = usages.filter { $0.provider == provider }
            guard !providerUsages.isEmpty else { return nil }

            let totalCost = providerUsages.reduce(0) { $0 + $1.cost }
            let totalTokens = providerUsages.reduce(0) { $0 + $1.totalTokens }
            let totalInputTokens = providerUsages.reduce(0) { $0 + $1.inputTokens }
            let totalOutputTokens = providerUsages.reduce(0) { $0 + $1.outputTokens }

            var modelData: [String: (input: Int, output: Int, cacheCreation: Int, cacheRead: Int, cost: Double)] = [:]
            for usage in providerUsages {
                let existing = modelData[usage.model] ?? (0, 0, 0, 0, 0)
                modelData[usage.model] = (
                    existing.0 + usage.inputTokens,
                    existing.1 + usage.outputTokens,
                    existing.2 + usage.cacheCreationTokens,
                    existing.3 + usage.cacheReadTokens,
                    existing.4 + usage.cost
                )
            }

            let modelBreakdown = modelData.map { modelName, data in
                let totalModelTokens = data.input + data.output + data.cacheCreation + data.cacheRead
                return ModelUsage(
                    modelName: modelName,
                    inputTokens: data.input,
                    outputTokens: data.output,
                    cacheCreationTokens: data.cacheCreation,
                    cacheReadTokens: data.cacheRead,
                    totalTokens: totalModelTokens,
                    cost: data.cost,
                    percentage: totalCost > 0 ? (data.cost / totalCost) * 100 : 0
                )
            }.sorted { $0.cost > $1.cost }

            return ProviderSummary(
                provider: provider,
                totalCost: totalCost,
                totalTokens: totalTokens,
                totalInputTokens: totalInputTokens,
                totalOutputTokens: totalOutputTokens,
                sessionCount: providerUsages.count,
                modelBreakdown: modelBreakdown
            )
        }.sorted { $0.totalCost > $1.totalCost }
    }

    // MARK: - Model Summaries

    var modelSummaries: [ModelSummary] {
        Self.makeModelSummaries(from: usages)
    }

    func modelSummaries(in dateRange: ClosedRange<Date>?) -> [ModelSummary] {
        Self.makeModelSummaries(from: usages(in: dateRange))
    }

    private static func makeModelSummaries(from usages: [TokenUsage]) -> [ModelSummary] {
        let grouped = Dictionary(grouping: usages) {
            TokenExtractionUtility.normalizeModelKey($0.model)
        }
        return grouped.compactMap { key, modelUsages -> ModelSummary? in
            guard !modelUsages.isEmpty else { return nil }
            let totalCost = modelUsages.reduce(0) { $0 + $1.cost }
            let totalTokens = modelUsages.reduce(0) { $0 + $1.totalTokens }
            let totalInputTokens = modelUsages.reduce(0) { $0 + $1.inputTokens }
            let totalOutputTokens = modelUsages.reduce(0) { $0 + $1.outputTokens }

            let byProvider = Dictionary(grouping: modelUsages) { $0.provider }
            let providerBreakdown = byProvider.map { provider, pUsages -> ProviderUsage in
                let pCost = pUsages.reduce(0) { $0 + $1.cost }
                let pTokens = pUsages.reduce(0) { $0 + $1.totalTokens }
                return ProviderUsage(
                    provider: provider,
                    sessionCount: pUsages.count,
                    totalTokens: pTokens,
                    cost: pCost,
                    percentage: totalCost > 0 ? (pCost / totalCost) * 100 : 0
                )
            }.sorted { $0.cost > $1.cost }

            return ModelSummary(
                modelName: key,
                displayName: TokenExtractionUtility.displayNameForModel(modelUsages.first?.model ?? key),
                totalCost: totalCost,
                totalTokens: totalTokens,
                totalInputTokens: totalInputTokens,
                totalOutputTokens: totalOutputTokens,
                sessionCount: modelUsages.count,
                providerBreakdown: providerBreakdown
            )
        }.sorted { $0.totalCost > $1.totalCost }
    }

    /// Sessions overlapping `dateRange`. `nil` means no time filter (all stored sessions).
    func usages(in dateRange: ClosedRange<Date>?) -> [TokenUsage] {
        guard let dateRange else { return usages }
        return usages.filter { $0.intersects(dateRange: dateRange) }
    }

    func usages(forModel normalizedName: String) -> [TokenUsage] {
        usages.filter { TokenExtractionUtility.normalizeModelKey($0.model) == normalizedName }
    }

    func usages(forModel normalizedName: String, in dateRange: ClosedRange<Date>) -> [TokenUsage] {
        usages.filter {
            TokenExtractionUtility.normalizeModelKey($0.model) == normalizedName
            && $0.intersects(dateRange: dateRange)
        }
    }

    var dailySummaries: [DailyUsageSummary] {
        let calendar = Calendar.current
        var dayData: [Date: [TokenUsage]] = [:]
        
        for usage in usages {
            let dayKey = calendar.startOfDay(for: usage.startTime)
            dayData[dayKey, default: []].append(usage)
        }
        
        return dayData.map { date, usages in
            DailyUsageSummary(
                date: date,
                provider: usages.first?.provider ?? .factory,
                totalInputTokens: usages.reduce(0) { $0 + $1.inputTokens },
                totalOutputTokens: usages.reduce(0) { $0 + $1.outputTokens },
                totalCacheCreationTokens: usages.reduce(0) { $0 + $1.cacheCreationTokens },
                totalCacheReadTokens: usages.reduce(0) { $0 + $1.cacheReadTokens },
                totalTokens: usages.reduce(0) { $0 + $1.totalTokens },
                totalCost: usages.reduce(0) { $0 + $1.cost },
                sessionCount: usages.count,
                models: Array(Set(usages.map { $0.model }))
            )
        }.sorted { $0.date > $1.date }
    }
    
    // MARK: - Initialization

    convenience init() throws {
        let appDir = try BurnBarMigration.prepareSupportDirectory()
        let dbPath = appDir.appendingPathComponent(BurnBarIdentity.databaseFileName).path
        let queue = try DatabaseQueue(path: dbPath)
        try self.init(databaseQueue: queue)
    }

    init(
        databaseQueue: DatabaseQueue,
        runMigrations: Bool = true,
        refreshOnInit: Bool = true
    ) throws {
        dbQueue = databaseQueue
        localSearchStore = LocalSearchStore(dbQueue: databaseQueue)

        if runMigrations {
            try migrator.migrate(databaseQueue)
        }

        if refreshOnInit {
            refresh()
        }
    }
    
    // MARK: - Database Schema
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "token_usage") { t in
                t.column("id", .text).primaryKey()
                t.column("provider", .text).notNull().indexed()
                t.column("sessionId", .text).notNull().indexed()
                t.column("projectName", .text).notNull()
                t.column("model", .text).notNull()
                t.column("inputTokens", .integer).notNull()
                t.column("outputTokens", .integer).notNull()
                t.column("cacheCreationTokens", .integer).notNull()
                t.column("cacheReadTokens", .integer).notNull()
                t.column("totalTokens", .integer).notNull()
                t.column("cost", .double).notNull()
                t.column("startTime", .datetime).notNull().indexed()
                t.column("endTime", .datetime).notNull()
                t.column("createdAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v2_sync") { db in
            try db.alter(table: "token_usage") { t in
                t.add(column: "syncedAt", .datetime)
            }
        }

        migrator.registerMigration("v3_conversations") { db in
            try db.create(table: "conversations") { t in
                t.column("id", .text).primaryKey()
                t.column("provider", .text).notNull().indexed()
                t.column("sessionId", .text).notNull().indexed()
                t.column("projectName", .text).notNull()
                t.column("startTime", .datetime)
                t.column("endTime", .datetime)
                t.column("messageCount", .integer).notNull().defaults(to: 0)
                t.column("userWordCount", .integer).notNull().defaults(to: 0)
                t.column("assistantWordCount", .integer).notNull().defaults(to: 0)
                t.column("keyFiles", .text)
                t.column("keyCommands", .text)
                t.column("keyTools", .text)
                t.column("inferredTaskTitle", .text).notNull().defaults(to: "")
                t.column("lastAssistantMessage", .text).notNull().defaults(to: "")
                t.column("fullText", .text).notNull().defaults(to: "")
                t.column("indexedAt", .datetime).notNull()
                t.column("fileModifiedAt", .datetime)
            }

            try db.create(table: "chat_messages") { t in
                t.column("id", .text).primaryKey()
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("cliUsed", .text)
            }

            try db.execute(
                sql: """
                CREATE VIRTUAL TABLE conversations_fts USING fts5(
                    inferredTaskTitle,
                    fullText,
                    content='conversations',
                    content_rowid='rowid',
                    tokenize='porter unicode61'
                )
                """
            )
        }

        migrator.registerMigration("v4_summaries") { db in
            try db.alter(table: "conversations") { t in
                t.add(column: "summary", .text)
            }
        }

        /// Rebuild FTS index from `conversations` so MATCH/snippet queries work. External-content
        /// FTS5 is normally updated automatically on DML; a rebuild fixes empty or stale indexes
        /// (e.g. after upgrades or if the shadow table was not populated).
        migrator.registerMigration("v5_fts_rebuild") { db in
            try db.execute(
                sql: "INSERT INTO conversations_fts(conversations_fts) VALUES('rebuild')"
            )
        }

        /// Replace external-content FTS with a standalone FTS5 table + triggers so the index
        /// is always updated on DML (external-content auto-sync is unreliable with some SQLite builds).
        migrator.registerMigration("v6_fts_standalone_triggers") { db in
            try db.execute(sql: "DROP TRIGGER IF EXISTS conversations_ai")
            try db.execute(sql: "DROP TRIGGER IF EXISTS conversations_ad")
            try db.execute(sql: "DROP TRIGGER IF EXISTS conversations_au")
            try db.execute(sql: "DROP TABLE IF EXISTS conversations_fts")

            try db.execute(
                sql: """
                CREATE VIRTUAL TABLE conversations_fts USING fts5(
                    inferredTaskTitle,
                    fullText,
                    tokenize='porter unicode61'
                )
                """
            )

            try db.execute(
                sql: """
                INSERT INTO conversations_fts(rowid, inferredTaskTitle, fullText)
                SELECT rowid, inferredTaskTitle, fullText FROM conversations
                """
            )

            try db.execute(
                sql: """
                CREATE TRIGGER conversations_ai AFTER INSERT ON conversations BEGIN
                    INSERT INTO conversations_fts(rowid, inferredTaskTitle, fullText)
                    VALUES (new.rowid, new.inferredTaskTitle, new.fullText);
                END
                """
            )
            try db.execute(
                sql: """
                CREATE TRIGGER conversations_ad AFTER DELETE ON conversations BEGIN
                    DELETE FROM conversations_fts WHERE rowid = old.rowid;
                END
                """
            )
            try db.execute(
                sql: """
                CREATE TRIGGER conversations_au AFTER UPDATE ON conversations BEGIN
                    DELETE FROM conversations_fts WHERE rowid = old.rowid;
                    INSERT INTO conversations_fts(rowid, inferredTaskTitle, fullText)
                    VALUES (new.rowid, new.inferredTaskTitle, new.fullText);
                END
                """
            )
        }

        migrator.registerMigration("v7_conversation_cloud_sync") { db in
            try db.alter(table: "conversations") { t in
                t.add(column: "conversationSyncedAt", .datetime)
            }
        }

        migrator.registerMigration("v8_chat_transcript_pieces") { db in
            try db.alter(table: "chat_messages") { t in
                t.add(column: "transcriptPiecesJSON", .text)
            }
        }

        /// Discriminates provider-log conversations from the in-app CLI assistant thread.
        migrator.registerMigration("v9_source_type") { db in
            try db.alter(table: "conversations") { t in
                t.add(column: "sourceType", .text).notNull().defaults(to: "provider_log")
            }
        }

        /// Independent dirty-flag for full session-log (Markdown) cloud backup.
        migrator.registerMigration("v10_log_synced_at") { db in
            try db.alter(table: "conversations") { t in
                t.add(column: "logSyncedAt", .datetime)
            }
        }

        /// Auto-summary metadata and spend ledger for budget capping.
        migrator.registerMigration("v11_auto_summary_metadata") { db in
            try db.alter(table: "conversations") { t in
                t.add(column: "summaryTitle", .text)
                t.add(column: "summaryUpdatedAt", .datetime)
                t.add(column: "summaryProvider", .text)
                t.add(column: "summaryModel", .text)
            }

            try db.create(table: "summary_runs") { t in
                t.column("id", .text).primaryKey()
                t.column("conversationId", .text).notNull().indexed()
                t.column("provider", .text).notNull()
                t.column("model", .text).notNull()
                t.column("costUSD", .double).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull().indexed()
            }
        }

        /// Prevent duplicate usage rows across repeated scans.
        /// Keep the newest row per (provider, sessionId, model), then enforce uniqueness.
        migrator.registerMigration("v12_token_usage_dedupe_unique_session_model") { db in
            try db.execute(sql: """
                DELETE FROM token_usage
                WHERE rowid NOT IN (
                    SELECT MAX(rowid)
                    FROM token_usage
                    GROUP BY provider, sessionId, model
                )
                """)
            try db.execute(sql: """
                CREATE UNIQUE INDEX IF NOT EXISTS token_usage_unique_session_model_idx
                ON token_usage(provider, sessionId, model)
                """)
        }

        /// Backfill Claude usage timestamps from indexed conversations.
        /// Handles subagent session IDs by collapsing `root/agent-*` to `root`.
        migrator.registerMigration("v13_backfill_claude_usage_timestamps") { db in
            try db.execute(sql: """
                UPDATE token_usage
                SET
                    startTime = COALESCE(
                        (
                            SELECT c.startTime
                            FROM conversations c
                            WHERE c.provider = token_usage.provider
                              AND c.sessionId = CASE
                                  WHEN instr(token_usage.sessionId, '/') > 0
                                  THEN substr(token_usage.sessionId, 1, instr(token_usage.sessionId, '/') - 1)
                                  ELSE token_usage.sessionId
                              END
                            ORDER BY COALESCE(c.endTime, c.startTime, c.indexedAt) DESC
                            LIMIT 1
                        ),
                        token_usage.startTime
                    ),
                    endTime = COALESCE(
                        (
                            SELECT COALESCE(c.endTime, c.startTime)
                            FROM conversations c
                            WHERE c.provider = token_usage.provider
                              AND c.sessionId = CASE
                                  WHEN instr(token_usage.sessionId, '/') > 0
                                  THEN substr(token_usage.sessionId, 1, instr(token_usage.sessionId, '/') - 1)
                                  ELSE token_usage.sessionId
                              END
                            ORDER BY COALESCE(c.endTime, c.startTime, c.indexedAt) DESC
                            LIMIT 1
                        ),
                        token_usage.endTime
                    )
                WHERE token_usage.provider = 'Claude Code'
                """)
        }

        /// Derived local retrieval substrate for hybrid search, projection outbox,
        /// embedding/version lineage, and typed subsystem health.
        migrator.registerMigration("v14_local_search_substrate") { db in
            try db.create(table: "search_documents") { t in
                t.column("id", .text).primaryKey()
                t.column("sourceKind", .text).notNull().indexed()
                t.column("sourceID", .text).notNull()
                t.column("sourceVersionID", .text).notNull().defaults(to: "")
                t.column("provider", .text)
                t.column("projectName", .text)
                t.column("title", .text).notNull()
                t.column("subtitle", .text)
                t.column("bodyPreview", .text)
                t.column("sourceUpdatedAt", .datetime)
                t.column("indexedAt", .datetime).notNull().indexed()
                t.column("contentHash", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(
                index: "search_documents_source_lookup_idx",
                on: "search_documents",
                columns: ["sourceKind", "sourceID", "sourceVersionID"],
                unique: true
            )
            try db.create(
                index: "search_documents_project_provider_idx",
                on: "search_documents",
                columns: ["projectName", "provider", "indexedAt"]
            )

            try db.create(table: "search_chunks") { t in
                t.column("id", .text).primaryKey()
                t.column("documentID", .text)
                    .notNull()
                    .references("search_documents", column: "id", onDelete: .cascade)
                t.column("sourceKind", .text).notNull().indexed()
                t.column("sourceID", .text).notNull()
                t.column("sourceVersionID", .text).notNull().defaults(to: "")
                t.column("ordinal", .integer).notNull()
                t.column("startOffset", .integer).notNull()
                t.column("endOffset", .integer).notNull()
                t.column("messageStartOffset", .integer)
                t.column("messageEndOffset", .integer)
                t.column("sectionPath", .text)
                t.column("text", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(
                index: "search_chunks_unique_document_ordinal_idx",
                on: "search_chunks",
                columns: ["documentID", "ordinal"],
                unique: true
            )
            try db.create(
                index: "search_chunks_document_offset_idx",
                on: "search_chunks",
                columns: ["documentID", "startOffset", "endOffset"]
            )
            try db.create(
                index: "search_chunks_source_lookup_idx",
                on: "search_chunks",
                columns: ["sourceKind", "sourceID", "sourceVersionID"]
            )
            try db.execute(
                sql: """
                CREATE VIRTUAL TABLE search_chunks_fts USING fts5(
                    chunkID UNINDEXED,
                    documentID UNINDEXED,
                    title,
                    chunkText,
                    tokenize='porter unicode61'
                )
                """
            )

            try db.create(table: "projection_jobs") { t in
                t.column("id", .text).primaryKey()
                t.column("jobType", .text).notNull().indexed()
                t.column("sourceKind", .text)
                t.column("sourceID", .text)
                t.column("sourceVersionID", .text).notNull().defaults(to: "")
                t.column("status", .text).notNull().indexed()
                t.column("priority", .integer).notNull().defaults(to: 100)
                t.column("attempts", .integer).notNull().defaults(to: 0)
                t.column("maxAttempts", .integer).notNull().defaults(to: 5)
                t.column("payloadJSON", .text)
                t.column("lastErrorCode", .text)
                t.column("lastErrorMessage", .text)
                t.column("scheduledAt", .datetime).notNull()
                t.column("availableAt", .datetime).notNull().indexed()
                t.column("startedAt", .datetime)
                t.column("completedAt", .datetime)
                t.column("leaseOwner", .text)
                t.column("leaseExpiresAt", .datetime)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(
                index: "projection_jobs_poll_idx",
                on: "projection_jobs",
                columns: ["status", "availableAt", "priority", "createdAt"]
            )
            try db.create(
                index: "projection_jobs_source_lookup_idx",
                on: "projection_jobs",
                columns: ["sourceKind", "sourceID", "sourceVersionID"]
            )

            try db.create(table: "embedding_models") { t in
                t.column("id", .text).primaryKey()
                t.column("provider", .text).notNull()
                t.column("modelName", .text).notNull()
                t.column("dimensions", .integer).notNull()
                t.column("distanceMetric", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(
                index: "embedding_models_provider_model_idx",
                on: "embedding_models",
                columns: ["provider", "modelName"],
                unique: true
            )

            try db.create(table: "embedding_versions") { t in
                t.column("id", .text).primaryKey()
                t.column("modelID", .text)
                    .notNull()
                    .references("embedding_models", column: "id", onDelete: .cascade)
                t.column("versionTag", .text).notNull()
                t.column("chunkerVersion", .text).notNull()
                t.column("normalizationVersion", .text).notNull()
                t.column("promptVersion", .text).notNull()
                t.column("isActive", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(
                index: "embedding_versions_identity_idx",
                on: "embedding_versions",
                columns: ["modelID", "versionTag", "chunkerVersion", "normalizationVersion", "promptVersion"],
                unique: true
            )
            try db.create(
                index: "embedding_versions_active_idx",
                on: "embedding_versions",
                columns: ["modelID", "isActive"]
            )

            try db.create(table: "chunk_embeddings") { t in
                t.column("chunkID", .text)
                    .notNull()
                    .references("search_chunks", column: "id", onDelete: .cascade)
                t.column("embeddingVersionID", .text)
                    .notNull()
                    .references("embedding_versions", column: "id", onDelete: .cascade)
                t.column("vectorBlob", .blob).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.primaryKey(["chunkID", "embeddingVersionID"])
            }
            try db.create(
                index: "chunk_embeddings_version_lookup_idx",
                on: "chunk_embeddings",
                columns: ["embeddingVersionID"]
            )

            try db.create(table: "retrieval_health") { t in
                t.column("subsystem", .text).primaryKey()
                t.column("status", .text).notNull()
                t.column("errorCode", .text)
                t.column("errorMessage", .text)
                t.column("detailsJSON", .text)
                t.column("observedAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v15_source_artifact_registry") { db in
            try db.create(table: "source_artifacts") { t in
                t.column("id", .text).primaryKey()
                t.column("sourceKind", .text).notNull().indexed()
                t.column("canonicalPath", .text).notNull()
                t.column("rootPath", .text).notNull().indexed()
                t.column("relativePath", .text).notNull()
                t.column("provenance", .text).notNull()
                t.column("title", .text).notNull()
                t.column("body", .text).notNull()
                t.column("contentHash", .text).notNull()
                t.column("fileSizeBytes", .integer).notNull().defaults(to: 0)
                t.column("fileModifiedAt", .datetime)
                t.column("status", .text).notNull().defaults(to: SourceArtifactStatus.active.rawValue).indexed()
                t.column("discoveredAt", .datetime).notNull()
                t.column("deletedAt", .datetime)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(
                index: "source_artifacts_canonical_path_idx",
                on: "source_artifacts",
                columns: ["canonicalPath"],
                unique: true
            )
            try db.create(
                index: "source_artifacts_root_relative_idx",
                on: "source_artifacts",
                columns: ["rootPath", "relativePath"],
                unique: true
            )
        }

        migrator.registerMigration("v16_shared_artifact_sync_state") { db in
            try db.create(table: "shared_artifact_sync_state") { t in
                t.column("sourceArtifactID", .text)
                    .primaryKey()
                    .references("source_artifacts", column: "id", onDelete: .cascade)
                t.column("remoteArtifactID", .text).notNull()
                t.column("workspaceID", .text).notNull()
                t.column("teamID", .text).notNull()
                t.column("ownerUserID", .text)
                t.column("revisionID", .text).notNull()
                t.column("remoteContentHash", .text)
                t.column("localContentHashAtSync", .text)
                t.column("remoteUpdatedAt", .datetime)
                t.column("lastPulledAt", .datetime)
                t.column("lastSyncedAt", .datetime)
                t.column("syncStatus", .text).notNull().defaults(to: SharedArtifactSyncStatus.pendingPull.rawValue)
                t.column("lastErrorCode", .text)
                t.column("lastErrorMessage", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(
                index: "shared_artifact_sync_remote_lookup_idx",
                on: "shared_artifact_sync_state",
                columns: ["remoteArtifactID"],
                unique: true
            )
            try db.create(
                index: "shared_artifact_sync_scope_idx",
                on: "shared_artifact_sync_state",
                columns: ["workspaceID", "teamID"]
            )
            try db.create(
                index: "shared_artifact_sync_status_idx",
                on: "shared_artifact_sync_state",
                columns: ["syncStatus"]
            )
        }

        migrator.registerMigration("v17_shared_artifact_permissions_and_audit") { db in
            try db.create(table: "artifact_permissions") { t in
                t.column("sourceArtifactID", .text)
                    .notNull()
                    .references("source_artifacts", column: "id", onDelete: .cascade)
                t.column("workspaceID", .text).notNull()
                t.column("teamID", .text).notNull()
                t.column("principalType", .text).notNull()
                t.column("principalID", .text).notNull()
                t.column("role", .text).notNull()
                t.column("visibility", .text).notNull()
                t.column("canRead", .boolean).notNull().defaults(to: true)
                t.column("canWrite", .boolean).notNull().defaults(to: false)
                t.column("canShare", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.primaryKey(["sourceArtifactID", "principalType", "principalID"])
            }
            try db.create(
                index: "artifact_permissions_principal_lookup_idx",
                on: "artifact_permissions",
                columns: ["workspaceID", "teamID", "principalType", "principalID", "canRead"]
            )
            try db.create(
                index: "artifact_permissions_source_lookup_idx",
                on: "artifact_permissions",
                columns: ["sourceArtifactID", "canRead", "visibility"]
            )

            try db.create(table: "audit_events") { t in
                t.column("id", .text).primaryKey()
                t.column("sourceArtifactID", .text)
                    .references("source_artifacts", column: "id", onDelete: .setNull)
                t.column("remoteArtifactID", .text)
                t.column("workspaceID", .text).notNull()
                t.column("teamID", .text).notNull()
                t.column("actorUserID", .text)
                t.column("actorRole", .text)
                t.column("action", .text).notNull()
                t.column("detailsJSON", .text)
                t.column("occurredAt", .datetime).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(
                index: "audit_events_source_time_idx",
                on: "audit_events",
                columns: ["sourceArtifactID", "occurredAt"]
            )
            try db.create(
                index: "audit_events_scope_time_idx",
                on: "audit_events",
                columns: ["workspaceID", "teamID", "occurredAt"]
            )
            try db.create(
                index: "audit_events_action_time_idx",
                on: "audit_events",
                columns: ["action", "occurredAt"]
            )
        }

        /// Tracks the most recent summary attempt (success or failure) to throttle retries.
        migrator.registerMigration("v18_summary_attempt_tracking") { db in
            try db.alter(table: "conversations") { t in
                t.add(column: "summaryAttemptedAt", .datetime)
            }
        }

        /// Fixes FTS update/delete triggers to use direct rowid deletes for standalone FTS.
        migrator.registerMigration("v19_conversation_fts_trigger_fix") { db in
            try db.execute(sql: "DROP TRIGGER IF EXISTS conversations_ad")
            try db.execute(sql: "DROP TRIGGER IF EXISTS conversations_au")

            try db.execute(
                sql: """
                CREATE TRIGGER conversations_ad AFTER DELETE ON conversations BEGIN
                    DELETE FROM conversations_fts WHERE rowid = old.rowid;
                END
                """
            )
            try db.execute(
                sql: """
                CREATE TRIGGER conversations_au AFTER UPDATE ON conversations BEGIN
                    DELETE FROM conversations_fts WHERE rowid = old.rowid;
                    INSERT INTO conversations_fts(rowid, inferredTaskTitle, fullText)
                    VALUES (new.rowid, new.inferredTaskTitle, new.fullText);
                END
                """
            )
        }

        /// Thread-aware storage for in-app Burn Bar chat history and scoped search.
        migrator.registerMigration("v20_chat_threads") { db in
            try db.create(table: "chat_threads") { t in
                t.column("id", .text).primaryKey()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull().indexed()
            }

            try db.alter(table: "chat_messages") { t in
                t.add(column: "threadId", .text).notNull().defaults(to: Self.legacyChatThreadID)
            }

            try db.create(
                index: "chat_messages_thread_time_idx",
                on: "chat_messages",
                columns: ["threadId", "timestamp"]
            )

            try db.execute(
                sql: """
                INSERT OR IGNORE INTO chat_threads (id, createdAt, updatedAt)
                VALUES (
                    ?,
                    COALESCE((SELECT MIN(timestamp) FROM chat_messages), CURRENT_TIMESTAMP),
                    COALESCE((SELECT MAX(timestamp) FROM chat_messages), CURRENT_TIMESTAMP)
                )
                """,
                arguments: [Self.legacyChatThreadID]
            )
        }

        /// Multi-field FTS5 for enhanced lexical retrieval:
        /// - Adds projectName and provider columns to the FTS virtual table for field-weighted search
        /// - Creates a separate search_documents_fts for document-level title/bodyPreview matching
        /// - Enables field-boosted queries (title:foo OR projectName:bar OR chunkText:baz)
        migrator.registerMigration("v21_multifield_fts") { db in
            // Step 1: Create new FTS5 table with additional columns
            try db.execute(sql: """
                CREATE VIRTUAL TABLE search_chunks_fts_new USING fts5(
                    chunkID UNINDEXED,
                    documentID UNINDEXED,
                    title,
                    chunkText,
                    projectName,
                    provider,
                    tokenize='porter unicode61'
                )
                """)

            // Step 2: Migrate data from old FTS to new FTS
            try db.execute(sql: """
                INSERT INTO search_chunks_fts_new (chunkID, documentID, title, chunkText, projectName, provider)
                SELECT
                    scf.chunkID,
                    scf.documentID,
                    COALESCE(scf.title, ''),
                    COALESCE(scf.chunkText, ''),
                    COALESCE(d.projectName, ''),
                    COALESCE(d.provider, '')
                FROM search_chunks_fts scf
                JOIN search_documents d ON d.id = scf.documentID
                """)

            // Step 3: Drop old FTS table and rename new one
            try db.execute(sql: "DROP TABLE search_chunks_fts")
            try db.execute(sql: "ALTER TABLE search_chunks_fts_new RENAME TO search_chunks_fts")

            // Step 4: Create document-level FTS for title/bodyPreview matching
            try db.execute(sql: """
                CREATE VIRTUAL TABLE search_documents_fts USING fts5(
                    documentID UNINDEXED,
                    title,
                    subtitle,
                    bodyPreview,
                    projectName,
                    provider,
                    tokenize='porter unicode61'
                )
                """)

            // Step 5: Populate document FTS from search_documents
            try db.execute(sql: """
                INSERT INTO search_documents_fts (documentID, title, subtitle, bodyPreview, projectName, provider)
                SELECT
                    id,
                    COALESCE(title, ''),
                    COALESCE(subtitle, ''),
                    COALESCE(bodyPreview, ''),
                    COALESCE(projectName, ''),
                    COALESCE(provider, '')
                FROM search_documents
                """)

            // Step 6: Create triggers to keep document FTS in sync
            try db.execute(sql: """
                CREATE TRIGGER search_documents_fts_ai AFTER INSERT ON search_documents BEGIN
                    INSERT INTO search_documents_fts(documentID, title, subtitle, bodyPreview, projectName, provider)
                    VALUES (
                        new.id,
                        COALESCE(new.title, ''),
                        COALESCE(new.subtitle, ''),
                        COALESCE(new.bodyPreview, ''),
                        COALESCE(new.projectName, ''),
                        COALESCE(new.provider, '')
                    );
                END
                """)

            try db.execute(sql: """
                CREATE TRIGGER search_documents_fts_ad AFTER DELETE ON search_documents BEGIN
                    DELETE FROM search_documents_fts WHERE documentID = old.id;
                END
                """)

            try db.execute(sql: """
                CREATE TRIGGER search_documents_fts_au AFTER UPDATE ON search_documents BEGIN
                    DELETE FROM search_documents_fts WHERE documentID = old.id;
                    INSERT INTO search_documents_fts(documentID, title, subtitle, bodyPreview, projectName, provider)
                    VALUES (
                        new.id,
                        COALESCE(new.title, ''),
                        COALESCE(new.subtitle, ''),
                        COALESCE(new.bodyPreview, ''),
                        COALESCE(new.projectName, ''),
                        COALESCE(new.provider, '')
                    );
                END
                """)
        }

        migrator.registerMigration("v22_cross_device_sync") { db in
            try db.alter(table: "token_usage") { t in
                t.add(column: "sourceDeviceId", .text)
                t.add(column: "sourceDeviceName", .text)
                t.add(column: "isRemote", .integer).notNull().defaults(to: 0)
            }
            try db.execute(sql: "DROP INDEX IF EXISTS token_usage_unique_session_model_idx")
            try db.execute(sql: """
                CREATE UNIQUE INDEX token_usage_unique_session_model_device_idx
                ON token_usage(provider, sessionId, model, COALESCE(sourceDeviceId, ''))
                """)
            try db.alter(table: "conversations") { t in
                t.add(column: "sourceDeviceId", .text)
                t.add(column: "sourceDeviceName", .text)
                t.add(column: "isRemote", .integer).notNull().defaults(to: 0)
            }
            try db.create(table: "devices") { t in
                t.column("deviceId", .text).primaryKey()
                t.column("deviceName", .text).notNull()
                t.column("isLocal", .integer).notNull().defaults(to: 0)
                t.column("lastSeenAt", .datetime)
                t.column("createdAt", .datetime).notNull()
            }
            let localName = Host.current().localizedName ?? "This Mac"
            let now = Date()
            try db.execute(
                sql: "INSERT OR IGNORE INTO devices (deviceId, deviceName, isLocal, lastSeenAt, createdAt) VALUES (?, ?, 1, ?, ?)",
                arguments: [UserDefaults.standard.string(forKey: BurnBarIdentity.deviceIDKey) ?? "unknown", localName, now, now]
            )
        }

        migrator.registerMigration("v23_device_hardware_model") { db in
            try db.alter(table: "devices") { t in
                t.add(column: "hardwareModel", .text)
                t.add(column: "customIcon", .text)
            }
            let hwModel = DeviceHardwareIcon.localHardwareModel
            try db.execute(
                sql: "UPDATE devices SET hardwareModel = ? WHERE isLocal = 1",
                arguments: [hwModel]
            )
        }

        // Repair: v23 may have been recorded without actually adding customIcon
        // (e.g. partial migration or schema rebuild). Idempotently ensure the column exists.
        migrator.registerMigration("v24_repair_custom_icon_column") { db in
            let columns = try Row.fetchAll(db, sql: "PRAGMA table_info(devices)")
            let hasCustomIcon = columns.contains { ($0["name"] as? String) == "customIcon" }
            if !hasCustomIcon {
                try db.alter(table: "devices") { t in
                    t.add(column: "customIcon", .text)
                }
            }
        }

        migrator.registerMigration("v25_operating_action_history") { db in
            try db.create(table: "operating_action_history") { t in
                t.column("id", .text).primaryKey()
                t.column("projectName", .text).notNull()
                t.column("missionFingerprint", .text)
                t.column("actionKind", .text).notNull()
                t.column("summary", .text).notNull()
                t.column("detail", .text)
                t.column("overrideMode", .text)
                t.column("forcedDirectionStatus", .text)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(
                index: "operating_action_history_project_time_idx",
                on: "operating_action_history",
                columns: ["projectName", "createdAt"]
            )
            try db.create(
                index: "operating_action_history_kind_time_idx",
                on: "operating_action_history",
                columns: ["actionKind", "createdAt"]
            )
            try db.create(
                index: "operating_action_history_mission_time_idx",
                on: "operating_action_history",
                columns: ["missionFingerprint", "createdAt"]
            )
        }

        migrator.registerMigration("v26_controller_runtime_cache") { db in
            try db.create(table: "controller_runtime_cache") { t in
                t.column("cacheKey", .text).primaryKey()
                t.column("payloadJSON", .text).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(
                index: "controller_runtime_cache_updated_idx",
                on: "controller_runtime_cache",
                columns: ["updatedAt"]
            )
        }

        return migrator
    }
    
    // MARK: - CRUD Operations
    
    func insert(_ usage: TokenUsage) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO token_usage (
                        id, provider, sessionId, projectName, model,
                        inputTokens, outputTokens, cacheCreationTokens, cacheReadTokens,
                        totalTokens, cost, startTime, endTime, createdAt,
                        sourceDeviceId, sourceDeviceName, isRemote
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(provider, sessionId, model, COALESCE(sourceDeviceId, '')) DO UPDATE SET
                        projectName = excluded.projectName,
                        inputTokens = excluded.inputTokens,
                        outputTokens = excluded.outputTokens,
                        cacheCreationTokens = excluded.cacheCreationTokens,
                        cacheReadTokens = excluded.cacheReadTokens,
                        totalTokens = excluded.totalTokens,
                        cost = excluded.cost,
                        startTime = excluded.startTime,
                        endTime = excluded.endTime,
                        createdAt = excluded.createdAt,
                        syncedAt = NULL
                    WHERE
                        token_usage.projectName != excluded.projectName
                        OR token_usage.inputTokens != excluded.inputTokens
                        OR token_usage.outputTokens != excluded.outputTokens
                        OR token_usage.cacheCreationTokens != excluded.cacheCreationTokens
                        OR token_usage.cacheReadTokens != excluded.cacheReadTokens
                        OR token_usage.totalTokens != excluded.totalTokens
                        OR token_usage.cost != excluded.cost
                        OR token_usage.startTime != excluded.startTime
                        OR token_usage.endTime != excluded.endTime
                    """,
                arguments: [
                    usage.id.uuidString,
                    usage.provider.rawValue,
                    usage.sessionId,
                    usage.projectName,
                    usage.model,
                    usage.inputTokens,
                    usage.outputTokens,
                    usage.cacheCreationTokens,
                    usage.cacheReadTokens,
                    usage.totalTokens,
                    usage.cost,
                    usage.startTime,
                    usage.endTime,
                    usage.createdAt,
                    usage.sourceDeviceId,
                    usage.sourceDeviceName,
                    usage.isRemote ? 1 : 0
                ]
            )
        }
    }

    func insert(_ newUsages: [TokenUsage]) throws {
        for usage in newUsages {
            try insert(usage)
        }
    }
    
    func deleteAll() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM token_usage")
        }
        usages = []
        rollingDailyAverage = 0
    }

    func deleteUsage(sessionIDPrefix: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    DELETE FROM token_usage
                    WHERE sessionId LIKE ? AND COALESCE(sourceDeviceId, '') = ''
                    """,
                arguments: ["\(sessionIDPrefix)%"]
            )
        }
    }

    func replaceUsages(_ newUsages: [TokenUsage]) {
        usages = newUsages.sorted { $0.startTime > $1.startTime }
        rollingDailyAverage = computeRollingAverage()
        lastRefresh = Date()
    }

    private func computeRollingAverage() -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var total: Double = 0
        for dayOffset in 1...7 {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
            let dayCost = usages
                .filter { $0.startTime >= day && $0.startTime < nextDay }
                .reduce(0) { $0 + $1.cost }
            total += dayCost
        }
        return total / 7
    }
    
    // MARK: - Refresh
    
    func refresh() {
        isLoading = true
        
        do {
            let records = try dbQueue.read { db -> [TokenUsage] in
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM token_usage ORDER BY startTime DESC")
                return rows.compactMap { row -> TokenUsage? in
                    guard let idString = row["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let providerString = row["provider"] as? String,
                          let provider = AgentProvider(rawValue: providerString),
                          let sessionId = row["sessionId"] as? String,
                          let projectName = row["projectName"] as? String,
                          let model = row["model"] as? String else {
                        return nil
                    }

                    let inputTokens = (row["inputTokens"] as? Int) ?? Int(row["inputTokens"] as? Int64 ?? 0)
                    let outputTokens = (row["outputTokens"] as? Int) ?? Int(row["outputTokens"] as? Int64 ?? 0)
                    let cacheCreationTokens = (row["cacheCreationTokens"] as? Int) ?? Int(row["cacheCreationTokens"] as? Int64 ?? 0)
                    let cacheReadTokens = (row["cacheReadTokens"] as? Int) ?? Int(row["cacheReadTokens"] as? Int64 ?? 0)

                    let cost = (row["cost"] as? Double)
                        ?? ((row["cost"] as? NSNumber)?.doubleValue)
                        ?? 0

                    let startTime = parseDate(row["startTime"])
                    let endTime = parseDate(row["endTime"])
                    guard let startTime, let endTime else { return nil }
                    
                    return TokenUsage(
                        id: id,
                        provider: provider,
                        sessionId: sessionId,
                        projectName: projectName,
                        model: model,
                        inputTokens: inputTokens,
                        outputTokens: outputTokens,
                        cacheCreationTokens: cacheCreationTokens,
                        cacheReadTokens: cacheReadTokens,
                        costUSD: cost,
                        startTime: startTime,
                        endTime: endTime,
                        sourceDeviceId: row["sourceDeviceId"] as? String,
                        sourceDeviceName: row["sourceDeviceName"] as? String,
                        isRemote: ((row["isRemote"] as? Int) ?? Int(row["isRemote"] as? Int64 ?? 0)) != 0
                    )
                }
            }
            replaceUsages(records)
        } catch {
            print("DataStore: Failed to refresh data: \(error)")
        }
        
        isLoading = false
    }

    private func parseDate(_ value: Any?) -> Date? {
        Self.parseDateValue(value)
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
            if let parsed = sqliteDateFormatterStatic.date(from: string) { return parsed }
            return ISO8601DateFormatter().date(from: string)
        }
        return nil
    }

    private static let sqliteDateFormatterStatic: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    // MARK: - Sync Helpers

    func fetchUnsynced() throws -> [TokenUsage] {
        try dbQueue.read { db -> [TokenUsage] in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM token_usage WHERE syncedAt IS NULL AND isRemote = 0 ORDER BY startTime ASC LIMIT 400"
            )
            return rows.compactMap { row -> TokenUsage? in
                guard let idString = row["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let providerString = row["provider"] as? String,
                      let provider = AgentProvider(rawValue: providerString),
                      let sessionId = row["sessionId"] as? String,
                      let projectName = row["projectName"] as? String,
                      let model = row["model"] as? String else { return nil }

                let inputTokens = (row["inputTokens"] as? Int) ?? Int(row["inputTokens"] as? Int64 ?? 0)
                let outputTokens = (row["outputTokens"] as? Int) ?? Int(row["outputTokens"] as? Int64 ?? 0)
                let cacheCreationTokens = (row["cacheCreationTokens"] as? Int) ?? Int(row["cacheCreationTokens"] as? Int64 ?? 0)
                let cacheReadTokens = (row["cacheReadTokens"] as? Int) ?? Int(row["cacheReadTokens"] as? Int64 ?? 0)
                let cost = (row["cost"] as? Double) ?? ((row["cost"] as? NSNumber)?.doubleValue) ?? 0
                let startTime = parseDate(row["startTime"])
                let endTime = parseDate(row["endTime"])
                guard let startTime, let endTime else { return nil }

                return TokenUsage(
                    id: id,
                    provider: provider,
                    sessionId: sessionId,
                    projectName: projectName,
                    model: model,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cacheCreationTokens: cacheCreationTokens,
                    cacheReadTokens: cacheReadTokens,
                    costUSD: cost,
                    startTime: startTime,
                    endTime: endTime
                )
            }
        }
    }

    func markSynced(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        let idStrings: [String] = ids.map { $0.uuidString }
        try dbQueue.write { db in
            // Build arguments: first param is the syncedAt date, rest are UUIDs
            var args = StatementArguments([Date()])
            args += StatementArguments(idStrings)
            try db.execute(
                sql: "UPDATE token_usage SET syncedAt = ? WHERE id IN (\(placeholders))",
                arguments: args
            )
        }
    }

    /// Conversations whose metadata has not been uploaded to Firestore (or changed since last upload).
    func fetchUnsyncedConversations(limit: Int = 400) throws -> [ConversationRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM conversations
                WHERE conversationSyncedAt IS NULL AND isRemote = 0
                ORDER BY COALESCE(endTime, startTime) ASC
                LIMIT ?
                """,
                arguments: [limit]
            )
            return rows.compactMap { Self.conversation(from: $0) }
        }
    }

    func markConversationsSynced(ids: [String]) throws {
        guard !ids.isEmpty else { return }
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        try dbQueue.write { db in
            var args = StatementArguments([Date()])
            args += StatementArguments(ids)
            try db.execute(
                sql: "UPDATE conversations SET conversationSyncedAt = ? WHERE id IN (\(placeholders))",
                arguments: args
            )
        }
    }

    // MARK: - Query Helpers
    
    func usages(for provider: AgentProvider) -> [TokenUsage] {
        usages.filter { $0.provider == provider }
    }
    
    func usages(for provider: AgentProvider, in dateRange: ClosedRange<Date>) -> [TokenUsage] {
        usages.filter { $0.provider == provider && $0.intersects(dateRange: dateRange) }
    }
    
    func topProviderToday() -> (provider: AgentProvider, cost: Double)? {
        let calendar = Calendar.current
        let todayUsages = usages.filter { calendar.isDateInToday($0.startTime) }
        
        var costs: [AgentProvider: Double] = [:]
        for usage in todayUsages {
            costs[usage.provider, default: 0] += usage.cost
        }
        
        return costs.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    // MARK: - Conversations (indexed)

    func upsertConversation(_ record: ConversationRecord) throws {
        let keyFilesJSON = try Self.encodeJSON(record.keyFiles)
        let keyCommandsJSON = try Self.encodeJSON(record.keyCommands)
        let keyToolsJSON = try Self.encodeJSON(record.keyTools)

        try dbQueue.write { db in
            let existing = try Self.fetchConversationRow(db, id: record.id)
            let priorSyncedAt: Date? = try Date.fetchOne(
                db,
                sql: "SELECT conversationSyncedAt FROM conversations WHERE id = ?",
                arguments: [record.id]
            )
            let priorLogSyncedAt: Date? = try Date.fetchOne(
                db,
                sql: "SELECT logSyncedAt FROM conversations WHERE id = ?",
                arguments: [record.id]
            )

            var summaryOut = record.summary
            if summaryOut == nil {
                summaryOut = try String.fetchOne(db, sql: "SELECT summary FROM conversations WHERE id = ?", arguments: [record.id])
            }
            var summaryTitleOut = record.summaryTitle
            if summaryTitleOut == nil {
                summaryTitleOut = try String.fetchOne(db, sql: "SELECT summaryTitle FROM conversations WHERE id = ?", arguments: [record.id])
            }
            var summaryUpdatedAtOut = record.summaryUpdatedAt
            if summaryUpdatedAtOut == nil {
                summaryUpdatedAtOut = try Date.fetchOne(db, sql: "SELECT summaryUpdatedAt FROM conversations WHERE id = ?", arguments: [record.id])
            }
            var summaryAttemptedAtOut: Date? = try Date.fetchOne(
                db,
                sql: "SELECT summaryAttemptedAt FROM conversations WHERE id = ?",
                arguments: [record.id]
            )
            if summaryUpdatedAtOut != nil, summaryAttemptedAtOut == nil {
                summaryAttemptedAtOut = summaryUpdatedAtOut
            }
            var summaryProviderOut = record.summaryProvider
            if summaryProviderOut == nil {
                summaryProviderOut = try String.fetchOne(db, sql: "SELECT summaryProvider FROM conversations WHERE id = ?", arguments: [record.id])
            }
            var summaryModelOut = record.summaryModel
            if summaryModelOut == nil {
                summaryModelOut = try String.fetchOne(db, sql: "SELECT summaryModel FROM conversations WHERE id = ?", arguments: [record.id])
            }

            let preserve = existing.map {
                Self.shouldPreserveConversationSyncedAt(
                    existing: $0,
                    incoming: record,
                    resolvedSummary: summaryOut,
                    resolvedSummaryTitle: summaryTitleOut,
                    resolvedSummaryUpdatedAt: summaryUpdatedAtOut,
                    resolvedSummaryProvider: summaryProviderOut,
                    resolvedSummaryModel: summaryModelOut
                )
            } ?? false

            let conversationSyncedAt: Date? = preserve ? priorSyncedAt : nil
            let logSyncedAt: Date? = preserve ? priorLogSyncedAt : nil

            try db.execute(
                sql: """
                INSERT OR REPLACE INTO conversations (
                    id, provider, sessionId, projectName, startTime, endTime,
                    messageCount, userWordCount, assistantWordCount,
                    keyFiles, keyCommands, keyTools,
                    inferredTaskTitle, lastAssistantMessage, fullText,
                    indexedAt, fileModifiedAt, summary, conversationSyncedAt,
                    sourceType, logSyncedAt, summaryTitle, summaryUpdatedAt, summaryAttemptedAt,
                    summaryProvider, summaryModel
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    record.id,
                    record.provider.rawValue,
                    record.sessionId,
                    record.projectName,
                    record.startTime,
                    record.endTime,
                    record.messageCount,
                    record.userWordCount,
                    record.assistantWordCount,
                    keyFilesJSON,
                    keyCommandsJSON,
                    keyToolsJSON,
                    record.inferredTaskTitle,
                    record.lastAssistantMessage,
                    record.fullText,
                    record.indexedAt,
                    record.fileModifiedAt,
                    summaryOut,
                    conversationSyncedAt,
                    record.sourceType.rawValue,
                    logSyncedAt,
                    summaryTitleOut,
                    summaryUpdatedAtOut,
                    summaryAttemptedAtOut,
                    summaryProviderOut,
                    summaryModelOut
                ]
            )
        }
    }

    func fileModifiedAtForConversation(id: String) throws -> Date? {
        try dbQueue.read { db in
            try Date.fetchOne(
                db,
                sql: "SELECT fileModifiedAt FROM conversations WHERE id = ?",
                arguments: [id]
            )
        }
    }

    func fetchConversation(id: String) throws -> ConversationRecord? {
        try dbQueue.read { db in
            try Self.fetchConversationRow(db, id: id)
        }
    }

    func fetchConversations(limit: Int = 500) throws -> [ConversationRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM conversations ORDER BY COALESCE(endTime, startTime, indexedAt) DESC LIMIT ?",
                arguments: [limit]
            )
            return rows.compactMap { Self.conversation(from: $0) }
        }
    }

    func updateConversationSummary(
        id: String,
        title: String?,
        summary: String?,
        provider: String?,
        model: String?,
        updatedAt: Date = Date(),
        runCostUSD: Double = 0
    ) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE conversations
                SET summary = ?, summaryTitle = ?, summaryUpdatedAt = ?, summaryAttemptedAt = ?, summaryProvider = ?, summaryModel = ?,
                    indexedAt = ?, conversationSyncedAt = NULL, logSyncedAt = NULL
                WHERE id = ?
                """,
                arguments: [summary, title, updatedAt, updatedAt, provider, model, updatedAt, id]
            )

            try db.execute(
                sql: """
                INSERT INTO summary_runs (id, conversationId, provider, model, costUSD, createdAt)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    UUID().uuidString,
                    id,
                    provider ?? "unknown",
                    model ?? "unknown",
                    max(runCostUSD, 0),
                    updatedAt
                ]
            )
        }

        try enqueueConversationProjectionJob(conversationID: id, jobType: .reproject)
    }

    /// Records a failed summary attempt to throttle repeated retries for unchanged rows.
    func markConversationSummaryAttempt(id: String, attemptedAt: Date = Date()) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE conversations
                SET summaryAttemptedAt = ?
                WHERE id = ?
                """,
                arguments: [attemptedAt, id]
            )
        }
    }

    /// Candidate conversations for auto-summarization.
    /// - Missing summary/title metadata OR stale summary relative to latest indexed content.
    /// - Failed attempts are throttled by `retryCooldown` unless content changed since attempt.
    func fetchConversationsNeedingSummary(
        limit: Int = 25,
        now: Date = Date(),
        retryCooldown: TimeInterval = 60 * 60,
        indexedAfter: Date? = nil
    ) throws -> [ConversationRecord] {
        let cutoff = now.addingTimeInterval(-max(retryCooldown, 0))
        return try dbQueue.read { db in
            var sql = """
                SELECT * FROM conversations
                WHERE fullText <> ''
                AND (
                    summary IS NULL
                    OR summaryTitle IS NULL
                    OR summaryUpdatedAt IS NULL
                    OR summaryUpdatedAt < indexedAt
                )
                AND (
                    summaryAttemptedAt IS NULL
                    OR summaryAttemptedAt <= ?
                    OR indexedAt > summaryAttemptedAt
                )
                """
            var arguments: [any DatabaseValueConvertible] = [cutoff]

            if let indexedAfter {
                sql += """
                
                AND indexedAt >= ?
                """
                arguments.append(indexedAfter)
            }

            sql += """
                
                ORDER BY COALESCE(endTime, startTime, indexedAt) DESC
                LIMIT ?
                """
            arguments.append(limit)

            let rows = try Row.fetchAll(
                db,
                sql: sql,
                arguments: StatementArguments(arguments)
            )
            return rows.compactMap { Self.conversation(from: $0) }
        }
    }

    /// Sum of cloud summary cost (USD) for today's local day.
    func summarySpendToday(now: Date = Date()) throws -> Double {
        try dbQueue.read { db in
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return try Double.fetchOne(
                db,
                sql: """
                SELECT COALESCE(SUM(costUSD), 0)
                FROM summary_runs
                WHERE createdAt >= ? AND createdAt < ?
                """,
                arguments: [start, end]
            ) ?? 0
        }
    }

    func deleteAllIndexedConversations() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM conversations")
            try db.execute(sql: "DELETE FROM summary_runs")
        }
    }

    func approximateConversationStorageBytes() throws -> Int64 {
        try dbQueue.read { db in
            let text: Int64 = try Int64.fetchOne(
                db,
                sql: """
                SELECT COALESCE(SUM(LENGTH(fullText)), 0) + COALESCE(SUM(LENGTH(inferredTaskTitle)), 0)
                + COALESCE(SUM(LENGTH(lastAssistantMessage)), 0) FROM conversations
                """
            ) ?? 0
            return text
        }
    }

    // MARK: - Chat messages (persisted)

    func saveChatMessage(_ message: ChatMessageRecord) throws {
        try saveChatMessage(message, threadID: Self.legacyChatThreadID)
    }

    func saveChatMessage(_ message: ChatMessageRecord, threadID: String) throws {
        let piecesJSON: String?
        if message.transcriptPieces.isEmpty {
            piecesJSON = nil
        } else {
            piecesJSON = try Self.encodeTranscriptPieces(message.transcriptPieces)
        }

        try dbQueue.write { db in
            try upsertChatThread(threadID, at: message.timestamp, db: db)
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO chat_messages (id, threadId, role, content, timestamp, cliUsed, transcriptPiecesJSON)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    message.id,
                    threadID,
                    message.role.rawValue,
                    message.content,
                    message.timestamp,
                    message.cliUsed,
                    piecesJSON
                ]
            )
        }
    }

    func createChatThread(id: String = UUID().uuidString, at date: Date = Date()) throws -> String {
        try dbQueue.write { db in
            try upsertChatThread(id, at: date, db: db)
        }
        return id
    }

    func chatThreadExists(id: String) throws -> Bool {
        try dbQueue.read { db in
            let count = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(1) FROM chat_threads WHERE id = ?",
                arguments: [id]
            ) ?? 0
            return count > 0
        }
    }

    func fetchMostRecentChatThreadID() throws -> String? {
        try dbQueue.read { db in
            try String.fetchOne(
                db,
                sql: """
                SELECT t.id
                FROM chat_threads t
                LEFT JOIN chat_messages m ON m.threadId = t.id
                GROUP BY t.id, t.createdAt, t.updatedAt
                ORDER BY COALESCE(MAX(m.timestamp), t.updatedAt, t.createdAt) DESC
                LIMIT 1
                """
            )
        }
    }

    func fetchChatThreadSummaries(searchQuery: String = "", limit: Int = 80) throws -> [ChatThreadSummary] {
        let normalizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return try dbQueue.read { db in
            var sql = """
            SELECT
                t.id AS threadID,
                t.createdAt AS createdAt,
                t.updatedAt AS updatedAt,
                COUNT(m.id) AS messageCount,
                MAX(m.timestamp) AS lastMessageAt,
                (
                    SELECT um.content
                    FROM chat_messages um
                    WHERE um.threadId = t.id
                      AND um.role = 'user'
                      AND TRIM(um.content) != ''
                    ORDER BY um.timestamp ASC
                    LIMIT 1
                ) AS firstUserMessage,
                (
                    SELECT lm.content
                    FROM chat_messages lm
                    WHERE lm.threadId = t.id
                      AND TRIM(lm.content) != ''
                    ORDER BY lm.timestamp DESC
                    LIMIT 1
                ) AS lastMessageContent
            FROM chat_threads t
            LEFT JOIN chat_messages m ON m.threadId = t.id
            """
            var args: [any DatabaseValueConvertible] = []

            if !normalizedQuery.isEmpty {
                sql += """
                 WHERE EXISTS (
                    SELECT 1
                    FROM chat_messages sm
                    WHERE sm.threadId = t.id
                      AND lower(sm.content) LIKE ?
                )
                """
                args.append("%\(normalizedQuery)%")
            }

            sql += """
             GROUP BY t.id, t.createdAt, t.updatedAt
             HAVING COUNT(m.id) > 0
             ORDER BY COALESCE(MAX(m.timestamp), t.updatedAt, t.createdAt) DESC
             LIMIT ?
            """
            args.append(limit)

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
            return rows.compactMap { row -> ChatThreadSummary? in
                guard let id = row["threadID"] as? String,
                      let createdAt = parseDate(row["createdAt"]),
                      let updatedAt = parseDate(row["updatedAt"]) else {
                    return nil
                }

                let messageCount = row["messageCount"] as? Int
                    ?? Int((row["messageCount"] as? Int64) ?? 0)
                let lastMessageAt = parseDate(row["lastMessageAt"])
                let firstUserMessage = (row["firstUserMessage"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let lastMessageContent = (row["lastMessageContent"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let titleSource = (firstUserMessage?.isEmpty == false) ? firstUserMessage! : "Burn Bar Chat"
                let previewSource = (lastMessageContent?.isEmpty == false) ? lastMessageContent! : titleSource

                return ChatThreadSummary(
                    id: id,
                    title: Self.compactChatSnippet(titleSource, limit: 84),
                    preview: Self.compactChatSnippet(previewSource, limit: 180),
                    messageCount: messageCount,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    lastMessageAt: lastMessageAt
                )
            }
        }
    }

    func fetchChatMessages() throws -> [ChatMessageRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM chat_messages ORDER BY timestamp ASC")
            return rows.compactMap { self.chatMessage(from: $0) }
        }
    }

    func fetchChatMessages(threadID: String) throws -> [ChatMessageRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM chat_messages WHERE threadId = ? ORDER BY timestamp ASC",
                arguments: [threadID]
            )
            return rows.compactMap { self.chatMessage(from: $0) }
        }
    }

    func deleteAllChatMessages() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM chat_messages")
            try db.execute(sql: "DELETE FROM chat_threads")
            let now = Date()
            try db.execute(
                sql: "INSERT INTO chat_threads (id, createdAt, updatedAt) VALUES (?, ?, ?)",
                arguments: [Self.legacyChatThreadID, now, now]
            )
        }
    }

    private func chatMessage(from row: Row) -> ChatMessageRecord? {
        guard let id = row["id"] as? String,
              let roleRaw = row["role"] as? String,
              let role = ChatMessageRole(rawValue: roleRaw),
              let content = row["content"] as? String,
              let ts = parseDate(row["timestamp"]) else {
            return nil
        }

        let pieces = Self.decodeTranscriptPieces(row["transcriptPiecesJSON"] as? String) ?? []
        return ChatMessageRecord(
            id: id,
            role: role,
            content: content,
            timestamp: ts,
            cliUsed: row["cliUsed"] as? String,
            transcriptPieces: pieces
        )
    }

    private func upsertChatThread(_ threadID: String, at timestamp: Date, db: Database) throws {
        try db.execute(
            sql: """
            INSERT OR IGNORE INTO chat_threads (id, createdAt, updatedAt)
            VALUES (?, ?, ?)
            """,
            arguments: [threadID, timestamp, timestamp]
        )
        try db.execute(
            sql: """
            UPDATE chat_threads
            SET updatedAt = CASE WHEN updatedAt > ? THEN updatedAt ELSE ? END
            WHERE id = ?
            """,
            arguments: [timestamp, timestamp, threadID]
        )
    }

    // MARK: - Full-text search

    func searchConversationsFTS(
        query: String,
        provider: AgentProvider? = nil,
        projectName: String? = nil,
        dateRange: ClosedRange<Date>? = nil
    ) throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let ftsQuery = BurnBarFTSQueryBuilder.naturalLanguage(from: trimmed)
        guard !ftsQuery.isEmpty else { return [] }

        return try dbQueue.read { db -> [SearchResult] in
            var sql = """
            SELECT c.*, bm25(conversations_fts) AS rank,
            snippet(conversations_fts, 1, '<b>', '</b>', '…', 10) AS snip
            FROM conversations_fts
            JOIN conversations AS c ON c.rowid = conversations_fts.rowid
            WHERE conversations_fts MATCH ?
            """
            var args: [any DatabaseValueConvertible] = [ftsQuery]

            if let provider {
                sql += " AND c.provider = ?"
                args.append(provider.rawValue)
            }
            if let projectName {
                sql += " AND c.projectName = ?"
                args.append(projectName)
            }
            if let range = dateRange {
                sql += " AND c.startTime >= ? AND c.startTime <= ?"
                args.append(range.lowerBound)
                args.append(range.upperBound)
            }

            sql += " ORDER BY rank ASC LIMIT 50"

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
            var results = rows.compactMap { row -> SearchResult? in
                guard let conv = Self.conversation(from: row) else { return nil }
                let rank = (row["rank"] as? Double) ?? Double(row["rank"] as? Int64 ?? 0)
                let snip = (row["snip"] as? String) ?? ""
                return SearchResult(conversation: conv, snippet: snip, rank: rank)
            }

            if results.count < 50 {
                var fallbackSQL = """
                SELECT c.*
                FROM conversations AS c
                WHERE (
                    LOWER(COALESCE(c.summaryTitle, '')) LIKE ?
                    OR LOWER(COALESCE(c.summary, '')) LIKE ?
                )
                """
                var fallbackArgs: [any DatabaseValueConvertible] = [
                    "%\(trimmed.lowercased())%",
                    "%\(trimmed.lowercased())%"
                ]

                if let provider {
                    fallbackSQL += " AND c.provider = ?"
                    fallbackArgs.append(provider.rawValue)
                }
                if let projectName {
                    fallbackSQL += " AND c.projectName = ?"
                    fallbackArgs.append(projectName)
                }
                if let range = dateRange {
                    fallbackSQL += " AND c.startTime >= ? AND c.startTime <= ?"
                    fallbackArgs.append(range.lowerBound)
                    fallbackArgs.append(range.upperBound)
                }

                fallbackSQL += " ORDER BY COALESCE(c.endTime, c.startTime, c.indexedAt) DESC LIMIT 50"
                let fallbackRows = try Row.fetchAll(db, sql: fallbackSQL, arguments: StatementArguments(fallbackArgs))
                var seen = Set(results.map { $0.conversation.id })
                for row in fallbackRows {
                    guard let conv = Self.conversation(from: row), !seen.contains(conv.id) else { continue }
                    seen.insert(conv.id)
                    let fallbackSnippet = conv.summary ?? conv.summaryTitle ?? conv.inferredTaskTitle
                    results.append(
                        SearchResult(
                            conversation: conv,
                            snippet: fallbackSnippet,
                            rank: (results.last?.rank ?? 0) + 100
                        )
                    )
                    if results.count >= 50 { break }
                }
            }

            return results
        }
    }

    // MARK: - Local search substrate (derived/rebuildable)

    func enqueueConversationProjectionJob(
        conversationID: String,
        jobType: ProjectionJobType = .reproject,
        priority: Int = 5,
        now: Date = Date()
    ) throws {
        guard let conversation = try fetchConversation(id: conversationID) else { return }
        let sourceVersionID = ProjectionIdentity.conversationSourceVersionID(for: conversation)
        try enqueueProjectionJob(
            ProjectionJobRecord(
                id: ProjectionIdentity.jobID(
                    jobType: jobType,
                    sourceKind: .conversation,
                    sourceID: conversation.id,
                    sourceVersionID: sourceVersionID
                ),
                jobType: jobType,
                sourceKind: .conversation,
                sourceID: conversation.id,
                sourceVersionID: sourceVersionID,
                status: .queued,
                priority: min(max(priority, 0), 10_000),
                attempts: 0,
                maxAttempts: 5,
                scheduledAt: now,
                availableAt: now,
                createdAt: now,
                updatedAt: now
            )
        )
    }

    func upsertSearchDocument(_ document: SearchDocumentRecord) throws {
        try localSearchStore.upsertDocument(document)
    }

    func fetchSearchDocuments(limit: Int = 500) throws -> [SearchDocumentRecord] {
        try localSearchStore.fetchDocuments(limit: limit)
    }

    func fetchSearchDocuments(
        limit: Int = 500,
        provider: AgentProvider? = nil,
        projectName: String? = nil,
        sourceKinds: [SearchSourceKind]? = nil,
        dateRange: ClosedRange<Date>? = nil
    ) throws -> [SearchDocumentRecord] {
        try localSearchStore.fetchDocuments(
            limit: limit,
            provider: provider?.rawValue,
            projectName: projectName,
            sourceKinds: sourceKinds,
            dateRange: dateRange
        )
    }

    func fetchSearchDocuments(ids: [String]) throws -> [SearchDocumentRecord] {
        try localSearchStore.fetchDocuments(ids: ids)
    }

    func fetchSearchDocument(id: String) throws -> SearchDocumentRecord? {
        try localSearchStore.fetchDocument(id: id)
    }

    func fetchSearchDocuments(sourceKind: SearchSourceKind, sourceID: String) throws -> [SearchDocumentRecord] {
        try localSearchStore.fetchDocuments(sourceKind: sourceKind, sourceID: sourceID)
    }

    func countSearchDocuments(
        provider: AgentProvider? = nil,
        projectName: String? = nil,
        sourceKinds: [SearchSourceKind]? = nil,
        dateRange: ClosedRange<Date>? = nil
    ) throws -> Int {
        try localSearchStore.countDocuments(
            provider: provider?.rawValue,
            projectName: projectName,
            sourceKinds: sourceKinds,
            dateRange: dateRange
        )
    }

    func countSearchChunks(
        sourceKinds: [SearchSourceKind]? = nil,
        dateRange: ClosedRange<Date>? = nil
    ) throws -> Int {
        try localSearchStore.countChunks(
            sourceKinds: sourceKinds,
            dateRange: dateRange
        )
    }

    func countSearchChunks(documentID: String) throws -> Int {
        try localSearchStore.countChunks(documentID: documentID)
    }

    func replaceSearchChunks(documentID: String, title: String, chunks: [SearchChunkRecord]) throws {
        try localSearchStore.replaceChunks(documentID: documentID, title: title, chunks: chunks)
    }

    func fetchSearchChunks(documentID: String) throws -> [SearchChunkRecord] {
        try localSearchStore.fetchChunks(documentID: documentID)
    }

    func fetchSearchChunks(ids: [String]) throws -> [SearchChunkRecord] {
        try localSearchStore.fetchChunks(ids: ids)
    }

    func fetchSearchChunks(sourceKind: SearchSourceKind, sourceID: String) throws -> [SearchChunkRecord] {
        try localSearchStore.fetchChunks(sourceKind: sourceKind, sourceID: sourceID)
    }

    func searchLexicalChunks(
        ftsQuery: String,
        provider: AgentProvider? = nil,
        projectName: String? = nil,
        sourceKinds: [SearchSourceKind]? = nil,
        dateRange: ClosedRange<Date>? = nil,
        visibility: SearchVisibilityScope = .all,
        sharedArtifactAccessContext: SharedArtifactAccessContext? = nil,
        sourceIDs: [String]? = nil,
        limit: Int = 120
    ) throws -> [SearchChunkLexicalMatch] {
        let trimmed = ftsQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return try localSearchStore.searchLexicalChunks(
            ftsQuery: trimmed,
            provider: provider?.rawValue,
            projectName: projectName,
            sourceKinds: sourceKinds,
            dateRange: dateRange,
            visibility: visibility,
            sharedArtifactAccessContext: sharedArtifactAccessContext,
            sourceIDs: sourceIDs,
            limit: limit
        )
    }

    /// Sums non-overlapping substring occurrence counts of each pattern in `conversations.fullText` (case-insensitive).
    func countOccurrencesInConversationFullText(
        patterns: [String],
        provider: AgentProvider? = nil,
        projectName: String? = nil,
        dateRange: ClosedRange<Date>? = nil,
        conversationSources: Set<ConversationSourceType>? = nil
    ) throws -> Int {
        let cleaned = patterns
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return 0 }

        var total = 0
        for raw in cleaned {
            let pattern = raw.lowercased()
            guard pattern.isEmpty == false else { continue }
            let n = try dbQueue.read { db -> Int in
                var sql = """
                SELECT COALESCE(SUM(
                    (LENGTH(COALESCE(c.fullText,'')) - LENGTH(REPLACE(LOWER(COALESCE(c.fullText,'')), ?, ''))) / LENGTH(?)
                ), 0)
                FROM conversations AS c
                WHERE 1 = 1
                """
                var args: [any DatabaseValueConvertible] = [pattern, pattern]
                if let provider {
                    sql += " AND c.provider = ?"
                    args.append(provider.rawValue)
                }
                if let projectName {
                    sql += " AND c.projectName = ?"
                    args.append(projectName)
                }
                if let range = dateRange {
                    sql += """
                     AND COALESCE(c.endTime, c.startTime, c.fileModifiedAt, c.indexedAt) >= ?
                     AND COALESCE(c.startTime, c.endTime, c.fileModifiedAt, c.indexedAt) <= ?
                    """
                    args.append(range.lowerBound)
                    args.append(range.upperBound)
                }
                if let sources = conversationSources, sources.isEmpty == false {
                    let rawVals = sources.map(\.rawValue)
                    let placeholders = Array(repeating: "?", count: rawVals.count).joined(separator: ", ")
                    sql += " AND c.sourceType IN (\(placeholders))"
                    args.append(contentsOf: rawVals)
                }
                let v = try Int64.fetchOne(db, sql: sql, arguments: StatementArguments(args)) ?? 0
                return Int(v)
            }
            total += n
        }
        return total
    }

    func findConversationFullTextMatches(
        patterns: [String],
        provider: AgentProvider? = nil,
        projectName: String? = nil,
        dateRange: ClosedRange<Date>? = nil,
        conversationSources: Set<ConversationSourceType>? = nil,
        limit: Int = 12
    ) throws -> [ConversationJumpTarget] {
        let cleanedPatterns = Array(
            Set(
                patterns
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        ).sorted()
        let boundedLimit = max(1, min(limit, 200))
        guard cleanedPatterns.isEmpty == false else { return [] }

        let conversations = try fetchConversationsForTranscriptScan(
            provider: provider,
            projectName: projectName,
            dateRange: dateRange,
            conversationSources: conversationSources
        )

        var results: [ConversationJumpTarget] = []
        var seen = Set<String>()

        for conversation in conversations {
            let original = conversation.fullText
            guard original.isEmpty == false else { continue }

            let lowered = original.lowercased() as NSString
            let originalNSString = original as NSString

            for pattern in cleanedPatterns {
                let patternLength = pattern.count
                guard patternLength > 0 else { continue }

                var searchRange = NSRange(location: 0, length: lowered.length)
                while searchRange.length > 0 {
                    let found = lowered.range(of: pattern, options: [], range: searchRange)
                    guard found.location != NSNotFound else { break }

                    let dedupeKey = "\(conversation.id)|\(found.location)|\(found.length)"
                    if seen.insert(dedupeKey).inserted {
                        results.append(
                            ConversationJumpTarget(
                                conversation: conversation,
                                snippet: Self.aggregateMatchSnippet(
                                    text: originalNSString,
                                    matchRange: found
                                ),
                                startOffset: found.location,
                                endOffset: found.location + found.length,
                                source: .aggregateExact
                            )
                        )
                        if results.count >= boundedLimit {
                            return results
                        }
                    }

                    let nextLocation = found.location + max(found.length, 1)
                    guard nextLocation < lowered.length else { break }
                    searchRange = NSRange(location: nextLocation, length: lowered.length - nextLocation)
                }
            }
        }

        return results
    }

    func countOccurrencesInConversationFullTextByProvider(
        patterns: [String],
        projectName: String? = nil,
        dateRange: ClosedRange<Date>? = nil,
        conversationSources: Set<ConversationSourceType>? = nil
    ) throws -> [ConversationProviderOccurrence] {
        let cleanedPatterns = Array(
            Set(
                patterns
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        ).sorted()
        guard cleanedPatterns.isEmpty == false else { return [] }

        let conversations = try fetchConversationsForTranscriptScan(
            provider: nil,
            projectName: projectName,
            dateRange: dateRange,
            conversationSources: conversationSources
        )

        struct MutableProviderCount {
            var occurrenceCount: Int = 0
            var conversationCount: Int = 0
        }

        var grouped: [AgentProvider: MutableProviderCount] = [:]
        for conversation in conversations {
            let lower = conversation.fullText.lowercased()
            guard lower.isEmpty == false else { continue }

            var conversationOccurrences = 0
            for pattern in cleanedPatterns {
                conversationOccurrences += Self.nonOverlappingOccurrenceCount(of: pattern, in: lower)
            }
            guard conversationOccurrences > 0 else { continue }

            var current = grouped[conversation.provider] ?? MutableProviderCount()
            current.occurrenceCount += conversationOccurrences
            current.conversationCount += 1
            grouped[conversation.provider] = current
        }

        return grouped
            .map { provider, counts in
                ConversationProviderOccurrence(
                    provider: provider,
                    occurrenceCount: counts.occurrenceCount,
                    conversationCount: counts.conversationCount
                )
            }
            .sorted {
                if $0.occurrenceCount != $1.occurrenceCount {
                    return $0.occurrenceCount > $1.occurrenceCount
                }
                if $0.conversationCount != $1.conversationCount {
                    return $0.conversationCount > $1.conversationCount
                }
                return $0.provider.displayName < $1.provider.displayName
            }
    }

    func scanConversationFullTextForCredentialExposure(
        provider: AgentProvider? = nil,
        projectName: String? = nil,
        dateRange: ClosedRange<Date>? = nil,
        conversationSources: Set<ConversationSourceType>? = nil,
        limit: Int = 12
    ) throws -> CredentialExposureScanResult {
        let boundedLimit = max(1, min(limit, 200))
        let conversations = try fetchConversationsForTranscriptScan(
            provider: provider,
            projectName: projectName,
            dateRange: dateRange,
            conversationSources: conversationSources
        )

        let regexes = Self.credentialExposureRegexes
        guard !regexes.isEmpty else {
            return CredentialExposureScanResult(totalMatches: 0, jumpTargets: [])
        }
        var totalMatches = 0
        var jumpTargets: [ConversationJumpTarget] = []
        var seen = Set<String>()

        for conversation in conversations {
            let text = conversation.fullText
            guard text.isEmpty == false else { continue }
            let nsText = text as NSString

            for regex in regexes {
                let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
                for match in matches {
                    let matchText = nsText.substring(with: match.range)
                    if Self.looksLikePlaceholderCredential(matchText) {
                        continue
                    }

                    let dedupeKey = "\(conversation.id)|\(match.range.location)|\(match.range.length)"
                    guard seen.insert(dedupeKey).inserted else { continue }

                    totalMatches += 1
                    if jumpTargets.count < boundedLimit {
                        jumpTargets.append(
                            ConversationJumpTarget(
                                conversation: conversation,
                                snippet: Self.aggregateMatchSnippet(text: nsText, matchRange: match.range),
                                startOffset: match.range.location,
                                endOffset: match.range.location + match.range.length,
                                source: .aggregateExact
                            )
                        )
                    }
                }
            }
        }

        return CredentialExposureScanResult(totalMatches: totalMatches, jumpTargets: jumpTargets)
    }

    private func fetchConversationsForTranscriptScan(
        provider: AgentProvider?,
        projectName: String?,
        dateRange: ClosedRange<Date>?,
        conversationSources: Set<ConversationSourceType>?
    ) throws -> [ConversationRecord] {
        try dbQueue.read { db -> [ConversationRecord] in
            var sql = """
            SELECT *
            FROM conversations AS c
            WHERE 1 = 1
            """
            var args: [any DatabaseValueConvertible] = []
            if let provider {
                sql += " AND c.provider = ?"
                args.append(provider.rawValue)
            }
            if let projectName {
                sql += " AND c.projectName = ?"
                args.append(projectName)
            }
            if let range = dateRange {
                sql += """
                 AND COALESCE(c.endTime, c.startTime, c.fileModifiedAt, c.indexedAt) >= ?
                 AND COALESCE(c.startTime, c.endTime, c.fileModifiedAt, c.indexedAt) <= ?
                """
                args.append(range.lowerBound)
                args.append(range.upperBound)
            }
            if let sources = conversationSources, sources.isEmpty == false {
                let rawVals = sources.map(\.rawValue).sorted()
                let placeholders = Array(repeating: "?", count: rawVals.count).joined(separator: ", ")
                sql += " AND c.sourceType IN (\(placeholders))"
                args.append(contentsOf: rawVals)
            }
            sql += " ORDER BY COALESCE(c.endTime, c.startTime, c.indexedAt) DESC"

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
            return rows.compactMap(Self.conversation(from:))
        }
    }

    private static func aggregateMatchSnippet(text: NSString, matchRange: NSRange, radius: Int = 120) -> String {
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

    private static let _credentialExposureRegexes: [NSRegularExpression]? = {
        let patterns = [
            #"(?i)\b[A-Z0-9_]*(?:API[_-]?KEY|ACCESS[_-]?TOKEN|TOKEN|SECRET|PASSWORD)\b\s*[:=]\s*["']?[A-Za-z0-9_\-./+=]{8,}"#,
            #"\bsk-[A-Za-z0-9]{16,}\b"#,
            #"\bAIza[0-9A-Za-z\-_]{16,}\b"#,
            #"\bgh[pousr]_[A-Za-z0-9]{20,}\b"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private static var credentialExposureRegexes: [NSRegularExpression] {
        _credentialExposureRegexes ?? []
    }

    private static func nonOverlappingOccurrenceCount(of pattern: String, in lowercasedText: String) -> Int {
        guard pattern.isEmpty == false, lowercasedText.isEmpty == false else { return 0 }
        var count = 0
        var searchStart = lowercasedText.startIndex
        while searchStart < lowercasedText.endIndex,
              let range = lowercasedText.range(of: pattern, range: searchStart..<lowercasedText.endIndex) {
            count += 1
            searchStart = range.upperBound
        }
        return count
    }

    private static func looksLikePlaceholderCredential(_ text: String) -> Bool {
        let lower = text.lowercased()
        let placeholders = [
            "your-key", "your_key", "your key", "key-here", "placeholder",
            "example", "dummy", "changeme", "replace-me", "***", "<", "test"
        ]
        return placeholders.contains { lower.contains($0) }
    }

    func upsertSourceArtifact(_ artifact: SourceArtifactRecord) throws -> SourceArtifactWriteDisposition {
        try localSearchStore.upsertSourceArtifact(artifact)
    }

    func fetchSourceArtifacts(
        includeDeleted: Bool = false,
        rootPaths: [String]? = nil,
        sourceKinds: [SearchSourceKind] = [.skillDoc, .agentDoc, .sharedArtifact]
    ) throws -> [SourceArtifactRecord] {
        try localSearchStore.fetchSourceArtifacts(
            includeDeleted: includeDeleted,
            rootPaths: rootPaths,
            sourceKinds: sourceKinds
        )
    }

    func countSourceArtifacts(
        includeDeleted: Bool = false,
        rootPaths: [String]? = nil,
        sourceKinds: [SearchSourceKind] = [.skillDoc, .agentDoc, .sharedArtifact]
    ) throws -> Int {
        try localSearchStore.countSourceArtifacts(
            includeDeleted: includeDeleted,
            rootPaths: rootPaths,
            sourceKinds: sourceKinds
        )
    }

    func fetchSourceArtifact(id: String, includeDeleted: Bool = false) throws -> SourceArtifactRecord? {
        try localSearchStore.fetchSourceArtifact(id: id, includeDeleted: includeDeleted)
    }

    @discardableResult
    func markSourceArtifactDeleted(id: String, deletedAt: Date = Date()) throws -> Bool {
        try localSearchStore.markSourceArtifactDeleted(id: id, deletedAt: deletedAt)
    }

    func upsertSharedArtifactSyncState(_ state: SharedArtifactSyncStateRecord) throws {
        try localSearchStore.upsertSharedArtifactSyncState(state)
    }

    func fetchSharedArtifactSyncState(sourceArtifactID: String) throws -> SharedArtifactSyncStateRecord? {
        try localSearchStore.fetchSharedArtifactSyncState(sourceArtifactID: sourceArtifactID)
    }

    func fetchSharedArtifactSyncState(remoteArtifactID: String) throws -> SharedArtifactSyncStateRecord? {
        try localSearchStore.fetchSharedArtifactSyncState(remoteArtifactID: remoteArtifactID)
    }

    func fetchSharedArtifactSyncStates(
        workspaceID: String? = nil,
        teamID: String? = nil,
        statuses: [SharedArtifactSyncStatus]? = nil,
        limit: Int = 500
    ) throws -> [SharedArtifactSyncStateRecord] {
        try localSearchStore.fetchSharedArtifactSyncStates(
            workspaceID: workspaceID,
            teamID: teamID,
            statuses: statuses,
            limit: limit
        )
    }

    func countSharedArtifactSyncStates(
        workspaceID: String? = nil,
        teamID: String? = nil,
        statuses: [SharedArtifactSyncStatus]? = nil
    ) throws -> Int {
        try localSearchStore.countSharedArtifactSyncStates(
            workspaceID: workspaceID,
            teamID: teamID,
            statuses: statuses
        )
    }

    func upsertSharedArtifactPermission(_ permission: SharedArtifactPermissionRecord) throws -> SharedArtifactPermissionWriteDisposition {
        try localSearchStore.upsertSharedArtifactPermission(permission)
    }

    func replaceSharedArtifactPermissions(
        sourceArtifactID: String,
        permissions: [SharedArtifactPermissionRecord]
    ) throws {
        try localSearchStore.replaceSharedArtifactPermissions(
            sourceArtifactID: sourceArtifactID,
            permissions: permissions
        )
    }

    func fetchSharedArtifactPermissions(
        sourceArtifactID: String? = nil,
        workspaceID: String? = nil,
        teamID: String? = nil,
        principalType: SharedArtifactPrincipalType? = nil,
        principalID: String? = nil,
        limit: Int = 500
    ) throws -> [SharedArtifactPermissionRecord] {
        try localSearchStore.fetchSharedArtifactPermissions(
            sourceArtifactID: sourceArtifactID,
            workspaceID: workspaceID,
            teamID: teamID,
            principalType: principalType,
            principalID: principalID,
            limit: limit
        )
    }

    func countSharedArtifactPermissions(
        sourceArtifactID: String? = nil,
        workspaceID: String? = nil,
        teamID: String? = nil,
        principalType: SharedArtifactPrincipalType? = nil,
        principalID: String? = nil
    ) throws -> Int {
        try localSearchStore.countSharedArtifactPermissions(
            sourceArtifactID: sourceArtifactID,
            workspaceID: workspaceID,
            teamID: teamID,
            principalType: principalType,
            principalID: principalID
        )
    }

    func fetchReadableSharedArtifactSourceIDs(
        accessContext: SharedArtifactAccessContext,
        limit: Int = 2_000
    ) throws -> Set<String> {
        Set(
            try localSearchStore.fetchReadableSharedArtifactSourceIDs(
                accessContext: accessContext,
                limit: limit
            )
        )
    }

    func appendSharedArtifactAuditEvent(_ event: SharedArtifactAuditEventRecord) throws {
        try localSearchStore.appendSharedArtifactAuditEvent(event)
    }

    func fetchSharedArtifactAuditEvents(
        sourceArtifactID: String? = nil,
        workspaceID: String? = nil,
        teamID: String? = nil,
        actions: [SharedArtifactAuditAction]? = nil,
        limit: Int = 500
    ) throws -> [SharedArtifactAuditEventRecord] {
        try localSearchStore.fetchSharedArtifactAuditEvents(
            sourceArtifactID: sourceArtifactID,
            workspaceID: workspaceID,
            teamID: teamID,
            actions: actions,
            limit: limit
        )
    }

    func countSharedArtifactAuditEvents(
        sourceArtifactID: String? = nil,
        workspaceID: String? = nil,
        teamID: String? = nil,
        actions: [SharedArtifactAuditAction]? = nil
    ) throws -> Int {
        try localSearchStore.countSharedArtifactAuditEvents(
            sourceArtifactID: sourceArtifactID,
            workspaceID: workspaceID,
            teamID: teamID,
            actions: actions
        )
    }

    func enqueueProjectionJob(_ job: ProjectionJobRecord) throws {
        try localSearchStore.enqueueProjectionJob(job)
    }

    func appendOperatingActionRecord(_ record: BurnBarOperatingActionRecord) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO operating_action_history (
                    id, projectName, missionFingerprint, actionKind, summary,
                    detail, overrideMode, forcedDirectionStatus, createdAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO NOTHING
                """,
                arguments: [
                    record.id,
                    record.projectName,
                    record.missionFingerprint,
                    record.actionKind.rawValue,
                    record.summary,
                    record.detail,
                    record.overrideMode?.rawValue,
                    record.forcedDirectionStatus?.rawValue,
                    record.createdAt,
                ]
            )
        }
    }

    func fetchOperatingActionRecords(
        projectName: String? = nil,
        actionKinds: [BurnBarActionKind]? = nil,
        limit: Int = 100
    ) throws -> [BurnBarOperatingActionRecord] {
        if let actionKinds, actionKinds.isEmpty { return [] }

        var clauses: [String] = []
        var args: [any DatabaseValueConvertible] = []

        if let projectName = projectName?.trimmingCharacters(in: .whitespacesAndNewlines), projectName.isEmpty == false {
            clauses.append("projectName = ?")
            args.append(projectName)
        }
        if let actionKinds, actionKinds.isEmpty == false {
            clauses.append("actionKind IN (\(Array(repeating: "?", count: actionKinds.count).joined(separator: ", ")))")
            args.append(contentsOf: actionKinds.map(\.rawValue))
        }

        args.append(max(1, limit))
        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")

        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM operating_action_history
                \(whereSQL)
                ORDER BY createdAt DESC, id ASC
                LIMIT ?
                """,
                arguments: StatementArguments(args)
            )
            return rows.compactMap { row in
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
                    createdAt: self.parseDate(row["createdAt"]) ?? Date()
                )
            }
        }
    }

    func countOperatingActionRecords(
        projectName: String? = nil,
        actionKinds: [BurnBarActionKind]? = nil
    ) throws -> Int {
        if let actionKinds, actionKinds.isEmpty { return 0 }

        var clauses: [String] = []
        var args: [any DatabaseValueConvertible] = []

        if let projectName = projectName?.trimmingCharacters(in: .whitespacesAndNewlines), projectName.isEmpty == false {
            clauses.append("projectName = ?")
            args.append(projectName)
        }
        if let actionKinds, actionKinds.isEmpty == false {
            clauses.append("actionKind IN (\(Array(repeating: "?", count: actionKinds.count).joined(separator: ", ")))")
            args.append(contentsOf: actionKinds.map(\.rawValue))
        }

        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        return try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM operating_action_history
                \(whereSQL)
                """,
                arguments: StatementArguments(args)
            ) ?? 0
        }
    }

    func saveControllerRuntimeMirror(
        _ snapshot: BurnBarControllerRuntimeSnapshot,
        cacheKey: String = "latest"
    ) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        guard let payloadJSON = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "BurnBar.ControllerRuntime", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Controller runtime payload could not be encoded as UTF-8."
            ])
        }

        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO controller_runtime_cache (cacheKey, payloadJSON, updatedAt)
                VALUES (?, ?, ?)
                ON CONFLICT(cacheKey) DO UPDATE SET
                    payloadJSON = excluded.payloadJSON,
                    updatedAt = excluded.updatedAt
                """,
                arguments: [cacheKey, payloadJSON, snapshot.updatedAt]
            )
        }
    }

    func fetchControllerRuntimeMirror(
        cacheKey: String = "latest"
    ) throws -> BurnBarControllerRuntimeSnapshot? {
        try dbQueue.read { db in
            guard let payloadJSON = try String.fetchOne(
                db,
                sql: "SELECT payloadJSON FROM controller_runtime_cache WHERE cacheKey = ?",
                arguments: [cacheKey]
            ) else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let data = payloadJSON.data(using: .utf8) else { return nil }
            return try decoder.decode(BurnBarControllerRuntimeSnapshot.self, from: data)
        }
    }

    func localAuthoritySnapshot() throws -> BurnBarLocalAuthoritySnapshot {
        try dbQueue.read { db in
            let usageRows = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM token_usage") ?? 0
            let conversationRows = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM conversations") ?? 0
            let sourceArtifactsTableExists = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'source_artifacts'"
            ) ?? 0
            let sharedArtifacts = sourceArtifactsTableExists > 0
                ? ((try? Int.fetchOne(db, sql: "SELECT COUNT(*) FROM source_artifacts")) ?? 0)
                : 0
            let cachedMirror = (try String.fetchOne(
                db,
                sql: "SELECT cacheKey FROM controller_runtime_cache WHERE cacheKey = ? LIMIT 1",
                arguments: ["latest"]
            )) != nil

            return BurnBarLocalAuthoritySnapshot(
                usageRowCount: usageRows,
                conversationRowCount: conversationRows,
                sharedArtifactCount: sharedArtifacts,
                controllerRuntimeCached: cachedMirror
            )
        }
    }

    func mutateControllerRuntimeMirror(
        cacheKey: String = "latest",
        _ mutate: (inout BurnBarControllerRuntimeSnapshot) -> Void
    ) throws {
        var snapshot = try fetchControllerRuntimeMirror(cacheKey: cacheKey) ?? .empty
        mutate(&snapshot)
        try saveControllerRuntimeMirror(snapshot, cacheKey: cacheKey)
    }

    @discardableResult
    func answerControllerQuestion(
        id: String,
        answer: String,
        selectedOptionID: String? = nil,
        cacheKey: String = "latest",
        answeredAt: Date = Date()
    ) throws -> Bool {
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAnswer.isEmpty == false else { return false }

        var updated = false
        try mutateControllerRuntimeMirror(cacheKey: cacheKey) { snapshot in
            guard let index = snapshot.questions.firstIndex(where: { $0.id == id }) else { return }
            let question = snapshot.questions[index]
            guard question.state == .pending else { return }
            snapshot.questions[index] = BurnBarControllerQuestion(
                id: question.id,
                projectName: question.projectName,
                sessionID: question.sessionID,
                title: question.title,
                prompt: question.prompt,
                stageLabel: question.stageLabel,
                evidenceHint: question.evidenceHint,
                state: .answered,
                priority: question.priority,
                sourceLabel: question.sourceLabel,
                createdAt: question.createdAt,
                answeredAt: answeredAt,
                answer: trimmedAnswer,
                selectedOptionID: selectedOptionID,
                answerPlaceholder: question.answerPlaceholder,
                suggestedOptions: question.suggestedOptions,
                deepLink: question.deepLink,
                isUnread: false,
                notificationCount: question.notificationCount
            )
            snapshot.recentEvents.insert(
                BurnBarControllerEvent(
                    projectName: question.projectName,
                    category: .question,
                    title: "Question answered",
                    summary: question.title,
                    detail: trimmedAnswer,
                    createdAt: answeredAt
                ),
                at: 0
            )
            snapshot.recentEvents = Array(snapshot.recentEvents.prefix(10))
            snapshot.updatedAt = answeredAt
            snapshot.summary = snapshot.summary.recounted(
                pendingQuestions: snapshot.questions.filter { $0.state == .pending }.count,
                unresolvedFollowups: snapshot.followups.filter { $0.state == .open }.count,
                openMissions: snapshot.missions.filter { $0.state != .completed }.count
            )
            updated = true
        }
        return updated
    }

    @discardableResult
    func completeControllerFollowup(
        id: String,
        cacheKey: String = "latest",
        completedAt: Date = Date()
    ) throws -> Bool {
        var updated = false
        try mutateControllerRuntimeMirror(cacheKey: cacheKey) { snapshot in
            guard let index = snapshot.followups.firstIndex(where: { $0.id == id }) else { return }
            let followup = snapshot.followups[index]
            guard followup.state != .done else { return }
            snapshot.followups[index] = followup.updating(state: .done, updatedAt: completedAt)
            snapshot.recentEvents.insert(
                BurnBarControllerEvent(
                    projectName: followup.projectName,
                    category: .followup,
                    title: "Followup completed",
                    summary: followup.title,
                    detail: followup.summary,
                    createdAt: completedAt
                ),
                at: 0
            )
            snapshot.recentEvents = Array(snapshot.recentEvents.prefix(10))
            snapshot.updatedAt = completedAt
            snapshot.summary = snapshot.summary.recounted(
                pendingQuestions: snapshot.questions.filter { $0.state == .pending }.count,
                unresolvedFollowups: snapshot.followups.filter { $0.state == .open }.count,
                openMissions: snapshot.missions.filter { $0.state != .completed }.count
            )
            updated = true
        }
        return updated
    }

    @discardableResult
    func snoozeControllerFollowup(
        id: String,
        until: Date,
        cacheKey: String = "latest",
        updatedAt: Date = Date()
    ) throws -> Bool {
        var updated = false
        try mutateControllerRuntimeMirror(cacheKey: cacheKey) { snapshot in
            guard let index = snapshot.followups.firstIndex(where: { $0.id == id }) else { return }
            let followup = snapshot.followups[index]
            snapshot.followups[index] = followup.updating(
                state: .snoozed,
                snoozedUntil: until,
                updatedAt: updatedAt
            )
            snapshot.recentEvents.insert(
                BurnBarControllerEvent(
                    projectName: followup.projectName,
                    category: .followup,
                    title: "Followup snoozed",
                    summary: followup.title,
                    detail: "Snoozed until \(until.formatted(date: .abbreviated, time: .shortened)).",
                    createdAt: updatedAt
                ),
                at: 0
            )
            snapshot.recentEvents = Array(snapshot.recentEvents.prefix(10))
            snapshot.updatedAt = updatedAt
            snapshot.summary = snapshot.summary.recounted(
                pendingQuestions: snapshot.questions.filter { $0.state == .pending }.count,
                unresolvedFollowups: snapshot.followups.filter { $0.state == .open }.count,
                openMissions: snapshot.missions.filter { $0.state != .completed }.count
            )
            updated = true
        }
        return updated
    }

    @discardableResult
    func scheduleControllerFollowupCalendar(
        id: String,
        title: String?,
        start: Date,
        durationMinutes: Int,
        cacheKey: String = "latest",
        updatedAt: Date = Date()
    ) throws -> Bool {
        var updated = false
        try mutateControllerRuntimeMirror(cacheKey: cacheKey) { snapshot in
            guard let index = snapshot.followups.firstIndex(where: { $0.id == id }) else { return }
            let followup = snapshot.followups[index]
            let resolvedTitle: String
            if let title {
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                resolvedTitle = trimmedTitle.isEmpty ? followup.title : trimmedTitle
            } else {
                resolvedTitle = followup.title
            }
            let end = start.addingTimeInterval(Double(max(durationMinutes, 15)) * 60)
            snapshot.followups[index] = followup.updating(
                calendarTitle: resolvedTitle,
                calendarStart: start,
                calendarEnd: end,
                updatedAt: updatedAt
            )
            snapshot.recentEvents.insert(
                BurnBarControllerEvent(
                    projectName: followup.projectName,
                    category: .notification,
                    title: "Calendar hold created",
                    summary: resolvedTitle,
                    detail: "\(start.formatted(date: .abbreviated, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))",
                    createdAt: updatedAt
                ),
                at: 0
            )
            snapshot.recentEvents = Array(snapshot.recentEvents.prefix(10))
            snapshot.updatedAt = updatedAt
            updated = true
        }
        return updated
    }

    func fetchProjectionJobs(
        statuses: [ProjectionJobStatus] = [.queued, .leased, .running, .failed],
        limit: Int = 100
    ) throws -> [ProjectionJobRecord] {
        try localSearchStore.fetchProjectionJobs(statuses: statuses, limit: limit)
    }

    func countProjectionJobs(statuses: [ProjectionJobStatus]? = nil) throws -> Int {
        try localSearchStore.countProjectionJobs(statuses: statuses)
    }

    func leaseNextProjectionJob(
        leaseOwner: String,
        leaseDuration: TimeInterval,
        now: Date = Date()
    ) throws -> ProjectionJobRecord? {
        try localSearchStore.leaseNextJob(
            leaseOwner: leaseOwner,
            leaseExpiresAt: now.addingTimeInterval(leaseDuration),
            now: now
        )
    }

    func markProjectionJobLeased(
        id: String,
        leaseOwner: String,
        leaseDuration: TimeInterval,
        now: Date = Date()
    ) throws {
        try localSearchStore.markJobLeased(
            id: id,
            leaseOwner: leaseOwner,
            leaseExpiresAt: now.addingTimeInterval(leaseDuration),
            updatedAt: now
        )
    }

    func markProjectionJobCompleted(id: String, completedAt: Date = Date()) throws {
        try localSearchStore.markJobCompleted(id: id, completedAt: completedAt)
    }

    func markProjectionJobFailed(
        id: String,
        errorCode: String?,
        errorMessage: String?,
        retryAt: Date? = nil,
        updatedAt: Date = Date()
    ) throws {
        try localSearchStore.markJobFailed(
            id: id,
            errorCode: errorCode,
            errorMessage: errorMessage,
            retryAt: retryAt,
            updatedAt: updatedAt
        )
    }

    func markProjectionJobCanceled(
        id: String,
        errorCode: String?,
        errorMessage: String?,
        updatedAt: Date = Date()
    ) throws {
        try localSearchStore.markJobCanceled(
            id: id,
            errorCode: errorCode,
            errorMessage: errorMessage,
            updatedAt: updatedAt
        )
    }

    func deleteSearchDocuments(sourceKind: SearchSourceKind, sourceID: String) throws {
        try localSearchStore.deleteDocuments(sourceKind: sourceKind, sourceID: sourceID)
    }

    func upsertEmbeddingModel(_ model: EmbeddingModelRecord) throws {
        try localSearchStore.upsertEmbeddingModel(model)
    }

    func fetchEmbeddingModels() throws -> [EmbeddingModelRecord] {
        try localSearchStore.fetchEmbeddingModels()
    }

    func countEmbeddingModels() throws -> Int {
        try localSearchStore.countEmbeddingModels()
    }

    func upsertEmbeddingVersion(_ version: EmbeddingVersionRecord) throws {
        try localSearchStore.upsertEmbeddingVersion(version)
    }

    func fetchEmbeddingVersions(modelID: String? = nil) throws -> [EmbeddingVersionRecord] {
        try localSearchStore.fetchEmbeddingVersions(modelID: modelID)
    }

    func countEmbeddingVersions(modelID: String? = nil) throws -> Int {
        try localSearchStore.countEmbeddingVersions(modelID: modelID)
    }

    func upsertChunkEmbedding(_ embedding: ChunkEmbeddingRecord) throws {
        try localSearchStore.upsertChunkEmbedding(embedding)
    }

    func fetchChunkEmbeddings(chunkID: String? = nil) throws -> [ChunkEmbeddingRecord] {
        try localSearchStore.fetchChunkEmbeddings(chunkID: chunkID)
    }

    func fetchChunkEmbeddings(embeddingVersionID: String) throws -> [ChunkEmbeddingRecord] {
        try localSearchStore.fetchChunkEmbeddings(embeddingVersionID: embeddingVersionID)
    }

    func countChunkEmbeddings(
        chunkID: String? = nil,
        embeddingVersionID: String? = nil
    ) throws -> Int {
        try localSearchStore.countChunkEmbeddings(
            chunkID: chunkID,
            embeddingVersionID: embeddingVersionID
        )
    }

    func countChunkEmbeddings(
        documentID: String,
        embeddingVersionID: String? = nil
    ) throws -> Int {
        try localSearchStore.countChunkEmbeddings(
            documentID: documentID,
            embeddingVersionID: embeddingVersionID
        )
    }

    func upsertRetrievalHealth(_ health: RetrievalHealthRecord) throws {
        try localSearchStore.upsertRetrievalHealth(health)
    }

    func fetchRetrievalHealth() throws -> [RetrievalHealthRecord] {
        try localSearchStore.fetchRetrievalHealth()
    }

    func localSearchSchemaInventory() throws -> LocalSearchSchemaInventory {
        try localSearchStore.schemaInventory()
    }

    func countConversations() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM conversations"
            ) ?? 0
        }
    }

    // MARK: - Conversation row mapping

    private static func fetchConversationRow(_ db: Database, id: String) throws -> ConversationRecord? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM conversations WHERE id = ?", arguments: [id]) else {
            return nil
        }
        return conversation(from: row)
    }

    private static func conversation(from row: Row) -> ConversationRecord? {
        guard let id = row["id"] as? String,
              let providerRaw = row["provider"] as? String,
              let provider = AgentProvider(rawValue: providerRaw),
              let sessionId = row["sessionId"] as? String,
              let projectName = row["projectName"] as? String else {
            return nil
        }
        let messageCount = (row["messageCount"] as? Int) ?? Int(row["messageCount"] as? Int64 ?? 0)
        let userWordCount = (row["userWordCount"] as? Int) ?? Int(row["userWordCount"] as? Int64 ?? 0)
        let assistantWordCount = (row["assistantWordCount"] as? Int) ?? Int(row["assistantWordCount"] as? Int64 ?? 0)
        let inferredTaskTitle = (row["inferredTaskTitle"] as? String) ?? ""
        let lastAssistantMessage = (row["lastAssistantMessage"] as? String) ?? ""
        let fullText = (row["fullText"] as? String) ?? ""

        let keyFiles = decodeJSONStringArray(row["keyFiles"] as? String)
        let keyCommands = decodeJSONStringArray(row["keyCommands"] as? String)
        let keyTools = decodeJSONStringArray(row["keyTools"] as? String)

        let startTime = Self.parseDateValue(row["startTime"])
        let endTime = Self.parseDateValue(row["endTime"])
        let indexedAt = Self.parseDateValue(row["indexedAt"]) ?? Date()
        let fileModifiedAt = Self.parseDateValue(row["fileModifiedAt"])

        let sourceTypeRaw = (row["sourceType"] as? String) ?? "provider_log"
        let sourceType = ConversationSourceType(rawValue: sourceTypeRaw) ?? .providerLog

        return ConversationRecord(
            id: id,
            provider: provider,
            sessionId: sessionId,
            projectName: projectName,
            startTime: startTime,
            endTime: endTime,
            messageCount: messageCount,
            userWordCount: userWordCount,
            assistantWordCount: assistantWordCount,
            keyFiles: keyFiles,
            keyCommands: keyCommands,
            keyTools: keyTools,
            inferredTaskTitle: inferredTaskTitle,
            lastAssistantMessage: lastAssistantMessage,
            fullText: fullText,
            indexedAt: indexedAt,
            fileModifiedAt: fileModifiedAt,
            summary: row["summary"] as? String,
            summaryTitle: row["summaryTitle"] as? String,
            summaryUpdatedAt: Self.parseDateValue(row["summaryUpdatedAt"]),
            summaryProvider: row["summaryProvider"] as? String,
            summaryModel: row["summaryModel"] as? String,
            sourceType: sourceType,
            sourceDeviceId: row["sourceDeviceId"] as? String,
            sourceDeviceName: row["sourceDeviceName"] as? String,
            isRemote: ((row["isRemote"] as? Int) ?? Int(row["isRemote"] as? Int64 ?? 0)) != 0
        )
    }

    private static func decodeJSONStringArray(_ string: String?) -> [String] {
        guard let string, !string.isEmpty, let data = string.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return arr
    }

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private static func encodeTranscriptPieces(_ value: [ChatTranscriptPiece]) throws -> String {
        try encodeJSON(value)
    }

    private static func decodeTranscriptPieces(_ string: String?) -> [ChatTranscriptPiece]? {
        guard let string, !string.isEmpty, let data = string.data(using: .utf8),
              let arr = try? JSONDecoder().decode([ChatTranscriptPiece].self, from: data) else {
            return nil
        }
        return arr
    }

    private static func compactChatSnippet(_ source: String, limit: Int) -> String {
        let compact = source
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > limit else { return compact }
        return String(compact.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    // MARK: - Session Logs

    /// All indexed conversations sorted by most-recent first, for the Session Logs center.
    func fetchAllSessionLogs(limit: Int = 1000) throws -> [ConversationRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM conversations ORDER BY COALESCE(endTime, startTime, indexedAt) DESC LIMIT ?",
                arguments: [limit]
            )
            return rows.compactMap { Self.conversation(from: $0) }
        }
    }

    /// Lightweight session-log rows for the list/sidebar.
    /// Uses an empty `fullText` payload so the list can render without hydrating every transcript body.
    func fetchSessionLogSummaries(limit: Int = 1000) throws -> [ConversationRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    id, provider, sessionId, projectName, startTime, endTime,
                    messageCount, userWordCount, assistantWordCount,
                    keyFiles, keyCommands, keyTools,
                    inferredTaskTitle, lastAssistantMessage,
                    '' AS fullText,
                    indexedAt, fileModifiedAt, summary, summaryTitle, summaryUpdatedAt,
                    summaryProvider, summaryModel, sourceType, sourceDeviceId, sourceDeviceName, isRemote
                FROM conversations
                ORDER BY COALESCE(endTime, startTime, indexedAt) DESC
                LIMIT ?
                """,
                arguments: [limit]
            )
            return rows.compactMap { Self.conversation(from: $0) }
        }
    }

    /// Conversations whose full Markdown log has not yet been uploaded to Firestore.
    func fetchUnsyncedSessionLogs(limit: Int = 100) throws -> [ConversationRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM conversations
                WHERE logSyncedAt IS NULL AND isRemote = 0
                ORDER BY COALESCE(endTime, startTime) ASC
                LIMIT ?
                """,
                arguments: [limit]
            )
            return rows.compactMap { Self.conversation(from: $0) }
        }
    }

    func markSessionLogsSynced(ids: [String]) throws {
        guard !ids.isEmpty else { return }
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        try dbQueue.write { db in
            var args = StatementArguments([Date()])
            args += StatementArguments(ids)
            try db.execute(
                sql: "UPDATE conversations SET logSyncedAt = ? WHERE id IN (\(placeholders))",
                arguments: args
            )
        }
    }

    // MARK: - Session Model Lookup

    /// Returns the dominant (highest-cost) model for each conversation sessionId.
    /// Key is `{provider}:{sessionId}` (the conversation ID format).
    func sessionModelMap() throws -> [String: String] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT provider, sessionId, model, SUM(cost) AS totalCost
                FROM token_usage
                GROUP BY provider, sessionId, model
                ORDER BY provider, sessionId, totalCost DESC
                """)
            var result: [String: String] = [:]
            for row in rows {
                guard let provider = row["provider"] as? String,
                      let sessionId = row["sessionId"] as? String,
                      let model = row["model"] as? String else { continue }
                // For Claude Code, collapse subagent IDs: "root/agent-1" → "root"
                let rootSession: String
                if let slashIdx = sessionId.firstIndex(of: "/") {
                    rootSession = String(sessionId[..<slashIdx])
                } else {
                    rootSession = sessionId
                }
                let key = "\(provider):\(rootSession)"
                if result[key] == nil {
                    result[key] = model // First row is highest cost due to ORDER BY
                }
            }
            return result
        }
    }

    // MARK: - Devices

    func fetchDevices() throws -> [DeviceRecord] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM devices ORDER BY isLocal DESC, deviceName ASC")
            return rows.compactMap { row -> DeviceRecord? in
                guard let deviceId = row["deviceId"] as? String,
                      let deviceName = row["deviceName"] as? String else { return nil }
                return DeviceRecord(
                    deviceId: deviceId, deviceName: deviceName,
                    isLocal: ((row["isLocal"] as? Int) ?? 0) != 0,
                    lastSeenAt: Self.parseDateValue(row["lastSeenAt"]),
                    createdAt: Self.parseDateValue(row["createdAt"]) ?? Date(),
                    hardwareModel: row["hardwareModel"] as? String,
                    customIcon: row["customIcon"] as? String
                )
            }
        }
    }

    func upsertDevice(_ device: DeviceRecord) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO devices (deviceId, deviceName, isLocal, lastSeenAt, createdAt, hardwareModel, customIcon)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(deviceId) DO UPDATE SET
                        deviceName = excluded.deviceName,
                        lastSeenAt = excluded.lastSeenAt,
                        hardwareModel = COALESCE(excluded.hardwareModel, devices.hardwareModel),
                        customIcon = COALESCE(excluded.customIcon, devices.customIcon)
                    """,
                arguments: [device.deviceId, device.deviceName, device.isLocal ? 1 : 0, device.lastSeenAt, device.createdAt, device.hardwareModel, device.customIcon]
            )
        }
    }

    func deviceUsageSummaries() throws -> [DeviceUsageSummary] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    COALESCE(tu.sourceDeviceId, d_local.deviceId) AS deviceId,
                    COALESCE(tu.sourceDeviceName, d_local.deviceName, 'This Mac') AS deviceName,
                    CASE WHEN tu.sourceDeviceId IS NULL THEN 1 ELSE 0 END AS isLocal,
                    SUM(tu.cost) AS totalCost,
                    SUM(tu.totalTokens) AS totalTokens,
                    COUNT(DISTINCT tu.sessionId) AS sessionCount,
                    d.hardwareModel AS hardwareModel,
                    d.customIcon AS customIcon
                FROM token_usage tu
                LEFT JOIN devices d_local ON d_local.isLocal = 1
                LEFT JOIN devices d ON d.deviceId = COALESCE(tu.sourceDeviceId, d_local.deviceId)
                GROUP BY COALESCE(tu.sourceDeviceId, 'local')
                ORDER BY isLocal DESC, totalCost DESC
                """)
            return rows.compactMap { row -> DeviceUsageSummary? in
                DeviceUsageSummary(
                    deviceId: row["deviceId"] as? String,
                    deviceName: (row["deviceName"] as? String) ?? "Unknown",
                    isLocal: ((row["isLocal"] as? Int) ?? 0) != 0,
                    totalCost: (row["totalCost"] as? Double) ?? 0,
                    totalTokens: (row["totalTokens"] as? Int) ?? Int(row["totalTokens"] as? Int64 ?? 0),
                    sessionCount: (row["sessionCount"] as? Int) ?? Int(row["sessionCount"] as? Int64 ?? 0),
                    hardwareModel: row["hardwareModel"] as? String,
                    customIcon: row["customIcon"] as? String
                )
            }
        }
    }

    func insertRemoteUsage(_ usage: TokenUsage) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT OR IGNORE INTO token_usage (
                        id, provider, sessionId, projectName, model,
                        inputTokens, outputTokens, cacheCreationTokens, cacheReadTokens,
                        totalTokens, cost, startTime, endTime, createdAt,
                        sourceDeviceId, sourceDeviceName, isRemote, syncedAt
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
                    """,
                arguments: [
                    usage.id.uuidString, usage.provider.rawValue, usage.sessionId,
                    usage.projectName, usage.model,
                    usage.inputTokens, usage.outputTokens, usage.cacheCreationTokens,
                    usage.cacheReadTokens, usage.totalTokens, usage.cost,
                    usage.startTime, usage.endTime, usage.createdAt,
                    usage.sourceDeviceId, usage.sourceDeviceName, Date()
                ]
            )
        }
    }

    func insertRemoteConversation(_ record: ConversationRecord) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT OR IGNORE INTO conversations (
                        id, provider, sessionId, projectName, startTime, endTime,
                        messageCount, userWordCount, assistantWordCount,
                        keyFiles, keyCommands, keyTools,
                        inferredTaskTitle, lastAssistantMessage, fullText,
                        indexedAt, fileModifiedAt, sourceType,
                        sourceDeviceId, sourceDeviceName, isRemote, conversationSyncedAt
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
                    """,
                arguments: [
                    record.id, record.provider.rawValue, record.sessionId,
                    record.projectName, record.startTime, record.endTime,
                    record.messageCount, record.userWordCount, record.assistantWordCount,
                    Self.encodeJSONStringArray(record.keyFiles),
                    Self.encodeJSONStringArray(record.keyCommands),
                    Self.encodeJSONStringArray(record.keyTools),
                    record.inferredTaskTitle, record.lastAssistantMessage, record.fullText,
                    record.indexedAt, record.fileModifiedAt, record.sourceType.rawValue,
                    record.sourceDeviceId, record.sourceDeviceName, Date()
                ]
            )
        }
    }

    /// Update fullText for a remote conversation (lazy body download).
    func updateDeviceIcon(deviceId: String, customIcon: String?) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE devices SET customIcon = ? WHERE deviceId = ?",
                arguments: [customIcon, deviceId]
            )
        }
    }

    func updateConversationFullText(id: String, fullText: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE conversations SET fullText = ? WHERE id = ?",
                arguments: [fullText, id]
            )
        }
    }

    private static func encodeJSONStringArray(_ array: [String]) -> String {
        (try? JSONEncoder().encode(array)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    /// Synthesizes a single `cliAssistant` ConversationRecord from persisted chat messages
    /// and upserts it so the Session Logs center and cloud sync treat it like any other session.
    func upsertCLIConversation(from messages: [ChatMessageRecord]) throws {
        guard messages.isEmpty == false else { return }

        let start = messages.first?.timestamp
        let end   = messages.last?.timestamp

        let assistantWords = messages
            .filter { $0.role == .assistant }
            .reduce(0) { $0 + $1.content.split(separator: " ").count }
        let userWords = messages
            .filter { $0.role == .user }
            .reduce(0) { $0 + $1.content.split(separator: " ").count }

        let markdown = SessionLogMarkdownFormatter.cliMarkdown(from: messages)
        let lastAssistant = messages.last(where: { $0.role == .assistant })?.content ?? ""

        let record = ConversationRecord(
            id: ConversationRecord.cliAssistantId,
            provider: .claudeCode,
            sessionId: "cli-assistant-local",
            projectName: "BurnBar",
            startTime: start,
            endTime: end,
            messageCount: messages.count,
            userWordCount: userWords,
            assistantWordCount: assistantWords,
            keyFiles: [],
            keyCommands: [],
            keyTools: [],
            inferredTaskTitle: "BurnBar Assistant",
            lastAssistantMessage: String(lastAssistant.prefix(500)),
            fullText: markdown,
            indexedAt: Date(),
            fileModifiedAt: nil,
            summary: nil,
            sourceType: .cliAssistant
        )
        try upsertConversation(record)

        try enqueueConversationProjectionJob(conversationID: record.id, jobType: .reproject)
    }

    // MARK: - Sync Helpers (private)

    /// Returns true when every synced field is unchanged so the existing sync timestamps can be preserved.
    /// Checking `fullText` ensures transcript changes also reset the full-log dirty flag (`logSyncedAt`).
    private static func shouldPreserveConversationSyncedAt(
        existing: ConversationRecord,
        incoming: ConversationRecord,
        resolvedSummary: String?,
        resolvedSummaryTitle: String?,
        resolvedSummaryUpdatedAt: Date?,
        resolvedSummaryProvider: String?,
        resolvedSummaryModel: String?
    ) -> Bool {
        let coreUnchanged =
            existing.provider == incoming.provider
            && existing.sessionId == incoming.sessionId
            && existing.projectName == incoming.projectName
            && existing.startTime == incoming.startTime
            && existing.endTime == incoming.endTime
            && existing.messageCount == incoming.messageCount
            && existing.userWordCount == incoming.userWordCount
            && existing.assistantWordCount == incoming.assistantWordCount
            && existing.keyFiles == incoming.keyFiles
            && existing.keyCommands == incoming.keyCommands
            && existing.keyTools == incoming.keyTools
            && existing.inferredTaskTitle == incoming.inferredTaskTitle
            && existing.lastAssistantMessage == incoming.lastAssistantMessage
            && existing.fullText == incoming.fullText

        let summaryUnchanged =
            existing.summary == resolvedSummary
            && existing.summaryTitle == resolvedSummaryTitle
            && existing.summaryUpdatedAt == resolvedSummaryUpdatedAt
            && existing.summaryProvider == resolvedSummaryProvider
            && existing.summaryModel == resolvedSummaryModel

        return coreUnchanged && summaryUnchanged
    }

}

