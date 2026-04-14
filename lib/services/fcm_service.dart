import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class FcmService {
  static const String _serverUrl = 'http://34.81.221.132:8000';
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init(String deviceId) async {
    // 1. 알림 권한 요청
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('[FCM] 알림 권한 거부됨');
      return;
    }

    await FirebaseMessaging.instance.deleteToken();
    await Future.delayed(Duration(seconds: 1));
    // 2. FCM 토큰 가져오기
    String? token = await _fcm.getToken();

    if (token == null) {
      print('[FCM] 토큰 없음');
      return;
    }
    print('[FCM] 토큰: $token');

    // 3. 서버에 등록
    await _registerDevice(deviceId: deviceId, appToken: token);

    // 4. 토큰 갱신 시 자동 재등록
    _fcm.onTokenRefresh.listen((newToken) {
      _registerDevice(deviceId: deviceId, appToken: newToken);
    });

    // 5. 포그라운드 메시지 수신
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCM] 포그라운드 메시지: ${message.notification?.title}');
      // TODO: 앱 내 알림 UI 표시 (예: flutter_local_notifications)
    });

    // 6. 알림 클릭 시 (백그라운드 → 앱 열기)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final imageUrl = message.data['image_url'];
      final deviceId = message.data['device_id'];
      print('[FCM] 알림 클릭: device=$deviceId, image=$imageUrl');
      // TODO: 해당 예측 상세 화면으로 이동
    });
  }

  Future<void> _registerDevice({
    required String deviceId,
    required String appToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/v1/register-device').replace(
          queryParameters: {
            'device_id': deviceId,
            'user_id': deviceId, // 지금은 device_id = user_id
            'app_token': appToken,
            'device_name': '벌통 $deviceId',
          },
        ),
      );

      if (response.statusCode == 200) {
        print('[FCM] 디바이스 등록 성공');
      } else {
        print('[FCM] 디바이스 등록 실패: ${response.body}');
      }
    } catch (e) {
      print('[FCM] 디바이스 등록 에러: $e');
    }
  }
}
