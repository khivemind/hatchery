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

<4/13 전체 작업 내용>
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

<4/14 전체 작업 내용>

구분	작업	내용
image_url 연동	푸시 알림 수신 시 AI 분석 이미지 상세화면 표시
onTokenRefresh 자동 갱신	토큰 갱신 시 모든 벌통 자동 재등록
연동	벌통 CRUD	register / unregister / update / getDevices 연동
프로젝트 교체	overlord-5076b로 교체
탐지 로그 날짜 포맷	월/일 시:분 형식으로 변경
전체 폰트 스케일	textScaleFactor: 1.15 전체 적용
조치완료 버튼	알림 배너 탭 → 상세화면 이동
 앱 아이콘	골드 벌집 패턴 아이콘 제작 및 적용
스플래시 화면	벌집 핑 애니메이션 구현
시퀀스 다이어그램	draw.io용 전체 시스템 흐름 XML 작성

<4/15 전체 작업 내용>

인수인계서 작성 및 Claude 학습
draw.io 시퀀스 다이어그램 (전체 시스템 흐름)	
FCM 토큰 자동갱신 로직 추가 (onTokenRefresh)	
안드로이드 폰 실기기 테스트 환경 세팅	
flutter run --release 로 앱 설치	
FCM background/terminated 수신 처리 추가	

<4/16 전체 작업 내용>
FCM 토큰 자동갱신 로직 (onTokenRefresh) 안정화	
fcm_service.dart deleteToken() 제거 (토큰 불안정 원인 제거)
_handleFcmMessage 함수 분리 및 공통화	
안드로이드 실기기 연결 및 테스트 환경 세팅	및 설치
/v1/predictions 서버 연동 (탐지 로그 재시작 후 유지)	
from_time/to_time 파라미터 형식 수정 (밀리초 제거)	
_loadDevices 로컬 상태 유지 로직 개선 (새로고침 시 isAlert 등 보존)	
드래그 새로고침 (RefreshIndicator) 추가	
벌통 이름 5글자 / 구역 이름 7글자 제한 + 경고 다이얼로그	
전체 탐지 로그 보기 (bottomSheet + 서버 실시간 조회)	
버튼 눌림 효과 (_PressableButton, AnimatedScale 0.95)	
알림 배너 깜빡임 애니메이션 (ColorTween kRed ↔ 0xFF8B0000)	
AI 예측 화면 테두리 펄스 애니메이션 (TickerProviderStateMixin)	
조치완료 버튼 하단 고정 + 골드 배경으로 변경	
구역 삭제 시 소속 벌통 서버 일괄 해제	
PopScope로 안드로이드 뒤로가기 버튼 result 반환	
_loadDevices 완료 후 FCM 토큰 자동 재등록	
앱 아이콘 교체 (골드 벌집 + 빨간 핑 디자인)	
FCM data-only 전환 (서버팀 반영 완료)	
foreground FCM 수신 문제 디버깅	🔴 미해결

<4/17 전체 작업 내용>
1. FCM 버그 해결 
FirebaseMessaging.onMessage.listen(_handleFcmMessage) 추가
onMessageOpenedApp, getInitialMessage 추가
flutter run --release로 실기기 테스트 완료

2. 기타 앱 수정

탐지 로그 시간 버그 수정 (DateTime.parse(fixedTime).toLocal())
구역 탭 슬라이딩 적용 (SingleChildScrollView)
앱 이름 변경 (AndroidManifest.xml)

3. 분류 모델 탐색

멜 스펙트로그램으로 Bee/Hornet 시각적 차이 확인
MFCC + Spectral Contrast + 멜 스펙트로그램 피처 추출 방향 설정
CNN → 랜덤 포레스트 전환 시도 (보류)

<4/20 전체 작업 내용>
1. 장치 상태 변경(벌통 감지 ON/OFF) API 연동 성공
기존 문제: PATCH 메서드로 데이터를 보낼 때 Body에 담아 보냈더니 서버에서 인식은 하지만 앱에서는 계속 '실패' 팝업이 뜸.
원인 분석: API 문서를 재검토한 결과, is_enabled 값을 Body가 아닌 Query Parameter(?is_enabled=true)로 보내야 한다는 점을 발견함.
해결: ApiService.dart에서 Uri.replace를 사용해 주소 뒤에 파라미터를 붙이는 방식으로 수정하여 통신 성공(Status Code 200).

2. 개발 환경 메모리 최적화 컨설팅
현황: 메모리 사용량이 87%까지 치솟아 시스템 과부하 발생 (qemu-system, OpenJDK, Chrome이 주범).

조치 사항:
안드로이드 에뮬레이터 대신 실제 기기(Physical Device) 사용 권장.
크롬 '메모리 절약 모드' 활성화 및 안쓰는 탭 정리.
VS Code '작업 관리자'를 통한 무거운 확장 프로그램 식별 및 'Profile' 기능을 활용한 가벼운 환경 설정 제안.

3. 모델 성능 향상을 위한 전략 수립
이슈: 학습 정확도는 100%에 가깝지만 실전 데이터 예측(Prediction) 성능이 떨어지는 '과적합' 의심 상황.
대안: 꿀벌의 스트레스 반응(화난 날갯짓 소리)을 1차로 감지하고 말벌을 2차로 확인하는 '2중 계층적 분류(Hierarchical Classification)' 아이디어 구체화 및 학습 데이터 수집처 확보.
