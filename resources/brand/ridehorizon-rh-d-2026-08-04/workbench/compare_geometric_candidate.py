#!/usr/bin/env python3
"""Compare the hand-built geometric SVG candidate with the approved reference."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
candidate_name = sys.argv[1] if len(sys.argv) > 1 else "candidate-v3-designed"
svg_name = sys.argv[2] if len(sys.argv) > 2 else "ridehorizon-rh-d-geometric-master.svg"
OUTPUT = ROOT / "workbench" / candidate_name
SVG = OUTPUT / svg_name
RASTER = OUTPUT / f"{SVG.stem}-512.png"
REFERENCE = ROOT / "workbench/candidate-v2/reference-normalised-without-D.png"
BACKGROUND = np.array([4, 26, 58], dtype=np.int16)


def foreground(rgb: np.ndarray) -> np.ndarray:
    return np.linalg.norm(rgb.astype(np.int16) - BACKGROUND, axis=2) > 34


def label(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str) -> None:
    font = ImageFont.truetype("/System/Library/Fonts/Avenir Next Condensed.ttc", 30, index=2)
    draw.text(xy, text, font=font, fill=(4, 26, 58, 255))


def main() -> None:
    reference = np.asarray(Image.open(REFERENCE).convert("RGB"))
    candidate = np.asarray(Image.open(RASTER).convert("RGB"))
    reference_fg = foreground(reference)
    candidate_fg = foreground(candidate)
    shared = reference_fg & candidate_fg
    missing = reference_fg & ~candidate_fg
    added = ~reference_fg & candidate_fg
    union = reference_fg | candidate_fg

    diff = np.full_like(reference, 246)
    diff[shared] = BACKGROUND
    diff[missing] = [0, 174, 239]
    diff[added] = [232, 45, 75]
    Image.fromarray(diff).save(OUTPUT / "shape-difference.png")

    overlay = ((reference.astype(np.uint16) + candidate.astype(np.uint16)) // 2).astype(np.uint8)
    Image.fromarray(overlay).save(OUTPUT / "reference-candidate-overlay.png")

    sheet = Image.new("RGBA", (2048, 650), (236, 232, 223, 255))
    panels = [
        (Image.fromarray(reference), "Approved reference, label removed"),
        (Image.fromarray(candidate), "Clean geometric SVG rasterisation"),
        (Image.fromarray(overlay), "50% overlay"),
        (Image.fromarray(diff), "Shape diff: cyan missing, red added"),
    ]
    draw = ImageDraw.Draw(sheet)
    for index, (panel, heading) in enumerate(panels):
        x = index * 512
        sheet.alpha_composite(panel.convert("RGBA"), (x, 65))
        label(draw, (x + 24, 16), heading)
    sheet.save(OUTPUT / "comparison-sheet.png")

    svg_text = SVG.read_text()
    path_data = re.findall(r'<path[^>]+d="([^"]+)"', svg_text)
    commands = re.findall(r"[A-Za-z]", " ".join(path_data))
    numbers = re.findall(r"[-+]?(?:\d*\.\d+|\d+)", " ".join(path_data))
    metrics = {
        "reference": str(REFERENCE.relative_to(ROOT)),
        "candidate_svg": str(SVG.relative_to(ROOT)),
        "foreground_intersection_over_union": round(float(shared.sum() / union.sum()), 8),
        "shape_mismatch_pixels": int((missing | added).sum()),
        "shape_mismatch_percent_of_canvas": round(float((missing | added).sum() / reference_fg.size * 100), 8),
        "svg_bytes": SVG.stat().st_size,
        "path_elements": len(path_data),
        "path_commands": len(commands),
        "command_types": {command: commands.count(command) for command in sorted(set(commands))},
        "numeric_values_in_path_data": len(numbers),
        "derived_asset_packs_regenerated": False,
    }
    (OUTPUT / "comparison-metrics.json").write_text(json.dumps(metrics, indent=2) + "\n")
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
