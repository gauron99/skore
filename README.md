# Skóre

A simple score counter for card games, built with Flutter. Targets Android
(sideloaded APK) and Linux desktop (for development).

## What it does

- **Any table.** Pick the players (2+) and name each one before the game starts.
- **Fixed or open-ended.** Set a round limit (optionally numbered from the
  top down — R8, R7, … R1) and/or a score target up front —
  the app calls the final standings after the last round, or the moment a
  player reaches the target (that only *ends* the game; who wins is still the
  scoring direction's call). Leave both empty and play until *End game*.
- **Rounds in, totals out.** Enter every player's score once per round
  (negatives welcome); running totals are always on screen and the current
  leader wears the crown. Four or more players get a live 1st / 2nd / 3rd
  podium instead of a row of cards. Highest points win by default - flip the
  *Lowest points wins* switch at setup for games scored the other way
  (Hearts-style).
- **Survives restarts.** Everything is saved on-device after every change
  (`shared_preferences`), so closing the app never loses a game.
- **New game, same table.** After a game (and from *Menu* during one),
  *New game* archives the last one and starts another with the same players
  and rules. *Menu*, then *Set up a new game*, is the way back to the setup
  form.
- **Past games.** History lists every archived game; a tap opens the paper
  score sheet. Delete games one by one, or wipe everything with *Delete all
  data*.
- **Undo.** *Menu*, then *Undo last round*, takes back the last scores.
  Totals are computed from the round history, never stored.
- **Whist.** Setup switch. Guess tricks, then tap who hit their guess
  (nobody is allowed). Exact hit scores guess+10, a miss is 0. Guesses
  must not add up to the number of tricks (dealer guesses last). Hands
  8 down to 1, repeated once per player so dealing stays even. Drag the
  players into seating order at setup: the last one deals first, then the
  deal moves to the next player each stack. A *D* marks the dealer
  during play.

## Dev

Flutter must be on your PATH. Then:

    make run            # run on Linux desktop
    make test           # unit + widget tests
    make shots          # named Linux UI screenshots (needs DISPLAY)
    make apk            # debug APK (needs JDK 17 + Android SDK)
    make release-check  # signing key, GitHub secrets, tests, clean main
    make release VERSION=X.Y.Z  # those checks, then tag a GitHub Release
    make clean          # drop build outputs

## APK

Grab the latest APK from the repo's
[Releases](https://github.com/gauron99/skore/releases) page. Open it in the
phone's browser, download, and install (sideloading must be allowed). Each
release is one signed APK for phones (arm64), about 20MB, same shape as
Hana's installable file. Not a zip of per-CPU APKs.

Cut a release from a clean tree on `main`:

    make release-check              # stop if signing or tests are not ready
    make release VERSION=0.1.3      # push main if needed, create v0.1.3
    # omit VERSION to bump the patch of the latest GitHub release

That runs `gh release create vX.Y.Z --target main --generate-notes`. The
Release APK workflow builds a signed APK and attaches it to the GitHub
release. Watch the Actions tab; the phone download is ready when the APK
appears on the release page.

CI also analyzes, tests, and compile-checks a debug APK on every push and PR;
a manual CI run (Actions → CI → Run workflow) uploads that debug APK as a
3-day artifact. Local APKs need JDK 17 + the Android SDK.

Every release auto-increments its Android versionCode (from the workflow run
number), so newer releases always register as updates. Updates only install
in place (keeping game data) when every APK is signed with the same
keystore. `make release-check` verifies `~/skore-release.jks` and the four
GitHub Actions secrets. Run `./scripts/setup-signing.sh` once if those are
missing, and back up the keystore plus password. A debug-signed build uses
a new cert each CI run; Android then shows "Something went wrong" instead
of updating, and the fix is uninstall (which wipes data) plus a signed
release.

## Layout

    AGENTS.md          how later agents should work in this repo
    lib/main.dart      app entry + saved-data restore
    lib/data/          Game/AppData models + shared_preferences persistence
    lib/screens/       setup, scoreboard, and past-games screens
    lib/widgets/       round-entry dialog, paper sheet, podium
    scripts/ui_shots.py  named Linux screenshot catalog (make shots)
    test/              model + persistence unit tests, widget tests
