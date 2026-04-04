import SwiftUI

// MARK: - Daemon Status Color

extension OpenBurnBarDaemonStatus {
    var color: Color {
        switch self {
        case .healthy: return DesignSystem.Colors.success
        case .checking: return DesignSystem.Colors.warning
        case .notInstalled: return DesignSystem.Colors.textMuted
        case .unhealthy: return DesignSystem.Colors.error
        }
    }
}

// MARK: - Setup Guide Cards

struct OpenBurnBarOperatingModelGuideCard: View {
    let guide: OpenBurnBarSetupGuideSnapshot
    var compact: Bool = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: compact ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md) {
                Text(compact ? guide.runtimeTitle : "How OpenBurnBar Works")
                    .font(compact ? DesignSystem.Typography.headline : DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(guide.headline)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                guideRow(title: guide.localTitle, detail: guide.localDetail, icon: "macwindow")
                guideRow(title: guide.cloudTitle, detail: guide.cloudDetail, icon: "cloud")
                guideRow(title: guide.runtimeTitle, detail: guide.runtimeDetail, icon: "waveform.path.ecg")
                guideRow(title: guide.providerHealthTitle, detail: guide.providerHealthDetail, icon: "checkmark.shield")
            }
            .padding(compact ? DesignSystem.Spacing.md : DesignSystem.Spacing.lg)
        }
    }

    private func guideRow(title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.amber)
                .frame(width: 18, alignment: .top)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(detail)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Controller Runtime Guide Card

struct OpenBurnBarControllerRuntimeGuideCard: View {
    let settingsManager: SettingsManager
    @Bindable var daemonManager: OpenBurnBarDaemonManager
    var compact: Bool = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: compact ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Controller Runtime")
                            .font(compact ? DesignSystem.Typography.headline : DesignSystem.Typography.title)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text("OpenBurnBar's review controller is local-first: the daemon owns live runtime state, while this app mirrors enough context to stay useful offline.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    OpenBurnBarStatusBadge(
                        title: daemonManager.status.label,
                        color: daemonManager.status.color
                    )
                }

                runtimeGuideRow(
                    title: settingsManager.controllerLocalNotificationsEnabled ? "Notifications on" : "Notifications off",
                    detail: settingsManager.controllerLocalNotificationsEnabled
                        ? "Local nudges can fire even when the OpenBurnBar window is closed."
                        : "OpenBurnBar will stay quiet until you opt into local nudges.",
                    icon: "bell.badge"
                )
                runtimeGuideRow(
                    title: settingsManager.controllerTelegramEnabled ? "Telegram armed" : "Telegram optional",
                    detail: settingsManager.controllerTelegramEnabled
                        ? "Use Telegram for pending, followups, answer, snooze, and status commands once the daemon is configured."
                        : "Leave Telegram off if you want OpenBurnBar to stay on-device only.",
                    icon: "paperplane"
                )
                runtimeGuideRow(
                    title: settingsManager.controllerCalendarIntegrationEnabled ? "Calendar holds ready" : "Calendar stays manual",
                    detail: settingsManager.controllerCalendarIntegrationEnabled
                        ? "Open followups can drop local calendar placeholders without exposing transcripts."
                        : "OpenBurnBar will keep followups in-app until you opt into calendar holds.",
                    icon: "calendar.badge.plus"
                )
                runtimeGuideRow(
                    title: settingsManager.controllerSimulatorToolsEnabled ? "Replay visible" : "Replay hidden",
                    detail: settingsManager.controllerSimulatorToolsEnabled
                        ? "Simulator and replay affordances stay visible for operator testing."
                        : "Replay tooling is hidden from the main product flow until you need it.",
                    icon: "play.square.stack"
                )
            }
            .padding(compact ? DesignSystem.Spacing.md : DesignSystem.Spacing.lg)
        }
    }

    private func runtimeGuideRow(title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.teal)
                .frame(width: 18, alignment: .top)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(detail)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
