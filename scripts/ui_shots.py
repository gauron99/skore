#!/usr/bin/env python3
"""Named Linux UI screenshots for Skóre.

Catalog: the SHOTS list below is the source of truth for names and how each
frame is produced. The review skill reads the PNGs this writes; it does not
invent extra filenames.

Capture on WSLg/X11: XGetImage on the app window. Grabbing the root window
(ffmpeg x11grab) is black. Clicks use xdotool in root coordinates
(window origin + fraction of client size) with press/release; window-relative
click often misses.

Every shot needs the window at exactly 420x800; the run stops otherwise.
Hyprland tiles new windows, so when HYPRLAND_INSTANCE_SIGNATURE is set and
hyprctl exists, the skore window is floated and sized right after it
appears. Those are per-window dispatches; nothing outlives the app.

Kill leftover `skore` by exact process name (`pkill -x skore`) before a run,
then the child pid. Do not pkill -f: the pattern matches the calling shell.

Usage (from repo root, DISPLAY set, linux debug bundle built):

    python scripts/ui_shots.py
    python scripts/ui_shots.py --only setup,menu
    python scripts/ui_shots.py --list
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

from PIL import Image
from Xlib import X, display
from Xlib.error import BadMatch

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = ROOT / "build/linux/x64/debug/bundle/skore"
OUT_DIR = ROOT / "screenshots"
PREFS = Path.home() / ".local/share/com.gauron99.skore/shared_preferences.json"
BACKUP = ROOT / ".tools/skore-prefs-backup.json"
PREFS_KEY = "flutter.skore.data"

# The phone-shaped window every shot and CLICK fraction assumes.
WIDTH, HEIGHT = 420, 800

# Client-size fractions for the 420x800 default window (see linux/runner).
# Update these here if the bottom bar or menu layout moves. Not in the skill.
CLICK = {
    "menu": (0.17, 0.963),
    "add_round": (0.62, 0.963),
    "new_game": (0.62, 0.963),
    "menu_new_game": (0.50, 0.865),
    # Past games is only in the game-over menu (Undo, Back to setup, Past games).
    "past_games": (0.50, 0.965),
    "history_row": (0.50, 0.12),
}

STARTED = "2026-08-21T12:00:00.000"

HISTORY_ANA_BEN = {
    "players": ["Ana", "Ben"],
    "rounds": [[5, 3], [2, 8], [10, 1]],
    "targetRounds": 3,
    "targetScore": None,
    "countDown": False,
    "lowestWins": False,
    "endedManually": False,
    "startedAt": "2026-08-20T20:15:00.000",
}

SCOREBOARD_3P = {
    "players": ["Ana", "Ben", "Cara"],
    "rounds": [[12, 8, 15], [7, 14, 3], [10, 6, 11]],
    "targetRounds": 8,
    "targetScore": None,
    "countDown": True,
    "lowestWins": False,
    "endedManually": False,
    "startedAt": STARTED,
}

SCOREBOARD_6P = {
    "players": ["Ana", "Ben", "Cara", "Dana", "Eli", "Fran"],
    "rounds": [[12, 8, 15, 4, 9, 11], [7, 14, 3, 10, 6, 8], [10, 6, 11, 5, 12, 4]],
    "targetRounds": None,
    "targetScore": 50,
    "countDown": False,
    "lowestWins": False,
    "endedManually": False,
    "startedAt": STARTED,
}

STANDINGS = {
    "players": ["Ana", "Ben", "Cara"],
    "rounds": [
        [12, 8, 15],
        [7, 14, 3],
        [10, 6, 11],
        [9, 20, 4],
        [11, 5, 8],
        [6, 12, 9],
        [14, 3, 10],
        [8, 7, 13],
    ],
    "targetRounds": 8,
    "targetScore": None,
    "countDown": True,
    "lowestWins": False,
    "endedManually": False,
    "startedAt": STARTED,
}

FIXTURES = {
    "setup": {"current": None, "history": [HISTORY_ANA_BEN]},
    "scoreboard_3p": {"current": SCOREBOARD_3P, "history": [HISTORY_ANA_BEN]},
    "scoreboard_6p": {"current": SCOREBOARD_6P, "history": [HISTORY_ANA_BEN]},
    "standings": {"current": STANDINGS, "history": [HISTORY_ANA_BEN]},
}


@dataclass(frozen=True)
class Shot:
    name: str
    fixture: str
    clicks: tuple[str, ...]


# Source of truth for screenshot filenames.
SHOTS = (
    Shot("setup", "setup", ()),
    Shot("scoreboard-3p", "scoreboard_3p", ()),
    Shot("scoreboard-6p", "scoreboard_6p", ()),
    Shot("add-round", "scoreboard_3p", ("add_round",)),
    Shot("menu", "scoreboard_3p", ("menu",)),
    Shot("rematch-confirm", "scoreboard_3p", ("menu", "menu_new_game")),
    Shot("history", "standings", ("menu", "past_games")),
    Shot("history-sheet", "standings", ("menu", "past_games", "history_row")),
    Shot("standings", "standings", ()),
)


def write_prefs(data: dict) -> None:
    PREFS.parent.mkdir(parents=True, exist_ok=True)
    inner = json.dumps(data, separators=(",", ":"))
    PREFS.write_text(json.dumps({PREFS_KEY: inner}), encoding="utf-8")


def backup_prefs() -> None:
    BACKUP.parent.mkdir(parents=True, exist_ok=True)
    if BACKUP.exists():
        PREFS.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(BACKUP, PREFS)
        print("restored prefs from previous interrupted run", file=sys.stderr)
    if PREFS.exists():
        shutil.copy2(PREFS, BACKUP)
    else:
        BACKUP.write_text("", encoding="utf-8")


def restore_prefs() -> None:
    if not BACKUP.exists():
        return
    if BACKUP.stat().st_size == 0:
        if PREFS.exists():
            PREFS.unlink()
    else:
        PREFS.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(BACKUP, PREFS)
    BACKUP.unlink(missing_ok=True)


def find_window(d: display.Display):
    wanted = []

    def walk(w):
        try:
            name = w.get_wm_name()
        except Exception:
            name = None
        try:
            g = w.get_geometry()
        except Exception:
            return
        if name and "skore" in name.lower() and g.width >= 200 and g.height >= 200:
            wanted.append((g.width * g.height, w, g, name))
        try:
            for child in w.query_tree().children:
                walk(child)
        except Exception:
            pass

    walk(d.screen().root)
    if not wanted:
        return None
    wanted.sort(key=lambda item: item[0], reverse=True)
    return wanted[0][1]


def _grab() -> Image.Image:
    d = display.Display()
    w = find_window(d)
    if w is None:
        raise RuntimeError("skore window not found")
    g = w.get_geometry()
    raw = w.get_image(0, 0, g.width, g.height, X.ZPixmap, 0xFFFFFFFF)
    return Image.frombytes(
        "RGBX", (g.width, g.height), raw.data, "raw", "BGRX"
    ).convert("RGB")


def require_phone_size(width: int, height: int) -> None:
    if (width, height) != (WIDTH, HEIGHT):
        raise SystemExit(
            f"ui_shots: the skore window is {width}x{height}, not "
            f"{WIDTH}x{HEIGHT}. The CLICK fractions and the phone layout in "
            "the shots assume that size, so clicks would miss and the PNGs "
            "would not show the phone. Check what resized the window "
            "(tiling, scaling)."
        )


def capture(path: Path) -> None:
    img = _grab()
    require_phone_size(img.width, img.height)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"saved {path.relative_to(ROOT)} {img.width}x{img.height}")


def wait_painted(proc: subprocess.Popen) -> None:
    """The GTK view is black until Flutter's first frame."""
    for _ in range(40):
        if proc.poll() is not None:
            raise RuntimeError(
                f"skore exited {proc.returncode}; see .tools/skore-shots.log"
            )
        try:
            extrema = _grab().convert("L").getextrema()
        except (RuntimeError, BadMatch):
            time.sleep(0.15)
            continue
        if extrema[1] > 40:
            time.sleep(0.2)
            return
        time.sleep(0.15)
    raise RuntimeError("skore window stayed black")


def window_id_and_origin() -> tuple[int, int, int, int, int]:
    d = display.Display()
    w = find_window(d)
    if w is None:
        raise RuntimeError("skore window not found")
    g = w.get_geometry()
    # Translate to root coordinates.
    root = d.screen().root
    trans = root.translate_coords(w, 0, 0)
    return int(w.id), trans.x, trans.y, g.width, g.height


def click(name: str) -> None:
    if name not in CLICK:
        raise KeyError(f"unknown click {name}")
    fx, fy = CLICK[name]
    xdotool = shutil.which("xdotool")
    if not xdotool:
        raise RuntimeError("xdotool not on PATH")
    wid, ox, oy, width, height = window_id_and_origin()
    x = ox + int(width * fx)
    y = oy + int(height * fy)
    # On Hyprland this prints XGetWindowProperty[_NET_ACTIVE_WINDOW] failed;
    # harmless, so its stderr is dropped.
    subprocess.run(
        [xdotool, "windowactivate", "--sync", str(wid)],
        check=False,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(0.15)
    subprocess.run([xdotool, "mousemove", str(x), str(y)], check=True)
    time.sleep(0.08)
    subprocess.run([xdotool, "mousedown", "1"], check=True)
    time.sleep(0.12)
    subprocess.run([xdotool, "mouseup", "1"], check=True)
    time.sleep(0.55)


def hover_window() -> None:
    """On Hyprland the first click of a run can land as focus only. Put the
    pointer in the window and let focus settle first."""
    _, ox, oy, width, height = window_id_and_origin()
    subprocess.run(
        ["xdotool", "mousemove", str(ox + width // 2), str(oy + height // 2)],
        check=True,
    )
    time.sleep(0.4)


def on_hyprland() -> bool:
    return bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")) and bool(
        shutil.which("hyprctl")
    )


def hyprland_client(pid: int) -> dict | None:
    """The skore window in `hyprctl clients -j`: by pid, else the one
    window whose class names skore."""
    out = subprocess.run(
        ["hyprctl", "clients", "-j"], capture_output=True, text=True, check=True
    ).stdout
    clients = json.loads(out)
    for client in clients:
        if client.get("pid") == pid:
            return client
    named = [c for c in clients if "skore" in str(c.get("class", "")).lower()]
    return named[0] if len(named) == 1 else None


def float_on_hyprland(pid: int) -> None:
    """Float the skore window at the phone size and center it. Hyprland 0.55+
    takes Lua dispatchers: `hyprctl dispatch '<hl.dsp... call>'`."""
    client = None
    for _ in range(25):
        client = hyprland_client(pid)
        if client is not None:
            break
        time.sleep(0.2)
    if client is None:
        raise RuntimeError("skore window not found in hyprctl clients")
    target = f'window = "address:{client["address"]}"'
    for lua in (
        f'hl.dsp.window.float({{ {target}, action = "enable" }})',
        f"hl.dsp.window.resize({{ {target}, x = {WIDTH}, y = {HEIGHT} }})",
        f"hl.dsp.window.center({{ {target} }})",
    ):
        result = subprocess.run(
            ["hyprctl", "dispatch", lua], capture_output=True, text=True
        )
        if result.stdout.strip() != "ok":
            raise RuntimeError(
                f"hyprctl dispatch {lua!r} failed: "
                f"{(result.stdout + result.stderr).strip()}"
            )


def wait_for_phone_size(d: display.Display) -> None:
    """The resize reaches the X window a moment after the dispatch."""
    for _ in range(25):
        w = find_window(d)
        if w is not None:
            g = w.get_geometry()
            if (g.width, g.height) == (WIDTH, HEIGHT):
                return
        time.sleep(0.2)


def kill_stale() -> None:
    subprocess.run(["pkill", "-x", "skore"], check=False)
    time.sleep(0.35)


def launch() -> subprocess.Popen:
    if not BUNDLE.exists():
        raise RuntimeError(f"missing {BUNDLE}; run flutter build linux --debug")
    kill_stale()
    env = os.environ.copy()
    env["GDK_BACKEND"] = "x11"
    log = open(ROOT / ".tools/skore-shots.log", "w", encoding="utf-8")
    proc = subprocess.Popen(
        [str(BUNDLE)],
        cwd=str(BUNDLE.parent),
        env=env,
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    d = display.Display()
    try:
        for _ in range(50):
            time.sleep(0.2)
            if proc.poll() is not None:
                log.close()
                raise RuntimeError(
                    f"skore exited {proc.returncode}; see .tools/skore-shots.log"
                )
            if find_window(d) is not None:
                if on_hyprland():
                    float_on_hyprland(proc.pid)
                    wait_for_phone_size(d)
                wait_painted(proc)
                g = find_window(d).get_geometry()
                require_phone_size(g.width, g.height)
                return proc
        raise RuntimeError("skore window did not appear")
    except BaseException:  # also SystemExit from the size check, and Ctrl-C
        stop(proc)
        raise


def stop(proc: subprocess.Popen | None) -> None:
    if proc is None:
        return
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=2)


def run_shot(shot: Shot) -> None:
    proc = None
    write_prefs(FIXTURES[shot.fixture])
    proc = launch()
    try:
        if shot.clicks:
            hover_window()
        for step in shot.clicks:
            click(step)
        capture(OUT_DIR / f"{shot.name}.png")
    finally:
        stop(proc)
        time.sleep(0.3)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--only", help="comma-separated shot names")
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()

    if args.list:
        for shot in SHOTS:
            clicks = ",".join(shot.clicks) if shot.clicks else "-"
            print(f"{shot.name}\t{shot.fixture}\t{clicks}")
        return 0

    if not os.environ.get("DISPLAY"):
        print("DISPLAY is unset; Linux UI shots need an X11 display", file=sys.stderr)
        return 1

    chosen = list(SHOTS)
    if args.only:
        wanted = [name.strip() for name in args.only.split(",") if name.strip()]
        known = {s.name: s for s in SHOTS}
        missing = [name for name in wanted if name not in known]
        if missing:
            print(f"unknown shots: {', '.join(missing)}", file=sys.stderr)
            return 1
        chosen = [known[name] for name in wanted]

    if shutil.which("xdotool") is None and any(s.clicks for s in chosen):
        print("xdotool not on PATH (needed for dialog/menu shots)", file=sys.stderr)
        return 1

    backup_prefs()
    written = []
    try:
        for shot in chosen:
            run_shot(shot)
            written.append(shot.name)
    finally:
        restore_prefs()
    print("wrote " + ", ".join(f"screenshots/{name}.png" for name in written))
    return 0


if __name__ == "__main__":
    sys.exit(main())
