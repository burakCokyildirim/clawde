import Testing
@testable import Clawde

/// The steps the app hands someone it cannot install for have to be the ones
/// that work: the key it installs under, and the marketplace it carries.
@MainActor
struct PluginSetupTests {

    @Test func theStepsNameTheBundledMarketplaceAndThePluginTheAppLooksFor() {
        let setup = PluginSetup()
        let commands = setup.commands.map(\.command)

        #expect(commands.count == 2)
        #expect(commands[0].hasPrefix("/plugin marketplace add "))
        // Whatever the app carries is what it tells you to add; in a test bundle
        // there is none, and the placeholder still points inside the app.
        #expect(commands[0].hasSuffix(setup.marketplacePath ?? "clawde-plugin"))
        #expect(commands[1] == "/plugin install \(PluginInstaller.pluginKey)")
    }

    /// `/reload-plugins` cannot make an open session report: the daemon is
    /// started by SessionStart alone. The advice must not send anyone to it.
    @Test func theAdviceSaysToStartSessionsAgainNotToReload() {
        #expect(!PluginSetup.restartAdvice.contains("reload-plugins"))
        #expect(PluginSetup.restartAdvice.contains("quit it"))
        #expect(PluginSetup.restartAdvice.contains("claude --resume"))
        #expect(!PluginSetup().commands.contains { $0.command.contains("reload-plugins") })
    }

    /// `PluginDetector` looks for this prefix; installing under another key would
    /// leave the app reporting that nothing is installed.
    @Test func thePluginKeyIsTheOneTheDetectorLooksFor() {
        #expect(PluginInstaller.pluginKey.hasPrefix("clawde@"))
        #expect(PluginInstaller.pluginKey.hasSuffix(PluginInstaller.marketplaceName))
    }
}
