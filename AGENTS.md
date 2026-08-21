# Skóre (agents)

Flutter score app. Phone is the product. Linux is a 420x800 window for
development, not a desktop layout.

Product, make targets, and the APK/release story: `README.md`.
UI screenshot loop: `.grok/skills/skore-ui-review/SKILL.md`.

## Commands

Work from this repo root. Flutter must be on PATH.

    make test                     # after code changes
    make shots                    # after UI changes (needs DISPLAY)
    make shots ONLY=name,name     # recapture a subset
    make release-check            # signing + secrets + clean main + tests

Do not push. The user cuts a release with `make release VERSION=X.Y.Z`
(or omits VERSION to bump the last GitHub patch).

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

`make release-check` fails if the keystore or secrets are missing. The
Release APK workflow fails closed too. Do not restore a debug-signing
fallback.

## UI review

After a visual change, run the `skore-ui-review` skill: `make shots`,
read the PNGs it printed, then recapture the same names after a fix.
Behavior stays `make test`.
