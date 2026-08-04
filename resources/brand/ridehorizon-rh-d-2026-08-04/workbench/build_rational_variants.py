#!/usr/bin/env python3
"""Build two experimental rationalisations of the approved RH monogram.

The script writes only to workbench candidate directories. It does not touch
the source master, exports, manifest, distributable archive or application.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
WORKBENCH = ROOT / "workbench"
NODE = "/Users/rob_dev/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
PYTHON = "/Users/rob_dev/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
RENDERER = WORKBENCH / "render_svg.js"
COMPARATOR = WORKBENCH / "compare_geometric_candidate.py"

CAP = 132.0
BASELINE = 359.0
HEIGHT = BASELINE - CAP
UNIT = HEIGHT / 30.0
SHEAR = 7.0 / 24.0
PLANE_MIDPOINT = (300.819 + 197.505) / 2.0
PLANE_LEFT = PLANE_MIDPOINT + 256.0 / 5.0
PLANE_RIGHT = PLANE_MIDPOINT - 256.0 / 5.0


def n(value: float) -> str:
    text = f"{value:.3f}".rstrip("0").rstrip(".")
    return "0" if text == "-0" else text


def svg_document(title: str, r_path: str, h_stem: str, h_crossbar: str) -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512" role="img" aria-labelledby="title desc">
  <title id="title">{title}</title>
  <desc id="desc">An experimental rational construction of the RideHorizon RH monogram.</desc>
  <rect width="512" height="512" fill="#041A3A"/>
  <defs>
    <path id="r-shape" fill-rule="evenodd" d="{r_path}"/>
    <path id="h-stem" d="{h_stem}"/>
    <path id="h-crossbar" d="{h_crossbar}"/>
    <clipPath id="mark-clip">
      <use href="#r-shape"/>
      <use href="#h-stem"/>
      <use href="#h-crossbar"/>
    </clipPath>
  </defs>
  <g fill="#FEFDFD">
    <use href="#r-shape"/>
    <use href="#h-stem"/>
    <use href="#h-crossbar"/>
  </g>
  <path d="M0 {n(PLANE_LEFT)} 512 {n(PLANE_RIGHT)}V512H0Z" fill="#F56C0E" clip-path="url(#mark-clip)"/>
</svg>
'''


def geometry(equal_rhythm: bool) -> tuple[str, str, str]:
    width = 7.0 * UNIT
    leg_width = width if equal_rhythm else 8.0 * UNIT
    inner = CAP + (3.0 if equal_rhythm else 6.0) * UNIT
    join = CAP + (10.0 if equal_rhythm else 13.0) * UNIT
    counter = CAP + 20.0 * UNIT

    outer_bottom = 116.0 - SHEAR * HEIGHT
    stem_inner_bottom = outer_bottom + width
    stem_inner_join = stem_inner_bottom + SHEAR * (BASELINE - join)
    stem_inner_top = stem_inner_bottom + SHEAR * (BASELINE - inner)

    leg_top_left = stem_inner_join + 2.0 * UNIT
    leg_top_right = leg_top_left + leg_width
    leg_shift = (BASELINE - join) / 2.0
    leg_bottom_left = leg_top_left + leg_shift
    leg_bottom_right = leg_top_right + leg_shift

    hole_lower_right = stem_inner_join + 7.0 * UNIT
    hole_upper_right = hole_lower_right + 2.0 * UNIT
    hole_max_x = hole_lower_right + 5.0 * UNIT
    if equal_rhythm:
        hole_mid_y = (inner + join) / 2.0
        handle_y = 1.5 * UNIT
    else:
        # Preserve the approved v5 optical positions; only the governing
        # ratios, station heights and nominal widths change in this variant.
        stem_inner_join = 143.0
        stem_inner_top = 158.0
        leg_top_left = 185.0 - leg_width / 2.0
        leg_top_right = 185.0 + leg_width / 2.0
        leg_bottom_left = 248.0 - leg_width / 2.0
        leg_bottom_right = 248.0 + leg_width / 2.0
        hole_lower_right = 203.0
        hole_upper_right = 216.0
        hole_max_x = 239.0
        hole_mid_y = inner + 3.0 * UNIT
        handle_y = 2.5 * UNIT
    hole_lower_control_y = hole_mid_y + handle_y
    hole_upper_control_y = hole_mid_y - handle_y

    r_path = (
        f"M{n(outer_bottom)} {n(BASELINE)} 116 {n(CAP)}h109"
        f"c95 0 57 {n(join - CAP)} 51 {n(join - CAP)}"
        f"H{n(leg_top_right)}L{n(leg_bottom_right)} {n(BASELINE)}"
        f"H{n(leg_bottom_left)}L{n(leg_top_left)} {n(join)}"
        f"H{n(stem_inner_join)}L{n(stem_inner_bottom)} {n(BASELINE)}Z"
        f"M{n(stem_inner_top)} {n(inner)}L{n(stem_inner_join)} {n(join)}"
        f"H{n(hole_lower_right)}"
        f"C{n(hole_lower_right + 3.0 * UNIT)} {n(join)} {n(hole_max_x)} {n(hole_lower_control_y)} {n(hole_max_x)} {n(hole_mid_y)}"
        f"S{n(hole_upper_right + 2.0 * UNIT)} {n(inner)} {n(hole_upper_right)} {n(inner)}Z"
    )

    h_outer_top = 434.0
    h_inner_top = h_outer_top - width
    h_outer_bottom = h_outer_top - SHEAR * HEIGHT
    h_inner_bottom = h_inner_top - SHEAR * HEIGHT
    h_stem = (
        f"M{n(h_inner_top)} {n(CAP)}H{n(h_outer_top)}"
        f"L{n(h_outer_bottom)} {n(BASELINE)}H{n(h_inner_bottom)}Z"
    )

    h_inner_join = h_inner_top - SHEAR * (join - CAP)
    h_inner_counter = h_inner_top - SHEAR * (counter - CAP)
    crossbar_left_join = leg_top_right - 1.0
    crossbar_left_counter = leg_top_right + (counter - join) / 2.0 - 1.0
    h_crossbar = (
        f"M{n(crossbar_left_join)} {n(join)}H{n(h_inner_join)}"
        f"L{n(h_inner_counter)} {n(counter)}H{n(crossbar_left_counter)}Z"
    )
    return r_path, h_stem, h_crossbar


def build_candidate(directory: str, filename: str, title: str, equal_rhythm: bool) -> None:
    output = WORKBENCH / directory
    output.mkdir(parents=True, exist_ok=True)
    svg_path = output / filename
    r_path, h_stem, h_crossbar = geometry(equal_rhythm)
    svg_path.write_text(svg_document(title, r_path, h_stem, h_crossbar))
    for size in (512, 2048):
        subprocess.run(
            [NODE, str(RENDERER), str(svg_path), str(output / f"{svg_path.stem}-{size}.png"), str(size)],
            check=True,
        )
    subprocess.run([PYTHON, str(COMPARATOR), directory, filename], check=True)


def contact_sheet() -> None:
    output = WORKBENCH / "rationalisation-study"
    output.mkdir(parents=True, exist_ok=True)
    panels = [
        (WORKBENCH / "candidate-v2/reference-normalised-without-D.png", "Reference"),
        (WORKBENCH / "candidate-v5-curve/ridehorizon-rh-d-curve-refined-master-512.png", "v5 · approved direction"),
        (WORKBENCH / "candidate-v6-rational/ridehorizon-rh-d-rational-master-512.png", "v6 · conservative ratios"),
        (WORKBENCH / "candidate-v7-equal-rhythm/ridehorizon-rh-d-equal-rhythm-master-512.png", "v7 · equal vertical thirds"),
    ]
    sheet = Image.new("RGBA", (2048, 610), (236, 232, 223, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("/System/Library/Fonts/Avenir Next Condensed.ttc", 30, index=2)
    for index, (path, label) in enumerate(panels):
        x = index * 512
        sheet.alpha_composite(Image.open(path).convert("RGBA"), (x, 64))
        draw.text((x + 24, 16), label, font=font, fill=(4, 26, 58, 255))
    sheet.save(output / "contact-sheet.png")


def main() -> None:
    build_candidate(
        "candidate-v6-rational",
        "ridehorizon-rh-d-rational-master.svg",
        "RideHorizon RH-D conservative rational candidate",
        equal_rhythm=False,
    )
    build_candidate(
        "candidate-v7-equal-rhythm",
        "ridehorizon-rh-d-equal-rhythm-master.svg",
        "RideHorizon RH-D equal vertical rhythm candidate",
        equal_rhythm=True,
    )
    contact_sheet()


if __name__ == "__main__":
    main()
