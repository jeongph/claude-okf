---
description: 위키 health-check
allowed-tools: [Bash, Read, Grep, Glob]
---

# OKF Lint

`okf-lint` skill을 실행해 OKF 지식 노드의 정합성을 점검한다.

## 실행 흐름

`okf-lint` skill의 절차를 그대로 따른다. 아래 순서로 실행한다.

---

## 단계 1: 점검 범위 결정

점검 경로는 다음 순서로 정한다: ① 인자로 주어지면 그 경로 ② 없으면 `docs/knowledge/`(있으면) ③ 없으면 `docs/okf/`(하위호환) ④ 둘 다 없으면 `docs/knowledge/`.

```bash
find docs/knowledge -name "*.md" | sort
```

---

## 단계 2: 모순 (Contradiction) 점검

같은 `title` 또는 `resource` 값을 가진 노드를 찾아 충돌 여부를 확인한다.

```bash
grep -rh '^resource:' docs/knowledge/ | sort | uniq -d
grep -rh '^title:' docs/knowledge/ | sort | uniq -d
```

---

## 단계 3: Stale (오래된 노드) 점검

노드 `timestamp`와 `resource`의 마지막 git 변경 시각을 비교한다.

```bash
grep -rn '^timestamp:' docs/knowledge/
git log --follow -1 --format="%ci" -- <resource 경로>
```

---

## 단계 4: Orphan (고아 노드) 점검

어느 노드도 링크하지 않는 노드를 찾는다.

```bash
while IFS= read -r f; do
  name=$(basename "$f" .md)
  if [ "$name" = "index" ]; then continue; fi
  count=$(grep -rl "$name" docs/knowledge/ | grep -v "^$f$" | wc -l | tr -d ' ')
  if [ "$count" -eq 0 ]; then echo "ORPHAN: $f"; fi
done < <(find docs/knowledge -name "*.md" -not -name "index.md")
```

---

## 단계 5: 누락 cross-ref / 미작성 노드 점검

관계 섹션의 링크 대상 파일이 실제로 존재하는지 확인한다.

```bash
# (이 절차는 okf-lint skill과 동기화 대상)
grep -rh '\[.*\](\.\/.*\.md)' docs/knowledge/ \
  | grep -oE '\(\.\/[A-Za-z0-9_-]+\.md\)' \
  | sed -E 's/\(\.\/([^)]+)\)/\1/' | sort -u \
  | while read -r target; do
      [ -f "docs/knowledge/$target" ] || echo "MISSING: $target"
    done
```

---

## 단계 6: 결과 보고

4가지 점검 결과를 표로 합산해 보고한다. **자동 수정 금지** — 모든 수정은 사용자 확인 후 별도 작업으로 진행한다.

```
## OKF Lint 결과

점검 경로: docs/knowledge/
점검 시각: <ISO8601, KST>

### 모순 (N건)
### Stale (N건)
### Orphan (N건)
### 누락 cross-ref (N건)

이상 발견 없음: ✅ / 발견: ⚠️ N건
```
