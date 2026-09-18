import AppKit
import SwiftUI
import Testing
@testable import Clawde

/// A row's height is the list's rhythm: every row the same, so the eye can run
/// down the state column. Nothing a session reports should be able to change it.
@MainActor
struct SessionRowLayoutTests {

    private static func session(activity: String) -> ClaudeSession {
        ClaudeSession(
            sessionId: "s",
            pid: 1,
            workingDirectory: "/Users/example/clawde",
            projectName: "clawde",
            state: .active,
            lastActivityAt: Date(),
            iTermSessionId: nil,
            tmuxPaneId: nil,
            tmuxSocket: nil,
            source: .terminal(app: "Ghostty"),
            activity: activity,
            sessionName: "A session"
        )
    }

    /// The popover's own width, which `SessionListView` fixes.
    private static let width: CGFloat = 300

    private static func height(forActivity activity: String) -> CGFloat {
        let row = SessionRowView(session: session(activity: activity), iconStyle: .dots)
            .frame(width: width)
        let host = NSHostingView(rootView: row)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.height
    }

    @Test func aLongToolNameDoesNotMakeItsRowTaller() {
        // An MCP tool reports itself like this, and it is long enough to wrap the
        // details line, which used to treble the row and push the rest down.
        let long = Self.height(forActivity: "mcp__trello-burak__get_board_cards")
        let short = Self.height(forActivity: "Edit")
        #expect(long == short)
    }

    @Test func aFolderAndHostLongerThanTheRowDoNotEither() {
        let long = Self.height(forActivity: String(repeating: "verylongtoolname", count: 4))
        let none = Self.height(forActivity: "")
        #expect(long == none)
    }
}
