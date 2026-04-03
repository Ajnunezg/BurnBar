import SwiftUI

struct ProvidersSettingsView: View {
    @Bindable var settingsManager: SettingsManager
    @Bindable var daemonManager: BurnBarDaemonManager

    private var providers: [AgentProvider] {
        AgentProvider.allCases.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                SettingsSectionHeader(title: "Routed Providers")

                GlassCard {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Daemon routing")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Text("BurnBar's routed providers live behind the local daemon and are mirrored here from the daemon config.")
                                    .font(DesignSystem.Typography.tiny)
                                    .foregroundStyle(DesignSystem.Colors.textMuted)
                            }
                            Spacer()
                            Button("Refresh") {
                                Task { await daemonManager.refreshHealth() }
                            }
                            .buttonStyle(.bordered)
                        }

                        if daemonManager.providerConfigurations.isEmpty {
                            Text("No daemon provider configuration is available yet. Install or repair the daemon to manage routed providers.")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        } else {
                            ForEach(daemonManager.providerConfigurations) { configuration in
                                RoutedProviderRow(
                                    configuration: configuration,
                                    onToggle: { enabled in
                                        Task {
                                            await daemonManager.updateProviderConfiguration(
                                                providerID: configuration.providerID,
                                                isEnabled: enabled
                                            )
                                        }
                                    }
                                )

                                if configuration.id != daemonManager.providerConfigurations.last?.id {
                                    Divider().background(DesignSystem.Colors.border)
                                }
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }

                SettingsSectionHeader(title: "Observed Log Sources")

                GlassCard {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        ForEach(providers) { provider in
                            ProviderObservationRow(
                                provider: provider,
                                configuredPath: settingsManager.logPaths[provider] ?? provider.logDirectory,
                                isDetected: settingsManager.detectAvailableProviders()[provider] ?? false
                            )

                            if provider.id != providers.last?.id {
                                Divider().background(DesignSystem.Colors.border)
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Colors.background)
        .scrollContentBackground(.hidden)
    }
}

private struct RoutedProviderRow: View {
    let configuration: BurnBarDaemonProviderConfiguration
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ProviderLogoView(provider: configuration.provider, size: 20, useFallbackColor: false)

            VStack(alignment: .leading, spacing: 2) {
                Text(configuration.displayName)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(configuration.baseURL)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                if configuration.preferredModelIDs.isEmpty == false {
                    Text(configuration.preferredModelIDs.joined(separator: ", "))
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .lineLimit(2)
                }
            }

            Spacer()

            Toggle(
                "",
                isOn: Binding(
                    get: { configuration.isEnabled },
                    set: onToggle
                )
            )
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.blaze))
        }
    }
}

private struct ProviderObservationRow: View {
    let provider: AgentProvider
    let configuredPath: String
    let isDetected: Bool

    private var supportLabel: String {
        switch provider.supportLevel {
        case .supported: return "Supported"
        case .partial: return "Partial"
        case .unsupported: return "Not yet supported"
        }
    }

    private var supportColor: Color {
        switch provider.supportLevel {
        case .supported: return DesignSystem.Colors.success
        case .partial: return DesignSystem.Colors.warning
        case .unsupported: return DesignSystem.Colors.textMuted
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            ProviderLogoView(provider: provider, size: 20, useFallbackColor: false)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(provider.displayName)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(supportLabel)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(supportColor)
                }

                Text(configuredPath)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .textSelection(.enabled)

                Text(isDetected ? "Detected on this Mac" : "Not currently detected")
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(isDetected ? DesignSystem.Colors.success : DesignSystem.Colors.textMuted)
            }

            Spacer()
        }
    }
}
