import Foundation
import Testing
@testable import Clawde

@Suite("Terminal focusing")
struct TerminalFocuserTests {

    @Test("the script names the tab's own device")
    func theScriptNamesTheTabsOwnDevice() throws {
        let script = try #require(SessionFocuser.terminalTabScript(tty: "/dev/ttys006"))
        #expect(script.contains("tty of aTab is \"/dev/ttys006\""))
        // Falls through to activating the app when no tab is attached to it,
        // so a session whose tab has been closed still brings Terminal forward.
        #expect(script.hasSuffix("    activate\nend tell"))
    }

    @Test(
        "a device path we did not write is refused",
        arguments: [
            #"/dev/ttys006" is "" or true then activate"#,
            "/dev/../etc/passwd",
            "/dev/ttys 006",
            "ttys006",
            "",
        ]
    )
    func aDevicePathWeDidNotWriteIsRefused(tty: String) {
        #expect(SessionFocuser.terminalTabScript(tty: tty) == nil)
    }

    @Test("a process with no controlling terminal has no device")
    func aProcessWithNoControllingTerminalHasNoDevice() {
        // launchd is the one pid that is always there and never on a terminal.
        #expect(SessionFocuser.controllingTTY(for: 1) == nil)
    }

    @Test("a process that is gone has no device")
    func aProcessThatIsGoneHasNoDevice() {
        #expect(SessionFocuser.controllingTTY(for: -1) == nil)
    }
}
