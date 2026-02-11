#!/usr/bin/env bash
set -euo pipefail

threshold="${COVERAGE_THRESHOLD:-100}"
report_dir="${COVERAGE_REPORT_DIR:-coverage}"
allowlist_file="${COVERAGE_ALLOWLIST_FILE:-coverage-allowlist.txt}"

mkdir -p "$report_dir"

cabal build --enable-coverage test:tests
test_bin="$(cabal list-bin test:tests)"
latest_tix="$report_dir/tests.tix"
HPCTIXFILE="$latest_tix" "$test_bin"

mapfile -t modules < <(find src -type f -name '*.hs' -print | sed -E 's#^src/##; s#\.hs$##; s#/#.#g' | sort -u)
if [[ "${#modules[@]}" -eq 0 ]]; then
  echo "ERROR: no source modules found under src/" >&2
  exit 1
fi

exclude_module() {
  local mod="$1"
  local excluded="$2"
  [[ "$mod" == "$excluded" ]]
}

included_modules=()
for mod in "${modules[@]}"; do
  skip=0
  if [[ -f "$allowlist_file" ]]; then
    while IFS='|' read -r excluded rationale; do
      [[ -z "${excluded// }" ]] && continue
      [[ "$excluded" =~ ^# ]] && continue
      if exclude_module "$mod" "$excluded"; then
        if [[ -z "${rationale// }" ]]; then
          echo "ERROR: allowlist entry for '$excluded' is missing rationale" >&2
          exit 1
        fi
        skip=1
        break
      fi
    done < "$allowlist_file"
  fi
  if [[ "$skip" -eq 0 ]]; then
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

report_output="$(hpc report "$latest_tix" --hpcdir "$combined_hpcdir" "${included_modules[@]}")"
printf '%s\n' "$report_output" | tee "$report_dir/hpc-report.txt"

coverage_percent="$(printf '%s\n' "$report_output" | sed -n -E 's/^[[:space:]]*([0-9]+(\.[0-9]+)?)% expressions used.*/\1/p' | head -n 1)"
if [[ -z "$coverage_percent" ]]; then
  echo "ERROR: unable to parse expression coverage percentage" >&2
  exit 1
fi

{
  echo "scope=src/**/*.hs"
  echo "excluded_generated_modules=true"
  echo "threshold_percent=$threshold"
  echo "expressions_percent=$coverage_percent"
  echo "tix=$latest_tix"
  echo "included_modules=${included_modules[*]}"
} > "$report_dir/summary.txt"

if ! awk -v c="$coverage_percent" -v t="$threshold" 'BEGIN { exit ((c + 0) >= (t + 0) ? 0 : 1) }'; then
  echo "ERROR: expression coverage ${coverage_percent}% is below threshold ${threshold}%" >&2
  exit 1
fi

echo "Coverage gate passed: ${coverage_percent}% >= ${threshold}%"
