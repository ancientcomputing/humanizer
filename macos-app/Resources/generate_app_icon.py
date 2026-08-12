#!/usr/bin/env python3
"""Generate the Humanizer macOS app icon asset catalog.

Draws the same mark used in web/static/favicon.svg: a rounded square in the
brand accent color with a white "person" silhouette (circle head + shoulders).
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ModuleNotFoundError as exc:
    raise SystemExit(
        "Pillow is required to generate Humanizer app icon assets. "
        "Install it for this Python, or run with ICON_PYTHON/PYTHON set to a "
        "Python that can import PIL."
    ) from exc

ACCENT = (181, 80, 45, 255)  # #b5502d
WHITE = (255, 255, 255, 255)

ICON_FILES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def draw_icon(size: int) -> Image.Image:
    scale = 8
    canvas_size = size * scale
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    unit = canvas_size / 64.0
    radius = 14 * unit
    draw.rounded_rectangle(
        [(0, 0), (canvas_size - 1, canvas_size - 1)], radius=radius, fill=ACCENT
    )

    head_cx, head_cy, head_r = 32 * unit, 24 * unit, 11 * unit
    draw.ellipse(
        [head_cx - head_r, head_cy - head_r, head_cx + head_r, head_cy + head_r],
        fill=WHITE,
    )

    # Shoulders: a bezier-like curve approximated with a smooth polygon.
    top_y = 42 * unit
    bottom_y = 62 * unit
    left_x = 12 * unit
    right_x = 52 * unit
    steps = 40
    points = [(left_x, bottom_y)]
    for i in range(steps + 1):
        t = i / steps
        # Cubic bezier: P0=(12,62) C1=(12,42) C2=(52,42) P1=(52,62)
        x = (
            (1 - t) ** 3 * left_x
            + 3 * (1 - t) ** 2 * t * left_x
            + 3 * (1 - t) * t**2 * right_x
            + t**3 * right_x
        )
        y = (
            (1 - t) ** 3 * bottom_y
            + 3 * (1 - t) ** 2 * t * top_y
            + 3 * (1 - t) * t**2 * top_y
            + t**3 * bottom_y
        )
        points.append((x, y))
    points.append((right_x, bottom_y))
    draw.polygon(points, fill=WHITE)

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    appiconset = Path(sys.argv[1]) if len(sys.argv) > 1 else (
        Path(__file__).resolve().parent / "Assets.xcassets" / "AppIcon.appiconset"
    )
    appiconset.mkdir(parents=True, exist_ok=True)

    for filename, size in ICON_FILES:
        icon = draw_icon(size)
        icon.save(appiconset / filename)
        print(f"Wrote {filename} ({size}x{size})")


if __name__ == "__main__":
    main()
