#!/usr/bin/env bash
# update-index.sh 회귀 테스트
#
# 목적: index.md 생성 결과가 실행 환경의 로케일에 좌우되지 않음을 보장한다.
#   glob 확장 정렬은 LC_COLLATE에 종속되므로, 로케일을 고정하지 않으면
#   같은 디렉토리에서도 머신마다 다른 순서의 index.md가 만들어진다.
#   그 결과 노드를 건드리지 않은 커밋에 순서 diff가 딸려 들어간다.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/hooks/scripts/update-index.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

ok()   { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
nope() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

# 정렬 차이를 드러내는 픽스처를 만든다.
#  - 한글 노드: 로케일별 한글 정렬 규칙 차이를 드러낸다
#  - ASCII 대/소문자 혼합: C(코드포인트)와 UTF-8 로케일(대소문자 무시)의 차이를 드러낸다
make_fixture() {
  local dir="$1"
  mkdir -p "$dir"
  local n
  for n in 릴리스-트랙과-호환성 모바일-스토어-배포-자동화 세션-자정-분할-집계 Alpha beta Gamma-node; do
    printf -- '---\ntype: Concept\ndescription: %s 설명\n---\n\n# %s\n' "$n" "$n" > "$dir/$n.md"
  done
}

# 시스템에 실재하는 로케일만 테스트 대상으로 삼는다.
# 없는 로케일은 경고 없이 C로 폴백하므로 테스트가 무의미해진다.
# (macOS 기본 bash 3.2에는 mapfile이 없어 공백 구분 문자열로 넘긴다)
available_locales() {
  local all cand found=""
  all=$(locale -a 2>/dev/null || true)
  for cand in C en_US.UTF-8 ko_KR.UTF-8 ja_JP.UTF-8 de_DE.UTF-8; do
    # grep -q 는 매치 즉시 종료해 상류에 SIGPIPE를 보낸다.
    # pipefail 하에서는 그 141이 파이프라인 결과가 되므로 -q 를 쓰지 않는다.
    if [ "$cand" = "C" ] || printf '%s\n' "$all" | grep -xF "$cand" >/dev/null; then
      found="$found $cand"
    fi
  done
  printf '%s' "${found# }"
}

# --- 테스트 1: 로케일이 달라도 index.md 내용이 동일하다 ---
test_locale_independent_output() {
  local dir="$WORK/case1/docs/knowledge"
  make_fixture "$dir"

  local baseline="" baseline_locale="" differing="" locales count
  locales=$(available_locales)
  count=$(printf '%s\n' $locales | grep -c .)

  if [ "$count" -lt 2 ]; then
    nope "로케일 독립성: 비교할 로케일이 2개 미만이라 검증 불가 (${locales:-없음})"
    return
  fi

  local loc out
  for loc in $locales; do
    LC_ALL="$loc" bash "$SCRIPT" "$dir" >/dev/null 2>&1
    out=$(cat "$dir/index.md")
    if [ -z "$baseline" ]; then
      baseline="$out"
      baseline_locale="$loc"
    elif [ "$out" != "$baseline" ]; then
      differing="$differing $loc"
    fi
  done
  differing="${differing# }"

  if [ -z "$differing" ]; then
    ok "로케일 독립성: ${count}개 로케일($locales)에서 index.md 동일"
  else
    local first
    first=$(printf '%s' "$differing" | cut -d' ' -f1)
    nope "로케일 독립성: ${baseline_locale} 대비 ${differing} 에서 index.md가 다름"
    printf '       --- %s vs %s ---\n' "$baseline_locale" "$first"
    LC_ALL="$first" bash "$SCRIPT" "$dir" >/dev/null 2>&1
    diff <(printf '%s\n' "$baseline") "$dir/index.md" | sed 's/^/       /'
  fi
}

# --- 테스트 2: 같은 로케일에서 반복 실행하면 결과가 멱등하다 ---
test_idempotent() {
  local dir="$WORK/case2/docs/knowledge"
  make_fixture "$dir"

  bash "$SCRIPT" "$dir" >/dev/null 2>&1
  local first
  first=$(cat "$dir/index.md")
  bash "$SCRIPT" "$dir" >/dev/null 2>&1

  if [ "$first" = "$(cat "$dir/index.md")" ]; then
    ok "멱등성: 반복 실행해도 index.md 동일"
  else
    nope "멱등성: 반복 실행 결과가 다름"
  fi
}

# --- 테스트 3: index.md 자신은 목록에 포함되지 않는다 ---
test_excludes_self() {
  local dir="$WORK/case3/docs/knowledge"
  make_fixture "$dir"

  bash "$SCRIPT" "$dir" >/dev/null 2>&1
  bash "$SCRIPT" "$dir" >/dev/null 2>&1

  if grep -q '\[index\](\./index\.md)' "$dir/index.md"; then
    nope "자기 제외: index.md가 자기 자신을 목록에 포함함"
  else
    ok "자기 제외: index.md가 목록에서 빠짐"
  fi
}

# --- 테스트 4: 노드의 type·description이 그대로 반영된다 (정렬 수정의 부작용 감시) ---
test_preserves_metadata() {
  local dir="$WORK/case4/docs/knowledge"
  make_fixture "$dir"

  bash "$SCRIPT" "$dir" >/dev/null 2>&1

  if grep -qF '| [릴리스-트랙과-호환성](./릴리스-트랙과-호환성.md) | Concept | 릴리스-트랙과-호환성 설명 |' "$dir/index.md"; then
    ok "메타데이터: 한글 노드의 type·description이 온전히 반영됨"
  else
    nope "메타데이터: 한글 노드 행이 기대와 다름"
    grep '릴리스' "$dir/index.md" | sed 's/^/       /'
  fi
}

printf 'update-index.sh 회귀 테스트\n'
test_locale_independent_output
test_idempotent
test_excludes_self
test_preserves_metadata

printf '\n통과 %d · 실패 %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
