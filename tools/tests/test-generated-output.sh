#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

readonly TOOLS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT=""
REPO_ROOT=""
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
    local temp_parent="${TMPDIR:-/private/tmp}"
    TEST_ROOT="$(mktemp -d "${temp_parent%/}/ridehorizon-generated-output-test.XXXXXX")"
    REPO_ROOT="$TEST_ROOT/repo"
    git init -q "$REPO_ROOT"
}

run_tool() {
    RIDEHORIZON_GENERATED_OUTPUT_REPO_ROOT="$REPO_ROOT" \
    RIDEHORIZON_DERIVED_DATA_ROOT="$TEST_ROOT/RideHorizonDerivedData" \
    RIDEHORIZON_DERIVED_DATA_KEY="fixture-task" \
    "$TOOLS_ROOT/generated-output" "$@"
}

test_task_cleanup_removes_disposable_output_only() {
    new_fixture
    mkdir -p \
        "$REPO_ROOT/fact-proxy/build/classes" \
        "$REPO_ROOT/fact-proxy/out/classes" \
        "$REPO_ROOT/privacy-site/.wrangler/state" \
        "$REPO_ROOT/tools/apple-place-audit/.build/bin" \
        "$REPO_ROOT/scripts/__pycache__" \
        "$REPO_ROOT/fact-proxy/.idea" \
        "$REPO_ROOT/RideHorizon.xcodeproj/xcuserdata" \
        "$REPO_ROOT/fact-proxy/.gradle/cache" \
        "$REPO_ROOT/build/TestFlight/App.xcarchive/__pycache__"
    printf 'generated\n' > "$REPO_ROOT/fact-proxy/build/classes/value"
    printf 'generated\n' > "$REPO_ROOT/fact-proxy/out/classes/value"
    printf 'generated\n' > "$REPO_ROOT/privacy-site/.wrangler/state/value"
    printf 'generated\n' > "$REPO_ROOT/tools/apple-place-audit/.build/bin/value"
    printf 'generated\n' > "$REPO_ROOT/scripts/__pycache__/value.pyc"
    printf 'generated\n' > "$REPO_ROOT/fact-proxy/.idea/workspace.xml"
    printf 'generated\n' > "$REPO_ROOT/fact-proxy/fact-proxy.iml"
    printf 'generated\n' > "$REPO_ROOT/RideHorizon.xcodeproj/project.xcuserstate"
    printf 'generated\n' > "$REPO_ROOT/RideHorizon.xcodeproj/xcuserdata/value"
    printf 'cache\n' > "$REPO_ROOT/fact-proxy/.gradle/cache/value"
    printf 'archive\n' > "$REPO_ROOT/build/TestFlight/App.xcarchive/Info.plist"
    printf 'archive metadata\n' > "$REPO_ROOT/build/TestFlight/App.xcarchive/__pycache__/retained.pyc"
    printf 'metadata\n' > "$REPO_ROOT/.DS_Store"

    run_tool clean-task >/dev/null

    [[ ! -e "$REPO_ROOT/fact-proxy/build" ]] || fail "proxy build output was retained"
    [[ ! -e "$REPO_ROOT/fact-proxy/out" ]] || fail "proxy IDE output was retained"
    [[ ! -e "$REPO_ROOT/privacy-site/.wrangler" ]] || fail "Wrangler output was retained"
    [[ ! -e "$REPO_ROOT/tools/apple-place-audit/.build" ]] || fail "audit build output was retained"
    [[ ! -e "$REPO_ROOT/scripts/__pycache__" ]] || fail "Python cache was retained"
    [[ ! -e "$REPO_ROOT/fact-proxy/.idea" ]] || fail "IDE metadata directory was retained"
    [[ ! -e "$REPO_ROOT/fact-proxy/fact-proxy.iml" ]] || fail "IDE module file was retained"
    [[ ! -e "$REPO_ROOT/RideHorizon.xcodeproj/project.xcuserstate" ]] || fail "Xcode user state was retained"
    [[ ! -e "$REPO_ROOT/RideHorizon.xcodeproj/xcuserdata" ]] || fail "Xcode user data was retained"
    [[ ! -e "$REPO_ROOT/.DS_Store" ]] || fail "OS metadata was retained"
    [[ -f "$REPO_ROOT/fact-proxy/.gradle/cache/value" ]] || fail "dependency cache was removed by task cleanup"
    [[ -f "$REPO_ROOT/build/TestFlight/App.xcarchive/Info.plist" ]] || fail "release archive was removed"
    [[ -f "$REPO_ROOT/build/TestFlight/App.xcarchive/__pycache__/retained.pyc" ]] || fail "release archive contents were altered"
    pass "task cleanup removes disposable output and retains caches and release evidence"
}

test_task_cleanup_retains_tracked_generated_looking_files() {
    new_fixture
    mkdir -p "$REPO_ROOT/scripts/__pycache__"
    printf 'tracked\n' > "$REPO_ROOT/scripts/__pycache__/tracked.pyc"
    git -C "$REPO_ROOT" add -f scripts/__pycache__/tracked.pyc

    run_tool clean-task >/dev/null

    [[ -f "$REPO_ROOT/scripts/__pycache__/tracked.pyc" ]] || fail "tracked generated-looking file was removed"
    pass "task cleanup retains tracked files"
}

test_dependency_prune_uses_thirty_day_activity() {
    new_fixture
    mkdir -p "$REPO_ROOT/fact-proxy/.gradle/cache" "$REPO_ROOT/privacy-site/node_modules/package"
    printf 'stale\n' > "$REPO_ROOT/fact-proxy/.gradle/cache/value"
    printf 'recent\n' > "$REPO_ROOT/privacy-site/node_modules/package/value"
    run_tool mark-dependency fact-proxy/.gradle >/dev/null
    run_tool mark-dependency privacy-site/node_modules >/dev/null
    touch -t 202001010000 "$REPO_ROOT/fact-proxy/.gradle/.ridehorizon-last-used"
    touch -t 202001010000 "$REPO_ROOT/privacy-site/node_modules/package/value"

    run_tool prune-dependencies 30 >/dev/null

    [[ ! -e "$REPO_ROOT/fact-proxy/.gradle" ]] || fail "stale dependency cache was retained"
    [[ -f "$REPO_ROOT/privacy-site/node_modules/package/value" ]] || fail "recent dependency cache was removed"
    pass "dependency pruning removes stale caches and retains recent caches"
}

test_dependency_prune_initialises_unmarked_cache() {
    new_fixture
    mkdir -p "$REPO_ROOT/fact-proxy/terraform/.terraform/providers"
    printf 'unknown use\n' > "$REPO_ROOT/fact-proxy/terraform/.terraform/providers/value"
    touch -t 202001010000 "$REPO_ROOT/fact-proxy/terraform/.terraform/providers/value"

    run_tool prune-dependencies 30 >/dev/null

    [[ -f "$REPO_ROOT/fact-proxy/terraform/.terraform/providers/value" ]] || fail "unmarked dependency cache was deleted"
    [[ -f "$REPO_ROOT/fact-proxy/terraform/.terraform/.ridehorizon-last-used" ]] || fail "unmarked dependency cache received no retention marker"
    touch -t 202001010000 "$REPO_ROOT/fact-proxy/terraform/.terraform/.ridehorizon-last-used"
    run_tool prune-dependencies 30 >/dev/null
    [[ ! -e "$REPO_ROOT/fact-proxy/terraform/.terraform" ]] || fail "initialised dependency cache never became eligible for pruning"
    pass "dependency pruning gives unmarked caches one grace period before age-based removal"
}

test_dependency_force_cleanup_is_explicit() {
    new_fixture
    mkdir -p "$REPO_ROOT/fact-proxy/.tools/jdk"
    printf 'recent\n' > "$REPO_ROOT/fact-proxy/.tools/jdk/value"

    run_tool clean-dependencies >/dev/null

    [[ ! -e "$REPO_ROOT/fact-proxy/.tools" ]] || fail "explicit dependency cleanup retained the cache"
    pass "explicit dependency cleanup supports disk-pressure recovery"
}

test_dependency_cleanup_rejects_symlink_targets() {
    new_fixture
    mkdir -p "$TEST_ROOT/protected" "$REPO_ROOT/fact-proxy"
    printf 'keep\n' > "$TEST_ROOT/protected/value"
    ln -s "$TEST_ROOT/protected" "$REPO_ROOT/fact-proxy/.tools"

    local output
    if output="$(run_tool clean-dependencies 2>&1)"; then
        fail "dependency cleanup accepted a symlink target"
    fi
    [[ "$output" == *"Refusing symbolic-link path component"* ]] || fail "symlink error was unclear: $output"
    [[ -f "$TEST_ROOT/protected/value" ]] || fail "dependency cleanup followed a symlink"
    pass "dependency cleanup rejects symlink targets"
}

test_dependency_mark_rejects_marker_symlinks() {
    new_fixture
    mkdir -p "$REPO_ROOT/fact-proxy/.gradle" "$TEST_ROOT/protected"
    printf 'keep\n' > "$TEST_ROOT/protected/marker"
    ln -s "$TEST_ROOT/protected/marker" "$REPO_ROOT/fact-proxy/.gradle/.ridehorizon-last-used"

    local output
    if output="$(run_tool mark-dependency fact-proxy/.gradle 2>&1)"; then
        fail "dependency marking accepted a marker symlink"
    fi
    [[ "$output" == *"Dependency marker must not be a symbolic link"* ]] || fail "marker-symlink error was unclear: $output"
    [[ "$(cat "$TEST_ROOT/protected/marker")" == "keep" ]] || fail "dependency marking followed a marker symlink"
    pass "dependency marking rejects marker symlinks"
}

test_dependency_cleanup_rejects_symlinked_ancestors() {
    new_fixture
    mkdir -p "$TEST_ROOT/protected/fact-proxy/.gradle/cache"
    printf 'keep\n' > "$TEST_ROOT/protected/fact-proxy/.gradle/cache/value"
    ln -s "$TEST_ROOT/protected/fact-proxy" "$REPO_ROOT/fact-proxy"

    local output
    if output="$(run_tool prune-dependencies 30 2>&1)"; then
        fail "dependency pruning accepted a symlinked ancestor"
    fi
    [[ "$output" == *"Refusing symbolic-link path component"* ]] || fail "ancestor-symlink error was unclear: $output"
    [[ -f "$TEST_ROOT/protected/fact-proxy/.gradle/cache/value" ]] || fail "dependency pruning changed an external cache"
    pass "dependency pruning rejects symlinked ancestors before traversal"
}

test_dependency_cleanup_rejects_internal_symlinked_ancestors() {
    new_fixture
    mkdir -p "$REPO_ROOT/alternate/.gradle/cache"
    printf 'keep\n' > "$REPO_ROOT/alternate/.gradle/cache/value"
    ln -s "$REPO_ROOT/alternate" "$REPO_ROOT/fact-proxy"

    local output
    if output="$(run_tool prune-dependencies 30 2>&1)"; then
        fail "dependency pruning accepted an internal symlinked ancestor"
    fi
    [[ "$output" == *"Refusing symbolic-link path component"* ]] || fail "internal ancestor-symlink error was unclear: $output"
    [[ -f "$REPO_ROOT/alternate/.gradle/cache/value" ]] || fail "dependency pruning changed an internal aliased cache"
    pass "dependency pruning rejects internal symlinked ancestors"
}

test_dependency_cleanup_rejects_tracked_content() {
    new_fixture
    mkdir -p "$REPO_ROOT/fact-proxy/.tools"
    printf 'tracked\n' > "$REPO_ROOT/fact-proxy/.tools/value"
    git -C "$REPO_ROOT" add -f fact-proxy/.tools/value

    local output
    if output="$(run_tool clean-dependencies 2>&1)"; then
        fail "dependency cleanup accepted tracked content"
    fi
    [[ "$output" == *"Refusing tracked generated-output target"* ]] || fail "tracked-content error was unclear: $output"
    [[ -f "$REPO_ROOT/fact-proxy/.tools/value" ]] || fail "dependency cleanup removed tracked content"
    pass "dependency cleanup rejects tracked content"
}

test_dependency_cleanup_rejects_unowned_target() {
    new_fixture
    mkdir -p "$REPO_ROOT/fact-proxy/.tools" "$TEST_ROOT/bin"
    printf 'keep\n' > "$REPO_ROOT/fact-proxy/.tools/value"
    cat > "$TEST_ROOT/bin/stat" <<'EOF'
#!/bin/bash
last="${!#}"
if [[ "$last" == *"fact-proxy/.tools" ]]; then
    printf '999999\n'
else
    /usr/bin/stat "$@"
fi
EOF
    chmod +x "$TEST_ROOT/bin/stat"

    local output
    if output="$(PATH="$TEST_ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin" run_tool clean-dependencies 2>&1)"; then
        fail "dependency cleanup accepted an unowned target"
    fi
    [[ "$output" == *"not owned by the current user"* ]] || fail "ownership error was unclear: $output"
    [[ -f "$REPO_ROOT/fact-proxy/.tools/value" ]] || fail "dependency cleanup removed an unowned target"
    pass "dependency cleanup rejects unowned targets"
}

test_cleanup_fails_closed_when_git_inspection_fails() {
    new_fixture
    mkdir -p "$REPO_ROOT/fact-proxy/build" "$TEST_ROOT/bin"
    printf 'keep\n' > "$REPO_ROOT/fact-proxy/build/value"
    cat > "$TEST_ROOT/bin/git" <<'EOF'
#!/bin/bash
if [[ "$*" == *"rev-parse --is-inside-work-tree"* ]]; then
    printf 'true\n'
    exit 0
fi
if [[ "$*" == *"ls-files"* ]]; then
    exit 42
fi
exec /usr/bin/git "$@"
EOF
    chmod +x "$TEST_ROOT/bin/git"

    local output
    if output="$(PATH="$TEST_ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin" run_tool clean-task 2>&1)"; then
        fail "cleanup proceeded after Git inspection failed"
    fi
    [[ "$output" == *"Could not inspect tracked content"* ]] || fail "Git failure was unclear: $output"
    [[ -f "$REPO_ROOT/fact-proxy/build/value" ]] || fail "cleanup removed output after Git inspection failed"
    pass "cleanup fails closed when Git inspection fails"
}

test_task_cleanup_refuses_embedded_release_evidence() {
    new_fixture
    mkdir -p "$REPO_ROOT/fact-proxy/build/App.xcresult"
    printf 'evidence\n' > "$REPO_ROOT/fact-proxy/build/App.xcresult/value"

    local output
    if output="$(run_tool clean-task 2>&1)"; then
        fail "task cleanup accepted embedded release evidence"
    fi
    [[ "$output" == *"protected release evidence"* ]] || fail "release-evidence error was unclear: $output"
    [[ -f "$REPO_ROOT/fact-proxy/build/App.xcresult/value" ]] || fail "task cleanup removed release evidence"
    pass "task cleanup refuses targets containing release evidence"
}

test_completion_runs_the_full_retention_lifecycle() {
    new_fixture
    RIDEHORIZON_DERIVED_DATA_ROOT="$TEST_ROOT/RideHorizonDerivedData" \
    RIDEHORIZON_DERIVED_DATA_KEY="fixture-task" \
    "$TOOLS_ROOT/derived-data" path >/dev/null
    mkdir -p \
        "$TEST_ROOT/RideHorizonDerivedData/fixture-task/Build/Products" \
        "$TEST_ROOT/RideHorizonDerivedData/fixture-task/Logs/Test/Run.xcresult"
    printf 'cache\n' > "$TEST_ROOT/RideHorizonDerivedData/fixture-task/Build/Products/value"
    printf 'evidence\n' > "$TEST_ROOT/RideHorizonDerivedData/fixture-task/Logs/Test/Run.xcresult/value"
    mkdir -p "$REPO_ROOT/fact-proxy/build/classes" "$REPO_ROOT/fact-proxy/.gradle/cache"
    printf 'generated\n' > "$REPO_ROOT/fact-proxy/build/classes/value"
    printf 'stale\n' > "$REPO_ROOT/fact-proxy/.gradle/cache/value"
    run_tool mark-dependency fact-proxy/.gradle >/dev/null
    touch -t 202001010000 "$REPO_ROOT/fact-proxy/.gradle/.ridehorizon-last-used"

    run_tool complete >/dev/null

    [[ ! -e "$TEST_ROOT/RideHorizonDerivedData/fixture-task/Build" ]] || fail "completion retained disposable task DerivedData"
    [[ -f "$TEST_ROOT/RideHorizonDerivedData/fixture-task/Logs/Test/Run.xcresult/value" ]] || fail "completion removed result evidence"
    [[ ! -e "$REPO_ROOT/fact-proxy/build" ]] || fail "completion retained task output"
    [[ ! -e "$REPO_ROOT/fact-proxy/.gradle" ]] || fail "completion retained stale dependency cache"
    pass "completion runs the full retention lifecycle"
}

test_task_cleanup_removes_disposable_output_only
test_task_cleanup_retains_tracked_generated_looking_files
test_dependency_prune_uses_thirty_day_activity
test_dependency_prune_initialises_unmarked_cache
test_dependency_force_cleanup_is_explicit
test_dependency_cleanup_rejects_symlink_targets
test_dependency_mark_rejects_marker_symlinks
test_dependency_cleanup_rejects_symlinked_ancestors
test_dependency_cleanup_rejects_internal_symlinked_ancestors
test_dependency_cleanup_rejects_tracked_content
test_dependency_cleanup_rejects_unowned_target
test_cleanup_fails_closed_when_git_inspection_fails
test_task_cleanup_refuses_embedded_release_evidence
test_completion_runs_the_full_retention_lifecycle

printf 'All %s generated-output tests passed.\n' "$PASS_COUNT"
