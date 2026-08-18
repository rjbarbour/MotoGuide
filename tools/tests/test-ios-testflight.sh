#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

readonly TOOLS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT=""
PASS_COUNT=0

cleanup() {
    if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
        rm -rf -- "$TEST_ROOT"
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS: %s\n' "$1"
}

new_fixture() {
    cleanup
    unset FAKE_XCODE_VERSION
    TEST_ROOT="$(mktemp -d "${TMPDIR:-/private/tmp}/ios-testflight-test.XXXXXX")"
    mkdir -p "$TEST_ROOT/repo/.git" "$TEST_ROOT/repo/tools" "$TEST_ROOT/repo/App.xcodeproj/xcshareddata/xcschemes" "$TEST_ROOT/repo/App" "$TEST_ROOT/repo/AppTests" "$TEST_ROOT/auth" "$TEST_ROOT/bin" "$TEST_ROOT/tmp"
    cp "$TOOLS_ROOT/ios-testflight" "$TEST_ROOT/repo/tools/ios-testflight"
    cp "$TOOLS_ROOT/tests/fixtures/bin/"* "$TEST_ROOT/bin/"
    chmod +x "$TEST_ROOT/bin/"*
    : > "$TEST_ROOT/fake.log"
    printf 'project\n' > "$TEST_ROOT/repo/App.xcodeproj/project.pbxproj"
    printf 'scheme\n' > "$TEST_ROOT/repo/App.xcodeproj/xcshareddata/xcschemes/App.xcscheme"
    printf 'source\n' > "$TEST_ROOT/repo/App/App.swift"
    printf 'test source\n' > "$TEST_ROOT/repo/AppTests/AppTests.swift"
    cat > "$TEST_ROOT/repo/.ios-testflight.json" <<'JSON'
{
  "schemaVersion": 2,
  "project": "App.xcodeproj",
  "scheme": "App",
  "productName": "App",
  "configuration": "Release",
  "bundleIdentifier": "example.app",
  "teamID": "TEAM123456",
  "authProfile": "test-auth",
  "appStoreConnectAppID": "1234567890",
  "internalBetaGroupName": "Internal",
  "evidenceMaxAgeHours": 168,
  "evidenceProfiles": ["ridehorizon-unit"],
  "testDestination": "platform=iOS Simulator,name=Fixture",
  "testTarget": "AppTests",
  "processingTimeoutSeconds": 30,
  "processingPollSeconds": 1,
  "readinessTimeoutSeconds": 3,
  "archiveInputRoots": ["App.xcodeproj", "App", "AppTests"],
  "forbiddenArchivePaths": ["internal-only.dat"],
  "allowedReleaseEntitlements": ["application-identifier", "beta-reports-active", "com.apple.developer.team-identifier", "get-task-allow"]
}
JSON
}

run_tool() {
    IOS_TESTFLIGHT_REPO_ROOT="$TEST_ROOT/repo" \
    IOS_TESTFLIGHT_CONFIG_PATH="$TEST_ROOT/repo/.ios-testflight.json" \
    IOS_TESTFLIGHT_AUTH_ROOT="$TEST_ROOT/auth" \
    IOS_TESTFLIGHT_STATE_DIR="$TEST_ROOT/state" \
    IOS_TESTFLIGHT_DERIVED_DATA_PATH="$TEST_ROOT/derived" \
    IOS_TESTFLIGHT_RECEIPT_DIR="$TEST_ROOT/receipts" \
    IOS_TESTFLIGHT_TOOL_PATH="$TEST_ROOT/repo/tools/ios-testflight" \
    TMPDIR="$TEST_ROOT/tmp" \
    FAKE_LOG="$TEST_ROOT/fake.log" \
    FAKE_MODE="${FAKE_MODE:-success}" \
    FAKE_XCODE_VERSION="${FAKE_XCODE_VERSION:-Xcode 26.3.1 fixture}" \
    FAKE_REPO_ROOT="$TEST_ROOT/repo" \
    PATH="$TEST_ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$TEST_ROOT/repo/tools/ios-testflight" "$@"
}

write_auth_profile() {
    cat > "$TEST_ROOT/auth/test-auth.json" <<'JSON'
{
  "keyID": "KEY1234567",
  "issuerID": "00000000-0000-0000-0000-000000000000",
  "keychainPath": "fixture.keychain-db",
  "keychainService": "fixture.asc",
  "keychainAccount": "fixture",
  "keychainReadPreauthorised": true,
  "testerAccount": "tester@example.com"
}
JSON
}

test_configuration_changes_invalidate_fingerprint() {
    new_fixture
    local before after
    before="$(run_tool fingerprint)"
    /usr/bin/plutil -replace configuration -string Debug "$TEST_ROOT/repo/.ios-testflight.json"
    after="$(run_tool fingerprint)"
    [[ "$before" != "$after" ]] || fail "configuration change retained the same fingerprint"
    before="$after"
    printf 'changed test source\n' >> "$TEST_ROOT/repo/AppTests/AppTests.swift"
    after="$(run_tool fingerprint)"
    [[ "$before" != "$after" ]] || fail "test-suite change retained the same fingerprint"
    pass "configuration and test-suite changes invalidate tested inputs"
}

test_tool_changes_and_schema_are_fail_closed() {
    new_fixture
    local before after output
    before="$(run_tool fingerprint)"
    printf '\n# fixture implementation change\n' >> "$TEST_ROOT/repo/tools/ios-testflight"
    after="$(run_tool fingerprint)"
    [[ "$before" != "$after" ]] || fail "deployment implementation change retained the same fingerprint"
    before="$after"
    after="$(FAKE_XCODE_VERSION='Xcode 26.3.2 fixture' run_tool fingerprint)"
    [[ "$before" != "$after" ]] || fail "Xcode toolchain change retained the same fingerprint"
    /usr/bin/plutil -replace schemaVersion -integer 99 "$TEST_ROOT/repo/.ios-testflight.json"
    if output="$(run_tool fingerprint 2>&1)"; then
        fail "unsupported configuration schema was accepted"
    fi
    [[ "$output" == *"Unsupported ios-testflight configuration schemaVersion"* ]] || fail "schema error was not explicit: $output"
    pass "deployment implementation, Xcode toolchain and configuration schema are part of the trust boundary"
}

test_missing_input_fails_closed() {
    new_fixture
    rm -f "$TEST_ROOT/repo/App/App.swift"
    rmdir "$TEST_ROOT/repo/App"
    local output
    if output="$(run_tool fingerprint 2>&1)"; then
        fail "fingerprint succeeded with a missing configured input root"
    fi
    [[ "$output" == *"Configured archive input does not exist: App"* ]] || fail "missing-input error was not explicit: $output"
    pass "missing configured inputs fail closed"
}

test_arbitrary_evidence_is_rejected() {
    new_fixture
    local output
    if output="$(run_tool trust-current anything 2>&1)"; then
        fail "arbitrary evidence text was accepted"
    fi
    [[ "$output" == *"owner-override"* || "$output" == *"test-and-trust"* ]] || fail "safe evidence usage was not explained: $output"
    pass "arbitrary evidence text cannot bless inputs"
}

test_expired_evidence_is_rejected() {
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    sed -i '' 's/^recordedEpoch=.*/recordedEpoch=1/' "$TEST_ROOT/state/App.trusted-inputs"
    local output
    if output="$(run_tool deploy 2>&1)"; then
        fail "deploy accepted expired evidence"
    fi
    [[ "$output" == *"evidence is older"* ]] || fail "expired-evidence error was not explicit: $output"
    pass "expired evidence cannot authorise deployment"
}

test_concurrent_deploy_is_refused() {
    new_fixture
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    mkdir -p "$TEST_ROOT/state/App.lock"
    printf '%s\n' "$$" > "$TEST_ROOT/state/App.lock/pid"
    local output
    if output="$(run_tool deploy 2>&1)"; then
        fail "deploy succeeded while another process held the lock"
    fi
    [[ "$output" == *"already running"* ]] || fail "concurrent-run error was not explicit: $output"
    if output="$(run_tool trust-current --owner-override "concurrent trust rewrite" 2>&1)"; then
        fail "trust record was rewritten while deployment lock was held"
    fi
    [[ "$output" == *"already running"* ]] || fail "concurrent evidence-write error was not explicit: $output"
    pass "concurrent deployments are refused before authentication"
}

test_authentication_failure_precedes_archive() {
    new_fixture
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local trusted_fingerprint current_fingerprint auth_mode_fingerprint
    trusted_fingerprint="$(sed -n '1p' "$TEST_ROOT/state/App.trusted-inputs")"
    current_fingerprint="$(run_tool fingerprint)"
    auth_mode_fingerprint="$(FAKE_MODE=auth_missing run_tool fingerprint)"
    [[ "$trusted_fingerprint" == "$current_fingerprint" && "$current_fingerprint" == "$auth_mode_fingerprint" ]] || fail "fixture fingerprint drifted before authentication test: trusted=$trusted_fingerprint current=$current_fingerprint auth=$auth_mode_fingerprint"
    local output
    if output="$(FAKE_MODE=auth_missing run_tool deploy 2>&1)"; then
        fail "deploy succeeded with missing authentication"
    fi
    [[ "$output" == *"Missing local auth profile"* ]] || fail "authentication error was not explicit: $output"
    ! grep -q ' archive ' "$TEST_ROOT/fake.log" || fail "archive started before authentication failed"
    pass "authentication failure occurs before archive work"
}

test_input_change_during_archive_stops_upload() {
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local output
    if output="$(FAKE_MODE=input_change run_tool deploy 2>&1)"; then
        fail "deploy succeeded after an input changed during archive"
    fi
    [[ "$output" == *"changed during archive"* ]] || fail "post-archive input error was not explicit: $output"
    ! grep -q -- '-exportArchive' "$TEST_ROOT/fake.log" || fail "upload began after an input changed during archive"
    pass "inputs are revalidated after archive creation"
}

test_evidence_baseline_race_stops_upload() {
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local output
    if output="$(FAKE_MODE=evidence_baseline_race run_tool deploy 2>&1)"; then
        fail "deploy absorbed an edit made after evidence verification"
    fi
    [[ "$output" == *"changed during archive creation"* ]] || fail "evidence-baseline race was not explicit: $output"
    ! grep -q -- '-exportArchive' "$TEST_ROOT/fake.log" || fail "upload began after the trusted-input boundary was crossed"
    pass "deployment cannot re-baseline inputs after evidence verification"
}

test_archive_team_mismatch_stops_upload() {
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local output
    if output="$(FAKE_ARCHIVE_TEAM=WRONGTEAM FAKE_MODE=success run_tool deploy 2>&1)"; then
        fail "deploy succeeded with the wrong archived team"
    fi
    [[ "$output" == *"Archive team mismatch"* ]] || fail "archive-team error was not explicit: $output"
    ! grep -q -- '-exportArchive' "$TEST_ROOT/fake.log" || fail "upload began with the wrong archived team"
    pass "archive team mismatch prevents upload"
}

test_archive_binary_and_profile_failures_stop_upload() {
    local mode expected output
    for mode in wrong_executable_arch expired_profile unknown_signing_identity codesign_verify_failure signed_entitlement_mismatch unexpected_signed_entitlement profile_team_mismatch profile_app_mismatch; do
        new_fixture
        write_auth_profile
        run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
        case "$mode" in
            wrong_executable_arch) expected='does not contain arm64' ;;
            expired_profile) expected='provisioning profile is expired' ;;
            unknown_signing_identity) expected='recognised Apple app identity' ;;
            codesign_verify_failure) expected='code signature verification failed' ;;
            signed_entitlement_mismatch) expected='signing team entitlement mismatch' ;;
            unexpected_signed_entitlement) expected='unexpected Release entitlement' ;;
            profile_team_mismatch) expected='provisioning team mismatch' ;;
            profile_app_mismatch) expected='provisioning application identifier mismatch' ;;
        esac
        if output="$(FAKE_MODE="$mode" run_tool deploy 2>&1)"; then
            fail "deploy succeeded for archive failure mode $mode"
        fi
        [[ "$output" == *"$expected"* ]] || fail "$mode error was not explicit: $output"
        ! grep -q -- '-exportArchive' "$TEST_ROOT/fake.log" || fail "upload began for archive failure mode $mode"
    done
    pass "archive architecture, signatures, entitlements and provisioning are fail-closed"
}

test_processing_failure_is_not_success() {
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local output
    if output="$(FAKE_MODE=processing_failure run_tool deploy 2>&1)"; then
        fail "deploy reported success after Apple processing failed"
    fi
    [[ "$output" == *"processing failed"* || "$output" == *"processing response"* ]] || fail "processing error was not explicit: $output"
    pass "Apple processing failure cannot report success"
}

test_wrong_audience_is_not_ready() {
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local output
    if output="$(FAKE_MODE=wrong_audience run_tool deploy 2>&1)"; then
        fail "deploy reported readiness for an App Store eligible build"
    fi
    [[ "$output" == *"audience"* ]] || fail "audience mismatch was not explicit: $output"
    pass "wrong TestFlight audience cannot report readiness"
}

test_missing_export_compliance_is_not_ready() {
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local output
    if output="$(FAKE_MODE=missing_compliance run_tool deploy 2>&1)"; then
        fail "deploy reported readiness while export compliance was missing"
    fi
    [[ "$output" == *"MISSING_EXPORT_COMPLIANCE"* ]] || fail "missing export-compliance state was not explicit: $output"
    pass "missing export compliance cannot report internal tester readiness"
}

test_api_authentication_failure_precedes_archive() {
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local output
    if output="$(FAKE_MODE=api_auth_failure run_tool deploy 2>&1)"; then
        fail "deploy succeeded with rejected API authentication"
    fi
    [[ "$output" == *"HTTP 401"* ]] || fail "API authentication error was not explicit: $output"
    ! grep -q ' archive ' "$TEST_ROOT/fake.log" || fail "archive started before API authentication failed"
    pass "API capability authentication is verified before archive work"
}

test_processing_timeout_and_malformed_api_fail_closed() {
    new_fixture
    write_auth_profile
    /usr/bin/plutil -replace processingTimeoutSeconds -integer 2 "$TEST_ROOT/repo/.ios-testflight.json"
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local output
    if output="$(FAKE_MODE=processing_timeout run_tool deploy 2>&1)"; then
        fail "deploy succeeded after processing timeout"
    fi
    [[ "$output" == *"did not complete within 2 seconds"* ]] || fail "processing-timeout error was not explicit: $output"
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    if output="$(FAKE_MODE=malformed_api run_tool deploy 2>&1)"; then
        fail "deploy succeeded with malformed API data"
    fi
    [[ "$output" == *"invalid JSON"* ]] || fail "malformed-API error was not explicit: $output"
    pass "processing timeout and malformed API responses fail closed"
}

test_missing_group_build_is_not_ready() {
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local output
    if output="$(FAKE_MODE=missing_group_build run_tool deploy 2>&1)"; then
        fail "deploy reported readiness without group access to the build"
    fi
    [[ "$output" == *"not available to the configured internal TestFlight group"* ]] || fail "missing group-build relationship was not explicit: $output"
    pass "missing beta-group assignment cannot report readiness"
}

test_missing_tester_is_not_ready() {
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local output
    if output="$(FAKE_MODE=missing_tester run_tool deploy 2>&1)"; then
        fail "deploy reported readiness without the intended tester"
    fi
    [[ "$output" == *"Intended tester account is not in"* ]] || fail "missing tester was not explicit: $output"
    pass "missing intended tester cannot report readiness"
}

test_inactive_tester_is_not_ready() {
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local output
    if output="$(FAKE_MODE=inactive_tester run_tool deploy 2>&1)"; then
        fail "deploy reported readiness for an invited but unaccepted tester"
    fi
    [[ "$output" == *"state: INVITED"* ]] || fail "inactive tester state was not explicit: $output"
    pass "only accepted or installed tester states can report readiness"
}

test_forbidden_release_resource_stops_upload() {
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local output
    if output="$(FAKE_MODE=forbidden_resource run_tool deploy 2>&1)"; then
        fail "deploy succeeded with an internal-only resource"
    fi
    [[ "$output" == *"Forbidden release resource"* ]] || fail "forbidden-resource error was not explicit: $output"
    ! grep -q -- '-exportArchive' "$TEST_ROOT/fake.log" || fail "upload began with a forbidden release resource"
    pass "forbidden release resources prevent upload"
}

test_success_emits_ready_receipt() {
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local output
    output="$(FAKE_MODE=success run_tool deploy 2>&1)" || fail "successful fixture failed: $output"
    [[ "$output" == *"Ready for internal tester"* ]] || fail "success did not report tester readiness: $output"
    local receipt
    receipt="$(find "$TEST_ROOT/receipts" -type f -name '*.json' -print -quit 2>/dev/null || true)"
    [[ -n "$receipt" ]] || fail "success did not produce a JSON receipt"
    [[ "$(/usr/bin/plutil -extract status raw -o - "$receipt")" == "ready_for_internal_tester" ]] || fail "receipt status was not ready_for_internal_tester"
    [[ "$(/usr/bin/plutil -extract audience raw -o - "$receipt")" == "INTERNAL_ONLY" ]] || fail "receipt audience was not INTERNAL_ONLY"
    [[ "$(/usr/bin/plutil -extract appStoreConnectBuildID raw -o - "$receipt")" == "BUILD123" ]] || fail "receipt omitted the verified ASC build ID"
    [[ "$(/usr/bin/plutil -extract internalBetaState raw -o - "$receipt")" == "READY_FOR_BETA_TESTING" ]] || fail "receipt omitted the verified internal beta state"
    [[ "$(/usr/bin/plutil -extract betaGroupID raw -o - "$receipt")" == "GROUP123" ]] || fail "receipt omitted the verified beta group ID"
    [[ "$(/usr/bin/plutil -extract testerID raw -o - "$receipt")" == "TESTER123" ]] || fail "receipt omitted the verified tester ID"
    [[ "$(/usr/bin/plutil -extract testerState raw -o - "$receipt")" == "ACCEPTED" ]] || fail "receipt omitted the verified tester state"
    [[ "$(/usr/bin/plutil -extract archiveInputFingerprint raw -o - "$receipt")" == "$(sed -n '1p' "$TEST_ROOT/state/App.trusted-inputs")" ]] || fail "receipt fingerprint differed from verified evidence"
    [[ "$(/usr/bin/plutil -extract evidenceType raw -o - "$receipt")" == "owner-override" ]] || fail "receipt evidence type was inaccurate"
    /usr/bin/plutil -extract timings.archiveSeconds raw -o - "$receipt" >/dev/null || fail "receipt omitted archive timing"
    /usr/bin/plutil -extract timings.uploadSeconds raw -o - "$receipt" >/dev/null || fail "receipt omitted upload timing"
    /usr/bin/plutil -extract timings.processingSeconds raw -o - "$receipt" >/dev/null || fail "receipt omitted processing timing"
    /usr/bin/plutil -extract timings.readinessSeconds raw -o - "$receipt" >/dev/null || fail "receipt omitted readiness timing"
    [[ -f "$receipt.sha256" && "$(cat "$receipt.sha256")" == "$(/usr/bin/shasum -a 256 "$receipt" | awk '{print $1}')" ]] || fail "receipt integrity hash was missing or invalid"
    pass "successful deployment emits a machine-readable readiness receipt"
}

test_xcresult_provenance_reaches_receipt() {
    new_fixture
    write_auth_profile
    run_tool test-and-trust ridehorizon-unit >/dev/null
    local trusted_count trusted_hash output receipt
    trusted_count="$(sed -n 's/^testCount=//p' "$TEST_ROOT/state/App.trusted-inputs")"
    trusted_hash="$(sed -n 's/^summarySha256=//p' "$TEST_ROOT/state/App.trusted-inputs")"
    output="$(FAKE_MODE=success run_tool deploy 2>&1)" || fail "xcresult-provenance fixture failed: $output"
    receipt="$(find "$TEST_ROOT/receipts" -type f -name '*.json' -print -quit 2>/dev/null || true)"
    [[ "$(/usr/bin/plutil -extract evidenceType raw -o - "$receipt")" == "xcresult" ]] || fail "receipt lost xcresult evidence type"
    [[ "$(/usr/bin/plutil -extract evidenceTestCount raw -o - "$receipt")" == "$trusted_count" ]] || fail "receipt lost verified test count"
    [[ "$(/usr/bin/plutil -extract evidenceSummarySha256 raw -o - "$receipt")" == "$trusted_hash" ]] || fail "receipt lost verified xcresult summary hash"
    pass "xcresult test provenance is preserved in the deployment receipt"
}

test_configured_tests_are_atomically_bound() {
    new_fixture
    local output
    output="$(run_tool test-and-trust ridehorizon-unit 2>&1)" || fail "successful configured tests were rejected: $output"
    [[ "$(sed -n 's/^evidenceType=//p' "$TEST_ROOT/state/App.trusted-inputs")" == "xcresult" ]] || fail "xcresult evidence type was not recorded"
    [[ "$(sed -n 's/^profile=//p' "$TEST_ROOT/state/App.trusted-inputs")" == "ridehorizon-unit" ]] || fail "xcresult profile was not recorded"
    rm -f "$TEST_ROOT/state/App.trusted-inputs"
    if output="$(FAKE_MODE=xcresult_failure run_tool test-and-trust ridehorizon-unit 2>&1)"; then
        fail "failing configured tests were trusted"
    fi
    [[ ! -f "$TEST_ROOT/state/App.trusted-inputs" ]] || fail "failing tests wrote a trust record"
    if output="$(FAKE_MODE=test_input_change run_tool test-and-trust ridehorizon-unit 2>&1)"; then
        fail "tests trusted inputs that changed during execution"
    fi
    [[ "$output" == *"changed while tests were running"* ]] || fail "test/input race was not explicit: $output"
    if output="$(run_tool test-and-trust invented-profile 2>&1)"; then
        fail "unconfigured evidence profile was accepted"
    fi
    pass "configured tests atomically bind their exact input fingerprint"
}

test_traversal_failure_fails_closed() {
    new_fixture
    local output
    if output="$(FAKE_MODE=find_failure run_tool fingerprint 2>&1)"; then
        fail "fingerprint succeeded after input traversal failed"
    fi
    [[ "$output" == *"Could not enumerate every file"* ]] || fail "traversal error was not explicit: $output"
    pass "input traversal failures cannot produce a partial fingerprint"
}

test_stale_private_key_is_recovered_safely() {
    new_fixture
    local stale="$TEST_ROOT/tmp/ios-testflight.ABC123"
    mkdir -p "$stale"
    printf 'format=ios-testflight-private-run-v1\npid=999999\nrepo=%s\nrunDir=%s\nscheme=App\n' "$TEST_ROOT/repo" "$stale" > "$stale/.ios-testflight-run"
    printf '%s\n' 'fixture private key' > "$stale/AuthKey_STALE.p8"
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    run_tool deploy >/dev/null 2>&1 || true
    [[ ! -e "$stale" ]] || fail "dead marked run directory containing a key was not recovered"
    pass "stale marked credential directories from dead runs are recovered"
}

test_private_key_is_removed_after_ordinary_failure() {
    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    FAKE_MODE=processing_failure run_tool deploy >/dev/null 2>&1 || true
    ! find "$TEST_ROOT/tmp" -name 'AuthKey_*.p8' -print -quit | grep -q . || fail "temporary private key remained after ordinary failure"

    new_fixture
    write_auth_profile
    run_tool trust-current --owner-override "fixture no-test deployment" >/dev/null
    local output status
    set +e
    output="$(FAKE_MODE=term_during_archive run_tool deploy 2>&1)"
    status=$?
    set -e
    [[ "$status" == "143" ]] || fail "TERM did not stop deployment with status 143: status=$status output=$output"
    ! find "$TEST_ROOT/tmp" -name 'AuthKey_*.p8' -print -quit | grep -q . || fail "temporary private key remained after TERM"
    ! grep -q -- '-exportArchive' "$TEST_ROOT/fake.log" || fail "upload continued after TERM"
    pass "temporary private key is removed after ordinary failure and TERM stops deployment"
}

test_embedded_jwt_helper_runs_with_ephemeral_key() {
    new_fixture
    local swift_source="$TEST_ROOT/tmp/jwt.swift"
    local private_key="$TEST_ROOT/tmp/fixture-private-key.p8"
    local module_cache="$TEST_ROOT/tmp/module-cache"
    mkdir -p "$module_cache"
    awk '/^import CryptoKit$/{capture=1} capture && /^SWIFT$/{exit} capture{print}' "$TOOLS_ROOT/ios-testflight" > "$swift_source"
    /usr/bin/openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$private_key" >/dev/null 2>&1
    local token
    token="$(SWIFT_MODULECACHE_PATH="$module_cache" CLANG_MODULE_CACHE_PATH="$module_cache" XDG_CACHE_HOME="$TEST_ROOT/tmp" /usr/bin/xcrun swift "$swift_source" KEY1234567 00000000-0000-0000-0000-000000000000 "$private_key")" || fail "embedded JWT helper did not run"
    [[ "$token" == *.*.* && "$token" != *PRIVATE* ]] || fail "embedded JWT helper returned an invalid token shape"
    pass "embedded App Store Connect JWT helper signs with an ephemeral P-256 key"
}

test_configuration_changes_invalidate_fingerprint
test_tool_changes_and_schema_are_fail_closed
test_missing_input_fails_closed
test_arbitrary_evidence_is_rejected
test_expired_evidence_is_rejected
test_concurrent_deploy_is_refused
test_authentication_failure_precedes_archive
test_input_change_during_archive_stops_upload
test_evidence_baseline_race_stops_upload
test_archive_team_mismatch_stops_upload
test_archive_binary_and_profile_failures_stop_upload
test_processing_failure_is_not_success
test_wrong_audience_is_not_ready
test_missing_export_compliance_is_not_ready
test_api_authentication_failure_precedes_archive
test_processing_timeout_and_malformed_api_fail_closed
test_missing_group_build_is_not_ready
test_missing_tester_is_not_ready
test_inactive_tester_is_not_ready
test_forbidden_release_resource_stops_upload
test_success_emits_ready_receipt
test_xcresult_provenance_reaches_receipt
test_configured_tests_are_atomically_bound
test_traversal_failure_fails_closed
test_stale_private_key_is_recovered_safely
test_private_key_is_removed_after_ordinary_failure
test_embedded_jwt_helper_runs_with_ephemeral_key
printf 'RESULT: %d tests passed\n' "$PASS_COUNT"
