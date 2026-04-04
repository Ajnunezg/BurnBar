import AppKit
import SwiftUI
import WebKit
struct StatCard: View {
    let title: String
    let value: String
    let accent: Color
    let detail: String
    var moodLabel: String?
    var moodColor: Color?
    var confidenceLabel: String?
    var confidenceColor: Color?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(title)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .textCase(.uppercase)

                Text(value)
                    .font(DesignSystem.Typography.monoLarge)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .contentTransition(.numericText())
                    .animation(DesignSystem.Animation.gentle, value: value)

                if let moodLabel, let moodColor {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Circle()
                            .fill(moodColor)
                            .frame(width: 6, height: 6)
                        Text(moodLabel)
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(moodColor)
                    }
                }

                Text(detail)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                if let confidenceLabel, let confidenceColor {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Circle()
                            .fill(confidenceColor)
                            .frame(width: 4, height: 4)
                        Text(confidenceLabel)
                            .font(DesignSystem.Typography.tiny)
                            .foregroundStyle(confidenceColor)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(confidenceColor.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(confidenceColor.opacity(0.12), lineWidth: 0.5)
                    )
                    .clipShape(.capsule)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.lg)
        }
    }
}

// MARK: - Glass Picker

struct GlassPicker<Option: Identifiable & Hashable>: View {
    @Binding var selection: Option
    let options: [Option]

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    HStack {
                        Text(optionLabel(option))
                        if optionLabel(option) == selectionLabel(selection) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text(selectionLabel(selection))
                    .font(DesignSystem.Typography.caption)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                        .fill(DesignSystem.Colors.surface.opacity(0.5))
                }
            }
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .clipShape(.rect(cornerRadius: DesignSystem.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), DesignSystem.Colors.border.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .menuStyle(.borderlessButton)
    }

    private func selectionLabel(_ option: Option) -> String {
        if let tr = option as? TimeRange { return tr.displayName }
        return "\(option)"
    }

    private func optionLabel(_ option: Option) -> String {
        if let tr = option as? TimeRange { return tr.displayName }
        return "\(option)"
    }
}

// MARK: - Glass Badge

struct GlassBadge<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                        .fill(DesignSystem.Colors.surfaceElevated.opacity(0.5))
                }
            }
            .clipShape(.rect(cornerRadius: DesignSystem.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), DesignSystem.Colors.border.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

#Preview {
    let store = (try? DataStore()) ?? {
        preconditionFailure("Preview requires a valid DataStore - ensure app support directory is writable")
    }()
    let controller = ChatSessionController(dataStore: store)
    DashboardView(
        dataStore: store,
        aggregator: nil,
        chatController: controller,
        operatingLayer: OpenBurnBarOperatingLayer(dataStore: store, chatController: controller)
    )
}

struct SessionPreviewRow: View {
    let usage: TokenUsage
    @Bindable var settingsManager: SettingsManager

    private var theme: ProviderTheme { .theme(for: usage.provider) }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(usage.projectName)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)

                Text("\(usage.provider.displayName) • \(usage.model)")
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formatTime(usage.startTime))
                    .font(DesignSystem.Typography.monoTiny)
                    .foregroundStyle(theme.primaryColor)

                Text(settingsManager.formatUsageMetric(cost: usage.cost, tokens: usage.totalTokens))
                    .font(DesignSystem.Typography.monoSmall)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .contentTransition(.numericText())
                    .animation(DesignSystem.Animation.gentle, value: usage.id)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .fill(DesignSystem.Colors.surfaceElevated.opacity(0.4))
            }
        }
        .clipShape(.rect(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), DesignSystem.Colors.border.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Summarizing Status Strip

// MARK: - Mining Pick Animation

/// Renders the animated_mining_pick.svg using WKWebView so CSS @keyframes play natively.
