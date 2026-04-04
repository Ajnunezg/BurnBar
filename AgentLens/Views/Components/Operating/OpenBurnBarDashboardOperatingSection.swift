import SwiftUI

// MARK: - Dashboard Operating Section

struct OpenBurnBarDashboardOperatingSection: View {
    @Bindable var layer: OpenBurnBarOperatingLayer

    var body: some View {
        let snapshot = layer.snapshot

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            OpenBurnBarOperatingFreshnessStrip(summary: snapshot.freshness, compact: false)

            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                OpenBurnBarMissionSummaryCard(summary: snapshot.mission)
                OpenBurnBarDirectionSummaryCard(summary: snapshot.direction)
                OpenBurnBarBurnSummaryCard(summary: snapshot.burn)
            }

            OpenBurnBarEvidencePanel(summary: snapshot.evidence)
            OpenBurnBarOperatingActionBar(layer: layer, compact: false)
            OpenBurnBarControllerWorkbenchPanel(layer: layer, condensed: false)
            OpenBurnBarOperatingHistoryPanel(entries: snapshot.recentHistory)
        }
    }
}
