import Foundation

struct CodexQuotaAdapter: ProviderQuotaAdapter {
    func fetch(context: ProviderQuotaAdapterContext) async throws -> ProviderQuotaSnapshot {
        let candidateDirectories = [
            context.homeDirectoryURL.appendingPathComponent(".codex/sessions", isDirectory: true),
            context.homeDirectoryURL.appendingPathComponent(".codex/archived_sessions", isDirectory: true),
        ]

        let freshnessCutoff = Date().addingTimeInterval(-CodexQuotaScanPolicy.freshnessWindow)
        let existingCache = context.codexRolloutScanCache
        let scanResult = try await Task.detached(priority: .utility) {
            try CodexRolloutScanner.scanCodexRateLimitEvents(
                in: candidateDirectories,
                freshnessCutoff: freshnessCutoff,
                existingCache: existingCache
            )
        }.value
        await context.updateCodexRolloutScanCache(scanResult.cache, scanResult.didChangeCache)

        if let event = scanResult.latestEvent {
            let normalizedWindows = normalizedCodexRateLimitWindows(
                primary: event.primary,
                secondary: event.secondary
            )
            var buckets: [ProviderQuotaBucket] = []
            if let primary = normalizedWindows.primary {
                buckets.append(
                    ProviderQuotaBucket(
                        key: "codex-primary",
                        label: codexBucketLabel(for: primary, fallback: "Primary quota"),
                        windowKind: codexWindowKind(for: primary),
                        usedValue: primary.usedPercent,
                        limitValue: 100,
                        remainingValue: max(0, 100 - (primary.usedPercent ?? 0)),
                        usedPercent: primary.usedPercent,
                        resetsAt: primary.resetsAt,
                        unit: .percent,
                        isEstimated: false
                    )
                )
            }
            if let secondary = normalizedWindows.secondary {
                buckets.append(
                    ProviderQuotaBucket(
                        key: "codex-secondary",
                        label: codexBucketLabel(for: secondary, fallback: "Secondary quota"),
                        windowKind: codexWindowKind(for: secondary),
                        usedValue: secondary.usedPercent,
                        limitValue: 100,
                        remainingValue: max(0, 100 - (secondary.usedPercent ?? 0)),
                        usedPercent: secondary.usedPercent,
                        resetsAt: secondary.resetsAt,
                        unit: .percent,
                        isEstimated: false
                    )
                )
            }

            if !buckets.isEmpty {
                let plan = event.planType?.capitalized ?? "Codex"
                return ProviderQuotaSnapshot(
                    provider: .codex,
                    fetchedAt: event.timestamp,
                    source: .localSession,
                    confidence: .exact,
                    managementURL: "https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan",
                    statusMessage: "\(plan) quota snapshot from the latest local Codex rollout log.",
                    buckets: buckets
                )
            }
        }

        return unavailableSnapshot(
            for: .codex,
            source: .unavailable,
            message: "No recent Codex rate-limit snapshot was found in local sessions. Run Codex and use /status to refresh local quota data."
        )
    }

    // MARK: - Codex Helpers

    enum CodexWindowRole {
        case session
        case weekly
        case unknown
    }

    private func normalizedCodexRateLimitWindows(
        primary: CodexRateLimitWindow?,
        secondary: CodexRateLimitWindow?
    ) -> (primary: CodexRateLimitWindow?, secondary: CodexRateLimitWindow?) {
        switch (primary, secondary) {
        case let (.some(primaryWindow), .some(secondaryWindow)):
            switch (codexWindowRole(for: primaryWindow), codexWindowRole(for: secondaryWindow)) {
            case (.session, .weekly), (.session, .unknown), (.unknown, .weekly):
                return (primaryWindow, secondaryWindow)
            case (.weekly, .session), (.weekly, .unknown):
                return (secondaryWindow, primaryWindow)
            default:
                return (primaryWindow, secondaryWindow)
            }
        case let (.some(primaryWindow), .none):
            switch codexWindowRole(for: primaryWindow) {
            case .weekly:
                return (nil, primaryWindow)
            case .session, .unknown:
                return (primaryWindow, nil)
            }
        case let (.none, .some(secondaryWindow)):
            switch codexWindowRole(for: secondaryWindow) {
            case .weekly:
                return (nil, secondaryWindow)
            case .session, .unknown:
                return (secondaryWindow, nil)
            }
        case (.none, .none):
            return (nil, nil)
        }
    }

    private func codexWindowRole(for window: CodexRateLimitWindow) -> CodexWindowRole {
        switch window.windowMinutes {
        case 300:
            return .session
        case 10_080:
            return .weekly
        default:
            return .unknown
        }
    }

    private func codexWindowKind(for window: CodexRateLimitWindow) -> ProviderQuotaWindowKind {
        switch codexWindowRole(for: window) {
        case .session:
            return .rollingHours
        case .weekly:
            return .rollingDays
        case .unknown:
            return .custom
        }
    }

    private func codexBucketLabel(for window: CodexRateLimitWindow, fallback: String) -> String {
        switch codexWindowRole(for: window) {
        case .session:
            return "5-hour window"
        case .weekly:
            return "7-day window"
        case .unknown:
            if let minutes = window.windowMinutes, minutes > 0 {
                if minutes % 60 == 0 {
                    return "\(minutes / 60)-hour window"
                }
                return "\(minutes)-minute window"
            }
            return fallback
        }
    }
}
