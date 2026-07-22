# claude-okf

OKF(Open Knowledge Format) 기반 LLM-wiki를 Claude Code에서 **자동 활성화**하는 플러그인.

설치하면 — AI가 OKF 양식을 알고, 코드에서 노드 초안을 만들고, 노드 작성 시 자동 검증·`index` 갱신, 모순·stale 점검, 위키에서 grounded 답을 찾습니다.

## 개념

- **OKF** (Open Knowledge Format, Google): 지식 노드 포맷 표준 — 마크다운 + YAML frontmatter, `type` 필수, 마크다운 링크로 관계 그래프
- **LLM-wiki** (Andrej Karpathy): 에이전트가 읽고 쓰고 유지하는 마크다운 지식베이스 — `raw`/`wiki`/스키마 3-layer, ingest/query/lint 워크플로우
- **claude-okf** = 둘을 융합 — OKF의 *표준 포맷* + Karpathy의 *운영 워크플로우* 를 Claude Code 플러그인으로 패키징

## 설치

[jeongph/claude-plugins 마켓플레이스](https://github.com/jeongph/claude-plugins)에서 설치한다.

마켓플레이스 등록(최초 1회):

```sh
/plugin marketplace add jeongph/claude-plugins
```

플러그인 설치:

```sh
/plugin install claude-okf@jeongph-claude-plugins
```

설치 후 Claude Code를 재시작하면 플러그인이 자동 활성화된다.

## 컴포넌트

| 종류 | 이름 | 역할 |
|------|------|------|
| skill | `okf-authoring` | OKF 노드 작성·편집 가이드 — 양식 안내 + 노드 초안 생성 |
| skill | `okf-lint` | OKF 노드 정적 검사 — frontmatter 필수 필드·관계 링크 검증 |
| command | `/okf-ingest` | 코드·문서를 분석해 OKF 노드 초안을 생성하고 wiki에 추가 |
| command | `/okf-validate` | 지정 경로의 OKF 노드를 검증하고 오류를 보고 |
| command | `/okf-lint` | OKF 노드 lint 실행 (stale 링크·중복 노드·모순 점검) |
| command | `/okf-ask` | OKF wiki를 기반으로 grounded 답변 생성 |
| hook | `PostToolUse (Write\|Edit 트리거)` | 노드 저장 시 자동으로 검증·index 갱신 실행 |
| agent | `okf-enrichment` | 코드베이스 분석 후 OKF 노드를 풍부하게 보강하는 전용 에이전트 |

## 사용 예

### 코드에서 노드 초안 생성

```
/okf-ingest repositories/my-service/src
```

`src` 디렉토리를 분석해 OKF 노드 초안을 생성하고 wiki에 추가한다.

### 노드 작성 시 자동 검증

OKF 노드 파일(`.md`)을 편집·저장하면 `PostToolUse (Write|Edit 트리거)` 훅이 자동으로 실행된다.

- frontmatter 필수 필드(`type` 등) 누락 검사
- 관계 링크 유효성 검증
- `index.md` 갱신

오류가 있으면 편집 직후 터미널에 보고된다.

### 위키 기반 질의

```
/okf-ask my-service는 어떤 인프라에 배포되나요?
```

OKF wiki를 검색해 grounded 답변을 생성한다.

### 수동 노드 검증

```
/okf-validate docs/knowledge/my-node.md
```

지정 파일의 OKF 노드를 검증하고 오류 목록을 출력한다.

## 세션 핸드오프는 어디로 갔나

`handoff` 스킬·`/handoff` 커맨드는 [claude-tidy](https://github.com/jeongph/claude-tidy) 플러그인으로 이관됐다 (v0.5.0). claude-tidy의 handoff는 범용 세션 인수인계를 담당하며, OKF 프로젝트(`docs/knowledge/`)를 감지하면 기존과 동일한 절차(History 노드 마감 · resume 스냅샷 · 트래커 동기화)를 수행한다.

## 라이선스

MIT — [LICENSE](LICENSE) 참조
