#!/usr/bin/env python3
"""Validate v6 brand-pack geometry provenance, exports and archive integrity."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
NODE = "/Users/rob_dev/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
RENDERER = ROOT / "scripts/render_svg.js"
CANONICAL = ROOT / "source/ridehorizon-master-v6.svg"
APPROVED_CANDIDATE = ROOT / "workbench/candidate-v6-rational/ridehorizon-rh-d-rational-master.svg"
ARCHIVE = ROOT.parent / f"{ROOT.name}.zip"
NAVY = "#041A3A"
ORANGE = "#F56C0E"
WARM_WHITE = "#FEFDFD"


def fail(message: str) -> None:
    raise AssertionError(message)


def check_size(relative_path: str, expected: tuple[int, int]) -> None:
    with Image.open(ROOT / relative_path) as image:
        if image.size != expected:
            fail(f"{relative_path}: expected {expected}, found {image.size}")


def render_svg(path: Path, size: int) -> Image.Image:
    with tempfile.TemporaryDirectory(prefix="ridehorizon-validation-") as temporary:
        output = Path(temporary) / "render.png"
        subprocess.run([NODE, str(RENDERER), str(path), str(output), str(size)], check=True)
        return Image.open(output).convert("RGBA").copy()


def assert_pixel_identical(svg_path: Path, png_path: Path, size: int) -> None:
    expected = render_svg(svg_path, size)
    actual = Image.open(png_path).convert("RGBA")
    if ImageChops.difference(expected, actual).getbbox() is not None:
        fail(f"{png_path.relative_to(ROOT)} is not a direct rasterisation of {svg_path.relative_to(ROOT)}")


def main() -> None:
    expected_sizes = {
        "exports/ios/AppIcon.appiconset/app-icon-1024.png": (1024, 1024),
        "exports/ios/icon-composer-layers/background-1024.png": (1024, 1024),
        "exports/ios/icon-composer-layers/foreground-upper-1024.png": (1024, 1024),
        "exports/ios/icon-composer-layers/foreground-lower-1024.png": (1024, 1024),
        "exports/ios/icon-composer-layers/mono-mark-1024.png": (1024, 1024),
        "exports/web/favicon-16.png": (16, 16),
        "exports/web/favicon-32.png": (32, 32),
        "exports/web/favicon-48.png": (48, 48),
        "exports/web/apple-touch-icon-180.png": (180, 180),
        "exports/web/web-app-icon-192.png": (192, 192),
        "exports/web/web-app-icon-512.png": (512, 512),
        "exports/web/maskable-icon-192.png": (192, 192),
        "exports/web/maskable-icon-512.png": (512, 512),
        "exports/social/open-graph-1200x630.png": (1200, 630),
        "exports/social/profile-image-1024.png": (1024, 1024),
        "exports/social/square-share-1200.png": (1200, 1200),
        "preview.png": (1600, 1100),
    }
    for path, dimensions in expected_sizes.items():
        check_size(path, dimensions)

    for path in (ROOT / "source").glob("*.svg"):
        ET.parse(path)
    for path in (ROOT / "exports/web").glob("*.svg"):
        ET.parse(path)

    source_master = ROOT / "source/ridehorizon-master-v6.svg"
    if APPROVED_CANDIDATE.is_file() and source_master.read_bytes() != APPROVED_CANDIDATE.read_bytes():
        fail("source/ridehorizon-master-v6.svg does not match the approved v6 candidate")

    assert_pixel_identical(
        ROOT / "source/ridehorizon-app-icon.svg",
        ROOT / "exports/ios/AppIcon.appiconset/app-icon-1024.png",
        1024,
    )
    assert_pixel_identical(
        ROOT / "source/ridehorizon-app-icon.svg",
        ROOT / "exports/web/web-app-icon-512.png",
        512,
    )
    assert_pixel_identical(
        ROOT / "source/ridehorizon-app-icon.svg",
        ROOT / "exports/social/profile-image-1024.png",
        1024,
    )

    app_icon = Image.open(ROOT / "exports/ios/AppIcon.appiconset/app-icon-1024.png").convert("RGBA")
    if app_icon.getextrema()[3] != (255, 255):
        fail("iOS app icon must be fully opaque")
    navy_rgb = tuple(int(NAVY[index:index + 2], 16) for index in (1, 3, 5))
    corners = [app_icon.getpixel(point)[:3] for point in ((0, 0), (1023, 0), (0, 1023), (1023, 1023))]
    if any(corner != navy_rgb for corner in corners):
        fail(f"iOS app-icon corners must be v6 midnight navy {NAVY}")

    for filename in ("foreground-upper-1024.png", "foreground-lower-1024.png", "mono-mark-1024.png"):
        image = Image.open(ROOT / "exports/ios/icon-composer-layers" / filename).convert("RGBA")
        alpha_min, alpha_max = image.getextrema()[3]
        if alpha_min != 0 or alpha_max != 255:
            fail(f"{filename} must contain transparent and opaque pixels")

    favicon = Image.open(ROOT / "exports/web/favicon.ico")
    frames = set(favicon.ico.sizes()) if hasattr(favicon, "ico") else {favicon.size}
    if not {(16, 16), (32, 32), (48, 48)}.issubset(frames):
        fail(f"favicon.ico missing required frames; found {sorted(frames)}")

    web_manifest = json.loads((ROOT / "exports/web/site.webmanifest").read_text())
    if web_manifest.get("theme_color") != NAVY or web_manifest.get("background_color") != NAVY:
        fail("site.webmanifest does not use the v6 midnight navy")

    manifest = json.loads((ROOT / "manifest.json").read_text())
    if manifest.get("identity") != "RideHorizon RH-D v6 rational":
        fail("manifest identity is not v6 rational")
    if manifest.get("canonical_master") != "source/ridehorizon-master-v6.svg":
        fail("manifest canonical master is incorrect")
    if manifest.get("palette") != {
        "midnight_navy": NAVY,
        "horizon_orange": ORANGE,
        "warm_white": WARM_WHITE,
    }:
        fail("manifest palette is not the approved v6 palette")

    for entry in manifest["files"]:
        path = ROOT / entry["path"]
        if not path.is_file():
            fail(f"manifest entry missing: {entry['path']}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != entry["sha256"]:
            fail(f"manifest hash mismatch: {entry['path']}")

    if not ARCHIVE.is_file():
        fail("distributable ZIP is missing")
    expected_archive_files = {str(Path(ROOT.name) / entry["path"]) for entry in manifest["files"]}
    expected_archive_files.add(str(Path(ROOT.name) / "manifest.json"))
    with zipfile.ZipFile(ARCHIVE) as archive:
        archive_files = {name for name in archive.namelist() if not name.endswith("/")}
        if archive_files != expected_archive_files:
            fail("distributable ZIP contents do not match the manifest")
        bad_file = archive.testzip()
        if bad_file is not None:
            fail(f"distributable ZIP has a corrupt member: {bad_file}")

    print(f"PASS: validated {len(manifest['files'])} v6 brand-pack files and distributable ZIP")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, ET.ParseError, OSError, json.JSONDecodeError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
