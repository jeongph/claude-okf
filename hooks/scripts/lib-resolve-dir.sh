#!/usr/bin/env bash
# OKF 노드 디렉토리를 결정한다.
#  1) 인자로 경로가 주어지면 그대로 사용한다.
#  2) 없으면 PostToolUse hook이 stdin으로 넘긴 JSON에서 file_path를 읽고,
#     그 파일의 상위 디렉토리를 따라 올라가며 docs/knowledge(우선) 또는 docs/okf를 찾는다.
# 찾지 못하면 빈 문자열을 반환한다(호출 측에서 무동작 처리).
resolve_okf_dir() {
  local dir="${1:-}"
  if [ -n "$dir" ]; then
    printf '%s' "$dir"
    return 0
  fi

  local payload file d p
  payload=$(cat 2>/dev/null || true)
  file=$(printf '%s' "$payload" \
    | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' || true)
  [ -z "$file" ] && return 0

  d=$(dirname "$file")
  while [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -d "$d/docs/knowledge" ]; then printf '%s' "$d/docs/knowledge"; return 0; fi
    if [ -d "$d/docs/okf" ]; then printf '%s' "$d/docs/okf"; return 0; fi
    p=$(dirname "$d")
    [ "$p" = "$d" ] && break
    d="$p"
  done
  return 0
}
