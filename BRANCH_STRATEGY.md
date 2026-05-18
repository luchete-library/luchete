# Branch Strategy

이 프로젝트는 Git Flow 기반 브랜치 전략을 사용합니다.

## Main branches

- `main`
  - 배포 가능한 안정 버전만 유지합니다.
  - 직접 작업하지 않고, 릴리스 또는 핫픽스가 끝났을 때만 병합합니다.

- `develop`
  - 다음 개발 버전을 통합하는 기본 개발 브랜치입니다.
  - 일반 기능 작업은 `develop`에서 분기합니다.

## Supporting branches

- `feature/<name>`
  - 새 기능 또는 작은 개선 작업에 사용합니다.
  - `develop`에서 분기하고 `develop`으로 병합합니다.
  - 예: `feature/visitor-state-labels`

- `release/<version>`
  - 배포 준비, QA, 문서 정리, 버전 조정에 사용합니다.
  - `develop`에서 분기하고 완료 후 `main`과 `develop`에 병합합니다.
  - 예: `release/0.1.0`

- `hotfix/<name>`
  - 배포 버전의 긴급 수정에 사용합니다.
  - `main`에서 분기하고 완료 후 `main`과 `develop`에 병합합니다.
  - 예: `hotfix/fix-launch-crash`

## Workflow

1. 기능 작업은 `develop`에서 최신 내용을 받습니다.
2. `feature/<name>` 브랜치를 만듭니다.
3. 작업 후 커밋 컨벤션에 맞춰 커밋합니다.
4. 기능이 끝나면 `develop`으로 병합합니다.
5. 배포 준비 시 `release/<version>` 브랜치를 만듭니다.
6. 릴리스가 끝나면 `main`과 `develop`에 반영합니다.
7. 긴급 수정은 `hotfix/<name>` 브랜치로 처리합니다.

## Commit message

커밋 메시지는 `COMMIT_CONVENTION.md`를 따릅니다.

예:

```bash
Feat: Add visitor state labels
Docs: Add Git Flow branch strategy
Fix: Correct visitor label position
```
