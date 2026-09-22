import AppKit
import SwiftUI
import Testing
@testable import Clawde

/// The settings window is sized by what a screen can give it, not by what it has
/// to list. Sized to its content it grew past the bottom of the display once a
/// few profiles were there, with nothing to scroll.
@MainActor
struct SettingsWindowLayoutTests {

    /// A home with several profiles in it, which is what made the window overflow.
    private static func home(profiles: [String]) throws -> URL {
        let home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("clawde-settings-\(UUID().uuidString)")
        for name in profiles {
            try FileManager.default.createDirectory(
                at: home.appendingPathComponent(name).appendingPathComponent("projects"),
                withIntermediateDirectories: true
            )
        }
        return home
    }

    @Test func itAsksForNoMoreHeightThanTheWindowWillGive() throws {
        let home = try Self.home(profiles: [".claude", ".claude-work", ".claude-spike", ".claude-old"])
        defer { try? FileManager.default.removeItem(at: home) }
        let store = ProfileStore(defaults: nil, homeDirectory: home)
        #expect(store.profiles.count == 4)

        let host = NSHostingView(rootView: SettingsView(
            profileStore: store,
            updater: nil,
            onInstallPlugin: { _ in },
            onUninstallPlugin: { _ in }
        ))
        host.layoutSubtreeIfNeeded()
        let fits = host.fittingSize

        #expect(fits.width == 420)
        // The window opens at 620 points at most and the form scrolls inside it.
        #expect(fits.height <= 620)
    }
}
