---
name: okf-lint
description: Use after writing/updating OKF nodes, or when checking wiki health — finds contradictions, stale claims, orphan pages, missing cross-references. 사용자가 "위키 점검", "okf lint", "노드 정합성 확인", "오래된 노드 찾아"라고 하거나, AI가 노드를 여러 개 갱신한 뒤 스스로 정합성을 점검할 때 사용.
---

# OKF Lint

OKF 지식 노드의 정합성을 점검하는 위키 health-check 가이드다.

비유: 코드에 `eslint`가 있듯, OKF 위키엔 `okf-lint`가 있다. 노드가 서로 모순되거나, 원본과 동떨어지거나, 고립되거나, 언급만 되고 존재하지 않는 개념을 찾아낸다.

**원칙: 자동 수정 금지.** lint 결과는 표로 보고하고, 모든 수정은 사용자 확인 후 진행한다.

---

## 1. 점검 범위 결정

먼저 어느 경로를 점검할지 확인한다. 기본값은 현재 repo의 OKF 노드 디렉토리다.

```bash
# 기본: 현재 repo의 OKF 노드 전체
find docs/okf -name "*.md" | sort

# 워크스페이스 조망 노드도 함께 점검할 경우
find docs/projects -name "*.md" | sort
```

범위가 맞으면 아래 4가지 점검을 순서대로 수행한다.

---

## 2. 모순 (Contradiction)

**의미**: 같은 대상을 다루는 두 노드가 서로 충돌하는 주장을 담고 있는 경우.

**방법**: 같은 `title` 또는 같은 `resource` 값을 가진 노드를 찾고, 기술 내용을 비교한다.

```bash
# resource 중복 확인
grep -rh '^resource:' docs/okf/ | sort | uniq -d

# title 중복 확인
grep -rh '^title:' docs/okf/ | sort | uniq -d
```

중복이 발견되면 해당 파일들을 열어 주요 주장(요약·구성·상태)을 비교한다. 충돌 여부는 **사람이 판단**한다. AI는 후보를 제시하는 역할에 그친다.

**보고 형식**:

| 노드 A | 노드 B | 충돌 내용 | 판단 필요 |
|--------|--------|-----------|-----------|
| `a.md` | `b.md` | status 불일치: 운영 중 vs 보관 | ✅ |

---

## 3. Stale (오래된 노드)

**의미**: 노드의 `timestamp`가 오래됐는데, 해당 `resource`(원본 코드·문서)가 그 이후 변경된 경우. 노드가 현실을 반영하지 못하고 있을 가능성이 높다.

**방법**: 각 노드의 `timestamp`와 `resource`의 마지막 git 변경 시각을 비교한다.

```bash
# 노드별 timestamp 추출
grep -rn '^timestamp:' docs/okf/

# resource 경로의 마지막 git 변경 시각 확인 (resource 값을 확인 후 대입)
git log --follow -1 --format="%ci" -- <resource 경로>
```

`resource` 커밋 시각이 노드 `timestamp`보다 **최신**이면 stale 후보다.

**보고 형식**:

| 노드 | 노드 timestamp | resource 최종 변경 | Stale 여부 |
|------|----------------|-------------------|------------|
| `a.md` | 2026-05-01 | 2026-06-10 | ⚠️ |

---

## 4. Orphan (고아 노드)

**의미**: 어느 노드도 링크하지 않는 노드. `index.md` 또는 다른 노드의 `## 관계` 섹션에서 참조되지 않으면 탐색 경로가 없다.

**방법**: 각 노드 파일명을 기준으로 다른 파일에서 inbound 링크가 0개인 파일을 찾는다.

```bash
# 점검 대상 노드 목록
find docs/okf -name "*.md" -not -name "index.md" | sort

# 특정 노드(예: service-a.md)를 링크하는 파일이 있는지 확인
grep -rl "service-a" docs/okf/

# inbound 링크 0개인 파일 일괄 탐색 (-L: 매칭 없는 파일 반환)
for f in docs/okf/*.md; do
  name=$(basename "$f" .md)
  if [ "$name" = "index" ]; then continue; fi
  count=$(grep -rl "$name" docs/okf/ | grep -v "^$f$" | wc -l | tr -d ' ')
  if [ "$count" -eq 0 ]; then echo "ORPHAN: $f"; fi
done
```

`index.md`는 orphan 판단에서 제외한다 (목차 역할이므로 링크를 받지 않아도 정상).

**보고 형식**:

| 노드 | inbound 링크 수 | 판단 |
|------|-----------------|------|
| `a.md` | 0 | ⚠️ orphan 후보 |

---

## 5. 누락 cross-ref / 미작성 노드

**의미**: 노드 본문에서 자주 언급되는 개념·시스템인데, 자기 OKF 노드가 존재하지 않는 경우. 위키의 "빈 링크" 상태다.

**방법**: 관계 섹션의 마크다운 링크 대상 파일이 실제로 존재하는지 확인한다.

```bash
# 관계 섹션의 링크 대상 파일 존재 여부 확인
grep -rh '\[.*\](\.\/.*\.md)' docs/okf/ \
  | grep -oP '\(\.\/\K[^)]+' \
  | sort -u \
  | while read target; do
      [ -f "docs/okf/$target" ] || echo "MISSING: $target"
    done
```

추가로, 본문에서 반복 언급되지만 링크가 없는 개념어도 후보로 제시한다 (자동 탐지 어려우므로 AI가 읽고 판단).

**보고 형식**:

| 참조 위치 | 언급된 개념 | 노드 존재 | 조치 제안 |
|-----------|-------------|-----------|-----------|
| `a.md` | `b.md` | ❌ 없음 | `b.md` 신규 작성 검토 |

---

## 6. 결과 보고 및 수정 확인

위 4가지 점검을 마친 뒤, 각 표를 합산해 다음 형식으로 보고한다.

```
## OKF Lint 결과

점검 경로: docs/okf/
점검 시각: <ISO8601, KST>

### 모순 (N건)
<표>

### Stale (N건)
<표>

### Orphan (N건)
<표>

### 누락 cross-ref (N건)
<표>

---
이상 발견 없음: ✅ / 발견: ⚠️ N건 — 아래 수정 제안을 검토 후 진행해 주세요.
```

**자동 수정 금지.** 모든 수정(노드 삭제·갱신·신규 작성)은 사용자 확인 후 별도 작업으로 진행한다.
