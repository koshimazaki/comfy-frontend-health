#!/usr/bin/env bash
# comfy-health scoped commands -- check, diff, branch, lint-review
# Sourced by comfy-health main script. Requires: lib/helpers.sh sourced first.

# These functions implement the complex scoped commands.
# Called from the case statement in comfy-health main script.

cmd_check() {
# "check" maps to "review --prepare" by default
# --branch [BASE]: scope review to only branch-changed files
has_explicit=false
has_branch=false
branch_base="main"
remaining_args=()
for arg in "$@"; do
  case "$arg" in
    --import|--prepare) has_explicit=true; remaining_args+=("$arg") ;;
    --branch) has_branch=true ;;
    --branch=*) has_branch=true; branch_base="${arg#--branch=}" ;;
    --since=*|--commits=*) remaining_args+=("$arg") ;;
    *) remaining_args+=("$arg") ;;
  esac
done

if $has_branch; then
  # Scoped review: copy only branch-changed files to temp dir,
  # pass that as --path so reviewers only see branch contributions.
  parse_scope_flags "$branch_base" "${remaining_args[@]+"${remaining_args[@]}"}"
  resolve_scope_ref "$_BASE"
  ref="$_RESOLVED_REF"

  get_changed_files "$ref"
  all_files=$(echo -e "${_NEW_FILES}\n${_MOD_FILES}" | grep -v '^$' | sort -u || true)

  if [[ -z "$all_files" ]]; then
    echo "No changed .vue/.ts files vs $_BASE — nothing to review."
    exit 0
  fi

  new_count=$(count_lines "$_NEW_FILES")
  mod_count=$(count_lines "$_MOD_FILES")
  current_branch=$(cd "$PROJECT_PATH" && git symbolic-ref --short HEAD 2>/dev/null || echo "detached")

  # Create scoped temp dir with only changed files
  tmpdir=$(mktemp -d)
  trap "rm -rf $tmpdir" EXIT

  while IFS= read -r f; do
    if [[ -n "$f" && -f "$PROJECT_PATH/$f" ]]; then
      mkdir -p "$tmpdir/$(dirname "$f")"
      cp "$PROJECT_PATH/$f" "$tmpdir/$f"
    fi
  done <<< "$all_files"

  # Write branch context file so reviewers understand scope
  cat > "$tmpdir/.branch-context.md" <<CTXEOF
# Branch Review Context
Branch: $current_branch vs $_BASE (merge-base: ${ref:0:8})
New files: $new_count | Modified files: $mod_count

## Scope
This review covers ONLY files changed in this branch.
Score the branch contribution, NOT inherited repo debt.

## Branch-scoped dimensions (skip repo-wide ones)
Focus on: naming_quality, contract_coherence, test_strategy, type_safety,
logic_clarity, dependency_health, performance_awareness, convention_outlier,
error_consistency, abstraction_fitness, design_coherence

Skip (require whole-repo): cross_module_architecture, initialization_coupling,
package_organization, api_surface_coherence, authorization_consistency
CTXEOF

  # Also run deterministic detectors for context
  issues_json=$(run_detectors_on_files "$all_files")
  if [[ -n "$issues_json" && "$issues_json" != "[]" ]]; then
    echo "$issues_json" > "$tmpdir/.detector-findings.json"
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Branch-Scoped Subjective Review"
  echo "Branch: $current_branch vs $_BASE"
  echo "Scope: $new_count new files, $mod_count modified files"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Forward to desloppify review with scoped path (no exec — let trap clean tmpdir)
  if $has_explicit; then
    python3 -m desloppify review --path "$tmpdir" "${remaining_args[@]+"${remaining_args[@]}"}"
    exit $?
  else
    python3 -m desloppify review --prepare --path "$tmpdir" "${remaining_args[@]+"${remaining_args[@]}"}"
    exit $?
  fi
else
  # Standard full-repo review
  if $has_explicit; then
    exec python3 -m desloppify review --path "$PROJECT_PATH" "${remaining_args[@]+"${remaining_args[@]}"}"
  else
    exec python3 -m desloppify review --prepare --path "$PROJECT_PATH" "${remaining_args[@]+"${remaining_args[@]}"}"
  fi
fi
}

cmd_diff() {
parse_scope_flags "HEAD~1" "$@"
# For diff, default ref is HEAD~1 (not merge-base)
if [[ -z "$_SINCE" && -z "$_COMMITS" && -z "$_EXPLICIT_REF" ]]; then
  _RESOLVED_REF="HEAD~1"
else
  resolve_scope_ref "HEAD"
fi
ref="$_RESOLVED_REF"

get_changed_files "$ref"
all_files=$(echo -e "${_NEW_FILES}\n${_MOD_FILES}" | grep -v '^$' | sort -u || true)
if [[ -z "$all_files" ]]; then
  echo "No changed .vue/.ts files since $ref"
  exit 0
fi

new_count=$(count_lines "$_NEW_FILES")
mod_count=$(count_lines "$_MOD_FILES")
echo "Diff scope: $new_count new, $mod_count modified files since $ref"
echo ""

issues_json=$(run_detectors_on_files "$all_files")
output=$(classify_and_report_issues "$issues_json" "$_NEW_FILES" "$_MOD_FILES" "$ref")
total=$(echo "$output" | grep '^__TOTAL__:' | cut -d: -f2)
echo "$output" | grep -v '^__TOTAL__:'

log_run "diff" "${total:-0}" "ref:$ref new:$new_count mod:$mod_count"
if $_STRICT && [[ "${total:-0}" -gt 0 ]]; then
  exit 1
fi
}

cmd_branch() {
parse_scope_flags "main" "$@"

# Auto-fetch remote base and use remote ref for merge-base (not stale local)
_REMOTE_BASE=""
if ! $_UPSTREAM; then
  local auto_remote
  auto_remote=$(cd "$PROJECT_PATH" && git remote | head -1 2>/dev/null || echo "")
  if [[ -n "$auto_remote" ]]; then
    (cd "$PROJECT_PATH" && git fetch "$auto_remote" "$_BASE" --quiet 2>/dev/null) || true
    # Prefer remote ref over local — local main may be weeks behind
    if cd "$PROJECT_PATH" && git rev-parse --verify "$auto_remote/$_BASE" >/dev/null 2>&1; then
      _REMOTE_BASE="$auto_remote/$_BASE"
      local local_sha remote_sha
      local_sha=$(cd "$PROJECT_PATH" && git rev-parse "$_BASE" 2>/dev/null || echo "")
      remote_sha=$(cd "$PROJECT_PATH" && git rev-parse "$_REMOTE_BASE" 2>/dev/null || echo "")
      if [[ -n "$local_sha" && -n "$remote_sha" && "$local_sha" != "$remote_sha" ]]; then
        local behind
        behind=$(cd "$PROJECT_PATH" && git rev-list --count "$_BASE..$_REMOTE_BASE" 2>/dev/null || echo "?")
        echo "Using $_REMOTE_BASE (local $_BASE is $behind commits behind)" >&2
      fi
    fi
  fi
fi

# Use remote ref for merge-base if available, otherwise local
local effective_base="${_REMOTE_BASE:-$_BASE}"
resolve_scope_ref "$effective_base"
ref="$_RESOLVED_REF"

get_changed_files "$ref"
all_files=$(echo -e "${_NEW_FILES}\n${_MOD_FILES}" | grep -v '^$' | sort -u || true)
if [[ -z "$all_files" ]]; then
  echo "No changed .vue/.ts files vs $_BASE"
  exit 0
fi

# Cross-check diff-based vs date-based scope
cross_check_scope "$ref" "$_BASE"

# Merge date-only files into the scan (union of both methods)
if [[ -n "$_CROSS_DATE_ONLY" ]]; then
  date_extra_new=$(cd "$PROJECT_PATH" && echo "$_CROSS_DATE_ONLY" | while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if ! cd "$PROJECT_PATH" && git cat-file -e "${ref}:${f}" 2>/dev/null; then echo "$f"; fi
  done)
  date_extra_mod=$(cd "$PROJECT_PATH" && echo "$_CROSS_DATE_ONLY" | while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if cd "$PROJECT_PATH" && git cat-file -e "${ref}:${f}" 2>/dev/null; then echo "$f"; fi
  done)
  if [[ -n "$date_extra_new" ]]; then
    _NEW_FILES=$(echo -e "${_NEW_FILES}\n${date_extra_new}" | grep -v '^$' | sort -u || true)
  fi
  if [[ -n "$date_extra_mod" ]]; then
    _MOD_FILES=$(echo -e "${_MOD_FILES}\n${date_extra_mod}" | grep -v '^$' | sort -u || true)
  fi
  all_files=$(echo -e "${_NEW_FILES}\n${_MOD_FILES}" | grep -v '^$' | sort -u || true)
fi

# Also get deleted files (need to know what to remove from PR repo)
del_list=$(cd "$PROJECT_PATH" && git diff --name-only --diff-filter=D "$ref" -- '*.vue' '*.ts' 2>/dev/null || true)

# --list-files: just print file manifest and exit
if $_LIST_FILES; then
  if [[ -n "$_NEW_FILES" ]]; then
    echo "# New files (copy these):"
    echo "$_NEW_FILES"
  fi
  if [[ -n "$_MOD_FILES" ]]; then
    echo "# Modified files (copy these):"
    echo "$_MOD_FILES"
  fi
  if [[ -n "$del_list" ]]; then
    echo "# Deleted files (remove these from target):"
    echo "$del_list"
  fi
  exit 0
fi

# --copy-to: copy changed files to target repo, delete removed files
if [[ -n "$_COPY_TO" ]]; then
  if [[ ! -d "$_COPY_TO" ]]; then
    echo "Error: target directory does not exist: $_COPY_TO"
    exit 1
  fi
  copied=0
  deleted=0
  # Copy new + modified files
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if [[ -f "$PROJECT_PATH/$f" ]]; then
      mkdir -p "$_COPY_TO/$(dirname "$f")"
      cp "$PROJECT_PATH/$f" "$_COPY_TO/$f"
      copied=$((copied + 1))
    fi
  done <<< "$all_files"
  # Delete removed files from target
  if [[ -n "$del_list" ]]; then
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      if [[ -f "$_COPY_TO/$f" ]]; then
        rm "$_COPY_TO/$f"
        deleted=$((deleted + 1))
      fi
    done <<< "$del_list"
  fi
  echo "Copied $copied files to $_COPY_TO"
  if [[ $deleted -gt 0 ]]; then
    echo "Deleted $deleted files from $_COPY_TO"
  fi
  # Verify: diff the copied files against source
  mismatches=0
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if [[ -f "$PROJECT_PATH/$f" && -f "$_COPY_TO/$f" ]]; then
      if ! diff -q "$PROJECT_PATH/$f" "$_COPY_TO/$f" >/dev/null 2>&1; then
        echo "  MISMATCH: $f"
        mismatches=$((mismatches + 1))
      fi
    elif [[ -f "$PROJECT_PATH/$f" ]]; then
      echo "  MISSING in target: $f"
      mismatches=$((mismatches + 1))
    fi
  done <<< "$all_files"
  if [[ $mismatches -eq 0 ]]; then
    echo "Verified: all files match."
  else
    echo "WARNING: $mismatches file(s) did not match!"
    exit 1
  fi
  exit 0
fi

current_branch=$(cd "$PROJECT_PATH" && git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
new_count=$(count_lines "$_NEW_FILES")
mod_count=$(count_lines "$_MOD_FILES")

# Git stats for branch summary
stat_line=$(cd "$PROJECT_PATH" && git diff --shortstat "$ref" -- '*.vue' '*.ts' 2>/dev/null || true)
total_files=$(echo -e "${_NEW_FILES}\n${_MOD_FILES}" | grep -v '^$' | wc -l | tr -d ' ')

# Count test files in branch
test_new=$(echo "$_NEW_FILES" | grep -c '\.test\.\|\.spec\.\|__tests__' || echo 0)
test_mod=$(echo "$_MOD_FILES" | grep -c '\.test\.\|\.spec\.\|__tests__' || echo 0)
src_new=$((new_count - test_new))
del_files=$(count_lines "$del_list")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Branch: $current_branch vs $_BASE (merge-base: ${ref:0:8})"
if [[ -n "${_SINCE:-}" ]]; then
  echo "Scope: commits since $_SINCE"
elif [[ -n "${_COMMITS:-}" ]]; then
  echo "Scope: last $_COMMITS commits"
fi
if $_UPSTREAM; then
  echo "Compared against: upstream/$_BASE"
fi
echo "Files: $new_count new, $mod_count modified, $del_files deleted ($total_files total changed)"
if [[ -n "$stat_line" ]]; then
  echo "Stats:$stat_line"
fi
echo "Tests: $test_new new test files, $test_mod modified test files"
if [[ "$src_new" -gt 0 && "$test_new" -eq 0 ]]; then
  echo "  Warning: $src_new new source files with no new test files"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

issues_json=$(run_detectors_on_files "$all_files")
output=$(classify_and_report_issues "$issues_json" "$_NEW_FILES" "$_MOD_FILES" "$ref")
total=$(echo "$output" | grep '^__TOTAL__:' | cut -d: -f2)
echo "$output" | grep -v '^__TOTAL__:'

log_run "branch" "${total:-0}" "base:$_BASE new:$new_count mod:$mod_count"
if $_STRICT && [[ "${total:-0}" -gt 0 ]]; then
  exit 1
fi
}

cmd_lint_review() {
parse_scope_flags "main" "$@"
resolve_scope_ref "$_BASE"
ref="$_RESOLVED_REF"

get_changed_files "$ref"
all_files=$(echo -e "${_NEW_FILES}\n${_MOD_FILES}" | grep -v '^$' | sort -u || true)

new_count=$(count_lines "$_NEW_FILES")
mod_count=$(count_lines "$_MOD_FILES")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Deterministic Code Review (lint-review)"
echo "Scope: ${new_count} new files, ${mod_count} modified files vs ${_BASE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -z "$all_files" ]]; then
  echo "No changed .vue/.ts files — nothing to review."
  log_run "lint-review" "0" "base:$_BASE no_changes"
  exit 0
fi

issues_json=$(run_detectors_on_files "$all_files")

if [[ -z "$issues_json" || "$issues_json" == "[]" ]]; then
  echo "All clean — no convention violations in changed files."
  echo ""
  echo "### Branch Health Delta"
  echo "  New files: $new_count (issues: 0)"
  echo "  Modified files: $mod_count (branch-introduced: 0)"
  echo "  Net: CLEAN"
  log_run "lint-review" "0" "base:$_BASE clean"
  exit 0
fi

output=$(classify_and_report_issues "$issues_json" "$_NEW_FILES" "$_MOD_FILES" "$ref")
total=$(echo "$output" | grep '^__TOTAL__:' | cut -d: -f2)
echo "$output" | grep -v '^__TOTAL__:'

log_run "lint-review" "${total:-0}" "base:$_BASE"
}
