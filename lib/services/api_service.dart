import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiService {
  final String baseUrl = 'http://34.81.221.132:8000';
  final String apiKey = Config.apiKey;

  // ───────────────────────── 말벌 감지 예측 ─────────────────────────
  Future<Map<String, dynamic>> predict(int hiveId, String wavBase64) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/predict'),
      headers: {'Content-Type': 'application/json', 'x-api-key': Config.apiKey},
      body: jsonEncode({
        'id': hiveId.toString(),
        'event_time': DateTime.now().toIso8601String(),
        'wav_base64': wavBase64,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('예측 실패: ${response.statusCode}');
    }
  }

  // ───────────────────────── 벌통 목록 조회 ─────────────────────────
  // GET /v1/devices → _groups 구조로 변환해서 반환
  Future<List<Map<String, dynamic>>> getDevices() async {
    try {
      final uri = Uri.parse(
        '$baseUrl/v1/devices',
      ).replace(queryParameters: {'user_id': 'khivemind'});
      final response = await http.get(
        uri,
        headers: {'x-api-key': Config.apiKey},
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final devices = data['devices'] as List;

      // group 기준으로 묶기
      final Map<String, List<Map<String, dynamic>>> groupMap = {};
      for (final device in devices) {
        final groupName = device['group'] as String? ?? '기본 구역';
        groupMap.putIfAbsent(groupName, () => []);
        groupMap[groupName]!.add({
          'id': int.tryParse(device['device_id'] ?? '0') ?? 0,
          'name': device['device_name'] ?? '',
          'cctvUrl': '',
          'raspberryPiIp': '',
          'isAlert': false,
          'confidence': 0.0,
          'isDoorOpen': true,
          'isAutoMode': true,
          'temp': 35.0,
          'humidity': 60.0,
          'lastDetected': null,
          'logs': [],
          'predictionImageUrl': '',
        });
      }

      // _groups 구조로 변환
      return groupMap.entries
          .map((e) => {'name': e.key, 'hives': e.value})
          .toList();
    } catch (e) {
      print('벌통 목록 조회 실패: $e');
      return [];
    }
  }

  // ───────────────────────── 벌통 등록 ─────────────────────────
  // POST /v1/register-device
  Future<bool> registerDevice({
    required String deviceId,
    required String userId,
    String? appToken,
    required String deviceName,
    required String group,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/v1/register-device'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': Config.apiKey,
        },
        body: jsonEncode({
          'device_id': deviceId,
          'user_id': userId,
          'app_token': appToken,
          'device_name': deviceName,
          'group': group,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('벌통 등록 실패: $e');
      return false;
    }
  }

  // ───────────────────────── 벌통 해제 ─────────────────────────
  // POST /v1/unregister-device
  Future<bool> unregisterDevice({required String deviceId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/v1/unregister-device'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': Config.apiKey,
        },
        body: jsonEncode({'device_id': deviceId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('벌통 해제 실패: $e');
      return false;
    }
  }

  // ───────────────────────── 벌통 수정 ─────────────────────────
  // POST /v1/update-device
  Future<bool> updateDevice({
    required String deviceId,
    required String deviceName,
    required String group,
    String? appToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/v1/update-device'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': Config.apiKey,
        },
        body: jsonEncode({
          'device_id': deviceId,
          'device_name': deviceName,
          'group': group,
          if (appToken != null) 'app_token': appToken,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('벌통 수정 실패: $e');
      return false;
    }
  }

  // ───────────────────────── 감지 기록 조회 ─────────────────────────
  // GET /v1/predictions
  Future<List<Map<String, dynamic>>> getPredictions(String deviceId) async {
    try {
      final now = DateTime.now();
      final fromTime =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T00:00:00';
      final toTime =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T23:59:59';

      final uri = Uri.parse('$baseUrl/v1/predictions').replace(
        queryParameters: {
          'device_id': deviceId,
          'from_time': fromTime,
          'to_time': toTime,
        },
      );
      final response = await http.get(
        uri,
        headers: {'x-api-key': Config.apiKey},
      );
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final predictions = data['predictions'] as List;

      return predictions.where((p) => p['is_hornet'] == true).map((p) {
        // event_time 파싱 (T11-15-40 → T11:15:40 으로 변환)
        final rawTime = p['event_time'] as String;
        final fixedTime = rawTime.replaceAllMapped(
          RegExp(r'T(\d{2})-(\d{2})-(\d{2})'),
          (m) => 'T${m[1]}:${m[2]}:${m[3]}',
        );
        return {
          'time': DateTime.parse(fixedTime),
          'confidence': (p['confidence'] as num).toDouble(),
        };
      }).toList();
    } catch (e) {
      print('감지 기록 조회 실패: $e');
      return [];
    }
  }
}
