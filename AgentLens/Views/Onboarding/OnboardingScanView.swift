import SwiftUI

struct OnboardingScanView: View {
    let selectedProviders: Set<AgentProvider>
    var aggregator: UsageAggregator?

    @State private var scanStarted = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Scanning logs")
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("OpenBurnBar is reading your agent logs and building a local operating picture \u{2014} spend, sessions, and project context.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    ForEach(selectedProviders.sorted { $0.displayName < $1.displayName }) { provider in
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            parserHealthIcon(for: provider)

                            Image(systemName: provider.iconName)
                                .font(.system(size: 12))
                                .foregroundStyle(DesignSystem.Colors.primary(for: provider))
                                .frame(width: 16)

                            Text(provider.displayName)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)

                            Spacer()

                            parserHealthDetail(for: provider)
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .background {
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                                .fill(DesignSystem.Colors.surface)
                        }
                    }
                }
            }

            if aggregator?.isRefreshing == true {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Parsing session data\u{2026}")
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
            }
        }
        .onAppear {
            guard !scanStarted else { return }
            scanStarted = true
            Task { await aggregator?.refreshAll() }
        }
    }

    @ViewBuilder
    private func parserHealthIcon(for provider: AgentProvider) -> some View {
        let health = aggregator?.parserHealth[provider]
        switch health {
        case .healthy:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.success)
        case .degraded:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.warning)
        case .empty:
            Image(systemName: "minus.circle")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.textMuted)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.error)
        case .notConfigured, .none:
            ProgressView()
                .controlSize(.mini)
                .frame(width: 12, height: 12)
        }
    }

    @ViewBuilder
    private func parserHealthDetail(for provider: AgentProvider) -> some View {
        let health = aggregator?.parserHealth[provider]
        switch health {
        case .healthy(let n):
            Text("\(n) session\(n == 1 ? "" : "s")")
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
        case .degraded(let n, _):
            Text("\(n) session\(n == 1 ? "" : "s") (partial)")
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.warning)
        case .empty:
            Text("No sessions")
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
        case .failed:
            Text("Failed")
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.error)
        case .notConfigured, .none:
            Text("Scanning\u{2026}")
                .font(DesignSystem.Typography.tiny)
                .foregroundStyle(DesignSystem.Colors.textMuted)
        }
    }
}
