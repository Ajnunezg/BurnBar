import SwiftUI

// MARK: - Dashboard Operating Section

struct BurnBarDashboardOperatingSection: View {
    @Bindable var layer: BurnBarOperatingLayer

    var body: some View {
        let snapshot = layer.snapshot

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            BurnBarOperatingFreshnessStrip(summary: snapshot.freshness, compact: false)

            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                BurnBarMissionSummaryCard(summary: snapshot.mission)
                BurnBarDirectionSummaryCard(summary: snapshot.direction)
                BurnBarBurnSummaryCard(summary: snapshot.burn)
            }

            BurnBarEvidencePanel(summary: snapshot.evidence)
            BurnBarOperatingActionBar(layer: layer, compact: false)
            BurnBarControllerWorkbenchPanel(layer: layer, condensed: false)
            BurnBarOperatingHistoryPanel(entries: snapshot.recentHistory)
        }
    }
}
