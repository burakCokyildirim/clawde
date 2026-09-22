import Foundation

nonisolated extension PetCharacter {

    /// Pulls a laptop out from behind itself and types, stopping now and then to
    /// think. Writes a question over its head while it is waiting on you, and dozes
    /// off when the session is idle.
    static let claudie = PetCharacter(
        palette: [
            "b": 0xD1684A, "e": 0x000000, "g": 0x7C7C7B, "w": 0xF4F1EC
        ],
        badgeCorner: CGPoint(x: 6.3, y: 7.0),
        active: PetRoutine(
            // Rummages behind itself, hauls the laptop up over its head and sets it down.
            enter: [
                PetFrame(250, Part.rest.at(0, 5)),
                PetFrame(83, Part.rummageA.at(0, 5)),
                PetFrame(74, Part.rummageB.at(0, 5)),
                PetFrame(91, Part.rummageA.at(0, 5)),
                PetFrame(175, Part.rummageB.at(0, 5)),
                PetFrame(83, Part.liftA.at(0, 5)),
                PetFrame(166, Part.liftB.at(0, 5)),
                PetFrame(83, Part.swing.at(0, 5)),
                PetFrame(75, Part.laptop.at(1, 13), Part.setDown.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 13), Part.upright.at(0, 5)),
                PetFrame(140, Part.laptop.at(1, 13), Part.cheer.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 13), Part.lean.at(0, 5)),
            ],
            // Keystrokes bounce the laptop a row; now and then the hands rest while it
            // looks away to think.
            loop: [
                PetFrame(83, Part.laptop.at(1, 13), Part.typeMid.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 13), Part.typeHigh.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 12), Part.typeLow.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 13), Part.typeMid.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 13), Part.typeHigh.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 12), Part.typeLow.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 13), Part.typeMid.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 12), Part.typeLow.at(0, 5)),
                PetFrame(360, Part.laptop.at(1, 13), Part.typeMid.at(0, 5)),
                PetFrame(420, Part.laptop.at(1, 13), Part.thinkRight.at(0, 5)),
                PetFrame(300, Part.laptop.at(1, 13), Part.typeMid.at(0, 5)),
                PetFrame(260, Part.laptop.at(1, 13), Part.thinkRight.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 13), Part.typeHigh.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 12), Part.typeLow.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 13), Part.typeMid.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 12), Part.typeLow.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 13), Part.typeHigh.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 13), Part.typeMid.at(0, 5)),
            ],
            // Picks the laptop up and tucks it away behind itself.
            exit: [
                PetFrame(83, Part.laptop.at(1, 13), Part.reach.at(0, 5)),
                PetFrame(83, Part.laptop.at(1, 13), Part.reach.at(0, 5)),
                PetFrame(83, Part.pickup.at(0, 5)),
                PetFrame(83, Part.tuck.at(0, 5)),
                PetFrame(166, Part.rummageB.at(0, 5)),
                PetFrame(83, Part.rummageA.at(0, 5)),
                PetFrame(83, Part.settle.at(0, 5)),
            ]
        ),
        // Writes a question over its head, looking up at it as it goes, lets the
        // dot drop in, and waits. Then it fidgets, and writes it again. The mark
        // stays put: it is the question, and Claudie is the one who is waiting.
        waiting: PetRoutine(
            loop: [
                PetFrame(250, Part.rest.at(0, 5)),
                PetFrame(70, Part.lookUp.at(0, 5), PetProp.questionStrokes[0].at(15, 1)),
                PetFrame(70, Part.lookUp.at(0, 5), PetProp.questionStrokes[1].at(15, 1)),
                PetFrame(70, Part.lookUp.at(0, 5), PetProp.questionStrokes[2].at(15, 1)),
                PetFrame(70, Part.lookUp.at(0, 5), PetProp.questionStrokes[3].at(15, 1)),
                PetFrame(70, Part.lookUp.at(0, 5), PetProp.questionStrokes[4].at(15, 1)),
                PetFrame(70, Part.lookUp.at(0, 5), PetProp.questionStrokes[5].at(15, 1)),
                PetFrame(60, Part.lookUp.at(0, 5), PetProp.questionDotFalling.at(15, 1)),
                PetFrame(90, Part.lookUp.at(0, 5), PetProp.question.at(15, 1)),
                PetFrame(60, Part.lookUp.at(0, 5), PetProp.questionDotFalling.at(15, 1)),
                PetFrame(1000, Part.rest.at(0, 5), PetProp.question.at(15, 1)),
                // Fidgets from side to side.
                PetFrame(50, Part.rest.at(1, 5), PetProp.question.at(15, 1)),
                PetFrame(50, Part.rest.at(-1, 5), PetProp.question.at(15, 1)),
                PetFrame(50, Part.rest.at(1, 5), PetProp.question.at(15, 1)),
                PetFrame(50, Part.rest.at(-1, 5), PetProp.question.at(15, 1)),
                PetFrame(60, Part.rest.at(0, 5), PetProp.question.at(15, 1)),
                PetFrame(500, Part.rest.at(0, 5), PetProp.question.at(15, 1)),
                PetFrame(140, Part.eyesShut.at(0, 5), PetProp.question.at(15, 1)),
                PetFrame(300, Part.rest.at(0, 5), PetProp.question.at(15, 1)),
            ],
            // Held still, it has to say question on its own.
            still: 10
        ),
        unread: PetRoutine(
            loop: [
                PetFrame(520, Part.rest.at(0, 5), PetProp.bubble.at(13, 0)),
                PetFrame(520, Part.rest.at(0, 5), PetProp.bubble.at(13, 1)),
                PetFrame(520, Part.rest.at(0, 5), PetProp.bubble.at(13, 0)),
                PetFrame(140, Part.eyesShut.at(0, 5), PetProp.bubble.at(13, 1)),
            ]
        ),
        compacting: PetRoutine(
            loop: [
                PetFrame(160, Part.rest.at(0, 5)),
                PetFrame(160, Part.squishA.at(0, 5)),
                PetFrame(320, Part.squishB.at(0, 5), PetProp.dust.at(3, 13), PetProp.dust.at(17, 13)),
                PetFrame(160, Part.squishA.at(0, 5)),
            ],
            still: 2
        ),
        idle: PetRoutine(
            loop: [
                PetFrame(460, Part.doze.at(0, 5), PetProp.snore.at(14, 3)),
                PetFrame(460, Part.sleep.at(0, 5), PetProp.snore.at(15, 2)),
                PetFrame(460, Part.doze.at(0, 5), PetProp.snore.at(15, 1)),
                PetFrame(460, Part.sleep.at(0, 5), PetProp.snore.at(16, 0)),
                PetFrame(460, Part.doze.at(0, 5)),
            ]
        ),
        resting: PetRoutine(
            loop: [
                PetFrame(2400, Part.rest.at(0, 5)),
                PetFrame(140, Part.eyesShut.at(0, 5)),
            ]
        )
    )
}

/// Claudie's pieces, each placed on the canvas by the frames above.
nonisolated private enum Part {

    /// The laptop, open, seen from the side. A layer of its own, so a keystroke
    /// can bounce it a row.
    static let laptop: PetPart = [
        "g....",
        "gg...",
        ".gggg",
    ]

    static let rest: PetPart = [
        "....................",
        "....................",
        "....................",
        "........bbbbbbbb....",
        "........bebbbbeb....",
        "......bbbbbbbbbbbb..",
        "......bbbbbbbbbbbb..",
        "........bbbbbbbb....",
        "........bbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]

    /// Eyes up a row: it looks at what is over its head.
    static let lookUp: PetPart = [
        "....................",
        "....................",
        "....................",
        "........bebbbbeb....",
        "........bbbbbbbb....",
        "......bbbbbbbbbbbb..",
        "......bbbbbbbbbbbb..",
        "........bbbbbbbb....",
        "........bbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]

    static let eyesShut: PetPart = [
        "....................",
        "....................",
        "....................",
        "........bbbbbbbb....",
        "........bbbbbbbb....",
        "......bbbbbbbbbbbb..",
        "......bbbbbbbbbbbb..",
        "........bbbbbbbb....",
        "........bbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]

    static let rummageA: PetPart = [
        "....................",
        "....................",
        "....................",
        "........bbbbbbbb....",
        "........bbbbbbbbbb..",
        "........bebbbbebbb..",
        "......bbbbbbbbbb....",
        "......bbbbbbbbbb....",
        "........bbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]

    static let rummageB: PetPart = [
        "....................",
        "....................",
        "....................",
        "........bbbbbbbb....",
        "........bbbbbbbbbb..",
        "........bebbbbebbb..",
        "........bbbbbbbb....",
        "......bbbbbbbbbb....",
        "......bbbbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]

    static let liftA: PetPart = [
        "....................",
        "......g.............",
        "....gg..............",
        "....ggg.bbbbbbbb....",
        "......bbbebbbbeb....",
        "......bbbbbbbbbbbb..",
        "........bbbbbbbbbb..",
        "........bbbbbbbb....",
        "........bbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]

    static let liftB: PetPart = [
        "....g...............",
        "....g...............",
        "......bb............",
        "......bbbbbbbbbb....",
        "........bebbbbeb....",
        "........bbbbbbbbbb..",
        "........bbbbbbbbbb..",
        "........bbbbbbbbbb..",
        "........bbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]

    static let swing: PetPart = [
        "....................",
        "....................",
        "....................",
        "........bbbbbbbb....",
        "..g.....bebbbbeb....",
        ".ggg...bbbbbbbbbbb..",
        "..gggggbbbbbbbbbbb..",
        "...gggbbbbbbbbbb....",
        "......bbbbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]

    static let setDown: PetPart = [
        "....................",
        "....................",
        "....................",
        "........bbbbbbbb....",
        "........bebbbbeb....",
        "........bbbbbbbbbb..",
        "........bbbbbbbbbb..",
        "......bbbbbbbbbbbb..",
        "......bbbbbbbbbb....",
        "......bbb.b..b.b....",
        "........b.b..b.b....",
    ]

    static let upright: PetPart = [
        "....................",
        "....................",
        "....................",
        "........bbbbbbbb....",
        "........bebbbbebbb..",
        "......bbbbbbbbbbbb..",
        "......bbbbbbbbbb....",
        "........bbbbbbbb....",
        "........bbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]

    static let cheer: PetPart = [
        ".......bb....bb.....",
        ".......bb....bb.....",
        ".......bbbbbbbb.....",
        ".......bbbbbbbb.....",
        ".......bebbbbeb.....",
        ".......bbbbbbbb.....",
        ".......bbbbbbbb.....",
        ".......bbbbbbbb.....",
        ".......bbbbbbbb.....",
        ".......b.b..b.b.....",
        ".......b.b..b.b.....",
    ]

    static let lean: PetPart = [
        "....................",
        "....................",
        "....................",
        "....................",
        ".......bbbbbbbb.....",
        ".......ebbbebbb.....",
        ".......bbbbbbbb.....",
        ".......bbbbbbbb.....",
        ".......bbbbbbbb.....",
        ".......b.b..b.b.....",
        ".......b.b..b.b.....",
    ]

    static let typeHigh: PetPart = [
        "....................",
        "....................",
        "....................",
        "....................",
        ".......bbbbbbbb.....",
        ".......ebbbebbb.....",
        ".....bbbbbbbbbb.....",
        ".....bbbbbbbbbb.....",
        ".......bbbbbbbb.....",
        ".......b.b..b.b.....",
        ".......b.b..b.b.....",
    ]

    static let typeMid: PetPart = [
        "....................",
        "....................",
        "....................",
        "....................",
        ".......bbbbbbbb.....",
        ".......ebbbebbb.....",
        ".......bbbbbbbb.....",
        ".....bbbbbbbbbb.....",
        ".....bbbbbbbbbb.....",
        ".......b.b..b.b.....",
        ".......b.b..b.b.....",
    ]

    static let typeLow: PetPart = [
        "....................",
        "....................",
        "....................",
        "....................",
        ".......bbbbbbbb.....",
        ".......ebbbebbb.....",
        ".......bbbbbbbb.....",
        ".......bbbbbbbb.....",
        ".....bbbbbbbbbb.....",
        ".....bbb.b..b.b.....",
        ".......b.b..b.b.....",
    ]

    static let thinkRight: PetPart = [
        "....................",
        "....................",
        "....................",
        "....................",
        ".......bbbbbbbb.....",
        ".......bebbbebb.....",
        ".......bbbbbbbb.....",
        ".....bbbbbbbbbb.....",
        ".....bbbbbbbbbb.....",
        ".......b.b..b.b.....",
        ".......b.b..b.b.....",
    ]

    static let reach: PetPart = [
        "....................",
        "....................",
        "....................",
        "....................",
        ".......bbbbbbbb.....",
        ".......ebbbebbb.....",
        ".......bbbbbbbb.....",
        ".....bbbbbbbbbb.....",
        ".....bbbbbbbbbb.....",
        ".....bbb.b..b.b.....",
        ".......b.b..b.b.....",
    ]

    static let pickup: PetPart = [
        "....................",
        "....................",
        "....................",
        ".......bbbbbbbb.....",
        "......bbbbbbbbb.....",
        ".....bbebbbebbb.....",
        "..g..bbbbbbbbbbb....",
        "..gg..bbbbbbbbbb....",
        "...ggbbbbbbbbbbb....",
        ".......b.b..b.b.....",
        ".......b.b..b.b.....",
    ]

    static let tuck: PetPart = [
        "....................",
        "....................",
        "....................",
        "........bbbbbbbb....",
        "........ebbbbebb....",
        "......gbbbbbbbbbb...",
        "....ggbbbbbbbbbbb...",
        "....gbbbbbbbbbbbb...",
        "....ggg.bbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]

    static let settle: PetPart = [
        "....................",
        "....................",
        "....................",
        "........bbbbbbbb....",
        "........bebbbbeb....",
        "......bbbbbbbbbbbb..",
        "......bbbbbbbbbbbb..",
        "......bbbbbbbbbbbb..",
        "........bbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]

    static let waveA: PetPart = [
        "....................",
        "....................",
        "....................",
        "........bbbbbbbbbb..",
        "........bebbbbebbb..",
        "......bbbbbbbbbb....",
        "......bbbbbbbbbb....",
        "........bbbbbbbb....",
        "........bbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]

    static let waveB: PetPart = [
        "....................",
        "....................",
        "................bb..",
        "........bbbbbbbbbb..",
        "........bebbbbeb....",
        "......bbbbbbbbbb....",
        "......bbbbbbbbbb....",
        "........bbbbbbbb....",
        "........bbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]

    static let squishA: PetPart = [
        "....................",
        "....................",
        "....................",
        "....................",
        "........bbbbbbbb....",
        "........bebbbbeb....",
        "......bbbbbbbbbbbb..",
        "......bbbbbbbbbbbb..",
        "........bbbbbbbb....",
        "........bbbbbbbb....",
        "........b.b..b.b....",
    ]

    static let squishB: PetPart = [
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        ".......bbbbbbbbbb...",
        ".......bebbbbbbeb...",
        ".....bbbbbbbbbbbbbb.",
        ".....bbbbbbbbbbbbbb.",
        ".......bbbbbbbbbb...",
        ".......b.b....b.b...",
    ]

    /// Asleep, breathing out: the arms sink a row, and the eyes are shut to lines.
    static let doze: PetPart = [
        "....................",
        "....................",
        "....................",
        "........bbbbbbbb....",
        "........beebbeeb....",
        "........bbbbbbbb....",
        "......bbbbbbbbbbbb..",
        "......bbbbbbbbbbbb..",
        "........bbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]

    /// Asleep, breathing in: sitting up as it rests, eyes still shut.
    static let sleep: PetPart = [
        "....................",
        "....................",
        "....................",
        "........bbbbbbbb....",
        "........beebbeeb....",
        "......bbbbbbbbbbbb..",
        "......bbbbbbbbbbbb..",
        "........bbbbbbbb....",
        "........bbbbbbbb....",
        "........b.b..b.b....",
        "........b.b..b.b....",
    ]
}
