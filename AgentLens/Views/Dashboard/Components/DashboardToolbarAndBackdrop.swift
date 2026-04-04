import AppKit
import SwiftUI
import WebKit
struct UsageModeToolbarPicker: View {
    @Binding var selection: UsageDisplayMode

    var body: some View {
        Menu {
            ForEach(UsageDisplayMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    HStack {
                        Text(mode.label)
                        if selection == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text(selection.label)
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
        .help("Show totals in USD or token volume")
    }
}

struct DashboardBackdrop: View {
    let moodBand: MoodBand

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            BracketSwarmBackground(moodBand: moodBand)
                .ignoresSafeArea()
                .opacity(0.68)
                .allowsHitTesting(false)

            RadialGradient(
                colors: [
                    DesignSystem.Colors.ember.opacity(0.09),
                    DesignSystem.Colors.amber.opacity(0.04),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: 520
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    DesignSystem.Colors.whimsy.opacity(0.06),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 80,
                endRadius: 560
            )
            .ignoresSafeArea()
        }
    }
}
