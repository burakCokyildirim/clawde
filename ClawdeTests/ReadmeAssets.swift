import AppKit
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import Clawde

/// Renders the README's pictures and animations from the real engine and views,
/// with example sessions: the pet's moods and characters as they play in the app,
/// the bubble and the popover as SwiftUI draws them. Never from a screen capture.
///
/// Off unless asked for, since it writes into `assets/`. When a character, the
/// bubble or the popover changes, run it again and commit what it wrote:
///
///     TEST_RUNNER_RENDER_README_ASSETS=1 xcodebuild test -project Clawde.xcodeproj \
///       -scheme Clawde -only-testing:ClawdeTests/ReadmeAssets MARKETING_VERSION=<version> \
///       CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=15.0
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["RENDER_README_ASSETS"] != nil))
struct ReadmeAssets {

    static let out = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("assets/readme")

    static let graphite = Color(red: 0x2B / 255, green: 0x2F / 255, blue: 0x36 / 255)
    static let backdrop = Color(red: 0.24, green: 0.22, blue: 0.30)

    // MARK: - Output

    /// A SwiftUI view rasterised into a context of our own, so what is not drawn
    /// stays transparent — `ImageRenderer.cgImage` fills it white.
    static func image<V: View>(_ view: V, size: CGSize, scale: CGFloat = 2) -> CGImage {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        var made: CGImage?
        renderer.render(rasterizationScale: scale) { _, draw in
            let context = CGContext(
                data: nil,
                width: Int(size.width * scale), height: Int(size.height * scale),
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.scaleBy(x: scale, y: scale)
            draw(context)
            made = context.makeImage()
        }
        return made!
    }

    static func bytes(_ image: CGImage) -> Data {
        image.dataProvider?.data as Data? ?? Data()
    }

    // MARK: - Animated PNG, written by hand

    /// Frames that look the same as the one before are folded into it, and every
    /// frame after the first carries only the rectangle that changed. ImageIO's
    /// own APNG writer stores every frame whole, which put the hero at 4.9 MB for
    /// what is mostly a few cells of an arm moving.
    static func writeAPNG(_ frames: [(CGImage, Double)], named name: String) throws -> (Int, Int) {
        var merged: [(image: CGImage, delay: Double, data: Data)] = []
        for (image, delay) in frames where delay > 0.0005 {
            let data = bytes(image)
            if let last = merged.last, last.data == data {
                merged[merged.count - 1].delay += delay
            } else {
                merged.append((image, delay, data))
            }
        }

        var png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        var sequence: UInt32 = 0
        func be32(_ value: UInt32) -> Data { withUnsafeBytes(of: value.bigEndian) { Data($0) } }
        func be16(_ value: UInt16) -> Data { withUnsafeBytes(of: value.bigEndian) { Data($0) } }
        func chunk(_ type: String, _ body: Data) {
            let typed = Data(type.utf8) + body
            png += be32(UInt32(body.count)) + typed + be32(crc32(typed))
        }
        func control(_ rect: CGRect, _ delay: Double) {
            let milliseconds = UInt16(max(1, min(65535, Int((delay * 1000).rounded()))))
            chunk("fcTL", be32(sequence) + be32(UInt32(rect.width)) + be32(UInt32(rect.height))
                + be32(UInt32(rect.minX)) + be32(UInt32(rect.minY))
                + be16(milliseconds) + be16(1000) + Data([0, 0]))  // dispose none, blend source
            sequence += 1
        }

        let first = chunks(ofPNG: pngData(merged[0].image))
        let header = try #require(first.first { $0.type == "IHDR" }).body
        chunk("IHDR", header)
        chunk("acTL", be32(UInt32(merged.count)) + be32(0))
        for (type, body) in first.prefix(while: { $0.type != "IDAT" }) where type != "IHDR" {
            chunk(type, body)
        }
        let size = CGRect(x: 0, y: 0, width: merged[0].image.width, height: merged[0].image.height)
        control(size, merged[0].delay)
        for (type, body) in first where type == "IDAT" { chunk("IDAT", body) }

        for index in merged.indices.dropFirst() {
            let rect = changed(from: merged[index - 1].image, to: merged[index].image) ?? CGRect(x: 0, y: 0, width: 1, height: 1)
            let crop = try #require(merged[index].image.cropping(to: rect))
            let parts = chunks(ofPNG: pngData(crop))
            let subHeader = try #require(parts.first { $0.type == "IHDR" }).body
            // Same bit depth, colour type and interlace, or the data cannot be spliced.
            #expect(subHeader[subHeader.startIndex + 8] == header[header.startIndex + 8])
            #expect(subHeader[subHeader.startIndex + 9] == header[header.startIndex + 9])
            #expect(subHeader[subHeader.startIndex + 12] == header[header.startIndex + 12])
            control(rect, merged[index].delay)
            for (type, body) in parts where type == "IDAT" {
                chunk("fdAT", be32(sequence) + body)
                sequence += 1
            }
        }
        chunk("IEND", Data())

        let url = Self.out.appendingPathComponent(name)
        try png.write(to: url)
        try verify(url, against: merged.map(\.image))
        return (merged.count, png.count)
    }

    /// Reads the file back through ImageIO, which composites each frame from its
    /// rectangle, and holds every frame to the one it was made from.
    static func verify(_ url: URL, against frames: [CGImage]) throws {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        #expect(CGImageSourceGetCount(source) == frames.count)
        var worst = 0
        for (index, original) in frames.enumerated() {
            let decoded = try #require(CGImageSourceCreateImageAtIndex(source, index, nil))
            let a = rgba(original), b = rgba(decoded)
            for i in stride(from: 0, to: min(a.count, b.count), by: 1) {
                worst = max(worst, abs(Int(a[i]) - Int(b[i])))
            }
        }
        print("VERIFY \(url.lastPathComponent): \(frames.count) frames, worst channel difference \(worst)")
        #expect(worst <= 3)
    }

    /// Pixels in one known layout, whatever the image came in.
    static func rgba(_ image: CGImage) -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
        buffer.withUnsafeMutableBytes { raw in
            let context = CGContext(
                data: raw.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return buffer
    }

    /// The smallest rectangle, in image coordinates from the top left, holding
    /// every pixel that differs.
    static func changed(from old: CGImage, to new: CGImage) -> CGRect? {
        let a = rgba(old), b = rgba(new)
        let width = new.width, height = new.height
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = y * width * 4
            for x in 0..<width {
                let i = row + x * 4
                if a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2] || a[i + 3] != b[i + 3] {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    static func pngData(_ image: CGImage) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    static func chunks(ofPNG data: Data) -> [(type: String, body: Data)] {
        let bytes = [UInt8](data)
        var chunks: [(type: String, body: Data)] = []
        var i = 8
        while i + 12 <= bytes.count {
            let length = Int(bytes[i]) << 24 | Int(bytes[i + 1]) << 16 | Int(bytes[i + 2]) << 8 | Int(bytes[i + 3])
            let type = String(decoding: bytes[(i + 4)..<(i + 8)], as: UTF8.self)
            chunks.append((type, Data(bytes[(i + 8)..<(i + 8 + length)])))
            i += 12 + length
        }
        return chunks
    }

    static let crcTable: [UInt32] = (0..<256).map { n in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in data { c = crcTable[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }

    // MARK: - Tiles

    struct Sprite: View {
        let character: PetCharacter
        let frame: PetFrame
        let scale: CGFloat
        var body: some View {
            Canvas { context, _ in
                for (row, line) in frame.rows.enumerated() {
                    for (column, key) in line.enumerated() {
                        guard let colour = character.color(for: key) else { continue }
                        let rect = CGRect(
                            x: CGFloat(column) * scale, y: CGFloat(row) * scale,
                            width: scale, height: scale
                        )
                        context.fill(Path(rect), with: .color(colour), style: FillStyle(antialiased: false))
                    }
                }
            }
            .frame(width: CGFloat(PetLayout.gridWidth) * scale, height: CGFloat(PetLayout.gridHeight) * scale)
        }
    }

    /// The pet sheet's state card: the character on graphite, and what it is doing.
    struct Tile: View {
        let character: PetCharacter
        let frame: PetFrame
        let label: String
        let accent: Color?
        let side: CGFloat
        /// Whole points per canvas cell, so the art stays crisp at 1x and 2x.
        let cell: CGFloat
        var body: some View {
            VStack(spacing: side * 0.085) {
                Sprite(character: character, frame: frame, scale: cell)
                HStack(spacing: 6) {
                    if let accent {
                        Circle().fill(accent).frame(width: 8, height: 8)
                    }
                    Text(label)
                        .font(.system(size: side < 130 ? 11 : 12, weight: .semibold))
                        .foregroundStyle(Color(white: 0.9))
                }
            }
            .frame(width: side, height: side)
            .background(
                RoundedRectangle(cornerRadius: side * 0.12, style: .continuous).fill(ReadmeAssets.graphite)
            )
        }
    }

    static func tile(
        _ character: PetCharacter, _ mood: PetMood, label: String, accent: Color?,
        side: CGFloat, cell: CGFloat, named name: String
    ) throws {
        let routine = character.routine(for: mood)
        var frames: [(PetFrame, Double)] = []
        if mood == .active {
            for frame in (routine.enter ?? []) + routine.loop + routine.loop + (routine.exit ?? []) {
                frames.append((frame, frame.duration))
            }
            frames.append((character.still(for: .resting), 0.7))
        } else {
            frames = routine.loop.map { ($0, $0.duration) }
        }
        let images = frames.map { frame, delay in
            (image(Tile(character: character, frame: frame, label: label, accent: accent, side: side, cell: cell),
                   size: CGSize(width: side, height: side)), delay)
        }
        let (count, bytes) = try writeAPNG(images, named: name)
        print("ANIM \(name): \(count) frames, \(bytes / 1024) KB")
    }

    // MARK: - Menu bar

    /// A day with something in it, so the popover's usage bar is in the picture.
    static let day = ProductivityStats(
        date: Calendar.current.startOfDay(for: Date()),
        timeInState: ["active": 9_240, "waiting": 2_100, "idle": 3_600, "compacting": 420],
        peakConcurrency: 4,
        concurrencySeconds: [0: 600, 1: 3_600, 2: 5_400, 3: 1_800, 4: 900],
        totalTrackedTime: 12_300,
        score: 78
    )

    /// The popover, drawn by AppKit — ImageRenderer never draws a ScrollView's
    /// contents — then given the popover's rounded edge.
    @Test func menuBar() throws {
        let sessions = [
            Self.session("Ship the release", folder: "clawde", state: .waiting,
                         source: .claudeDesktop, activity: "question", ago: 8),
            Self.session("Answer the review", folder: "clawde-plugin", state: .idle,
                         source: .claudeDesktop, ago: 180, unread: true),
            Self.session("Rewrite the parser", folder: "jsonl-spec", state: .active,
                         source: .terminal(app: "Ghostty"), activity: "Edit", ago: 3),
            Self.session("Tidy the docs", folder: "clawde", state: .idle,
                         source: .terminal(app: "Terminal"), ago: 2400),
        ]
        AppGroup.defaults?.set(true, forKey: PetSettings.Keys.enabled)
        defer { AppGroup.defaults?.removeObject(forKey: PetSettings.Keys.enabled) }

        let view = SessionListView(sessions: sessions, productivityData: ProductivityData(today: Self.day, allTime: Self.day))
        let host = NSHostingView(rootView: view.fixedSize())
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 10, height: 10),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        window.setFrameOrigin(CGPoint(x: -20000, y: -20000))
        window.orderBack(nil)
        host.layoutSubtreeIfNeeded()
        window.setContentSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        window.orderOut(nil)
        let list = try #require(rep.cgImage)

        let radius: CGFloat = 24, width = list.width, height = list.height
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let edge = CGPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.addPath(edge)
        context.clip()
        context.draw(list, in: bounds)
        context.resetClip()
        context.addPath(edge)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.14))
        context.setLineWidth(2)
        context.strokePath()
        let framed = try #require(context.makeImage())
        let data = try #require(NSBitmapImageRep(cgImage: framed).representation(using: .png, properties: [:]))
        try data.write(to: Self.out.deletingLastPathComponent().appendingPathComponent("menu-bar.png"))
        print("STILL menu-bar.png \(width)x\(height)")
    }


    // MARK: - Hero

    static func session(
        _ name: String, folder: String, state: SessionState, source: SessionSource,
        activity: String = "", ago: TimeInterval, unread: Bool = false
    ) -> ClaudeSession {
        ClaudeSession(
            sessionId: name, pid: 1, workingDirectory: "/Users/example/\(folder)",
            projectName: folder, state: state, lastActivityAt: Date().addingTimeInterval(-ago),
            iTermSessionId: nil, tmuxPaneId: nil, tmuxSocket: nil,
            source: source, activity: activity, sessionName: name, isUnread: unread
        )
    }

    /// No unread session here: its prop sits behind an open bubble and pokes out
    /// of it (a known issue, handled separately), and between Waiting and Active
    /// in the list the pointer would cross it.
    static let heroSessions = [
        session("Rewrite the parser", folder: "jsonl-spec", state: .active,
                source: .terminal(app: "Ghostty"), activity: "Edit", ago: 3),
        session("Ship the release", folder: "clawde", state: .waiting,
                source: .claudeDesktop, activity: "question", ago: 8),
        session("Tidy the docs", folder: "clawde", state: .idle,
                source: .terminal(app: "Terminal"), ago: 2400),
    ]

    struct HeroFrame: View {
        let character: PetCharacter
        let frame: PetFrame
        let mood: PetMood
        let busy: Int
        let rows: [PetBubbleRow]
        let highlighted: Int?
        let placement: PetBubblePlacement
        let panelOffset: CGPoint
        let bubbleOffset: CGPoint
        let pointer: CGPoint
        let size: CGSize
        let scale: CGFloat

        var body: some View {
            ZStack(alignment: .topLeading) {
                ReadmeAssets.backdrop
                PetView(
                    character: character, frame: frame, mood: mood, scale: scale,
                    sessionCount: busy, isBubbleShown: true, isBubbleOpen: true, jumpCount: 0
                )
                .frame(width: PetLayout.panelSize(scale: scale).width, height: PetLayout.panelSize(scale: scale).height)
                .offset(x: panelOffset.x, y: panelOffset.y)
                PetBubbleView(
                    rows: rows, isAbove: placement.isAbove, highlighted: highlighted,
                    tailX: placement.tailX, isShown: true
                )
                .frame(width: placement.frame.width, height: placement.frame.height)
                .offset(x: bubbleOffset.x, y: bubbleOffset.y)
                Image(nsImage: NSCursor.arrow.image)
                    .offset(x: pointer.x - NSCursor.arrow.hotSpot.x, y: pointer.y - NSCursor.arrow.hotSpot.y)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .environment(\.colorScheme, .dark)
        }
    }

    /// The pointer runs down the bubble's lines and back to the pet, and the pet
    /// acts out each line's session on the way — through the same entrances and
    /// exits PetPlayback plays in the app, on its own clock.
    @Test func hero() throws {
        try? FileManager.default.createDirectory(at: Self.out, withIntermediateDirectories: true)
        let scale: CGFloat = 14
        let claudie = PetCharacter.character(for: .claudie)
        let listed = PetPresenter.listed(from: Self.heroSessions)
        let rows = listed.map(PetBubbleRow.init(session:))
        let moods = listed.map { PetMood(state: $0.state, isUnread: $0.isUnread == true) }
        let own = moods[0]
        let busy = Self.heroSessions.count { $0.state != .idle || $0.isUnread == true }

        let panelSize = PetLayout.panelSize(scale: scale)
        let petOrigin = CGPoint(x: 408, y: 110)
        let panelFrame = CGRect(origin: PetLayout.panelOrigin(forPetOrigin: petOrigin, scale: scale), size: panelSize)
        let badge = PetLayout.badgeRect(scale: scale, corner: claudie.badgeCorner, count: busy, isBubbleOpen: true)
        let placement = PetLayout.bubblePlacement(
            size: PetLayout.bubbleSize(rows: rows.count),
            target: PetLayout.screenRect(badge, inPanelAt: panelFrame),
            below: petOrigin.y,
            in: CGRect(x: 0, y: 0, width: 840, height: 660)
        )
        let petOnScreen = CGRect(origin: petOrigin, size: PetLayout.petSize(scale: scale))
        let content = petOnScreen
            .union(PetLayout.screenRect(badge, inPanelAt: panelFrame))
            .union(placement.frame.insetBy(dx: PetLayout.bubbleShadowInset, dy: PetLayout.bubbleShadowInset))
            .insetBy(dx: -24, dy: -24)
        func local(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x - content.minX, y: content.maxY - point.y)
        }
        let panelOffset = local(CGPoint(x: panelFrame.minX, y: panelFrame.maxY))
        let bubbleOffset = local(CGPoint(x: placement.frame.minX, y: placement.frame.maxY))
        let petPoint = local(CGPoint(x: petOrigin.x + 12.5 * scale, y: petOnScreen.maxY - 11.5 * scale))
        func rowPoint(_ row: Int) -> CGPoint {
            let slot = placement.isAbove ? rows.count - 1 - row : row
            let outlineTop = PetLayout.bubbleShadowInset + (placement.isAbove ? 0 : PetLayout.bubbleTailHeight)
            return CGPoint(
                x: bubbleOffset.x + PetLayout.bubbleShadowInset + 96,
                y: bubbleOffset.y + outlineTop + PetLayout.bubblePadding
                    + (CGFloat(slot) + 0.55) * PetLayout.bubbleRowHeight
            )
        }

        // Where the pointer goes, and when; nil is the pet itself.
        let glide = 0.24
        let waitingRow = try #require(moods.firstIndex(of: .waiting))
        let activeRow = try #require(moods.firstIndex(of: .active))
        let stops: [(leave: Double, to: Int?)] = [(1.5, waitingRow), (3.1, activeRow), (7.0, nil)]
        let total = 9.6
        func target(_ to: Int?) -> CGPoint { to.map(rowPoint) ?? petPoint }
        func pointer(at t: Double) -> CGPoint {
            var from = petPoint
            for stop in stops {
                if t < stop.leave { return from }
                let to = target(stop.to)
                if t < stop.leave + glide {
                    let x = (t - stop.leave) / glide
                    let eased = x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
                    return CGPoint(x: from.x + (to.x - from.x) * eased, y: from.y + (to.y - from.y) * eased)
                }
                from = to
            }
            return from
        }
        // The line under the pointer, by the app's own hit test, so a line the
        // pointer only crosses lights up for the moment it is under it.
        func hovered(at t: Double) -> Int? {
            let point = pointer(at: t)
            let inBubble = CGPoint(x: point.x - bubbleOffset.x, y: point.y - bubbleOffset.y)
            return PetLayout.bubbleRow(
                at: inBubble, in: placement.frame.size, rows: rows.count, isAbove: placement.isAbove
            )
        }
        var events: [Double] = []
        for stop in stops {
            for step in 0...8 { events.append(stop.leave + glide * Double(step) / 8) }
        }
        events.sort()

        var playback = PetPlayback(character: claudie, mood: own, now: 0)
        var shownHover: Int?
        var t = 0.0
        var frames: [(CGImage, Double)] = []
        while t < total - 1e-6 {
            let hover = hovered(at: t)
            if hover != shownHover {
                shownHover = hover
                playback.play(hover.map { moods[$0] } ?? own, now: t)
            }
            while playback.nextFrameAt <= t + 1e-9 {
                playback.advance(now: t)
            }
            let view = HeroFrame(
                character: claudie, frame: playback.frame, mood: hover.map { moods[$0] } ?? own,
                busy: busy, rows: rows, highlighted: hover, placement: placement,
                panelOffset: panelOffset, bubbleOffset: bubbleOffset, pointer: pointer(at: t),
                size: content.size, scale: scale
            )
            let next = min(playback.nextFrameAt, events.first { $0 > t + 1e-9 } ?? total, total)
            // Three device pixels a point, shown at one and a half CSS pixels a
            // point: a 2x screen then draws every pixel of it once, cells and text.
            frames.append((Self.image(view, size: content.size, scale: 3), next - t))
            t = next
        }
        let (count, bytes) = try Self.writeAPNG(frames, named: "hero.png")
        print("ANIM hero.png: \(count) frames, \(bytes / 1024) KB, \(Int(content.width))x\(Int(content.height)) pt")
    }

    @Test func moods() throws {
        try? FileManager.default.createDirectory(at: Self.out, withIntermediateDirectories: true)
        let claudie = PetCharacter.character(for: .claudie)
        let moods: [(PetMood, String)] = [
            (.active, "Active"), (.waiting, "Waiting"), (.unread, "Unread"),
            (.compacting, "Compacting"), (.idle, "Idle"), (.resting, "Resting"),
        ]
        for (mood, label) in moods {
            try Self.tile(claudie, mood, label: label, accent: mood == .resting ? nil : mood.accent,
                          side: 120, cell: 4, named: "mood-\(label.lowercased()).png")
        }
    }

    @Test func cast() throws {
        try? FileManager.default.createDirectory(at: Self.out, withIntermediateDirectories: true)
        let cast: [(PetCharacterID, String)] = [
            (.claudie, "Claudie"), (.nibble, "Nibble"), (.quack, "Quack"), (.kernel, "Kernel"),
        ]
        for (id, name) in cast {
            try Self.tile(PetCharacter.character(for: id), .active, label: name, accent: nil,
                          side: 136, cell: 5, named: "cast-\(name.lowercased()).png")
        }
    }
}
