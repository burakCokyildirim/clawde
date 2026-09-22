import AppKit
import SwiftUI
import Testing
@testable import Clawde

/// Draws every mood of a character for a look before it goes anywhere near the
/// app: an animated tile per mood, played through its entrance, loop and exit,
/// and a strip of every frame in it on the canvas grid, with its time and the
/// frame Reduce Motion holds marked. Then a page that shows them all.
///
/// Off unless asked for. `just preview-character nibble` runs it and opens the
/// page; `all` draws every character. By hand:
///
///     TEST_RUNNER_PREVIEW_CHARACTER=nibble xcodebuild test -project Clawde.xcodeproj \
///       -scheme Clawde -only-testing:ClawdeTests/CharacterPreview \
///       CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=15.0
///
/// Everything lands in `build/character-preview/`, which git ignores.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["PREVIEW_CHARACTER"] != nil))
struct CharacterPreview {

    static let out = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("build/character-preview")

    static let moods: [(mood: PetMood, name: String)] = [
        (.active, "Active"), (.waiting, "Waiting"), (.unread, "Unread"),
        (.compacting, "Compacting"), (.idle, "Idle"), (.resting, "Resting"),
    ]

    @Test func preview() throws {
        let asked = ProcessInfo.processInfo.environment["PREVIEW_CHARACTER"] ?? ""
        let ids: [PetCharacterID] = asked == "all"
            ? PetCharacterID.allCases
            : [try #require(PetCharacterID(rawValue: asked), "No character called \(asked); try one of \(PetCharacterID.allCases.map(\.rawValue)) or all")]

        try? FileManager.default.removeItem(at: Self.out)
        for id in ids {
            let folder = Self.out.appendingPathComponent(id.rawValue)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let character = PetCharacter.character(for: id)
            for (mood, name) in Self.moods {
                try Self.tile(character, mood, name: name, in: folder)
                try Self.strip(character, mood, name: name, in: folder)
            }
            try Self.badge(character, in: folder)
        }
        let page = Self.out.appendingPathComponent("index.html")
        try Self.page(for: ids).write(to: page, atomically: true, encoding: .utf8)
        print("PREVIEW \(page.path)")
    }

    // MARK: - Tiles

    /// The mood as it plays: in through its entrance, round the loop twice, and
    /// out through its exit, then a beat of resting so the exit reads as one.
    static func tile(_ character: PetCharacter, _ mood: PetMood, name: String, in folder: URL) throws {
        let routine = character.routine(for: mood)
        let played = (routine.enter ?? []) + routine.loop + routine.loop + (routine.exit ?? [])
        var frames = played.map { ($0, $0.duration) }
        if routine.exit != nil {
            frames.append((character.still(for: .resting), 0.7))
        }
        let images = frames.map { frame, delay in
            (ReadmeAssets.image(
                ReadmeAssets.Tile(character: character, frame: frame, label: name,
                                  accent: mood == .resting ? nil : mood.accent, side: 160, cell: 6),
                size: CGSize(width: 160, height: 160)
            ), delay)
        }
        _ = try ReadmeAssets.writeAPNG(images, named: "\(name.lowercased()).png", in: folder)
    }

    /// The character in place with a count badge up, to see where the badge
    /// hangs from `badgeCorner`.
    static func badge(_ character: PetCharacter, in folder: URL) throws {
        let scale: CGFloat = 8
        let size = PetLayout.panelSize(scale: scale)
        let view = ZStack {
            ReadmeAssets.backdrop
            PetView(character: character, frame: character.still(for: .resting), mood: .active, scale: scale,
                    sessionCount: 2, isBubbleShown: false, isBubbleOpen: false, jumpCount: 0)
        }
        let image = ReadmeAssets.image(view.environment(\.colorScheme, .dark), size: size)
        try ReadmeAssets.pngData(image).write(to: folder.appendingPathComponent("badge.png"))
    }

    // MARK: - Strips

    /// Every frame of the mood, clip by clip, on the canvas grid.
    static func strip(_ character: PetCharacter, _ mood: PetMood, name: String, in folder: URL) throws {
        let routine = character.routine(for: mood)
        let clips: [(String, [PetFrame])] = [
            ("enter", routine.enter ?? []), ("loop", routine.loop), ("exit", routine.exit ?? []),
        ].filter { !$0.1.isEmpty }
        let view = Strip(character: character, title: name, clips: clips, still: routine.still)
        let host = NSHostingView(rootView: view.fixedSize())
        let size = host.fittingSize
        let image = ReadmeAssets.image(view, size: size)
        try ReadmeAssets.pngData(image).write(to: folder.appendingPathComponent("\(name.lowercased())-frames.png"))
    }

    struct Strip: View {
        let character: PetCharacter
        let title: String
        let clips: [(String, [PetFrame])]
        let still: Int

        static let cell: CGFloat = 5
        static let perRow = 8

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                Text("Times in milliseconds. Yellow: the frame Reduce Motion holds.")
                    .font(.system(size: 11)).foregroundStyle(Color(white: 0.6))
                ForEach(clips.indices, id: \.self) { index in
                    let (clip, frames) = clips[index]
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: "\(clip) · \(frames.count) frames · \(Self.milliseconds(frames.map(\.duration).reduce(0, +))) ms")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(white: 0.75))
                        ForEach(Array(stride(from: 0, to: frames.count, by: Self.perRow)), id: \.self) { start in
                            HStack(alignment: .top, spacing: 8) {
                                ForEach(start..<min(start + Self.perRow, frames.count), id: \.self) { number in
                                    cell(frames[number], number: number, isStill: clip == "loop" && number == still)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(white: 0.11))
        }

        private func cell(_ frame: PetFrame, number: Int, isStill: Bool) -> some View {
            VStack(spacing: 3) {
                ZStack {
                    ReadmeAssets.graphite
                    CellLines(cell: Self.cell)
                    ReadmeAssets.Sprite(character: character, frame: frame, scale: Self.cell)
                }
                .frame(width: CGFloat(PetLayout.gridWidth) * Self.cell, height: CGFloat(PetLayout.gridHeight) * Self.cell)
                .overlay(Rectangle().stroke(isStill ? Color.yellow : .clear, lineWidth: 2))
                Text(verbatim: "\(number) · \(Self.milliseconds(frame.duration))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isStill ? Color.yellow : Color(white: 0.7))
            }
        }

        /// Digits only: an interpolated number in a Text takes the locale's
        /// grouping, and a thousand milliseconds is no place for a separator.
        static func milliseconds(_ seconds: TimeInterval) -> String {
            String(Int((seconds * 1000).rounded()))
        }
    }

    /// Faint lines between the canvas cells, so a part a cell out of place shows.
    struct CellLines: View {
        let cell: CGFloat
        var body: some View {
            Canvas { context, size in
                var lines = Path()
                for column in 1..<PetLayout.gridWidth {
                    lines.addRect(CGRect(x: CGFloat(column) * cell, y: 0, width: 0.5, height: size.height))
                }
                for row in 1..<PetLayout.gridHeight {
                    lines.addRect(CGRect(x: 0, y: CGFloat(row) * cell, width: size.width, height: 0.5))
                }
                context.fill(lines, with: .color(.white.opacity(0.07)))
            }
        }
    }

    // MARK: - Page

    static func page(for ids: [PetCharacterID]) -> String {
        let sections = ids.map { id in
            let tiles = moods.map { _, name in
                let file = name.lowercased()
                return "<figure><a href=\"\(id.rawValue)/\(file)-frames.png\"><img src=\"\(id.rawValue)/\(file).png\" width=\"160\" height=\"160\" alt=\"\(name)\"></a><figcaption>\(name) · <a href=\"\(id.rawValue)/\(file)-frames.png\">frames</a></figcaption></figure>"
            }.joined()
            return """
                <section><h2>\(id.label)</h2><p>\(id.blurb)</p>
                <div class="row">\(tiles)<figure><img src="\(id.rawValue)/badge.png" height="160" alt="With its badge up"><figcaption>Badge</figcaption></figure></div></section>
                """
        }.joined(separator: "\n")
        return """
            <!doctype html><meta charset="utf-8"><title>Character preview</title>
            <style>
            body{background:#16181c;color:#e8e6e1;font:14px -apple-system,system-ui,sans-serif;margin:0;padding:24px 16px}
            h2{margin:0 0 2px;font-size:18px}p{margin:0 0 12px;color:#9a9ca3}section{margin-bottom:32px}
            .row{display:flex;flex-wrap:wrap;gap:12px}figure{margin:0}figcaption{font-size:12px;color:#9a9ca3;margin-top:4px}
            a{color:#d1684a}img{display:block;border-radius:14px;image-rendering:pixelated}
            </style>
            <p>Each tile plays its mood through its entrance, loop and exit. Click one for every frame.</p>
            \(sections)
            """
    }
}
