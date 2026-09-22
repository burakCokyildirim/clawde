import SwiftUI

/// A piece of pixel art: rows of palette keys, with `.` transparent.
nonisolated struct PetPart: ExpressibleByArrayLiteral {

    let rows: [String]

    init(arrayLiteral rows: String...) {
        self.rows = rows
    }

    /// This part with its top-left corner at column `x`, row `y` of the canvas.
    func at(_ x: Int, _ y: Int) -> PetLayer {
        PetLayer(part: self, x: x, y: y)
    }
}

/// A part placed on the canvas.
nonisolated struct PetLayer {
    let part: PetPart
    let x: Int
    let y: Int
}

/// One drawing of the pet, and how long it stays up.
///
/// Composed once, when its character is first used, so showing a frame is only
/// ever a walk over finished rows.
nonisolated struct PetFrame: Equatable {

    let duration: TimeInterval

    /// `PetLayout.gridHeight` rows of `PetLayout.gridWidth` palette keys.
    let rows: [String]

    /// Stacks `layers` bottom first. A layer's `.` lets whatever is beneath show
    /// through, and anything that falls off the canvas is cut away.
    init(_ milliseconds: Int, _ layers: PetLayer...) {
        var grid = Array(
            repeating: Array(repeating: Character("."), count: PetLayout.gridWidth),
            count: PetLayout.gridHeight
        )
        for layer in layers {
            for (rowOffset, line) in layer.part.rows.enumerated() {
                let row = layer.y + rowOffset
                guard grid.indices.contains(row) else { continue }
                for (columnOffset, key) in line.enumerated() where key != "." {
                    let column = layer.x + columnOffset
                    guard grid[row].indices.contains(column) else { continue }
                    grid[row][column] = key
                }
            }
        }
        duration = TimeInterval(milliseconds) / 1000
        rows = grid.map { String($0) }
    }
}

/// What the pet is acting out.
///
/// Unread is a mood of its own although it is not a `SessionState`: the hook
/// reports those sessions idle, but a pet that has something to tell you should
/// not look like it has dozed off. It ranks where `attentionRank` puts it, below
/// waiting.
nonisolated enum PetMood: CaseIterable {
    case active
    case waiting
    case unread
    case compacting
    case idle
    /// No session to stand for, while the pet stays out anyway.
    case resting

    init(state: SessionState?, isUnread: Bool) {
        guard let state else {
            self = .resting
            return
        }
        switch state {
        case .waiting: self = .waiting
        case _ where isUnread: self = .unread
        case .active: self = .active
        case .compacting: self = .compacting
        case .idle: self = .idle
        }
    }
}

/// How a character acts out one mood.
nonisolated struct PetRoutine {

    /// Played once on the way into the mood.
    let enter: [PetFrame]?
    let loop: [PetFrame]
    /// Played once on the way out of it.
    let exit: [PetFrame]?
    /// The loop frame drawn when motion is reduced: the one that says the most
    /// on its own.
    let still: Int

    init(enter: [PetFrame]? = nil, loop: [PetFrame], exit: [PetFrame]? = nil, still: Int = 0) {
        self.enter = enter
        self.loop = loop
        self.exit = exit
        self.still = still
    }
}

/// A pet character: a palette, and a routine for every mood.
///
/// Every motion is drawn, frame by frame, on a canvas of `PetLayout.gridWidth` by
/// `PetLayout.gridHeight` cells, with the feet on the bottom row. The drawings
/// live one character per file under `Characters/`, built from parts placed on
/// that canvas, so a pose is drawn once however many frames use it.
nonisolated struct PetCharacter {

    let active: PetRoutine
    let waiting: PetRoutine
    let unread: PetRoutine
    let compacting: PetRoutine
    let idle: PetRoutine
    let resting: PetRoutine

    /// Where the count badge's bottom-right corner sits, in canvas cells: up and
    /// to the left of the character's head, so the badge grows away from it.
    let badgeCorner: CGPoint

    /// Fixed rather than theme-derived: the pet floats over arbitrary wallpapers,
    /// so it carries its own contrast instead of borrowing the system appearance.
    private let palette: [Character: Color]

    init(
        palette: [Character: UInt32],
        badgeCorner: CGPoint,
        active: PetRoutine,
        waiting: PetRoutine,
        unread: PetRoutine,
        compacting: PetRoutine,
        idle: PetRoutine,
        resting: PetRoutine
    ) {
        self.palette = palette.mapValues { rgb in
            Color(
                red: Double(rgb >> 16 & 0xFF) / 255,
                green: Double(rgb >> 8 & 0xFF) / 255,
                blue: Double(rgb & 0xFF) / 255
            )
        }
        self.badgeCorner = badgeCorner
        self.active = active
        self.waiting = waiting
        self.unread = unread
        self.compacting = compacting
        self.idle = idle
        self.resting = resting
    }

    static func character(for id: PetCharacterID) -> PetCharacter {
        switch id {
        case .claudie: claudie
        case .nibble: nibble
        case .quack: quack
        case .kernel: kernel
        }
    }

    func routine(for mood: PetMood) -> PetRoutine {
        switch mood {
        case .active: active
        case .waiting: waiting
        case .unread: unread
        case .compacting: compacting
        case .idle: idle
        case .resting: resting
        }
    }

    /// The single frame drawn for `mood` when motion is reduced.
    func still(for mood: PetMood) -> PetFrame {
        let routine = routine(for: mood)
        return routine.loop[routine.still]
    }

    /// The colour a palette key maps to, or `nil` where the pet is transparent.
    func color(for key: Character) -> Color? {
        palette[key]
    }
}

// MARK: - Props

/// The props every character shares, so a sleeping pet snores the same "z"
/// whoever it is.
nonisolated enum PetProp {

    /// A "z", drifting up while it sleeps.
    static let snore: PetPart = [
        "wwww",
        "..w.",
        ".w..",
        "wwww",
    ]

    /// A speech bubble holding "...": there is something to read.
    static let bubble: PetPart = [
        ".wwwww.",
        "wwwwwww",
        "wewewew",
        "wwwwwww",
        ".ww....",
    ]

    /// A puff of dust, kicked up while it squeezes.
    static let dust: PetPart = [
        ".w.",
        "w.w",
    ]

    /// A question mark, for a session that is waiting on you.
    static let question: PetPart = [
        ".ww.",
        "w..w",
        "...w",
        "..w.",
        "....",
        "..w.",
    ]

    /// The same mark being written: the hook a stroke at a time, then with its
    /// dot a row high on its way down. `question` is where the dot lands.
    static let questionStrokes: [PetPart] = [
        ["....", "w...", "....", "....", "....", "...."],
        [".w..", "w...", "....", "....", "....", "...."],
        [".ww.", "w...", "....", "....", "....", "...."],
        [".ww.", "w..w", "....", "....", "....", "...."],
        [".ww.", "w..w", "...w", "....", "....", "...."],
        [".ww.", "w..w", "...w", "..w.", "....", "...."],
    ]
    static let questionDotFalling: PetPart = [".ww.", "w..w", "...w", "..w.", "..w.", "...."]
}
