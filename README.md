# Skelzies — iPad Edition

A SwiftUI + SpriteKit recreation of the classic NYC street game: bottle caps flicked
across a chalk board on asphalt, boxes 1–13 in order, then Killer mode.

## Requirements

- **Xcode 16 or newer** (the project uses filesystem-synchronized groups)
- iPadOS 17+ target, landscape orientation
- Runs fine in the iPad Simulator; on-device requires signing (see below)

## Getting started

1. Unzip and open `Skelzies.xcodeproj` in Xcode.
2. Select the **Skelzies** target → Signing & Capabilities → pick your Team,
   and change the bundle identifier from `com.example.Skelzies` to your own.
3. Choose an iPad simulator (or your iPad) and Run.

### If the project file won't open (older Xcode)

Create a new iOS App project named `Skelzies` (SwiftUI interface), delete the
generated `ContentView.swift`, then drag every `.swift` file from the `Skelzies/`
folder into the project. In target settings, set **iPad only** and
**Landscape Left/Right** orientations. That's the entire app — there are no
external dependencies or asset images; every texture is drawn in code.

## How to play

- **2–6 players.** Everyone's cap starts stacked at **Start**, outside the
  board's top-left corner.
- **Your turn:** your cap breathes (pulses). Touch it and drag backwards to aim —
  slingshot style. The dashed trajectory **grows and shrinks on its own rhythm**,
  and at high power the direction **wanders slightly**. Power and direction lock
  the instant you release. Timing is the skill.
- **Progression:** land your cap **squarely inside** boxes 1 → 13 in order.
  A clean landing earns another shot. Resting **on any chalk line**, in the
  wrong box, or off the board ends your turn.
- **Dead zone:** the framed ring around box 13. Rest there and you drop back
  one box and lose your turn.
- **No walls:** the border is just chalk. Caps slide onto the surrounding
  pavement and play from wherever they stop. Fly too far off the block and
  your cap resets to Start.
- **Killer:** clear box 13 and you're crowned 👑. Now you hunt caps: each hit
  on a rival counts (their pips fill in red); **three hits knocks them out**
  (red ✕ on the leaderboard). Every successful hit earns you another shot.
  Multiple players can become rival Killers. **Last cap standing wins.**

## Where things live

| File | What it does |
|---|---|
| `BoardLayout.swift` | Box positions/numbering (matches the reference photo), chalk segment list, the geometry "judge" |
| `ChalkRenderer.swift` | All CoreGraphics art: asphalt, jittered chalk lines, rotated numbers, cap textures |
| `GameScene.swift` | SpriteKit physics, breathing aim mechanic, contact tracking, off-world resets |
| `GameViewModel.swift` | The rules engine: turn resolution, killer hits/KOs, win detection |
| `LeaderboardView.swift` | Dynamic turn-order sidebar with NOW/NEXT, targets, crowns, ✕, hit pips |
| `SetupView.swift` / `ContentView.swift` | Player setup, layout, game-over overlay |

## Tuning knobs (top of `GameScene.swift`)

- `pulsePeriod` — breathing pace of the power gauge (default 1.6 s)
- `minSpeed` / `maxSpeed` — flick strength range
- `maxWander` — how much the aim drifts at full power
- `linearDamping` (in `makeCaps`) — how far caps slide

Box sizes, cap radius, dead-zone size, and the Start cluster are all in
`BoardLayout.swift`.
