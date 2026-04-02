import SwiftUI

// MARK: - Operating Action Bar

struct BurnBarActionButton: View {
    let title: String
    let icon: String
    let compact: Bool
    let enabled: Bool
    let emphasized: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 10 : 12, weight: .semibold))
                Text(title)
                    .font(compact ? DesignSystem.Typography.tiny : DesignSystem.Typography.caption)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, compact ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md)
            .padding(.vertical, compact ? DesignSystem.Spacing.xs + 2 : DesignSystem.Spacing.sm)
            .background(backgroundShape)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var foregroundColor: Color {
        guard enabled else { return DesignSystem.Colors.textMuted }
        return emphasized ? DesignSystem.Colors.blaze : DesignSystem.Colors.textPrimary
    }

    @ViewBuilder
    private var backgroundShape: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .fill((enabled ? DesignSystem.Colors.surfaceElevated : DesignSystem.Colors.surface).opacity(emphasized ? 0.7 : 0.45))
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(enabled ? DesignSystem.Colors.blaze.opacity(0.25) : DesignSystem.Colors.border.opacity(0.25), lineWidth: 0.6)
        }
    }
}

struct BurnBarDirectionOverrideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var layer: BurnBarOperatingLayer

    @State private var mode: BurnBarDirectionOverrideModeKind = .supersedeStatus
    @State private var forcedStatus: BurnBarDirectionAssessment = .aligned
    @State private var summary: String = ""
    @State private var rationale: String = ""

    var body: some View {
        let snapshot = layer.snapshot

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Direction Override")
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("Record an operator call for \(snapshot.projectName ?? "this project"). BurnBar will carry it across dashboard, popover, and Hermes.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Mode", selection: $mode) {
                ForEach(BurnBarDirectionOverrideModeKind.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if mode == .supersedeStatus {
                Picker("Status", selection: $forcedStatus) {
                    ForEach(BurnBarDirectionAssessment.allCases, id: \.self) { status in
                        Text(status.label).tag(status)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Summary")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                TextField("What should BurnBar carry forward?", text: $summary)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Rationale")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                TextEditor(text: $rationale)
                    .frame(minHeight: 120)
                    .padding(6)
                    .background(DesignSystem.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous)
                            .stroke(DesignSystem.Colors.border.opacity(0.55), lineWidth: 0.5)
                    )
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Spacer()

                Button("Save Override") {
                    layer.saveDirectionOverride(
                        mode: mode,
                        forcedStatus: mode == .supersedeStatus ? forcedStatus : nil,
                        summary: summary,
                        rationale: rationale
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.blaze)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(minWidth: 420, idealWidth: 460)
        .onAppear {
            if let projectName = snapshot.projectName {
                summary = snapshot.direction.overrideSummary?.nonEmpty
                    ?? "BurnBar should carry my latest call for \(projectName)."
            }
            rationale = snapshot.direction.sparseReason?.nonEmpty
                ?? snapshot.direction.summary
        }
    }
}

struct BurnBarOperatingActionBar: View {
    @Bindable var layer: BurnBarOperatingLayer
    var compact: Bool
    @State private var showingDirectionOverride = false

    var body: some View {
        let snapshot = layer.snapshot
        let missionAction = snapshot.availableActions.first(where: { $0.kind == .missionApproval })
        let directionAction = snapshot.availableActions.first(where: { $0.kind == .directionOverride })

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                BurnBarActionButton(
                    title: missionAction?.title ?? BurnBarActionKind.missionApproval.label,
                    icon: BurnBarActionKind.missionApproval.icon,
                    compact: compact,
                    enabled: missionAction?.available == true,
                    emphasized: missionAction?.available == true
                ) {
                    layer.approveMission()
                }

                BurnBarActionButton(
                    title: directionAction?.title ?? BurnBarActionKind.directionOverride.label,
                    icon: BurnBarActionKind.directionOverride.icon,
                    compact: compact,
                    enabled: directionAction?.available == true,
                    emphasized: directionAction?.available == true
                ) {
                    showingDirectionOverride = true
                }
            }

            if compact == false {
                if let missionReason = missionAction?.reason.nonEmpty {
                    Text(missionReason)
                        .font(DesignSystem.Typography.tiny)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            } else if let pending = snapshot.pendingHighlight?.nonEmpty {
                Text(pending)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }

            if let feedback = layer.actionFeedback {
                Text(feedback.detail?.nonEmpty ?? feedback.message)
                    .font(DesignSystem.Typography.tiny)
                    .foregroundStyle(feedback.tone.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(isPresented: $showingDirectionOverride) {
            BurnBarDirectionOverrideSheet(layer: layer)
                .presentationBackground(Material.ultraThinMaterial)
        }
    }
}
