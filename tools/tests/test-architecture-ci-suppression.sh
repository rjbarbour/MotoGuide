#!/usr/bin/env bash

set -euo pipefail

TOOLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/private/tmp}/architecture-ci-selection.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

repo="$TEST_ROOT/repo"
mkdir -p "$repo/tools"
cp "$TOOLS_ROOT/test-changed" "$repo/tools/test-changed"
chmod +x "$repo/tools/test-changed"
git -C "$repo" init -q
git -C "$repo" checkout -q -b main
git -C "$repo" config user.email test@example.invalid
git -C "$repo" config user.name "Architecture CI fixture"
git -C "$repo" add tools/test-changed
git -C "$repo" commit -q -m baseline
base="$(git -C "$repo" rev-parse HEAD)"

task_path() { printf 'backlog/tasks/rh-%s - batch.md\n' "$1"; }

write_task() {
    local batch="$1" state="$2" path evidence_batch="$1"
    path="$repo/$(task_path "$batch")"
    [[ "$state" == wrong ]] && evidence_batch=013.99
    mkdir -p "$(dirname "$path")"
    {
        printf '%s\n' '---' "id: RH-$batch" '---'
        [[ "$state" != missing && "$state" != deleted ]] && printf 'Local-iOS-Evidence: RH-%s\n' "$evidence_batch"
        printf '%s\n' '- [x] #1 first acceptance' '- [x] #2 second acceptance'
        [[ "$state" == unchecked ]] && printf '%s\n' '- [ ] #3 unchecked acceptance'
    } > "$path"
}

assert_output() {
    local output_file="$1" expected_ios="$2" expected_github_ios="$3" expected_proxy="$4" expected_proxy_deploy="$5"
    grep -qx "ios=$expected_ios" "$output_file"
    grep -qx "github_ios=$expected_github_ios" "$output_file"
    grep -qx "proxy=$expected_proxy" "$output_file"
    grep -qx "proxy_deploy=$expected_proxy_deploy" "$output_file"
}

run_pr_case() {
    local branch="$1" batch="$2" state="$3" expected_github_ios="$4" include_proxy="$5"
    local output_file="$TEST_ROOT/output" selection path proxy proxy_deploy
    path="$(task_path "$batch")"
    git -C "$repo" checkout -q -B "$branch" "$base"
    printf '%s\n' fixture > "$repo/RideHorizon.swift"
    proxy=false; proxy_deploy=false
    if [[ "$include_proxy" == true ]]; then mkdir -p "$repo/fact-proxy"; printf '%s\n' fixture > "$repo/fact-proxy/source.kt"; proxy=true; proxy_deploy=true; fi
    write_task "$batch" "$state"
    [[ "$state" == deleted ]] && rm -f "$repo/$path"
    git -C "$repo" add -A
    git -C "$repo" commit -q -m "$branch"
    : > "$output_file"
    selection="$(GITHUB_EVENT_NAME=pull_request PR_HEAD_REF="$branch" PR_HEAD_REPOSITORY=fixture/MotoGuide CURRENT_REPOSITORY=fixture/MotoGuide GITHUB_OUTPUT="$output_file" "$repo/tools/test-changed" --base "$base" --head HEAD --dry-run --github-output)"
    grep -q 'Selection: iOS=true' <<< "$selection"
    assert_output "$output_file" true "$expected_github_ios" "$proxy" "$proxy_deploy"
}

run_pr_case codex/rh-013.36-dependency-foundation--local-ios-evidence 013.36 valid false false
run_pr_case codex/rh-013.37-ride-orchestration--local-ios-evidence 013.37 valid false true
run_pr_case codex/rh-013.38-announcement-orchestration--local-ios-evidence 013.38 valid false true
run_pr_case codex/rh-013.36-dependency-foundation 013.36 valid true false
run_pr_case codex/rh-013.36-dependency-foundation--local-ios-evidence-extra 013.36 valid true false
run_pr_case codex/rh-013.36-dependency-foundation--local-ios-evidence 013.36 missing true false
run_pr_case codex/rh-013.36-dependency-foundation--local-ios-evidence 013.36 unchecked true false
run_pr_case codex/rh-013.36-dependency-foundation--local-ios-evidence 013.36 wrong true false
run_pr_case codex/rh-013.36-dependency-foundation--local-ios-evidence 013.36 deleted true false
run_pr_case codex/rh-013.99-other--local-ios-evidence 013.36 valid true false

run_main_case() {
    local batch="$1" state="$2" merge_mode="$3" expected_github_ios="$4" include_proxy="$5" message="$6"
    local output_file="$TEST_ROOT/output" selection path side proxy proxy_deploy
    path="$(task_path "$batch")"; side="fixture-$batch-$state-$merge_mode"
    git -C "$repo" checkout -q -B main "$base"
    git -C "$repo" checkout -q -B "$side" "$base"
    printf '%s\n' fixture > "$repo/RideHorizon.swift"
    proxy=false; proxy_deploy=false
    if [[ "$include_proxy" == true ]]; then mkdir -p "$repo/fact-proxy"; printf '%s\n' fixture > "$repo/fact-proxy/source.kt"; proxy=true; proxy_deploy=true; fi
    write_task "$batch" "$state"
    git -C "$repo" add -A
    git -C "$repo" commit -q -m side-change
    if [[ "$state" == deleted ]]; then rm -f "$repo/$path"; git -C "$repo" add -A; git -C "$repo" commit -q -m delete-task; fi
    if [[ "$merge_mode" == merge ]]; then git -C "$repo" checkout -q main; git -C "$repo" merge --no-ff -q "$side" -m "$message"; else git -C "$repo" checkout -q -B main "$side"; fi
    : > "$output_file"
    selection="$(GITHUB_EVENT_NAME=push PUSH_HEAD_REF=refs/heads/main PUSH_HEAD_MESSAGE="$message" GITHUB_OUTPUT="$output_file" "$repo/tools/test-changed" --base "$base" --head HEAD --dry-run --github-output)"
    grep -q 'Selection: iOS=true' <<< "$selection"
    assert_output "$output_file" true "$expected_github_ios" "$proxy" "$proxy_deploy"
}

run_main_case 013.36 valid merge false false $'merge\nLocal-iOS-Evidence: RH-013.36'
run_main_case 013.37 valid merge false true $'merge\nLocal-iOS-Evidence: RH-013.37'
run_main_case 013.38 valid merge false true $'merge\nLocal-iOS-Evidence: RH-013.38'
run_main_case 013.36 missing merge true false $'merge\nLocal-iOS-Evidence: RH-013.36'
run_main_case 013.36 unchecked merge true false $'merge\nLocal-iOS-Evidence: RH-013.36'
run_main_case 013.36 wrong merge true false $'merge\nLocal-iOS-Evidence: RH-013.36'
run_main_case 013.36 deleted merge true false $'merge\nLocal-iOS-Evidence: RH-013.36'
run_main_case 013.36 valid direct true false $'direct\nLocal-iOS-Evidence: RH-013.36'
run_main_case 013.36 valid merge true false $'merge\nLocal-iOS-Evidence: RH-013.37'

git -C "$repo" checkout -q -B main "$base"
printf '%s\n' fixture > "$repo/RideHorizon.swift"
git -C "$repo" add RideHorizon.swift
git -C "$repo" commit -q -m non-main
: > "$TEST_ROOT/output"
GITHUB_EVENT_NAME=push PUSH_HEAD_REF=refs/heads/not-main PUSH_HEAD_MESSAGE=$'merge\nLocal-iOS-Evidence: RH-013.36' GITHUB_OUTPUT="$TEST_ROOT/output" "$repo/tools/test-changed" --base "$base" --head HEAD --dry-run --github-output >/dev/null
grep -qx github_ios=true "$TEST_ROOT/output"

if "$repo/tools/test-changed" --base missing-ref --head HEAD --dry-run >/dev/null 2>&1; then
    printf '%s\n' 'invalid comparison unexpectedly succeeded' >&2
    exit 1
fi

printf '%s\n' 'architecture CI suppression selector fixtures passed'
