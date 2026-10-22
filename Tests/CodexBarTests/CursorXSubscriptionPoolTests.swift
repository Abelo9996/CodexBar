import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

/// The X Subscription's shared weekly pool sits in Cursor's weekly lane, so the generic weekly consumers
/// (warnings, menu bar tokens, compact account rows) pick it up without Cursor special cases.
@MainActor
struct CursorXSubscriptionPoolTests {
    private static let now = Date(timeIntervalSince1970: 1_792_000_000)

    @MainActor
    private final class NotifierSpy: SessionQuotaNotifying {
        private(set) var quotaWarnings: [QuotaWarningEvent] = []

        func post(transition _: SessionQuotaTransition, provider _: UsageProvider, badge _: NSNumber?) {}

        func postQuotaWarning(
            event: QuotaWarningEvent,
            provider _: UsageProvider,
            soundEnabled _: Bool,
            onScreenAlertEnabled _: Bool)
        {
            self.quotaWarnings.append(event)
        }
    }

    private static func pool(usedPercent: Double) -> UsageSnapshot {
        UsageSnapshot(
            primary: nil,
            secondary: RateWindow(
                usedPercent: usedPercent,
                windowMinutes: 10080,
                resetsAt: self.now.addingTimeInterval(86400),
                resetDescription: nil),
            updatedAt: self.now)
    }

    @Test
    func `pool crossings use the weekly warning lane`() {
        let settings = testSettingsStore(suiteName: "CursorXSubscriptionPoolTests-warnings")
        settings.refreshFrequency = .manual
        settings.statusChecksEnabled = false
        settings.quotaWarningNotificationsEnabled = true
        settings.quotaWarningThresholds = [50]
        settings.setQuotaWarningWindowEnabled(.session, enabled: false)
        settings.setQuotaWarningWindowEnabled(.weekly, enabled: true)
        settings.sessionQuotaNotificationsEnabled = false
        settings.predictivePaceWarningNotificationsEnabled = false
        let notifier = NotifierSpy()
        let store = UsageStore(
            fetcher: UsageFetcher(),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings,
            sessionQuotaNotifier: notifier,
            startupBehavior: .testing)

        store.handleQuotaWarningTransitions(provider: .cursor, snapshot: Self.pool(usedPercent: 40))
        store.handleQuotaWarningTransitions(provider: .cursor, snapshot: Self.pool(usedPercent: 55))

        #expect(notifier.quotaWarnings.map(\.window) == [.weekly])
        #expect(notifier.quotaWarnings.map(\.threshold) == [50])
    }

    @Test
    func `pool card bar uses weekly warning markers and label`() throws {
        let metadata = try #require(ProviderDefaults.metadata[.cursor])
        let model = UsageMenuCardView.Model.make(.init(
            provider: .cursor,
            metadata: metadata,
            snapshot: Self.pool(usedPercent: 10),
            credits: nil,
            creditsError: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: false,
            hidePersonalInfo: false,
            quotaWarningThresholds: [.session: [80], .weekly: [50]],
            now: Self.now))

        #expect(model.metrics.map(\.title) == ["Weekly"])
        #expect(model.metrics.first?.warningMarkerPercents == [50])
    }

    @Test
    func `menu bar tokens resolve the pool under its weekly label`() {
        let settings = testSettingsStore(suiteName: "CursorXSubscriptionPoolTests-tokens")
        settings.refreshFrequency = .manual
        settings.statusChecksEnabled = false
        let store = UsageStore(
            fetcher: UsageFetcher(),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings,
            startupBehavior: .testing)
        let snapshot = Self.pool(usedPercent: 10)
        let data = store.menuBarLayoutRenderData(
            provider: .cursor,
            snapshot: snapshot,
            iconKey: "cursor",
            accountLabel: nil,
            costs: MenuBarLayoutCostValues(today: nil, last30Days: nil, todayUSD: nil, last30DaysUSD: nil),
            now: Self.now)
        let output = MenuBarLayoutRenderer().render(
            layout: MenuBarLayout(lines: [[.percent(window: .weekly), .extraPercent(id: "cursor-grok-bot")]]),
            data: data,
            icon: nil,
            options: MenuBarLayoutRenderOptions(
                size: .regular,
                highContrast: false,
                showUsed: false,
                conditionals: [],
                appearanceName: "aqua",
                isDebugApp: false,
                now: Self.now))

        #expect(output.attributedTitle.string == "W 90%\u{2009}GB 90%")
        #expect(output.accessibilityLabel == "Weekly 90%, Grok Bot 90%")
        #expect(MenuBarPercentWindowPreference.weekly.label(for: .cursor, snapshot: snapshot) == "Weekly")
    }

    @Test
    func `compact account rows label the pool weekly`() throws {
        let accounts = (1...4).map { (slot: Int) -> ProviderAccountUsageSnapshot in
            ProviderAccountUsageSnapshot(
                id: ProviderAccountIdentity(source: "cursor", opaqueID: String(slot)),
                provider: .cursor,
                displayLabel: "account-\(slot)",
                isActive: slot == 1,
                canActivate: true,
                snapshot: Self.pool(usedPercent: slot == 2 ? 95 : 10),
                error: nil,
                sourceLabel: "cursor")
        }
        let plan = AccountMenuLayoutPlanner.plan(accounts: accounts)
        let compactRows = plan.rows.compactMap { row -> AccountMenuLayoutPlanner.CompactRow? in
            if case let .compact(compact) = row { return compact }
            return nil
        }
        let constrained = try #require(compactRows.first)

        #expect(constrained.label == "account-2")
        #expect(constrained.windowDetails.map(\.label) == ["Weekly"])
    }
}
