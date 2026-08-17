#!/usr/bin/env python3
"""Resumable, deliberately slow Apple place-label audit runner.

This tool is intentionally separate from the iOS application.  It asks the
small Swift probe to make one CLGeocoder request at a time, caches every
outcome, and resumes from the JSON result store after an interruption.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


SCHEMA_VERSION = "apple-place-audit-results-v1"
DEFAULT_INTERVAL_SECONDS = 60
MAX_ATTEMPTS = 3


def utc_now() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def read_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def validate_manifest(manifest: dict[str, Any]) -> None:
    if manifest.get("schemaVersion") != "apple-place-audit-manifest-v1":
        raise ValueError("Unsupported manifest schemaVersion.")
    seen: set[str] = set()
    for sample in manifest.get("samples", []):
        sample_id = sample.get("id")
        if not isinstance(sample_id, str) or not sample_id:
            raise ValueError("Every sample needs a non-empty id.")
        if sample_id in seen:
            raise ValueError(f"Duplicate sample id: {sample_id}")
        seen.add(sample_id)
        operation = sample.get("operation")
        if operation not in {"reverse", "forward-reverse"}:
            raise ValueError(f"{sample_id}: operation must be reverse or forward-reverse.")
        if operation == "reverse":
            coordinate = sample.get("coordinate")
            if not isinstance(coordinate, dict) or not all(isinstance(coordinate.get(key), (int, float)) for key in ("latitude", "longitude")):
                raise ValueError(f"{sample_id}: reverse samples need numeric latitude and longitude.")
        if operation == "forward-reverse" and not isinstance(sample.get("query"), str):
            raise ValueError(f"{sample_id}: forward-reverse samples need a query.")


def empty_results(manifest: dict[str, Any]) -> dict[str, Any]:
    return {
        "schemaVersion": SCHEMA_VERSION,
        "manifestVersion": manifest["manifestVersion"],
        "createdAt": utc_now(),
        "requests": {},
    }


def load_results(path: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    if not path.exists():
        return empty_results(manifest)
    results = read_json(path)
    if results.get("schemaVersion") != SCHEMA_VERSION:
        raise ValueError("Unsupported results schemaVersion.")
    if results.get("manifestVersion") != manifest["manifestVersion"]:
        raise ValueError("Results belong to a different manifest version.")
    if not isinstance(results.get("requests"), dict):
        raise ValueError("Results requests must be an object.")
    return results


def atomic_write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as file:
        json.dump(value, file, indent=2, sort_keys=True)
        file.write("\n")
        temporary_path = Path(file.name)
    os.replace(temporary_path, path)


def is_complete(record: dict[str, Any] | None) -> bool:
    return bool(record) and record.get("outcome") in {"success", "permanent_failure"}


def classify_failure(probe_result: dict[str, Any]) -> str:
    code = str(probe_result.get("errorCode", "")).lower()
    message = str(probe_result.get("errorMessage", "")).lower()
    if any(token in code or token in message for token in ("invalid", "foundnoresult", "denied", "cancelled")):
        return "permanent"
    if any(token in code or token in message for token in ("network", "kclerrordomain:2", "timeout", "service", "temporar", "unavailable")):
        return "transient"
    return "unknown"


def derived_address(raw: dict[str, Any]) -> dict[str, Any]:
    """Mirror Address.init(placemark:) for deterministic tool tests.

    Production observations use the actual Address.swift implementation in the
    Swift probe.  This small mirror protects report generation and makes the
    precedence rule explicit: a valid subLocality wins over locality.
    """
    def value(name: str) -> str:
        candidate = raw.get(name)
        if not isinstance(candidate, str) or not candidate.strip():
            return "N/A"
        return candidate.strip()

    sub_locality = value("subLocality")
    locality = value("locality")
    return {
        "street": value("thoroughfare"),
        "town": sub_locality if sub_locality != "N/A" else locality,
        "county": value("subAdministrativeArea"),
        "administrativeArea": value("administrativeArea"),
        "country": value("country"),
    }


def base_request(sample: dict[str, Any], operation: str, request_id: str, coordinate: dict[str, float] | None = None) -> dict[str, Any]:
    return {
        "requestID": request_id,
        "sampleID": sample["id"],
        "samplePurpose": sample["purpose"],
        "boundaryLevel": sample["boundaryLevel"],
        "samplePosition": sample["position"],
        "officialGeography": sample.get("officialGeography", {}),
        "source": sample["source"],
        "operation": operation,
        "requestedLocale": sample.get("locale", "en_GB"),
        "coordinate": coordinate if coordinate is not None else sample.get("coordinate"),
        "query": sample.get("query"),
    }


def planned_requests(manifest: dict[str, Any], results: dict[str, Any]) -> list[dict[str, Any]]:
    plan: list[dict[str, Any]] = []
    requests = results["requests"]
    for sample in manifest["samples"]:
        if sample["operation"] == "reverse":
            request = base_request(sample, "reverse", f"{sample['id']}:reverse")
            if not is_complete(requests.get(request["requestID"])):
                plan.append(request)
            continue

        forward = base_request(sample, "forward", f"{sample['id']}:forward")
        forward_result = requests.get(forward["requestID"])
        if not is_complete(forward_result):
            plan.append(forward)
            continue
        if forward_result.get("outcome") != "success":
            continue
        candidates = forward_result.get("probe", {}).get("candidates", [])
        if not candidates:
            continue
        coordinate = candidates[0].get("coordinate")
        if not isinstance(coordinate, dict):
            continue
        reverse = base_request(sample, "reverse", f"{sample['id']}:reverse-returned-1", coordinate)
        reverse["derivedFrom"] = forward["requestID"]
        if not is_complete(requests.get(reverse["requestID"])):
            plan.append(reverse)
    return plan


def select_samples(manifest: dict[str, Any], selected_ids: set[str]) -> dict[str, Any]:
    if not selected_ids:
        return manifest
    known_ids = {sample["id"] for sample in manifest["samples"]}
    unknown_ids = selected_ids - known_ids
    if unknown_ids:
        raise ValueError(f"Unknown sample id(s): {', '.join(sorted(unknown_ids))}")
    return {**manifest, "samples": [sample for sample in manifest["samples"] if sample["id"] in selected_ids]}


def probe_command(binary: Path, request: dict[str, Any]) -> list[str]:
    command = [str(binary), "--operation", request["operation"], "--locale", request["requestedLocale"]]
    if request["operation"] == "reverse":
        coordinate = request["coordinate"]
        command.extend(["--latitude", str(coordinate["latitude"]), "--longitude", str(coordinate["longitude"])])
    else:
        command.extend(["--query", request["query"]])
    return command


def run_probe(binary: Path, request: dict[str, Any]) -> dict[str, Any]:
    completed = subprocess.run(probe_command(binary, request), check=False, capture_output=True, text=True, timeout=90)
    if completed.returncode != 0:
        return {
            "outcome": "failure",
            "errorCode": f"probe_exit_{completed.returncode}",
            "errorMessage": completed.stderr.strip() or "The probe exited without a result.",
        }
    try:
        return json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        return {
            "outcome": "failure",
            "errorCode": "invalid_probe_json",
            "errorMessage": str(error),
        }


def wait_for_interval(seconds: int) -> None:
    if seconds <= 0:
        return
    print(f"Waiting {seconds}s before the next Apple request…", flush=True)
    time.sleep(seconds)


def execute(manifest: dict[str, Any], results: dict[str, Any], results_path: Path, binary: Path, interval_seconds: int) -> int:
    if interval_seconds < DEFAULT_INTERVAL_SECONDS:
        print(f"WARNING: using {interval_seconds}s, below the conservative 60s default.", file=sys.stderr, flush=True)
    made_request = False
    while plan := planned_requests(manifest, results):
        request = plan[0]
        if made_request:
            wait_for_interval(interval_seconds)
        print(f"Requesting {request['requestID']} ({request['operation']}); {len(plan)} request(s) currently pending.", flush=True)
        attempts: list[dict[str, Any]] = []
        for attempt in range(1, MAX_ATTEMPTS + 1):
            probe = run_probe(binary, request)
            failure_class = "none" if probe.get("outcome") == "success" else classify_failure(probe)
            attempts.append({"attempt": attempt, "at": utc_now(), "failureClass": failure_class, "probe": probe})
            if probe.get("outcome") == "success" or failure_class == "permanent" or attempt == MAX_ATTEMPTS:
                break
            wait_for_interval(max(interval_seconds, 15 * attempt))
        final_probe = attempts[-1]["probe"]
        outcome = final_probe.get("outcome")
        record = {
            **request,
            "completedAt": utc_now(),
            "outcome": "success" if outcome == "success" else ("permanent_failure" if attempts[-1]["failureClass"] == "permanent" else "transient_failure"),
            "attempts": attempts,
            "probe": final_probe,
        }
        results["requests"][request["requestID"]] = record
        results["updatedAt"] = utc_now()
        atomic_write_json(results_path, results)
        print(f"Recorded {request['requestID']}: {record['outcome']}.", flush=True)
        made_request = True
    print("No pending Apple requests remain for this manifest.", flush=True)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--results", type=Path, required=True)
    parser.add_argument("--probe", type=Path, required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--interval-seconds", type=int, default=DEFAULT_INTERVAL_SECONDS)
    parser.add_argument("--only", help="Comma-separated sample IDs for a bounded pilot; omitted means the full manifest.")
    arguments = parser.parse_args()
    manifest = read_json(arguments.manifest)
    validate_manifest(manifest)
    selected_ids = {sample_id.strip() for sample_id in (arguments.only or "").split(",") if sample_id.strip()}
    manifest = select_samples(manifest, selected_ids)
    results = load_results(arguments.results, manifest)
    plan = planned_requests(manifest, results)
    if arguments.dry_run:
        print(json.dumps({"manifestVersion": manifest["manifestVersion"], "pendingRequests": [{"requestID": request["requestID"], "operation": request["operation"], "sampleID": request["sampleID"]} for request in plan]}, indent=2))
        return 0
    if not arguments.probe.is_file():
        raise FileNotFoundError(f"Probe is missing: {arguments.probe}")
    return execute(manifest, results, arguments.results, arguments.probe, arguments.interval_seconds)


if __name__ == "__main__":
    raise SystemExit(main())
