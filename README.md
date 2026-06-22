# claude-okf

OKF(Open Knowledge Format) 기반 LLM-wiki를 Claude Code에서 **자동 활성화**하는 플러그인.

설치하면 — AI가 OKF 양식을 알고, 코드에서 노드 초안을 만들고, 노드 작성 시 자동 검증·`index` 갱신, 모순·stale 점검, 위키에서 grounded 답을 찾습니다.

> 🚧 설계·구현 진행 중. 설계 문서: [`docs/superpowers/specs/`](docs/superpowers/specs/)

## 개념

- **OKF** (Open Knowledge Format, Google): 지식 노드 포맷 표준 — 마크다운 + YAML frontmatter, `type` 필수, 마크다운 링크로 관계 그래프
- **LLM-wiki** (Andrej Karpathy): 에이전트가 읽고 쓰고 유지하는 마크다운 지식베이스 — `raw`/`wiki`/스키마 3-layer, ingest/query/lint 워크플로우
- **claude-okf** = 둘을 융합 — OKF의 *표준 포맷* + Karpathy의 *운영 워크플로우* 를 Claude Code 플러그인으로 패키징

## 라이선스

MIT
