#if canImport(AppKit)
import AppKit
import Foundation
import SwiftUI
import Testing
@testable import CodexBarCore
@testable import CodexBarWidget

/// Renders the provider empty states to PNGs when `CODEXBAR_WIDGET_EMPTY_PROOF_DIR` is set so the
/// #4669 copy change can be verified visually; without the environment variable the test only
/// asserts that each view builds.
@MainActor
struct WidgetEmptyStateRenderProofTests {
    private static let size = CGSize(width: 360, height: 170)

    @Test
    func `disabled provider empty states render provider-specific guidance`() throws {
        let snapshot = WidgetSnapshot(entries: [], enabledProviders: [.claude, .pi], generatedAt: Date())

        let usage = CodexBarUsageWidgetView(
            entry: CodexBarWidgetEntry(date: snapshot.generatedAt, provider: .codex, snapshot: snapshot))
        let metric = CodexBarCompactWidgetView(
            entry: CodexBarCompactEntry(
                date: snapshot.generatedAt,
                provider: .codex,
                metric: .credits,
                snapshot: snapshot))
        // The statically configured Switcher resolves to Codex when no usage-selectable
        // provider is enabled; only burn-down-only providers are enabled here.
        let switcher = CodexBarSwitcherWidgetView(
            entry: CodexBarSwitcherEntry(
                date: snapshot.generatedAt,
                provider: .codex,
                availableProviders: [.codex],
                snapshot: WidgetSnapshot(
                    entries: [],
                    enabledProviders: [.grok],
                    generatedAt: snapshot.generatedAt)))
        let waiting = CodexBarUsageWidgetView(
            entry: CodexBarWidgetEntry(date: snapshot.generatedAt, provider: .claude, snapshot: snapshot))

        guard let path = ProcessInfo.processInfo.environment["CODEXBAR_WIDGET_EMPTY_PROOF_DIR"] else { return }
        let output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try Self.render(usage, named: "usage-codex-disabled", to: output)
        try Self.render(metric, named: "metric-codex-disabled", to: output)
        try Self.render(switcher, named: "switcher-grok-only", to: output)
        try Self.render(waiting, named: "usage-claude-awaiting-data", to: output)
    }

    private static func render(_ view: some View, named name: String, to output: URL) throws {
        let framed = view
            .environment(\.widgetRenderingMode, .fullColor)
            .environment(\.colorScheme, .light)
            .padding(14)
            .frame(width: self.size.width, height: self.size.height)
            .background(.background)
        let hosting = NSHostingView(rootView: framed)
        hosting.frame = NSRect(origin: .zero, size: self.size)
        hosting.appearance = NSAppearance(named: .aqua)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        try #require(bitmap.representation(using: .png, properties: [:]))
            .write(to: output.appendingPathComponent("\(name).png"))
    }
}
#endif
