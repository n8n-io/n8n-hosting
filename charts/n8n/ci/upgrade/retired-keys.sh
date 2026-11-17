#!/usr/bin/env bash
# Prints, one per line, the retired keys that the given values files set.
#
#   retired-keys.sh <chart-dir> <values-file>...
#
# The list is n8n.retiredKeys in the chart's helpers, and a key counts as set
# the way n8n.validate counts it: its path is present, whatever its value.
# Helm reads the list and merges the files, through a scratch chart that
# holds only the chart's helpers, so this cannot parse either differently
# from the chart. The retiredKeysTest entries are unit test fixtures and are
# left out. A chart with no list prints nothing.
set -euo pipefail

[[ $# -ge 2 ]] || { echo "usage: $0 <chart-dir> <values-file>..." >&2; exit 2; }
chart=$1
shift

if ! grep -qs 'define "n8n.retiredKeys"' "$chart"/templates/_*.tpl; then
  exit 0
fi

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir "$scratch/templates"
cp "$chart"/templates/_*.tpl "$scratch/templates/"
printf 'apiVersion: v2\nname: retired-keys\nversion: 0.0.0\n' > "$scratch/Chart.yaml"
cat > "$scratch/templates/set.yaml" <<'EOF'
{{- range $retired := include "n8n.retiredKeys" . | fromYamlArray }}
{{- if not (hasPrefix "retiredKeysTest." $retired.path) }}
{{- $node := $.Values }}
{{- $set := true }}
{{- range $part := splitList "." $retired.path }}
{{- if and $set (kindIs "map" $node) (hasKey $node $part) }}
{{- $node = index $node $part }}
{{- else }}
{{- $set = false }}
{{- end }}
{{- end }}
{{- if $set }}
# retired-key: {{ $retired.path }}
{{- end }}
{{- end }}
{{- end }}
EOF

values=()
for f in "$@"; do
  values+=(-f "$f")
done

rendered=$(helm template retired-keys "$scratch" "${values[@]}")
sed -n 's/^# retired-key: //p' <<< "$rendered"
