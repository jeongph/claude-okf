#!/usr/bin/env bash
set -euo pipefail
DIR="${1:-docs/okf}"
[ -d "$DIR" ] || { echo "no dir: $DIR"; exit 0; }
fail=0
while IFS= read -r -d '' f; do
  head -1 "$f" | grep -q '^---' || { echo "WARN $f: frontmatter 없음"; fail=1; continue; }
  awk '/^---/{n++; next} n==1 && /^type:/{found=1} END{exit !found}' "$f" \
    || { echo "WARN $f: type 누락"; fail=1; }
  # 상대 링크 대상 존재 확인
  while read -r t; do
    [ -f "$(dirname "$f")/$t" ] || { echo "WARN $f: 깨진 링크 $t"; fail=1; }
  done < <(grep -oE '\]\(\./[A-Za-z0-9_-]+\.md\)' "$f" 2>/dev/null | sed -E 's/\]\(\.\/(.*)\)/\1/')
done < <(find "$DIR" -name '*.md' -print0)
[ "$fail" -eq 0 ] && echo "OKF validate: OK" || echo "OKF validate: 경고 있음"
exit "$fail"
