#!/usr/bin/env python3
"""Generate a compact, privacy-safe comparison report from cached audit JSON."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def cell(value: object) -> str:
    if not isinstance(value, str) or not value:
        return "—"
    return value.replace("|", "\\|")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    results = json.loads(arguments.results.read_text(encoding="utf-8"))
    records = sorted(results["requests"].values(), key=lambda record: record["requestID"])
    rows = []
    for record in records:
        candidate = record.get("probe", {}).get("candidates", [{}])[0]
        address = candidate.get("rideHorizonAddress", {})
        official = record.get("officialGeography", {})
        raw_place = "/".join(filter(None, [candidate.get("subLocality"), candidate.get("locality")])) or "—"
        derived = "/".join(filter(None, [address.get("town"), address.get("county"), address.get("administrativeArea"), address.get("country")])) or "—"
        if candidate.get("subLocality") and candidate.get("locality") and candidate.get("subLocality") != candidate.get("locality"):
            interpretation = "Both raw labels retained; current Address chooses subLocality for town."
        elif candidate.get("subLocality"):
            interpretation = "subLocality retained and used as town."
        elif candidate.get("locality"):
            interpretation = "locality used as town because subLocality is absent."
        else:
            interpretation = "No locality-like label returned in the first candidate."
        sides = official.get("sideA", {}).get("name")
        if official.get("sideB", {}).get("name"):
            sides = f"{sides or '—'} / {official['sideB']['name']}"
        rows.append(f"| {cell(record['requestID'])} | {cell(record.get('samplePosition'))} | {cell(sides)} | {cell(raw_place)} | {cell(candidate.get('subAdministrativeArea'))} / {cell(candidate.get('administrativeArea'))} | {cell(derived)} | {interpretation} |")
    markdown = "\n".join([
        "# Apple place-label comparison — 2026-08-05",
        "",
        "Generated from the versioned public-synthetic audit result JSON. This table deliberately does not repeat coordinates; the canonical machine-readable evidence retains them.",
        "",
        "| Request | Position | Official comparison | Apple subLocality / locality | Apple sub-administrative / administrative | RideHorizon derived town / county / administrative / country | Information loss or ambiguity |",
        "| --- | --- | --- | --- | --- | --- | --- |",
        *rows,
        "",
        "Interpretation: Apple service labels are observations at the recorded timestamp, platform and locale. They do not redefine official boundaries or decide rider-facing wording.",
        "",
    ])
    arguments.output.write_text(markdown, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
