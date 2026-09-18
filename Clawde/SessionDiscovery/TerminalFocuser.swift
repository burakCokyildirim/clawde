import AppKit
import Darwin
import os

/// Focuses the appropriate app for a Claude session based on its source.
struct SessionFocuser {

    /// Focuses the session's host app — iTerm2 for terminal sessions,
    /// or the IDE app for Xcode/VS Code/JetBrains/Zed sessions.
    func focus(session: ClaudeSession) {
        switch session.source {
        case .terminal(let app):
            focusTerminal(session, app: app)
        case .xcode:
            activateApp(bundleId: "com.apple.dt.Xcode")
        case .vscode:
            activateApp(bundleId: "com.microsoft.VSCode")
        case .jetbrains:
            activateJetBrainsApp()
        
        case .zed:
            activateApp(bundleId: "dev.zed.Zed")
        case .claudeDesktop:
            focusClaudeDesktop(session)
        }
    }

    // MARK: - IDE Activation

    /// Activates an app by bundle identifier.
    private func activateApp(bundleId: String) {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleId
        ).first else {
            return
        }
        app.activate()
    }

    /// Activates the frontmost JetBrains IDE. Multiple JetBrains IDEs may be
    /// running (IntelliJ, PyCharm, WebStorm, etc.), so we find any that match
    /// the JetBrains bundle ID pattern.
    private func activateJetBrainsApp() {
        let jetbrainsApp = NSWorkspace.shared.runningApplications.first { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return bundleId.hasPrefix("com.jetbrains.")
        }
        jetbrainsApp?.activate()
    }

    // MARK: - Claude Desktop

    /// Opens the session itself in the Claude desktop app, or at least brings
    /// the app forward when the session cannot be matched.
    private func focusClaudeDesktop(_ session: ClaudeSession) {
        var store = ClaudeDesktopSessionStore()
        store.refresh(force: true)
        if let desktop = store.session(forCLISession: session.sessionId),
           let url = Self.claudeDesktopURL(forDesktopSession: desktop.sessionId) {
            NSWorkspace.shared.open(url)
            return
        }
        // Bridged by Remote Control. Should the app refuse the link, it still
        // comes forward.
        if let remote = session.remoteSessionId,
           let url = Self.claudeDesktopURL(forRemoteSession: remote) {
            NSWorkspace.shared.open(url)
        }
        activateApp(bundleId: ClaudeDesktopSessionStore.claudeDesktopBundleId)
    }

    /// The desktop app's link to a session it shows through Remote Control:
    /// `claude://claude.ai/code/session_…`. The app also routes the shorter
    /// `claude://code/session_…`, but holds that form behind a feature switch
    /// and drops it while the switch is off ("code session deep link gated off"
    /// in its log); the claude.ai form reaches the same handler without it.
    /// Anything but a `session_` ID is refused.
    static func claudeDesktopURL(forRemoteSession remoteSessionId: String) -> URL? {
        let prefix = "session_"
        let suffix = remoteSessionId.dropFirst(prefix.count)
        guard remoteSessionId.hasPrefix(prefix),
              (1...64).contains(suffix.count),
              suffix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "claude"
        components.host = "claude.ai"
        components.path = "/code/" + remoteSessionId
        return components.url
    }

    /// The desktop app's link to an existing Claude Code session. Its handler
    /// accepts only `local_` IDs, so anything else is refused, not passed along.
    static func claudeDesktopURL(forDesktopSession desktopSessionId: String) -> URL? {
        let prefix = "local_"
        let suffix = desktopSessionId.dropFirst(prefix.count)
        guard desktopSessionId.hasPrefix(prefix),
              (1...64).contains(suffix.count),
              suffix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "claude"
        components.host = "code"
        components.path = "/continue"
        components.queryItems = [URLQueryItem(name: "session", value: desktopSessionId)]
        return components.url
    }

    // MARK: - Terminal

    /// Known bundle identifiers for terminal applications.
    private static let terminalBundleIds: [String: String] = [
        "iTerm2": "com.googlecode.iterm2",
        "Terminal": "com.apple.Terminal",
        "Warp": "dev.warp.Warp-Stable",
        "Alacritty": "org.alacritty",
        "Kitty": "net.kovidgoyal.kitty",
        "WezTerm": "com.github.wez.wezterm",
        "Ghostty": "com.mitchellh.ghostty",
    ]

    private func focusTerminal(_ session: ClaudeSession, app: String) {
        // tmux sessions: select the pane/window then activate the terminal.
        // The tab's own device is tmux's here, not the session's, so the tab
        // match below would not find it either way.
        if let paneId = session.tmuxPaneId {
            focusTmuxPane(paneId: paneId, socket: session.tmuxSocket)
            // iTerm2: use AppleScript to focus the tab hosting tmux
            if app == "iTerm2", let sessionId = session.iTermSessionId {
                focusBySessionId(sessionId)
            } else {
                activateTerminalApp(name: app)
            }
            return
        }

        // iTerm2 supports focusing a specific session via AppleScript
        if app == "iTerm2" {
            if let sessionId = session.iTermSessionId {
                focusBySessionId(sessionId)
                return
            }
            openITermTab(at: session.workingDirectory)
            return
        }

        // Ghostty supports focusing a specific terminal via AppleScript
        if app == "Ghostty" {
            focusGhosttyTerminal(workingDirectory: session.workingDirectory)
            return
        }

        // Terminal.app keeps no session id, but every tab knows the device it
        // is attached to, and so does the process.
        if app == "Terminal", let tty = Self.controllingTTY(for: session.pid) {
            focusTerminalAppTab(tty: tty)
            return
        }

        // For other terminals, just activate the app
        activateTerminalApp(name: app)
    }

    // MARK: - Terminal.app

    /// The terminal device a process is attached to, spelled the way
    /// Terminal.app spells a tab's `tty`: `/dev/ttysNNN`.
    ///
    /// Nil when the process has no controlling terminal, which is every session
    /// the Claude desktop app runs, and every one started by a script.
    static func controllingTTY(for pid: pid_t) -> String? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        // NODEV comes back as every bit set in this unsigned field.
        guard info.e_tdev != UInt32.max, info.e_tdev != 0 else { return nil }
        guard let name = devname(dev_t(info.e_tdev), S_IFCHR) else { return nil }
        return "/dev/" + String(cString: name)
    }

    /// Raises the Terminal.app tab attached to `tty`, window and all.
    ///
    /// Without this the app is only activated, and comes forward on whichever
    /// window was last in front — which, with a second window open, looks
    /// exactly like the click did nothing. Matching the device gives Terminal
    /// what iTerm2 gets from its session id.
    private func focusTerminalAppTab(tty: String) {
        // Falls back to activating the app for every way this can fail — a path
        // we would not write, a refused Apple Event, a tab that has been closed
        // — so the click never does nothing at all, which is what it did before
        // Terminal had a tab to aim at.
        guard let script = Self.terminalTabScript(tty: tty), runAppleScript(script) else {
            activateTerminalApp(name: "Terminal")
            return
        }
    }

    /// A device path as `devname` writes one, and nothing that could close a
    /// string literal and carry on as AppleScript.
    private static let safeTTYPattern = try! NSRegularExpression(pattern: #"^/dev/[A-Za-z0-9]+$"#)

    /// The script that raises `tty`'s tab, or nil if the path is not one we wrote.
    ///
    /// It activates even when no tab matches: a session whose tab has been closed
    /// while the process lives on should still bring the app forward, as it did
    /// before any of this.
    static func terminalTabScript(tty: String) -> String? {
        let range = NSRange(tty.startIndex..., in: tty)
        guard safeTTYPattern.firstMatch(in: tty, range: range) != nil else { return nil }
        return """
        tell application "Terminal"
            repeat with aWindow in windows
                repeat with aTab in tabs of aWindow
                    if tty of aTab is "\(tty)" then
                        set selected of aTab to true
                        set index of aWindow to 1
                        activate
                        return
                    end if
                end repeat
            end repeat
            activate
        end tell
        """
    }

    /// Activates a terminal app by bundle ID, falling back to name matching.
    private func activateTerminalApp(name: String) {
        if let bundleId = Self.terminalBundleIds[name] {
            activateApp(bundleId: bundleId)
        } else {
            let match = NSWorkspace.shared.runningApplications.first { runningApp in
                runningApp.localizedName?.contains(name) == true
            }
            match?.activate()
        }
    }

    /// Selects the target tmux pane and its window so it's visible when
    /// the terminal app comes to front. Unzooms first if another pane is zoomed.
    /// Resolves the tmux binary path, checking common Homebrew and MacPorts
    /// locations before falling back to PATH lookup via /usr/bin/env.
    private static let tmuxPath: String = {
        for candidate in ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/opt/local/bin/tmux"] {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return "/usr/bin/env"
    }()

    private func focusTmuxPane(paneId: String, socket: String?) {
        var baseArgs = [String]()
        if let socket {
            baseArgs += ["-S", socket]
        }
        let tmuxBin = Self.tmuxPath
        let usesEnv = tmuxBin == "/usr/bin/env"

        // Select the window containing the target pane
        let selectWindow = Process()
        selectWindow.executableURL = URL(fileURLWithPath: tmuxBin)
        selectWindow.arguments = (usesEnv ? ["tmux"] : []) + baseArgs + ["select-window", "-t", paneId]
        try? selectWindow.run()
        selectWindow.waitUntilExit()

        // Unzoom the current window if zoomed (resize-pane -Z toggles zoom;
        // check window_zoomed_flag first to avoid accidentally zooming in)
        let checkZoom = Process()
        let pipe = Pipe()
        checkZoom.executableURL = URL(fileURLWithPath: tmuxBin)
        checkZoom.arguments = (usesEnv ? ["tmux"] : []) + baseArgs + [
            "display-message", "-p", "#{window_zoomed_flag}"
        ]
        checkZoom.standardOutput = pipe
        try? checkZoom.run()
        checkZoom.waitUntilExit()
        let zoomFlag = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        if zoomFlag == "1" {
            let unzoom = Process()
            unzoom.executableURL = URL(fileURLWithPath: tmuxBin)
            unzoom.arguments = (usesEnv ? ["tmux"] : []) + baseArgs + ["resize-pane", "-Z"]
            try? unzoom.run()
            unzoom.waitUntilExit()
        }

        // Select the target pane
        let selectPane = Process()
        selectPane.executableURL = URL(fileURLWithPath: tmuxBin)
        selectPane.arguments = (usesEnv ? ["tmux"] : []) + baseArgs + ["select-pane", "-t", paneId]
        try? selectPane.run()
        selectPane.waitUntilExit()
    }

    /// Validates that a string contains only alphanumeric characters and hyphens (safe for AppleScript interpolation).
    private static let safeIdPattern = try! NSRegularExpression(pattern: #"^[A-Za-z0-9\-]+$"#)

    private func focusBySessionId(_ sessionId: String) {
        // ITERM_SESSION_ID format is "w0t0p0:UUID" — extract the UUID portion
        // which matches iTerm2's AppleScript `unique ID` property.
        let uniqueId: String
        if let colonIndex = sessionId.firstIndex(of: ":") {
            uniqueId = String(sessionId[sessionId.index(after: colonIndex)...])
        } else {
            uniqueId = sessionId
        }
        // Validate to prevent AppleScript injection
        let range = NSRange(uniqueId.startIndex..., in: uniqueId)
        guard Self.safeIdPattern.firstMatch(in: uniqueId, range: range) != nil else {
            return
        }

        // Select the correct tab/window BEFORE activating so iTerm raises
        // the right window to front (not whichever was last active).
        // Note: `select aTab` works at top scope but window selection requires
        // a `tell aWindow` block to properly raise the window.
        let script = """
        tell application "iTerm2"
            repeat with aWindow in windows
                repeat with aTab in tabs of aWindow
                    repeat with aSession in sessions of aTab
                        if unique ID of aSession is "\(uniqueId)" then
                            select aTab
                            tell aWindow
                                select
                            end tell
                            activate
                            return
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    /// Escapes a string for safe interpolation into AppleScript string literals.
    private func appleScriptEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - Ghostty

    /// Finds a Ghostty terminal whose working directory matches the session's
    /// and focuses it, bringing the containing window to front.
    ///
    /// Both paths are normalized via alias resolution before comparison so that
    /// symlink paths (e.g. ~/Source/…) and mount paths (e.g. /Volumes/…) that
    /// refer to the same directory still match correctly.
    private func focusGhosttyTerminal(workingDirectory: String) {
        let escapedDir = appleScriptEscape(workingDirectory)
        let script = """
        tell application "Ghostty"
            set targetDir to "\(escapedDir)"
            try
                set normalTarget to POSIX path of ((POSIX file targetDir) as alias)
            on error
                set normalTarget to targetDir
            end try
            repeat with aWindow in windows
                repeat with t in every terminal of aWindow
                    set tDir to working directory of t
                    try
                        set normalTDir to POSIX path of ((POSIX file tDir) as alias)
                    on error
                        set normalTDir to tDir
                    end try
                    if normalTDir is normalTarget then
                        focus t
                        set index of aWindow to 1
                        activate
                        return
                    end if
                end repeat
            end repeat
            activate
        end tell
        """
        runAppleScript(script)
    }

    private func openITermTab(at directory: String) {
        let escapedDir = appleScriptEscape(directory)
        let script = """
        tell application "iTerm2"
            activate
            tell current window
                create tab with default profile
                tell current session
                    write text "cd \\\"\(escapedDir)\\\""
                end tell
            end tell
        end tell
        """
        runAppleScript(script)
    }

    /// Where a refused Apple Event goes, so a click that quietly does nothing
    /// can be explained. `errAEEventNotPermitted` (-1743) means macOS has not
    /// been asked, or has been told no, under Privacy & Security ▸ Automation.
    private static let log = Logger(subsystem: "com.burakcokyildirim.clawde", category: "focus")

    /// Runs `source`, and says whether it got through.
    ///
    /// Apple Events are refused with `errAEEventNotPermitted` (-1743) until the
    /// user allows this app to control the other under Privacy & Security ▸
    /// Automation, and a caller that swallows that leaves a click doing nothing
    /// with nothing to show for it.
    @discardableResult
    private func runAppleScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else {
            Self.log.error("could not compile the script")
            return false
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        guard let error else { return true }
        let number = error[NSAppleScript.errorNumber] as? Int ?? 0
        let message = error[NSAppleScript.errorMessage] as? String ?? "\(error)"
        Self.log.error("apple event refused (\(number)): \(message, privacy: .public)")
        return false
    }
}
