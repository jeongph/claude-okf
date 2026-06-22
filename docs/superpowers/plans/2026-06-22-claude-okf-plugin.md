# claude-okf 플러그인 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** OKF 기반 LLM-wiki를 설치만으로 자동 활성화하는 Claude Code 플러그인(claude-okf)을 lighthouse 플러그인 패턴으로 구축한다.

**Architecture:** skill(AI 자율) + command(사람 진입점) + hook(결정론적 자동) + agent(격리)로 OKF 동작을 패키징한다. 컴포넌트는 마크다운(skill/command/agent) + JSON(plugin.json/hooks.json) + bash(hook 스크립트)다. 실행 코드가 적은 "문서·설정 중심" 플러그인이라, 검증은 단위 테스트 대신 **형식 유효성(JSON/frontmatter) + 스크립트 동작 + 설치 후 동작 확인**으로 한다.

**Tech Stack:** Markdown, YAML frontmatter, JSON, bash. (참조: claude-intent=skill, claude-telemetry=command/hook/CI)

**참조 spec:** `docs/superpowers/specs/2026-06-22-claude-okf-plugin-design.md` — 양식·정책의 단일 출처.

## Global Constraints

- 작업 repo: `/Users/jeonguk/dev/lighthouse/repositories/claude-okf` (독립 git, 현재 `main`, 초기 커밋 `937e447` 존재). remote는 아직 없음 → 각 task는 **로컬 `main`에 커밋**, GitHub push·PR은 완성 후
- lighthouse 커밋 컨벤션: Conventional Commits, `<type>` 영어 소문자 + 제목 한글, `--squash` 금지
- 본문·설명은 한글, 식별자·경로·필드명·키는 영어
- 플러그인 형식(lighthouse 패턴): `.claude-plugin/plugin.json`, `skills/<name>/SKILL.md`, `commands/<name>.md`, `agents/<name>.md`, `hooks/hooks.json` + `hooks/scripts/*.sh`
- hook 스크립트 경로는 `${CLAUDE_PLUGIN_ROOT}/...` 사용 (claude-telemetry 패턴)
- OKF 표준 준수: frontmatter `type` 필수, 링크는 `[name](./name.md)`, 예약 파일 `index.md`/`log.md`
- **작성 원칙(핵심)**: 노드는 코드 복제가 아니라 "코드에 없는 맥락"만 담는다 (싱크 방지). 이 원칙을 skill·agent 프롬프트에 명시
- 참조 모델 파일(형식 그대로 따를 것):
  - skill → `repositories/claude-intent/skills/intent-record/SKILL.md`
  - command → `repositories/claude-telemetry/commands/setup.md`
  - hook → `repositories/claude-telemetry/hooks/hooks.json`
  - plugin.json → `repositories/claude-telemetry/.claude-plugin/plugin.json`
  - marketplace.json → `repositories/claude-plugins/.claude-plugin/marketplace.json`

---

## File Structure

**생성:**
- `.claude-plugin/plugin.json` — 플러그인 manifest
- `skills/okf-authoring/SKILL.md` — OKF 양식·작성 원칙 (AI 자율)
- `skills/okf-lint/SKILL.md` — 모순·stale·orphan 점검 (AI 자율)
- `commands/okf-ingest.md` `okf-lint.md` `okf-validate.md` `okf-ask.md` — 사람 진입점
- `agents/okf-enrichment.md` — 코드→노드 초안
- `hooks/hooks.json` — PostToolUse 트리거
- `hooks/scripts/validate.sh` — frontmatter·링크 검증
- `hooks/scripts/update-index.sh` — index.md 갱신
- `LICENSE` (MIT), `.github/workflows/release.yml` `update-sha.yml`

**수정:**
- `README.md` — 사용법 보강
- (외부) `repositories/claude-plugins/.claude-plugin/marketplace.json` — claude-okf 등록

---

## Task 1: plugin.json (manifest)

**Files:** Create `.claude-plugin/plugin.json`

**Interfaces:** Produces — 플러그인 정체성. 이후 모든 컴포넌트가 이 plugin에 속함. version은 hook/CI가 참조.

- [ ] **Step 1: plugin.json 작성**

`repositories/claude-telemetry/.claude-plugin/plugin.json` 형식 그대로:
```json
{
  "name": "claude-okf",
  "version": "0.1.0",
  "description": "OKF(Open Knowledge Format) 기반 LLM-wiki를 자동 활성화 — 코드에서 지식 노드를 작성·검증·lint·enrichment",
  "author": { "name": "JeongUk Park", "url": "https://github.com/jeongph" },
  "homepage": "https://github.com/jeongph/claude-okf",
  "repository": "https://github.com/jeongph/claude-okf",
  "license": "MIT",
  "keywords": ["okf", "llm-wiki", "knowledge-base", "documentation", "claude-code"]
}
```

- [ ] **Step 2: JSON 유효성 검증**

Run:
```bash
cd /Users/jeonguk/dev/lighthouse/repositories/claude-okf
python3 -m json.tool .claude-plugin/plugin.json > /dev/null && echo "valid JSON"
```
Expected: `valid JSON`

- [ ] **Step 3: 커밋**
```bash
git -C /Users/jeonguk/dev/lighthouse/repositories/claude-okf add .claude-plugin/plugin.json
git -C /Users/jeonguk/dev/lighthouse/repositories/claude-okf commit -m "feat: 플러그인 manifest(plugin.json) 추가"
```

---

## Task 2: okf-authoring skill (핵심)

**Files:** Create `skills/okf-authoring/SKILL.md`

**Interfaces:** Produces — OKF 양식·작성 원칙. agent·command가 이 skill의 양식을 전제로 노드를 만든다.

- [ ] **Step 1: SKILL.md 작성**

형식은 `repositories/claude-intent/skills/intent-record/SKILL.md`를 그대로 따른다 (frontmatter `name` + 상세 `description`, 본문 워크플로우). 내용 출처는 spec 4·5장 + jenxor `okf-convention.md`(특히 "작성 원칙" 절).

frontmatter:
```yaml
---
name: okf-authoring
description: Use when writing or updating OKF knowledge nodes (docs/okf/*.md) — defines frontmatter schema, body structure, and the authoring discipline. 사용자가 "OKF 노드 작성", "위키 노드 만들어", "지식 노드 기록", "docs/okf 정리", "이 코드 위키화"라고 하거나, AI가 코드·도메인 지식을 OKF 노드로 기록·갱신할 때 스스로 사용. 핵심 규율: 코드 복제가 아니라 코드에 없는 맥락(이유·관계·조망)만 담는다.
---
```

본문에 반드시 포함:
1. **frontmatter 스키마** — `type`(필수) + `title`·`description`·`resource`·`tags`·`timestamp`(권장) + `status`·`stack`·`depends_on`(확장). type 종류표(Product/Infra/Tool/Index/History + 열린 집합)
2. **본문 구조** — `# 제목` / `## 요약` / `## 구성` / `## 관계`(마크다운 링크) / `## 상세 지식`(resource 포인터)
3. **작성 원칙** (가장 중요): 코드 복제 금지, 코드에 없는 맥락만, `resource`로 원본(SSOT) 가리키기, 변경 시 같은 PR에서 갱신
4. **날짜** — 파일명 `yyyy-MM-dd` / `timestamp` ISO8601(+09:00)
5. **링크** — `[name](./name.md)` (OKF 표준), `index.md`/`log.md` 예약

- [ ] **Step 2: 검증**

Run:
```bash
cd /Users/jeonguk/dev/lighthouse/repositories/claude-okf
grep -qE '^name: okf-authoring' skills/okf-authoring/SKILL.md && echo "name OK"
grep -qE 'description:' skills/okf-authoring/SKILL.md && echo "desc OK"
grep -q '복제' skills/okf-authoring/SKILL.md && echo "작성원칙 포함 OK"
```
Expected: 세 줄 모두 출력

- [ ] **Step 3: 커밋**
```bash
git -C /Users/jeonguk/dev/lighthouse/repositories/claude-okf add skills/okf-authoring/
git -C /Users/jeonguk/dev/lighthouse/repositories/claude-okf commit -m "feat(skill): okf-authoring — OKF 양식·작성 원칙"
```

---

## Task 3: okf-lint skill

**Files:** Create `skills/okf-lint/SKILL.md`

**Interfaces:** Consumes — Task 2의 양식. Produces — 위키 health-check 절차. `/okf-lint` command가 이 skill을 트리거.

- [ ] **Step 1: SKILL.md 작성**

intent-record 형식. frontmatter:
```yaml
---
name: okf-lint
description: Use after writing/updating OKF nodes, or when checking wiki health — finds contradictions, stale claims, orphan pages, missing cross-references. 사용자가 "위키 점검", "okf lint", "노드 정합성 확인", "오래된 노드 찾아"라고 하거나, AI가 노드를 여러 개 갱신한 뒤 스스로 정합성을 점검할 때 사용.
---
```

본문 워크플로우 (Karpathy lint 4종 점검, 각 bash 방법 제시):
1. **모순** — 같은 대상을 다루는 노드 간 상충 주장 (사람 판단 필요, 후보 제시)
2. **stale** — `timestamp`가 오래됐고 원본(`resource`)이 그 후 변경된 노드: `git log` 비교
3. **orphan** — 어떤 노드도 링크하지 않는 노드: `grep -rL` 로 inbound 링크 0 검출
4. **누락 cross-ref / 미작성** — 자주 언급되나 자기 노드가 없는 개념
5. 결과를 표로 보고 + 수정 제안 (자동 수정 금지, 사용자 확인)

- [ ] **Step 2: 검증**
```bash
cd /Users/jeonguk/dev/lighthouse/repositories/claude-okf
grep -qE '^name: okf-lint' skills/okf-lint/SKILL.md && echo "OK"
grep -qE 'orphan|stale|모순' skills/okf-lint/SKILL.md && echo "점검항목 OK"
```
Expected: 두 줄 출력

- [ ] **Step 3: 커밋**
```bash
git -C /Users/jeonguk/dev/lighthouse/repositories/claude-okf add skills/okf-lint/
git -C /Users/jeonguk/dev/lighthouse/repositories/claude-okf commit -m "feat(skill): okf-lint — 모순·stale·orphan 점검"
```

---

## Task 4: commands (4개)

**Files:** Create `commands/okf-ingest.md` `okf-lint.md` `okf-validate.md` `okf-ask.md`

**Interfaces:** Consumes — Task 2·3 skill, Task 5 agent. 사람 진입점.

- [ ] **Step 1: 4개 command 작성**

형식은 `repositories/claude-telemetry/commands/setup.md` (frontmatter `description` + `allowed-tools` + 본문 프롬프트). 각 내용:

- `okf-ingest.md` — `description: 코드/소스를 OKF 노드로 추출(enrichment)`, `allowed-tools: [Bash, Read, Glob, Grep, Write, Task]`. 본문: 인자로 받은 경로를 okf-enrichment agent(Task 5)로 보내 노드 초안 생성 → 사용자 검수 → docs/okf/ 저장 → index/log 갱신
- `okf-lint.md` — `description: 위키 health-check`, `allowed-tools: [Bash, Read, Grep, Glob]`. 본문: okf-lint skill(Task 3) 절차를 명시 실행
- `okf-validate.md` — `description: OKF 노드 frontmatter·링크 검증`, `allowed-tools: [Bash]`. 본문: `hooks/scripts/validate.sh`(Task 6)를 docs/okf 대상으로 실행하고 결과 보고
- `okf-ask.md` — `description: 위키에서 grounded 답변`, `allowed-tools: [Read, Grep, Glob]`. 본문: `index.md`로 관련 노드 검색 → 인용과 함께 답변 합성 → 가치 있으면 새 노드로 저장 제안

- [ ] **Step 2: 검증**
```bash
cd /Users/jeonguk/dev/lighthouse/repositories/claude-okf
for c in okf-ingest okf-lint okf-validate okf-ask; do
  grep -qE '^description:' "commands/$c.md" && echo "$c OK" || echo "$c FAIL"
done
```
Expected: 4개 모두 `OK`

- [ ] **Step 3: 커밋**
```bash
git -C /Users/jeonguk/dev/lighthouse/repositories/claude-okf add commands/
git -C /Users/jeonguk/dev/lighthouse/repositories/claude-okf commit -m "feat(command): okf-ingest·lint·validate·ask 추가"
```

---

## Task 5: okf-enrichment agent

**Files:** Create `agents/okf-enrichment.md`

**Interfaces:** Consumes — Task 2 양식. Produces — 코드→노드 초안. `/okf-ingest`가 이 agent를 Task로 호출.

- [ ] **Step 1: agent 작성**

Claude Code agent 형식 (frontmatter `name`·`description`·`tools` + 본문 시스템 프롬프트). frontmatter:
```yaml
---
name: okf-enrichment
description: 코드(엔티티·API·도메인 로직)를 읽어 OKF 노드 초안을 생성한다. 컬럼·시그니처 복제가 아니라 관계·맥락·이유를 보강한다.
tools: [Read, Grep, Glob, Bash]
---
```

본문 시스템 프롬프트에 반드시:
1. 입력(코드 경로)을 읽고 OKF 노드 초안 생성 (okf-authoring 양식)
2. **복제 금지**: 컬럼/타입/메서드 시그니처를 나열하지 않는다. `resource`로 원본을 가리킨다
3. **보강(enrich)**: 역할, 관계(join paths·의존), 설계 이유, 조망 — *코드를 봐도 빨리 안 보이는 것*만
4. 출력은 *초안* — 사용자가 검수·큐레이션 (자동 확정 금지)

- [ ] **Step 2: 검증**
```bash
cd /Users/jeonguk/dev/lighthouse/repositories/claude-okf
grep -qE '^name: okf-enrichment' agents/okf-enrichment.md && echo "OK"
grep -q '복제' agents/okf-enrichment.md && echo "복제금지 원칙 OK"
```
Expected: 두 줄 출력

- [ ] **Step 3: 커밋**
```bash
git -C /Users/jeonguk/dev/lighthouse/repositories/claude-okf add agents/
git -C /Users/jeonguk/dev/lighthouse/repositories/claude-okf commit -m "feat(agent): okf-enrichment — 코드→노드 초안(맥락 보강)"
```

---

## Task 6: hooks (자동 검증·index 갱신)

**Files:** Create `hooks/hooks.json`, `hooks/scripts/validate.sh`, `hooks/scripts/update-index.sh`

**Interfaces:** Produces — Write가 `docs/okf/*.md`를 건드리면 자동 검증 + index 갱신. `/okf-validate`도 `validate.sh`를 재사용.

- [ ] **Step 1: validate.sh 작성 + 실패 테스트**

`hooks/scripts/validate.sh` — 인자로 받은 디렉토리의 `*.md`가 OKF 노드 양식을 지키는지 검사 (frontmatter `type` 존재, 상대 링크 대상 실재):
```bash
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
  grep -oE '\]\(\./[A-Za-z0-9_-]+\.md\)' "$f" | sed -E 's/\]\(\.\/(.*)\)/\1/' | while read -r t; do
    [ -f "$(dirname "$f")/$t" ] || echo "WARN $f: 깨진 링크 $t"
  done
done < <(find "$DIR" -name '*.md' -print0)
[ "$fail" -eq 0 ] && echo "OKF validate: OK" || echo "OKF validate: 경고 있음"
```

테스트 (type 없는 노드로 경고 확인):
```bash
cd /Users/jeonguk/dev/lighthouse/repositories/claude-okf
mkdir -p /tmp/okf-test && printf '%s\n' '---' 'title: x' '---' '# x' > /tmp/okf-test/bad.md
bash hooks/scripts/validate.sh /tmp/okf-test
```
Expected: `WARN .../bad.md: type 누락` + `OKF validate: 경고 있음`

- [ ] **Step 2: update-index.sh 작성**

`hooks/scripts/update-index.sh` — `docs/okf/*.md`(index.md 제외)의 frontmatter `type`·`title`·`description`을 모아 `docs/okf/index.md` 표 생성:
```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="${1:-docs/okf}"
[ -d "$DIR" ] || exit 0
OUT="$DIR/index.md"
{
  echo "---"; echo "type: Index"; echo "title: OKF 노드 지도"; echo "---"; echo
  echo "# OKF 노드 지도"; echo
  echo "| 노드 | type | 요약 |"; echo "|---|---|---|"
  for f in "$DIR"/*.md; do
    [ "$(basename "$f")" = "index.md" ] && continue
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    type=$(awk '/^type:/{print $2; exit}' "$f")
    desc=$(awk -F': ' '/^description:/{print $2; exit}' "$f")
    echo "| [$name](./$name.md) | ${type:--} | ${desc:--} |"
  done
} > "$OUT"
echo "index 갱신: $OUT"
```

테스트:
```bash
cd /Users/jeonguk/dev/lighthouse/repositories/claude-okf
mkdir -p /tmp/okf-test2 && printf '%s\n' '---' 'type: Table' 'title: users' 'description: 사용자' '---' '# users' > /tmp/okf-test2/users.md
bash hooks/scripts/update-index.sh /tmp/okf-test2 && grep -q 'users' /tmp/okf-test2/index.md && echo "index OK"
```
Expected: `index 갱신: ...` + `index OK`

- [ ] **Step 3: hooks.json 작성**

`repositories/claude-telemetry/hooks/hooks.json` 형식. PostToolUse(Write|Edit)에서 두 스크립트 실행:
```json
{
  "description": "docs/okf 노드 작성 시 자동 검증 + index 갱신",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/validate.sh docs/okf", "timeout": 15 },
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/update-index.sh docs/okf", "timeout": 15 }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: 검증 + 커밋**
```bash
cd /Users/jeonguk/dev/lighthouse/repositories/claude-okf
python3 -m json.tool hooks/hooks.json > /dev/null && echo "hooks.json valid"
chmod +x hooks/scripts/*.sh
git add hooks/
git commit -m "feat(hook): docs/okf 작성 시 자동 검증·index 갱신"
```
Expected: `hooks.json valid`

---

## Task 7: LICENSE · README · CI

**Files:** Create `LICENSE`, `.github/workflows/release.yml`, `.github/workflows/update-sha.yml`; Modify `README.md`

**Interfaces:** 배포 인프라. CI는 claude-telemetry 워크플로우를 참조.

- [ ] **Step 1: LICENSE (MIT) 작성** — 표준 MIT 전문, `Copyright (c) 2026 JeongUk Park`

- [ ] **Step 2: README 보강** — 설치법(마켓 경유), 컴포넌트 표(skill/command/hook/agent), 사용 예(`/okf-ingest <경로>`, 노드 작성→자동 검증). 기존 개념 절은 유지

- [ ] **Step 3 (선택): CI 워크플로우** — claude-okf는 순수 마크다운/bash라 **CI 없이도 동작한다.** 배포 자동화가 필요할 때만 `repositories/claude-telemetry/.github/workflows/`(release.yml·update-sha.yml)를 참조해 릴리스 태그 + marketplace sha 갱신 워크플로우를 작성한다. **1차 구현에서는 생략 가능** (생략 시 Task 8의 sha는 수동 갱신). 생략하면 이 Step의 검증·커밋도 건너뛴다

- [ ] **Step 4: 검증 + 커밋**
```bash
cd /Users/jeonguk/dev/lighthouse/repositories/claude-okf
test -f LICENSE && echo "LICENSE OK"
for w in .github/workflows/release.yml .github/workflows/update-sha.yml; do test -f "$w" && echo "$w OK"; done
git add LICENSE README.md .github/
git commit -m "docs: LICENSE·README 보강 및 릴리스 CI 추가"
```

---

## Task 8: 마켓 등록 + 최종 통합 검증

**Files:** Modify `repositories/claude-plugins/.claude-plugin/marketplace.json`

**Interfaces:** Consumes — 모든 이전 task. claude-okf를 마켓에 노출.

- [ ] **Step 1: 최종 구조 검증**
```bash
C=/Users/jeonguk/dev/lighthouse/repositories/claude-okf
echo "=== 필수 파일 ==="
for p in .claude-plugin/plugin.json skills/okf-authoring/SKILL.md skills/okf-lint/SKILL.md \
  commands/okf-ingest.md commands/okf-validate.md agents/okf-enrichment.md hooks/hooks.json \
  hooks/scripts/validate.sh hooks/scripts/update-index.sh; do
  test -f "$C/$p" && echo "OK $p" || echo "MISSING $p"
done
python3 -m json.tool "$C/.claude-plugin/plugin.json" >/dev/null && python3 -m json.tool "$C/hooks/hooks.json" >/dev/null && echo "JSON valid"
```
Expected: 모든 `OK` + `JSON valid` (MISSING 없음)

- [ ] **Step 2: marketplace.json에 claude-okf 등록**

`repositories/claude-plugins/.claude-plugin/marketplace.json`의 `plugins` 배열에 추가 (기존 항목 형식 그대로, sha는 claude-okf의 최신 커밋):
```json
{
  "name": "claude-okf",
  "description": "OKF 기반 LLM-wiki 자동 활성화 — 코드에서 지식 노드를 작성·검증·lint·enrichment",
  "source": {
    "source": "url",
    "url": "https://github.com/jeongph/claude-okf.git",
    "sha": "<claude-okf main 최신 커밋 sha>"
  }
}
```
> 주의: GitHub repo·push가 선행돼야 url·sha가 유효. push 전이면 이 step은 "등록 항목 준비"까지만 하고, push 후 sha 확정 (사용자 보고).

- [ ] **Step 3: 검증 + 커밋 (claude-plugins repo)**
```bash
M=/Users/jeonguk/dev/lighthouse/repositories/claude-plugins
python3 -m json.tool "$M/.claude-plugin/marketplace.json" >/dev/null && echo "marketplace valid"
git -C "$M" add .claude-plugin/marketplace.json
git -C "$M" commit -m "feat: claude-okf 플러그인 마켓 등록"
```
Expected: `marketplace valid`

- [ ] **Step 4: 완료 보고 (push·머지는 사용자 결정)**

claude-okf와 claude-plugins 각각의 커밋 목록을 보고하고, GitHub repo 생성·push·마켓 sha 확정 여부를 사용자에게 확인한다.

---

## 검증 요약 (spec 9장 대응)

- [ ] 각 컴포넌트 형식 유효 (plugin.json·hooks.json JSON valid, SKILL/command/agent frontmatter) — Task 1·2·3·4·5·6·8
- [ ] hook 스크립트 동작 (validate 경고 검출, update-index 표 생성) — Task 6 Step 1·2
- [ ] 작성 원칙(복제 금지)이 skill·agent에 명시 — Task 2·5 검증
- [ ] 마켓 등록 형식이 기존 플러그인과 정합 — Task 8
- [ ] 설치 후 end-to-end(노드 작성→hook 검증→lint→ask) 동작 — 사용자 수동 확인
