---
description: OKF 노드 frontmatter·링크 검증
allowed-tools: [Bash]
---

# OKF Validate

`hooks/scripts/validate.sh`를 실행해 OKF 노드의 frontmatter 필드와 내부 링크를 검증하고 결과를 보고한다.

## 실행 흐름

---

## 단계 1: 검증 대상 경로 결정

인자로 경로가 주어지면 해당 경로를 사용한다. 없으면 `docs/okf/`를 기본값으로 쓴다.

---

## 단계 2: validate.sh 실행

`hooks/scripts/validate.sh`를 대상 경로에 대해 실행한다.

```bash
bash hooks/scripts/validate.sh docs/okf/
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
