---
description: 세션 상태를 durable 노드로 저장하고 트래커 동기화 (핸드오프)
allowed-tools: [Bash, Read, Grep, Glob, Write, Edit, Task]
---

# Handoff

현재 세션의 상태를 다음 세션이 이어받도록 정리한다. `handoff` skill의 3층 모델(완료=History / 진행=resume 스냅샷 / 외부=트래커)을 따른다.

단계 1 → 7 순서로 실행한다. 단계를 건너뛰거나 병합하지 않는다. (넘길 상태가 없는 사소한 세션이면 단계 0에서 조기 종료)

---

## 단계 0: 핸드오프 필요 판단

이어받을 상태가 있는지 본다 — 진행 중 작업·미커밋 변경·연 PR·미완 다음 스텝 중 하나라도 있으면 진행. 없으면(단순 질의·완결된 사소한 수정) 사용자에게 "핸드오프할 상태가 없습니다"라고 알리고 종료한다.

---

## 단계 1: 세션 상태 수집

git과 대화에서 상태를 모은다.

```bash
git branch --show-current
git status --short
git log --oneline -8
git stash list
```

- **git**: 현재 브랜치, 미커밋/미추적 변경, 최근 커밋, 이번 세션이 만든 브랜치·PR·태그·배포
- **대화**: 완료한 작업 단위, 진행 중 작업과 도달 지점, 다음 액션, 블로커, 이번 세션의 결정과 근거, 발견한 함정

수집 결과를 아래 단계의 재료로 쓴다.

---

## 단계 2: 완료 작업 마감 → History 노드

이번 세션에 **완료된 작업 단위** 중 `docs/history/`에 노드가 없는 것을 찾아 초안한다.

- 파일명·frontmatter·본문(Why→How→What)은 프로젝트의 히스토리 컨벤션을 따른다. 없으면 `handoff` skill과 `okf-authoring` 스킬의 `type: History` 양식을 쓴다.
- `timestamp`는 실제 시각을 조회해 기록한다: `date '+%Y-%m-%dT%H:%M:%S+09:00'`
- 초안 후 커밋한다 (프로젝트 커밋 컨벤션 준수, 완료 작업이 여럿이면 작업 단위로 분리).

> 대형 세션이면 `Task`로 완료 작업 목록화를 병렬 위임할 수 있다.

---

## 단계 3: resume 노드 작성 / 갱신

`docs/knowledge/session-state.md`(없으면 생성, 있으면 **덮어씀**)를 `handoff` skill의 `type: Handoff` 포맷으로 쓴다.

핵심은 맨 위 **"▶ 여기서 시작"** 한 줄 — 다음 세션의 단일 다음 액션. 이어서 진행 중·남은 작업·블로커·결정(근거)·함정·부작용·검증 상태·완료(History 링크).

- `resource`에 `<branch> @ <SHA 7자리>`를 박아 staleness 감지 근거로 둔다.
- 대화 복붙·코드 복제 금지. 상세는 파일 경로·SHA로 가리킨다.
- 저장 시 OKF validate/update-index 훅이 있으면 자동 검증·색인된다.

---

## 단계 4: 태스크 트래커 동기화

작업 목록 트래커를 감지해 진행 상태를 맞춘다.

1. **감지**: `.okf/handoff.yml`이 있으면 그 설정을 쓴다. 없으면 추정 —
   - `gh` 사용 가능 + git 원격 GitHub → **github-issues**
   - Notion MCP 연결됨 → **notion**
   - `docs/tasks.md` 존재 → **file**
   - 위 모두 아님 → **none** (단계 건너뜀)
2. 추정 결과를 사용자에게 **한 줄로 확인**받는다 (틀리면 지정).
3. **동기화**: 진행 중 항목의 상태 전이 + 상태 코멘트(완료분·다음 액션 요약). 어댑터별로:
   - github-issues: `gh issue comment` + 필요 시 프로젝트 Status 전이
   - notion: Notion MCP로 페이지 속성·코멘트 갱신
   - file: `docs/tasks.md` 항목 갱신
4. **외부로 나가는 코멘트는 draft를 먼저 보여주고 확인**받는다 (설정 `auto: true`면 생략).

---

## 단계 5: 레포 위생 점검

컨텍스트가 사라지기 전에 흘린 것을 잡는다.

- 미커밋 변경 / 미추적 잔여 파일(스크린샷·임시파일 등) → 커밋 대상인지, 지워도 되는지 사용자에게 보고
- 머지됐는데 남은 로컬 브랜치, 남은 stash → 정리 제안
- 판단 애매한 파일은 지우지 말고 **surface만** 한다

---

## 단계 6: (선택) 개인 메모리 연동

`.remember/` 등 개인 메모리 도구가 감지되면, 그 버퍼(예: `now.md`)에 **resume 노드 포인터 한 줄**만 얹어 다음 세션 SessionStart 자동 로드에 태운다. 없으면 건너뛴다. **하드 의존을 만들지 않는다** — resume 노드가 SSOT다.

---

## 단계 7: 핸드오프 요약 출력

사용자에게 간결한 요약을 낸다:

- 이번 세션 완료분 (History 노드 링크)
- 현재 상태 + **다음 액션 한 줄**
- 블로커 / 대기 중인 것
- 트래커 동기화 결과
- 복원 경로: `docs/knowledge/session-state.md` (+ 개인 메모리 연동 시 그 위치)

끝으로 다음 세션 재개 방법을 안내한다: 새 세션에서 `session-state.md`를 읽거나 `/handoff-resume`(있으면)로 재브리핑.
