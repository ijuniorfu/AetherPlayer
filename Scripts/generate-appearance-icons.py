#!/usr/bin/env python3
"""Generate the iOS AppIcon appearance variants (light, dark, tinted) from the master art.

The master carries a dark bloom baked into its alpha, authored for a black background, so
compositing it onto a light one leaves a dirty ring. A feathered circular mask removes it
exactly: measured along the radius, alpha holds at 255 out to ~405 px and brightness stays
above 210, then both collapse (77 by 410 px). That is the orb's edge, and everything past
it is bloom.

Deliberately NO brightness-based alpha ramp here. The orb's own interior contains dark
navy nebula regions, so keying on brightness dissolved 9% of the pixels inside the orb and
let the light background bleed through as milky patches.

Usage: Scripts/generate-appearance-icons.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

REPO = Path(__file__).resolve().parent.parent
MASTER = REPO / "docs/images/aetherplayer-icon.png"
OUT = REPO / "Sources/iOS/Resources/Assets.xcassets/AppIcon.appiconset"
SIZE = 1024

ORB_CENTER, ORB_RADIUS, ORB_FEATHER = (512, 513), 406, 3


def _isolate_orb(src: Image.Image) -> Image.Image:
    """Keep the master's alpha inside the orb untouched, drop everything outside."""
    out = src.copy()
    mask = Image.new("L", (SIZE, SIZE), 0)
    cx, cy = ORB_CENTER
    ImageDraw.Draw(mask).ellipse(
        (cx - ORB_RADIUS, cy - ORB_RADIUS, cx + ORB_RADIUS, cy + ORB_RADIUS), fill=255
    )
    mask = mask.filter(ImageFilter.GaussianBlur(ORB_FEATHER))
    alpha = Image.new("L", (SIZE, SIZE))
    alpha.paste(out.getchannel("A"), (0, 0), mask)
    out.putalpha(alpha)
    return out


def _light_background() -> Image.Image:
    bg = Image.new("RGBA", (SIZE, SIZE))
    px = bg.load()
    for y in range(SIZE):
        t = y / (SIZE - 1)
        row = (int(247 - 10 * t), int(249 - 8 * t), int(255 - 6 * t), 255)
        for x in range(SIZE):
            px[x, y] = row
    return bg


def _drop_shadow(motif: Image.Image) -> Image.Image:
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow.paste((50, 60, 170, 95), (0, 0), motif.getchannel("A"))
    return shadow.filter(ImageFilter.GaussianBlur(30))


def main() -> None:
    master = Image.open(MASTER).convert("RGBA")
    orb = _isolate_orb(master)

    light = Image.alpha_composite(_light_background(), _drop_shadow(orb))
    light = Image.alpha_composite(light, orb).convert("RGB")
    light.save(OUT / "icon_light_1024.png")

    tinted = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    tinted = Image.alpha_composite(tinted, orb).convert("L").convert("RGB")
    tinted.save(OUT / "icon_tinted_1024.png")

    # Dark keeps the shipped artwork; the bloom is what that background was drawn for.
    dark = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    dark = Image.alpha_composite(dark, master).convert("RGB")
    dark.save(OUT / "icon_dark_1024.png")

    for name in ("icon_light_1024.png", "icon_dark_1024.png", "icon_tinted_1024.png"):
        print(f"  wrote {name}")


if __name__ == "__main__":
    main()
