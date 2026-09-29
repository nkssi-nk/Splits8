# Splits8 — 애플워치 구간 기록 운동 앱

Claude Design 에서 만든 시안(Splits8)을 그대로 옮긴 앱입니다. 애플워치에서 구간별 시간과 심박을 재고, 아이폰에서 기록을 보고 공유합니다.

> 전에 `Splits` 로 설치 설정을 해 두셨다면: 번들 ID가 `com.exorenal.splits8` 로 바뀌었습니다. 새 저장소에 올린 뒤 **6번(처음 설정)** 과 **7번(앱 등록)** 만 다시 하면 됩니다. 비밀값 4개는 그대로 복사해 넣으면 됩니다.

## 들어 있는 기능

**애플워치**
- 홈: Training / Full Simulation / Race 세 가지
- Training: 아이폰에서 만든 프로그램 목록 + 워치에서 바로 만드는 Quick training
- 운동 중: 큰 구간 시간, 목표(또는 최고 기록) 대비, 러닝 페이스, 심박·존 색, 다음 구간 버튼 (손가락 두 번 톡톡도 됨, watchOS 11 이상)
- 옆으로 밀면 끝내기 / 일시정지 / 다음, 구간 목록
- 끝나면 요약 화면, 건강 앱에 저장, 아이폰으로 자동 전송

**아이폰**
- 처음 실행: 체급, 심박 존, 워치 연결 (계정 없이 바로 시작)
- Training: 프로그램 만들기·고치기, 기록
- Full Simulation: 기록 변화 그래프 (Total / Run avg / Roxzone / 스테이션 8개), 목표·지난번·친구와 비교
- Race: 목표 시간과 최고 기록 비교, 대회 찾기(다가오는 대회 목록)·직접 입력, 친구 순위표, 기록
- 기록 상세: 심박 그래프, 존별 시간, 러닝 페이스, 구간 기록, 친구와 비교
- 공유: 사진 위에 기록 올리기 (Poster / Ticket / Block, 스토리·게시물 비율) → Instagram / 사진 저장
- Settings: 프로필(사진·닉네임·체급·심박), 러닝 방식, 구간 목표, 친구
- 계정(선택): 이메일 코드 또는 Apple 로그인. 친구 추가·순위표에만 필요하고, 나머지는 계정 없이 다 됩니다.

---

## 계정·친구 기능 켜기 (선택 · Supabase)

계정, 친구, 순위표, 대회 목록 갱신은 **Supabase**(무료)에 저장됩니다. 이 설정을 안 하면 앱에서 "Sign up"을 눌렀을 때 "서버 설정이 아직 없어요"라고 나오고, 나머지 기능은 모두 정상입니다. 나중에 해도 됩니다.

1. https://supabase.com 가입 → **New project** (이름 `splits8`, 지역 Northeast Asia(Seoul))
2. 왼쪽 **SQL Editor** → `supabase/schema.sql` 파일 내용을 통째로 붙여 넣고 **Run**
3. **Authentication → Providers → Email**: "Confirm email" 끄고, **Email OTP** 켜기
4. (Apple 로그인도 쓰려면) **Authentication → Providers → Apple** 켜고, 애플 개발자 사이트의 Services ID·키를 넣기. 어려우면 이메일 코드만 써도 됩니다.
5. **Project Settings → API** 에서 **Project URL** 과 **anon public** 키를 복사해 `iOSApp/Config.swift` 의 두 줄에 붙여 넣기
6. 코드를 GitHub에 올리면 빌드가 다시 돌아갑니다.

Instagram 스토리로 바로 보내려면 Meta 개발자 앱 ID가 필요합니다 (`Config.swift` 의 `facebookAppID`). 비워 두면 "Instagram" 버튼이 iOS 공유 창을 열고, 거기서 Instagram을 고르면 됩니다.

---

## 설치 방법 (맥 없이, 처음 한 번만)

전체 순서: **애플 개발자 등록 → 키 2개 만들기 → GitHub에 올리기 → 자동 빌드 → TestFlight로 설치**

### 1. 애플 개발자 등록
- https://developer.apple.com/programs/ 에서 가입 (1년 99달러). 승인까지 보통 하루~이틀 걸립니다.

### 2. App Store Connect API 키 만들기
1. https://appstoreconnect.apple.com → **사용자 및 액세스** → **통합** 탭 → **App Store Connect API** → **팀 키**
2. **+** 누르고 이름 `github`, 액세스 **관리(Admin)** 선택 → 생성
3. 다음 3가지를 메모합니다.
   - **Issuer ID** (페이지 위쪽)
   - **키 ID** (만든 키 옆)
   - **API 키 다운로드** → `AuthKey_XXXX.p8` 파일 (한 번만 받을 수 있으니 잘 보관)

### 3. 인증서용 키 만들기 (윈도우)
PowerShell을 열고 아래를 그대로 붙여 넣습니다.
```powershell
cd $HOME\Desktop
ssh-keygen -t rsa -b 2048 -m PEM -f cert_key -q -N '""'
```
바탕화면에 `cert_key` 파일이 생깁니다. (같이 생긴 `cert_key.pub`는 안 씁니다)

### 4. GitHub에 코드 올리기
1. https://github.com 가입 → https://desktop.github.com 에서 **GitHub Desktop** 설치
2. 받은 `Splits8` 폴더 압축을 풉니다.
3. GitHub Desktop → **File → Add local repository** → `Splits8` 폴더 선택 → "create a repository" 누르기 → **Publish repository** (Keep this code private 체크)

> 비공개 저장소는 맥 빌드 무료 시간이 한 달에 약 200분(빌드 10~15번)입니다. 공개로 하면 제한이 없습니다.

### 5. 비밀값(Secrets) 4개 넣기
GitHub 저장소 페이지 → **Settings → Secrets and variables → Actions → New repository secret**

| 이름 | 값 |
|---|---|
| `APP_STORE_CONNECT_ISSUER_ID` | 2번의 Issuer ID |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | 2번의 키 ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | `AuthKey_XXXX.p8` 파일을 메모장으로 열어 **전체 내용** 복사 |
| `CERTIFICATE_PRIVATE_KEY` | `cert_key` 파일을 메모장으로 열어 **전체 내용** 복사 |

### 5-1. (개발자 등록 전에도 가능) 가상 아이폰으로 화면 먼저 보기
저장소 페이지 → **Actions** 탭 → 왼쪽 **"0. 화면 확인 (스크린샷)"** → **Run workflow**
→ 15~20분 뒤 초록 체크가 뜨면, 그 실행을 눌러 아래 **Artifacts → screenshots** 를 내려받으세요. 앱을 진짜로 만들어 가상 아이폰에서 찍은 화면 30여 장이 들어 있습니다. (비밀값·개발자 등록 없이 GitHub만 있으면 됩니다. 실행할 때마다 맥 서버 시간이 약 20분 쓰입니다.)

### 6. 처음 설정 실행
저장소 페이지 → **Actions** 탭 → 왼쪽 **"1. 처음 설정 (번들 ID 만들기)"** → **Run workflow**
→ 1분 정도 뒤 초록 체크가 뜨면 성공입니다.

### 7. App Store Connect에 앱 등록
https://appstoreconnect.apple.com → **앱** → **+** → **신규 앱**
- 플랫폼: iOS
- 이름: `Splits8` (이미 있는 이름이면 `Splits8 구간기록` 등으로 바꿔도 됩니다. 폰에 보이는 이름은 그대로 Splits8)
- 기본 언어: 한국어
- 번들 ID: `com.exorenal.splits8` 선택
- SKU: `splits8`

### 8. 빌드 + TestFlight 업로드
**Actions** 탭 → **"2. 빌드 + TestFlight 업로드"** → **Run workflow**
→ 15~20분 걸립니다. 이후에는 코드를 올릴 때마다 자동으로 실행됩니다.

### 9. 아이폰·워치에 설치
1. App Store Connect → 앱 → **TestFlight** 탭 → 빌드가 "처리 중"에서 끝날 때까지 기다림 (10~30분)
2. **내부 테스트** 옆 **+** → 그룹 만들기 → 본인 이메일 추가
3. 아이폰에 **TestFlight** 앱 설치 → 초대 수락 → **설치**
4. 워치 앱: 아이폰의 **Watch** 앱 → 아래로 내려 **Splits8** → **설치** (자동 설치가 켜져 있으면 알아서 설치됨)
5. 워치에서 처음 열 때 **건강 데이터 권한**을 모두 허용

---

## 문제가 생기면
Actions에서 빨간 X가 뜨면, 그 실행을 눌러 빨간 단계의 로그를 복사해서 Claude에게 보내 주세요. 고쳐 드립니다.

## 파일 구조
```
Shared/     아이폰·워치 공통 (색·글꼴, 데이터 모델, 체급표, 구간 순서)
WatchApp/   애플워치 앱 (홈, Quick training, 운동 중 화면, 요약)
iOSApp/     아이폰 앱 (Training, Full Simulation, Race, Settings, 기록 상세, 공유 이미지)
Resources/  앱 아이콘(S8), 구간 아이콘, 시작 화면 사진
supabase/   서버 테이블 설정 (schema.sql) — 계정·친구 기능을 쓸 때만
project.yml Xcode 프로젝트 설정 (번들 ID는 여기 APP_BUNDLE_ID 한 줄)
.github/    클라우드 빌드 설정
```
