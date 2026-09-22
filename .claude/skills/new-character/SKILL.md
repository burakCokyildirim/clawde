---
name: new-character
description: Design a new desktop pet character for Clawde with the person asking, draw it as pixel art on the 20x16 canvas with a routine for every mood, preview it, and wire it into the app. Use when someone wants to make, draw, design or add a pet character.
---

# New character

You are helping someone add a character to Clawde's desktop pet. It is their character: they
decide what it is and how it moves, and you do the drawing, the code and the checking.

Talk with them in whatever language they write in. Code, comments and the blurb are in English.

## Before anything else

Read these, in this order:

1. `docs/characters.md`, the spec. Everything below assumes it.
2. `Clawde/Pet/PetCharacter.swift`, for `PetPart`, `PetFrame`, `PetRoutine` and `PetProp`.
3. `Clawde/Pet/Characters/Nibble.swift`, the shortest complete character.
4. `Clawde/Pet/Characters/Claudie.swift` as well, if the new character brings a prop in and out
   (an entrance and an exit).

## 1. Find the character

Ask what they have in mind, briefly. If the idea is vague or missing, offer three or four concepts,
each built around what it does while Claude works; the ideas at the end of `docs/characters.md`
are a place to start. Settle on:

- a one-word name, which becomes the enum case, the file name and the label in Settings
- its move while Claude works, the thing that makes it this character
- how it asks while waiting; there has to be a question mark in it
- how it sleeps, squeezes down and shows it has something for you to read
- four to eight colours

If they have already said enough, propose the rest and let them correct you rather than asking
everything. If they ask for someone else's mascot or a character from a game, film or show, say it
has to be original and offer an original take on the same idea.

## 2. Draw the base pose

Draw the standing pose first and show it to them in the chat as the rows of letters, with the
palette beside it, before drawing anything else. It is much cheaper to change the shape now.

- Draw the body as full 20-column rows padded with `.`, so every row of a part has the same length
  and columns line up by eye. Count them.
- Feet on row 15. Keep the top-left corner clear for the badge and the top-right for the props.
- A dark outline, or a body colour strong enough for both light and dark wallpapers.
- `w` and `e` must be in the palette: the shared props draw with them.

## 3. Write the file

Create `Clawde/Pet/Characters/<Name>.swift` shaped like Nibble's:

- `nonisolated extension PetCharacter` holding `static let <name> = PetCharacter(...)`, with a doc
  comment of a sentence or two saying who the character is and what it does.
- A `nonisolated private enum Part` at the bottom holding every part, each drawn once.
- A routine for all six moods, as the table in `docs/characters.md` describes. Use the shared props
  (`PetProp.question`, `questionStrokes`, `bubble`, `dust`, `snore`) rather than drawing new ones.
- `enter` and `exit` for any mood that brings something in, so nothing appears or vanishes in
  mid-air.
- `still` pointing at the loop frame that says the most about the mood on its own. The six stills
  must all differ.

Timing: frames of 70 to 600 ms, held poses longer. Nothing that flips back and forth faster than
about 150 ms; that reads as shivering. Loops of 1.5 to 4 seconds. Keep the motion at the
character's own pace.

Comments explain why a frame or a part is there, briefly, the way the existing characters do.

## 4. Wire it in

- A case in `PetCharacterID` (`Clawde/Pet/PetSettings.swift`), with its `label` and a one-line
  `blurb`.
- A line in the `switch` in `PetCharacter.character(for:)` (`Clawde/Pet/PetCharacter.swift`).

Xcode picks the new file up on its own; do not edit the project file.

## 5. Check it, then show it

Run the tests that cover characters, and fix the character, not the tests:

```bash
just test-class PetCharacterTests
just test-class PetLayoutTests
just test-class PetViewTests
```

Then draw the preview:

```bash
just preview-character <name>
```

The first build takes a few minutes. If `just` is missing, the plain `xcodebuild` line is at the
top of `ClawdeTests/CharacterPreview.swift`. It writes `build/character-preview/<name>/` and opens
its page in the browser.

Look before they do. Read every `<mood>-frames.png`: each frame on the canvas grid, with its time.
Look for a stray or missing cell, a part that jumps two cells where it should move one, a prop cut
off at an edge, a pose that repeats by accident. Read `badge.png` and make sure the badge floats
beside the head, not on it. Fix what you find and draw the preview again.

Then ask them to watch the page and tell you what to change. Go round as many times as they want.
It is done when they are happy with it, not when the tests pass.

## 6. Hand it over

Tell them which files changed. For the pull request: one character per pull request, and the
animated `active.png` and `waiting.png` from `build/character-preview/<name>/` dropped into its
description, since GitHub plays them. Offer to write the description.

Do not commit, push or open the pull request unless they ask. Leave `assets/` and the README
pictures alone; those are drawn again when a release goes out.
