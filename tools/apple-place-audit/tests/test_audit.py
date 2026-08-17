import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import apple_place_audit as audit


class ApplePlaceAuditTests(unittest.TestCase):
    def manifest(self):
        return {
            "schemaVersion": "apple-place-audit-manifest-v1",
            "manifestVersion": "test-v1",
            "samples": [
                {"id": "reverse", "purpose": "test", "boundaryLevel": "locality", "position": "side-a", "source": {}, "operation": "reverse", "coordinate": {"latitude": 51.0, "longitude": -0.1}},
                {"id": "forward", "purpose": "test", "boundaryLevel": "locality", "position": "centre", "source": {}, "operation": "forward-reverse", "query": "Esher", "locale": "en_GB"},
            ],
        }

    def test_manifest_validation_rejects_duplicate_ids(self):
        manifest = self.manifest()
        manifest["samples"].append(manifest["samples"][0].copy())
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            audit.validate_manifest(manifest)

    def test_plan_suppresses_completed_requests_and_adds_returned_reverse(self):
        manifest = self.manifest()
        results = audit.empty_results(manifest)
        first_plan = audit.planned_requests(manifest, results)
        self.assertEqual([item["requestID"] for item in first_plan], ["reverse:reverse", "forward:forward"])
        results["requests"]["reverse:reverse"] = {"outcome": "success"}
        results["requests"]["forward:forward"] = {"outcome": "success", "probe": {"candidates": [{"coordinate": {"latitude": 51.1, "longitude": -0.2}}]}}
        second_plan = audit.planned_requests(manifest, results)
        self.assertEqual([item["requestID"] for item in second_plan], ["forward:reverse-returned-1"])

    def test_retry_classification_is_bounded(self):
        self.assertEqual(audit.classify_failure({"errorCode": "kCLErrorNetwork", "errorMessage": "network unavailable"}), "transient")
        self.assertEqual(audit.classify_failure({"errorCode": "kCLErrorDomain:2", "errorMessage": ""}), "transient")
        self.assertEqual(audit.classify_failure({"errorCode": "invalid_input", "errorMessage": "bad coordinate"}), "permanent")
        self.assertEqual(audit.classify_failure({"errorCode": "unexpected", "errorMessage": "unknown"}), "unknown")

    def test_atomic_result_round_trip_has_stable_schema(self):
        manifest = self.manifest()
        results = audit.empty_results(manifest)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "results.json"
            audit.atomic_write_json(path, results)
            loaded = audit.load_results(path, manifest)
        self.assertEqual(loaded["schemaVersion"], audit.SCHEMA_VERSION)
        self.assertEqual(json.dumps(loaded, sort_keys=True), json.dumps(results, sort_keys=True))

    def test_derived_address_prefers_sublocality(self):
        self.assertEqual(
            audit.derived_address({"thoroughfare": "Lovelace Road", "subLocality": "Surbiton", "locality": "Kingston upon Thames", "subAdministrativeArea": "Kingston upon Thames", "administrativeArea": "England", "country": "United Kingdom"}),
            {"street": "Lovelace Road", "town": "Surbiton", "county": "Kingston upon Thames", "administrativeArea": "England", "country": "United Kingdom"},
        )

    def test_select_samples_preserves_manifest_order_and_rejects_unknown_ids(self):
        selected = audit.select_samples(self.manifest(), {"forward"})
        self.assertEqual([sample["id"] for sample in selected["samples"]], ["forward"])
        with self.assertRaisesRegex(ValueError, "Unknown"):
            audit.select_samples(self.manifest(), {"missing"})


if __name__ == "__main__":
    unittest.main()
