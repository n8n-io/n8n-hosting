#!/usr/bin/env bash
# Tests for scripts/migrate-values.sh.
#
# Each cases/NAME.in.yaml is migrated and compared with NAME.out.yaml, the
# expected values, and NAME.report.txt, the expected report. Each output is
# migrated again to check that a second run changes nothing. So is every
# example in examples/, which is already written for this chart. Every key in
# n8n.retiredKeys must appear in the script.
#
# Usage: run.sh [-u]
#   -u  rewrite the expected files from the current output.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
chart="$(cd "$here/../.." && pwd)"
script="$chart/scripts/migrate-values.sh"
update=false
[[ "${1:-}" == "-u" ]] && update=true

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failed=0

fail() {
  echo "FAIL $*"
  failed=1
}

# Every retired key needs a transform. The retiredKeysTest entries are
# fixtures for the chart's own tests.
while read -r path; do
  [[ "$path" == retiredKeysTest.* ]] && continue
  grep -qF "$path" "$script" || fail "n8n.retiredKeys retires $path, but migrate-values.sh does not handle it"
done < <(sed -n '/define "n8n.retiredKeys"/,/end -/s/^- path: //p' "$chart/templates/_helpers.tpl")

for in in "$here"/cases/*.in.yaml; do
  name="$(basename "$in" .in.yaml)"
  out="$here/cases/$name.out.yaml"
  report="$here/cases/$name.report.txt"
  if ! "$script" "$in" > "$tmp/out.yaml" 2> "$tmp/report.txt"; then
    fail "$name: the script exited non-zero"
    cat "$tmp/report.txt"
    continue
  fi
  if [[ "$update" == true ]]; then
    cp "$tmp/out.yaml" "$out"
    cp "$tmp/report.txt" "$report"
  else
    diff -u "$out" "$tmp/out.yaml" || fail "$name: values differ from $name.out.yaml"
    diff -u "$report" "$tmp/report.txt" || fail "$name: report differs from $name.report.txt"
  fi
  "$script" "$tmp/out.yaml" > "$tmp/again.yaml" 2> "$tmp/again.txt"
  cmp -s "$tmp/out.yaml" "$tmp/again.yaml" || fail "$name: a second run changed the values"
  [[ "$(cat "$tmp/again.txt")" == "migrate-values: nothing to change." ]] || fail "$name: a second run reported: $(cat "$tmp/again.txt")"
done

for example in "$chart"/examples/*.yaml; do
  "$script" "$example" > "$tmp/out.yaml" 2> "$tmp/report.txt"
  cmp -s "$example" "$tmp/out.yaml" || fail "examples/$(basename "$example"): the script changed a values file written for this chart"
  [[ "$(cat "$tmp/report.txt")" == "migrate-values: nothing to change." ]] || fail "examples/$(basename "$example"): the script reported: $(cat "$tmp/report.txt")"
done

if [[ "$failed" == 0 ]]; then echo "All migrate-values tests passed."; fi
exit "$failed"
