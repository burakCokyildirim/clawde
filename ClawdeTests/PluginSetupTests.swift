import Testing
@testable import Clawde

/// The steps the app hands someone it cannot install for have to be the ones
/// that work: the key it installs under, and the marketplace it carries.
@MainActor
struct PluginSetupTests {

    @Test func theStepsNameTheBundledMarketplaceAndThePluginTheAppLooksFor() {
        let setup = PluginSetup()
        let commands = setup.commands.map(\.command)

        #expect(commands.count == 3)
        #expect(commands[0].hasPrefix("/plugin marketplace add "))
        // Whatever the app carries is what it tells you to add; in a test bundle
        // there is none, and the placeholder still points inside the app.
        #expect(commands[0].hasSuffix(setup.marketplacePath ?? "clawde-plugin"))
        #expect(commands[1] == "/plugin install \(PluginInstaller.pluginKey)")
        // A plugin's hooks only run after a reload or a new session.
        #expect(commands[2] == "/reload-plugins")
    }

    /// `PluginDetector` looks for this prefix; installing under another key would
    /// leave the app reporting that nothing is installed.
    @Test func thePluginKeyIsTheOneTheDetectorLooksFor() {
        #expect(PluginInstaller.pluginKey.hasPrefix("clawde@"))
        #expect(PluginInstaller.pluginKey.hasSuffix(PluginInstaller.marketplaceName))
    }
}
