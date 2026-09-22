import AppKit
import SwiftUI

/// The steps that install the plugin by hand, for someone the app cannot do it
/// for: Claude Code reached through the desktop app ships no `claude` binary, so
/// there is nothing for `PluginInstaller` to run.
///
/// The commands are built from the marketplace the app carries in its own bundle,
/// so what the window shows is the path that actually exists on this machine.
struct PluginSetup {

    /// Where the bundled marketplace sits, or nil if the app bundle is broken.
    let marketplacePath: String?

    init(installer: PluginInstaller = PluginInstaller()) {
        marketplacePath = installer.bundledMarketplacePath
    }

    /// Run in any Claude Code session — the desktop app's included.
    var commands: [(title: String, command: String)] {
        [
            (
                "Point Claude Code at the plugin Clawde carries",
                "/plugin marketplace add \(marketplacePath ?? "<Clawde.app>/Contents/Resources/clawde-plugin")"
            ),
            (
                "Install it",
                "/plugin install \(PluginInstaller.pluginKey)"
            ),
        ]
    }

    /// What it takes for a session to report, said the same way everywhere.
    ///
    /// The plugin's daemon is started by the SessionStart hook and by nothing
    /// else, so a session that was already running when the plugin arrived —
    /// or was updated — never gets one: `/reload-plugins` registers the hooks,
    /// but that session's start is long past. Only a session that starts again
    /// reports.
    static let restartAdvice = """

        Sessions that were already open will not report until they start again:
        \u{2022} Claude desktop app: quit it (\u{2318}Q) and open it again.
        \u{2022} Terminal: leave the session and pick it up with claude --resume.
        """
}

/// Walks through setting the plugin up by hand, and says what a session has to
/// do before its hooks run.
struct PluginSetupView: View {

    /// Shown when the app offered to do it and could not find the CLI.
    var noCLIFound: Bool = false
    var onInstallForMe: (() -> Void)?
    var onDone: () -> Void

    private let setup = PluginSetup()
    @State private var copied: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Set up the Clawde plugin")
                    .font(.system(size: 15, weight: .semibold))
                Text(lede)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(setup.commands.enumerated()), id: \.offset) { index, entry in
                    step(number: index + 1, title: entry.title, command: entry.command)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("3. Start the sessions again")
                    .font(.system(size: 12, weight: .medium))
                Text("A session only reports if it started after the plugin arrived — the one you "
                     + "ran these in included. In the Claude desktop app, quit it (\u{2318}Q) and "
                     + "open it again; in a terminal, leave the session and pick it up with "
                     + "claude --resume.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Reveal Plugin in Finder") {
                    guard let path = setup.marketplacePath else { return }
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                }
                if let onInstallForMe {
                    Button("Install for Me") { onInstallForMe() }
                }
                Spacer()
                Button("Done") { onDone() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private var lede: String {
        noCLIFound
            ? "Clawde installs the plugin with the claude command, and there is none on this Mac \u{2014}"
                + " the Claude desktop app has Claude Code built in and ships no CLI. Run these in any"
                + " Claude Code session instead, the desktop app's included."
            : "Run these in any Claude Code session — the desktop app's included — or let Clawde"
                + " install it for you from Settings."
    }

    @ViewBuilder
    private func step(number: Int, title: String, command: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(number). \(title)")
                .font(.system(size: 12, weight: .medium))
            HStack(spacing: 8) {
                Text(command)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06))
                    )
                Button(copied == number ? "Copied" : "Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    copied = number
                }
                .frame(width: 66)
            }
        }
    }
}
