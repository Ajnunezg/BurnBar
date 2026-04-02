import SwiftUI

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Control Room Section

private enum ControlRoomSection: String, CaseIterable, Identifiable {
    case overview
    case missions
    case queue
    case artifacts

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: return "Overview"
        case .missions: return "Missions"
        case .queue: return "Queue"
        case .artifacts: return "Artifacts"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "gauge.open.with.lines.needle.33percent.and.arrowtriangle"
        case .missions: return "target"
        case .queue: return "tray.full.fill"
        case .artifacts: return "doc.text.fill"
        }
    }
}

// MARK: - Missions View (Control Room)

struct MissionsView: View {
    @Bindable var operatingLayer: BurnBarOperatingLayer
    var dataStore: DataStore?
    var onNavigateToSessionLogs: () -> Void

    @State private var openMissionID: String?
    @State private var activeSection: ControlRoomSection = .overview
    @State private var listAppeared = false

    private var allMissions: [BurnBarControllerMissionRecord] {
        operatingLayer.snapshot.controllerRuntime.missions
    }

    private var pendingQuestions: [BurnBarControllerQuestion] {
        operatingLayer.snapshot.controllerRuntime.pendingQuestions
    }

    private var followups: [BurnBarControllerFollowup] {
        operatingLayer.snapshot.controllerRuntime.followups
    }

    private var recentEvents: [BurnBarControllerEvent] {
        operatingLayer.snapshot.controllerRuntime.recentEvents
    }

    private var activeMissions: [BurnBarControllerMissionRecord] {
        allMissions.filter { $0.state == .running || $0.state == .partial }
    }

    private var blockedMissions: [BurnBarControllerMissionRecord] {
        allMissions.filter { $0.state == .blocked }
    }

    private var pendingApprovals: [BurnBarControllerMissionRecord] {
        allMissions.filter { $0.approval == .pending }
    }

    private var openFollowups: [BurnBarControllerFollowup] {
        followups.filter { $0.state == .open || $0.state == .snoozed }
    }

    var body: some View {
        Group {
            if let missionID = openMissionID,
               let mission = allMissions.first(where: { $0.id == missionID }) {
                MissionDetailView(
                    mission: mission,
                    operatingLayer: operatingLayer,
                    pendingQuestions: pendingQuestions.filter { $0.projectName == mission.projectName },
                    onBack: {
                        withAnimation(DesignSystem.Animation.standard) {
                            openMissionID = nil
                        }
                    },
                    onNavigateToSessionLogs: onNavigateToSessionLogs
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            } else {
                controlRoomView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(DesignSystem.Animation.standard, value: openMissionID)
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Control Room

    private var controlRoomView: some View {
        VStack(spacing: 0) {
            // Header
            controlRoomHeader
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.top, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.md)

            // Section tabs
            sectionTabs
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.lg)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    switch activeSection {
                    case .overview:
                        overviewSection
                    case .missions:
                        missionsSection
                    case .queue:
                        queueSection
                    case .artifacts:
                        artifactsSection
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
        .onAppear { listAppeared = true }
    }

    // MARK: - Header

    private var controlRoomHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                    Text("gstack")
                        .font(DesignSystem.Typography.title)
                        .foregroundStyle(DesignSystem.Colors.hermesAureate)
                    Text("Mission Command Center")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                HStack(spacing: DesignSystem.Spacing.md) {
                    statusIndicator(
                        count: activeMissions.count,
                        label: "active",
                        color: DesignSystem.Colors.blaze
                    )
                    statusIndicator(
                        count: pendingQuestions.count,
                        label: "pending",
                        color: DesignSystem.Colors.amber
                    )
                    statusIndicator(
                        count: blockedMissions.count,
                        label: "blocked",
                        color: DesignSystem.Colors.error
                    )
                }
            }

            Spacer()

            // Quick action: refresh
            Button {
                Task { await operatingLayer.refreshControllerRuntime() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                            .fill(DesignSystem.Colors.surfaceElevated.opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                            .stroke(DesignSystem.Colors.border.opacity(0.3), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func statusIndicator(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(count > 0 ? color : DesignSystem.Colors.textMuted)
                .frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(count > 0 ? color : DesignSystem.Colors.textMuted)
        }
    }

    // MARK: - Section Tabs

    private var sectionTabs: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(ControlRoomSection.allCases) { section in
                let isActive = section == activeSection
                let badgeCount = badgeForSection(section)

                Button {
                    withAnimation(DesignSystem.Animation.snappy) { activeSection = section }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: section.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(section.label)
                            .font(DesignSystem.Typography.caption)
                        if badgeCount > 0 {
                            Text("\(badgeCount)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(isActive ? DesignSystem.Colors.background : DesignSystem.Colors.amber)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(isActive ? DesignSystem.Colors.amber : DesignSystem.Colors.amber.opacity(0.2))
                                )
                        }
                    }
                    .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textMuted)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                            .fill(isActive ? DesignSystem.Colors.surfaceElevated : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                            .stroke(isActive ? DesignSystem.Colors.border.opacity(0.4) : Color.clear, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    private func badgeForSection(_ section: ControlRoomSection) -> Int {
        switch section {
        case .overview: return 0
        case .missions: return pendingApprovals.count
        case .queue: return pendingQuestions.count + openFollowups.count
        case .artifacts: return 0
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Stat cards row — tappable, jumps to Missions tab
            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    withAnimation(DesignSystem.Animation.snappy) { activeSection = .missions }
                } label: {
                    overviewStatCard(
                        title: "Total missions",
                        value: "\(allMissions.count)",
                        icon: "target",
                        color: DesignSystem.Colors.textPrimary
                    )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(DesignSystem.Animation.snappy) { activeSection = .missions }
                } label: {
                    overviewStatCard(
                        title: "Total burn",
                        value: allMissions.reduce(0) { $0 + $1.burnCostUSD }.formatAsCost(),
                        icon: "flame.fill",
                        color: DesignSystem.Colors.hermesAureate
                    )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(DesignSystem.Animation.snappy) { activeSection = .missions }
                } label: {
                    overviewStatCard(
                        title: "Total runs",
                        value: "\(allMissions.reduce(0) { $0 + $1.packetRunCount })",
                        icon: "bolt.horizontal.fill",
                        color: DesignSystem.Colors.blaze
                    )
                }
                .buttonStyle(.plain)
            }

            // Urgent items
            if !pendingApprovals.isEmpty || !pendingQuestions.isEmpty || !blockedMissions.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    controlRoomSectionHeader("Needs attention")

                    ForEach(pendingApprovals) { mission in
                        urgentRow(
                            icon: "checkmark.seal",
                            iconColor: DesignSystem.Colors.amber,
                            title: mission.title,
                            subtitle: "Awaiting approval",
                            action: { withAnimation(DesignSystem.Animation.standard) { openMissionID = mission.id } }
                        )
                    }

                    ForEach(blockedMissions) { mission in
                        urgentRow(
                            icon: "exclamationmark.octagon.fill",
                            iconColor: DesignSystem.Colors.error,
                            title: mission.title,
                            subtitle: "Blocked",
                            action: { withAnimation(DesignSystem.Animation.standard) { openMissionID = mission.id } }
                        )
                    }

                    ForEach(pendingQuestions.prefix(3)) { question in
                        urgentRow(
                            icon: "questionmark.circle.fill",
                            iconColor: DesignSystem.Colors.amber,
                            title: question.title,
                            subtitle: question.projectName,
                            action: {
                                withAnimation(DesignSystem.Animation.snappy) { activeSection = .queue }
                            }
                        )
                    }
                }
            }

            // All missions — always visible when there are any
            if !allMissions.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        controlRoomSectionHeader("Missions")
                        Spacer()
                        Button {
                            withAnimation(DesignSystem.Animation.snappy) { activeSection = .missions }
                        } label: {
                            Text("View all \u{2192}")
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(DesignSystem.Colors.whimsy)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(allMissions.sorted { $0.updatedAt > $1.updatedAt }.prefix(5)) { mission in
                        MissionRow(mission: mission) {
                            withAnimation(DesignSystem.Animation.standard) {
                                openMissionID = mission.id
                            }
                        }
                    }
                }
            }

            // Recent events
            if !recentEvents.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    controlRoomSectionHeader("Recent activity")

                    ForEach(recentEvents.prefix(6)) { event in
                        eventRow(event)
                    }
                }
            }

            // Empty state
            if allMissions.isEmpty && pendingQuestions.isEmpty && recentEvents.isEmpty {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "gauge.open.with.lines.needle.33percent.and.arrowtriangle")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                    Text("Control room is quiet")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Text("Missions, questions, and activity appear here as BurnBar detects work across your projects.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xxxl)
            }
        }
    }

    private func overviewStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color.opacity(0.7))
                    Text(title)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
                Text(value)
                    .font(DesignSystem.Typography.monoLarge)
                    .foregroundStyle(color)
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func urgentRow(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textMuted)
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                    .fill(iconColor.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                    .stroke(iconColor.opacity(0.12), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func eventRow(_ event: BurnBarControllerEvent) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Circle()
                .fill(event.category.color)
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                Text(event.summary)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .lineLimit(2)
            }

            Spacer()

            Text(event.createdAt, style: .relative)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    // MARK: - Missions Section

    private var missionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Filter chips
            missionFilterChips

            // Mission list
            if allMissions.isEmpty {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "target")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                    Text("No missions yet")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Text("Missions appear when BurnBar detects active work across your projects.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xxxl)
            } else {
                let filtered = missionFilterState.map { state in
                    allMissions.filter { $0.state == state }
                } ?? allMissions
                let sorted = filtered.sorted { $0.updatedAt > $1.updatedAt }

                if sorted.isEmpty {
                    Text("No \(missionFilterState?.label.lowercased() ?? "") missions")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.xl)
                } else {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, mission in
                            MissionRow(mission: mission) {
                                withAnimation(DesignSystem.Animation.standard) {
                                    openMissionID = mission.id
                                }
                            }
                            .opacity(listAppeared ? 1 : 0)
                            .offset(y: listAppeared ? 0 : 8)
                            .animation(
                                DesignSystem.Animation.standard.delay(Double(index) * 0.04),
                                value: listAppeared
                            )
                        }
                    }
                }
            }
        }
    }

    @State private var missionFilterState: BurnBarMissionLifecycle?

    private var missionFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                MissionFilterChip(title: "All", isActive: missionFilterState == nil, activeColor: DesignSystem.Colors.textPrimary) {
                    withAnimation(DesignSystem.Animation.standard) { missionFilterState = nil }
                }
                ForEach([BurnBarMissionLifecycle.planned, .running, .partial, .blocked, .completed], id: \.self) { lifecycle in
                    let count = allMissions.filter { $0.state == lifecycle }.count
                    MissionFilterChip(
                        title: "\(lifecycle.label)\(count > 0 ? " (\(count))" : "")",
                        isActive: missionFilterState == lifecycle,
                        activeColor: lifecycle.color
                    ) {
                        withAnimation(DesignSystem.Animation.standard) { missionFilterState = lifecycle }
                    }
                }
            }
        }
    }

    // MARK: - Queue Section (Questions + Followups)

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Pending questions
            if !pendingQuestions.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        controlRoomSectionHeader("Pending questions")
                        Spacer()
                        Text("\(pendingQuestions.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(DesignSystem.Colors.amber)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.amber.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    ForEach(pendingQuestions) { question in
                        InlineQuestionRow(question: question, operatingLayer: operatingLayer)
                    }
                }
            }

            // Open followups
            if !openFollowups.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    controlRoomSectionHeader("Open followups")

                    ForEach(openFollowups) { followup in
                        FollowupRow(followup: followup, operatingLayer: operatingLayer)
                    }
                }
            }

            // Pending approvals
            if !pendingApprovals.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    controlRoomSectionHeader("Awaiting approval")

                    ForEach(pendingApprovals) { mission in
                        MissionApprovalCard(mission: mission, operatingLayer: operatingLayer)
                    }
                }
            }

            // Empty state
            if pendingQuestions.isEmpty && openFollowups.isEmpty && pendingApprovals.isEmpty {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "tray")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                    Text("Queue is clear")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Text("No pending questions, followups, or approvals.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xxxl)
            }
        }
    }

    // MARK: - Artifacts Section

    private var artifactsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // gstack review artifacts
            let artifacts = (try? dataStore?.fetchSourceArtifacts()) ?? []
            let reviewArtifacts = artifacts.filter { artifact in
                let t = artifact.title.lowercased()
                return t.contains("review") || t.contains("plan") || t.contains("ceo") || t.contains("founder")
            }.sorted { $0.updatedAt > $1.updatedAt }

            let ceoReviews = reviewArtifacts.filter {
                let t = $0.title.lowercased()
                return t.contains("ceo") || t.contains("founder") || (t.contains("plan") && t.contains("review") && !t.contains("eng"))
            }
            let engReviews = reviewArtifacts.filter {
                let t = $0.title.lowercased()
                return t.contains("eng") || t.contains("engineering") || t.contains("architecture")
            }

            // CEO / Founder Reviews
            if !ceoReviews.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    controlRoomSectionHeader("CEO & Founder Reviews")

                    ForEach(ceoReviews.prefix(10), id: \.id) { artifact in
                        artifactCard(
                            icon: "checkmark.seal.fill",
                            iconColor: DesignSystem.Colors.hermesAureate,
                            title: artifact.title,
                            subtitle: String(artifact.body.prefix(120)),
                            detail: artifact.rootPath.components(separatedBy: "/").last ?? artifact.rootPath,
                            timestamp: artifact.updatedAt,
                            action: {}
                        )
                    }
                }
            }

            // Engineering Plan Reviews
            if !engReviews.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    controlRoomSectionHeader("Engineering Plan Reviews")

                    ForEach(engReviews.prefix(10), id: \.id) { artifact in
                        artifactCard(
                            icon: "wrench.and.screwdriver.fill",
                            iconColor: DesignSystem.Colors.blaze,
                            title: artifact.title,
                            subtitle: String(artifact.body.prefix(120)),
                            detail: artifact.rootPath.components(separatedBy: "/").last ?? artifact.rootPath,
                            timestamp: artifact.updatedAt,
                            action: {}
                        )
                    }
                }
            }

            // Decision log from operating action history
            let actionRecords = (try? dataStore?.fetchOperatingActionRecords(limit: 20)) ?? []
            if !actionRecords.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    controlRoomSectionHeader("Decision Log")

                    ForEach(actionRecords, id: \.id) { record in
                        GlassCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    Circle()
                                        .fill(record.actionKind == .missionApproval ? DesignSystem.Colors.hermesAureate : DesignSystem.Colors.whimsy)
                                        .frame(width: 6, height: 6)
                                    Text(record.summary)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(record.createdAt, style: .relative)
                                        .font(DesignSystem.Typography.tiny)
                                        .foregroundStyle(DesignSystem.Colors.textMuted)
                                }
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Text(record.projectName)
                                        .font(DesignSystem.Typography.tiny)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    if let detail = record.detail?.nonEmpty {
                                        Text("·")
                                            .foregroundStyle(DesignSystem.Colors.textMuted)
                                        Text(detail)
                                            .font(DesignSystem.Typography.tiny)
                                            .foregroundStyle(DesignSystem.Colors.textMuted)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .padding(DesignSystem.Spacing.md)
                        }
                    }
                }
            }

            // Recent completed missions with results
            let completedWithResults = allMissions
                .filter { $0.state == .completed && $0.latestResultSummary?.nonEmpty != nil }
                .sorted { $0.updatedAt > $1.updatedAt }

            if !completedWithResults.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    controlRoomSectionHeader("Mission results")

                    ForEach(completedWithResults.prefix(10)) { mission in
                        artifactCard(
                            icon: "checkmark.circle.fill",
                            iconColor: DesignSystem.Colors.success,
                            title: mission.title,
                            subtitle: mission.latestResultSummary ?? "",
                            detail: mission.projectName,
                            timestamp: mission.updatedAt,
                            action: { withAnimation(DesignSystem.Animation.standard) { openMissionID = mission.id } }
                        )
                    }
                }
            }

            // Recent events as artifact log
            if !recentEvents.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    controlRoomSectionHeader("Event log")

                    ForEach(recentEvents) { event in
                        GlassCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    Circle()
                                        .fill(event.category.color)
                                        .frame(width: 6, height: 6)
                                    Text(event.title)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(event.createdAt, style: .relative)
                                        .font(DesignSystem.Typography.tiny)
                                        .foregroundStyle(DesignSystem.Colors.textMuted)
                                }
                                Text(event.summary)
                                    .font(DesignSystem.Typography.tiny)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    .lineLimit(3)
                                if let detail = event.detail?.nonEmpty {
                                    Text(detail)
                                        .font(DesignSystem.Typography.tiny)
                                        .foregroundStyle(DesignSystem.Colors.textMuted)
                                        .lineLimit(2)
                                }
                            }
                            .padding(DesignSystem.Spacing.md)
                        }
                    }
                }
            }

            // Session logs link
            GlassButton(
                title: "Open Session Logs",
                icon: "doc.text.magnifyingglass",
                style: .regular,
                action: onNavigateToSessionLogs
            )

            // Empty state
            let hasContent = !ceoReviews.isEmpty || !engReviews.isEmpty || !actionRecords.isEmpty || !completedWithResults.isEmpty || !recentEvents.isEmpty
            if !hasContent {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                    Text("No artifacts yet")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Text("CEO reviews, engineering plans, decision logs, and mission results appear here.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xxxl)
            }
        }
    }

    private func artifactCard(icon: String, iconColor: Color, title: String, subtitle: String, detail: String, timestamp: Date, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            GlassCard(interactive: true) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(iconColor)
                        Text(title)
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(timestamp, style: .relative)
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                    }
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                    Text(detail)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
                .padding(DesignSystem.Spacing.md)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Header

    private func controlRoomSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DesignSystem.Typography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .textCase(.uppercase)
    }
}

// MARK: - Mission Approval Card (inline)

private struct MissionApprovalCard: View {
    let mission: BurnBarControllerMissionRecord
    @Bindable var operatingLayer: BurnBarOperatingLayer
    @State private var approvalNote = ""

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.amber)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(mission.title)
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                        Text(mission.projectName)
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                    }
                }

                if !mission.summary.isEmpty {
                    Text(mission.summary)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(3)
                }

                HStack(spacing: DesignSystem.Spacing.sm) {
                    TextField("Optional note\u{2026}", text: $approvalNote)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                .fill(DesignSystem.Colors.surfaceElevated.opacity(0.6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                .stroke(DesignSystem.Colors.border.opacity(0.4), lineWidth: 0.75)
                        )

                    Button {
                        withAnimation(DesignSystem.Animation.standard) {
                            operatingLayer.approveMission(id: mission.id, projectName: mission.projectName, note: approvalNote)
                            approvalNote = ""
                        }
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .medium))
                            Text("Approve")
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundStyle(DesignSystem.Colors.hermesAureate)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                                .fill(DesignSystem.Colors.hermesAureate.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                                .stroke(DesignSystem.Colors.hermesAureate.opacity(0.35), lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }
}

// MARK: - Followup Row

private struct FollowupRow: View {
    let followup: BurnBarControllerFollowup
    @Bindable var operatingLayer: BurnBarOperatingLayer
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Button {
                withAnimation(DesignSystem.Animation.standard) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: followup.state == .snoozed ? "clock.badge.fill" : "arrow.uturn.right.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(followup.state == .snoozed ? DesignSystem.Colors.textMuted : DesignSystem.Colors.whimsy)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        if let stageLabel = followup.stageLabel?.nonEmpty {
                            Text(stageLabel)
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(DesignSystem.Colors.whimsy)
                        }
                        Text(followup.title)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(expanded ? nil : 2)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Text(followup.projectName)
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                            if let due = followup.dueAt {
                                Text("Due \(due, style: .relative)")
                                    .font(DesignSystem.Typography.tiny)
                                    .foregroundStyle(due < Date() ? DesignSystem.Colors.error : DesignSystem.Colors.textMuted)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Text(followup.summary)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 28)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Button {
                        Task { await operatingLayer.completeFollowup(id: followup.id) }
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Complete")
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundStyle(DesignSystem.Colors.success)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                .fill(DesignSystem.Colors.success.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                .stroke(DesignSystem.Colors.success.opacity(0.3), lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        let snoozeDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
                        Task { await operatingLayer.snoozeFollowup(id: followup.id, until: snoozeDate) }
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "clock")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Snooze 4h")
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                .fill(DesignSystem.Colors.surfaceElevated.opacity(0.6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                .stroke(DesignSystem.Colors.border.opacity(0.3), lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 28)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                .fill(DesignSystem.Colors.surfaceElevated.opacity(expanded ? 0.4 : 0))
        )
    }
}

// MARK: - Mission Detail View (full screen)

private struct MissionDetailView: View {
    let mission: BurnBarControllerMissionRecord
    @Bindable var operatingLayer: BurnBarOperatingLayer
    let pendingQuestions: [BurnBarControllerQuestion]
    let onBack: () -> Void
    let onNavigateToSessionLogs: () -> Void

    @State private var approvalNote = ""

    private var canApprove: Bool {
        mission.approval == .pending && operatingLayer.snapshot.mission.missionID == mission.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                // Back bar
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 12, weight: .semibold))
                        Text("gstack")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(DesignSystem.Colors.surfaceElevated.opacity(0.62))
                    )
                    .overlay(
                        Capsule().stroke(DesignSystem.Colors.borderSubtle.opacity(0.7), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Title block
                HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(mission.title)
                            .font(DesignSystem.Typography.title)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Text(mission.projectName)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                            Text("\u{00B7}")
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                            Text(mission.updatedAt, style: .relative)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        missionStatusBadge(title: mission.state.label, color: mission.state.color)
                        missionStatusBadge(title: mission.approval.label, color: mission.approval.color)
                        if let takeoverState = mission.latestTakeoverState {
                            missionStatusBadge(title: takeoverState.label, color: takeoverState.color)
                        }
                    }
                }

                // Metrics strip
                HStack(spacing: DesignSystem.Spacing.lg) {
                    metricChip(title: "Burn", value: mission.burnCostUSD.formatAsCost(), color: DesignSystem.Colors.hermesAureate)
                    metricChip(title: "Tokens", value: mission.burnTokens.formatAsTokenVolume(), color: DesignSystem.Colors.textPrimary)
                    metricChip(title: "Runs", value: "\(mission.packetRunCount)", color: DesignSystem.Colors.blaze)
                    if mission.takeoverCount > 0 {
                        metricChip(title: "Takeovers", value: "\(mission.takeoverCount)", color: mission.latestTakeoverState?.color ?? DesignSystem.Colors.blaze)
                    }
                }

                // Summary card
                GlassCard {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        detailSectionHeader("Summary")
                        Text(mission.summary)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let packetSummary = mission.packetSummary?.nonEmpty, packetSummary != mission.summary {
                            Text(packetSummary)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }

                // Active execution card
                if mission.activeWorkerName?.nonEmpty != nil || mission.activeRunID?.nonEmpty != nil {
                    GlassCard {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            detailSectionHeader("Active Execution")
                            if let workerName = mission.activeWorkerName?.nonEmpty {
                                factRow(icon: "bolt.horizontal.circle.fill", title: "Worker", value: workerName)
                            }
                            if let runID = mission.activeRunID?.nonEmpty {
                                factRow(icon: "point.3.filled.connected.trianglepath.dotted", title: "Run", value: runID)
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                }

                // Latest result card
                if mission.latestResultSummary?.nonEmpty != nil {
                    GlassCard {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            detailSectionHeader("Latest Result")
                            if let resultSummary = mission.latestResultSummary?.nonEmpty {
                                Text(resultSummary)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let resultDetail = mission.latestResultDetail?.nonEmpty {
                                Text(resultDetail)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let resultRunID = mission.latestResultRunID?.nonEmpty {
                                factRow(icon: "checkmark.circle", title: "Result run", value: resultRunID)
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                }

                // Takeover card
                if mission.takeoverCount > 0 {
                    GlassCard {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            detailSectionHeader("Auto-Takeover")
                            if let takeoverState = mission.latestTakeoverState {
                                factRow(icon: "arrow.triangle.branch", title: "Status", value: takeoverState.label, accent: takeoverState.color)
                            }
                            if let reason = mission.latestTakeoverReason?.nonEmpty {
                                factRow(icon: "exclamationmark.triangle", title: "Reason", value: reason)
                            }
                            if let takeoverRunID = mission.latestTakeoverRunID?.nonEmpty {
                                factRow(icon: "figure.run", title: "Takeover run", value: takeoverRunID)
                            }
                            Text("\(mission.takeoverCount) takeover attempt\(mission.takeoverCount == 1 ? "" : "s") total")
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                }

                // Pending questions for this project
                if !pendingQuestions.isEmpty {
                    PendingQuestionsStrip(
                        questions: pendingQuestions,
                        operatingLayer: operatingLayer
                    )
                }

                // Approval card
                if canApprove {
                    GlassCard {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            detailSectionHeader("Approve Mission")
                            Text("This mission is waiting for operator approval before proceeding.")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)

                            HStack(spacing: DesignSystem.Spacing.sm) {
                                TextField("Optional note\u{2026}", text: $approvalNote)
                                    .textFieldStyle(.plain)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                    .padding(.vertical, DesignSystem.Spacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                            .fill(DesignSystem.Colors.surfaceElevated.opacity(0.6))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                            .stroke(DesignSystem.Colors.border.opacity(0.4), lineWidth: 0.75)
                                    )

                                Button {
                                    withAnimation(DesignSystem.Animation.standard) {
                                        operatingLayer.approveMission(id: mission.id, projectName: mission.projectName, note: approvalNote)
                                        approvalNote = ""
                                    }
                                } label: {
                                    HStack(spacing: DesignSystem.Spacing.xs) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 12, weight: .medium))
                                        Text("Approve")
                                            .font(DesignSystem.Typography.caption)
                                    }
                                    .foregroundStyle(DesignSystem.Colors.hermesAureate)
                                    .padding(.horizontal, DesignSystem.Spacing.lg)
                                    .padding(.vertical, DesignSystem.Spacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                                            .fill(DesignSystem.Colors.hermesAureate.opacity(0.12))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                                            .stroke(DesignSystem.Colors.hermesAureate.opacity(0.35), lineWidth: 0.75)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                }

                // Actions
                HStack(spacing: DesignSystem.Spacing.md) {
                    GlassButton(
                        title: "Inspect Session Logs",
                        icon: "doc.text.magnifyingglass",
                        style: .regular,
                        action: onNavigateToSessionLogs
                    )
                }

                // Feedback
                if let feedback = operatingLayer.controllerFeedback {
                    Text(feedback.message)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(feedback.tone.color)
                }

                // Timestamp
                Text("Last updated \(mission.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
            }
            .padding(DesignSystem.Spacing.xl)
        }
    }
}

// MARK: - Pending Questions Strip

private struct PendingQuestionsStrip: View {
    let questions: [BurnBarControllerQuestion]
    @Bindable var operatingLayer: BurnBarOperatingLayer

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    detailSectionHeader("Pending Questions")
                    Spacer()
                    Text("\(questions.count)")
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.amber)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.amber.opacity(0.15))
                        .clipShape(Capsule())
                }

                ForEach(questions) { question in
                    InlineQuestionRow(question: question, operatingLayer: operatingLayer)
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }
}

// MARK: - Inline Question Row (answerable)

private struct InlineQuestionRow: View {
    let question: BurnBarControllerQuestion
    @Bindable var operatingLayer: BurnBarOperatingLayer
    @State private var answerText = ""
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Button {
                withAnimation(DesignSystem.Animation.standard) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Circle()
                        .fill(DesignSystem.Colors.amber)
                        .frame(width: 6, height: 6)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 2) {
                        if let stageLabel = question.stageLabel?.nonEmpty {
                            Text(stageLabel)
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(DesignSystem.Colors.amber)
                        }
                        Text(question.title)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(expanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: expanded)
                    }

                    Spacer()

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                if let prompt = question.prompt.nonEmpty {
                    Text(prompt)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, DesignSystem.Spacing.lg)
                }

                // Suggested options
                if !question.suggestedOptions.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(question.suggestedOptions, id: \.id) { option in
                            Button {
                                Task {
                                    await operatingLayer.answerPendingQuestion(
                                        id: question.id,
                                        answer: option.answer.isEmpty ? option.title : option.answer,
                                        selectedOptionID: option.id
                                    )
                                }
                            } label: {
                                Text(option.title)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.whimsy)
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                            .fill(DesignSystem.Colors.whimsy.opacity(0.10))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                            .stroke(DesignSystem.Colors.whimsy.opacity(0.3), lineWidth: 0.75)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, DesignSystem.Spacing.lg)
                }

                // Free text answer
                HStack(spacing: DesignSystem.Spacing.sm) {
                    TextField("Type an answer\u{2026}", text: $answerText)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                .fill(DesignSystem.Colors.surfaceElevated.opacity(0.6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                .stroke(DesignSystem.Colors.border.opacity(0.4), lineWidth: 0.75)
                        )
                        .onSubmit { sendAnswer() }

                    Button(action: sendAnswer) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? DesignSystem.Colors.textMuted
                                : DesignSystem.Colors.whimsy)
                    }
                    .buttonStyle(.plain)
                    .disabled(answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.leading, DesignSystem.Spacing.lg)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                .fill(DesignSystem.Colors.surfaceElevated.opacity(expanded ? 0.4 : 0))
        )
    }

    private func sendAnswer() {
        let trimmed = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            await operatingLayer.answerPendingQuestion(id: question.id, answer: trimmed)
            answerText = ""
        }
    }
}

// MARK: - Filter Chip

private struct MissionFilterChip: View {
    let title: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(isActive ? activeColor : DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? activeColor.opacity(0.18) : DesignSystem.Colors.surfaceElevated.opacity(0.6))
                )
                .overlay(
                    Capsule()
                        .stroke(isActive ? activeColor.opacity(0.35) : DesignSystem.Colors.border.opacity(0.3), lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mission Row

private struct MissionRow: View {
    let mission: BurnBarControllerMissionRecord
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard(interactive: true) {
                HStack(spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(mission.title)
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Text(mission.projectName)
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                            Text("\u{00B7}")
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                            Text(mission.updatedAt, style: .relative)
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                        }

                        Text(mission.packetSummary?.nonEmpty ?? mission.summary)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .lineLimit(2)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            metricChip(title: "Burn", value: mission.burnCostUSD.formatAsCost(), color: DesignSystem.Colors.hermesAureate)
                            if mission.packetRunCount > 0 {
                                metricChip(title: "Runs", value: "\(mission.packetRunCount)", color: DesignSystem.Colors.blaze)
                            }
                            if mission.takeoverCount > 0 {
                                metricChip(title: "Takeovers", value: "\(mission.takeoverCount)", color: mission.latestTakeoverState?.color ?? DesignSystem.Colors.blaze)
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 6) {
                        missionStatusBadge(title: mission.state.label, color: mission.state.color)
                        missionStatusBadge(title: mission.approval.label, color: mission.approval.color)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared Helpers

private func missionStatusBadge(title: String, color: Color) -> some View {
    Text(title)
        .font(DesignSystem.Typography.tiny)
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
}

private func detailSectionHeader(_ title: String) -> some View {
    Text(title)
        .font(DesignSystem.Typography.caption)
        .fontWeight(.semibold)
        .foregroundStyle(DesignSystem.Colors.textSecondary)
        .textCase(.uppercase)
}

private func factRow(icon: String, title: String, value: String, accent: Color? = nil) -> some View {
    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
        Image(systemName: icon)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(accent ?? DesignSystem.Colors.textSecondary)
            .frame(width: 16, alignment: .center)

        Text(title)
            .font(DesignSystem.Typography.tiny)
            .foregroundStyle(DesignSystem.Colors.textMuted)
            .frame(width: 80, alignment: .leading)

        Text(value)
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(accent ?? DesignSystem.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func metricChip(title: String, value: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(title)
            .font(DesignSystem.Typography.tiny)
            .foregroundStyle(DesignSystem.Colors.textMuted)
        Text(value)
            .font(DesignSystem.Typography.monoSmall)
            .foregroundStyle(color)
    }
    .padding(.horizontal, DesignSystem.Spacing.sm)
    .padding(.vertical, 6)
    .background(
        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
            .fill(DesignSystem.Colors.surfaceElevated.opacity(0.7))
    )
    .overlay(
        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
            .stroke(DesignSystem.Colors.border.opacity(0.3), lineWidth: 0.5)
    )
}
