#!/usr/bin/env bash
# validate.sh 회귀 테스트
#
# 목적: 링크 검사가 한글 파일명을 포함한 모든 상대 링크를 대상으로 삼는지
#   보장한다. ASCII만 매칭하는 패턴은 한글 노드의 깨진 링크를 놓친다.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/hooks/scripts/validate.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

ok()   { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
nope() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

printf 'validate.sh 회귀 테스트\n'

# --- 한글 파일명의 깨진 링크를 잡아낸다 ---
dir="$WORK/case1/docs/knowledge"
mkdir -p "$dir"
printf -- '---\ntype: Concept\n---\n\n# 노드\n\n[없는-노드](./없는-노드.md)\n' > "$dir/노드.md"

out=$(bash "$SCRIPT" "$dir" 2>&1)
case "$out" in
  *"깨진 링크"*) ok "한글 파일명 깨진 링크를 감지" ;;
  *)             nope "한글 파일명 깨진 링크를 놓침 (출력: $out)" ;;
esac

# --- 링크 대상이 실재하면 통과시킨다 ---
dir2="$WORK/case2/docs/knowledge"
mkdir -p "$dir2"
printf -- '---\ntype: Concept\n---\n\n# 노드\n\n[있는-노드](./있는-노드.md)\n' > "$dir2/노드.md"
printf -- '---\ntype: Concept\n---\n\n# 있는-노드\n' > "$dir2/있는-노드.md"

out2=$(bash "$SCRIPT" "$dir2" 2>&1)
case "$out2" in
  *"깨진 링크"*) nope "실재하는 한글 링크를 깨졌다고 오탐 (출력: $out2)" ;;
  *)             ok "실재하는 한글 링크는 통과" ;;
esac

printf '\n통과 %d · 실패 %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
