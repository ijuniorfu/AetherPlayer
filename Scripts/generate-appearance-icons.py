#!/usr/bin/env python3
"""Refresh the transparent motif inside the iOS AppIcon.icon package.

The iOS icon is an Icon Composer package: Sources/iOS/Resources/AppIcon.icon holds
icon.json (background fill plus one layer) and Assets/motif.png. actool compiles it and
renders the light, dark and tinted appearances from that single motif, so nothing is
composited here beyond producing a clean cutout.

The master's bloom is baked into its alpha for a black background and would show as a
ring once the system puts the orb on a light one. A feathered circular mask removes it
exactly: measured along the radius, alpha holds at 255 out to ~405 px with brightness
above 210, then both collapse (77 by 410 px). That is the orb's edge.

Deliberately NO brightness-based alpha ramp. The orb's interior contains dark navy nebula
regions, so keying on brightness dissolved 9% of the pixels inside the orb and let the
background bleed through as milky patches.

Usage: Scripts/generate-appearance-icons.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

REPO = Path(__file__).resolve().parent.parent
MASTER = REPO / "docs/images/aetherplayer-icon.png"
MOTIF = REPO / "docs/images/aetherplayer-motif-transparent.png"
ICON_ASSET = REPO / "Sources/iOS/Resources/AppIcon.icon/Assets/motif.png"
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


def main() -> None:
    orb = _isolate_orb(Image.open(MASTER).convert("RGBA"))
    for path in (MOTIF, ICON_ASSET):
        orb.save(path)
        print(f"  wrote {path.relative_to(REPO)}")


if __name__ == "__main__":
    main()
