# RideHorizon RH-D v6 rational brand asset pack

Approved: 2026-08-04

Status: selected v6 design resource; not yet implemented in the iOS app or public website.

## Identity

The selected v6 mark is a forward-leaning `RH` monogram divided by one consistent 1:5 rising colour plane. The upper field is warm white on dark backgrounds or midnight navy on light backgrounds. The lower field is horizon orange.

`source/ridehorizon-master-v6.svg` is the canonical production geometry. Every generated SVG copies that geometry and every raster export is rendered from SVG-derived artwork. The generator contains no independent pixel or polygon reconstruction of the mark.

## Palette

| Name | Hex | RGB | Intended use |
| --- | --- | --- | --- |
| Midnight navy | `#041A3A` | `4, 26, 58` | Primary dark field and light-background symbol |
| Horizon orange | `#F56C0E` | `245, 108, 14` | Lower structural colour plane |
| Warm white | `#FEFDFD` | `254, 253, 253` | Dark-background symbol and wordmark |

Use sRGB for raster exports.

## Pack layout

- `source/ridehorizon-master-v6.svg`: canonical v6 geometry.
- `source/`: canonical master plus generated SVG applications for light, dark, monochrome, lockup and square app-icon use.
- `reference/selected-concept-D.png`: the approved exploratory concept retained as provenance, not as production artwork.
- `exports/ios/`: a staged `AppIcon.appiconset`, the 1024 px master and separate Icon Composer source layers. These files are not connected to Xcode.
- `exports/web/`: SVG symbols, light/dark horizontal logo PNGs, favicons, Apple touch icon, web-app icons and maskable icons.
- `exports/general/`: transparent PNG symbol exports from 64 to 2048 px plus copied SVG masters.
- `exports/social/`: profile, square-share and Open Graph images.
- `manifest.json`: dimensions, colour modes, byte sizes and SHA-256 hashes for every file.
- `scripts/generate_assets.py`: deterministic raster-export generator.
- `scripts/validate_assets.py`: repeatable integrity, dimension, opacity, transparency, SVG and favicon validation.
- `../ridehorizon-rh-d-2026-08-04.zip`: distributable pack regenerated with the assets.

## Usage rules

- Keep the diagonal division as one uninterrupted plane across the full monogram.
- Do not add isolated colour patches, outlines, shadows, gradients or textures.
- Use `on-dark` on midnight navy or another sufficiently dark solid background.
- Use `on-light` on white, warm white or another sufficiently light solid background.
- Use a monochrome export when colour reproduction is unavailable.
- Do not pre-mask iOS artwork with rounded corners; Apple applies the platform mask.
- Keep clear space around the mark of at least one quarter of the `H` stem width.
- Do not treat the generated horizontal lockup typography as a separately approved custom wordmark. It is a practical application lockup; the RH symbol is the approved identity asset.

## Regeneration

Prerequisites: Python 3 with Pillow, Node.js, Sharp, and the macOS Avenir Next Condensed font. The scripts resolve `node` from `PATH`; set `RIDEHORIZON_NODE` to override the executable and `RIDEHORIZON_SHARP_PATH` to supply a non-standard Sharp module path.

Run:

```text
python3 resources/brand/ridehorizon-rh-d-2026-08-04/scripts/generate_assets.py
```

Expected result: the `source/` applications, `exports/` tree, preview, manifest and distributable ZIP are regenerated from the v6 master. The command prints both pack locations.

Validate:

```text
python3 resources/brand/ridehorizon-rh-d-2026-08-04/scripts/validate_assets.py
```

Expected result: the command reports `PASS` with the number of validated pack files and confirms the distributable ZIP. Validation includes pixel-identical checks between representative SVG and PNG exports.

## Implementation boundary

No file in this pack is referenced by the application, Xcode project or website. Implementation is tracked separately in `Backlog.md`.
