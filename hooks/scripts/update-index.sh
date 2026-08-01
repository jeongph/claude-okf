#!/usr/bin/env bash
set -euo pipefail
# glob 확장 정렬은 LC_COLLATE에 종속된다. 고정하지 않으면 같은 노드 집합이라도
# 머신·셸 로케일에 따라 index.md의 행 순서가 달라져, 노드를 건드리지 않은
# 커밋에까지 순서 diff가 딸려 들어간다. C 로케일은 어디에나 존재하고
# UTF-8 바이트 순서 = 코드포인트 순서라 한글도 가나다순으로 정렬된다.
export LC_ALL=C
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
