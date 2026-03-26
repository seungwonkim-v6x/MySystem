# MySystem — Personal Workflow Rules

이 파일은 모든 프로젝트에 적용되는 개인 워크플로우 규칙이다.
도메인/프로젝트 특화 규칙은 각 프로젝트의 CLAUDE.md에 작성한다.

---

## 핵심 원칙

> "AI didn't make the slow phases less important — it made them more important."

1. **구체화 먼저, 코드는 나중에** — 무엇을/왜를 명확히 한 후에만 구현
2. **승인 없이 코드 없다** — 계획을 사용자가 확인한 후 진행
3. **커밋 전 리뷰 필수** — 모든 커밋은 버그 리뷰를 통과해야 함

---

## 의무 규칙 (MANDATORY)

### 1. Slow Down — 코드 작업 전 구체화 (`/slow-down`)

코드 구현을 시작하기 **전에** 반드시 실행한다.

- 5단계: 문제 정의 → 완료 조건 → 범위 → 리스크 점검 → 접근 방식 합의
- 사용자 승인 후에만 코드 작성 시작
- **스킵 가능**: "바로 해줘", "skip slow-down" / 오타 수정 등 자명한 작업 / 이미 설계된 티켓

### 2. Bugbot — 커밋 전 버그 리뷰 (`/bugbot`)

git commit 또는 push **전에** 반드시 실행한다.

- 별도 Agent(서브에이전트)로 fresh-eyes 리뷰
- Critical 버그 발견 시 수정 후 진행, Clean이면 바로 커밋
- **스킵 가능**: "skip bugbot", "just commit"

---

## 워크플로우: 아이디어 → 배포

아래 스킬들은 gstack에서 제공되며, 상황에 맞게 활용한다.

```
아이디어/문제 발견
    ↓
/office-hours          ← 아이디어 검증, 문제 정의 (선택)
    ↓
/slow-down             ← 구체화 (의무)
    ↓
Plan Mode 진입
    ↓
/autoplan              ← CEO + Design + Eng 리뷰 자동 파이프라인
  또는 개별 실행:
  ├─ /plan-ceo-review    범위/야망/전략 점검
  ├─ /plan-design-review UI/UX 디자인 점수 매기기
  └─ /plan-eng-review    아키텍처/엣지케이스/성능 점검
    ↓
구현
    ↓
/review                ← PR 코드 리뷰 (보안/구조)
    ↓
/bugbot                ← 커밋 전 버그 리뷰 (의무)
    ↓
/ship                  ← 커밋 → PR → 머지
```

### 디버깅 시

```
/investigate           ← 체계적 디버깅 (근본원인 필수, 추측 금지)
```

### 주간 회고

```
/retro                 ← 커밋 이력 분석, 팀별 기여도, 개선점
```

---

## 스킬 구성

### 개인 소유 (MySystem 관리)
| 스킬 | 위치 | 역할 |
|---|---|---|
| slow-down | `skills/slow-down/` | 코드 전 구체화 |
| bugbot | `skills/bugbot/` | 커밋 전 버그 리뷰 |

### gstack 의존 (자동 업데이트)
| 스킬 | 역할 |
|---|---|
| office-hours | 아이디어 검증/문제 정의 |
| plan-ceo-review | CEO 시점 플랜 리뷰 |
| plan-eng-review | 엔지니어링 플랜 리뷰 |
| plan-design-review | 디자인 플랜 리뷰 |
| autoplan | 리뷰 자동 파이프라인 |
| review | PR 코드 리뷰 |
| investigate | 체계적 디버깅 |
| retro | 주간 회고 |
| ship | 커밋→PR 워크플로우 |
