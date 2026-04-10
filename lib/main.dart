import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/api_service.dart';
import 'settings_screen.dart';
import 'detail_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MaterialApp(home: HomeScreen()));
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _videoIds = ['ePybIEu0TIU', '539nIqIOaCo', 'T8dcmRqDp2s'];
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();
  late YoutubePlayerController _youtubeController;
  bool _isAutoRotate = true;
  int _selectedHive = 0; // 선택된 벌통 인덱스
  int _selectedTab = 0; // 하단 탭 인덱스

  final List<Map<String, dynamic>> _hives = [
    {
      'id': 1,
      'name': '벌통 1',
      'isAlert': false,
      'detection': 0.0,
      'logs': [],
      'confidence': 0.0,
      'spectrogram': null,
    },
    {
      'id': 2,
      'name': '벌통 2',
      'isAlert': false,
      'detection': 0.0,
      'logs': [],
      'confidence': 0.0,
      'spectrogram': null,
    },
    {
      'id': 3,
      'name': '벌통 3',
      'isAlert': false,
      'detection': 0.0,
      'logs': [],
      'confidence': 0.0,
      'spectrogram': null,
    },
  ];

  bool _isAutoMode = true;

  @override
  void initState() {
    _youtubeController = YoutubePlayerController(
      initialVideoId: 'ePybIEu0TIU',
      flags: YoutubePlayerFlags(autoPlay: true, mute: false, loop: true),
    );
    Timer.periodic(Duration(seconds: 5), (timer) {
      if (_isAutoRotate && mounted) {
        setState(() {
          _selectedHive = (_selectedHive + 1) % 3;
        });
        _youtubeController.load(_videoIds[_selectedHive]);
      }
    });
  }

  // 로컬 알림 초기화
  Future<void> _init() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
    await _getFcmToken();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );
    await _localNotifications.initialize(initSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // hive_id 추출 (데이터에서 받아오기)
      final hiveId = int.tryParse(message.data['hive_id'] ?? '1') ?? 1;
      final hiveIndex = hiveId - 1;

      setState(() {
        _hives[hiveIndex]['isAlert'] = true;
        _hives[hiveIndex]['detection'] = 87.5;
        _hives[hiveIndex]['logs'].add({
          'time': DateTime.now().toString().substring(0, 19),
          'message': '말벌 감지됨 - 87.5Hz',
        });
        _isAutoRotate = false; // 자동 순환 멈춤
        _selectedHive = hiveIndex; // 감지된 벌통으로 이동F
      });
      // 로컬 알림 (소리+진동)
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'hivemind_channel',
            '말벌 감지 알림',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          );
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );
      await _localNotifications.show(
        0,
        '🐝 벌통 $hiveId 이상 감지!',
        '말벌 감지됨 - 87.5Hz',
        details,
      );

      if (_isAutoMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔒 벌통 $hiveId 소문 개폐완료'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('⚠️ 벌통 $hiveId 말벌 감지됨!'),
            content: Text('벌통 $hiveId 소문을 개폐하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('개폐'),
              ),
            ],
          ),
        );
      }
    });
  }

  Future<void> _getFcmToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    print('FCM 토큰: $token');
  }

  @override
  Widget build(BuildContext context) {
    final hive = _hives[_selectedHive];

    return Scaffold(
      appBar: AppBar(
        title: Text('Hivemind'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
              if (result != null) {
                setState(() {
                  _isAutoMode = result;
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 상단 벌통 탭
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: List.generate(3, (index) {
                final isSelected = _selectedHive == index;
                final isAlert = _hives[index]['isAlert'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedHive = index),
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      padding: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isAlert
                            ? Colors.red[isSelected ? 400 : 100]
                            : Colors.green[isSelected ? 400 : 100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAlert ? Colors.red : Colors.green,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        '벌통 ${index + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // 중앙 상태 버튼
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                // 상태 원형 버튼
                GestureDetector(
                  onTap: () {
                    if (hive['isAlert']) {
                      setState(() {
                        _hives[_selectedHive]['isAlert'] = false;
                        _hives[_selectedHive]['detection'] = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hive['isAlert'] ? Colors.red : Colors.green,
                      boxShadow: [
                        BoxShadow(
                          color: (hive['isAlert'] ? Colors.red : Colors.green)
                              .withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        hive['isAlert'] ? '⚠️' : '✅',
                        style: TextStyle(fontSize: 36),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                // 탐지율
                Text(
                  '탐지율 ${hive['detection']}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hive['isAlert'] ? Colors.red : Colors.green,
                  ),
                ),
                SizedBox(height: 6),
                // 개폐 상태
                Text(
                  hive['isAlert']
                      ? (_isAutoMode ? '🔒 개폐완료' : '❓ 개폐하시겠습니까?')
                      : '정상 운영 중',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ),

          // 하단 탭 버튼
          Row(
            children: ['모니터', '상세', '탐지현황'].asMap().entries.map((e) {
              final isSelected = _selectedTab == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = e.key),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? Colors.amber : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      e.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? Colors.amber[800] : Colors.grey,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // 탭 내용
          Expanded(child: _buildTabContent(hive)),
        ],
      ),
    );
  }

  Widget _buildTabContent(Map<String, dynamic> hive) {
    switch (_selectedTab) {
      case 0:
        return _buildMonitorTab(hive);
      case 1:
        return _buildDetailTab(hive);
      case 2:
        return _buildLogsTab(hive);
      default:
        return Container();
    }
  }

  // 상세 탭
  Widget _buildDetailTab(Map<String, dynamic> hive) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Waveform',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(size: Size.infinite, painter: WaveformPainter()),
          ),
          SizedBox(height: 16),
          Text(
            'FFT',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(size: Size.infinite, painter: FFTPainter()),
          ),
          SizedBox(height: 16),
          Text(
            'Spectrogram',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              size: Size.infinite,
              painter: SpectrogramPainter(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _youtubeController.dispose();
    super.dispose();
  }

  // 모니터 탭
  Widget _buildMonitorTab(Map<String, dynamic> hive) {
    return Column(
      children: [
        YoutubePlayer(
          controller: _youtubeController,
          showVideoProgressIndicator: true,
        ),
        SizedBox(height: 12),
        Text(
          '벌통 ${hive['id']}번 모니터링',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          _isAutoRotate ? '자동 순환 중...' : '말벌 감지 - 고정됨',
          style: TextStyle(
            fontSize: 13,
            color: _isAutoRotate ? Colors.grey : Colors.red,
          ),
        ),
      ],
    );
  }

  // 탐지현황 탭
  Widget _buildLogsTab(Map<String, dynamic> hive) {
    final logs = hive['logs'] as List;
    if (logs.isEmpty) {
      return Center(
        child: Text('탐지 기록이 없습니다.', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(12),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[logs.length - 1 - index];
        return Card(
          child: ListTile(
            leading: Icon(Icons.warning, color: Colors.red),
            title: Text(log['message']),
            subtitle: Text(log['time']),
          ),
        );
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < size.width.toInt(); i++) {
      final y =
          size.height / 2 +
          30 * (i % 40 < 20 ? (i % 20 - 10) / 10 : (10 - i % 20) / 10);
      if (i == 0)
        path.moveTo(i.toDouble(), y);
      else
        path.lineTo(i.toDouble(), y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FFTPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 3;

    final barWidth = size.width / 20;
    final heights = [
      20,
      40,
      60,
      80,
      100,
      90,
      70,
      50,
      30,
      20,
      15,
      35,
      55,
      75,
      95,
      85,
      65,
      45,
      25,
      10,
    ];

    for (int i = 0; i < 20; i++) {
      final x = i * barWidth;
      final h = heights[i].toDouble();
      canvas.drawRect(
        Rect.fromLTWH(x + 2, size.height - h, barWidth - 4, h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SpectrogramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (int x = 0; x < size.width.toInt(); x += 4) {
      for (int y = 0; y < size.height.toInt(); y += 4) {
        final intensity = ((x + y) % 80) / 80;
        final paint = Paint()
          ..color = Color.lerp(Colors.blue, Colors.yellow, intensity)!;
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 4, 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
