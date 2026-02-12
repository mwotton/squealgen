#!/usr/bin/env bash
set -euo pipefail

threshold="${COVERAGE_THRESHOLD:-100}"
report_dir="${COVERAGE_REPORT_DIR:-coverage}"
allowlist_file="${COVERAGE_ALLOWLIST_FILE:-coverage-allowlist.txt}"
zero_denominator_policy="${COVERAGE_ZERO_DENOMINATOR_POLICY:-allow}"

case "$zero_denominator_policy" in
  allow|fail) ;;
  *)
    echo "ERROR: invalid COVERAGE_ZERO_DENOMINATOR_POLICY '$zero_denominator_policy' (expected allow or fail)" >&2
    exit 1
    ;;
esac

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

threshold="$(trim "$threshold")"
if [[ ! "$threshold" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "ERROR: invalid COVERAGE_THRESHOLD '$threshold' (expected numeric value, e.g. 95 or 95.5)" >&2
  exit 1
fi

# Coverage artifacts are run-specific; stale .tix files can cause hash mismatches.
rm -rf "$report_dir"
mkdir -p "$report_dir"

cabal build --enable-coverage test:tests
test_bin="$(cabal list-bin test:tests)"
latest_tix="$report_dir/tests.tix"
test_run_log="$(mktemp "$report_dir/test-run.XXXXXX.log")"
if ! HPCTIXFILE="$latest_tix" "$test_bin" >"$test_run_log" 2>&1; then
  cat "$test_run_log" >&2
  if grep -Fq "module mismatch with .tix/.mix file hash number" "$test_run_log"; then
    echo "ERROR: coverage hash mismatch detected while running tests; stale HPC data is likely present. Re-running with a clean coverage directory is required." >&2
  fi
  exit 1
fi
rm -f "$test_run_log"

mapfile -t modules < <(find src -type f -name '*.hs' -print | sed -E 's#^src/##; s#\.hs$##; s#/#.#g' | sort -u)
if [[ "${#modules[@]}" -eq 0 ]]; then
  echo "ERROR: no source modules found under src/" >&2
  exit 1
fi

declare -A module_exclusions=()
line_exclusions_file="$(mktemp "$report_dir/line-exclusions.XXXXXX.tsv")"
line_exclusion_selectors_file="$(mktemp "$report_dir/line-exclusion-selectors.XXXXXX.txt")"
cleanup_line_exclusion_files() {
  rm -f "$line_exclusions_file" "$line_exclusion_selectors_file"
}
trap cleanup_line_exclusion_files EXIT

allowlist_entries=0
line_exclusion_entries=0
if [[ -f "$allowlist_file" ]]; then
  module_pattern="[A-Za-z][A-Za-z0-9_']*(\\.[A-Za-z][A-Za-z0-9_']*)*"
  line_number=0
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line_number=$((line_number + 1))
    line="$(trim "$raw_line")"
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    if [[ "$line" != *"|"* ]]; then
      echo "ERROR: invalid allowlist entry at $allowlist_file:$line_number (expected Selector|Rationale)" >&2
      exit 1
    fi

    selector="$(trim "${line%%|*}")"
    rationale="$(trim "${line#*|}")"
    if [[ -z "$selector" ]]; then
      echo "ERROR: invalid allowlist entry at $allowlist_file:$line_number (empty selector)" >&2
      exit 1
    fi
    if [[ -z "$rationale" ]]; then
      echo "ERROR: allowlist entry for '$selector' is missing rationale" >&2
      exit 1
    fi
    allowlist_entries=$((allowlist_entries + 1))

    if [[ "$selector" == *":"* ]]; then
      module="${selector%%:*}"
      line_selector="${selector#*:}"
      if [[ ! "$module" =~ ^$module_pattern$ ]]; then
        echo "ERROR: invalid allowlist selector '$selector' (invalid module name)" >&2
        exit 1
      fi
      if [[ "$line_selector" == *"-"* ]]; then
        start_line="${line_selector%-*}"
        end_line="${line_selector#*-}"
        if [[ ! "$start_line" =~ ^[0-9]+$ || ! "$end_line" =~ ^[0-9]+$ ]]; then
          echo "ERROR: invalid allowlist selector '$selector' (line range must be numeric)" >&2
          exit 1
        fi
        if (( end_line < start_line )); then
          echo "ERROR: invalid allowlist selector '$selector' (range end before start)" >&2
          exit 1
        fi
      else
        if [[ ! "$line_selector" =~ ^[0-9]+$ ]]; then
          echo "ERROR: invalid allowlist selector '$selector' (line selector must be numeric)" >&2
          exit 1
        fi
        start_line="$line_selector"
        end_line="$line_selector"
      fi
      printf '%s\t%s\t%s\t%s\n' "$module" "$start_line" "$end_line" "$rationale" >> "$line_exclusions_file"
      printf '%s:%s-%s|%s\n' "$module" "$start_line" "$end_line" "$rationale" >> "$line_exclusion_selectors_file"
      line_exclusion_entries=$((line_exclusion_entries + 1))
      continue
    fi

    if [[ "$selector" =~ ^$module_pattern$ ]]; then
      module_exclusions["$selector"]="$rationale"
      continue
    fi

    echo "ERROR: invalid allowlist selector '$selector' (expected Module.Name, Module.Name:line, or Module.Name:start-end)" >&2
    exit 1
  done < "$allowlist_file"
fi

included_modules=()
for mod in "${modules[@]}"; do
  if [[ -z "${module_exclusions[$mod]+x}" ]]; then
    included_modules+=("$mod")
  fi
done

if [[ "${#included_modules[@]}" -eq 0 ]]; then
  echo "ERROR: coverage scope is empty after exclusions" >&2
  exit 1
fi

mapfile -t hpcdirs < <(find dist-newstyle -type d -name mix -path '*/hpc/*' -print | sort -u)
if [[ "${#hpcdirs[@]}" -eq 0 ]]; then
  echo "ERROR: no HPC mix directories found" >&2
  exit 1
fi

combined_hpcdir="$report_dir/mix"
rm -rf "$combined_hpcdir"
mkdir -p "$combined_hpcdir"
for dir in "${hpcdirs[@]}"; do
  while IFS= read -r pkg_dir; do
    pkg_name="$(basename "$pkg_dir")"
    dest="$combined_hpcdir/$pkg_name"
    ln -sfn "$pkg_dir" "$dest"
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -print)
done

hpc_report_log="$(mktemp "$report_dir/hpc-report.XXXXXX.log")"
if ! hpc report "$latest_tix" --hpcdir "$combined_hpcdir" "${included_modules[@]}" >"$hpc_report_log" 2>&1; then
  cat "$hpc_report_log" >&2
  if grep -Fq "module mismatch with .tix/.mix file hash number" "$hpc_report_log"; then
    echo "ERROR: coverage hash mismatch detected while reporting; .tix and .mix inputs are inconsistent." >&2
  fi
  exit 1
fi
report_output="$(cat "$hpc_report_log")"
rm -f "$hpc_report_log"
printf '%s\n' "$report_output" | tee "$report_dir/hpc-report.txt"

coverage_percent="$(printf '%s\n' "$report_output" | sed -n -E 's/^[[:space:]]*([0-9]+(\.[0-9]+)?)% expressions used.*/\1/p' | head -n 1)"
coverage_line="$(printf '%s\n' "$report_output" | sed -n -E 's/^[[:space:]]*([0-9]+(\.[0-9]+)?)% expressions used[[:space:]]*\(([0-9]+)\/([0-9]+)\).*/\1 \3 \4/p' | head -n 1)"
if [[ -z "$coverage_line" ]]; then
  echo "ERROR: unable to parse expression coverage percentage and counts (used/total)" >&2
  exit 1
fi
read -r coverage_percent expressions_used expressions_total <<< "$coverage_line"
zero_denominator_triggered=false
zero_denominator_outcome="not-triggered"
coverage_gate_result="pass"
failure_message=""

line_exclusions_applied=0
line_exclusions_covered=0
if (( line_exclusion_entries > 0 )); then
  hpc_show_log="$(mktemp "$report_dir/hpc-show.XXXXXX.log")"
  if ! hpc show "$latest_tix" --hpcdir "$combined_hpcdir" "${included_modules[@]}" >"$hpc_show_log" 2>&1; then
    cat "$hpc_show_log" >&2
    if grep -Fq "module mismatch with .tix/.mix file hash number" "$hpc_show_log"; then
      echo "ERROR: coverage hash mismatch detected while collecting line-level exclusions; .tix and .mix inputs are inconsistent." >&2
    fi
    exit 1
  fi

  read -r line_exclusions_applied line_exclusions_covered expressions_used expressions_total <<<"$(awk -v ex_file="$line_exclusions_file" '
    BEGIN {
      FS = "[[:space:]]+"
      while ((getline ex_line < ex_file) > 0) {
        split(ex_line, parts, "\t")
        module = parts[1]
        idx = ++range_count[module]
        range_start[module, idx] = parts[2] + 0
        range_end[module, idx] = parts[3] + 0
      }
    }
    {
      if (NF < 5) next
      if ($5 != "ExpBox") next
      tick_count = $2 + 0
      split($3, module_parts, ":")
      module = module_parts[length(module_parts)]
      split($4, loc_parts, ":")
      line_no = loc_parts[1] + 0
      total_expr++
      if (tick_count > 0) covered_expr++

      excluded = 0
      for (i = 1; i <= range_count[module]; i++) {
        if (line_no >= range_start[module, i] && line_no <= range_end[module, i]) {
          excluded = 1
          break
        }
      }
      if (excluded) {
        excluded_expr++
        if (tick_count > 0) excluded_covered_expr++
      }
    }
    END {
      adjusted_used = covered_expr - excluded_covered_expr
      adjusted_total = total_expr - excluded_expr
      if (adjusted_used < 0) adjusted_used = 0
      if (adjusted_total < 0) adjusted_total = 0
      printf "%d %d %d %d\n", excluded_expr, excluded_covered_expr, adjusted_used, adjusted_total
    }
  ' "$hpc_show_log")"
  rm -f "$hpc_show_log"

  if [[ "$expressions_total" -gt 0 ]]; then
    coverage_percent="$(awk -v u="$expressions_used" -v t="$expressions_total" 'BEGIN { p=(u*100)/t; if (p == int(p)) printf "%d", p; else printf "%.2f", p }')"
  fi
  echo "Applied line-level exclusions: ${line_exclusions_applied} expressions removed (${line_exclusions_covered} covered)"
fi

if [[ "$expressions_total" -eq 0 ]]; then
  zero_denominator_triggered=true
  case "$zero_denominator_policy" in
    allow)
      zero_denominator_outcome="not-applicable"
      coverage_gate_result="not-applicable"
      coverage_percent="NA"
      echo "Coverage gate not-applicable: expression denominator is zero (${expressions_used}/${expressions_total})"
      ;;
    fail)
      zero_denominator_outcome="fail"
      coverage_gate_result="fail"
      coverage_percent="NA"
      failure_message="ERROR: expression coverage denominator is zero (${expressions_used}/${expressions_total}) and policy is fail"
      ;;
  esac
else
  echo "Parsed expression coverage: ${coverage_percent}% (${expressions_used}/${expressions_total})"
  if ! awk -v c="$coverage_percent" -v t="$threshold" 'BEGIN { exit ((c + 0) >= (t + 0) ? 0 : 1) }'; then
    coverage_gate_result="fail"
    failure_message="ERROR: expression coverage ${coverage_percent}% (${expressions_used}/${expressions_total}) is below threshold ${threshold}%"
  fi
fi

{
  module_exclusions_summary="none"
  if [[ "${#module_exclusions[@]}" -gt 0 ]]; then
    mapfile -t excluded_module_names < <(printf '%s\n' "${!module_exclusions[@]}" | sort -u)
    module_exclusions_summary="$(printf '%s\n' "${excluded_module_names[@]}" | paste -sd ',' -)"
  fi
  line_exclusions_summary="none"
  if (( line_exclusion_entries > 0 )); then
    line_exclusions_summary="$(sort "$line_exclusion_selectors_file" | paste -sd ';' -)"
  fi
  echo "scope=src/**/*.hs"
  echo "excluded_generated_modules=true"
  echo "allowlist_file=$allowlist_file"
  echo "allowlist_entries=$allowlist_entries"
  echo "module_exclusions=$module_exclusions_summary"
  echo "line_exclusions=$line_exclusions_summary"
  echo "line_exclusions_applied=$line_exclusions_applied"
  echo "threshold_percent=$threshold"
  echo "expressions_percent=$coverage_percent"
  echo "expressions_used=$expressions_used"
  echo "expressions_total=$expressions_total"
  echo "zero_denominator_policy=$zero_denominator_policy"
  echo "zero_denominator_triggered=$zero_denominator_triggered"
  echo "zero_denominator_outcome=$zero_denominator_outcome"
  echo "coverage_gate_result=$coverage_gate_result"
  echo "tix=$latest_tix"
  echo "included_modules=${included_modules[*]}"
} > "$report_dir/summary.txt"

if [[ -n "$failure_message" ]]; then
  echo "$failure_message" >&2
  exit 1
fi

if [[ "$coverage_gate_result" == "pass" ]]; then
  echo "Coverage gate passed: ${coverage_percent}% (${expressions_used}/${expressions_total}) >= ${threshold}%"
fi
