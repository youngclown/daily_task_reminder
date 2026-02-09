# 할 일 관리 앱 (Daily Task Reminder)

Flutter로 개발된 할 일 관리 애플리케이션입니다.

## 주요 기능

### 1. 할 일 관리
- **매일 반복**: 매일 해야 하는 일 등록
- **매월 특정 날짜**: 매월 특정 날짜에 해야 하는 일 등록
- **음력 지원**: 음력 날짜로 할 일 등록 가능
- **공휴일 조정**: 주말(토/일)이면 평일(금/월)로 자동 조정

### 2. 푸시 알림
- 완료하지 않은 할 일에 대해 주기적 알림
- 알림 간격 설정 가능 (10분, 30분, 1시간)
- 완료 시 자동으로 알림 중단

### 3. 캘린더
- 월간 캘린더로 할 일 확인
- 음력/양력 날짜 표시
- 날짜별 할 일 및 생일 확인

### 4. 생일 관리
- 중요한 사람들의 생년월일 저장
- 음력 생일 지원
- D-day 및 나이 자동 계산
- 생일 알림

## 설치 및 실행

### 필요 사항
- Flutter SDK 3.0.0 이상
- Android Studio 또는 VS Code
- Android SDK (API 21 이상)

### 설치

1. 저장소 클론 또는 프로젝트 다운로드

2. 의존성 패키지 설치
```bash
cd daily_task_reminder
flutter pub get
```

3. Android 빌드 (선택사항)
```bash
flutter build apk --release
```

4. 앱 실행
```bash
flutter run
```

## 사용된 주요 패키지

- **provider**: 상태 관리
- **sqflite**: 로컬 데이터베이스
- **flutter_local_notifications**: 푸시 알림
- **lunar**: 음력 변환
- **table_calendar**: 캘린더 UI
- **flutter_slidable**: 스와이프 액션

## 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── models/                   # 데이터 모델
│   ├── task.dart
│   └── birthday.dart
├── providers/                # 상태 관리
│   └── task_provider.dart
├── screens/                  # 화면
│   ├── home_screen.dart
│   ├── add_task_screen.dart
│   ├── calendar_screen.dart
│   └── birthday_screen.dart
├── services/                 # 서비스
│   ├── database_service.dart
│   ├── notification_service.dart
│   └── lunar_service.dart
└── widgets/                  # 재사용 위젯
    └── task_item.dart
```

## 사용 방법

### 할 일 추가
1. 홈 화면에서 + 버튼 클릭
2. 제목 입력
3. 반복 주기 선택 (매일/매월)
4. 매월 선택 시:
   - 날짜 선택 (1-31일)
   - 음력 사용 여부 선택
   - 공휴일 조정 여부 선택
5. 알림 간격 선택 (10분/30분/1시간)
6. 추가 버튼 클릭

### 할 일 완료
- 할 일 항목의 체크박스를 클릭하여 완료 표시
- 완료 시 알림이 자동으로 중단됨

### 할 일 수정/삭제
- 할 일 항목을 왼쪽으로 스와이프
- 파란색 "수정" 버튼: 할 일 수정
- 빨간색 "삭제" 버튼: 할 일 삭제

### 생일 추가
1. 하단 탭에서 "생일" 선택
2. + 버튼 클릭
3. 이름, 생년월일 입력
4. 음력 생일 여부 선택
5. 메모 입력 (선택사항)
6. 추가 버튼 클릭

## 알림 권한

앱 첫 실행 시 알림 권한을 허용해야 푸시 알림을 받을 수 있습니다.

**Android 13 이상**: 설정 > 앱 > 할 일 관리 > 알림에서 권한 허용

## 기술적 특징

- **Material Design 3**: 최신 디자인 가이드라인 적용
- **로컬 저장소**: SQLite를 사용한 오프라인 데이터 저장
- **음력 변환**: 정확한 음력-양력 변환 알고리즘
- **백그라운드 알림**: 앱이 꺼져있어도 알림 수신
- **공휴일 처리**: 주말을 평일로 자동 조정

## 문제 해결

### 알림이 오지 않는 경우
1. 알림 권한 확인
2. 배터리 최적화 설정 확인 (설정 > 배터리 > 배터리 최적화에서 앱 제외)
3. 앱을 재시작

### 음력 날짜가 정확하지 않은 경우
- 음력 계산은 lunar 패키지를 사용하며, 1900-2100년 범위에서 정확합니다

## 라이선스

MIT License

## 개발 환경

- Flutter 3.38.7
- Dart 3.0+
- Android SDK 34
