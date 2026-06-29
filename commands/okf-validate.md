---
description: OKF 노드 frontmatter·링크 검증
allowed-tools: [Bash]
---

# OKF Validate

`hooks/scripts/validate.sh`를 실행해 OKF 노드의 frontmatter 필드와 내부 링크를 검증하고 결과를 보고한다.

## 실행 흐름

---

## 단계 1: 검증 대상 경로 결정

검증 경로는 다음 순서로 정한다: ① 인자로 주어지면 그 경로 ② 없으면 `docs/knowledge/`(있으면) ③ 없으면 `docs/okf/`(하위호환) ④ 둘 다 없으면 `docs/knowledge/`.

---

## 단계 2: validate.sh 실행

`hooks/scripts/validate.sh`를 대상 경로에 대해 실행한다.

```bash
bash hooks/scripts/validate.sh   # 인자 생략 시 docs/knowledge → docs/okf 순으로 자동 감지
```

스크립트가 없으면 오류를 보고하고 중단한다.

```bash
[ -f hooks/scripts/validate.sh ] || echo "ERROR: hooks/scripts/validate.sh 없음"
```

---

## 단계 3: 결과 보고

스크립트 출력(exit code, 오류 목록)을 그대로 사용자에게 전달한다.

- exit code 0: 검증 통과 — 이상 없음을 알린다.
- exit code 1 이상: 검증 실패 — 오류 항목을 표로 정리해 보고한다.

**자동 수정 금지.** 오류 수정은 사용자 확인 후 별도 작업으로 진행한다.
