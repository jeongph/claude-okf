#!/usr/bin/env bash
set -euo pipefail
DIR="${1:-docs/okf}"
[ -d "$DIR" ] || exit 0
OUT="$DIR/index.md"
{
  echo "---"; echo "type: Index"; echo "title: OKF 노드 지도"; echo "---"; echo
  echo "# OKF 노드 지도"; echo
  echo "| 노드 | type | 요약 |"; echo "|---|---|---|"
  for f in "$DIR"/*.md; do
    [ "$(basename "$f")" = "index.md" ] && continue
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    type=$(awk '/^type:/{print $2; exit}' "$f")
    desc=$(awk -F': ' '/^description:/{print $2; exit}' "$f")
    echo "| [$name](./$name.md) | ${type:--} | ${desc:--} |"
  done
} > "$OUT"
echo "index 갱신: $OUT"
