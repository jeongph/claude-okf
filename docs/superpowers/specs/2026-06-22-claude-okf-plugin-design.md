# claude-okf 플러그인 설계

- 작성일: 2026-06-22
- 작성자: claude
- 대상: `lighthouse/repositories/claude-okf` (독립 Claude Code 플러그인 → `jeongph/claude-okf`)

## 1. 배경 (Why)

- **OKF (Open Knowledge Format, Google)**: 지식 노드 포맷 표준. 마크다운 + YAML frontmatter, `type`만 필수, 마크다운 링크로 관계 그래프. *포맷*만 정의하고 운영 방식은 없음.
- **Karpathy LLM-wiki (Gist, 38k★)**: 에이전트가 읽고 쓰고 유지하는 마크다운 지식베이스. `raw/`(불변 소스) + `wiki/`(LLM 생성) + `CLAUDE.md`(스키마) 3-layer, **ingest/query/lint** 워크플로우. *운영 방식*은 풍부하나 포맷은 느슨.
- **상보 관계**: OKF=표준 포맷, Karpathy=운영 워크플로우. 한쪽이 가진 걸 다른 쪽이 비워둠.
- **문제**: 이 패턴을 쓰려면 사용자가 `CLAUDE.md` 스키마를 손수 작성하고 양식·검증·유지를 수동 관리해야 함 → 진입장벽.
- **해결**: 플러그인으로 패키징 → **설치만으로 OKF 기반 LLM-wiki가 자동 활성화**.

## 2. 목표

claude-okf를 설치하면:
- AI가 OKF 양식·작성 원칙을 자동으로 앎 (skill)
- 코드·소스에서 노드 초안 생성 (agent)
- 노드 작성 시 자동 검증·index 갱신 (hook)
- 모순·stale·orphan을 점검 (skill/command)
- 위키에서 grounded 답을 찾음 (command)

## 3. 아키텍처

**3-layer (코드베이스 맥락에 매핑):**
- `raw` = 코드·원본 (사람이 큐레이션, 불변)
- `wiki` = `docs/okf/` OKF 노드 (AI가 생성·유지)
- `schema` = **플러그인 자체** (Karpathy가 CLAUDE.md로 한 걸, plugin이 제공)

**컴포넌트 역할 맵:**

| OKF 동작 | `command` (사람) | `skill` (AI 자율) | `hook` (자동) | `agent` (격리) |
|---|:---:|:---:|:---:|:---:|
| 양식·작성 원칙 | — | ✅ okf-authoring | — | — |
| ingest (소스→노드) | `/okf-ingest` | ✅ | — | ✅ enrichment |
| lint (모순·stale·orphan) | `/okf-lint` | ✅ okf-lint | — | — |
| validate (포맷·링크) | `/okf-validate` | — | ✅ | — |
| index/log 유지 | — | — | ✅ | — |
| query (위키서 답) | `/okf-ask` | ✅ | — | — |

원리: **skill(AI 자율) + hook(결정론적)** 이 "자동 활성화"의 핵심. command는 사람 진입점, agent는 무거운 격리 작업.

## 4. 컴포넌트 상세

### skills/
- **okf-authoring** — OKF 양식 + 작성 원칙을 AI가 노드 작성 시 자율 적용. 핵심: frontmatter 스키마(`type` 필수 등), 본문 구조, **작성 원칙(코드 복제 금지, 코드에 없는 맥락만, 싱크 회피)**. *이게 과잉·싱크 함정을 막는 가드레일.*
- **okf-lint** — 모순·stale·orphan·누락 cross-ref 점검을 AI가 갱신 직후 자율 수행(또는 `/okf-lint`로 명시).

### commands/
- **/okf-ingest `<source>`** — 소스(코드 경로 등)를 받아 노드화 (enrichment agent 호출)
- **/okf-lint** — 위키 health-check 명시 트리거
- **/okf-validate** — frontmatter 스키마·링크 유효성 검증
- **/okf-ask `<question>`** — index 기반으로 위키에서 답 합성

### hooks/hooks.json
- **PostToolUse** (Write가 `docs/okf/*` 대상일 때): 자동 `validate` + `index.md`/`log.md` 갱신. "까먹지 않는" 결정론적 유지.

### agents/
- **okf-enrichment** — 코드(엔티티·API·도메인)를 읽고 OKF 노드 *초안* 생성. 컬럼 복제가 아니라 **관계·맥락 보강**(join paths·이유). 사람은 검수·큐레이션.

## 5. OKF + Karpathy 융합 결정

- **링크**: OKF 표준 `[name](./name.md)`을 기본으로 한다 (claude-okf는 OKF *표준* 준수가 정체성). `[[wikilink]]`(Obsidian)는 비범위.
- **예약 파일**: `index.md`(카탈로그, 매 ingest 갱신) + `log.md`(`## [yyyy-MM-dd] ingest | …` 시간순). 둘 다 OKF·Karpathy 공통.
- **frontmatter**: OKF `type` 필수 + 표준 필드. (Karpathy의 느슨함보다 OKF의 구조를 채택)
- **작성 원칙**: *코드 복제 금지, 코드에 없는 맥락만* — claude-okf의 핵심 차별점이자 싱크 방지 장치.

## 6. 플러그인 구조 (lighthouse 패턴)

```
claude-okf/                          (→ github jeongph/claude-okf)
├── .claude-plugin/plugin.json       (name·version·description·author·license·keywords)
├── skills/
│   ├── okf-authoring/SKILL.md
│   └── okf-lint/SKILL.md
├── commands/
│   ├── okf-ingest.md · okf-lint.md · okf-validate.md · okf-ask.md
├── hooks/hooks.json
├── agents/okf-enrichment.md
├── docs/superpowers/specs|plans/
├── .github/workflows/  (release.yml · update-sha.yml)
├── README.md · LICENSE · .gitignore
```

## 7. 배포

- **독립 repo** `jeongph/claude-okf` (lighthouse/repositories 하위)
- **마켓 등록**: `claude-plugins/.claude-plugin/marketplace.json`에 `{name, description, source:{url, sha}}` 추가
- **CI**: `.github/workflows` (release + marketplace sha 자동 갱신 — claude-telemetry 패턴)
- **참조 모델**: `claude-intent` (skill 기반, `docs/intent/` 기록·역추적 — 구조가 가장 유사)

## 8. 비범위 (초기 제외)

- 코드베이스 외 소스(PDF·웹) ingest — 1차는 코드→노드에 집중
- 그래프 시각화(OKF HTML visualizer) — 별도
- `[[wikilink]]`/Obsidian 호환 — OKF 표준 링크만

## 9. 검증

- 각 컴포넌트 단위: skill 자율 invoke / command 실행 / hook 트리거(Write→validate) / agent 초안 생성
- end-to-end: 테스트 위키에 코드 ingest → 노드 생성 → validate(hook) → lint → ask 가 동작
- plugin.json·marketplace.json 형식이 lighthouse 기존 플러그인과 정합
