---
name: skore-ui-review
description: >
  Capture and review Skóre UI with named Linux screenshots. Use after a Skóre
  UI change, when asked for screenshots, visual check, UI review, make shots,
  or /skore-ui-review.
---

# Skóre UI review

Validation loop for how the app looks. Behavior tests stay `make test`.

The shot catalog and capture method live in `scripts/ui_shots.py` (`SHOTS`,
`CLICK`, docstring). Do not duplicate names or click coordinates here. Do not
invent extra PNG names.

## Loop

1. Work from the Skóre repo root (`repos/gauron99/skore`).
2. Run `make shots`. Use `make shots ONLY=name,name` to recapture a subset.
3. Read every PNG `make shots` printed (`screenshots/<name>.png`).
4. Score the checklist below. Cite the filename on each finding.
5. After a UI fix: run `make shots` again (or `ONLY=` the touched names), read
   **the same filenames**, and only then claim the issue is gone.
6. Leave the harness to restore prefs and kill the app. Do not commit PNGs.

If `make shots` fails, fix `scripts/ui_shots.py`. Do not capture with
`ffmpeg x11grab` of the root window (black on WSLg). Do not `pkill -f skore`
(that kills the calling shell).

## Checklist

- **4+ players:** a three-step stand: 2nd left, 1st tall in the middle, 3rd
  right. Remaining players belong in the table, not a clipped totals strip.
- **2-3 players:** crowned cards, no podium.
- **Bottom bar:** Menu plus Add round while playing, Menu plus New game when
  the game is over. Pad the bar with `viewPadding.bottom` (not `SafeArea`
  inside the Scaffold bar) so it stays above the phone buttons.
- **New game** (end of game, and Menu during play): archives and starts
  another with the same players and rules. Setup form only via Menu, then
  Set up a new game.
- **Menu (in play):** Undo last round, End game, New game (same rules), Past
  games, Set up a new game.
- **History:** a tap opens the paper score sheet (rounds, double rule, sums),
  not a totals-only dialog.
- **Add round:** dialog for every player, empty counts as 0.
- **Setup:** Start game is on screen, not hidden under the system inset.
- **Window:** phone-shaped (default 420x800). Desktop layout is not the target.
- **Whist:** setup switch. Bid dialog, tap who hit their guess, Finish round.

A finding is not fixed until the new PNG of the same name shows it gone.
