#!/usr/bin/env python3
"""Collect RideHorizon fact proxy outputs for repeatable prompt review."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path


PRODUCTION_BASE_URL = "https://ridehorizon.digitalmercenaries.ai"
KEYCHAIN_SERVICE = "RideHorizonProxy"
SANITIZE_FOR_LLM = os.environ.get("SANITIZE_FOR_LLM", "true").lower() not in {"0", "false", "no"}

GLOUCESTERSHIRE_TEST_CASES = [
    {
        "label": "county context",
        "boundary": "county",
        "placeName": "Gloucestershire",
        "placeHierarchy": {
            "county": "Gloucestershire",
            "region": "England",
            "country": "United Kingdom",
        },
    },
    {
        "label": "route town",
        "boundary": "town",
        "placeName": "Nailsworth",
        "placeHierarchy": {
            "town": "Nailsworth",
            "county": "Gloucestershire",
            "region": "England",
            "country": "United Kingdom",
        },
    },
    {
        "label": "route town",
        "boundary": "town",
        "placeName": "Minchinhampton",
        "placeHierarchy": {
            "town": "Minchinhampton",
            "county": "Gloucestershire",
            "region": "England",
            "country": "United Kingdom",
        },
    },
    {
        "label": "route town",
        "boundary": "town",
        "placeName": "Stroud",
        "placeHierarchy": {
            "town": "Stroud",
            "county": "Gloucestershire",
            "region": "England",
            "country": "United Kingdom",
        },
    },
    {
        "label": "route town",
        "boundary": "town",
        "placeName": "Stonehouse",
        "placeHierarchy": {
            "town": "Stonehouse",
            "county": "Gloucestershire",
            "region": "England",
            "country": "United Kingdom",
        },
    },
]

DIVERSE_TEST_CASES = [
    {
        "label": "nation",
        "boundary": "nation",
        "placeName": "Wales",
        "placeHierarchy": {
            "region": "Wales",
            "country": "United Kingdom",
        },
    },
    {
        "label": "nation",
        "boundary": "nation",
        "placeName": "England",
        "placeHierarchy": {
            "region": "England",
            "country": "United Kingdom",
        },
    },
    {
        "label": "county",
        "boundary": "county",
        "placeName": "Monmouthshire",
        "placeHierarchy": {
            "county": "Monmouthshire",
            "region": "Wales",
            "country": "United Kingdom",
        },
    },
    {
        "label": "county",
        "boundary": "county",
        "placeName": "Gloucestershire",
        "placeHierarchy": {
            "county": "Gloucestershire",
            "region": "England",
            "country": "United Kingdom",
        },
    },
    {
        "label": "town",
        "boundary": "town",
        "placeName": "Chepstow",
        "placeHierarchy": {
            "town": "Chepstow",
            "county": "Monmouthshire",
            "region": "Wales",
            "country": "United Kingdom",
        },
    },
    {
        "label": "town",
        "boundary": "town",
        "placeName": "Stroud",
        "placeHierarchy": {
            "town": "Stroud",
            "county": "Gloucestershire",
            "region": "England",
            "country": "United Kingdom",
        },
    },
    {
        "label": "point of interest",
        "boundary": "town",
        "placeName": "Gloucester Cathedral",
        "placeHierarchy": {
            "town": "Gloucester",
            "county": "Gloucestershire",
            "region": "England",
            "country": "United Kingdom",
        },
    },
    {
        "label": "point of interest",
        "boundary": "town",
        "placeName": "Tintern Abbey",
        "placeHierarchy": {
            "town": "Tintern",
            "county": "Monmouthshire",
            "region": "Wales",
            "country": "United Kingdom",
        },
    },
    {
        "label": "point of interest",
        "boundary": "town",
        "placeName": "Minchinhampton Common",
        "placeHierarchy": {
            "town": "Minchinhampton",
            "county": "Gloucestershire",
            "region": "England",
            "country": "United Kingdom",
        },
    },
    {
        "label": "point of interest",
        "boundary": "town",
        "placeName": "Severn Bridge",
        "placeHierarchy": {
            "town": "Chepstow",
            "county": "Monmouthshire",
            "region": "Wales",
            "country": "United Kingdom",
        },
    },
]

SEQUENCE_TEST_CASES = [
    GLOUCESTERSHIRE_TEST_CASES[0],
    GLOUCESTERSHIRE_TEST_CASES[1],
    GLOUCESTERSHIRE_TEST_CASES[2],
    GLOUCESTERSHIRE_TEST_CASES[3],
    GLOUCESTERSHIRE_TEST_CASES[4],
    {
        "label": "nearby town",
        "boundary": "town",
        "placeName": "Painswick",
        "placeHierarchy": {
            "town": "Painswick",
            "county": "Gloucestershire",
            "region": "England",
            "country": "United Kingdom",
        },
    },
    {
        "label": "nearby town",
        "boundary": "town",
        "placeName": "Dursley",
        "placeHierarchy": {
            "town": "Dursley",
            "county": "Gloucestershire",
            "region": "England",
            "country": "United Kingdom",
        },
    },
]

FACT_MODES = ["shortFacts", "longFacts"]
DEFAULT_RIDER_CONTEXT = {
    "homeCountry": "United Kingdom",
    "homeRegion": "West Midlands",
    "familiarRegions": ["England", "Cotswolds"],
    "factInterestCategories": [
        "locationFacts",
        "pointsOfInterest",
        "history",
        "landmarks",
    ],
    "customFactInstructions": "old roads, landscape, industry, local history",
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default=PRODUCTION_BASE_URL)
    parser.add_argument("--label", required=True, help="Review run label, for example before or after-2026-07-03")
    parser.add_argument(
        "--output",
        default="docs/evidence/fact-quality/FACT_QUALITY_REVIEW_2026-07-03.md",
        help="Markdown file to append to, relative to repo root unless absolute.",
    )
    parser.add_argument("--timeout", type=float, default=20.0)
    parser.add_argument("--user-id", default=None, help="Optional X-RideHorizon-User-Id value for prompt override tests.")
    parser.add_argument("--device-id", default=None, help="Optional X-RideHorizon-Device-Id value if binding is enabled.")
    parser.add_argument(
        "--rider-context",
        choices=["none", "minimal", "full"],
        default="full",
        help="Rider context shape to send. Use none when testing an older deployed proxy.",
    )
    parser.add_argument(
        "--fixture",
        choices=["gloucestershire", "diverse", "sequence", "all"],
        default="gloucestershire",
        help="Place set to sample.",
    )
    parser.add_argument(
        "--retain-generated-facts",
        action="store_true",
        help="Explicitly retain provider-generated fact text in the evidence file for controlled human review.",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = repo_root / output_path

    if not args.retain_generated_facts:
        progress("Refusing live collection without --retain-generated-facts; generated task content is redacted by default.")
        return 2

    request_count = len(test_cases_for_fixture(args.fixture)) * len(FACT_MODES)
    progress(
        f"SLOW OPERATION WARNING: up to {request_count} production fact requests; "
        "generated fact retention was explicitly enabled."
    )

    token = load_proxy_token()
    if not token:
        print(
            "Missing proxy token. Set RIDEHORIZON_PROXY_TOKEN or store it in Keychain service RideHorizonProxy.",
            file=sys.stderr,
        )
        return 2

    started = dt.datetime.now(dt.UTC).replace(microsecond=0)
    results = collect_results(
        args.base_url.rstrip("/"),
        token,
        args.timeout,
        args.user_id,
        args.device_id,
        args.rider_context,
        args.fixture,
    )
    append_markdown(output_path, args.label, started, args.base_url.rstrip("/"), args.rider_context, args.fixture, results)
    progress(f"Wrote {len(results)} generated fact rows to {display_path(output_path, repo_root)}")
    return 0


def load_proxy_token() -> str | None:
    token = os.environ.get("RIDEHORIZON_PROXY_TOKEN")
    if token and token.strip():
        return token.strip()

    try:
        completed = subprocess.run(
            ["security", "find-generic-password", "-w", "-s", KEYCHAIN_SERVICE],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        return None
    if completed.returncode != 0:
        return None
    token = completed.stdout.strip()
    return token or None


def collect_results(
    base_url: str,
    token: str,
    timeout: float,
    user_id: str | None,
    device_id: str | None,
    rider_context_mode: str,
    fixture: str,
) -> list[dict[str, str]]:
    results: list[dict[str, str]] = []
    total_requests = len(test_cases_for_fixture(fixture)) * len(FACT_MODES)
    for test_case in test_cases_for_fixture(fixture):
        for fact_mode in FACT_MODES:
            request_body = {
                "boundary": test_case["boundary"],
                "placeName": test_case["placeName"],
                "factMode": fact_mode,
                "countryContext": "United Kingdom",
                "placeHierarchy": test_case["placeHierarchy"],
            }
            rider_context = rider_context_for_mode(rider_context_mode)
            if rider_context is not None:
                request_body["riderContext"] = rider_context
            result = {
                "label": test_case["label"],
                "boundary": test_case["boundary"],
                "placeName": test_case["placeName"],
                "factMode": fact_mode,
            }
            try:
                result["fact"] = request_fact(base_url, token, request_body, timeout, user_id, device_id)
                result["status"] = "ok"
            except urllib.error.HTTPError as exc:
                result["status"] = f"http {exc.code}"
                result["fact"] = response_error_body(exc)
            except Exception as exc:  # noqa: BLE001 - review script should capture all row failures.
                result["status"] = exc.__class__.__name__
                result["fact"] = "[error detail redacted]" if SANITIZE_FOR_LLM else str(exc)
            results.append(result)
            progress(f"Request {len(results)}/{total_requests}: {result['status']}")
    return results


def test_cases_for_fixture(fixture: str) -> list[dict[str, object]]:
    if fixture == "diverse":
        return DIVERSE_TEST_CASES
    if fixture == "sequence":
        return SEQUENCE_TEST_CASES
    if fixture == "all":
        return GLOUCESTERSHIRE_TEST_CASES + DIVERSE_TEST_CASES
    return GLOUCESTERSHIRE_TEST_CASES


def rider_context_for_mode(mode: str) -> dict[str, object] | None:
    if mode == "none":
        return None
    if mode == "minimal":
        return {
            "homeCountry": DEFAULT_RIDER_CONTEXT["homeCountry"],
            "homeRegion": DEFAULT_RIDER_CONTEXT["homeRegion"],
            "familiarRegions": DEFAULT_RIDER_CONTEXT["familiarRegions"],
        }
    return DEFAULT_RIDER_CONTEXT


def request_fact(
    base_url: str,
    token: str,
    request_body: dict[str, object],
    timeout: float,
    user_id: str | None,
    device_id: str | None,
) -> str:
    body = json.dumps(request_body, separators=(",", ":")).encode("utf-8")
    request = urllib.request.Request(
        f"{base_url}/v1/fact",
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    if user_id:
        request.add_header("X-RideHorizon-User-Id", user_id)
    if device_id:
        request.add_header("X-RideHorizon-Device-Id", device_id)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = json.loads(response.read().decode("utf-8"))
    fact = payload.get("fact")
    if not isinstance(fact, str) or not fact.strip():
        raise ValueError("response did not include a non-empty fact")
    return fact.strip()


def response_error_body(exc: urllib.error.HTTPError) -> str:
    if SANITIZE_FOR_LLM:
        return "[provider error body redacted]"
    try:
        body = exc.read().decode("utf-8", errors="replace").strip()
    except Exception:  # noqa: BLE001
        return ""
    return body[:500]


def append_markdown(
    output_path: Path,
    label: str,
    started: dt.datetime,
    base_url: str,
    rider_context_mode: str,
    fixture: str,
    results: list[dict[str, str]],
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    is_new = not output_path.exists()
    with output_path.open("a", encoding="utf-8") as handle:
        if is_new:
            handle.write("# RideHorizon Fact Quality Review\n\n")
            handle.write("Review criteria: specific, non-obvious, locally grounded, rider-relevant, adult tone, not Wikipedia filler.\n\n")
            handle.write("No proxy tokens, raw coordinates, home addresses, or live ride logs belong in this file.\n")
        handle.write(f"\n## Run {label} - {started.isoformat().replace('+00:00', 'Z')}\n\n")
        handle.write(f"- Base URL: `{base_url}`\n")
        handle.write(f"- Fixture: `{fixture}`; no live coordinates.\n")
        if fixture == "sequence":
            handle.write("- Sequence fixture is ordered to expose repeated regional wording. It still sends isolated proxy calls until rideContext exists.\n")
        if fixture in {"diverse", "all"}:
            handle.write("- POI rows use the current `town` boundary because the API does not yet expose a landmark boundary.\n")
        if rider_context_mode == "none":
            handle.write("- Rider context: omitted to test the currently deployed proxy contract.\n\n")
        elif rider_context_mode == "minimal":
            handle.write("- Rider context: UK rider, West Midlands, familiar with England and the Cotswolds.\n\n")
        else:
            handle.write("- Rider context: UK rider, West Midlands, familiar with England and the Cotswolds; interests in history, landmarks, old roads, landscape, and industry.\n\n")
        handle.write("| Place | Mode | Status | Fact | Score Notes |\n")
        handle.write("|---|---|---|---|---|\n")
        for result in results:
            fact = markdown_escape(result["fact"])
            handle.write(
                f"| {result['placeName']} | `{result['factMode']}` | {result['status']} | {fact} |  |\n"
            )


def markdown_escape(value: str) -> str:
    return value.replace("\n", "<br>").replace("|", "\\|")


def timestamp() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def progress(message: str) -> None:
    print(f"{timestamp()} {message}", flush=True)


def display_path(path: Path, repo_root: Path) -> str:
    if not SANITIZE_FOR_LLM:
        return str(path)
    try:
        return f"[repo]/{path.relative_to(repo_root)}"
    except ValueError:
        return f"[temporary]/{path.name}"


def run_with_diagnostic_log() -> int:
    log_path = Path(os.environ.get(
        "RIDEHORIZON_FACT_REVIEW_LOG",
        f"/tmp/ridehorizon-fact-review-{dt.datetime.now(dt.UTC).strftime('%Y%m%dT%H%M%SZ')}.log",
    ))
    tee = subprocess.Popen(
        ["tee", str(log_path)],
        stdin=subprocess.PIPE,
        text=True,
    )
    if tee.stdin is None:
        raise RuntimeError("tee did not expose stdin")

    original_stdout = sys.stdout
    original_stderr = sys.stderr
    sys.stdout = tee.stdin
    sys.stderr = tee.stdin
    outcome = "FAIL"
    try:
        progress(f"START RideHorizon fact quality collection; SANITIZE_FOR_LLM={str(SANITIZE_FOR_LLM).lower()}")
        result = main()
        outcome = "PASS" if result == 0 else "FAIL"
        return result
    finally:
        progress(f"DONE RideHorizon fact quality collection: {outcome}")
        tee.stdin.close()
        tee.wait(timeout=5)
        sys.stdout = original_stdout
        sys.stderr = original_stderr


if __name__ == "__main__":
    raise SystemExit(run_with_diagnostic_log())
