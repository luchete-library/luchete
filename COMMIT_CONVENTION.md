# Commit Convention Guide

## 1. Commit 메시지 구조

기본적인 커밋 메시지 구조는 제목, 본문, 꼬리말 세 가지 파트로 나누고, 각 파트는 빈줄을 두어 구분한다.

```
type : subject

body 

footer
```

## 2. Commit Type

타입은 태그와 제목으로 구성되고, 태그는 영어로 쓰되 첫 문자는 대문자로 한다.

태그 : 제목의 형태이며, `:` 뒤에만 space가 있음에 유의한다.

| Type | Description |
|------|-------------|
| `Feat` | 새로운 기능 추가 |
| `Fix` | 버그 수정 |
| `Docs` | 문서 수정 |
| `Style` | 코드 포맷팅, 세미콜론 누락, 코드 변경이 없는 경우 |
| `Refactor` | 코드 리팩토링 |
| `Test` | 테스트 코드, 리팩토링 테스트 코드 추가 |
| `Chore` | 빌드 업무 수정, 패키지 매니저 수정 |

## 3. Subject

- 제목은 최대 50글자가 넘지 않도록 함
- 마침표 및 특수기호는 사용하지 않음
- 영문으로 표기하는 경우 동사(원형)를 가장 앞에 두고 첫 글자는 대문자로 표기 (과거 시제 사용 금지)
  - ❌ Fixed, Added, Modified
  - ✅ Fix, Add, Modify
- 제목은 개조식 구문으로 작성 (완전한 서술형 문장이 아니라, 간결하고 요점적인 서술)

## 4. Body

- 본문은 한 줄 당 72자 내로 작성
- 본문 내용은 양에 구애받지 않고 최대한 상세히 작성
- 본문 내용은 어떻게 변경했는지보다 무엇을 변경했는지 또는 왜 변경했는지를 설명

## 5. Footer

꼬리말은 optional이며 이슈 트래커 ID를 작성한다.

- 꼬리말은 `유형: #이슈 번호` 형식으로 사용
- 여러 개의 이슈 번호를 적을 때는 쉼표(`,`)로 구분

**이슈 트래커 유형:**
- `Fixes` : 이슈 수정중 (아직 해결되지 않은 경우)
- `Resolves` : 이슈를 해결했을 때 사용
- `Ref` : 참고할 이슈가 있을 때 사용
- `Related to` : 해당 커밋에 관련된 이슈번호 (아직 해결되지 않은 경우)

**예시:**
```
Fixes: #45
Related to: #34, #23
Resolves: #123
Ref: #456
```

## 6. Commit 예시

```
Feat: Implement user registration feature

Develop SMS and email verification API for user signup process.
Integrate third-party SMS service for OTP verification.
Add validation for email and phone number formats.

Resolves: #123
Ref: #456
Related to: #48, #45
```

## 7. Commit Message Emoji

자주 사용되는 이모지 리스트:

| Emoji | Description |
|-------|-------------|
| 🎨 | 코드의 형식 / 구조를 개선할 때 |
| 📰 | 새 파일을 만들 때 |
| 📝 | 사소한 코드 또는 언어를 변경할 때 |
| 🐎 | 성능을 향상시킬 때 |
| 📚 | 문서를 쓸 때 |
| 🐛 | 버그 reporting할 때, @FIXME 주석 태그 삽입 |
| 🚑 | 버그를 고칠 때 |
| 🔥 | 코드 또는 파일 제거할 때, @CHANGED주석 태그와 함께 |
| 🚜 | 파일 구조를 변경할 때, 🎨과 함께 사용 |
| 🔨 | 코드를 리팩토링할 때 |
| 💄 | UI / style 개선시 |
| ♿ | 접근성을 향상시킬 때 |
| 🚧 | WIP (진행중인 작업)에 커밋, @REVIEW주석 태그와 함께 사용 |
| 💎 | New Release |
| 🔖 | 버전 태그 |
| ✨ | 새로운 기능을 소개할 때 |
| ⚡ | 이전 버전과 호환되지 않는 특징 도입, @CHANGED주석 태그 사용 |
| 💡 | 새로운 아이디어, @IDEA주석 태그 |
| 🚀 | 배포 / 개발 작업과 관련된 모든 것 |

## 사용 예시

```bash
# 기본 커밋
git commit -m "Feat: Add player movement system"

# 이모지 포함
git commit -m "✨ Feat: Add player movement system"

# 자세한 커밋 (본문 포함)
git commit  # 편집기가 열리면 작성
```
