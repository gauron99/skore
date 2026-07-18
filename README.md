# Skóre

A simple score counter for card games, built with Flutter. Targets Android
(sideloaded APK) and Linux desktop (for development).

## What it does

- **Any table.** Pick the players (2+, named or auto-named) when a game starts.
- **Fixed or open-ended.** Set a round limit and/or a score target up front —
  the app calls the final standings after the last round, or the moment a
  player reaches the target (that only *ends* the game; who wins is still the
  scoring direction's call). Leave both empty and play until *End game*.
- **Rounds in, totals out.** Enter every player's score once per round
  (negatives welcome); running totals are always on screen and the current
  leader wears the crown. Highest points win by default — flip the *Lowest
  points wins* switch at setup for games scored the other way (Hearts-style).
- **Survives restarts.** Everything is saved on-device after every change
  (`shared_preferences`), so closing the app never loses a game.
- **Past games.** Starting a new game archives the old one — the history
  screen lists every game (date, totals, winner) with full standings a tap
  away. Delete games one by one, or wipe everything with *Delete all data*.
- **Undo.** The last round can always be taken back — totals are computed from
  the round history, never stored.

## Dev

Flutter must be on your PATH. Then:

    make run    # run on Linux desktop
    make test   # unit + widget tests
    make apk    # debug APK (needs JDK 17 + Android SDK)
    make clean  # drop build outputs

## APK

CI (GitHub Actions) analyzes, tests, and builds a debug APK on every push to
main, every PR, and on manual dispatch. Trigger the **CI** workflow manually
(Actions → CI → Run workflow) to get the APK uploaded as a 3-day artifact —
that is the supported way to produce an installable APK; a local build needs
JDK 17 + the Android SDK.

## Layout

    lib/main.dart      app entry + saved-data restore
    lib/data/          Game/AppData models + shared_preferences persistence
    lib/screens/       setup, scoreboard, and past-games screens
    lib/widgets/       round-entry dialog
    test/              model + persistence unit tests, widget tests
