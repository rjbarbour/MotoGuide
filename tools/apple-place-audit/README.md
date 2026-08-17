# Apple place-label audit

This is an isolated, off-bike probe of Apple place labels. It is not an iOS app feature, a route importer or a release test. It uses public synthetic coordinates only and must never receive personal GPX traces or precise personal locations.

The audit records four separate things: official geography stated in the manifest, Apple’s dated response, the exact five-field `Address(placemark:)` projection, and the deliberately separate product/fact discussion in the research report.

`CLGeocoder` is used only because RideHorizon currently uses it. The Swift probe compiles with the production `RideHorizon/Address.swift`, so the captured derived tuple is the current application transformation rather than a second implementation. Apple marks the Core Location geocoding methods deprecated on the installed SDK; the tool exists to characterise present behaviour, not to decide a migration.

## Commands

Compile the isolated macOS probe:

```bash
swiftc -framework Foundation -framework CoreLocation RideHorizon/Address.swift tools/apple-place-audit/ApplePlaceProbe.swift -o tools/apple-place-audit/.build/apple-place-probe
```

Expected result: no compiler errors and `tools/apple-place-audit/.build/apple-place-probe` exists. Warnings about the deprecated Core Location geocoder are expected evidence of the current migration position.

Run focused tooling checks with the project-standard Python runtime:

```bash
uv run --python 3.13 python -m unittest discover -s tools/apple-place-audit/tests -v
```

Expected result: all audit tests pass.

Inspect the pending request plan without touching Apple services:

```bash
uv run --python 3.13 tools/apple-place-audit/apple_place_audit.py --manifest fixtures/geography/apple-place-audit/manifest-2026-08-05-v1.json --results fixtures/geography/apple-place-audit/results-2026-08-05-v1.json --probe tools/apple-place-audit/.build/apple-place-probe --dry-run
```

Expected result for the retained completed cache: JSON contains `"pendingRequests": []` and no results file is written. To inspect the initial public request plan, supply a path for a nonexistent temporary results file rather than the retained cache.

This command is an operator-only empirical probe, not an LLM-safe diagnostic collector. Do not paste raw live-run output into an AI session. If future evidence is intended for LLM-assisted diagnosis, use the repository's Diagnostic Script Standards, including collection-time redaction and the required output markers.

Run the six-request Lovelace Road and Hampton Court pilot before the broader corpus:

```bash
uv run --python 3.13 tools/apple-place-audit/apple_place_audit.py --manifest fixtures/geography/apple-place-audit/manifest-2026-08-05-v1.json --results fixtures/geography/apple-place-audit/results-2026-08-05-v1.json --probe tools/apple-place-audit/.build/apple-place-probe --only lovelace-road-kingston-side,lovelace-road-boundary-candidate,lovelace-road-elmbridge-side,hampton-court-elmbridge-side,hampton-court-bridge-boundary-candidate,hampton-court-richmond-side
```

Expected result: six cached observations, no faster than 60 seconds apart, before a broader run is considered.

Run or resume the bounded audit at the conservative default of 60 seconds between Apple requests:

```bash
uv run --python 3.13 tools/apple-place-audit/apple_place_audit.py --manifest fixtures/geography/apple-place-audit/manifest-2026-08-05-v1.json --results fixtures/geography/apple-place-audit/results-2026-08-05-v1.json --probe tools/apple-place-audit/.build/apple-place-probe
```

Expected result: each completed request is immediately persisted to the results JSON. Re-running skips successful and permanent-failure entries. Interrupting with `Ctrl-C` keeps completed results intact.

Generate the comparison report from the completed cache:

```bash
uv run --python 3.13 tools/apple-place-audit/generate_comparison.py --results fixtures/geography/apple-place-audit/results-2026-08-05-v1.json --output fixtures/geography/apple-place-audit/comparison-2026-08-05-v1.md
```

Expected result: a compact table contrasts official comparison context, Apple's raw first-candidate tuple and RideHorizon’s current derived tuple without duplicating coordinates.

The runner defaults to 60 seconds. A smaller explicit `--interval-seconds` value prints a warning and is for controlled local diagnosis only; it is not the normal evidence run.

## Retention and promotion

The manifest records public candidate coordinates. A candidate is not a legal boundary assertion merely because it is named `boundary`. Promote it into the deterministic application fixture corpus only after a dated OS Boundary-Line verification records the exact geometry, source version and two official side codes. Keep Apple responses versioned and refresh them deliberately; never make live Apple wording a permanently asserted unit-test expectation.
