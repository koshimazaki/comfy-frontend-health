#!/usr/bin/env bash
# comfy-health shared helpers -- scoped detection, git operations, classification
# Sourced by comfy-health main script. Requires: SCRIPT_DIR, PROJECT_PATH

# ── Shared helpers for scoped detection ─────────────────────────────────
# These functions are used by diff, branch, and lint-review to run detectors
# directly on changed files without requiring a full-repo scan.

# Get changed files classified as new (A) or modified (M) since a ref.
# Sets: _NEW_FILES, _MOD_FILES (newline-separated lists)
get_changed_files() {
  local ref="$1"
  _NEW_FILES=$(cd "$PROJECT_PATH" && git diff --name-only --diff-filter=A "$ref" -- '*.vue' '*.ts' 2>/dev/null || true)
  _MOD_FILES=$(cd "$PROJECT_PATH" && git diff --name-only --diff-filter=M "$ref" -- '*.vue' '*.ts' 2>/dev/null || true)
}

# Count non-empty lines in a string
count_lines() {
  local input="$1"
  if [[ -z "$input" ]]; then echo 0; else echo "$input" | grep -c -v '^$' || echo 0; fi
}

# Extract changed line numbers for a file vs a ref.
# Returns newline-separated line numbers.
extract_changed_lines() {
  local ref="$1" file="$2"
  cd "$PROJECT_PATH" && git diff -U0 "$ref" -- "$file" 2>/dev/null | \
    perl -ne 'print "$1\n" if /^@@.*\+(\d+(?:,\d+)?)/' | \
    while IFS=, read -r start count; do
      count=${count:-1}
      for ((i=start; i<start+count; i++)); do echo "$i"; done
    done
}

# Run all 6 Vue detectors on a set of files (copied to temp dir).
# Args: file list (newline-separated, relative to PROJECT_PATH)
# Outputs: JSON array of issue objects
run_detectors_on_files() {
  local file_list="$1"
  local tmpdir
  tmpdir=$(mktemp -d)

  # Copy files into temp dir preserving structure
  while IFS= read -r f; do
    if [[ -n "$f" && -f "$PROJECT_PATH/$f" ]]; then
      mkdir -p "$tmpdir/$(dirname "$f")"
      cp "$PROJECT_PATH/$f" "$tmpdir/$f"
    fi
  done <<< "$file_list"

  # Run all 6 detectors (pass SCRIPT_DIR via env var to avoid injection)
  local result
  result=$(cd "$tmpdir" && _DESLOP_ROOT="$SCRIPT_DIR/desloppify-fork" _PROJECT_ROOT="$PROJECT_PATH" python3 -c "
import sys, json, os
from pathlib import Path

sys.path.insert(0, os.environ['_DESLOP_ROOT'])
from desloppify.languages.typescript.detectors.vue import (
    detect_composition_api,
    detect_component_violations,
    detect_styling_violations,
    detect_layer_violations,
    detect_conventions,
    detect_reka_patterns,
)

path = Path('.')
all_issues = []
for detect_fn in [
    detect_composition_api,
    detect_component_violations,
    detect_styling_violations,
    detect_layer_violations,
    detect_conventions,
    detect_reka_patterns,
]:
    issues, _ = detect_fn(path)
    all_issues.extend(issues)

print(json.dumps(all_issues))
" 2>/dev/null || echo "[]")

  rm -rf "$tmpdir"
  echo "$result"
}

# Build changed-lines map for modified files (file -> set of line numbers).
# Args: $1=mod_files (newline-separated), $2=ref
# Outputs: JSON object { "file": [line, line, ...], ... } on stdout
build_changed_lines_json() {
  local mod_files="$1" ref="$2"
  local entries=()
  if [[ -n "$mod_files" ]]; then
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      local lines
      lines=$(extract_changed_lines "$ref" "$f" | paste -sd',' -)
      entries+=("$f"$'\t'"$lines")
    done <<< "$mod_files"
  fi
  # Use Python to safely build JSON (handles special chars in filenames)
  printf '%s\n' "${entries[@]+"${entries[@]}"}" | python3 -c "
import sys, json
result = {}
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split('\t', 1)
    fname = parts[0]
    lines_str = parts[1] if len(parts) > 1 else ''
    lines_list = [int(x) for x in lines_str.split(',') if x.strip()]
    result[fname] = lines_list
print(json.dumps(result))
" 2>/dev/null
}

# Classify issues as NEW FILE or CHANGED LINE, filter modified-file issues
# to only those on changed lines.
# Args: $1=issues_json, $2=new_files, $3=mod_files, $4=ref
# Outputs: formatted report to stdout; last line is __TOTAL__:N
classify_and_report_issues() {
  local issues_json="$1" new_files="$2" mod_files="$3" ref="$4"

  # Build changed-lines map for line-level filtering of modified files
  local changed_lines_json
  changed_lines_json=$(build_changed_lines_json "$mod_files" "$ref")

  # Pass data via env vars to avoid injection via triple-quoted strings
  _CH_ISSUES="$issues_json" \
  _CH_NEW="$new_files" \
  _CH_MOD="$mod_files" \
  _CH_LINES="$changed_lines_json" \
  python3 -c "
import json, sys, os
from collections import defaultdict

issues = json.loads(os.environ.get('_CH_ISSUES', '[]'))
new_files_str = os.environ.get('_CH_NEW', '').strip()
mod_files_str = os.environ.get('_CH_MOD', '').strip()
changed_lines_map = json.loads(os.environ.get('_CH_LINES', '{}'))

new_set = set(new_files_str.split('\n')) if new_files_str else set()
mod_set = set(mod_files_str.split('\n')) if mod_files_str else set()

def normalize(f):
    return f[2:] if f.startswith('./') else f

def match_file(f, file_set):
    if f in file_set:
        return f
    for sf in file_set:
        if f.endswith('/' + sf) or sf.endswith('/' + f):
            return sf
    return None

# Classify and filter issues
new_issues = []
mod_issues = []
skipped_preexisting = 0
for issue in issues:
    f = normalize(issue.get('file', ''))
    matched_new = match_file(f, new_set)
    matched_mod = match_file(f, mod_set)
    if matched_new:
        new_issues.append(issue)
    elif matched_mod:
        # Filter to changed lines only
        line_num = issue.get('line', 0)
        allowed_lines = set(changed_lines_map.get(matched_mod, []))
        if not allowed_lines or line_num in allowed_lines:
            mod_issues.append(issue)
        else:
            skipped_preexisting += 1

all_issues = new_issues + mod_issues
sev_order = {'critical': 0, 'warning': 1, 'info': 2}

def format_issue(issue, tag):
    sev = issue.get('severity', 'warning').upper()
    priority = 'Critical' if sev == 'CRITICAL' else 'Warning' if sev == 'WARNING' else 'Info'
    line = issue.get('line', 0)
    return f'  {priority} | {tag} | {issue.get(\"file\",\"?\")}:{line} -- {issue.get(\"summary\",\"?\")}'

# ── Pre-existing issues (filtered out) ──
if skipped_preexisting > 0:
    print(f'-- Pre-existing ({skipped_preexisting} issues filtered out, not branch-introduced) --')
    print(f'  {skipped_preexisting} issues in modified files are on unchanged lines (inherited debt)')
    print('')

# ── Table 1: Branch-introduced issues ──
total = 0
if new_issues:
    new_issues.sort(key=lambda x: sev_order.get(x.get('severity', 'info'), 3))
    print(f'-- New files ({len(new_issues)} issues, all branch-introduced) --')
    for issue in new_issues:
        print(format_issue(issue, 'NEW'))
    print('')
    total += len(new_issues)

if mod_issues:
    mod_issues.sort(key=lambda x: sev_order.get(x.get('severity', 'info'), 3))
    print(f'-- Modified files ({len(mod_issues)} issues on changed lines) --')
    for issue in mod_issues:
        print(format_issue(issue, 'CHANGED'))
    print('')
    total += len(mod_issues)

# ── Table 2: Grouped by detector/area with scores ──
if all_issues:
    by_detector = defaultdict(list)
    for issue in all_issues:
        det = issue.get('detector', 'unknown')
        by_detector[det].append(issue)

    print('-- Branch contributions by area --')
    area_scores = []
    for det, det_issues in sorted(by_detector.items()):
        crit = sum(1 for i in det_issues if i.get('severity') == 'critical')
        warn = sum(1 for i in det_issues if i.get('severity') == 'warning')
        info_c = sum(1 for i in det_issues if i.get('severity') == 'info')
        score = max(0, 100 - (crit * 15) - (warn * 5) - (info_c * 1))
        area_scores.append(score)
        files = len(set(normalize(i.get('file','')) for i in det_issues))
        print(f'  {det:30s}  {crit}C {warn}W {info_c}I  ({files} files)  Score: {score}/100')
    print('')

    overall = sum(area_scores) // len(area_scores) if area_scores else 100
else:
    overall = 100

if total == 0:
    print('All clean -- no convention violations in changed files.')

# ── Summary ──
critical = sum(1 for i in all_issues if i.get('severity') == 'critical')
warning = sum(1 for i in all_issues if i.get('severity') == 'warning')
info_count = sum(1 for i in all_issues if i.get('severity') == 'info')

print('')
print('=== Branch Health Summary ===')
print(f'  Issues: {total} ({len(new_issues)} in new files, {len(mod_issues)} on changed lines)')
if skipped_preexisting > 0:
    print(f'  Filtered: {skipped_preexisting} pre-existing issues excluded')
print(f'  Critical: {critical}, Warning: {warning}, Info: {info_count}')
verdict = 'WORSE' if critical > 0 else 'NEUTRAL' if warning > 0 else 'BETTER' if total == 0 else 'NEUTRAL'
print(f'  Verdict: {verdict}')
print(f'  Branch-Scoped Score: {overall}/100')

print(f'__TOTAL__:{total}')
" 2>/dev/null
}

# Resolve scope ref from flexible flags: --since=2d, --commits=N, explicit ref, or merge-base
# Args: base (default branch), plus flag vars: _SINCE, _COMMITS, _EXPLICIT_REF
# Sets: _RESOLVED_REF
resolve_scope_ref() {
  local base="$1"

  if [[ -n "${_SINCE:-}" ]]; then
    # Time-based: find the commit at that time boundary
    _RESOLVED_REF=$(cd "$PROJECT_PATH" && git log --since="$_SINCE" --format="%H" --reverse HEAD 2>/dev/null | head -1)
    if [[ -z "$_RESOLVED_REF" ]]; then
      echo "No commits found since $_SINCE"
      exit 0
    fi
    # Use parent of earliest commit in range
    _RESOLVED_REF=$(cd "$PROJECT_PATH" && git rev-parse "${_RESOLVED_REF}^" 2>/dev/null || echo "$_RESOLVED_REF")
  elif [[ -n "${_COMMITS:-}" ]]; then
    # Commit-count based
    _RESOLVED_REF="HEAD~${_COMMITS}"
  elif [[ -n "${_EXPLICIT_REF:-}" ]]; then
    _RESOLVED_REF="$_EXPLICIT_REF"
  else
    # Default: merge-base with the base branch
    # If --upstream, fetch upstream first and use upstream/BASE
    if $_UPSTREAM; then
      local upstream_remote
      upstream_remote=$(cd "$PROJECT_PATH" && git remote | grep -x 'upstream' 2>/dev/null || echo "")
      if [[ -n "$upstream_remote" ]]; then
        echo "Fetching upstream/$base..." >&2
        (cd "$PROJECT_PATH" && git fetch upstream "$base" --quiet 2>/dev/null) || true
        _RESOLVED_REF=$(cd "$PROJECT_PATH" && git merge-base "upstream/$base" HEAD 2>/dev/null || echo "upstream/$base")
      else
        # No upstream remote — fall back to origin
        echo "No 'upstream' remote found, using origin/$base..." >&2
        (cd "$PROJECT_PATH" && git fetch origin "$base" --quiet 2>/dev/null) || true
        _RESOLVED_REF=$(cd "$PROJECT_PATH" && git merge-base "origin/$base" HEAD 2>/dev/null || echo "origin/$base")
      fi
      # Warn if merge-base is old
      local mb_age
      mb_age=$(cd "$PROJECT_PATH" && git log -1 --format="%cr" "$_RESOLVED_REF" 2>/dev/null || echo "unknown")
      echo "Merge-base: ${_RESOLVED_REF:0:8} ($mb_age)" >&2
    else
      _RESOLVED_REF=$(cd "$PROJECT_PATH" && git merge-base "$base" HEAD 2>/dev/null || echo "$base")
    fi
  fi
}

# Cross-check: run both diff-based and date-based file discovery.
# Compares results and reports discrepancies.
# Args: $1=diff_ref (merge-base for diff), $2=branch_name
# Sets: _CROSS_DIFF_ONLY, _CROSS_DATE_ONLY, _CROSS_BOTH (newline-separated file lists)
cross_check_scope() {
  local diff_ref="$1" branch_name="$2"

  # Diff-based: files that differ structurally from ref
  local diff_files
  diff_files=$(cd "$PROJECT_PATH" && git diff --name-only "$diff_ref" -- '*.vue' '*.ts' 2>/dev/null | sort -u)

  # Date-based: get branch creation date (first commit not on base)
  local branch_start_date
  branch_start_date=$(cd "$PROJECT_PATH" && git log "$diff_ref..HEAD" --format="%aI" --reverse 2>/dev/null | head -1)
  local date_files=""
  if [[ -n "$branch_start_date" ]]; then
    # Files touched by commits since branch started
    date_files=$(cd "$PROJECT_PATH" && git log --since="$branch_start_date" --name-only --format="" HEAD -- '*.vue' '*.ts' 2>/dev/null | sort -u | grep -v '^$' || true)
  fi

  # Compare
  _CROSS_BOTH=""
  _CROSS_DIFF_ONLY=""
  _CROSS_DATE_ONLY=""

  if [[ -n "$diff_files" && -n "$date_files" ]]; then
    _CROSS_BOTH=$(comm -12 <(echo "$diff_files") <(echo "$date_files"))
    _CROSS_DIFF_ONLY=$(comm -23 <(echo "$diff_files") <(echo "$date_files"))
    _CROSS_DATE_ONLY=$(comm -13 <(echo "$diff_files") <(echo "$date_files"))
  elif [[ -n "$diff_files" ]]; then
    _CROSS_BOTH="$diff_files"
  elif [[ -n "$date_files" ]]; then
    _CROSS_DATE_ONLY="$date_files"
  fi

  # Report discrepancies
  local diff_only_count date_only_count
  diff_only_count=$(count_lines "$_CROSS_DIFF_ONLY")
  date_only_count=$(count_lines "$_CROSS_DATE_ONLY")

  if [[ "$diff_only_count" -gt 0 || "$date_only_count" -gt 0 ]]; then
    echo "" >&2
    echo "-- Scope cross-check (diff vs date-based) --" >&2
    if [[ "$diff_only_count" -gt 0 ]]; then
      echo "  $diff_only_count files in diff-only (rebased/cherry-picked?):" >&2
      echo "$_CROSS_DIFF_ONLY" | head -5 | sed 's/^/    /' >&2
      [[ "$diff_only_count" -gt 5 ]] && echo "    ... and $((diff_only_count - 5)) more" >&2
    fi
    if [[ "$date_only_count" -gt 0 ]]; then
      echo "  $date_only_count files in date-only (reverted/amended?):" >&2
      echo "$_CROSS_DATE_ONLY" | head -5 | sed 's/^/    /' >&2
      [[ "$date_only_count" -gt 5 ]] && echo "    ... and $((date_only_count - 5)) more" >&2
    fi
    echo "" >&2
  fi
}

# Parse common scope flags from args.
# Sets: _STRICT, _BASE, _SINCE, _COMMITS, _EXPLICIT_REF, _UPSTREAM, _LIST_FILES, _COPY_TO
parse_scope_flags() {
  local default_base="${1:-main}"
  _STRICT=false
  _BASE="$default_base"
  _SINCE=""
  _COMMITS=""
  _EXPLICIT_REF=""
  _UPSTREAM=false
  _LIST_FILES=false
  _COPY_TO=""

  shift || true
  for arg in "$@"; do
    case "$arg" in
      --strict) _STRICT=true ;;
      --since=*) _SINCE="${arg#--since=}" ;;
      --commits=*) _COMMITS="${arg#--commits=}" ;;
      --base=*) _BASE="${arg#--base=}" ;;
      --upstream) _UPSTREAM=true ;;
      --list-files) _LIST_FILES=true ;;
      --copy-to=*) _COPY_TO="${arg#--copy-to=}" ;;
      -*) ;; # ignore other flags
      *) _EXPLICIT_REF="$arg" ;;
    esac
  done
}
