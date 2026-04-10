import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://10.0.2.2:8000'; // 에뮬레이터용 로컬 주소

  // 감지 기록 조회
  Future<List> getAlerts() async {
    final response = await http.get(Uri.parse('$baseUrl/alerts'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('조회 실패');
    }
  }

  // 말벌 감지 데이터 전송
  Future<void> postAlert(int hiveId, String status, double hz) async {
    final response = await http.post(
      Uri.parse('$baseUrl/alerts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'hive_id': hiveId,
        'status': status,
        'hz': hz,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('전송 실패');
    }
  }
}