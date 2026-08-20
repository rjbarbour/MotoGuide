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
    TEST_ROOT="$(mktemp -d "${TMPDIR:-/private/tmp}/ridehorizon-derived-data-test.XXXXXX")"
    mkdir -p "$TEST_ROOT/RideHorizonDerivedData"
}

run_tool() {
    RIDEHORIZON_DERIVED_DATA_ROOT="$TEST_ROOT/RideHorizonDerivedData" "$TOOLS_ROOT/derived-data" "$@"
}

test_path_uses_one_parent_and_sanitises_branch_keys() {
    new_fixture
    local output
    output="$(RIDEHORIZON_DERIVED_DATA_KEY='codex/rh-073-build-output-hygiene' run_tool path)"
    [[ "$output" == "$TEST_ROOT/RideHorizonDerivedData/codex-rh-073-build-output-hygiene-"* ]] || fail "unexpected cache path: $output"
    [[ -f "$output/.last-used" ]] || fail "path did not record active cache use"
    [[ "$(cat "$TEST_ROOT/RideHorizonDerivedData/.ridehorizon-derived-data-root")" == "format=ridehorizon-derived-data-v1" ]] || fail "root ownership marker was not created"
    pass "path uses the external parent and a safe task key"
}

test_clean_removes_only_the_requested_cache() {
    new_fixture
    run_tool path RH-073 >/dev/null
    run_tool path RH-059 >/dev/null
    printf 'cache\n' > "$TEST_ROOT/RideHorizonDerivedData/RH-073/value"
    printf 'keep\n' > "$TEST_ROOT/RideHorizonDerivedData/RH-059/value"
    run_tool clean RH-073 >/dev/null
    [[ ! -e "$TEST_ROOT/RideHorizonDerivedData/RH-073" ]] || fail "requested cache was retained"
    [[ -f "$TEST_ROOT/RideHorizonDerivedData/RH-059/value" ]] || fail "unrelated cache was removed"
    pass "clean removes exactly one task-scoped cache"
}

test_clean_does_not_follow_cache_symlinks() {
    new_fixture
    run_tool path RH-059 >/dev/null
    mkdir -p "$TEST_ROOT/protected"
    printf 'keep\n' > "$TEST_ROOT/protected/value"
    ln -s "$TEST_ROOT/protected" "$TEST_ROOT/RideHorizonDerivedData/RH-073"
    run_tool clean RH-073 >/dev/null
    [[ ! -e "$TEST_ROOT/RideHorizonDerivedData/RH-073" ]] || fail "cache symlink was retained"
    [[ -f "$TEST_ROOT/protected/value" ]] || fail "cleanup followed a cache symlink"
    pass "clean removes a cache symlink without following it"
}

test_prune_preserves_result_evidence_and_removes_disposable_output() {
    new_fixture
    run_tool path RH-076 >/dev/null
    mkdir -p \
        "$TEST_ROOT/RideHorizonDerivedData/RH-076/Build/Products" \
        "$TEST_ROOT/RideHorizonDerivedData/RH-076/Logs/Test/Run.xcresult"
    printf 'cache\n' > "$TEST_ROOT/RideHorizonDerivedData/RH-076/Build/Products/value"
    printf 'evidence\n' > "$TEST_ROOT/RideHorizonDerivedData/RH-076/Logs/Test/Run.xcresult/value"
    touch -t 202001010000 "$TEST_ROOT/RideHorizonDerivedData/RH-076/.last-used"

    run_tool prune 7 >/dev/null

    [[ ! -e "$TEST_ROOT/RideHorizonDerivedData/RH-076/Build" ]] || fail "disposable DerivedData was retained"
    [[ -f "$TEST_ROOT/RideHorizonDerivedData/RH-076/Logs/Test/Run.xcresult/value" ]] || fail "result evidence was removed"
    pass "prune preserves result evidence while removing disposable DerivedData"
}

test_clean_fails_closed_when_evidence_inspection_fails() {
    new_fixture
    run_tool path RH-076 >/dev/null
    mkdir -p "$TEST_ROOT/RideHorizonDerivedData/RH-076/unreadable"
    chmod 000 "$TEST_ROOT/RideHorizonDerivedData/RH-076/unreadable"

    local output
    if output="$(run_tool clean RH-076 2>&1)"; then
        chmod 700 "$TEST_ROOT/RideHorizonDerivedData/RH-076/unreadable"
        fail "clean proceeded after evidence inspection failed"
    fi
    chmod 700 "$TEST_ROOT/RideHorizonDerivedData/RH-076/unreadable"
    [[ "$output" == *"Could not inspect DerivedData for protected evidence"* ]] || fail "evidence-inspection error was unclear: $output"
    [[ -d "$TEST_ROOT/RideHorizonDerivedData/RH-076" ]] || fail "clean removed cache after evidence inspection failed"
    pass "clean fails closed when evidence inspection fails"
}

test_prune_removes_only_stale_directories() {
    new_fixture
    run_tool path stale >/dev/null
    run_tool path recent >/dev/null
    touch -t 202001010000 "$TEST_ROOT/RideHorizonDerivedData/stale/.last-used"
    touch -t 202001010000 "$TEST_ROOT/RideHorizonDerivedData/recent"
    touch "$TEST_ROOT/RideHorizonDerivedData/recent/.last-used"
    run_tool prune 7 >/dev/null
    [[ ! -e "$TEST_ROOT/RideHorizonDerivedData/stale" ]] || fail "stale cache was retained"
    [[ -d "$TEST_ROOT/RideHorizonDerivedData/recent" ]] || fail "recent cache was removed"
    pass "prune removes stale caches and retains recent caches"
}

test_path_automatically_prunes_abandoned_caches() {
    new_fixture
    run_tool path stale >/dev/null
    run_tool path recent >/dev/null
    touch -t 202001010000 "$TEST_ROOT/RideHorizonDerivedData/stale/.last-used"
    touch "$TEST_ROOT/RideHorizonDerivedData/recent/.last-used"

    local current
    current="$(run_tool path current)"

    [[ ! -e "$TEST_ROOT/RideHorizonDerivedData/stale" ]] || fail "path retained an abandoned cache"
    [[ -d "$TEST_ROOT/RideHorizonDerivedData/recent" ]] || fail "path removed a recent cache"
    [[ -d "$current" ]] || fail "path did not prepare the current cache"
    pass "path automatically prunes abandoned caches"
}

test_unsafe_roots_and_keys_are_rejected() {
    new_fixture
    local output
    if output="$(RIDEHORIZON_DERIVED_DATA_ROOT="$TEST_ROOT/not-derived-data" "$TOOLS_ROOT/derived-data" clean RH-073 2>&1)"; then
        fail "unsafe root was accepted"
    fi
    [[ "$output" == *"basename must be RideHorizonDerivedData"* ]] || fail "unsafe-root error was unclear: $output"
    if output="$(run_tool clean '../outside' 2>&1)"; then
        fail "unsafe cache key was accepted"
    fi
    [[ "$output" == *"Invalid DerivedData cache key"* ]] || fail "unsafe-key error was unclear: $output"
    mkdir -p "$TEST_ROOT/unowned/RideHorizonDerivedData/RH-073"
    if output="$(RIDEHORIZON_DERIVED_DATA_ROOT="$TEST_ROOT/unowned/RideHorizonDerivedData" "$TOOLS_ROOT/derived-data" clean RH-073 2>&1)"; then
        fail "unmarked root was accepted for deletion"
    fi
    [[ "$output" == *"missing its RideHorizon ownership marker"* ]] || fail "unmarked-root error was unclear: $output"
    ln -s "$TOOLS_ROOT/.." "$TEST_ROOT/repository-link"
    if output="$(RIDEHORIZON_DERIVED_DATA_ROOT="$TEST_ROOT/repository-link/RideHorizonDerivedData" "$TOOLS_ROOT/derived-data" path RH-073 2>&1)"; then
        fail "root through a symlinked ancestor resolved inside the repository"
    fi
    [[ "$output" == *"must resolve outside the repository"* ]] || fail "physical-root error was unclear: $output"
    pass "unsafe roots and traversal keys are rejected"
}

test_distinct_branch_names_and_worktrees_do_not_collide() {
    new_fixture
    local first second
    first="$(run_tool path 'codex/a-b')"
    second="$(run_tool path 'codex/a/b')"
    [[ "$first" != "$second" ]] || fail "distinct branch names resolved to the same cache"
    pass "distinct branch names resolve to distinct caches"
}

test_changed_uses_the_task_scoped_parent_by_default() {
    new_fixture
    mkdir -p "$TEST_ROOT/bin"
    cat > "$TEST_ROOT/bin/xcodebuild" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "$FAKE_LOG"
EOF
    chmod +x "$TEST_ROOT/bin/xcodebuild"
    : > "$TEST_ROOT/fake.log"
    RIDEHORIZON_DERIVED_DATA_ROOT="$TEST_ROOT/RideHorizonDerivedData" \
    RIDEHORIZON_DERIVED_DATA_KEY="RH-073" \
    FAKE_LOG="$TEST_ROOT/fake.log" \
    PATH="$TEST_ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$TOOLS_ROOT/test-changed" --file RideHorizon/Address.swift >/dev/null
    grep -Fx -- "$TEST_ROOT/RideHorizonDerivedData/RH-073/selective-tests" "$TEST_ROOT/fake.log" >/dev/null || fail "test selector did not use the task-scoped DerivedData path"
    pass "test selector defaults to the task-scoped external parent"
}

test_path_uses_one_parent_and_sanitises_branch_keys
test_clean_removes_only_the_requested_cache
test_clean_does_not_follow_cache_symlinks
test_prune_preserves_result_evidence_and_removes_disposable_output
test_clean_fails_closed_when_evidence_inspection_fails
test_prune_removes_only_stale_directories
test_path_automatically_prunes_abandoned_caches
test_unsafe_roots_and_keys_are_rejected
test_distinct_branch_names_and_worktrees_do_not_collide
test_changed_uses_the_task_scoped_parent_by_default

printf 'All %s DerivedData tests passed.\n' "$PASS_COUNT"
