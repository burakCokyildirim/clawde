# Making a character

The pet is drawn frame by frame, and adding one of your own takes a single Swift file: a palette,
a few parts drawn as rows of letters, and a routine for each of six moods. No image editor and no
image files.

The easiest way in is Claude Code. Open this repository in it and run `/new-character`. It asks
what you have in mind, draws it with you, shows you a preview of every mood and wires it into the
app. This page is what that skill works from, and all you need to do it by hand.

## The canvas

Every frame is 20 cells wide and 16 high. Column 0 is the left edge, row 0 the top, and the
character stands on row 15. Anything drawn past an edge is cut off.

Two corners are spoken for:

- **Top left** is where the count badge hangs, from `badgeCorner`. In every mood but active, keep
  the character clear of it.
- **Top right**, roughly columns 12 to 19 and rows 0 to 5, is where the shared props float: the
  question mark (4 cells wide, 6 tall) at about column 15, row 1; the unread bubble (7 wide) at
  about column 12, row 0; the sleeping "z" drifting up from about column 14, row 2. Leave them
  room.

At the smallest size a cell is 3 points, so the whole pet is 60 × 48. A character about 12 to 16
cells wide and 9 to 14 tall still reads at that size.

## Palette

`palette` maps one letter to one colour, written `0xRRGGBB`, and `.` is transparent. Two letters
are shared with the props, so every palette needs them:

- `w`, a light colour: the question mark, the "z", the bubble, the dust.
- `e`, a dark one: the dots in the unread bubble. Most characters use it for their eyes too.

The pet floats over whatever wallpaper you have, light or dark, so give it contrast of its own: a
dark outline like Nibble's `o`, or a body colour strong enough to stand on both. Four to eight
colours is plenty. Every letter you draw has to be in the palette; a test checks.

## Parts and frames

Draw each piece once, as rows of letters, in a private `Part` enum at the bottom of your file. Place
it with `.at(column, row)`, which puts its top-left corner there. A frame stacks its layers bottom
first and lasts as many milliseconds as you give it:

```swift
PetFrame(150, Part.legs.at(0, 13), Part.head.at(0, 4), Part.eye.at(6, 7), Part.eye.at(11, 7))
```

A part can be as wide as the canvas, padded with `.`, or as small as one eye. Most motion is a
part moved by a cell: the head at row 3 instead of 4 is a bob, the whole body a row lower is a
squash. A pose you use in many frames, arms up or eyes shut, is simply another part.

[`Nibble.swift`](../Clawde/Pet/Characters/Nibble.swift) is the shortest character to read and
[`Claudie.swift`](../Clawde/Pet/Characters/Claudie.swift) the most elaborate.

## The six moods

Each mood is a `PetRoutine`: a `loop` that plays for as long as the mood lasts, an optional `enter`
played once on the way in, an optional `exit` played once on the way out, and `still`, the loop
frame shown instead of the animation when Reduce Motion is on.

| Mood | When | It should say | Shared prop |
|---|---|---|---|
| `active` | Claude is working | "I'm on it". This is the character's own move | none, bring your own |
| `waiting` | Claude needs an answer | "I have a question" | `PetProp.question`, or `PetProp.questionStrokes` to write it |
| `unread` | Claude answered and you have not looked | "There's something to read" | `PetProp.bubble` |
| `compacting` | The context is being compacted | squeezing down | `PetProp.dust` |
| `idle` | Nothing is going on | asleep | `PetProp.snore` |
| `resting` | No sessions at all | awake and calm, with a blink now and then | none |

Waiting is the one people act on, so whatever the character does, a question mark should be part
of it.

Use `enter` and `exit` when a mood brings something in. If the character pulls out a laptop to
work, the entrance hauls it out and the exit puts it away, so it never vanishes in mid-air.

The tests hold every character to a few rules:

- Every frame fills 20 × 16, every clip has at least one frame, and every frame lasts some time.
- The six still frames all differ, so each mood reads even with motion off.
- In every mood but active, nothing is drawn within a few points of the badge.

## Timing

Frames usually last between 70 and 600 milliseconds, and a held pose can take a second or more.
Let the character move at its own pace. Anything that flips back and forth faster than about 150
ms looks like shivering, so keep quick frames for single beats (a pop, a blink of 120 to 150 ms)
and out of repeating motion. A loop of 1.5 to 4 seconds feels alive without getting busy, which
matters for something that sits on screen all day.

## The badge corner

`badgeCorner` is where the bottom-right corner of the count badge sits, in canvas cells: up and to
the left of the head, in the air beside it. Nibble's is `(2.6, 3.6)`. The preview draws the
character with its badge up so you can check it.

## Wiring it in

1. Put your file in `Clawde/Pet/Characters/`. Xcode picks it up by itself.
2. Add a case to `PetCharacterID` in [`PetSettings.swift`](../Clawde/Pet/PetSettings.swift), with
   a `label` and a one-line `blurb` for under the picker in Settings.
3. Add it to the `switch` in `PetCharacter.character(for:)` in
   [`PetCharacter.swift`](../Clawde/Pet/PetCharacter.swift).

The tests go through every `PetCharacterID`, so from here on yours is checked with the rest.

## Previewing

```bash
just preview-character yourcharacter
```

This draws every mood into `build/character-preview/` and opens a page with an animated tile for
each (entrance, the loop twice, exit), every frame of each mood on the canvas grid with its
timing, and the character with its badge up. Run it with `all` to see yours next to the others.
Then run the tests that cover characters:

```bash
just test-class PetCharacterTests
just test-class PetLayoutTests
```

To try it on your own desktop, run the app from Xcode with your own signing team and pick it in
Settings.

## Sending it in

- One character per pull request: its file and the three lines that wire it in.
- Put the animated tiles from `build/character-preview/yourcharacter/` in the pull request
  description. GitHub plays them. Active and waiting at the very least.
- Original characters only. No one else's mascot, and nothing from a game, film or show.
- Leave the README's pictures alone; they are drawn again when a release goes out.

## Ideas

If you would like somewhere to start:

- a cat that walks across the keyboard while it works and naps on it when idle
- an octopus typing on four keyboards at once
- a coffee mug that fills up while it works and gets drained while compacting
- a cactus that grows a flower when there is something to read
- a ghost that turns see-through while compacting
- a frog catching bugs with its tongue
- a snail leaving a trail of semicolons
- a hedgehog that curls into a ball to compact
- a tiny dragon sitting on a hoard of tokens
