#!/usr/bin/env python3
"""Record a short GIF: start Whist, lock guesses, mark a hit, finish one hand."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import ui_shots as shots  # noqa: E402

OUT = ROOT / "screenshots" / "whist-one-hand.gif"
FRAMES_DIR = ROOT / ".tools" / "whist-gif-frames"


def click_frac(fx: float, fy: float) -> None:
    xdotool = shutil.which("xdotool")
    wid, ox, oy, width, height = shots.window_id_and_origin()
    x = ox + int(width * fx)
    y = oy + int(height * fy)
    subprocess.run([xdotool, "windowactivate", "--sync", str(wid)], check=False)
    time.sleep(0.12)
    subprocess.run([xdotool, "mousemove", str(x), str(y)], check=True)
    time.sleep(0.06)
    subprocess.run([xdotool, "mousedown", "1"], check=True)
    time.sleep(0.12)
    subprocess.run([xdotool, "mouseup", "1"], check=True)
    time.sleep(0.45)


def type_text(text: str) -> None:
    xdotool = shutil.which("xdotool")
    wid, *_ = shots.window_id_and_origin()
    subprocess.run([xdotool, "windowactivate", "--sync", str(wid)], check=False)
    time.sleep(0.1)
    subprocess.run([xdotool, "type", "--delay", "50", text], check=True)
    time.sleep(0.2)


def key(name: str) -> None:
    xdotool = shutil.which("xdotool")
    subprocess.run([xdotool, "key", name], check=True)
    time.sleep(0.2)


def click_px(x: int, y: int) -> None:
    xdotool = shutil.which("xdotool")
    wid, ox, oy, _, _ = shots.window_id_and_origin()
    subprocess.run([xdotool, "windowactivate", "--sync", str(wid)], check=False)
    time.sleep(0.1)
    subprocess.run([xdotool, "mousemove", str(ox + x), str(oy + y)], check=True)
    time.sleep(0.06)
    subprocess.run([xdotool, "mousedown", "1"], check=True)
    time.sleep(0.12)
    subprocess.run([xdotool, "mouseup", "1"], check=True)
    time.sleep(0.45)


def click_teal_in(y0: float, y1: float, x0: float = 0.0) -> None:
    """Click the largest teal blob in a vertical band of the window."""
    im = shots._grab()
    px = im.load()
    w, h = im.size
    hits = []
    for y in range(int(h * y0), int(h * y1)):
        for x in range(int(w * x0), w):
            r, g, b = px[x, y][:3]
            if r < 50 and 70 < g < 150 and 60 < b < 140 and g > r + 30:
                hits.append((x, y))
    if not hits:
        raise RuntimeError(f"no teal button in y={y0}-{y1}")
    x = sum(p[0] for p in hits) // len(hits)
    y = sum(p[1] for p in hits) // len(hits)
    click_px(x, y)


def record_loop(stop: threading.Event, frames: list) -> None:
    while not stop.is_set():
        try:
            frames.append(shots._grab().copy())
        except Exception:
            pass
        time.sleep(0.14)


def save_gif(frames: list) -> None:
    from PIL import Image

    if not frames:
        raise RuntimeError("no frames captured")
    FRAMES_DIR.mkdir(parents=True, exist_ok=True)
    for i, im in enumerate(frames):
        im.save(FRAMES_DIR / f"{i:04d}.png")
    # Keep every capture at the same interval as recording (0.14s) so the
    # GIF matches wall-clock time. Deduping unique scenes made Signal play
    # a 20s flow in under 2s.
    subprocess.run(
        [
            "ffmpeg", "-y",
            "-framerate", "1000/140",
            "-i", str(FRAMES_DIR / "%04d.png"),
            "-vf",
            "fps=1000/140,split[s0][s1];[s0]palettegen=max_colors=128[p];"
            "[s1][p]paletteuse=dither=bayer",
            str(OUT),
        ],
        check=True,
    )
    print(f"wrote {OUT} ({len(frames)} frames, ~{len(frames) * 0.14:.1f}s)")


def main() -> int:
    if not os.environ.get("DISPLAY"):
        print("DISPLAY is unset", file=sys.stderr)
        return 1
    shots.backup_prefs()
    proc = None
    stop = threading.Event()
    frames: list = []
    rec = threading.Thread(target=record_loop, args=(stop, frames), daemon=True)
    try:
        shots.write_prefs(shots.FIXTURES["setup"])
        proc = shots.launch()
        rec.start()
        time.sleep(1.2)

        click_frac(0.42, 0.155)
        key("ctrl+a")
        type_text("Ana")
        click_frac(0.42, 0.25)
        key("ctrl+a")
        type_text("Ben")
        click_frac(0.88, 0.455)
        time.sleep(1.0)
        click_frac(0.42, 0.305)
        key("ctrl+a")
        type_text("Cara")
        time.sleep(0.8)
        click_teal_in(0.55, 0.75)
        time.sleep(1.8)

        type_text("2")
        key("Tab")
        type_text("3")
        key("Tab")
        type_text("2")
        time.sleep(0.6)
        click_frac(0.69, 0.73)
        time.sleep(1.2)
        try:
            click_teal_in(0.68, 0.80, x0=0.40)
            time.sleep(1.0)
        except RuntimeError:
            pass
        time.sleep(0.5)

        click_frac(0.28, 0.30)
        time.sleep(1.0)
        click_teal_in(0.88, 1.0)
        time.sleep(2.0)
    finally:
        stop.set()
        rec.join(timeout=2)
        shots.stop(proc)
        shots.restore_prefs()
    save_gif(frames)
    return 0


if __name__ == "__main__":
    sys.exit(main())
