import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Source Filter

private enum SessionLogSourceFilter: String, CaseIterable, Identifiable {
    case all      = "All"
    case provider = "Provider"
    case assistant = "Assistant"
    var id: String { rawValue }
}

// MARK: - Group Mode

private enum SessionLogGroupMode: String, CaseIterable, Identifiable {
    case time = "Time"
    case provider = "Provider"
    case project = "Project"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .time: return "clock"
        case .provider: return "cpu"
        case .project: return "folder"
        }
    }
}

// MARK: - Data Source

private enum SessionLogDataSource: String, CaseIterable, Identifiable {
    case local  = "Local"
    case cloud  = "Cloud"
    case iCloud = "iCloud"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .local:  return "internaldrive"
        case .cloud:  return "cloud"
        case .iCloud: return "icloud"
        }
    }
}

// MARK: - Session Log Group

private struct SessionLogGroup: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let accentColor: Color
    let logs: [ConversationRecord]
}

// MARK: - Session Logs View

struct SessionLogsView: View {
    var dataStore: DataStore
    var accountManager: AccountManager
    var settingsManager: SettingsManager
    var operatingLayer: BurnBarOperatingLayer?
    var cloudSyncService: CloudSyncService?
    var iCloudMirrorService: ICloudSessionMirrorService?
    var jumpTarget: ConversationJumpTarget?
    /// Fallback when usage-derived `sessionModelMap` has no model (e.g. in-app Hermes chat).
    var preferredChatModelKey: String? = nil

    @State private var allLogs: [ConversationRecord] = []
    @State private var searchText = ""
    @State private var sourceFilter: SessionLogSourceFilter = .all
    @State private var groupMode: SessionLogGroupMode = .time
    @State private var expandedSections: Set<String> = []
    @State private var sectionDisplayLimits: [String: Int] = [:]
    @State private var selectedId: String?
    @State private var isLoading = false
    @State private var appeared = false
    @State private var dataSource: SessionLogDataSource = .local
    @State private var cloudBodyCache: [String: String] = [:]
    @State private var dataSourceError: String?
    @State private var retrievalSearchService: SearchService?
    @State private var retrievalHealthService: RetrievalHealthService?
    @State private var retrievalMatchedIDs: [String] = []
    @State private var isRetrievalSearching = false
    @State private var retrievalHealthSnapshot: RetrievalSystemHealthSnapshot = .empty
    @State private var deviceFilter: String?
    @State private var knownDevices: [DeviceRecord] = []
    @State private var sessionModelMap: [String: String] = [:]
    @State private var iconPickerDeviceId: String?
    @State private var selectedDetailLog: ConversationRecord?

    private let defaultDisplayLimit = 15
    private var hasMultipleDevices: Bool { knownDevices.count > 1 }
    private var hasAnyDevices: Bool { !knownDevices.isEmpty }

    // MARK: - Filtering

    private var sourceFilteredLogs: [ConversationRecord] {
        var result: [ConversationRecord]
        switch sourceFilter {
        case .all:
            result = allLogs
        case .provider:
            result = allLogs.filter { $0.sourceType == .providerLog }
        case .assistant:
            result = allLogs.filter { $0.sourceType == .cliAssistant }
        }
        if let deviceFilter {
            result = result.filter { record in
                if record.isRemote { return record.sourceDeviceId == deviceFilter }
                return knownDevices.first(where: { $0.isLocal })?.deviceId == deviceFilter
            }
        }
        return result
    }

    private var filteredLogs: [ConversationRecord] {
        let result = sourceFilteredLogs
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return result }

        if dataSource == .local {
            let byID = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
            return retrievalMatchedIDs.compactMap { byID[$0] }
        }

        return substringFilteredLogs(from: result, query: trimmedQuery)
    }

    private var visibleDegradedModes: [RetrievalDegradedState] {
        retrievalHealthSnapshot.degradedModes.filter { state in
            if dataSource == .local {
                return state.mode != .cloudSharedUnavailable
            }
            return true
        }
    }

    private var selectedLog: ConversationRecord? {
        guard let id = selectedId else { return nil }
        if let selectedDetailLog, selectedDetailLog.id == id {
            return selectedDetailLog
        }
        return allLogs.first { $0.id == id }
    }

    // MARK: - Grouping

    private var logGroups: [SessionLogGroup] {
        let logs = filteredLogs
        switch groupMode {
        case .time: return timeGroups(from: logs)
        case .provider: return providerGroups(from: logs)
        case .project: return projectGroups(from: logs)
        }
    }

    private func timeGroups(from logs: [ConversationRecord]) -> [SessionLogGroup] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        var buckets: [String: [ConversationRecord]] = [
            "today": [], "yesterday": [], "week": [], "month": [], "older": []
        ]
        for log in logs {
            // Bucket by when the session actually occurred — start first, then end.
            // Avoid preferring endTime alone (some pipelines align it with re-import);
            // fileModifiedAt beats indexedAt for "last known log activity" when times are missing.
            let date = log.startTime ?? log.endTime ?? log.fileModifiedAt ?? log.indexedAt
            if date >= startOfToday {
                buckets["today"]!.append(log)
            } else if date >= startOfYesterday {
                buckets["yesterday"]!.append(log)
            } else if date >= startOfWeek {
                buckets["week"]!.append(log)
            } else if date >= startOfMonth {
                buckets["month"]!.append(log)
            } else {
                buckets["older"]!.append(log)
            }
        }

        let defs: [(id: String, title: String, icon: String, color: Color)] = [
            ("today", "Today", "sun.max.fill", DesignSystem.Colors.ember),
            ("yesterday", "Yesterday", "moon.fill", DesignSystem.Colors.amber),
            ("week", "This Week", "calendar", DesignSystem.Colors.blaze),
            ("month", "This Month", "calendar.badge.clock", DesignSystem.Colors.whimsy),
            ("older", "Older", "archivebox.fill", DesignSystem.Colors.textMuted),
        ]
        return defs.compactMap { d in
            guard let logs = buckets[d.id], !logs.isEmpty else { return nil }
            return SessionLogGroup(id: d.id, title: d.title, systemImage: d.icon, accentColor: d.color, logs: logs)
        }
    }

    private func providerGroups(from logs: [ConversationRecord]) -> [SessionLogGroup] {
        Dictionary(grouping: logs) { $0.provider }
            .map { provider, logs in
                SessionLogGroup(
                    id: "provider-\(provider.rawValue)",
                    title: provider.displayName,
                    systemImage: provider.iconName,
                    accentColor: DesignSystem.Colors.primary(for: provider),
                    logs: logs
                )
            }
            .sorted { $0.logs.count > $1.logs.count }
    }

    private func projectGroups(from logs: [ConversationRecord]) -> [SessionLogGroup] {
        Dictionary(grouping: logs) { $0.projectName }
            .map { project, logs in
                SessionLogGroup(
                    id: "project-\(project)",
                    title: project.isEmpty ? "Unknown" : project,
                    systemImage: "folder.fill",
                    accentColor: DesignSystem.Colors.amber,
                    logs: logs
                )
            }
            .sorted { $0.logs.count > $1.logs.count }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            commandCenter
                .frame(width: 340)

            Divider().background(DesignSystem.Colors.border)

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .task {
            // Eager load devices so filter bar appears immediately
            knownDevices = (try? dataStore.fetchDevices()) ?? []
            await loadLogs()
            applyJumpTargetIfNeeded(jumpTarget)
        }
        .onChange(of: searchText) { _, _ in
            Task { await runLocalRetrievalSearchIfNeeded() }
        }
        .onChange(of: sourceFilter) { _, _ in
            Task {
                await runLocalRetrievalSearchIfNeeded()
                reconcileSelectionWithFilteredLogs()
            }
        }
        .onChange(of: groupMode) { _, _ in
            sectionDisplayLimits = [:]
            let groups = logGroups
            expandedSections = Set(groups.prefix(1).map(\.id))
        }
        .onChange(of: dataSource) { _, _ in
            selectedId = nil
            cloudBodyCache = [:]
            Task { await loadLogs() }
        }
        .onChange(of: settingsManager.conversationIndexingEnabled) { _, _ in
            refreshRetrievalHealth()
            Task { await runLocalRetrievalSearchIfNeeded() }
        }
        .onChange(of: settingsManager.preferredIndexEmbeddingVersionID) { _, _ in
            retrievalSearchService = SearchService.makeConversationSearchService(
                dataStore: dataStore,
                settingsManager: settingsManager
            )
            refreshRetrievalHealth()
            Task { await runLocalRetrievalSearchIfNeeded() }
        }
        .onChange(of: accountManager.isSignedIn) { _, _ in
            refreshRetrievalHealth()
        }
        .onChange(of: selectedId) { _, newId in
            if dataSource == .local {
                Task { await loadSelectedLogDetailIfNeeded(for: newId) }
                return
            }

            guard dataSource == .cloud,
                  let id = newId,
                  let record = allLogs.first(where: { $0.id == id }),
                  cloudBodyCache[record.sessionId] == nil else { return }
            Task {
                if let body = try? await cloudSyncService?.fetchCloudSessionLogBody(docId: record.sessionId) {
                    cloudBodyCache[record.sessionId] = body
                }
            }
        }
        .onChange(of: jumpTarget?.id) { _, _ in
            applyJumpTargetIfNeeded(jumpTarget)
        }
    }

    // MARK: - Command Center

    private var commandCenter: some View {
        VStack(spacing: 0) {
            statsHeader
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.md)

            searchBar
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.sm)

            filterBar
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, hasMultipleDevices ? DesignSystem.Spacing.xs : DesignSystem.Spacing.md)

            if hasAnyDevices {
                deviceFilterBar
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.md)
            }

            if dataSource == .local, !visibleDegradedModes.isEmpty {
                retrievalDegradedModeBanner
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.md)
            }

            Divider().background(DesignSystem.Colors.border.opacity(0.6))

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredLogs.isEmpty {
                emptyListState
            } else {
                groupedList
            }
        }
        .background {
            ZStack {
                DesignSystem.Colors.surface.opacity(0.92)
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.textPrimary.opacity(0.015),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "scroll")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.ember)
                Text("Session Logs")
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .textCase(.uppercase)
            }

            Text("\(filteredLogs.count) log\(filteredLogs.count == 1 ? "" : "s")")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            HStack(spacing: DesignSystem.Spacing.lg) {
                let providerCount = Set(filteredLogs.map(\.provider)).count
                let projectCount = Set(filteredLogs.map(\.projectName)).count
                statPill(value: "\(providerCount)", label: "providers")
                statPill(value: "\(projectCount)", label: "projects")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statPill(value: String, label: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            Text(value)
                .font(DesignSystem.Typography.monoSmall)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text(label)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textMuted)

            TextField("Search by title, project, provider, or keyword…", text: $searchText)
                .font(DesignSystem.Typography.caption)
                .textFieldStyle(.plain)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
                .buttonStyle(.plain)
            }

            if dataSource == .local, isRetrievalSearching {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.full, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.full, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.border.opacity(0.5), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(SessionLogSourceFilter.allCases) { filter in
                Button {
                    withAnimation(DesignSystem.Animation.snappy) {
                        sourceFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(
                            sourceFilter == filter
                                ? DesignSystem.Colors.textPrimary
                                : DesignSystem.Colors.textMuted
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.full, style: .continuous)
                                .fill(
                                    sourceFilter == filter
                                        ? AnyShapeStyle(filterAccent(for: filter).opacity(0.18))
                                        : AnyShapeStyle(DesignSystem.Colors.surfaceElevated.opacity(0.4))
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.full, style: .continuous)
                                .strokeBorder(
                                    sourceFilter == filter
                                        ? filterAccent(for: filter).opacity(0.45)
                                        : DesignSystem.Colors.border.opacity(0.3),
                                    lineWidth: 0.5
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            HStack(spacing: 2) {
                ForEach(SessionLogGroupMode.allCases) { mode in
                    Button {
                        withAnimation(DesignSystem.Animation.snappy) {
                            groupMode = mode
                        }
                    } label: {
                        Image(systemName: mode.icon)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(groupMode == mode ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textMuted)
                            .frame(width: 24, height: 20)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(groupMode == mode ? DesignSystem.Colors.surfaceElevated : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Group by \(mode.rawValue.lowercased())")
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                    .fill(DesignSystem.Colors.surfaceElevated.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.border.opacity(0.3), lineWidth: 0.5)
            )

            if hasMultipleDevices {
                Menu {
                    Button { withAnimation(DesignSystem.Animation.snappy) { deviceFilter = nil } } label: {
                        Label("All Devices", systemImage: "desktopcomputer")
                    }
                    Divider()
                    ForEach(knownDevices) { device in
                        Button { withAnimation(DesignSystem.Animation.snappy) { deviceFilter = device.deviceId } } label: {
                            Label(device.deviceName, systemImage: device.sfSymbolName)
                        }
                    }
                } label: {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(deviceFilter == nil ? DesignSystem.Colors.textMuted : DesignSystem.Colors.teal)
                        .frame(width: 24, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(deviceFilter == nil ? Color.clear : DesignSystem.Colors.teal.opacity(0.12))
                        )
                }
                .menuStyle(.borderlessButton)
                .help(deviceFilter.flatMap { id in knownDevices.first { $0.deviceId == id }?.deviceName } ?? "All Devices")
            }

            Menu {
                ForEach(SessionLogDataSource.allCases) { source in
                    Button {
                        withAnimation(DesignSystem.Animation.snappy) { dataSource = source }
                    } label: {
                        Label(source.rawValue, systemImage: source.icon)
                    }
                }
            } label: {
                Image(systemName: dataSource.icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(dataSource == .local ? DesignSystem.Colors.textMuted : DesignSystem.Colors.ember)
                    .frame(width: 24, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(dataSource == .local ? Color.clear : DesignSystem.Colors.ember.opacity(0.12))
                    )
            }
            .menuStyle(.borderlessButton)
            .help("Data source: \(dataSource.rawValue)")
        }
    }

    private func filterAccent(for filter: SessionLogSourceFilter) -> Color {
        switch filter {
        case .all:       return DesignSystem.Colors.ember
        case .provider:  return DesignSystem.Colors.amber
        case .assistant: return DesignSystem.Colors.whimsy
        }
    }

    private var deviceFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                deviceFilterPill(label: "All", icon: "rectangle.stack", id: nil)

                ForEach(knownDevices) { device in
                    deviceFilterPill(label: device.deviceName, icon: device.sfSymbolName, id: device.deviceId)
                }
            }
        }
    }

    private func deviceFilterPill(label: String, icon: String, id: String?) -> some View {
        let isActive = deviceFilter == id
        return Button {
            withAnimation(DesignSystem.Animation.snappy) {
                deviceFilter = id
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                Text(label)
                    .lineLimit(1)
            }
            .font(DesignSystem.Typography.tiny)
            .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textMuted)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs + 1)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.full, style: .continuous)
                    .fill(isActive ? DesignSystem.Colors.teal.opacity(0.18) : DesignSystem.Colors.surfaceElevated.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.full, style: .continuous)
                    .strokeBorder(
                        isActive ? DesignSystem.Colors.teal.opacity(0.45) : DesignSystem.Colors.border.opacity(0.3),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                if let id { iconPickerDeviceId = id }
            }
        )
        .popover(isPresented: Binding(
            get: { iconPickerDeviceId == id && id != nil },
            set: { if !$0 { iconPickerDeviceId = nil } }
        )) {
            if let id {
                DeviceIconPicker(
                    deviceId: id,
                    currentIcon: icon,
                    dataStore: dataStore
                ) {
                    iconPickerDeviceId = nil
                    knownDevices = (try? dataStore.fetchDevices()) ?? []
                }
            }
        }
    }

    private var retrievalDegradedModeBanner: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            ForEach(visibleDegradedModes) { state in
                HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignSystem.Colors.warning)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.title)
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text(state.message)
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.warning.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous))
            }
        }
    }

    // MARK: - Grouped List

    private var groupedList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(logGroups) { group in
                    Section {
                        if expandedSections.contains(group.id) {
                            sectionContent(for: group)
                        }
                    } header: {
                        sectionHeader(for: group)
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .scrollContentBackground(.hidden)
    }

    private func sectionHeader(for group: SessionLogGroup) -> some View {
        let isExpanded = expandedSections.contains(group.id)
        return Button {
            withAnimation(DesignSystem.Animation.snappy) {
                if isExpanded {
                    expandedSections.remove(group.id)
                } else {
                    expandedSections.insert(group.id)
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(group.accentColor)
                    .frame(width: 12, alignment: .center)

                Image(systemName: group.systemImage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(group.accentColor)

                Text(group.title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text("\(group.logs.count)")
                    .font(DesignSystem.Typography.monoSmall)
                    .foregroundStyle(group.accentColor)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(group.accentColor.opacity(0.12))
                    )
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.surface.opacity(0.95))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectionContent(for group: SessionLogGroup) -> some View {
        let limit = sectionDisplayLimits[group.id] ?? defaultDisplayLimit
        let showing = Array(group.logs.prefix(limit))

        VStack(spacing: DesignSystem.Spacing.xxs) {
            ForEach(showing) { record in
                CompactSessionRow(
                    record: record,
                    isSelected: selectedId == record.id,
                    showDeviceIndicator: hasMultipleDevices,
                    modelName: sessionModelMap[record.id],
                    deviceIcon: record.sourceDeviceId.flatMap { did in
                        knownDevices.first { $0.deviceId == did }?.sfSymbolName
                    }
                ) {
                    withAnimation(DesignSystem.Animation.snappy) {
                        selectedId = record.id
                    }
                }
            }

            if group.logs.count > limit {
                let remaining = group.logs.count - limit
                Button {
                    withAnimation(DesignSystem.Animation.gentle) {
                        sectionDisplayLimits[group.id] = limit + min(30, remaining)
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 9))
                        Text("Show \(min(30, remaining)) more of \(remaining) remaining")
                            .font(DesignSystem.Typography.tiny)
                    }
                    .foregroundStyle(group.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.sm)
        .transition(.opacity)
    }

    // MARK: - Empty State

    private var emptyListState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Spacer()
            Image(systemName: dataSource.icon)
                .font(.system(size: 36))
                .foregroundStyle(DesignSystem.Colors.textMuted.opacity(0.5))

            if let error = dataSourceError {
                Text("Could not load \(dataSource.rawValue) logs")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(error)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            } else if dataSource == .cloud {
                if !accountManager.isSignedIn {
                    Text("Sign in to load cloud logs")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("Cloud logs require a BurnBar account. Sign in via Settings.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                } else {
                    Text(searchText.isEmpty ? "No cloud logs yet" : "No results")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(searchText.isEmpty
                            ? "Enable session log cloud backup in Settings to store logs here."
                            : "Try a different search term."
                    )
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            } else if dataSource == .iCloud {
                if !(iCloudMirrorService?.hasUbiquityIdentity ?? false) {
                    Text("Sign in to iCloud")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("Sign in to iCloud in System Settings to access your mirrored sessions.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                } else {
                    Text(searchText.isEmpty ? "No mirrored files found" : "No results")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(searchText.isEmpty
                            ? "Enable iCloud session mirror in Settings and run a sync first."
                            : "Try a different search term."
                    )
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            } else if !settingsManager.conversationIndexingEnabled && sourceFilter != .assistant {
                Text("Enable conversation indexing")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Turn on indexing in Settings to track your provider sessions here.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            } else {
                Text(searchText.isEmpty ? "No logs yet" : "No results")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(searchText.isEmpty
                        ? "Start a chat with the BurnBar Assistant, or scan your provider sessions."
                        : "Try a different search term."
                )
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if let log = selectedLog {
            SessionLogDetailPane(
                record: log,
                dataStore: dataStore,
                operatingLayer: operatingLayer,
                overrideBody: dataSource == .cloud ? cloudBodyCache[log.sessionId] : nil,
                jumpTarget: jumpTarget?.conversation.id == log.id ? jumpTarget : nil,
                dominantModelKey: sessionModelMap[log.id],
                preferredChatModelKey: preferredChatModelKey
            )
            .id(log.id)
        } else {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Spacer()
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(DesignSystem.Colors.textMuted.opacity(0.4))
                Text("Select a session log")
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Pick any log from the list to preview its full Markdown.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Data Loading

    private func substringFilteredLogs(from logs: [ConversationRecord], query: String) -> [ConversationRecord] {
        let q = query.lowercased()
        return logs.filter {
            $0.inferredTaskTitle.lowercased().contains(q)
                || ($0.summaryTitle?.lowercased().contains(q) ?? false)
                || $0.projectName.lowercased().contains(q)
                || $0.provider.displayName.lowercased().contains(q)
                || ($0.summary?.lowercased().contains(q) ?? false)
                || $0.fullText.lowercased().contains(q)
        }
    }

    private func selectedConversationSources() -> Set<ConversationSourceType>? {
        switch sourceFilter {
        case .all:
            return nil
        case .provider:
            return [.providerLog]
        case .assistant:
            return [.cliAssistant]
        }
    }

    private func ensureRetrievalServices() {
        if retrievalSearchService == nil {
            retrievalSearchService = SearchService.makeConversationSearchService(
                dataStore: dataStore,
                settingsManager: settingsManager
            )
        }
        if retrievalHealthService == nil {
            retrievalHealthService = RetrievalHealthService(dataStore: dataStore)
        }
    }

    private func refreshRetrievalHealth() {
        ensureRetrievalServices()
        guard let retrievalHealthService else {
            retrievalHealthSnapshot = .empty
            return
        }

        let sharedFeaturesAvailable: Bool
        switch dataSource {
        case .cloud:
            sharedFeaturesAvailable = accountManager.isSignedIn
        case .local, .iCloud:
            sharedFeaturesAvailable = true
        }

        retrievalHealthSnapshot = retrievalHealthService.snapshot(
            indexingEnabled: settingsManager.conversationIndexingEnabled,
            sharedFeaturesAvailable: sharedFeaturesAvailable
        )
    }

    private func runLocalRetrievalSearchIfNeeded() async {
        refreshRetrievalHealth()
        guard dataSource == .local else {
            retrievalMatchedIDs = []
            isRetrievalSearching = false
            return
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            retrievalMatchedIDs = []
            isRetrievalSearching = false
            return
        }

        ensureRetrievalServices()
        guard let retrievalSearchService else {
            retrievalMatchedIDs = []
            isRetrievalSearching = false
            return
        }

        let activeSources = selectedConversationSources()
        let expectedFilter = sourceFilter
        isRetrievalSearching = true
        let results = await retrievalSearchService.search(
            query: trimmedQuery,
            conversationSources: activeSources
        )

        guard dataSource == .local,
              searchText.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
              sourceFilter == expectedFilter else {
            isRetrievalSearching = false
            return
        }

        retrievalMatchedIDs = results.map(\.conversation.id)
        isRetrievalSearching = false
        refreshRetrievalHealth()
    }

    private func reconcileSelectionWithFilteredLogs() {
        guard let selectedId else {
            self.selectedId = filteredLogs.first?.id
            return
        }
        if filteredLogs.contains(where: { $0.id == selectedId }) == false {
            self.selectedId = filteredLogs.first?.id
        }
    }

    private func applyJumpTargetIfNeeded(_ target: ConversationJumpTarget?) {
        guard let target else { return }
        dataSource = .local
        sourceFilter = .all
        searchText = ""
        retrievalMatchedIDs = []
        selectedId = target.conversation.id
    }

    private func loadSelectedLogDetailIfNeeded(for id: String?) async {
        guard dataSource == .local, let id else {
            selectedDetailLog = nil
            return
        }

        if let selectedDetailLog, selectedDetailLog.id == id, !selectedDetailLog.fullText.isEmpty {
            return
        }

        do {
            selectedDetailLog = try dataStore.fetchConversation(id: id)
        } catch {
            selectedDetailLog = allLogs.first { $0.id == id }
        }
    }

    private func loadLogs() async {
        isLoading = true
        dataSourceError = nil
        refreshRetrievalHealth()
        knownDevices = (try? dataStore.fetchDevices()) ?? []
        sessionModelMap = (try? dataStore.sessionModelMap()) ?? [:]
        selectedDetailLog = nil
        do {
            switch dataSource {
            case .local:
                let messages = try dataStore.fetchChatMessages()
                if !messages.isEmpty { try dataStore.upsertCLIConversation(from: messages) }
                allLogs = try dataStore.fetchSessionLogSummaries()

            case .cloud:
                if let svc = cloudSyncService {
                    allLogs = try await svc.fetchCloudSessionLogs()
                } else {
                    allLogs = []
                }

            case .iCloud:
                if let svc = iCloudMirrorService {
                    allLogs = await svc.fetchConversations()
                } else {
                    allLogs = []
                }
            }
        } catch {
            dataSourceError = error.localizedDescription
            allLogs = []
        }

        await runLocalRetrievalSearchIfNeeded()
        reconcileSelectionWithFilteredLogs()
        if expandedSections.isEmpty, let firstId = logGroups.first?.id {
            expandedSections = [firstId]
        }
        await loadSelectedLogDetailIfNeeded(for: selectedId)
        isLoading = false
    }
}

// MARK: - Compact Session Row

private struct CompactSessionRow: View {
    let record: ConversationRecord
    let isSelected: Bool
    var showDeviceIndicator: Bool = false
    var modelName: String?
    var deviceIcon: String?
    let action: () -> Void

    private var accentColor: Color {
        record.sourceType == .cliAssistant
            ? DesignSystem.Colors.whimsy
            : DesignSystem.Colors.primary(for: record.provider)
    }

    /// Short display model name, e.g. "claude-opus-4" → "Opus 4"
    private var shortModelLabel: String? {
        guard let model = modelName, !model.isEmpty else { return nil }
        return model
    }

    private var timeLabel: String {
        guard let date = record.endTime ?? record.startTime else {
            return record.indexedAt.relativeLabel
        }
        return date.relativeLabel
    }

    private var displayTitle: String {
        if let summaryTitle = record.summaryTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !summaryTitle.isEmpty {
            return summaryTitle
        }
        return record.inferredTaskTitle.isEmpty ? "Session" : record.inferredTaskTitle
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? accentColor.opacity(0.18) : DesignSystem.Colors.surfaceElevated.opacity(0.6))
                            .frame(width: 28, height: 28)

                        if record.sourceType == .cliAssistant {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(isSelected ? accentColor : DesignSystem.Colors.textSecondary)
                        } else {
                            ProviderLogoView(provider: record.provider, size: 16, useFallbackColor: false)
                        }
                    }

                    // Model vendor badge — small overlay in bottom-right
                    if let model = modelName, !model.isEmpty {
                        ModelProviderLogoView(modelKey: model, size: 13)
                            .background(
                                Circle()
                                    .fill(DesignSystem.Colors.surface)
                                    .frame(width: 15, height: 15)
                            )
                            .offset(x: 3, y: 3)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DesignSystem.Spacing.xxs) {
                        Text(displayTitle)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                            .lineLimit(1)

                        if let label = shortModelLabel {
                            Text(label)
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(LLMModelBrand.infer(fromModelKey: label).emblemColor.opacity(0.7))
                                .lineLimit(1)
                                .layoutPriority(-1)
                        }
                    }

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        if showDeviceIndicator, record.isRemote, let deviceName = record.sourceDeviceName {
                            Image(systemName: deviceIcon ?? "desktopcomputer")
                                .font(.system(size: 8))
                            Text(deviceName)
                                .lineLimit(1)
                            Text("·")
                        }
                        Text(record.projectName)
                            .lineLimit(1)
                        Text("·")
                        Text("\(record.messageCount) msgs")
                    }
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                }

                Spacer(minLength: 0)

                Text(timeLabel)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .fill(isSelected ? accentColor.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Device Icon Picker

private struct DeviceIconPicker: View {
    let deviceId: String
    let currentIcon: String
    var dataStore: DataStore
    var onDismiss: () -> Void

    private let columns = Array(repeating: GridItem(.fixed(36), spacing: DesignSystem.Spacing.sm), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Device Icon")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .textCase(.uppercase)
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.sm) {
                ForEach(DeviceHardwareIcon.allIcons, id: \.symbol) { item in
                    let isSelected = currentIcon == item.symbol
                    Button {
                        try? dataStore.updateDeviceIcon(deviceId: deviceId, customIcon: item.symbol)
                        onDismiss()
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(isSelected ? DesignSystem.Colors.teal : DesignSystem.Colors.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                        .fill(isSelected ? DesignSystem.Colors.teal.opacity(0.15) : DesignSystem.Colors.surfaceElevated)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                        .strokeBorder(
                                            isSelected ? DesignSystem.Colors.teal.opacity(0.5) : DesignSystem.Colors.border.opacity(0.3),
                                            lineWidth: isSelected ? 1.5 : 0.5
                                        )
                                )
                            Text(item.label)
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                try? dataStore.updateDeviceIcon(deviceId: deviceId, customIcon: nil)
                onDismiss()
            } label: {
                Text("Reset to Auto")
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(width: 220)
        .background(DesignSystem.Colors.surface)
    }
}

// MARK: - Transcript Role Filter

private enum TranscriptRoleFilter: String, CaseIterable {
    case all = "All"
    case user = "You"
    case assistant = "Assistant"

    var matchesBlock: (TranscriptBlock) -> Bool {
        switch self {
        case .all: return { _ in true }
        case .user: return { $0.kind == .userMessage }
        case .assistant: return { $0.kind == .assistantMessage || $0.kind == .toolUse || $0.kind == .codeBlock }
        }
    }

    var icon: String {
        switch self {
        case .all: return "text.bubble"
        case .user: return "person.fill"
        case .assistant: return "sparkles"
        }
    }
}

/// A chunk of consecutive blocks belonging to the same role, used for collapsed filter mode.
private struct TranscriptChunk: Identifiable {
    let id: Int
    let primaryKind: TranscriptBlock.Kind
    let blocks: [TranscriptBlock]
    /// Index range in the full block array for context expansion
    let sourceRange: Range<Int>

    var preview: String {
        let firstContent = blocks.first(where: { $0.kind == .userMessage || $0.kind == .assistantMessage })?.content ?? blocks.first?.content ?? ""
        let maxLen = 120
        if firstContent.count <= maxLen { return firstContent }
        return String(firstContent.prefix(maxLen)) + "..."
    }

    var blockCount: Int {
        blocks.filter { $0.kind == .userMessage || $0.kind == .assistantMessage }.count
    }
}

// MARK: - Session Log Detail Pane

struct SessionLogDetailPane: View {
    let record: ConversationRecord
    var dataStore: DataStore
    var operatingLayer: BurnBarOperatingLayer?
    var overrideBody: String?
    var jumpTarget: ConversationJumpTarget?
    /// Dominant model from `token_usage` (`sessionModelMap`); best for provider sessions.
    var dominantModelKey: String? = nil
    /// When usage has no model row (e.g. CLI assistant + Hermes), use the live chat model id.
    var preferredChatModelKey: String? = nil

    @State private var markdownBody = ""
    @State private var copyConfirmed = false
    @State private var transcriptFilter: TranscriptRoleFilter = .all
    @State private var expandedChunkIndex: Int?
    @State private var answerDrafts: [String: String] = [:]

    private var accentColor: Color {
        record.sourceType == .cliAssistant
            ? DesignSystem.Colors.whimsy
            : DesignSystem.Colors.amber
    }

    /// Model id for assistant-turn branding (vendor logo in transcript).
    private var assistantModelKeyForBadge: String? {
        if let m = dominantModelKey?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty { return m }
        if let m = record.summaryModel?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty { return m }
        if record.sourceType == .cliAssistant,
           let m = preferredChatModelKey?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty {
            return m
        }
        return nil
    }

    @ViewBuilder
    private func assistantAvatarBadge(size: CGFloat = 20) -> some View {
        let logoSize = max(12, size * 0.7)
        if let key = assistantModelKeyForBadge {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                ModelProviderLogoView(modelKey: key, size: logoSize, fallbackSymbolColor: accentColor)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: size, height: size)
                .background(accentColor.opacity(0.12))
                .clipShape(Circle())
        }
    }

    private var displayTitle: String {
        if let summaryTitle = record.summaryTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !summaryTitle.isEmpty {
            return summaryTitle
        }
        return record.inferredTaskTitle.isEmpty ? "Session" : record.inferredTaskTitle
    }

    private var relatedPendingQuestions: [BurnBarControllerQuestion] {
        guard let operatingLayer else { return [] }
        let runtime = operatingLayer.snapshot.controllerRuntime
        return runtime.pendingQuestions.filter { question in
            if let sessionID = question.sessionID, sessionID == record.sessionId { return true }
            return question.projectName == record.projectName
        }
    }

    private var relatedMission: BurnBarControllerMissionRecord? {
        guard let operatingLayer else { return nil }
        let runtime = operatingLayer.snapshot.controllerRuntime
        return runtime.missions.first(where: { $0.projectName == record.projectName }) ?? runtime.missions.first
    }

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            if relatedPendingQuestions.isEmpty == false {
                controllerQuestionPanel
            }
            if let relatedMission {
                controllerMissionPanel(relatedMission)
            }
            if let jumpTarget {
                jumpTargetCard(jumpTarget)
            }
            Divider().background(DesignSystem.Colors.border.opacity(0.5))

            structuredTranscriptView(blocks: TranscriptBlockParser.parse(record.fullText))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider().background(DesignSystem.Colors.border.opacity(0.5))

            actionBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .task { buildMarkdown() }
        .onChange(of: record.id) { _, _ in
            transcriptFilter = .all
            expandedChunkIndex = nil
        }
        .onChange(of: overrideBody) { _, newBody in
            if let newBody, !newBody.isEmpty { markdownBody = newBody }
        }
    }

    private var controllerQuestionPanel: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Pending Questions")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .textCase(.uppercase)
                Spacer()
                if let runtime = operatingLayer?.snapshot.controllerRuntime {
                    Text(runtime.source.label)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.blaze)
                }
            }

            ForEach(relatedPendingQuestions) { question in
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                if question.isUnread {
                                    Circle()
                                        .fill(DesignSystem.Colors.ember)
                                        .frame(width: 7, height: 7)
                                }
                                Text(question.title)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                if let stageLabel = question.stageLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
                                   stageLabel.isEmpty == false {
                                    Text(stageLabel)
                                        .font(DesignSystem.Typography.tiny)
                                        .foregroundStyle(DesignSystem.Colors.blaze)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(DesignSystem.Colors.blaze.opacity(0.12)))
                                }
                            }
                            Text(question.prompt)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        if question.notificationCount > 0 {
                            Text("Nudged \(question.notificationCount)x")
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                        }
                    }

                    if let rawHint = question.evidenceHint {
                        let hint = rawHint.trimmingCharacters(in: .whitespacesAndNewlines)
                        if hint.isEmpty == false {
                            Text(hint)
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }

                    if let deepLink = question.deepLink {
                        HStack(spacing: 4) {
                            Image(systemName: icon(for: deepLink.kind))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.whimsy)
                            Text(deepLink.title)
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                            if let subtitle = deepLink.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                               subtitle.isEmpty == false {
                                Text("• \(subtitle)")
                                    .font(DesignSystem.Typography.tiny)
                                    .foregroundStyle(DesignSystem.Colors.textMuted)
                            }
                        }
                    }

                    if question.suggestedOptions.isEmpty == false {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            ForEach(question.suggestedOptions.prefix(2)) { option in
                                Button {
                                    Task {
                                        await operatingLayer?.answerPendingQuestion(
                                            id: question.id,
                                            answer: option.answer,
                                            selectedOptionID: option.id
                                        )
                                        answerDrafts[question.id] = ""
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.title)
                                            .font(DesignSystem.Typography.tiny)
                                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        if let detail = option.detail?.trimmingCharacters(in: .whitespacesAndNewlines),
                                           detail.isEmpty == false {
                                            Text(detail)
                                                .font(DesignSystem.Typography.tiny)
                                                .foregroundStyle(DesignSystem.Colors.textMuted)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.horizontal, DesignSystem.Spacing.sm)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                            .fill(DesignSystem.Colors.surface.opacity(0.8))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        TextField(
                            {
                                if let placeholder = question.answerPlaceholder?.trimmingCharacters(in: .whitespacesAndNewlines),
                                   placeholder.isEmpty == false {
                                    return placeholder
                                }
                                return "Record an operator answer…"
                            }(),
                            text: Binding(
                                get: { answerDrafts[question.id] ?? "" },
                                set: { answerDrafts[question.id] = $0 }
                            )
                        )
                        .textFieldStyle(.roundedBorder)

                        Button("Answer") {
                            let answer = answerDrafts[question.id] ?? ""
                            Task {
                                await operatingLayer?.answerPendingQuestion(id: question.id, answer: answer)
                                answerDrafts[question.id] = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.surfaceElevated.opacity(0.72),
                            question.isUnread ? DesignSystem.Colors.ember.opacity(0.08) : DesignSystem.Colors.surface.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
            }

            if let feedback = operatingLayer?.controllerFeedback {
                Text(feedback.message)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(feedback.tone.color)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.bottom, DesignSystem.Spacing.lg)
    }

    private func controllerMissionPanel(_ mission: BurnBarControllerMissionRecord) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Mission Runtime")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .textCase(.uppercase)
                Spacer()
                Text(mission.state.label)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(mission.state.color)
                if let takeoverState = mission.latestTakeoverState {
                    Text("• \(takeoverState.label)")
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(takeoverState.color)
                }
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(mission.title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(trimmedValue(mission.packetSummary) ?? mission.summary)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    missionRuntimePill(title: "Burn", value: mission.burnCostUSD.formatAsCost(), color: DesignSystem.Colors.hermesAureate)
                    if mission.packetRunCount > 0 {
                        missionRuntimePill(title: "Runs", value: "\(mission.packetRunCount)", color: DesignSystem.Colors.blaze)
                    }
                    if mission.takeoverCount > 0 {
                        missionRuntimePill(
                            title: "Takeovers",
                            value: "\(mission.takeoverCount)",
                            color: mission.latestTakeoverState?.color ?? DesignSystem.Colors.blaze
                        )
                    }
                }

                if let activeRunID = trimmedValue(mission.activeRunID) {
                    missionRuntimeRow(icon: "point.3.filled.connected.trianglepath.dotted", title: "Run", value: activeRunID)
                }
                if let latestResult = trimmedValue(mission.latestResultSummary) {
                    missionRuntimeRow(icon: "checklist.checked", title: "Latest result", value: latestResult)
                }
                if let takeoverReason = trimmedValue(mission.latestTakeoverReason) {
                    missionRuntimeRow(
                        icon: "arrow.triangle.branch",
                        title: "Takeover",
                        value: takeoverReason,
                        accent: mission.latestTakeoverState?.color ?? DesignSystem.Colors.blaze
                    )
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.surfaceElevated.opacity(0.76),
                        (mission.latestTakeoverState?.color ?? DesignSystem.Colors.blaze).opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.bottom, DesignSystem.Spacing.lg)
    }

    @ViewBuilder
    private func missionRuntimePill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
            Text(value)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(color)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.surface.opacity(0.85))
        )
    }

    @ViewBuilder
    private func missionRuntimeRow(icon: String, title: String, value: String, accent: Color = DesignSystem.Colors.textPrimary) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 14, alignment: .top)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .textCase(.uppercase)
                Text(value)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func icon(for kind: BurnBarControllerQuestionDeepLinkKind) -> String {
        switch kind {
        case .sessionLog: return "doc.text.magnifyingglass"
        case .dashboard: return "square.grid.2x2"
        case .project: return "folder"
        case .settings: return "gearshape"
        }
    }

    private func trimmedValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }
        return trimmed
    }

    // MARK: - Structured Transcript

    @ViewBuilder
    private func structuredTranscriptView(blocks: [TranscriptBlock]) -> some View {
        VStack(spacing: 0) {
            transcriptFilterBar(blocks: blocks)

            Divider().background(DesignSystem.Colors.border.opacity(0.3))

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    if record.sourceType == .providerLog {
                        transcriptMetadataCard
                    }

                    if let summary = record.summary, !summary.isEmpty {
                        transcriptSummaryCard(summary)
                    }

                    if transcriptFilter == .all {
                        ForEach(Array(blocks.enumerated()), id: \.offset) { idx, block in
                            transcriptBlock(block)
                                .id("block-\(idx)-\(block.kind)")
                        }
                    } else {
                        let chunks = buildChunks(from: blocks, filter: transcriptFilter)
                        ForEach(chunks) { chunk in
                            transcriptChunkView(chunk, allBlocks: blocks)
                        }
                    }

                    if blocks.isEmpty && !record.fullText.isEmpty {
                        Text(.init(sessionLogFallbackMarkdown))
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .defaultScrollAnchor(.top)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.visible)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
    }

    /// When the parser yields no blocks, still render stored markdown (headings, lists) instead of plain text.
    private var sessionLogFallbackMarkdown: String {
        let raw = TranscriptBlockParser.stripSystemTags(record.fullText)
        if markdownBody.isEmpty == false { return markdownBody }
        if record.sourceType == .cliAssistant { return raw }
        return SessionLogMarkdownFormatter.markdown(for: record)
    }

    // MARK: - Filter Bar

    private func transcriptFilterBar(blocks: [TranscriptBlock]) -> some View {
        let userCount = blocks.filter { $0.kind == .userMessage }.count
        let assistantCount = blocks.filter { $0.kind == .assistantMessage }.count

        return HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(TranscriptRoleFilter.allCases, id: \.rawValue) { filter in
                let isSelected = transcriptFilter == filter
                let count: Int? = {
                    switch filter {
                    case .all: return nil
                    case .user: return userCount
                    case .assistant: return assistantCount
                    }
                }()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if transcriptFilter == filter && filter != .all {
                            transcriptFilter = .all
                            expandedChunkIndex = nil
                        } else {
                            transcriptFilter = filter
                            expandedChunkIndex = nil
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: filter.icon)
                            .font(.system(size: 9, weight: .semibold))
                        Text(filter.rawValue)
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                        if let count {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? .white.opacity(0.7) : DesignSystem.Colors.textMuted)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background {
                        Capsule(style: .continuous)
                            .fill(isSelected ? filterColor(for: filter) : DesignSystem.Colors.surface.opacity(0.6))
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                isSelected ? filterColor(for: filter).opacity(0.6) : DesignSystem.Colors.border.opacity(0.3),
                                lineWidth: 0.5
                            )
                    }
                    .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private func filterColor(for filter: TranscriptRoleFilter) -> Color {
        switch filter {
        case .all: return DesignSystem.Colors.textSecondary
        case .user: return DesignSystem.Colors.whimsy
        case .assistant: return accentColor
        }
    }

    // MARK: - Chunk Building

    private func buildChunks(from blocks: [TranscriptBlock], filter: TranscriptRoleFilter) -> [TranscriptChunk] {
        var chunks: [TranscriptChunk] = []
        var i = 0
        var chunkId = 0

        while i < blocks.count {
            let block = blocks[i]
            if filter.matchesBlock(block) {
                // Start a new chunk: gather consecutive matching blocks
                let start = i
                var chunkBlocks: [TranscriptBlock] = []
                while i < blocks.count && filter.matchesBlock(blocks[i]) {
                    chunkBlocks.append(blocks[i])
                    i += 1
                }
                chunks.append(TranscriptChunk(
                    id: chunkId,
                    primaryKind: block.kind,
                    blocks: chunkBlocks,
                    sourceRange: start..<i
                ))
                chunkId += 1
            } else {
                i += 1
            }
        }
        return chunks
    }

    // MARK: - Chunk View

    @ViewBuilder
    private func transcriptChunkView(_ chunk: TranscriptChunk, allBlocks: [TranscriptBlock]) -> some View {
        let isExpanded = expandedChunkIndex == chunk.id
        let isUserChunk = chunk.primaryKind == .userMessage
        let chunkColor = isUserChunk ? DesignSystem.Colors.whimsy : accentColor

        VStack(alignment: .leading, spacing: 0) {
            // Chunk button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedChunkIndex = isExpanded ? nil : chunk.id
                }
            } label: {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Group {
                        if isUserChunk {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(chunkColor)
                                .frame(width: 20, height: 20)
                                .background(chunkColor.opacity(0.12))
                                .clipShape(Circle())
                        } else {
                            assistantAvatarBadge(size: 20)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text(isUserChunk ? "You" : "Assistant")
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(chunkColor)
                            if chunk.blockCount > 1 {
                                Text("\(chunk.blockCount) messages")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(DesignSystem.Colors.textMuted)
                            }
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                        }
                        if !isExpanded {
                            Text(chunk.preview)
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .lineLimit(2)
                                .truncationMode(.tail)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignSystem.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content: show the chunk's blocks + surrounding context
            if isExpanded {
                Divider()
                    .background(chunkColor.opacity(0.2))
                    .padding(.horizontal, DesignSystem.Spacing.md)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Show a few blocks before for context
                    let contextBefore = contextBlocksBefore(chunk.sourceRange.lowerBound, in: allBlocks)
                    if !contextBefore.isEmpty {
                        ForEach(Array(contextBefore.enumerated()), id: \.offset) { _, block in
                            transcriptBlock(block)
                                .opacity(0.5)
                        }
                        Divider()
                            .background(chunkColor.opacity(0.15))
                    }

                    // The actual chunk blocks
                    ForEach(Array(chunk.blocks.enumerated()), id: \.offset) { _, block in
                        transcriptBlock(block)
                    }

                    // Show a few blocks after for context
                    let contextAfter = contextBlocksAfter(chunk.sourceRange.upperBound, in: allBlocks)
                    if !contextAfter.isEmpty {
                        Divider()
                            .background(chunkColor.opacity(0.15))
                        ForEach(Array(contextAfter.enumerated()), id: \.offset) { _, block in
                            transcriptBlock(block)
                                .opacity(0.5)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(chunkColor.opacity(isExpanded ? 0.04 : 0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .strokeBorder(chunkColor.opacity(isExpanded ? 0.2 : 0.12), lineWidth: 0.5)
        }
    }

    /// Grabs up to 2 context blocks before the chunk for expanded view.
    private func contextBlocksBefore(_ index: Int, in blocks: [TranscriptBlock]) -> [TranscriptBlock] {
        let start = max(0, index - 2)
        guard start < index else { return [] }
        return Array(blocks[start..<index]).filter { $0.kind != .separator }
    }

    /// Grabs up to 2 context blocks after the chunk for expanded view.
    private func contextBlocksAfter(_ index: Int, in blocks: [TranscriptBlock]) -> [TranscriptBlock] {
        let end = min(blocks.count, index + 2)
        guard index < end else { return [] }
        return Array(blocks[index..<end]).filter { $0.kind != .separator }
    }

    private var transcriptMetadataCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.md) {
                metadataField(label: "Provider", value: record.provider.displayName, color: DesignSystem.Colors.primary(for: record.provider))
                metadataField(label: "Project", value: record.projectName, color: DesignSystem.Colors.textPrimary)
            }
            HStack(spacing: DesignSystem.Spacing.md) {
                if let start = record.startTime {
                    metadataField(label: "Started", value: durationLabel(for: start), color: DesignSystem.Colors.textSecondary)
                }
                if let end = record.endTime {
                    metadataField(label: "Ended", value: durationLabel(for: end), color: DesignSystem.Colors.textSecondary)
                }
                if let start = record.startTime, let end = record.endTime {
                    let dur = end.timeIntervalSince(start)
                    if dur > 60 {
                        metadataField(label: "Duration", value: durationLabel(dur), color: DesignSystem.Colors.textSecondary)
                    }
                }
            }
            HStack(spacing: DesignSystem.Spacing.md) {
                metadataField(label: "Messages", value: "\(record.messageCount)", color: DesignSystem.Colors.textSecondary)
                if record.userWordCount > 0 || record.assistantWordCount > 0 {
                    metadataField(label: "Words", value: "\(record.userWordCount + record.assistantWordCount)", color: DesignSystem.Colors.textSecondary)
                }
            }
            if !record.keyTools.isEmpty {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Tools")
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                    ForEach(record.keyTools.prefix(6), id: \.self) { tool in
                        Text(tool)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.whimsy)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.whimsy.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            if !record.keyFiles.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Key Files")
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                    ForEach(record.keyFiles.prefix(4), id: \.self) { file in
                        Text(abbreviatePath(file))
                            .font(DesignSystem.Typography.monoTiny)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.surfaceElevated.opacity(0.5))
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .strokeBorder(DesignSystem.Colors.border.opacity(0.4), lineWidth: 0.5)
        )
    }

    private func metadataField(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
            Text(value)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(color)
        }
        .frame(minWidth: 80, alignment: .leading)
    }

    private func transcriptSummaryCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "text.quote")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.amber)
                Text("Summary")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            Text(summary)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(DesignSystem.Colors.amber.opacity(0.06))
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .strokeBorder(DesignSystem.Colors.amber.opacity(0.25), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func transcriptBlock(_ block: TranscriptBlock) -> some View {
        switch block.kind {
        case .userMessage:
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "person.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.whimsy)
                    .frame(width: 20, height: 20)
                    .background(DesignSystem.Colors.whimsy.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("You")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.whimsy)
                    Text(.init(block.content))
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.md)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: 16,
                    style: .continuous
                )
                .fill(DesignSystem.Colors.whimsy.opacity(0.06))
            }
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: 16,
                    style: .continuous
                )
                .strokeBorder(DesignSystem.Colors.whimsy.opacity(0.2), lineWidth: 0.5)
            )

        case .assistantMessage:
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                assistantAvatarBadge(size: 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Assistant")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(accentColor)
                    Text(.init(block.content))
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.md)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: 4,
                    style: .continuous
                )
                .fill(DesignSystem.Colors.surface.opacity(0.6))
            }
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: 4,
                    style: .continuous
                )
                .strokeBorder(DesignSystem.Colors.border.opacity(0.3), lineWidth: 0.5)
            )

        case .toolUse:
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: toolIconForTranscript(block.label ?? block.content))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.coral)
                Text(block.label ?? "Tool")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.coral)
                if !block.content.isEmpty && block.content != (block.label ?? "") {
                    Text(block.content)
                        .font(DesignSystem.Typography.monoTiny)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background {
                Capsule(style: .continuous)
                    .fill(DesignSystem.Colors.coral.opacity(0.08))
            }
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(DesignSystem.Colors.coral.opacity(0.2), lineWidth: 0.5)
            )

        case .codeBlock:
            VStack(alignment: .leading, spacing: 0) {
                if let lang = block.label, !lang.isEmpty {
                    Text(lang)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xxs)
                        .background(DesignSystem.Colors.border.opacity(0.3))
                }
                Text(block.content)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .textSelection(.enabled)
                    .padding(DesignSystem.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DesignSystem.Colors.background.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.border.opacity(0.4), lineWidth: 0.5)
            )

        case .separator:
            Divider()
                .background(DesignSystem.Colors.border.opacity(0.3))
                .padding(.vertical, DesignSystem.Spacing.xs)
        }
    }

    private func toolIconForTranscript(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("read") || n.contains("file") || n.contains("write") { return "doc.text" }
        if n.contains("bash") || n.contains("exec") || n.contains("run") || n.contains("terminal") { return "terminal" }
        if n.contains("search") || n.contains("grep") || n.contains("glob") { return "magnifyingglass" }
        if n.contains("web") || n.contains("browser") || n.contains("fetch") { return "globe" }
        if n.contains("edit") || n.contains("patch") { return "pencil.and.outline" }
        if n.contains("agent") { return "person.2" }
        if n.contains("task") { return "checklist" }
        return "wrench.and.screwdriver"
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var p = path
        if p.hasPrefix(home) {
            p = "~" + p.dropFirst(home.count)
        }
        return p
    }

    private func durationLabel(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }

    @ViewBuilder
    private func jumpTargetCard(_ target: ConversationJumpTarget) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "scope")
                    .font(.system(size: 10, weight: .semibold))
                Text(target.source == .aggregateExact ? "Exact transcript match" : "Retrieved passage")
                    .font(DesignSystem.Typography.tiny)
            }
            .foregroundStyle(DesignSystem.Colors.whimsy)

            Text(target.snippet)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .textSelection(.enabled)

            Text("Offsets \(target.startOffset)-\(target.endOffset)")
                .font(DesignSystem.Typography.monoTiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.whimsy.opacity(0.08))
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    if record.sourceType == .cliAssistant {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 9, weight: .semibold))
                    } else {
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    Text(record.sourceType == .cliAssistant ? "Assistant" : record.provider.displayName)
                        .font(DesignSystem.Typography.tiny)
                }
                .foregroundStyle(accentColor)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .background(
                    Capsule().fill(accentColor.opacity(0.14))
                )
                .overlay(
                    Capsule().strokeBorder(accentColor.opacity(0.35), lineWidth: 0.5)
                )

                Text(record.projectName)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)

                Spacer(minLength: 0)

                if let date = record.endTime ?? record.startTime {
                    Text(date.relativeLabel)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
            }

            Text(displayTitle)
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DesignSystem.Spacing.sm) {
                metaChip(icon: "bubble.left.and.bubble.right", label: "\(record.messageCount) messages")
                if record.userWordCount > 0 {
                    metaChip(icon: "textformat", label: "\(record.userWordCount + record.assistantWordCount) words")
                }
                if record.sourceType == .providerLog, let start = record.startTime, let end = record.endTime {
                    let duration = end.timeIntervalSince(start)
                    if duration > 60 {
                        metaChip(icon: "clock", label: durationLabel(duration))
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(Color.clear)
    }

    private func metaChip(icon: String, label: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
            Text(label)
                .font(DesignSystem.Typography.tiny)
        }
        .foregroundStyle(DesignSystem.Colors.textMuted)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .background(
            Capsule().fill(DesignSystem.Colors.surfaceElevated.opacity(0.5))
        )
        .overlay(
            Capsule().strokeBorder(DesignSystem.Colors.border.opacity(0.4), lineWidth: 0.5)
        )
    }

    private var actionBar: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(markdownBody, forType: .string)
                withAnimation(DesignSystem.Animation.snappy) { copyConfirmed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(DesignSystem.Animation.snappy) { copyConfirmed = false }
                }
            } label: {
                Label(
                    copyConfirmed ? "Copied!" : "Copy Markdown",
                    systemImage: copyConfirmed ? "checkmark" : "doc.on.doc"
                )
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(copyConfirmed ? DesignSystem.Colors.success : accentColor)
            }
            .buttonStyle(.plain)
            .disabled(markdownBody.isEmpty)

            Button {
                exportMarkdown()
            } label: {
                Label("Export .md", systemImage: "arrow.down.doc")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(markdownBody.isEmpty)
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    private func buildMarkdown() {
        if let body = overrideBody, !body.isEmpty {
            markdownBody = body
        } else {
            markdownBody = SessionLogMarkdownFormatter.markdown(for: record)
        }
    }

    private func exportMarkdown() {
        let panel = NSSavePanel()
        let slug = displayTitle.isEmpty ? "session" : displayTitle
        let safe = slug
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .lowercased()
            .prefix(60)
        panel.nameFieldStringValue = "\(safe).md"
        if let mdType = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [mdType]
        }
        panel.title = "Export session log"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? markdownBody.write(to: url, atomically: true, encoding: .utf8)
    }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds / 60)
        return mins < 60 ? "\(mins)m" : "\(mins / 60)h \(mins % 60)m"
    }
}

// MARK: - Date Relative Label

private extension Date {
    var relativeLabel: String {
        let interval = Date().timeIntervalSince(self)
        switch interval {
        case ..<60:          return "Just now"
        case ..<3_600:       return "\(Int(interval / 60))m ago"
        case ..<86_400:      return "\(Int(interval / 3_600))h ago"
        case ..<604_800:     return "\(Int(interval / 86_400))d ago"
        default:
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .none
            return fmt.string(from: self)
        }
    }
}

// MARK: - Session Log Cloud Consent Sheet

struct SessionLogCloudConsentSheet: View {
    @Bindable var settingsManager: SettingsManager
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.ember.opacity(0.4),
                                    DesignSystem.Colors.amber.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: "scroll.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Back up session logs to the cloud?")
                        .font(DesignSystem.Typography.title)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("BurnBar can securely back up your full conversation logs — including provider sessions and BurnBar Assistant history — to your private cloud storage. Access and export them from any device.")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                featureBullet(
                    icon: "lock.icloud",
                    iconColor: DesignSystem.Colors.whimsy,
                    text: "Stored under your account — no other user can access your logs."
                )
                featureBullet(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: DesignSystem.Colors.amber,
                    text: "Existing logs are backfilled automatically on first enable."
                )
                featureBullet(
                    icon: "gearshape",
                    iconColor: DesignSystem.Colors.textMuted,
                    text: "Toggle off anytime in Settings → Account."
                )
            }

            Divider().background(DesignSystem.Colors.border.opacity(0.5))

            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Not now") {
                    settingsManager.sessionLogCloudBackupEnabled = false
                    settingsManager.sessionLogCloudBackupConsentShown = true
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Enable Cloud Backup") {
                    settingsManager.sessionLogCloudBackupEnabled = true
                    settingsManager.sessionLogCloudBackupConsentShown = true
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.ember)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(minWidth: 440, maxWidth: 520)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .fill(DesignSystem.Colors.surfaceElevated.opacity(0.55))

                LinearGradient(
                    colors: [
                        DesignSystem.Colors.ember.opacity(0.06),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), DesignSystem.Colors.border.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
    }

    private func featureBullet(icon: String, iconColor: Color, text: String) -> some View {
        Label {
            Text(text)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 20, alignment: .center)
        }
    }
}
