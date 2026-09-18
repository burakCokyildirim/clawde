# CLAUDE.md

## Project Overview

Clawde is a native macOS app for watching Claude Code sessions. A pixel-art pet sits above your windows and acts out what the session it stands for is doing; a menu bar item lists every session, with one-click focus into the host app (terminals, IDEs, the Claude desktop app). It began as a fork of [gmr/claude-status](https://github.com/gmr/claude-status) and is now its own project. Distributed outside the Mac App Store via Developer ID signing, notarization, and Sparkle auto-updates (feed and keys not set up yet — see *Identity*).

## Build & Test

Xcode project with SPM dependencies (no standalone Package.swift). Use `just` for all build and test commands:

```bash
just build-plugin   # cargo build the two hook binaries into the plugin's scripts dir
just build          # Build debug configuration (runs build-plugin first)
just test           # Run all unit tests
just test-class PetLayoutTests     # Run a single test class
just clean          # Clean build artifacts
just swap           # Build, copy to /Applications, and relaunch
just sync-plugin    # Sync the plugin into the installed plugin cache
just show-version   # Show calculated version from git tags
```

The justfile handles `MACOSX_DEPLOYMENT_TARGET=15.0` override (needed for Xcode versions that don't know about macOS 26.2) and disables code signing for local dev builds.

## Platform & Language

- **macOS 26.2+** deployment target (override to 15.0 for CI/older Xcode)
- **Swift 5.0** with `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- **SwiftUI + AppKit** hybrid: AppKit for `NSStatusItem`/`NSPopover`/`NSWindow`, SwiftUI for all views
- **Menu bar-only**: `LSUIElement = YES` (no Dock icon)
- **No App Sandbox**: required for `proc_pidinfo`, `sysctl KERN_PROCARGS2`, and AppleScript automation
- Bundle ID: `com.burakcokyildirim.clawde`
- Widget Bundle ID: `com.burakcokyildirim.clawde.widget`
- App Group: `group.com.burakcokyildirim.clawde` (shared data between app and widget)
- URL Scheme: `clawde://`

### Identity — what not to "finish" renaming

The project was renamed from Claude Status, and the rename is complete. These
identifiers are contracts, not leftovers, and each has a counterpart that must
change with it:

| Identifier | Value | Its other half |
|---|---|---|
| Darwin notification | `com.burakcokyildirim.clawde.session-changed` | posted by `clawde-plugin`'s two binaries |
| Marketplace / plugin key | `clawde-marketplace` / `clawde@clawde-marketplace` | `marketplace.json` and `plugin.json` in the submodule |
| App Group | `group.com.burakcokyildirim.clawde` | every setting and file already on a user's disk |
| Widget kinds | `ClawdeStatusWidget`, `ClawdeProductivityWidget`, `ClawdeScoreWidget` | widgets a user has already placed |
| URL scheme | `clawde://` | the widget's deep links |
| `.cstatus` file and its JSON keys | unchanged | the plugin writes them |

No previous identifier appears anywhere any more. A carry-over from the old App
Group was tried and dropped: macOS keeps a group container to the apps entitled
to it, so reading one needs it in the entitlements, and the group Claude Status's
own releases write to belongs to that project's team and can never be claimed here.

## Dependencies (SPM)

| Package | Version | Purpose |
|---------|---------|---------|
| Sparkle | 2.7.0+ | Auto-updates via Appcast (EdDSA-signed) |

Sparkle is the only package. The hook plugin is a git submodule (`clawde-plugin/`, Rust), not an SPM dependency.

## Architecture

### Targets

| Target | Bundle ID | Purpose |
|--------|-----------|---------|
| `Clawde` | `com.burakcokyildirim.clawde` | Main app: `NSStatusItem` + `NSPopover` with SwiftUI views, and the pet's panels |
| `ClawdeTests` | `com.burakcokyildirim.clawde.tests` | Unit tests (Swift Testing framework) |
| `ClawdeWidgetExtension` | `com.burakcokyildirim.clawde.widget` | WidgetKit desktop widgets (status, productivity, score) |

### Source Layout

```
Clawde/                                # Main app target
  AppMain.swift                        # Entry point, menu bar-only setup
  AppDelegate.swift                    # NSStatusItem, NSPopover, settings window, Sparkle updater
  ClawdeWidgetConfiguration.swift      # WidgetKit configuration
  Info.plist                           # Sparkle feed URL, URL scheme
  Clawde.entitlements                  # App Groups (no sandbox)
  SessionDiscovery/                    # Core session monitoring
    ClaudeProfile.swift                # ClaudeProfile model + ProfileStore (multi-profile config dirs)
    SessionDiscovery.swift             # Scans each profile's projects/*/*.cstatus, validates PIDs, classifies source
    SessionMonitor.swift               # @Observable class: Darwin notifications + file watching + 5s polling
    StateResolver.swift                # DispatchSource file watchers (one per profile); JSONL timestamp fallback
    TerminalFocuser.swift              # Focuses host app (AppleScript for iTerm2, deep links for the Claude app)
    ClaudeDesktopSessions.swift        # Claude desktop records: session IDs for deep links, and the unread test
    ClaudeDesktopFocusLog.swift        # Which session the desktop app has on screen, from the app's own log
    ProductivityTracker.swift          # Time-in-state tracking, concurrency, score (persists to App Group)
    PluginDetector.swift               # Checks installed_plugins.json and settings.json for hook status
    PluginInstaller.swift              # Installs/uninstalls bundled plugin via `claude plugin` CLI
  Pet/                                 # Optional always-on-top desktop pet (off by default)
    PetPresenter.swift                 # Pure: [ClaudeSession] -> the one session the pet represents
    PetSettings.swift                  # Settings value + enums, read from App Group defaults
    PetPosition.swift                  # Codable position + pure screen resolution/clamp math
    PetLayout.swift                    # Pure panel/sprite/bubble geometry over the 20x16 canvas
    PetCharacter.swift                 # Frames composed from parts, a routine per mood, shared props
    PetPlayback.swift                  # Pure: which frame is up, through entrance, loop, and exit
    Characters/                        # Claudie, Nibble, Quack, Kernel: parts and the frames they make
    PetPanel.swift                     # NSPanel: borderless, non-activating, .floating, all Spaces
    PetContentView.swift               # NSView: hit test, tracking area, click/drag, context menu
    PetBubbleContentView.swift         # NSView: speech bubble hover and row clicks, in a panel of its own
    PetWindowController.swift          # Lifecycle, placement, animation driver, teardown
  Views/                               # SwiftUI views
    SessionListView.swift              # Popover: header, session list, empty state, Settings/Quit
    SessionRowView.swift               # Session row: status icon, project, source, activity, time
    SessionPalette.swift               # Colours shared by the session list and the pet
    SettingsView.swift                 # Icon style, launch at login, plugin management, desktop pet
    ProductivityBarView.swift          # Visual productivity tracking bar
    PetView.swift                      # SwiftUI Canvas: sprite render, count badge
    PetBubbleView.swift                # Pet speech bubble: busy and recent idle sessions, as session list rows

Shared/                                # Models shared between app and widget
  ClaudeSession.swift                  # ClaudeSession model, SessionState enum, SessionSource enum
  ProductivityStats.swift              # ProductivityStats and ProductivityData models
  AppGroup.swift                       # The App Group id, its defaults suite and container

ClawdeWidget/                          # Widget extension target
  ClawdeWidgetBundle.swift             # Widget bundle (3 widgets) and the session widget
  ClawdeTimelineProvider.swift         # WidgetKit timeline provider
  ClawdeWidgetEntryView.swift          # Session status widget view
  ProductivityWidget.swift             # Productivity widget definition
  ProductivityWidgetView.swift         # Productivity widget view
  ScoreWidgetView.swift                # Score visualization widget view
  Info.plist                           # Extension metadata

ClawdeWidgetExtension.entitlements     # App Sandbox + App Groups (widget)

ClawdeTests/                           # Unit tests (Swift Testing)

clawde-plugin/                         # The hook plugin, a submodule of burakCokyildirim/clawde-plugin (Rust)
  plugins/clawde/
    hooks/hooks.json                   # 5 hook events (SessionStart, PermissionRequest, Notification, PreCompact, SessionEnd)
    scripts/                           # session-status and set-session-name, built by `just build-plugin`
    skills/session-name/SKILL.md       # /name-session slash command
    .claude-plugin/plugin.json         # Plugin metadata (version the app compares against)
  .claude-plugin/marketplace.json      # Marketplace definition
  crates/                              # The Rust sources for both binaries

assets/                                # Marketing assets (screenshots, icons)
```

### Profiles

The app supports multiple Claude Code profiles (config dirs selected via `CLAUDE_CONFIG_DIR`). `ProfileStore` auto-detects `~/.claude` (the "default" profile) and `~/.claude-*` directories (validated by a `projects/` dir or `settings.json`); custom locations can be added manually in Settings. Each profile can be enabled/disabled and renamed; settings persist in the App Group defaults under `claudeProfiles`. Discovery, file watching, and plugin detection/installation all operate per enabled profile (the installer passes `CLAUDE_CONFIG_DIR` to the `claude` CLI). The hook plugin needs no profile awareness — it writes `.cstatus` next to the transcript path Claude Code provides, which already lives in the profile's `projects/` dir.

### Session Discovery Pipeline

1. **Plugin hook** (`session-status`) fires on Claude Code lifecycle events and writes `.cstatus` JSON to `<profile>/projects/<encoded-path>/<session-id>.cstatus`
2. **SessionDiscovery** scans each enabled profile's `projects/*/` for `.cstatus` files, parses JSON (session ID, PID, state, activity, cwd), validates PIDs with `kill(pid, 0)`
3. **Source classification** walks the process tree via `proc_pidinfo`/`proc_pidpath` and reads environment variables via `sysctl KERN_PROCARGS2` to identify the host app
4. **SessionMonitor** (`@Observable`) maintains the session list with three update mechanisms:
   - **Darwin notifications** (instant) — hook posts `com.burakcokyildirim.clawde.session-changed` via `notifyutil -p`
   - **File system watching** (fast) — `DispatchSource` on each enabled profile's `projects/` dir
   - **Polling timer** (5s fallback) — catches sessions without hooks (IDE agents)

A session is listed under the first name it has: one set with `/name-session` (the `.cstatus` `session_name`), the title the Claude desktop app lists it under, the title Claude Code wrote into its transcript (`custom-title`, then `ai-title`, read from the end and at most every 30 seconds), and otherwise its project folder. The name lands in `ClaudeSession.sessionName`, so the session list, the widget, and the pet all show it without knowing where it came from.

### Session State

State is reported by the hook script in `.cstatus` files:

| State | Emoji | Dot | Description |
|-------|-------|-----|-------------|
| Active | lightning | green | Claude is working (tool use, response streaming) |
| Waiting | hourglass | orange | Needs user input |
| Compacting | broom | blue | Context compaction in progress |
| Idle | sleep | gray | No recent activity |

The hook also reports waiting, with activity `question`, when a turn ends with a question in its last paragraph, a guess from the text. The **Questions Count as Waiting** setting (App Group key `countQuestionsAsWaiting`, on unless turned off) can show such a turn as the finished turn the Claude desktop app calls it; a prompt that really holds the session keeps waiting.

Sessions run by the Claude desktop app carry one signal the hook cannot give: **unread** — Claude has spoken since the user last had that session in front of them. It is a flag on `ClaudeSession`, not a `SessionState`, so it never makes the stronger claim `waiting` does (that the session is blocked until the user answers); the pet and the session list draw it in the same blue the desktop app uses for it. `ClaudeDesktopSessions.swift` decides it by comparing the time of Claude's last answer in the session's transcript against the last time the session was seen. The hook's `.cstatus` timestamp cannot stand in for that answer: the desktop app starts a session's process whenever the session is clicked, and every start rewrites the file. `ClaudeDesktopFocusLog.swift` supplies the hard part — which session the app currently has on screen — by reading the app's own `~/Library/Logs/Claude/main.log`, the only signal available without Screen Recording that tells reading a session apart from having the app up on a plain chat. The app also stops sessions' processes — evicting idle ones once it has too many open or after half an hour, and all of them when it quits — and the hook's file goes with each, so a session seen running with an unread answer stays listed, as last seen, until it is read or archived. Marks live in the App Group under `claudeDesktopSeenAt`, and those sessions under `claudeDesktopUnreadSessions`.

### Host App Recognition

**Terminals** (via process tree): iTerm2 (session-specific AppleScript focusing), Terminal, Warp, Alacritty, Kitty, WezTerm, Ghostty

**IDEs** (via process tree): Xcode, VS Code, JetBrains IDEs, Zed

**Claude desktop app** (via `CLAUDE_CODE_ENTRYPOINT=claude-desktop` on the Claude process): opens the exact session with `claude://code/continue`, matched through the app's `claude-code-sessions` records

**Remote Control** (a process no terminal or IDE owns, as when a script starts `claude --remote-control`, whose transcript records a `bridge-session`): shown as Claude too, since that is where the user reaches it. A click sends `claude://claude.ai/code/session_…`, which opens the session, and brings the app forward; the shorter `claude://code/session_…` waits on a feature switch in the app and is dropped while it is off. Without a bridge, such a process still falls back to Terminal

### Desktop Pet

An optional floating character, off by default. `PetWindowController` owns a borderless, non-activating `NSPanel` at `.floating` that joins all Spaces; SwiftUI draws into it and it lets every click through, while `PetContentView` owns every event from a sprite-sized child panel on top, so only the sprite is clickable and everything around it clicks through. `PetPresenter` picks the single session it stands for, reusing `SessionState.sortOrder`, and the sessions its speech bubble lists: every one doing something or holding an answer, in the same order, then the idle sessions that did something last — one after busy ones, up to three when nothing is busy. Each line reads as the session list's row does. The bubble is a third child panel that takes the mouse; while the pointer is on one of its lines the pet acts out that session, and a click focuses it. It hangs by a tail from the count badge at the character's top left, which takes the colour of the mood on screen: the bubble grows out of the badge and draws back into it, and the badge draws in to a dot while the list is open. Characters are frame animations on a 20x16 canvas: each file under `Characters/` draws a character's parts once and places them to make its frames, and every mood — the four states, unread, and resting with no session — has a routine of an optional entrance, a loop, and an optional exit. `PetPlayback` sequences those as a pure value, and the controller's timer wakes only when the frame on screen is due to change. A hop — twice, the one motion not drawn into the frames — plays over the top whenever a session takes up something new, and when the pet or one of the bubble's lines is clicked. Settings live in the App Group defaults under `pet*` keys (the popover's header has a button that shows or hides the pet) and are re-read on the status item's existing one-second tick — the pet polls nothing of its own, runs no frame timer while hidden or covered, and under reduced motion holds each mood on a single still frame.

### Productivity Tracking

`ProductivityTracker` maintains daily and all-time stats in the App Group shared container (`productivity.json`), tracking time-in-state across concurrent sessions and calculating a score (0-100). Both the app and widget extension read this shared file.

## Key Runtime Paths

| Path | Purpose |
|------|---------|
| `~/.claude/projects/` | Claude Code session state (encoded project paths as directory names) |
| `~/.claude-<name>/` | Additional Claude Code profiles (`CLAUDE_CONFIG_DIR`), auto-detected |
| `~/.claude/projects/<path>/<session-id>.cstatus` | Session status files written by hook script |
| `~/.claude/projects/<path>/sessions-index.json` | Session index with metadata, prompts, timestamps |
| `~/.claude/projects/<path>/<uuid>.jsonl` | Conversation logs per session |
| `~/.claude/plugins/installed_plugins.json` | Plugin registry |
| `~/Library/Group Containers/group.com.burakcokyildirim.clawde/productivity.json` | Shared productivity data |

## CI/CD

### CI Build (`xcode.yml`)

Runs on push/PR to `main`. Three jobs, the first feeding the other two:
- **Build Plugin**: `cargo build --release` in `clawde-plugin/`, ad-hoc signs the two binaries, uploads them as an artifact
- **Build**: `xcodebuild clean build` with code signing disabled
- **Test**: `xcodebuild test` for `ClawdeTests` only

All three check out submodules; Build and Test download the plugin artifact first. Every job overrides `MACOSX_DEPLOYMENT_TARGET=15.0`.

### Release (`release.yml`)

Triggered by publishing a GitHub release. The release tag becomes `MARKETING_VERSION`.

**Build & Notarize job:**
1. Import Developer ID certificate from `CERTIFICATE_P12` secret into a temporary keychain
2. Install provisioning profiles (`PROVISIONING_PROFILE_APP`, `PROVISIONING_PROFILE_WIDGET`) — required for App Groups entitlement
3. Inject per-target `PROVISIONING_PROFILE_SPECIFIER` into the pbxproj (Ruby script patches by bundle ID)
4. `xcodebuild archive` with manual signing, hardened runtime
5. `xcodebuild -exportArchive` with `ExportOptions.plist` mapping each bundle ID to its provisioning profile
6. Notarize the `.app` and `.pkg` via `notarytool` (fetches Apple log on failure)
7. Upload `.zip` and `.pkg` as release assets

**Update Appcast job:**
1. Downloads Sparkle tools, generates `appcast.xml` with EdDSA signature
2. Commits to `gh-pages` branch for GitHub Pages hosting

### Release Secrets

| Secret | Purpose |
|--------|---------|
| `CERTIFICATE_P12` | Base64 Developer ID Application certificate |
| `CERTIFICATE_PASSWORD` | P12 password |
| `CODE_SIGN_IDENTITY` | e.g. `Developer ID Application: Name (TEAMID)` |
| `DEVELOPMENT_TEAM` | Apple team ID |
| `PROVISIONING_PROFILE_APP` | Base64 provisioning profile for main app (with App Groups) |
| `PROVISIONING_PROFILE_WIDGET` | Base64 provisioning profile for widget (with App Groups) |
| `INSTALLER_SIGN_IDENTITY` | Developer ID Installer identity for `.pkg` |
| `APPLE_ID` | Apple ID for notarization |
| `APPLE_ID_PASSWORD` | App-specific password for notarization |
| `SPARKLE_ED_PUBLIC_KEY` | EdDSA public key embedded in builds |
| `SPARKLE_PRIVATE_KEY` | EdDSA private key for signing appcast |
