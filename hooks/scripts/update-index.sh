#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-resolve-dir.sh"
DIR=$(resolve_okf_dir "${1:-}")
[ -z "$DIR" ] && exit 0
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
    type=$(awk '/^---/{n++; next} n==1 && /^type:/{print $2; exit}' "$f")
    desc=$(awk '/^---/{n++; next} n==1 && /^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$f")
    echo "| [$name](./$name.md) | ${type:--} | ${desc:--} |"
  done
} > "$OUT"
echo "index 갱신: $OUT"
