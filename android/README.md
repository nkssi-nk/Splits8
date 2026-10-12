# SPLITS8 안드로이드

아이폰 앱과 같은 기능 · 같은 서버(Supabase) · 같은 규칙. 아이폰 파일(저장소 맨 위 폴더들)과 섞지 않고 이 폴더 안에서만 작업합니다.

| 폴더 | 내용 | 아이폰 쪽 짝 |
|---|---|---|
| `shared/` | 규칙 · 데이터 (디비전, 스테이션, 기록 판정, 목표 나누기 …) | `Shared/` |
| `app/` | 폰 앱 | `iOSApp/` |
| `wear/` | 갤럭시 워치 (Wear OS) 앱 | `WatchApp/` |

- 앱 이름(applicationId): 폰 · 워치 모두 `com.nkssi.splits8`
- 최소 버전: 폰 Android 10, 워치 Wear OS 4
- 글꼴: Pretendard (SIL Open Font License 1.1, 무료 · 앱에 넣어 배포 가능)

## PC 에서 열기

Android Studio → Open → 이 `android` 폴더 선택 → 위쪽 실행 목록에서 `app`(폰) 또는 `wear`(워치) 고르고 ▶.

## GitHub

`android/` 가 바뀌면 "A1. 안드로이드 빌드" 만 돕니다. 아이폰 TestFlight 빌드는 돌지 않습니다.
