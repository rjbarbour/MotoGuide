#!/usr/bin/env python3
"""Trace the approved concept into one SVG master and compare its rasterisation.

This script writes only to workbench/candidate-v2. It deliberately does not touch
source/, exports/, manifest.json or the distributable ZIP.
"""

from __future__ import annotations

import json
import math
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

TOOLS = Path("/private/tmp/ridehorizon-vector-tools")
sys.path.insert(0, str(TOOLS))

import cv2  # noqa: E402
import numpy as np  # noqa: E402
import vtracer  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "reference/selected-concept-D.png"
OUTPUT = ROOT / "workbench/candidate-v2"
NODE = "/Users/rob_dev/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
SVG_RENDERER = ROOT / "workbench/render_svg.js"

def largest_component(binary):
    count, labels, stats, _ = cv2.connectedComponentsWithStats(binary, connectivity=8)
    if count < 2:
        raise RuntimeError("No foreground component found")
    largest = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
    return np.where(labels == largest, 255, 0).astype(np.uint8)


def extract_reference_mask(rgb):
    brightness = rgb.max(axis=2)
    initial = np.where(brightness > 68, 255, 0).astype(np.uint8)
    roi = np.zeros_like(initial)
    roi[90:395, 25:475] = 255
    initial = cv2.bitwise_and(initial, roi)
    initial = cv2.morphologyEx(initial, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    mask = largest_component(initial)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((2, 2), np.uint8))
    softened = cv2.GaussianBlur(mask, (9, 9), 0)
    return np.where(softened >= 127, 255, 0).astype(np.uint8)


def fit_colour_plane(rgb, mask):
    red = rgb[:, :, 0].astype(np.float32)
    green = rgb[:, :, 1].astype(np.float32)
    blue = rgb[:, :, 2].astype(np.float32)
    orange = (mask > 0) & (red > 115) & (red > green * 1.45) & (blue < 115)
    white = (mask > 0) & (red > 130) & (green > 125) & (blue > 120)
    points = []
    for x in range(rgb.shape[1]):
        orange_y = np.flatnonzero(orange[:, x])
        white_y = np.flatnonzero(white[:, x])
        if len(orange_y) and len(white_y) and white_y.min() < orange_y.min():
            points.append((x, int(orange_y.min())))
    data = np.asarray(points, dtype=np.float64)
    for _ in range(4):
        slope, intercept = np.polyfit(data[:, 0], data[:, 1], 1)
        residual = np.abs(data[:, 1] - (slope * data[:, 0] + intercept))
        data = data[residual < max(2.0, np.percentile(residual, 70))]
    return float(slope), float(intercept), int(len(data))


def trace_with_vtracer(mask):
    mask_path = OUTPUT / "reference-shape-mask.png"
    traced_path = OUTPUT / "vtracer-intermediate.svg"
    Image.fromarray(np.where(mask > 0, 0, 255).astype(np.uint8)).save(mask_path)
    vtracer.convert_image_to_svg_py(
        str(mask_path),
        str(traced_path),
        colormode="binary",
        hierarchical="stacked",
        mode="spline",
        filter_speckle=4,
        corner_threshold=60,
        length_threshold=3.0,
        max_iterations=20,
        splice_threshold=45,
        path_precision=3,
    )
    root = ET.parse(traced_path).getroot()
    path = root.find("{http://www.w3.org/2000/svg}path")
    if path is None:
        raise RuntimeError("VTracer produced no path")
    path_data = path.attrib["d"]
    transform = path.attrib.get("transform", "")
    command_count = sum(path_data.count(command) for command in "MLCQAZ")
    return path_data, transform, command_count


def palette_from_reference(rgb, mask):
    red = rgb[:, :, 0].astype(np.float32)
    green = rgb[:, :, 1].astype(np.float32)
    blue = rgb[:, :, 2].astype(np.float32)
    orange_pixels = (mask > 0) & (red > 115) & (red > green * 1.45) & (blue < 115)
    white_pixels = (mask > 0) & (red > 180) & (green > 180) & (blue > 180)
    background_pixels = (mask == 0) & (rgb.max(axis=2) < 68)
    return {
        "background": np.median(rgb[background_pixels], axis=0).round().astype(np.uint8),
        "upper": np.median(rgb[white_pixels], axis=0).round().astype(np.uint8),
        "lower": np.median(rgb[orange_pixels], axis=0).round().astype(np.uint8),
    }


def hex_colour(colour):
    return "#" + "".join(f"{int(channel):02X}" for channel in colour)


def build_svg(path_data, transform, slope, intercept, palette):
    left_y = intercept
    right_y = slope * 512 + intercept
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512" role="img" aria-labelledby="title desc">
  <title id="title">RideHorizon RH-D candidate master</title>
  <desc id="desc">The approved forward-leaning RH monogram, reconstructed from the selected concept without its contact-sheet label.</desc>
  <rect id="background" width="512" height="512" fill="{hex_colour(palette['background'])}"/>
  <defs>
    <path id="rh-mark" d="{path_data}" transform="{transform}"/>
    <clipPath id="rh-clip"><use href="#rh-mark"/></clipPath>
  </defs>
  <use href="#rh-mark" fill="{hex_colour(palette['upper'])}"/>
  <path id="lower-colour-plane" d="M0 {left_y:.3f} L512 {right_y:.3f} L512 512 L0 512 Z" fill="{hex_colour(palette['lower'])}" clip-path="url(#rh-clip)"/>
</svg>
'''


def foreground_mask(rgb, background):
    distance = np.linalg.norm(rgb.astype(np.int16) - background.astype(np.int16), axis=2)
    return distance > 34


def optimise_alignment(candidate_mask, reference_mask):
    moments = cv2.moments(reference_mask.astype(np.uint8))
    centre_x = moments["m10"] / moments["m00"]
    centre_y = moments["m01"] / moments["m00"]
    best = None
    for scale in np.arange(0.975, 1.006, 0.001):
        for dx in np.arange(-2.0, 2.01, 0.5):
            for dy in np.arange(-2.0, 2.01, 0.5):
                matrix = np.array([
                    [scale, 0, centre_x * (1 - scale) + dx],
                    [0, scale, centre_y * (1 - scale) + dy],
                ], dtype=np.float32)
                shifted = cv2.warpAffine(
                    candidate_mask.astype(np.uint8),
                    matrix,
                    (512, 512),
                    flags=cv2.INTER_NEAREST,
                    borderMode=cv2.BORDER_CONSTANT,
                    borderValue=0,
                ) > 0
                intersection = np.logical_and(reference_mask, shifted).sum()
                union = np.logical_or(reference_mask, shifted).sum()
                iou = intersection / union
                if best is None or iou > best[0]:
                    best = (float(iou), float(scale), float(dx), float(dy), centre_x, centre_y)
    return best


def adjusted_transform(original_transform, alignment):
    match = re.fullmatch(r"translate\(([-0-9.]+),([-0-9.]+)\)", original_transform)
    if match is None:
        raise RuntimeError(f"Unexpected VTracer transform: {original_transform}")
    original_x, original_y = (float(value) for value in match.groups())
    _, scale, dx, dy, centre_x, centre_y = alignment
    translated_x = centre_x * (1 - scale) + scale * original_x + dx
    translated_y = centre_y * (1 - scale) + scale * original_y + dy
    return f"matrix({scale:.6f} 0 0 {scale:.6f} {translated_x:.6f} {translated_y:.6f})"


def label(draw, xy, text):
    font_path = "/System/Library/Fonts/Avenir Next Condensed.ttc"
    font = ImageFont.truetype(font_path, 30, index=2)
    draw.text(xy, text, font=font, fill=(4, 27, 58, 255))


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    rgb = np.asarray(Image.open(REFERENCE).convert("RGB"))
    mask = extract_reference_mask(rgb)
    palette = palette_from_reference(rgb, mask)
    slope, intercept, plane_samples = fit_colour_plane(rgb, mask)
    path_data, transform, command_count = trace_with_vtracer(mask)

    preliminary_svg = build_svg(path_data, transform, slope, intercept, palette)
    preliminary_svg_path = OUTPUT / "candidate-pre-alignment.svg"
    preliminary_png_path = OUTPUT / "candidate-pre-alignment.png"
    preliminary_svg_path.write_text(preliminary_svg)
    subprocess.run([NODE, str(SVG_RENDERER), str(preliminary_svg_path), str(preliminary_png_path), "512"], check=True)
    preliminary_rgb = np.asarray(Image.open(preliminary_png_path).convert("RGB"))
    alignment = optimise_alignment(foreground_mask(preliminary_rgb, palette["background"]), mask > 0)
    transform = adjusted_transform(transform, alignment)

    svg = build_svg(path_data, transform, slope, intercept, palette)
    svg_path = OUTPUT / "ridehorizon-rh-d-candidate-master.svg"
    svg_path.write_text(svg)
    rendered_path = OUTPUT / "candidate-raster-512.png"
    subprocess.run([NODE, str(SVG_RENDERER), str(svg_path), str(rendered_path), "512"], check=True)
    subprocess.run([NODE, str(SVG_RENDERER), str(svg_path), str(OUTPUT / "candidate-raster-2048.png"), "2048"], check=True)

    rows, columns = np.indices(mask.shape)
    lower = rows >= (slope * columns + intercept)
    normalised = np.empty_like(rgb)
    normalised[:, :] = palette["background"]
    normalised[(mask > 0) & ~lower] = palette["upper"]
    normalised[(mask > 0) & lower] = palette["lower"]
    normalised_path = OUTPUT / "reference-normalised-without-D.png"
    Image.fromarray(normalised).save(normalised_path)

    rendered = np.asarray(Image.open(rendered_path).convert("RGB"))
    reference_fg = mask > 0
    candidate_fg = foreground_mask(rendered, palette["background"])
    intersection = np.logical_and(reference_fg, candidate_fg).sum()
    union = np.logical_or(reference_fg, candidate_fg).sum()
    iou = intersection / union
    mismatch = np.logical_xor(reference_fg, candidate_fg)
    mismatch_pixels = int(mismatch.sum())
    mismatch_percent = mismatch_pixels / mask.size * 100

    diff = np.full_like(rgb, 246)
    diff[np.logical_and(reference_fg, ~candidate_fg)] = [0, 174, 239]
    diff[np.logical_and(~reference_fg, candidate_fg)] = [232, 45, 75]
    shared = np.logical_and(reference_fg, candidate_fg)
    diff[shared] = palette["background"]
    Image.fromarray(diff).save(OUTPUT / "shape-difference.png")

    overlay = ((normalised.astype(np.uint16) + rendered.astype(np.uint16)) // 2).astype(np.uint8)
    Image.fromarray(overlay).save(OUTPUT / "reference-candidate-overlay.png")

    sheet = Image.new("RGBA", (2048, 650), (236, 232, 223, 255))
    panels = [
        (Image.fromarray(normalised), "Normalised reference, D removed"),
        (Image.open(rendered_path).convert("RGB"), "Candidate SVG rasterisation"),
        (Image.fromarray(overlay), "50% overlay"),
        (Image.fromarray(diff), "Shape diff: cyan missing, red added"),
    ]
    draw = ImageDraw.Draw(sheet)
    for index, (panel, heading) in enumerate(panels):
        x = index * 512
        sheet.alpha_composite(panel.convert("RGBA"), (x, 65))
        label(draw, (x + 24, 16), heading)
    sheet.save(OUTPUT / "comparison-sheet.png")

    metrics = {
        "reference": str(REFERENCE.relative_to(ROOT)),
        "candidate_svg": str(svg_path.relative_to(ROOT)),
        "canvas": [512, 512],
        "foreground_pixels_reference": int(reference_fg.sum()),
        "foreground_pixels_candidate": int(candidate_fg.sum()),
        "foreground_intersection_over_union": round(float(iou), 8),
        "shape_mismatch_pixels": mismatch_pixels,
        "shape_mismatch_percent_of_canvas": round(float(mismatch_percent), 8),
        "palette": {key: hex_colour(value) for key, value in palette.items()},
        "colour_plane": {"slope": slope, "intercept": intercept, "samples": plane_samples},
        "trace": {"engine": "VTracer 0.6.15", "path_commands": command_count},
        "alignment": {
            "pre_alignment_iou": round(alignment[0], 8),
            "scale": alignment[1],
            "translate_x": alignment[2],
            "translate_y": alignment[3],
        },
        "derived_asset_packs_regenerated": False,
    }
    (OUTPUT / "comparison-metrics.json").write_text(json.dumps(metrics, indent=2) + "\n")
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
