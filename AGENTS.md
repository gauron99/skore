# Skóre (agents)

Flutter score app. Phone is the product. Linux is a 420x800 window for
development, not a desktop layout.

Product, make targets, and the APK/release story: `README.md`.
UI screenshot loop: `.grok/skills/skore-ui-review/SKILL.md`.

## Commands

Work from this repo root. Make uses `.tools/flutter` (git-ignored, an SDK
or a symlink to one) if it exists, else `flutter` on PATH;
`make FLUTTER=/path/to/bin/flutter` overrides both.

    make test                     # after code changes
    make shots                    # after UI changes (needs DISPLAY)
    make shots ONLY=name,name     # recapture a subset

`make shots` stops if the window is not 420x800. On Hyprland it floats the
skore window at that size by itself.

Do not push. Every push to main that changes the app is a release: CI
tests it and ships the next patch version (`.github/workflows/release.yml`).

Source control is `jj`, not git.

## Do not

- Capture with `ffmpeg x11grab` of the root window (black on WSLg).
  `scripts/ui_shots.py` uses XGetImage on the app window.
- `pkill -f skore` (that kills the calling shell). Use `pkill -x skore`.
- Invent extra screenshot filenames. Names and clicks live in
  `scripts/ui_shots.py`.
- Commit `screenshots/*.png`, `.tools/`, or any keystore / `key.properties`.
- Widen the Linux window. Default size is 420x800 in
  `linux/runner/my_application.cc`.
- Ship a fat all-ABI APK or fall back to the CI debug keystore.

## Phone APK

GitHub Releases attach **one** signed arm64 APK (`skore-vX.Y.Z.apk`), not
a per-CPU split. CI signs with the stable keystore
(`~/skore-release.jks` plus the four repo secrets from
`scripts/setup-signing.sh`).

In-place updates (keep game data) need that same cert and a higher
`versionCode` (workflow run number). A debug-signed or fat APK on the
phone will not update: Android shows "Something went wrong" /
"did not install". Uninstall once, then install the current signed
arm64 file.

The Release APK workflow fails closed if the secrets are missing. Do not
restore a debug-signing fallback. Do not run `scripts/setup-signing.sh`
on a machine without the existing keystore: it would make a new key and
replace the secrets, and the phone could no longer update in place.

## UI review

After a visual change, run the `skore-ui-review` skill: `make shots`,
read the PNGs it printed, then recapture the same names after a fix.
Behavior stays `make test`.
