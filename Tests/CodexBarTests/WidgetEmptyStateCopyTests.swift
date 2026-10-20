import Foundation
import Testing
@testable import CodexBarCore
@testable import CodexBarWidget

struct WidgetEmptyStateCopyTests {
    private static let refresh = "Usage data will appear once the app refreshes."

    @Test
    func `widget configured for a disabled provider names it in the empty state`() {
        // Issue #4669: a new widget defaults to Codex; with Codex disabled the snapshot
        // only lists enabled providers, so the empty state must name Codex instead of
        // promising data "once the app refreshes".
        let snapshot = WidgetSnapshot(entries: [], enabledProviders: [.claude, .pi], generatedAt: Date())
        let message = WidgetEmptyStateCopy.message(provider: .codex, snapshot: snapshot, refresh: Self.refresh)
        #expect(message.contains("Codex"))
        #expect(message.contains("Edit the widget"))
        #expect(message != Self.refresh)
    }

    @Test
    func `enabled provider without data keeps the refresh message`() {
        // An enabled provider that simply has no entry yet keeps the refresh guidance.
        let snapshot = WidgetSnapshot(entries: [], enabledProviders: [.claude, .pi], generatedAt: Date())
        #expect(WidgetEmptyStateCopy.message(provider: .claude, snapshot: snapshot, refresh: Self.refresh) == Self
            .refresh)
    }

    @Test
    func `recorded empty enabled list keeps the refresh message`() {
        // A snapshot written while every provider was disabled carries an explicit empty
        // list, which is indistinguishable from an unrecorded one — the message stays
        // generic rather than claiming the configured provider is disabled.
        let snapshot = WidgetSnapshot(
            entries: [Self.entry(provider: .claude)],
            enabledProviders: [],
            generatedAt: Date())
        #expect(WidgetEmptyStateCopy.message(provider: .codex, snapshot: snapshot, refresh: Self.refresh) == Self
            .refresh)
    }

    @Test
    func `legacy snapshot without recorded enablement does not report disabled`() throws {
        let json = """
        {"version":1,"generatedAt":0,"entries":[],"usageBarsShowUsed":true}
        """
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(json.utf8))
        #expect(decoded.enabledProviders.isEmpty)
        #expect(WidgetEmptyStateCopy.message(provider: .codex, snapshot: decoded, refresh: Self.refresh) == Self
            .refresh)
    }

    @Test
    func `legacy inference treats providers without entries as disabled`() {
        // Snapshots predating enabledProviders infer it from entries; an enabled provider
        // that has not produced data yet reads as disabled until the next snapshot write.
        let snapshot = WidgetSnapshot(
            entries: [Self.entry(provider: .claude)],
            enabledProviders: nil,
            generatedAt: Date())
        #expect(snapshot.enabledProviders == [.claude])
        #expect(WidgetEmptyStateCopy.isProviderDisabled(provider: .codex, snapshot: snapshot))
    }

    @Test
    func `switcher disabled state points at the app instead of editing the widget`() {
        // The Switcher is statically configured and has no provider parameter to edit;
        // its recovery guidance must send the user to enable a provider in CodexBar.
        let snapshot = WidgetSnapshot(entries: [], enabledProviders: [.grok], generatedAt: Date())
        let message = WidgetEmptyStateCopy.switcherMessage(provider: .codex, snapshot: snapshot)
        #expect(!message.contains("Edit the widget"))
        #expect(message.contains("CodexBar"))
        #expect(message.contains("Provider"))
        #expect(message != W("Usage data appears after a refresh."))
    }

    @Test
    func `switcher keeps the refresh message when its provider is enabled`() {
        let snapshot = WidgetSnapshot(entries: [], enabledProviders: [.claude, .pi], generatedAt: Date())
        #expect(WidgetEmptyStateCopy.switcherMessage(provider: .claude, snapshot: snapshot) ==
            W("Usage data appears after a refresh."))
    }

    private static func entry(provider: UsageProvider) -> WidgetSnapshot.ProviderEntry {
        WidgetSnapshot.ProviderEntry(
            provider: provider,
            updatedAt: Date(),
            primary: nil,
            secondary: nil,
            tertiary: nil,
            usageRows: [],
            creditsRemaining: nil,
            codeReviewRemainingPercent: nil,
            tokenUsage: nil,
            dailyUsage: [])
    }
}
