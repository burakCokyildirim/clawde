import CoreGraphics
import Foundation
import Testing
@testable import Clawde

@MainActor
struct PetCharacterTests {

    private static let characters = PetCharacterID.allCases.map(PetCharacter.character(for:))

    private func clips(of routine: PetRoutine) -> [[PetFrame]] {
        [routine.enter, routine.loop, routine.exit].compactMap { $0 }
    }

    /// The renderer walks rows and columns directly, so a frame of the wrong size
    /// would draw shifted or cut off rather than fail.
    @Test func everyFrameFillsTheCanvas() {
        for character in Self.characters {
            for mood in PetMood.allCases {
                for frame in clips(of: character.routine(for: mood)).joined() {
                    #expect(frame.rows.count == PetLayout.gridHeight)
                    for row in frame.rows {
                        #expect(row.count == PetLayout.gridWidth)
                    }
                }
            }
        }
    }

    /// A key missing from the palette would silently draw as a hole.
    @Test func everyKeyDrawnHasAColour() {
        for character in Self.characters {
            for mood in PetMood.allCases {
                for frame in clips(of: character.routine(for: mood)).joined() {
                    for key in frame.rows.joined() where key != "." {
                        #expect(character.color(for: key) != nil, "no colour for \(key)")
                    }
                }
            }
        }
    }

    /// An empty clip has no frame to show, and a frame with no duration would
    /// spin the driver.
    @Test func everyClipHasFramesThatTakeTime() {
        for character in Self.characters {
            for mood in PetMood.allCases {
                let routine = character.routine(for: mood)
                for clip in clips(of: routine) {
                    #expect(!clip.isEmpty)
                    #expect(clip.allSatisfy { $0.duration > 0 })
                }
                #expect(routine.loop.indices.contains(routine.still))
            }
        }
    }

    /// Under Reduce Motion one frame has to carry the whole mood.
    @Test func eachMoodStandsApartEvenStandingStill() {
        for character in Self.characters {
            let stills = PetMood.allCases.map { character.still(for: $0).rows }
            for (index, still) in stills.enumerated() {
                for other in stills[(index + 1)...] {
                    #expect(still != other)
                }
            }
        }
    }

    /// The question is written a stroke at a time and ends as the finished mark,
    /// so the loop never shows a stroke that is not in it.
    @Test func theQuestionIsWrittenOneStrokeAtATimeIntoTheFinishedMark() {
        func cells(_ part: PetPart) -> Set<[Int]> {
            var set = Set<[Int]>()
            for (y, row) in part.rows.enumerated() {
                for (x, key) in row.enumerated() where key != "." { set.insert([x, y]) }
            }
            return set
        }
        let finished = cells(PetProp.question)
        var drawn = Set<[Int]>()
        for stroke in PetProp.questionStrokes {
            let now = cells(stroke)
            #expect(now.isSuperset(of: drawn))
            #expect(now.count == drawn.count + 1)
            #expect(now.isSubset(of: finished))
            drawn = now
        }
        // The hook is done, and the dot is all that is left to drop in.
        #expect(finished.subtracting(drawn).count == 1)
        #expect(cells(PetProp.questionDotFalling).subtracting(drawn).count == 1)
    }

    /// Claudie waiting, held still under Reduce Motion, still has its question up.
    @Test func claudieStillAsksWhenMotionIsReduced() {
        let still = PetCharacter.claudie.still(for: .waiting)
        let question = PetFrame(0, PetProp.question.at(15, 1))
        for (y, row) in question.rows.enumerated() {
            for (x, key) in row.enumerated() where key != "." {
                let drawn = Array(still.rows[y])[x]
                #expect(drawn == key)
            }
        }
    }

    @Test func aFrameStacksItsLayersAndCutsAwayWhatFallsOffTheCanvas() {
        let back: PetPart = ["aaa", "aaa"]
        let front: PetPart = ["b.b"]
        let frame = PetFrame(100, back.at(-1, -1), front.at(0, 0), back.at(18, 15))

        #expect(frame.duration == 0.1)
        #expect(frame.rows[0].hasPrefix("bab."))
        #expect(frame.rows[1] == String(repeating: ".", count: PetLayout.gridWidth))
        #expect(frame.rows[15].hasSuffix("..aa"))
    }

    /// Unread ranks where `attentionRank` puts it: above everything but waiting.
    @Test func moodFollowsStateAndUnread() {
        #expect(PetMood(state: .waiting, isUnread: true) == .waiting)
        #expect(PetMood(state: .idle, isUnread: true) == .unread)
        #expect(PetMood(state: .active, isUnread: true) == .unread)
        #expect(PetMood(state: .compacting, isUnread: true) == .unread)
        #expect(PetMood(state: .idle, isUnread: false) == .idle)
        #expect(PetMood(state: .active, isUnread: false) == .active)
        #expect(PetMood(state: .compacting, isUnread: false) == .compacting)
        #expect(PetMood(state: nil, isUnread: false) == .resting)
    }

    @Test func claudieIsTheDefaultAndStandsInForACharacterThatIsGone() {
        let suite = "PetCharacterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)
        defer { defaults?.removePersistentDomain(forName: suite) }
        #expect(PetSettings.load(from: defaults).character == .claudie)

        defaults?.set("lint", forKey: PetSettings.Keys.character)
        #expect(PetSettings.load(from: defaults).character == .claudie)

        defaults?.set("quack", forKey: PetSettings.Keys.character)
        #expect(PetSettings.load(from: defaults).character == .quack)
    }
}

struct PetPlaybackTests {

    /// A character whose frames name themselves in their top row, a tenth of a
    /// second each: `E` enter, `L` loop, `X` exit.
    private static let character = PetCharacter(
        palette: [:],
        badgeCorner: .zero,
        active: PetRoutine(enter: frames("E", 2), loop: frames("L", 3), exit: frames("X", 2)),
        waiting: PetRoutine(loop: frames("W", 2)),
        unread: PetRoutine(loop: frames("U", 1)),
        compacting: PetRoutine(loop: frames("C", 1)),
        idle: PetRoutine(loop: frames("I", 2)),
        resting: PetRoutine(loop: frames("R", 1))
    )

    private static func frames(_ tag: String, _ count: Int) -> [PetFrame] {
        (0..<count).map { PetFrame(100, PetPart(arrayLiteral: "\(tag)\($0)").at(0, 0)) }
    }

    private func name(_ playback: PetPlayback) -> String {
        String(playback.frame.rows[0].prefix(2))
    }

    /// The frames shown from now on, the current one first, each left up for
    /// exactly its time.
    private func names(_ playback: inout PetPlayback, count: Int) -> [String] {
        var shown = [name(playback)]
        for _ in 1..<count {
            let advanced = playback.advance(now: playback.nextFrameAt)
            #expect(advanced)
            shown.append(name(playback))
        }
        return shown
    }

    @Test func startsInTheLoopWithoutPlayingTheEntrance() {
        var playback = PetPlayback(character: Self.character, mood: .active, now: 0)
        #expect(names(&playback, count: 4) == ["L0", "L1", "L2", "L0"])
    }

    @Test func holdsEachFrameForItsTime() {
        var playback = PetPlayback(character: Self.character, mood: .idle, now: 0)
        let early = playback.advance(now: 0.05)
        #expect(!early)
        #expect(name(playback) == "I0")
        let due = playback.advance(now: 0.1)
        #expect(due)
        #expect(name(playback) == "I1")
    }

    @Test func comesInThroughTheEntrance() {
        var playback = PetPlayback(character: Self.character, mood: .idle, now: 0)
        playback.play(.active, now: 0)
        #expect(names(&playback, count: 6) == ["E0", "E1", "L0", "L1", "L2", "L0"])
    }

    @Test func leavesThroughTheExit() {
        var playback = PetPlayback(character: Self.character, mood: .active, now: 0)
        playback.play(.idle, now: 0)
        #expect(names(&playback, count: 5) == ["X0", "X1", "I0", "I1", "I0"])
    }

    /// Cutting an entrance short would leave the drawing half way through a move.
    @Test func anEntranceRunsToItsEndWhenTheMoodMovesOn() {
        var playback = PetPlayback(character: Self.character, mood: .idle, now: 0)
        playback.play(.active, now: 0)
        playback.play(.waiting, now: 0)
        #expect(names(&playback, count: 6) == ["E0", "E1", "X0", "X1", "W0", "W1"])
    }

    @Test func aMoodThatComesBackDuringItsExitReturnsThroughItsEntrance() {
        var playback = PetPlayback(character: Self.character, mood: .active, now: 0)
        playback.play(.idle, now: 0)
        playback.play(.active, now: 0)
        #expect(names(&playback, count: 5) == ["X0", "X1", "E0", "E1", "L0"])
    }

    @Test func aLoopGivesWayAtOnce() {
        var playback = PetPlayback(character: Self.character, mood: .waiting, now: 0)
        playback.advance(now: 0.1)
        playback.play(.unread, now: 0.15)
        #expect(name(playback) == "U0")
        #expect(abs(playback.nextFrameAt - 0.25) < 1e-9)
    }

    /// The pet is on screen all day, and its timer is the part of it that costs
    /// energy: none while nobody can see it move.
    @Test func theFrameTimerRunsOnlyWhileThePetCanBeSeenMoving() {
        func delay(onScreen: Bool, reduceMotion: Bool, due nextFrameAt: TimeInterval) -> TimeInterval? {
            PetWindowController.frameTimerDelay(
                isOnScreen: onScreen,
                reduceMotion: reduceMotion,
                nextFrameAt: nextFrameAt,
                now: 10
            )
        }
        #expect(delay(onScreen: true, reduceMotion: false, due: 10.25) == 0.25)
        #expect(delay(onScreen: true, reduceMotion: false, due: 9) == 0)
        #expect(delay(onScreen: false, reduceMotion: false, due: 10.25) == nil)
        #expect(delay(onScreen: true, reduceMotion: true, due: 10.25) == nil)
    }

    /// The pet hops when a session takes up something new, and stays put for the
    /// housekeeping the Claude app does on its own.
    @Test func thePetHopsWhenASessionTakesUpSomethingNew() {
        let before = ["a": PetMood.active, "b": .idle]

        #expect(PetWindowController.hops(from: before, to: ["a": .waiting, "b": .idle]))
        #expect(PetWindowController.hops(from: before, to: ["a": .active, "b": .idle, "c": .active]))
        #expect(!PetWindowController.hops(from: before, to: before))
        #expect(!PetWindowController.hops(from: before, to: ["a": .active]))
    }

    /// A pet that was off screen does not race through the frames it missed.
    @Test func stepsOnceAfterAPause() {
        var playback = PetPlayback(character: Self.character, mood: .active, now: 0)
        let advanced = playback.advance(now: 3600)
        #expect(advanced)
        #expect(name(playback) == "L1")
        #expect(abs(playback.nextFrameAt - 3600.1) < 1e-9)
    }
}
