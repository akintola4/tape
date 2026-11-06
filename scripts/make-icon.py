#!/usr/bin/env python3
"""Draws Tape's app icon: a flat baby-blue tape measure on a clean background.

    python3 scripts/make-icon.py            # writes Tape/Assets.xcassets/AppIcon.appiconset/AppIcon.png

Drawn at 4x and scaled down, so every edge is antialiased. Needs Pillow.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
SCALE = 4
S = SIZE * SCALE

BACKGROUND = "#FFFFFF"
BLUE = "#8FD3FF"   # the case, Tape's colour
INK = "#0B2A40"    # the blade, hook and pin; the same navy as the chip text


def px(value: float) -> int:
    return round(value * SCALE)


def draw(out: Path) -> None:
    image = Image.new("RGB", (S, S), BACKGROUND)
    d = ImageDraw.Draw(image)

    case_size = 460
    blade_reach = 250       # how far the blade runs past the case
    hook_width = 28
    blade_height = 96

    # Centre the whole mark, case plus blade plus hook, on the canvas.
    total_width = case_size + blade_reach + hook_width
    case_left = (SIZE - total_width) / 2
    case_top = (SIZE - case_size) / 2
    case_right, case_bottom = case_left + case_size, case_top + case_size
    blade_right = case_right + blade_reach

    # The blade runs flush along the bottom and starts behind the case, so it
    # fills the case's bottom-right corner as if it's coming out of it.
    blade_top = case_bottom - blade_height
    d.rectangle([px(case_right - 140), px(blade_top), px(blade_right), px(case_bottom)], fill=INK)

    d.rounded_rectangle([px(case_left), px(case_top), px(case_right), px(case_bottom)], radius=px(132), fill=BLUE)

    # Tick marks hang from the blade's top edge: a long one every fourth.
    tick_width, step = 10, 30
    x, index = case_right + 24, 0
    while x + tick_width <= blade_right - 20:
        length = 52 if index % 4 == 0 else 30
        d.rectangle([px(x), px(blade_top), px(x + tick_width), px(blade_top + length)], fill=BLUE)
        x += step
        index += 1

    # The hook at the end of the blade.
    d.rounded_rectangle(
        [px(blade_right - 12), px(blade_top - 30), px(blade_right + hook_width), px(case_bottom)],
        radius=px(10),
        fill=INK,
    )

    # The hub: a white ring around a navy pin.
    cx, cy = case_left + case_size / 2, case_top + case_size / 2 - 20
    for radius, colour in ((118, BACKGROUND), (80, BLUE), (28, INK)):
        d.ellipse([px(cx - radius), px(cy - radius), px(cx + radius), px(cy + radius)], fill=colour)

    image.resize((SIZE, SIZE), Image.LANCZOS).save(out)
    print(f"wrote {out}")


if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "Tape/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    draw(target)
