import SwiftUI

/// Icon display style for session rows.
enum SessionIconStyle: String, CaseIterable {
    case emoji
    case dots

    var label: String {
        switch self {
        case .emoji: "Emoji"
        case .dots: "Dots"
        }
    }
}

/// A single row in the session list showing status, project name, and time.
struct SessionRowView: View {
    let session: ClaudeSession
    var iconStyle: SessionIconStyle = .emoji
    /// Show which profile the session belongs to (multi-profile setups).
    var showProfileBadge: Bool = false

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            statusIndicator
                .frame(width: 16, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.sessionName ?? session.projectName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if showProfileBadge, let profileName = session.profileName {
                        Text(profileName)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                    if session.sessionName != nil {
                        Text(session.projectName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text("\u{2022}")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    Text(session.source.label)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if !session.activity.isEmpty {
                        Text("\u{2022}")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                        Text(session.activity)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                // One line, whatever it says. A tool name long enough to wrap —
                // an MCP one reads like mcp__server__some_tool — used to take
                // three lines, treble the row's height and push every row under
                // it down the list.
                .lineLimit(1)
                .truncationMode(.tail)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(stateLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                Text(session.timeSinceActivity)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            // The state and how long ago are what the eye runs down the list
            // for, so they keep their width and the details give way.
            .lineLimit(1)
            .layoutPriority(1)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help(session.workingDirectory)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch iconStyle {
        case .emoji:
            Text(session.isUnread == true ? "\u{1F535}" : session.state.emoji)
                .font(.system(size: 14))
        case .dots:
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
        }
    }

    /// Unread is shown in place of the state it would otherwise report, which
    /// is idle: the hook calls a finished turn idle whether or not anyone has
    /// read it, and that is the distinction worth surfacing.
    private var stateLabel: String {
        session.isUnread == true ? "Unread" : session.state.label
    }

    private var dotColor: Color {
        if session.isUnread == true { return SessionPalette.unread }
        switch session.state {
        case .active: return .green
        case .waiting: return .orange
        case .compacting: return .blue
        case .idle: return .gray
        }
    }
}
