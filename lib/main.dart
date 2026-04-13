import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/api_service.dart';
import 'settings_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
// import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:math';

// 컬러 팔레트
const kCream = Color(0xFFF8F6F0);
const kGold = Color(0xFFE8A820);
const kDarkBrown = Color(0xFF1C1207);
const kLightBorder = Color(0xFFE0D8C8);
const kMutedGold = Color(0xFFA08040);
const kRed = Color(0xFFC62828);
const kLightRed = Color(0xFFFFF5F5);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(HivemindApp());
}

class HivemindApp extends StatefulWidget {
  @override
  State<HivemindApp> createState() => _HivemindAppState();
}

class _HivemindAppState extends State<HivemindApp> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreen(
        isDarkMode: _isDarkMode,
        onDarkModeChanged: (v) => setState(() => _isDarkMode = v),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  const HomeScreen({Key? key, required this.isDarkMode, required this.onDarkModeChanged}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _autoRotateProgress = 0.0;
  final List<String> _videoIds = ['ePybIEu0TIU', '539nIqIOaCo', 'T8dcmRqDp2s'];
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  // late YoutubePlayerController _youtubeController;
  bool _isAutoRotate = true;
  int _selectedHive = 0;
  bool _isAutoMode = true;
  bool _showDetailScreen = false; // AI 예측 결과 화면 표시 여부

  final List<Map<String, dynamic>> _hives = [
    {
      'id': 1, 'name': '벌통 1', 'isAlert': false,
      'confidence': 0.0, 'isDoorOpen': true,
      'temp': 34.2, 'humidity': 62.0,
      'lastDetected': null, 'logs': [],
    },
    {
      'id': 2, 'name': '벌통 2', 'isAlert': false,
      'confidence': 0.0, 'isDoorOpen': true,
      'temp': 35.1, 'humidity': 58.0,
      'lastDetected': null, 'logs': [],
    },
    {
      'id': 3, 'name': '벌통 3', 'isAlert': false,
      'confidence': 0.0, 'isDoorOpen': true,
      'temp': 33.8, 'humidity': 65.0,
      'lastDetected': null, 'logs': [],
    },
  ];

  @override
  void initState() {
    super.initState();
    /* _youtubeController = YoutubePlayerController(
      initialVideoId: 'ePybIEu0TIU',
      flags: YoutubePlayerFlags(autoPlay: true, mute: false, loop: true),
    );*/
    _initNotifications();
    Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (_isAutoRotate && mounted) {
        setState(() {
          _autoRotateProgress += 0.1 / 10;
          if (_autoRotateProgress >= 1.0) {
            _autoRotateProgress = 0.0;
            _selectedHive = (_selectedHive + 1) % 3;
            //_youtubeController.load(_videoIds[_selectedHive]);
          }
        });
      }
    });
  }

  Future<void> _initNotifications() async {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );
    final token = await FirebaseMessaging.instance.getToken();
    print('FCM 토큰: $token');

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      InitializationSettings(android: androidSettings),
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final hiveId = int.tryParse(message.data['hive_id'] ?? '1') ?? 1;
      final hiveIndex = hiveId - 1;
      final confidence = double.tryParse(message.data['confidence'] ?? '0') ?? 0.0;

      setState(() {
        _hives[hiveIndex]['isAlert'] = true;
        _hives[hiveIndex]['confidence'] = confidence;
        _hives[hiveIndex]['lastDetected'] = DateTime.now();
        _hives[hiveIndex]['logs'].add({
          'time': DateTime.now(),
          'confidence': confidence,
        });
        _isAutoRotate = false;
        _selectedHive = hiveIndex;
        if (_isAutoMode) _hives[hiveIndex]['isDoorOpen'] = false;
      });

      await _localNotifications.show(
        0,
        '벌통 $hiveId 말벌 침입 감지!',
        '신뢰도 ${(confidence * 100).toStringAsFixed(1)}%',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'hivemind_channel', '말벌 감지 알림',
            importance: Importance.max, priority: Priority.high,
            playSound: true, enableVibration: true,
          ),
        ),
      );
    });
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '없음';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  String _tempStatus(double temp) {
    if (temp >= 34 && temp <= 36) return '정상 (34~36°C)';
    if (temp < 34) return '낮음';
    return '높음';
  }

  Color _tempColor(double temp) {
    if (temp >= 34 && temp <= 36) return Color(0xFF4CAF50);
    return kRed;
  }

  String _humidityStatus(double h) {
    if (h >= 50 && h <= 70) return '정상 (50~70%)';
    if (h < 50) return '건조';
    return '과습';
  }

  Color _humidityColor(double h) {
    if (h >= 50 && h <= 70) return Color(0xFF4CAF50);
    return kRed;
  }

  @override
  Widget build(BuildContext context) {
    final hive = _hives[_selectedHive];

    return Scaffold(
      backgroundColor: kCream,
      body: SafeArea(
        child: _showDetailScreen
            ? _buildDetailScreen(hive)
            : _buildMainScreen(hive),
      ),
    );
  }

  Widget _buildMainScreen(Map<String, dynamic> hive) {
    return Stack(
      children: [
        Column(
          children: [
            _buildAppBar(),
            _buildHiveTabs(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(14),
                child: Column(
                  children: [
                    _buildMonitor(hive),
                    SizedBox(height: 12),
                    _buildStatusCards(hive),
                    SizedBox(height: 12),
                    _buildTodayLogs(hive),
                    SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
        // 감지 배너
        if (hive['isAlert']) _buildAlertBanner(hive),
      ],
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kCream,
        border: Border(bottom: BorderSide(color: kLightBorder, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // 헥사곤 로고
              CustomPaint(painter: HexLogoPainter(), size: Size(24, 24)),
              SizedBox(width: 8),
              Text(
                'HIVEMIND',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  letterSpacing: 3,
                  color: kDarkBrown,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(isDarkMode: widget.isDarkMode),
                ),
              );
              if (result != null) {
                setState(() => _isAutoMode = result['isAutoMode']);
                widget.onDarkModeChanged(result['isDarkMode']);
              }
            },
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Color(0xFFF0EBE0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kLightBorder, width: 0.5),
              ),
              child: Icon(Icons.settings_outlined, size: 16, color: kMutedGold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHiveTabs() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: List.generate(3, (i) {
          final isAlert = _hives[i]['isAlert'];
          final isSelected = _selectedHive == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedHive = i;
                  _showDetailScreen = isAlert; // 감지된 벌통만 상세로
                  // _youtubeController.load(_videoIds[i]);
                  _isAutoRotate = false;
                });
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 3),
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isAlert
                      ? kLightRed
                      : (isSelected ? Color(0xFFFFF8E0) : Color(0xFFF0EBE0)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAlert ? kRed : (isSelected ? kGold : kLightBorder),
                    width: isAlert || isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '벌통 ${i + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isAlert ? kRed : kDarkBrown,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      isAlert ? '감지 →' : '정상',
                      style: TextStyle(
                        fontSize: 9,
                        color: isAlert ? Color(0xFFE57373) : kMutedGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMonitor(Map<String, dynamic> hive) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: kDarkBrown,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hive['isAlert'] ? kRed : Color(0xFF3D2E00),
          width: hive['isAlert'] ? 1.5 : 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Container(
                color: kDarkBrown,
                child: Center(
                child: Text('CAM', style: TextStyle(color: kGold, letterSpacing: 2, fontSize: 12)),
            )),
            Positioned(
              top: 8, left: 10,
              child: Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: hive['isAlert'] ? kRed : Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text('LIVE',
                      style: TextStyle(fontSize: 8, color: kGold, letterSpacing: 1)),
                ],
              ),
            ),
            Positioned(
              bottom: 8, right: 10,
              child: Text(
                '벌통 ${hive['id']} CAM',
                style: TextStyle(fontSize: 8, color: kMutedGold, letterSpacing: 1),
              ),
            ),
            if (_isAutoRotate)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: LinearProgressIndicator(
                  value: _autoRotateProgress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(kGold),
                  minHeight: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCards(Map<String, dynamic> hive) {
    final isAlert = hive['isAlert'] as bool;
    final isDoorOpen = hive['isDoorOpen'] as bool;
    final temp = hive['temp'] as double;
    final humidity = hive['humidity'] as double;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '벌통 ${hive['id']} 상태',
          style: TextStyle(fontSize: 10, color: kMutedGold, letterSpacing: 1),
        ),
        SizedBox(height: 6),
        Row(
          children: [
            // 온도
            Expanded(child: _infoCard(
              label: '온도',
              value: '${temp.toStringAsFixed(1)}°',
              status: _tempStatus(temp),
              statusColor: _tempColor(temp),
              isAlert: false,
            )),
            SizedBox(width: 6),
            // 습도
            Expanded(child: _infoCard(
              label: '습도',
              value: '${humidity.toStringAsFixed(0)}%',
              status: _humidityStatus(humidity),
              statusColor: _humidityColor(humidity),
              isAlert: false,
            )),
          ],
        ),
        SizedBox(height: 6),
        Row(
          children: [
            // 소문 상태 - 터치로 토글 (수동모드만)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!_isAutoMode) {
                    setState(() {
                      _hives[_selectedHive]['isDoorOpen'] = !isDoorOpen;
                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isAlert ? kLightRed : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAlert ? Color(0xFFFFCDD2) : kLightBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('소문 상태',
                          style: TextStyle(fontSize: 9, color: kMutedGold)),
                      SizedBox(height: 3),
                      Text(
                        isDoorOpen ? '열림' : '닫힘',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDoorOpen ? Color(0xFF4CAF50) : kRed,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        _isAutoMode ? '자동 모드' : '탭하여 변경',
                        style: TextStyle(
                          fontSize: 8,
                          color: _isAutoMode ? kMutedGold : kGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 6),
            // 마지막 감지
            Expanded(child: _infoCard(
              label: '마지막 감지',
              value: _timeAgo(hive['lastDetected']),
              status: hive['confidence'] > 0
                  ? '신뢰도 ${(hive['confidence'] * 100).toStringAsFixed(0)}%'
                  : '이상 없음',
              statusColor: isAlert ? Color(0xFFE57373) : kMutedGold,
              isAlert: isAlert,
            )),
          ],
        ),
      ],
    );
  }

  Widget _infoCard({
    required String label,
    required String value,
    required String status,
    required Color statusColor,
    required bool isAlert,
  }) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isAlert ? kLightRed : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlert ? Color(0xFFFFCDD2) : kLightBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: kMutedGold)),
          SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w500, color: kDarkBrown)),
          SizedBox(height: 3),
          Row(
            children: [
              Container(width: 4, height: 4,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              SizedBox(width: 3),
              Expanded(
                child: Text(status,
                    style: TextStyle(fontSize: 8, color: statusColor),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayLogs(Map<String, dynamic> hive) {
    final logs = hive['logs'] as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('오늘 탐지 현황',
                style: TextStyle(fontSize: 10, color: kMutedGold, letterSpacing: 1)),
            Text('${logs.length}회',
                style: TextStyle(fontSize: 10, color: kRed, fontWeight: FontWeight.w500)),
          ],
        ),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kLightBorder, width: 0.5),
          ),
          child: logs.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('탐지 기록 없음',
                        style: TextStyle(fontSize: 11, color: kMutedGold)),
                  ),
                )
              : Column(
                  children: logs.reversed.take(5).map((log) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(width: 4, height: 4,
                                  decoration: BoxDecoration(
                                      color: kRed, shape: BoxShape.circle)),
                              SizedBox(width: 6),
                              Text(_timeAgo(log['time']),
                                  style: TextStyle(fontSize: 10, color: kDarkBrown)),
                            ],
                          ),
                          Text(
                            '${(log['confidence'] * 100).toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 10, color: Color(0xFFE57373)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildAlertBanner(Map<String, dynamic> hive) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        color: kRed,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            SizedBox(width: 8),
            Text(
              '벌통 ${hive['id']} — 말벌 침입 감지',
              style: TextStyle(color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w500, letterSpacing: 0.5),
            ),
            Spacer(),
            Text(
              '${(hive['confidence'] * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: Color(0xFFFFCDD2), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // AI 예측 결과 화면
  Widget _buildDetailScreen(Map<String, dynamic> hive) {
    return Column(
      children: [
        // 앱바
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: kCream,
            border: Border(bottom: BorderSide(color: kLightBorder, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(() => _showDetailScreen = false),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Color(0xFFF0EBE0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kLightBorder, width: 0.5),
                  ),
                  child: Icon(Icons.arrow_back_ios, size: 14, color: kMutedGold),
                ),
              ),
              Text('AI 예측 결과',
                  style: TextStyle(
                    fontFamily: 'Georgia', fontSize: 14,
                    letterSpacing: 1, color: kDarkBrown,
                    fontWeight: FontWeight.normal,
                  )),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kRed,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('말벌 감지',
                    style: TextStyle(fontSize: 10, color: Colors.white, letterSpacing: 0.5)),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 감지 정보
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kLightRed,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Color(0xFFFFCDD2), width: 0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('감지 시각',
                              style: TextStyle(fontSize: 9, color: kMutedGold)),
                          SizedBox(height: 2),
                          Text(
                            hive['lastDetected'] != null
                                ? hive['lastDetected'].toString().substring(0, 19)
                                : '-',
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w500, color: kRed),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('신뢰도',
                              style: TextStyle(fontSize: 9, color: kMutedGold)),
                          SizedBox(height: 2),
                          Text(
                            '${(hive['confidence'] * 100).toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 22,
                                fontWeight: FontWeight.w500, color: kRed),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14),

                // Waveform
                _graphLabel('WAVEFORM'),
                SizedBox(height: 6),
                Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: kDarkBrown,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CustomPaint(
                      size: Size.infinite, painter: WaveformPainter()),
                ),
                SizedBox(height: 12),

                // FFT
                _graphLabel('FFT'),
                SizedBox(height: 6),
                Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: kDarkBrown,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CustomPaint(
                      size: Size.infinite, painter: FFTPainter()),
                ),
                SizedBox(height: 12),

                // Spectrogram
                _graphLabel('SPECTROGRAM'),
                SizedBox(height: 6),
                Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: kDarkBrown,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CustomPaint(
                      size: Size.infinite, painter: SpectrogramPainter()),
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _graphLabel(String label) {
    return Text(label,
        style: TextStyle(fontSize: 10, color: kMutedGold, letterSpacing: 1.5));
  }

  @override
     void dispose() {
    //_youtubeController.dispose();
    super.dispose(); 
  }
}
// 헥사곤 로고 페인터
class HexLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Color(0xFF1C1207)..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Color(0xFFE8A820)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * 3.14159 / 180;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }
  @override
  bool shouldRepaint(_) => false;
}

// Waveform
class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFE8A820)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < size.width.toInt(); i++) {
      final y = size.height / 2 +
          (size.height * 0.35) *
              (i % 40 < 20 ? (i % 20 - 10) / 10 : (10 - i % 20) / 10);
      if (i == 0) path.moveTo(i.toDouble(), y);
      else path.lineTo(i.toDouble(), y);
    }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(_) => false;
}

// FFT
class FFTPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final heights = [15, 30, 45, 90, 100, 95, 70, 50, 35, 22, 15, 10, 8, 6, 4, 3, 2, 2, 1, 1];
    final barWidth = size.width / heights.length;
    for (int i = 0; i < heights.length; i++) {
      final h = size.height * heights[i] / 100;
      final isHornet = i >= 2 && i <= 5;
      final paint = Paint()
        ..color = isHornet ? Color(0xFFC62828) : Color(0xFFE8A820);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * barWidth + 1, size.height - h, barWidth - 2, h),
          Radius.circular(2),
        ),
        paint,
      );
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

// Spectrogram
class SpectrogramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (int x = 0; x < size.width.toInt(); x += 3) {
      for (int y = 0; y < size.height.toInt(); y += 3) {
        final intensity = ((x * 0.3 + y * 0.5) % 100) / 100;
        final paint = Paint()
          ..color = Color.lerp(
            Color(0xFF1C1207),
            intensity > 0.6 ? Color(0xFFC62828) : Color(0xFFE8A820),
            intensity,
          )!;
        canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), y.toDouble(), 3, 3), paint);
      }
    }
    
  }
  @override
  bool shouldRepaint(_) => false;
  
}
