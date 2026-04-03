import SwiftUI

// MARK: - Operating shared subviews

struct BurnBarStatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(DesignSystem.Typography.tiny)
            .foregroundStyle(color)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Operating view helpers

enum OperatingViewHelpers {
    static func sectionHeader(title: String) -> some View {
        Text(title)
            .font(DesignSystem.Typography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .textCase(.uppercase)
    }

    static func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Text(title)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
            Text(value)
                .font(DesignSystem.Typography.monoSmall)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
    }

    static func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Freshness Strip

struct BurnBarOperatingFreshnessStrip: View {
    let summary: BurnBarFreshnessSummary
    var compact: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(summary.status.color)
                .frame(width: compact ? 6 : 8, height: compact ? 6 : 8)

            Text(summary.headline)
                .font(compact ? DesignSystem.Typography.tiny : DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            if let updatedAt = summary.updatedAt {
                Text(OperatingViewHelpers.relativeTime(from: updatedAt))
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
            }

            Spacer()

            if !compact, let reason = summary.reasons.first?.nonEmpty {
                Text(reason)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Mission Summary Card

struct BurnBarMissionSummaryCard: View {
    let summary: BurnBarMissionSummary

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .top) {
                    OperatingViewHelpers.sectionHeader(title: "Mission")
                    Spacer()
                    BurnBarStatusBadge(title: summary.state.label, color: summary.state.color)
                }

                Text(summary.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)

                Text(summary.subtitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(3)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    BurnBarStatusBadge(title: summary.approval.label, color: summary.approval.color)
                    if let note = summary.approvalNote?.nonEmpty {
                        Text(note)
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                            .lineLimit(1)
                    }
                }

                Divider().background(DesignSystem.Colors.border)

                HStack(spacing: DesignSystem.Spacing.lg) {
                    OperatingViewHelpers.metric(title: "Sessions", value: "\(summary.sessionCount)")
                    OperatingViewHelpers.metric(title: "Burn", value: summary.estimatedCostUSD.formatAsCost())
                    OperatingViewHelpers.metric(title: "Tokens", value: summary.totalTokens.formatAsTokenVolume())
                }

                Text(summary.recommendationSummary)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - Direction Summary Card

struct BurnBarDirectionSummaryCard: View {
    let summary: BurnBarDirectionSummary

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .top) {
                    OperatingViewHelpers.sectionHeader(title: "Direction")
                    Spacer()
                    BurnBarStatusBadge(title: summary.status.label, color: summary.status.color)
                }

                Text(summary.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)

                Text(summary.summary)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(4)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    BurnBarStatusBadge(title: summary.mode.label, color: badgeColor(for: summary.mode))
                    BurnBarStatusBadge(title: summary.freshness.label, color: summary.freshness.color)
                }

                if let sparseReason = summary.sparseReason?.nonEmpty {
                    Text(sparseReason)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if summary.nextActions.isEmpty == false {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Next")
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                            .textCase(.uppercase)
                        ForEach(summary.nextActions.prefix(2), id: \.self) { action in
                            Text("• \(action)")
                                .font(DesignSystem.Typography.tiny)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func badgeColor(for mode: BurnBarDirectionMode) -> Color {
        switch mode {
        case .inferred: return DesignSystem.Colors.blaze
        case .sparse: return DesignSystem.Colors.textSecondary
        case .overrideAnnotating, .overrideSuperseding: return DesignSystem.Colors.whimsy
        }
    }
}

// MARK: - Burn Summary Card

struct BurnBarBurnSummaryCard: View {
    let summary: BurnBarBurnSummary

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                OperatingViewHelpers.sectionHeader(title: "Burn")

                Text(summary.estimatedCostUSD.formatAsCost())
                    .font(DesignSystem.Typography.monoLarge)
                    .foregroundStyle(DesignSystem.Colors.primaryGradient)

                Text(summary.windowLabel)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                HStack(spacing: DesignSystem.Spacing.lg) {
                    OperatingViewHelpers.metric(title: "Sessions", value: "\(summary.sessionCount)")
                    OperatingViewHelpers.metric(title: "Tokens", value: summary.totalTokens.formatAsTokenVolume())
                }

                if let latestSource = summary.latestSource?.nonEmpty {
                    Text("Latest source: \(latestSource)")
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                if let dominantModel = summary.dominantModel?.nonEmpty {
                    Text("Dominant model: \(dominantModel)")
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .lineLimit(1)
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .frame(width: 250, alignment: .topLeading)
    }
}

// MARK: - Evidence Panel

struct BurnBarEvidencePanel: View {
    let summary: BurnBarEvidenceSummary

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    OperatingViewHelpers.sectionHeader(title: "Evidence")
                    Spacer()
                    BurnBarStatusBadge(title: summary.freshness.label, color: summary.freshness.color)
                }

                Text(summary.summary)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let sparseReason = summary.sparseReason?.nonEmpty {
                    Text(sparseReason)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.amber)
                }

                if summary.entries.isEmpty == false {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(summary.entries) { entry in
                            BurnBarEvidenceEntryRow(entry: entry)
                        }
                    }
                }

                if summary.support.isEmpty == false || summary.contradictions.isEmpty == false {
                    Divider().background(DesignSystem.Colors.border)

                    HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
                        if summary.support.isEmpty == false {
                            judgmentColumn(title: "Support", color: DesignSystem.Colors.success, entries: summary.support)
                        }
                        if summary.contradictions.isEmpty == false {
                            judgmentColumn(title: "Contradictions", color: DesignSystem.Colors.warning, entries: summary.contradictions)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }

    private func judgmentColumn(
        title: String,
        color: Color,
        entries: [BurnBarEvidenceJudgment]
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(color)
                .textCase(.uppercase)
            ForEach(entries.prefix(2)) { entry in
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(entry.summary)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(entry.detail)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - Evidence Entry Row

struct BurnBarEvidenceEntryRow: View {
    let entry: BurnBarEvidenceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(entry.sourceLabel)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(entry.summary)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                }

                Spacer()

                BurnBarStatusBadge(title: entry.freshness.label, color: entry.freshness.color)
            }

            Text(entry.detail)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(entry.includedReason)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                .stroke(DesignSystem.Colors.border.opacity(0.45), lineWidth: 0.5)
        )
    }
}

// MARK: - Controller Compact Summary

struct BurnBarControllerCompactSummary: View {
    let runtime: BurnBarControllerRuntimeSnapshot
    var compact: Bool = false

    var body: some View {
        let mission = runtime.missions.first

        HStack(spacing: compact ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md) {
            compactPill(
                title: "Questions",
                value: "\(runtime.pendingQuestions.count)",
                color: DesignSystem.Colors.amber
            )
            compactPill(
                title: "Followups",
                value: "\(runtime.openFollowups.count)",
                color: DesignSystem.Colors.whimsy
            )
            if let mission {
                compactPill(
                    title: "Mission",
                    value: mission.state.label,
                    color: mission.state.color
                )
            }
            compactPill(
                title: mission?.latestTakeoverState == nil ? "Runtime" : "Takeover",
                value: mission?.latestTakeoverState?.label ?? runtime.source.label,
                color: mission?.latestTakeoverState?.color ?? DesignSystem.Colors.blaze
            )
            Spacer(minLength: 0)
        }
    }

    private func compactPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Text(title)
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
            Text(value)
                .font(compact ? DesignSystem.Typography.tiny : DesignSystem.Typography.caption)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}

// MARK: - Operating History Panel

struct BurnBarOperatingHistoryPanel: View {
    let entries: [BurnBarOperatingHistoryEntry]

    @ViewBuilder
    var body: some View {
        if !entries.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        OperatingViewHelpers.sectionHeader(title: "Governance")
                        Spacer()
                        Text("Local history")
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                    }

                    ForEach(entries.prefix(4)) { entry in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: entry.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(entry.tint)
                                .frame(width: 18, alignment: .top)

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                                HStack {
                                    Text(entry.title)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    Spacer()
                                    Text(OperatingViewHelpers.relativeTime(from: entry.createdAt))
                                        .font(DesignSystem.Typography.tiny)
                                        .foregroundStyle(DesignSystem.Colors.textMuted)
                                }

                                Text(entry.summary)
                                    .font(DesignSystem.Typography.tiny)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                if let detail = entry.detail?.nonEmpty {
                                    Text(detail)
                                        .font(DesignSystem.Typography.tiny)
                                        .foregroundStyle(DesignSystem.Colors.textMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
        }
    }
}
