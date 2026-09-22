import Foundation

/// Installs the bundled Clawde plugin using the Claude Code CLI.
///
/// The app bundles a complete plugin marketplace in its Resources directory.
/// Installation runs two CLI commands:
/// 1. `claude plugin marketplace add <path>` — registers the bundled marketplace
/// 2. `claude plugin install clawde@clawde-marketplace` — installs the plugin
///
/// Both commands run with `CLAUDE_CONFIG_DIR` pointing at the target profile,
/// so each profile gets its own installation.
struct PluginInstaller {

    static let marketplaceName = "clawde-marketplace"
    static let pluginKey = "clawde@clawde-marketplace"

    /// Path to the bundled marketplace inside the app bundle.
    var bundledMarketplacePath: String? {
        Bundle.main.resourceURL?
            .appendingPathComponent("clawde-plugin")
            .path
    }

    /// Version of the bundled plugin (read from the plugin's own plugin.json).
    var bundledPluginVersion: String? {
        guard let marketplacePath = bundledMarketplacePath else { return nil }
        let pluginJSON = URL(fileURLWithPath: marketplacePath)
            .appendingPathComponent("plugins/clawde/.claude-plugin/plugin.json")
        guard let data = try? Data(contentsOf: pluginJSON),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["version"] as? String else {
            return nil
        }
        return version
    }

    /// Resolves the `claude` CLI binary, or nil when there is none to run.
    ///
    /// An app launched from the Dock inherits launchd's PATH, not the shell's,
    /// so the usual places are checked first and the user's login shell is asked
    /// only if none of them has it. Someone who reaches Claude Code through the
    /// desktop app alone has no CLI at all — `PluginSetup` is the way in for them.
    var claudePath: String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".local/bin/claude").path,
            home.appendingPathComponent(".claude/local/claude").path,
            home.appendingPathComponent(".bun/bin/claude").path,
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/opt/local/bin/claude",
        ]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return found
        }
        return claudeFromLoginShell()
    }

    /// Asks the login shell where `claude` is, for an installation none of the
    /// usual paths covers — a version manager's shims, say.
    private func claudeFromLoginShell() -> String? {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-lc", "command -v claude"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let path = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }

    // MARK: - Install

    /// Installs the plugin into the given profile's config dir via the Claude CLI.
    /// Returns nil on success, or an error message.
    func install(configDir: URL) -> String? {
        guard let claude = claudePath else {
            return "Claude Code CLI not found. Install it first: https://docs.anthropic.com/en/docs/claude-code/overview"
        }

        guard let marketplacePath = bundledMarketplacePath else {
            return "Bundled marketplace not found in app resources"
        }

        // 1. Add the marketplace
        let addResult = runCLI(claude, arguments: [
            "plugin", "marketplace", "add", marketplacePath,
        ], configDir: configDir)
        if let error = addResult {
            // Ignore "already exists" errors
            if !error.contains("already") {
                return "Failed to add marketplace: \(error)"
            }
        }

        // 2. Install the plugin
        let installResult = runCLI(claude, arguments: [
            "plugin", "install", Self.pluginKey,
        ], configDir: configDir)
        if let error = installResult {
            // Ignore "already installed" errors
            if !error.contains("already") {
                return "Failed to install plugin: \(error)"
            }
        }

        return nil
    }

    // MARK: - Uninstall

    /// Uninstalls the plugin from the given profile's config dir via the Claude CLI.
    /// Returns nil on success, or an error message.
    func uninstall(configDir: URL) -> String? {
        guard let claude = claudePath else {
            return "Claude Code CLI not found."
        }

        // 1. Uninstall the plugin
        let uninstallResult = runCLI(claude, arguments: [
            "plugin", "uninstall", Self.pluginKey,
        ], configDir: configDir)
        if let error = uninstallResult {
            if !error.contains("not installed") && !error.contains("not found") {
                return "Failed to uninstall plugin: \(error)"
            }
        }

        // 2. Remove the marketplace
        let removeResult = runCLI(claude, arguments: [
            "plugin", "marketplace", "remove", Self.marketplaceName,
        ], configDir: configDir)
        if let error = removeResult {
            if !error.contains("not found") && !error.contains("not registered") {
                return "Failed to remove marketplace: \(error)"
            }
        }

        // 3. Clear the plugin cache directory if it exists
        let cacheDir = configDir
            .appendingPathComponent("plugins/cache/\(Self.marketplaceName)/clawde")
        try? FileManager.default.removeItem(at: cacheDir)

        return nil
    }

    // MARK: - CLI Runner

    /// Runs a CLI command targeting the given profile's config dir.
    /// Returns nil on success, or the stderr/error on failure.
    /// Reads pipe output before waiting to prevent deadlock when pipe buffers fill.
    private func runCLI(_ path: String, arguments: [String], configDir: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        // Inherit the user's PATH for any dependencies
        var env = ProcessInfo.processInfo.environment
        let homedir = FileManager.default.homeDirectoryForCurrentUser.path
        env["PATH"] = "\(homedir)/.local/bin:/usr/local/bin:/opt/homebrew/bin:" + (env["PATH"] ?? "")
        env["CLAUDE_CONFIG_DIR"] = configDir.path
        process.environment = env

        let stderrPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = stdoutPipe

        // Read pipe output asynchronously to prevent deadlock when buffers fill.
        // Use a serial queue to synchronize access to the mutable Data buffers.
        let pipeQueue = DispatchQueue(label: "com.burakcokyildirim.clawde.pipeIO")
        var stderrData = Data()
        var stdoutData = Data()
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            pipeQueue.sync { stderrData.append(chunk) }
        }
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            pipeQueue.sync { stdoutData.append(chunk) }
        }

        do {
            try process.run()
        } catch {
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            return error.localizedDescription
        }

        // Timeout after 30 seconds to avoid blocking the app indefinitely
        let deadline = DispatchTime.now() + .seconds(30)
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            process.waitUntilExit()
            group.leave()
        }
        if group.wait(timeout: deadline) == .timedOut {
            process.terminate()
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            return "CLI command timed out after 30 seconds"
        }

        // Drain remaining data and clean up handlers
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        pipeQueue.sync {
            stderrData.append(remainingStderr)
            stdoutData.append(remainingStdout)
        }

        if process.terminationStatus != 0 {
            let errorString = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let outString = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return errorString.isEmpty ? (outString.isEmpty ? "Exit code \(process.terminationStatus)" : outString) : errorString
        }

        return nil
    }
}
