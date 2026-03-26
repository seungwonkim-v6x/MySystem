# MySystem — Personal Workflow Gates

이 파일은 모든 프로젝트에 적용되는 **의무 게이트**를 정의한다.
프로젝트별 워크플로우는 각 프로젝트 CLAUDE.md에서 이 게이트를 통합하여 사용한다.

---

## Gate 1: Slow Down — 코드 작업 전 구체화

**트리거**: 사용자가 코드 구현/수정/리팩토링을 요청할 때
**동작**: `/slow-down` 스킬을 실행하여 5단계 구체화 수행
**완료 조건**: 사용자가 구체화 결과를 승인

```
IF 사용자가 코드 작업을 요청
AND 다음 예외에 해당하지 않음:
  - "바로 해줘", "skip slow-down", "구체화 건너뛰기"
  - 오타/한줄 수정 등 자명한 작업
  - 이미 설계가 완료된 티켓 (Description에 구현 설계 존재)
  - 질문, 설명, 리서치 요청
THEN /slow-down 실행 → 승인 후 다음 단계 진행
```

## Gate 2: Plan Review — 비자명한 작업의 설계 검증

**트리거**: slow-down 결과 영향 범위가 3개 파일 이상이거나, 아키텍처 변경이 포함될 때
**동작**: Plan Mode 진입 후 `/autoplan` 또는 개별 리뷰 실행
**완료 조건**: 사용자가 플랜을 승인

```
IF 작업이 비자명 (영향 파일 3+, 새 모듈, API 변경, DB 스키마 변경)
THEN EnterPlanMode → /autoplan (또는 /plan-ceo-review, /plan-eng-review, /plan-design-review 개별)
     → 승인 후 구현 시작
ELSE 바로 구현 진행
```

## Gate 3: Bugbot — 커밋 전 버그 리뷰

**트리거**: git commit 또는 push를 수행하기 직전
**동작**: `/bugbot` 실행
**완료 조건**: Clean이면 커밋 진행, Critical 발견 시 수정 후 재실행

```
IF git commit 또는 push 수행 직전
AND 다음 예외에 해당하지 않음:
  - "skip bugbot", "just commit"
THEN /bugbot 실행 → Clean이면 커밋, Critical이면 수정
```

---

## 워크플로우 요약

모든 코드 작업은 이 순서를 따른다. 각 프로젝트 CLAUDE.md에서 프로젝트 고유 단계를 추가한다.

```
요청 접수
  ↓
[Gate 1] /slow-down        ← 구체화 (의무)
  ↓
[Gate 2] /autoplan         ← 설계 리뷰 (비자명 작업만)
  ↓
구현 + 테스트              ← 프로젝트별 상세 (lint, test 등)
  ↓
[Gate 3] /bugbot           ← 커밋 전 리뷰 (의무)
  ↓
커밋/PR/배포               ← /ship 또는 프로젝트별 워크플로우
```

### 디버깅 시
```
버그 리포트/에러 발견 → /investigate (근본원인 필수, 추측 금지)
```

### 주간 회고
```
주말/스프린트 끝 → /retro (커밋 분석, 팀 기여도)
```

---

## 스킬 구성

### 개인 소유 (MySystem)
| 스킬 | 역할 |
|---|---|
| slow-down | Gate 1: 코드 전 구체화 |
| bugbot | Gate 3: 커밋 전 버그 리뷰 |

### gstack 의존 (자동 업데이트)
| 스킬 | 역할 |
|---|---|
| office-hours | 아이디어 검증 (Gate 1 이전, 선택) |
| autoplan | Gate 2: CEO+Design+Eng 리뷰 파이프라인 |
| plan-ceo-review | Gate 2 개별: 범위/야망 점검 |
| plan-eng-review | Gate 2 개별: 아키텍처/엣지케이스 |
| plan-design-review | Gate 2 개별: UI/UX 점수 |
| review | PR 코드 리뷰 (보안/구조) |
| investigate | 디버깅: 근본원인 분석 |
| retro | 주간 회고 |
| ship | 커밋→PR 워크플로우 |
