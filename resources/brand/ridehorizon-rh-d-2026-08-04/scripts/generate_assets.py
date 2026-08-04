#!/usr/bin/env python3
"""Generate the RideHorizon v6 brand pack from one canonical SVG master."""

from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
EXPORTS = ROOT / "exports"
IOS = EXPORTS / "ios"
WEB = EXPORTS / "web"
GENERAL = EXPORTS / "general"
SOCIAL = EXPORTS / "social"
SOURCE = ROOT / "source"
CANONICAL = SOURCE / "ridehorizon-master-v6.svg"
RENDERER = ROOT / "scripts/render_svg.js"
NODE = "/Users/rob_dev/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
ARCHIVE = ROOT.parent / f"{ROOT.name}.zip"

NAVY = "#041A3A"
ORANGE = "#F56C0E"
WARM_WHITE = "#FEFDFD"
BLACK = "#000000"
TRANSPARENT = (0, 0, 0, 0)

FONT_PATH = "/System/Library/Fonts/Avenir Next Condensed.ttc"
FONT_INDEX_DEMI_BOLD = 2


def rgba(hex_value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = hex_value.lstrip("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4)) + (alpha,)


def canonical_geometry() -> dict[str, str]:
    root = ET.parse(CANONICAL).getroot()
    namespace = {"svg": "http://www.w3.org/2000/svg"}
    geometry = {}
    for element_id in ("r-shape", "h-stem", "h-crossbar"):
        element = root.find(f".//svg:path[@id='{element_id}']", namespace)
        if element is None:
            raise RuntimeError(f"Canonical master is missing {element_id}")
        geometry[element_id] = element.attrib["d"]
    lower = root.findall("svg:path", namespace)
    if not lower:
        raise RuntimeError("Canonical master is missing its colour plane")
    geometry["plane"] = lower[-1].attrib["d"]
    return geometry


GEOMETRY = canonical_geometry()


def mark_definitions(prefix: str) -> str:
    return f'''    <path id="{prefix}-r" fill-rule="evenodd" d="{GEOMETRY['r-shape']}"/>
    <path id="{prefix}-h-stem" d="{GEOMETRY['h-stem']}"/>
    <path id="{prefix}-h-crossbar" d="{GEOMETRY['h-crossbar']}"/>
    <clipPath id="{prefix}-clip">
      <use href="#{prefix}-r"/>
      <use href="#{prefix}-h-stem"/>
      <use href="#{prefix}-h-crossbar"/>
    </clipPath>'''


def mark_uses(prefix: str, upper: str, lower: str, include_upper: bool = True, include_lower: bool = True) -> str:
    parts = []
    if include_upper:
        parts.append(f'''  <g fill="{upper}">
    <use href="#{prefix}-r"/>
    <use href="#{prefix}-h-stem"/>
    <use href="#{prefix}-h-crossbar"/>
  </g>''')
    if include_lower:
        parts.append(f'  <path d="{GEOMETRY["plane"]}" fill="{lower}" clip-path="url(#{prefix}-clip)"/>')
    return "\n".join(parts)


def symbol_svg(
    title: str,
    upper: str,
    lower: str,
    background: str | None = None,
    scale: float = 1.0,
    include_upper: bool = True,
    include_lower: bool = True,
) -> str:
    background_element = "" if background is None else f'  <rect width="512" height="512" fill="{background}"/>\n'
    transform = "" if scale == 1.0 else f' transform="translate(256 256) scale({scale:.6f}) translate(-256 -256)"'
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512" role="img" aria-labelledby="title desc">
  <title id="title">{title}</title>
  <desc id="desc">The v6 rational RideHorizon RH monogram.</desc>
{background_element}  <defs>
{mark_definitions('mark')}
  </defs>
  <g{transform}>
{mark_uses('mark', upper, lower, include_upper, include_lower)}
  </g>
</svg>
'''


def lockup_svg(dark: bool) -> str:
    upper = WARM_WHITE if dark else NAVY
    foreground = WARM_WHITE if dark else NAVY
    background = f'  <rect width="1200" height="300" fill="{NAVY}"/>\n' if dark else ""
    context = "dark" if dark else "light"
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="300" viewBox="0 0 1200 300" role="img" aria-labelledby="title desc">
  <title id="title">RideHorizon horizontal logo for {context} backgrounds</title>
  <desc id="desc">The v6 rational RH symbol followed by the RideHorizon name.</desc>
{background}  <defs>
{mark_definitions('lockup')}
  </defs>
  <g transform="translate(0 -106) scale(.59)">
{mark_uses('lockup', upper, ORANGE)}
  </g>
  <text x="300" y="188" fill="{foreground}" font-family="Avenir Next Condensed, Avenir Next, Helvetica Neue, Arial, sans-serif" font-size="94" font-weight="600">RideHorizon</text>
</svg>
'''


def write_sources() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    if not CANONICAL.is_file():
        raise RuntimeError(f"Canonical v6 master is missing: {CANONICAL}")
    files = {
        "ridehorizon-app-icon.svg": symbol_svg("RideHorizon v6 app icon", WARM_WHITE, ORANGE, NAVY),
        "ridehorizon-symbol-on-dark.svg": symbol_svg("RideHorizon v6 symbol for dark backgrounds", WARM_WHITE, ORANGE),
        "ridehorizon-symbol-on-light.svg": symbol_svg("RideHorizon v6 symbol for light backgrounds", NAVY, ORANGE),
        "ridehorizon-symbol-mono.svg": symbol_svg("RideHorizon v6 monochrome symbol", NAVY, NAVY),
        "ridehorizon-lockup-on-dark.svg": lockup_svg(dark=True),
        "ridehorizon-lockup-on-light.svg": lockup_svg(dark=False),
    }
    for filename, content in files.items():
        (SOURCE / filename).write_text(content)


def render_svg_file(path: Path, width: int, height: int | None = None) -> Image.Image:
    height = width if height is None else height
    with tempfile.TemporaryDirectory(prefix="ridehorizon-render-") as temporary:
        output = Path(temporary) / "render.png"
        subprocess.run([NODE, str(RENDERER), str(path), str(output), str(width), str(height)], check=True)
        return Image.open(output).convert("RGBA").copy()


def render_svg_text(content: str, width: int, height: int | None = None) -> Image.Image:
    with tempfile.TemporaryDirectory(prefix="ridehorizon-svg-") as temporary:
        source = Path(temporary) / "source.svg"
        source.write_text(content)
        return render_svg_file(source, width, height)


def render_symbol(size: int, upper: str, lower: str, background: str | None = None, scale: float = 1.0) -> Image.Image:
    return render_svg_text(symbol_svg("RideHorizon generated symbol", upper, lower, background, scale), size)


def save_png(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def make_lockup(width: int, height: int, dark: bool) -> Image.Image:
    background = NAVY if dark else None
    foreground = WARM_WHITE if dark else NAVY
    canvas = Image.new("RGBA", (width, height), TRANSPARENT if background is None else rgba(background))
    mark = render_symbol(height, WARM_WHITE if dark else NAVY, ORANGE)
    canvas.alpha_composite(mark, (0, 0))
    font = ImageFont.truetype(FONT_PATH, round(height * 0.28), index=FONT_INDEX_DEMI_BOLD)
    draw = ImageDraw.Draw(canvas)
    bbox = draw.textbbox((0, 0), "RideHorizon", font=font)
    text_y = (height - (bbox[3] - bbox[1])) // 2 - bbox[1]
    draw.text((round(height * 0.95), text_y), "RideHorizon", font=font, fill=rgba(foreground))
    return canvas


def make_social_card() -> Image.Image:
    canvas = Image.new("RGBA", (1200, 630), rgba(NAVY))
    canvas.alpha_composite(render_symbol(520, WARM_WHITE, ORANGE), (60, 55))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(FONT_PATH, 112, index=FONT_INDEX_DEMI_BOLD)
    draw.text((510, 220), "RideHorizon", font=font, fill=rgba(WARM_WHITE))
    return canvas


def make_preview() -> Image.Image:
    canvas = Image.new("RGBA", (1600, 1100), rgba("#ECE8DF"))
    draw = ImageDraw.Draw(canvas)
    title_font = ImageFont.truetype(FONT_PATH, 72, index=FONT_INDEX_DEMI_BOLD)
    label_font = ImageFont.truetype(FONT_PATH, 30, index=FONT_INDEX_DEMI_BOLD)
    draw.text((70, 45), "RideHorizon v6 rational identity pack", font=title_font, fill=rgba(NAVY))
    canvas.alpha_composite(render_symbol(420, WARM_WHITE, ORANGE, NAVY), (70, 180))
    draw.text((70, 620), "iOS / social profile", font=label_font, fill=rgba(NAVY))
    canvas.alpha_composite(make_lockup(980, 250, dark=False), (550, 180))
    draw.text((550, 445), "Light-background lockup", font=label_font, fill=rgba(NAVY))
    canvas.alpha_composite(make_lockup(980, 250, dark=True), (550, 540))
    draw.text((550, 805), "Dark-background lockup", font=label_font, fill=rgba(NAVY))
    for index, size in enumerate((128, 64, 32, 16)):
        icon = render_symbol(size, WARM_WHITE, ORANGE, NAVY)
        x = 590 + index * 170
        canvas.alpha_composite(icon, (x, 900 + 128 - size))
        draw.text((x, 1040), f"{size}px", font=label_font, fill=rgba(NAVY))
    return canvas


def generate_ios() -> None:
    appicon = IOS / "AppIcon.appiconset"
    sizes = {
        "app-icon-20.png": 20, "app-icon-29.png": 29, "app-icon-40.png": 40,
        "app-icon-20@3x.png": 60, "app-icon-29@2x.png": 58, "app-icon-29@3x.png": 87,
        "app-icon-40@2x.png": 80, "app-icon-40@3x.png": 120,
        "app-icon-60@2x.png": 120, "app-icon-60@3x.png": 180,
        "app-icon-76.png": 76, "app-icon-76@2x.png": 152,
        "app-icon-83.5@2x.png": 167, "app-icon-1024.png": 1024,
    }
    for filename, size in sizes.items():
        save_png(appicon / filename, render_svg_file(SOURCE / "ridehorizon-app-icon.svg", size))
    contents = {
        "images": [{"filename": "app-icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "ridehorizon-brand-pack", "version": 1},
    }
    (appicon / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")

    layers = IOS / "icon-composer-layers"
    save_png(layers / "background-1024.png", Image.new("RGBA", (1024, 1024), rgba(NAVY)))
    save_png(layers / "foreground-upper-1024.png", render_svg_text(symbol_svg("Upper layer", WARM_WHITE, ORANGE, include_lower=False), 1024))
    save_png(layers / "foreground-lower-1024.png", render_svg_text(symbol_svg("Lower layer", WARM_WHITE, ORANGE, include_upper=False), 1024))
    save_png(layers / "mono-mark-1024.png", render_symbol(1024, WARM_WHITE, WARM_WHITE))


def generate_web() -> None:
    for size in (16, 32, 48):
        save_png(WEB / f"favicon-{size}.png", render_svg_file(SOURCE / "ridehorizon-app-icon.svg", size))
    icon_master = render_svg_file(SOURCE / "ridehorizon-app-icon.svg", 256)
    icon_master.save(WEB / "favicon.ico", format="ICO", sizes=[(16, 16), (32, 32), (48, 48)])
    for size, filename in ((180, "apple-touch-icon-180.png"), (192, "web-app-icon-192.png"), (512, "web-app-icon-512.png")):
        save_png(WEB / filename, render_svg_file(SOURCE / "ridehorizon-app-icon.svg", size))
    for size in (192, 512):
        save_png(WEB / f"maskable-icon-{size}.png", render_symbol(size, WARM_WHITE, ORANGE, NAVY, scale=0.8))
    save_png(WEB / "logo-horizontal-on-light-1200x300.png", make_lockup(1200, 300, dark=False))
    save_png(WEB / "logo-horizontal-on-dark-1200x300.png", make_lockup(1200, 300, dark=True))
    for filename in (
        "ridehorizon-symbol-on-light.svg", "ridehorizon-symbol-on-dark.svg",
        "ridehorizon-lockup-on-light.svg", "ridehorizon-lockup-on-dark.svg",
    ):
        shutil.copy2(SOURCE / filename, WEB / filename)
    shutil.copy2(SOURCE / "ridehorizon-app-icon.svg", WEB / "favicon.svg")
    (WEB / "site.webmanifest").write_text(json.dumps({
        "name": "RideHorizon", "short_name": "RideHorizon",
        "icons": [
            {"src": "web-app-icon-192.png", "sizes": "192x192", "type": "image/png"},
            {"src": "web-app-icon-512.png", "sizes": "512x512", "type": "image/png"},
            {"src": "maskable-icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "maskable"},
            {"src": "maskable-icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable"},
        ],
        "theme_color": NAVY, "background_color": NAVY, "display": "standalone",
    }, indent=2) + "\n")


def generate_general() -> None:
    variants = (
        ("on-light", NAVY, ORANGE), ("on-dark", WARM_WHITE, ORANGE),
        ("mono-navy", NAVY, NAVY), ("mono-white", WARM_WHITE, WARM_WHITE),
        ("mono-black", BLACK, BLACK),
    )
    for label, upper, lower in variants:
        for size in (64, 128, 256, 512, 1024, 2048):
            save_png(GENERAL / label / f"ridehorizon-symbol-{label}-{size}.png", render_symbol(size, upper, lower))
    svg_output = GENERAL / "svg"
    svg_output.mkdir(parents=True, exist_ok=True)
    for source in SOURCE.glob("*.svg"):
        shutil.copy2(source, svg_output / source.name)


def generate_social() -> None:
    save_png(SOCIAL / "profile-image-1024.png", render_svg_file(SOURCE / "ridehorizon-app-icon.svg", 1024))
    save_png(SOCIAL / "open-graph-1200x630.png", make_social_card())
    save_png(SOCIAL / "square-share-1200.png", render_svg_file(SOURCE / "ridehorizon-app-icon.svg", 1200))


def pack_files() -> list[Path]:
    paths = [ROOT / "README.md", ROOT / "preview.png"]
    for directory in (ROOT / "reference", SOURCE, EXPORTS, ROOT / "scripts"):
        paths.extend(path for path in directory.rglob("*") if path.is_file() and "__pycache__" not in path.parts)
    return sorted(set(paths))


def write_manifest() -> None:
    files = []
    for path in pack_files():
        entry = {
            "path": str(path.relative_to(ROOT)),
            "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
        if path.suffix.lower() in {".png", ".ico"}:
            try:
                with Image.open(path) as image:
                    entry["dimensions"] = list(image.size)
                    entry["mode"] = image.mode
            except OSError:
                pass
        files.append(entry)
    (ROOT / "manifest.json").write_text(json.dumps({
        "identity": "RideHorizon RH-D v6 rational",
        "approved": "2026-08-04",
        "canonical_master": "source/ridehorizon-master-v6.svg",
        "palette": {"midnight_navy": NAVY, "horizon_orange": ORANGE, "warm_white": WARM_WHITE},
        "files": files,
    }, indent=2) + "\n")


def write_archive() -> None:
    with zipfile.ZipFile(ARCHIVE, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in pack_files() + [ROOT / "manifest.json"]:
            archive.write(path, Path(ROOT.name) / path.relative_to(ROOT))


def main() -> None:
    if EXPORTS.exists():
        shutil.rmtree(EXPORTS)
    write_sources()
    generate_ios()
    generate_web()
    generate_general()
    generate_social()
    save_png(ROOT / "preview.png", make_preview())
    write_manifest()
    write_archive()
    print(f"Generated RideHorizon v6 brand pack at {ROOT}")
    print(f"Generated distributable archive at {ARCHIVE}")


if __name__ == "__main__":
    main()
