import SwiftUI

/// The popover content showing all active Claude Code sessions.
struct SessionListView: View {
    let sessions: [ClaudeSession]
    let productivityData: ProductivityData
    /// Show per-session profile badges (when more than one profile is enabled).
    var showProfileBadges: Bool = false
    /// No profile has the hook, so nothing is reporting and the list is guesswork.
    var isHookMissing: Bool = false
    var onSetUpPlugin: (() -> Void)?
    var onSessionTap: ((ClaudeSession) -> Void)?
    var onRefresh: (() -> Void)?
    /// The pet was shown or hidden from the header, to act on it at once.
    var onPetToggle: (() -> Void)?
    var onSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    @AppStorage("iconStyle", store: AppGroup.defaults)
    private var iconStyle: SessionIconStyle = .emoji

    @AppStorage(PetSettings.Keys.enabled, store: AppGroup.defaults)
    private var isPetShown = false

    @State private var isRefreshing = false

    private let menuFont = Font.system(size: 13)

    /// Ordered the way the pet ranks them, so the row it stands for is the one
    /// at the top of this list rather than buried among the idle sessions.
    private var sortedSessions: [ClaudeSession] {
        sessions.sorted {
            $0.attentionRank != $1.attentionRank
                ? $0.attentionRank < $1.attentionRank
                : $0.lastActivityAt > $1.lastActivityAt
        }
    }

    /// Max height for session list: 80% of screen height minus chrome.
    private var maxSessionListHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        let chromeHeight: CGFloat = 160 // header + settings + menu + dividers
        return screenHeight * 0.8 - chromeHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if isHookMissing {
                pluginBanner
                Divider()
            }

            if sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }

            if productivityData.today.totalSessionTime > 0 {
                Divider()
                    .padding(.vertical, 4)
                productivitySection
            }

            Divider()
                .padding(.vertical, 4)
            menuSection
        }
        .frame(width: 300)
        .background(.background)
    }

    // MARK: - Subviews

    /// Without the plugin nothing reports, and the app cannot say much: sessions
    /// turn up late through polling, and their state is a guess from the
    /// transcript. Say so where it is noticed, rather than once on first launch.
    private var pluginBanner: some View {
        Button {
            onSetUpPlugin?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("No plugin installed")
                        .font(.system(size: 12, weight: .medium))
                    Text("State is guesswork until it is in.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Set Up\u{2026}")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            Text("Clawde")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("v\(Bundle.main.appVersion)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
            petToggle
            Button(action: {
                withAnimation(.linear(duration: 0.5)) {
                    isRefreshing = true
                }
                onRefresh?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isRefreshing = false
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(.linear(duration: 0.5), value: isRefreshing)
            }
            .buttonStyle(.plain)
            .help("Refresh")

            Button(action: { onSettings?() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// Shows or hides the desktop pet, and stays lit while it is out.
    private var petToggle: some View {
        Button {
            isPetShown.toggle()
            onPetToggle?()
        } label: {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 12))
        }
        .buttonStyle(RoundToggleButtonStyle(isOn: isPetShown))
        .help(isPetShown ? "Hide Desktop Pet" : "Show Desktop Pet")
        .accessibilityLabel("Desktop Pet")
        .accessibilityValue(isPetShown ? "On" : "Off")
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Text("No active sessions")
                .font(menuFont)
                .foregroundStyle(.secondary)
            Text("Sessions appear when claude is running")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var sessionList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(sortedSessions) { session in
                    Button {
                        onSessionTap?(session)
                    } label: {
                        SessionRowView(
                            session: session,
                            iconStyle: iconStyle,
                            showProfileBadge: showProfileBadges
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: maxSessionListHeight)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var productivitySection: some View {
        let stats = productivityData.today
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Claude Usage (Today)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(stats.totalTimeFormatted) · Score \(stats.score)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            // Stacked horizontal bar — hover shows floating legend tooltip
            ProductivityBarView(stats: stats)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }

    private var menuSection: some View {
        VStack(spacing: 0) {
            menuButton(action: { onQuit?() }) {
                Text("Quit")
            }
        }
        .padding(.bottom, 4)
    }

    private func menuButton<Content: View>(
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Content
    ) -> some View {
        MenuButtonView(action: action, label: label)
            .font(menuFont)
    }
}

/// A round button filled with the accent colour while what it switches is on, as
/// Control Center draws its toggles.
///
/// The circle is drawn outside the icon's own box rather than around a larger
/// frame, so the button takes the same room as the plain icons beside it and
/// lines up with them.
private struct RoundToggleButtonStyle: ButtonStyle {
    let isOn: Bool

    private static let ring: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isOn ? Color.white : Color.secondary)
            .background(
                Circle()
                    .fill(isOn ? Color.accentColor : Color.primary.opacity(0.1))
                    .padding(-Self.ring)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Circle().inset(by: -Self.ring))
    }
}

/// A menu-style button with hover highlight, similar to Claude Code's menu items.
private struct MenuButtonView<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Content

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                        .padding(.horizontal, 6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

}
