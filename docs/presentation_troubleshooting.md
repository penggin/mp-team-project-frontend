# 발표용 트러블슈팅 정리: 백그라운드 결제 처리

이 문서는 발표에서 사용할 수 있도록 백그라운드 결제 처리 과정에서 겪은 핵심 트러블슈팅 3가지를 정리한 자료입니다. 각 항목은 `증상 -> 원인 -> 해결 -> 발표 포인트` 흐름으로 설명할 수 있게 구성했습니다.

## 전체 흐름

이번 프로젝트의 결제 자동 처리 기능은 단순히 알림 텍스트를 읽는 기능이 아니라, 앱이 백그라운드에 있거나 Flutter 엔진이 완전히 준비되지 않은 상황에서도 결제 이벤트를 놓치지 않고 처리해야 했습니다.

발표에서는 다음 흐름으로 설명하면 자연스럽습니다.

1. Android 백그라운드 환경에서는 Flutter/Dart만으로 모든 OS 이벤트를 안정적으로 받을 수 없었다.
2. 그래서 일부 이벤트 수신은 Kotlin 네이티브 레이어가 먼저 담당하도록 했다.
3. 백그라운드 isolate에서는 Flutter 플러그인 초기화 문제가 발생해 별도 대응이 필요했다.
4. 마지막으로 백그라운드 요청에서도 인증 토큰 생명주기를 관리하도록 API 요청 구조를 중앙화했다.

## 1. Flutter 백그라운드 서비스와 Kotlin 네이티브 브리지

### 문제 상황

초기에는 Flutter에서 결제 관련 SMS나 알림 이벤트를 직접 받아 처리하려고 했습니다. 하지만 Android에서는 앱이 꺼져 있거나 Flutter 엔진이 아직 준비되지 않은 상태에서도 OS 이벤트가 먼저 도착할 수 있습니다.

이 경우 Dart 코드만으로는 이벤트를 즉시 받을 수 없거나, 앱이 다시 켜진 뒤에야 확인할 수 있어 결제 이벤트를 놓칠 위험이 있었습니다.

### 증상

- 앱을 실행하지 않은 상태에서 테스트하면 이벤트가 Flutter 쪽으로 바로 들어오지 않음
- 앱 프로세스가 살아 있지 않으면 Dart 리스너가 호출되지 않음
- 테스트 스크립트에서 백그라운드 감지 로그가 나타나지 않거나 지연됨
- 수신 이벤트를 나중에 복구할 방법이 없으면 결제 처리가 누락될 수 있음

### 원인

Flutter의 Dart 코드는 Flutter 엔진과 isolate가 떠 있어야 실행됩니다. 반면 Android의 SMS 수신 같은 OS 브로드캐스트는 네이티브 레벨에서 먼저 발생합니다.

즉, 이벤트 발생 시점과 Dart 런타임 준비 시점이 항상 일치하지 않습니다.

### 해결

Android 네이티브 Kotlin 레이어에서 먼저 이벤트를 받아 안전하게 저장한 뒤, Flutter가 준비되면 MethodChannel로 전달하도록 구조를 나눴습니다.

구현 구조:

- `android/app/src/main/kotlin/com/example/first/SmsReceiver.kt`
  - Android `BroadcastReceiver`
  - SMS 수신 이벤트를 네이티브에서 먼저 감지
  - sender, body, receivedAt, id를 이벤트 객체로 구성
- `android/app/src/main/kotlin/com/example/first/SmsEventStore.kt`
  - pending 이벤트를 로컬 저장소에 임시 보관
  - Flutter가 아직 준비되지 않았을 때도 이벤트 유실을 줄임
- `android/app/src/main/kotlin/com/example/first/MainActivity.kt`
  - MethodChannel 등록
  - Flutter 쪽에서 pending 이벤트 조회와 ack 처리를 할 수 있게 연결
- `lib/services/sms_event_service.dart`
  - Dart 쪽 이벤트 서비스
  - pending 이벤트 replay
  - 처리 완료 후 ack

### 발표 포인트

핵심 메시지는 다음과 같습니다.

> OS 이벤트 수신은 네이티브가 먼저 안정적으로 잡고, 결제 파싱과 저장 같은 비즈니스 로직은 Flutter가 담당하도록 역할을 분리했습니다.

이렇게 설명하면 단순히 "Kotlin을 추가했다"가 아니라, Android 백그라운드 생명주기 문제를 해결하기 위한 설계 선택이었다는 점이 잘 드러납니다.

### 배운 점

- Flutter는 UI와 비즈니스 로직을 빠르게 만들기 좋지만, OS 생명주기와 직접 맞닿는 이벤트는 네이티브 보강이 필요할 수 있습니다.
- 백그라운드 기능은 "앱이 켜져 있을 때"가 아니라 "앱이 준비되지 않았을 때"를 기준으로 설계해야 합니다.
- 이벤트를 바로 처리하지 못하더라도 일단 저장해두고 replay할 수 있는 구조가 중요합니다.

## 2. 백그라운드 알림 처리 중 MissingPluginException 발생

### 문제 상황

백그라운드에서 결제 알림을 감지하고 가계부 저장까지 성공한 뒤, 사용자에게 "결제 내역이 저장됐다"는 알림을 보내려고 했습니다.

하지만 Flutter local notification 플러그인을 백그라운드 isolate에서 호출하는 과정에서 플러그인 초기화 문제가 발생했습니다.

### 실제 로그 예시

```text
백그라운드 결제 처리 알림 전송 실패:
MissingPluginException(No implementation found for method initialize on channel dexterous.com/flutter/local_notifications)
```

### 증상

- 결제 파싱과 가계부 저장은 성공함
- 하지만 사용자에게 보여줄 로컬 알림은 뜨지 않음
- 백그라운드 로그에 `MissingPluginException`이 출력됨

### 원인

Flutter의 백그라운드 작업은 메인 UI isolate와 다른 isolate에서 실행됩니다. 메인 화면에서는 정상 동작하는 플러그인도 백그라운드 isolate에서는 자동으로 등록되어 있지 않을 수 있습니다.

특히 `flutter_local_notifications` 같은 플러그인은 네이티브 채널을 사용하므로, 백그라운드에서 호출하려면 플러그인 등록과 초기화 순서를 신경 써야 합니다.

### 해결

백그라운드 시작 지점에서 플러그인 등록을 보장하도록 처리했습니다.

관련 구현:

- `lib/background_task_handler.dart`
  - `startCallback()`에서 `DartPluginRegistrant.ensureInitialized()` 호출
  - 백그라운드 task handler 등록
- `lib/services/payment_push_notification_service.dart`
  - 결제 저장 완료 알림 로직 분리
  - foreground service notification 업데이트와 사용자 표시용 로컬 알림을 한 서비스에서 관리
  - 알림 권한 요청과 local notification 초기화 담당

### 발표 포인트

핵심 메시지는 다음과 같습니다.

> Flutter 플러그인은 백그라운드 isolate에서 자동으로 준비된다고 가정하면 안 됩니다. 백그라운드 진입점에서 플러그인 등록과 초기화를 명시적으로 다뤄야 했습니다.

### 배운 점

- Flutter 백그라운드 코드는 메인 화면 코드와 실행 환경이 다릅니다.
- "메인 화면에서 되는 플러그인"이 "백그라운드에서도 되는 플러그인"이라는 보장은 없습니다.
- 백그라운드 기능은 실제 기기 로그로 검증해야 합니다.

## 3. 백그라운드 인증 만료 반복 문제

### 문제 상황

백그라운드 서비스가 결제 알림을 감지하고 API를 호출하려면 access token이 필요합니다. 그런데 재로그인을 해도 백그라운드에서 계속 인증 만료 로그가 반복되는 문제가 있었습니다.

### 실제 로그 예시

```text
백그라운드 인증 만료: 다시 로그인이 필요합니다
백그라운드 인증 만료: 다시 로그인이 필요합니다
백그라운드 인증 만료: 다시 로그인이 필요합니다
```

### 증상

- 사용자가 재로그인했는데도 백그라운드 서비스는 인증 만료로 판단
- 결제 알림은 감지되지만 parser 또는 ledger 저장 요청이 진행되지 않음
- 백그라운드 로그에 authExpired 신호가 반복됨

### 원인

인증 토큰 관리가 여러 요청 함수에 흩어져 있으면 다음 문제가 생깁니다.

- access token 만료 여부를 요청마다 일관되게 확인하기 어려움
- refresh token 만료 시점을 놓칠 수 있음
- refresh token 수명이 얼마 남지 않았을 때 선제 갱신이 어려움
- 백그라운드 isolate에서 SharedPreferences 캐시가 최신 로그인 상태를 반영하지 못할 수 있음

즉, UI 요청과 백그라운드 요청이 같은 인증 규칙을 공유하지 못하는 것이 문제였습니다.

### 해결

모든 API 요청이 `ApiService.request()`를 거치도록 구조를 중앙화했습니다.

핵심 처리:

- 요청 전 access token 만료 확인
- access token이 만료되었으면 refresh token으로 자동 갱신
- refresh token이 만료되었으면 토큰 삭제 후 재로그인 유도
- refresh token 만료가 가까우면 선제적으로 재발급
- SharedPreferences를 읽을 때 `reload()`로 최신 저장 상태 반영
- 백그라운드에서도 동일한 `ApiService.hasValidToken()` 흐름 사용

관련 구현:

- `lib/services/api_service.dart`
  - `request()`
  - `_ensureTokenLifecycle()`
  - `refreshAccessToken()`
  - `_freshPreferences()`
- `lib/background_task_handler.dart`
  - 백그라운드 반복 이벤트마다 토큰 생명주기 확인
  - 토큰이 유효하지 않으면 메인 UI에 `authExpired` 신호 전달

### 발표 포인트

핵심 메시지는 다음과 같습니다.

> 백그라운드 서비스도 로그인한 사용자 대신 API를 호출하는 클라이언트입니다. 그래서 화면 요청과 동일한 인증 생명주기 관리가 필요했습니다.

### 배운 점

- access token/refresh token 관리는 화면 단위가 아니라 API 계층에서 중앙화해야 합니다.
- 백그라운드 isolate는 저장소 캐시 문제가 생길 수 있으므로 최신 토큰을 다시 읽는 처리가 필요합니다.
- 인증 실패를 조용히 무시하지 말고 UI에 재로그인 신호를 보내야 사용자 복구가 가능합니다.

## 발표용 요약 멘트

발표 마지막에는 아래처럼 정리하면 좋습니다.

> 이번 프로젝트에서 가장 어려웠던 부분은 결제 알림을 파싱하는 로직 자체보다, 모바일 백그라운드 환경에서 이벤트를 안정적으로 받고 Flutter 플러그인을 안전하게 초기화하며 인증 상태까지 유지하는 것이었습니다. 이를 해결하기 위해 네이티브 브리지, Flutter 백그라운드 isolate 초기화, 인증 토큰 중앙화를 순서대로 적용했습니다.

## 한 장짜리 발표 슬라이드 구성 예시

### 문제

- 앱이 꺼져 있거나 백그라운드일 때 결제 이벤트를 놓칠 수 있음
- 백그라운드 isolate에서 플러그인 오류 발생
- 토큰 만료 시 백그라운드 API 요청 실패

### 해결

- Kotlin BroadcastReceiver + pending event replay
- `DartPluginRegistrant.ensureInitialized()`와 알림 서비스 분리
- `ApiService.request()`로 토큰 생명주기 중앙화

### 결과

- 앱 상태와 무관하게 결제 이벤트 처리 안정성 향상
- 백그라운드에서도 인증 갱신 처리 가능
- 발표 가능한 수준의 구조적 개선 사례 확보
