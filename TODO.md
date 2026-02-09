# 작업 진행 상황 및 남은 작업

## ✅ 완료된 작업

1. **Flutter 프로젝트 생성 완료**
   - 기본 구조 생성
   - 모든 필요한 패키지 설치
   - Windows 플랫폼 지원 추가

2. **주요 기능 구현 완료**
   - Task, Birthday 데이터 모델
   - SQLite 데이터베이스 (sqflite_common_ffi 사용)
   - 음력 변환 서비스 (lunar 패키지)
   - 로컬 알림 서비스
   - Provider 상태 관리

3. **UI 화면 구현 완료**
   - 홈 화면 (할 일 목록)
   - 할 일 추가/수정 화면
   - 캘린더 화면
   - 생일 관리 화면

4. **문제 해결 완료**
   - lunar 패키지 1.7.8 API 호환성 문제 해결
   - Windows 데스크톱 데이터베이스 초기화 문제 해결
   - 앱 Windows 모드 실행 성공 확인

## 🚧 진행 중인 작업

### 시간 설정 기능 추가 (현재 작업)

**완료된 부분:**
- ✅ Task 모델에 scheduledHour, scheduledMinute 필드 추가
- ✅ toMap, fromMap, copyWith 메서드 업데이트

**남은 작업:**

1. **Task 모델 완성**
   - `lib/models/task.dart`에 시간 포맷팅 헬퍼 메서드 추가:
   ```dart
   String getScheduledTimeText() {
     final hour = scheduledHour.toString().padLeft(2, '0');
     final minute = scheduledMinute.toString().padLeft(2, '0');
     return '$hour:$minute';
   }
   ```

2. **데이터베이스 스키마 업데이트**
   - `lib/services/database_service.dart` 수정 필요
   - _createDB 메서드에 scheduledHour, scheduledMinute 컬럼 추가:
   ```dart
   await db.execute('''
     CREATE TABLE tasks (
       id $idType,
       title $textType,
       description $textTypeNullable,
       frequency $intType,
       dayOfMonth INTEGER,
       scheduledHour $intType DEFAULT 9,
       scheduledMinute $intType DEFAULT 0,
       adjustForHolidays $intType,
       isLunar $intType,
       reminderInterval $intType,
       isCompleted $intType,
       completedAt $textTypeNullable,
       createdAt $textType,
       dueDate $textTypeNullable
     )
   ''');
   ```
   - 또는 데이터베이스 버전 업그레이드 처리 (migration)

3. **할 일 추가/수정 화면 업데이트**
   - `lib/screens/add_task_screen.dart` 수정
   - 시간 선택 UI 추가:
     - TimeOfDay 변수 추가
     - TimePicker 위젯 추가
     - 선택된 시간 표시

   예시 코드:
   ```dart
   TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

   // UI에 추가:
   ListTile(
     leading: const Icon(Icons.access_time),
     title: const Text('시간'),
     subtitle: Text('${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}'),
     onTap: () async {
       final time = await showTimePicker(
         context: context,
         initialTime: _selectedTime,
       );
       if (time != null) {
         setState(() {
           _selectedTime = time;
         });
       }
     },
   )

   // Task 생성 시:
   scheduledHour: _selectedTime.hour,
   scheduledMinute: _selectedTime.minute,
   ```

4. **TaskItem 위젯 업데이트**
   - `lib/widgets/task_item.dart` 수정
   - 시간 표시 추가:
   ```dart
   Text(
     '${task.getScheduledTimeText()}',
     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
   )
   ```

5. **알림 서비스 업데이트**
   - `lib/services/notification_service.dart` 수정
   - 특정 시간에 알림 스케줄링:
   ```dart
   Future<void> scheduleTaskReminder(Task task) async {
     if (task.isCompleted) return;

     final now = tz.TZDateTime.now(tz.local);
     var scheduledDate = tz.TZDateTime(
       tz.local,
       now.year,
       now.month,
       now.day,
       task.scheduledHour,
       task.scheduledMinute,
     );

     // 오늘 시간이 지났으면 내일로
     if (scheduledDate.isBefore(now)) {
       scheduledDate = scheduledDate.add(const Duration(days: 1));
     }

     // 매일 반복이면 daily로 스케줄
     if (task.frequency == TaskFrequency.daily) {
       await flutterLocalNotificationsPlugin.zonedSchedule(
         int.parse(task.id ?? '0'),
         '할 일 알림',
         task.title,
         scheduledDate,
         platformDetails,
         androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
         uiLocalNotificationDateInterpretation:
             UILocalNotificationDateInterpretation.absoluteTime,
         matchDateTimeComponents: DateTimeComponents.time, // 매일 같은 시간
       );
     }
   }
   ```

6. **데이터베이스 마이그레이션**
   - 기존 데이터가 있다면 migration 필요
   - 또는 앱 재설치 후 테스트

## 📝 추가 개선 사항 (선택사항)

1. **알림 고도화**
   - 완료하지 않았을 때만 주기적 알림
   - 스누즈 기능
   - 알림음 설정

2. **UI/UX 개선**
   - 다크 모드
   - 테마 색상 변경
   - 애니메이션 추가

3. **추가 기능**
   - 할 일 카테고리/태그
   - 통계 화면
   - 백업/복원 기능
   - 위젯 추가

## 🔧 테스트 방법

수정 후 실행:
```bash
cd /mnt/c/AI/make_dev/app/daily_task_reminder
cmd.exe /c "flutter pub get"
cmd.exe /c "flutter run -d windows"
```

## 🐛 알려진 이슈

1. 데이터베이스에 새 컬럼 추가 시 기존 DB와 충돌 가능
   - 해결: 앱 데이터 삭제 후 재실행 또는 migration 구현

2. 음력 윤달 기능 간소화됨
   - 필요시 lunar 패키지 최신 API 문서 참고하여 개선

## 📂 프로젝트 구조

```
daily_task_reminder/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── task.dart          ✏️ 수정 중 (시간 필드 추가 완료)
│   │   └── birthday.dart
│   ├── providers/
│   │   └── task_provider.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── add_task_screen.dart  ⏭️ 다음 수정 필요
│   │   ├── calendar_screen.dart
│   │   └── birthday_screen.dart
│   ├── services/
│   │   ├── database_service.dart  ⏭️ 다음 수정 필요
│   │   ├── notification_service.dart  ⏭️ 다음 수정 필요
│   │   └── lunar_service.dart
│   └── widgets/
│       └── task_item.dart  ⏭️ 다음 수정 필요
├── pubspec.yaml
└── README.md
```

## 🎯 다음 작업 순서

1. Task 모델에 getScheduledTimeText() 메서드 추가
2. database_service.dart 스키마 업데이트
3. add_task_screen.dart에 시간 선택 UI 추가
4. task_item.dart에 시간 표시 추가
5. notification_service.dart 알림 스케줄링 로직 수정
6. 테스트 및 버그 수정

---
**마지막 업데이트:** 2026-02-03
**현재 상태:** Task 모델 수정 완료, UI 수정 대기 중
