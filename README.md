# hatchery

📋 Hivemind 전체 로드맵
Phase	내용	일정	완료일	상태
Phase 1	Flutter 앱 기본 구조	-	4/8	✅
Phase 2	FCM 푸시 알림	-	4/8	✅
Phase 3	로컬 알림 소리+진동	-	4/9	✅
Phase 4	설정 화면	-	4/9	✅
Phase 5	mic_test.py USB 마이크 → wav → 서버 전송	-	4/9	✅
Phase 6	소문 개폐 서버 연동	서버 팀 대기	-	🔜
Phase 7	실제 서버 /v1/predict 연동	4/10	4/10	✅
Phase 7.5	GitHub 레포 설정 + API 키 분리	4/10	4/10	✅
Phase 7.6	프로그레스 바 추가	4/10	4/10	✅
Phase 7.7	mic_test.py 2초마다 전송 방식 확정	4/13	4/13	✅
Phase 7.8	mic_test.py → FCM 트리거 연동	4/13	4/13	✅
Phase 8	UI 전면 개편 (메인화면, 상태카드, AI예측결과)	4/13	4/13	✅
Phase 8.1	settings_screen 개편 + 다크모드 토글	4/13	4/13	✅
Phase 9	라즈베리파이 연동	4/14~4/16	-	⏳
Phase 10	프론트 디자인 최종 적용	4/17~4/19	-	⏳
Phase 11	최종 마무리 및 발표 준비	4/20~4/23	-	⏳

📋 오늘 한 것 (4/14)
벌통 서버 연동

api_service.dart — registerDevice, unregisterDevice, updateDevice, getDevices 함수 추가
settings_screen.dart — 벌통 수정 다이얼로그 + ✏️ 수정 버튼 추가
벌통 추가/수정/삭제 시 서버 자동 호출 연동
GET /v1/devices?user_id=khivemind — 앱 시작 시 서버에서 벌통 목록 불러오기
main.dart — _loadDevices() 추가
Firebase 교체

google-services.json → 서버 팀 프로젝트(overlord-5076b)로 교체
firebase_options.dart → 새 프로젝트 값으로 교체
Firebase 중복 초기화 에러 수정 (try-catch 처리)
미해결
