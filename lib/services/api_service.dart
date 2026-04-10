import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiService {
  final String baseUrl = 'http://34.81.221.132:8000';
  final String apiKey = Config.apiKey;

  // 말벌 감지 데이터 전송
  Future<Map<String, dynamic>> predict(int hiveId, String wavBase64) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/predict'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
      },
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
}