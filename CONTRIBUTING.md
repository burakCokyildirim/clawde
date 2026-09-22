# Contributing to Clawde

Thanks for wanting to help. Clawde is small and friendly to first pull requests, and the most fun
place to start is a new pet character.

## Make a character

Every character is one Swift file: pixel art written as rows of letters, and a short animation for
each thing a session can be doing. No drawing tools needed.

The easiest way is with Claude Code. Open this repository in it and run:

```
/new-character
```

It asks what you have in mind, draws it with you, shows you every mood animated, and wires it into
the app. Bring any idea you like (a cat that walks across the keyboard while it works, an octopus
typing on four keyboards at once, a coffee mug that drains while the context compacts, a cactus
that grows a flower when there is something to read, a snail leaving a trail of semicolons).

To do it by hand, or to see what the skill works from, read
[Making a character](docs/characters.md).

## Other good first contributions

- **A terminal or editor Clawde doesn't recognise yet.** Sessions are matched to the app they run
  in by `classifySource` in
  [`SessionDiscovery.swift`](Clawde/SessionDiscovery/SessionDiscovery.swift), and brought forward
  by [`TerminalFocuser.swift`](Clawde/SessionDiscovery/TerminalFocuser.swift).
- **Bugs** in how a session's state is shown, or in focusing it.
- **The README and these docs**, wherever they left you guessing.

If you are planning something bigger, open an issue first so we can talk it through before you
spend the time.

## Setting up

You need a Mac with Xcode 26 or newer, [Rust](https://rustup.rs) (the plugin pins its own
toolchain, rustup fetches it) and [just](https://github.com/casey/just) (`brew install just`).

```bash
git clone --recurse-submodules https://github.com/burakCokyildirim/clawde.git
cd clawde
just build
just test
```

`just build` builds the hook plugin and then the app, unsigned. To run your build, open
`Clawde.xcodeproj` in Xcode, pick your own team under Signing & Capabilities for the `Clawde` and
`ClawdeWidgetExtension` targets, and run. Quit the released Clawde first if you have it, so there
is only one in the menu bar.

## How the pieces fit

- **The app** is here: SwiftUI views in an AppKit shell, a menu bar item, the pet's panels and the
  widgets. [`CLAUDE.md`](CLAUDE.md) walks through the architecture and is kept up to date, for
  people and for Claude Code alike.
- **The plugin** is a small Rust daemon that watches a session and writes its state to a
  `.cstatus` file. It lives in its own repository,
  [clawde-plugin](https://github.com/burakCokyildirim/clawde-plugin), checked out here as the
  `clawde-plugin/` submodule. Changes to it go to that repository.

A few names are contracts between the app, the plugin and what is already on people's Macs: the
App Group, the notification name, the URL scheme, the widget kinds and the `.cstatus` format. The
*Identity* section of `CLAUDE.md` lists them. Please don't rename them.

## Pull requests

- One thing per pull request. A character, a fix, a new terminal.
- Match the code around you: its naming, its comments (they say why, not what) and its tests. New
  tests use Swift Testing.
- `just test` passes before you send it.
- Anything you can see, show: a screenshot or the preview tiles for a character.
- Commit messages start with what kind of change it is: `feat:`, `fix:`, `docs:`, `test:`,
  `refactor:`, `chore:`.

Using Claude Code or another assistant to write your change is fine. You still own it: read it,
run it, and be ready to answer questions about it.

## Reporting a bug

Open an issue and tell us:

- your macOS version and Clawde's version
- how you run Claude Code: which terminal or editor, or the Claude desktop app
- what you expected and what you saw
- for a wrong state, the session's `.cstatus` file if you can find it, from
  `~/.claude/projects/<project>/<session id>.cstatus`

## License

Clawde is under the [BSD 3-Clause License](LICENSE), and anything you contribute is under it too.
