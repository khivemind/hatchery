import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/api_service.dart';
import 'settings_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:http/http.dart' as http;
import 'services/config.dart';
import 'services/fcm_service.dart';
import 'splash_screen.dart';

const kCream = Color(0xFFF8F6F0);
const kGold = Color(0xFFE8A820);
const kDarkBrown = Color(0xFF1C1207);
const kLightBorder = Color(0xFFE0D8C8);
const kMutedGold = Color(0xFFA08040);
const kRed = Color(0xFFC62828);
const kLightRed = Color(0xFFFFF5F5);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  print('[FCM] 백그라운드 메시지: ${message.notification?.title}');
}

final fcmService = FcmService();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {}
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(HivemindApp());
}

class HivemindApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      home: SplashScreen(nextScreen: HomeScreen()),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.15),
          child: child!,
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  int _selectedGroupIndex = 0;
  int _selectedHiveIndex = 0;
  bool _showDetailScreen = false;

  List<Map<String, dynamic>> _groups = [];

  Map<String, dynamic>? get _currentHive {
    if (_groups.isEmpty) return null;
    final hives = _groups[_selectedGroupIndex]['hives'] as List;
    if (hives.isEmpty) return null;
    if (_selectedHiveIndex >= hives.length) return null;
    return hives[_selectedHiveIndex];
  }

  List get _currentHives {
    if (_groups.isEmpty) return [];
    return _groups[_selectedGroupIndex]['hives'] as List;
  }

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final groups = await ApiService().getDevices();
    if (groups.isNotEmpty) {
      setState(() {
        _groups = groups;
      });
    }
  }

  void _handleFcmMessage(RemoteMessage message) async {
    print('FCM 수신 데이터: ${message.data}');
    print('FCM 알림: ${message.notification?.title}');
    final deviceId = message.data['device_id'] ?? '';
    final confidence =
        double.tryParse(message.data['confidence'] ?? '0') ?? 0.0;
    final imageUrl = message.data['image_url'] ?? '';

    for (int gi = 0; gi < _groups.length; gi++) {
      final hives = _groups[gi]['hives'] as List;
      for (int hi = 0; hi < hives.length; hi++) {
        hives[hi]['predictionImageUrl'] = imageUrl;
        if (hives[hi]['id'].toString() == message.data['device_id']) {
          setState(() {
            hives[hi]['isAlert'] = true;
            hives[hi]['confidence'] = confidence;
            hives[hi]['lastDetected'] = DateTime.now();
            hives[hi]['logs'].add({
              'time': DateTime.now(),
              'confidence': confidence,
            });
            _selectedGroupIndex = gi;
            _selectedHiveIndex = hi;
            _showDetailScreen = true;
            if (hives[hi]['isAutoMode'] == true)
              hives[hi]['isDoorOpen'] = false;
          });
          break;
        }
      }
    }

    await _localNotifications.show(
      0,
      '말벌 침입 감지!',
      '벌통 $deviceId | 신뢰도 ${(confidence * 100).toStringAsFixed(1)}%',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'hornet_alert',
          '말벌 감지 알림',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }

  Future<void> _initNotifications() async {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('FCM 토큰 갱신: $newToken');
      for (int gi = 0; gi < _groups.length; gi++) {
        final hives = _groups[gi]['hives'] as List;
        for (final hive in hives) {
          await ApiService().registerDevice(
            deviceId: hive['id'].toString(),
            userId: 'khivemind',
            appToken: newToken,
            deviceName: hive['name'] as String,
            group: _groups[gi]['name'] as String,
          );
          print('토큰 재등록 완료: ${hive['id']}');
        }
      }
    });
    await fcmService.init('khivemind');
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
    final token = await FirebaseMessaging.instance.getToken();
    print('FCM 토큰: $token');

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      InitializationSettings(android: androidSettings),
    );

    FirebaseMessaging.onMessage.listen(_handleFcmMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmMessage);

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleFcmMessage(message);
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

  String _formatLogTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _tempStatus(double t) {
    if (t >= 34 && t <= 36) return '정상 (34~36°C)';
    if (t < 34) return '낮음';
    return '높음';
  }

  Color _tempColor(double t) => (t >= 34 && t <= 36) ? Color(0xFF4CAF50) : kRed;

  String _humidityStatus(double h) {
    if (h >= 50 && h <= 70) return '정상 (50~70%)';
    if (h < 50) return '건조';
    return '과습';
  }

  Color _humidityColor(double h) =>
      (h >= 50 && h <= 70) ? Color(0xFF4CAF50) : kRed;

  @override
  Widget build(BuildContext context) {
    final hive = _currentHive;
    return Scaffold(
      backgroundColor: kCream,
      body: SafeArea(
        child: _showDetailScreen && hive != null
            ? _buildDetailScreen(hive)
            : _buildMainScreen(),
      ),
    );
  }

  Widget _buildMainScreen() {
    final hive = _currentHive;
    return Stack(
      children: [
        Column(
          children: [
            _buildAppBar(),
            if (_groups.isEmpty)
              Expanded(child: _buildEmptyState())
            else ...[
              _buildGroupTabs(),
              _buildHiveTabs(),
              Expanded(
                child: _currentHives.isEmpty
                    ? _buildEmptyHiveState()
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(14),
                        child: Column(
                          children: [
                            _buildMonitor(hive!),
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
          ],
        ),
        if (hive != null && hive['isAlert']) _buildAlertBanner(hive),
      ],
    );
  }

  Widget _buildEmptyState() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SettingsScreen(groups: _groups)),
        );
        if (result != null) {
          setState(() {
            _groups = result['groups'];
          });
        }
      },
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 48, color: kMutedGold),
            SizedBox(height: 16),
            Text(
              '구역을 추가해주세요',
              style: TextStyle(fontSize: 16, color: kMutedGold),
            ),
            SizedBox(height: 8),
            Text(
              '탭하여 설정으로 이동',
              style: TextStyle(fontSize: 14, color: kLightBorder),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHiveState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hive_outlined, size: 48, color: kMutedGold),
          SizedBox(height: 16),
          Text('벌통을 추가해주세요', style: TextStyle(fontSize: 16, color: kMutedGold)),
          SizedBox(height: 8),
          Text(
            '설정에서 이 구역에 벌통을 추가할 수 있어요',
            style: TextStyle(fontSize: 14, color: kLightBorder),
          ),
        ],
      ),
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
              CustomPaint(painter: HexLogoPainter(), size: Size(24, 24)),
              SizedBox(width: 8),
              Text(
                'HIVEMIND',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
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
                  builder: (_) => SettingsScreen(groups: _groups),
                ),
              );
              if (result != null) {
                setState(() {
                  _groups = result['groups'];
                  if (_selectedGroupIndex >= _groups.length) {
                    _selectedGroupIndex = 0;
                  }
                  if (_selectedHiveIndex >= _currentHives.length) {
                    _selectedHiveIndex = 0;
                  }
                });
              }
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(0xFFF0EBE0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kLightBorder, width: 0.5),
              ),
              child: Icon(Icons.settings_outlined, size: 18, color: kMutedGold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTabs() {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: _groups.asMap().entries.map((e) {
          final gi = e.key;
          final group = e.value;
          final isSelected = _selectedGroupIndex == gi;
          final hasAlert = (group['hives'] as List).any(
            (h) => h['isAlert'] == true,
          );

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedGroupIndex = gi;
                  _selectedHiveIndex = 0;
                  _showDetailScreen = false;
                });
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 3),
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: hasAlert
                      ? kLightRed
                      : (isSelected ? Color(0xFFFFF8E0) : Color(0xFFF0EBE0)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasAlert
                        ? kRed
                        : (isSelected ? kGold : kLightBorder),
                    width: hasAlert || isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Text(
                  group['name'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: hasAlert ? kRed : kDarkBrown,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHiveTabs() {
    final hives = _currentHives;
    if (hives.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          '벌통을 추가해주세요',
          style: TextStyle(fontSize: 14, color: kMutedGold),
        ),
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: hives.asMap().entries.map((e) {
            final hi = e.key;
            final hive = e.value;
            final isAlert = hive['isAlert'] as bool;
            final isSelected = _selectedHiveIndex == hi;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedHiveIndex = hi;
                  _showDetailScreen = isAlert;
                });
              },
              child: Container(
                margin: EdgeInsets.only(right: 6),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                      hive['name'],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isAlert ? kRed : kDarkBrown,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      isAlert ? '감지 →' : '정상',
                      style: TextStyle(
                        fontSize: 11,
                        color: isAlert ? Color(0xFFE57373) : kMutedGold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonitor(Map<String, dynamic> hive) {
    final cctvUrl = (hive['cctvUrl'] as String?) ?? '';

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
            cctvUrl.isNotEmpty
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: VlcPlayer(
                        controller: VlcPlayerController.network(
                          cctvUrl,
                          autoPlay: true,
                          options: VlcPlayerOptions(),
                        ),
                        aspectRatio: 16 / 9,
                        placeholder: Center(
                          child: CircularProgressIndicator(color: kGold),
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: kDarkBrown,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off_outlined,
                            color: kMutedGold,
                            size: 28,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'CCTV 미연결',
                            style: TextStyle(
                              color: kMutedGold,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            Positioned(
              top: 8,
              left: 10,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cctvUrl.isNotEmpty
                          ? (hive['isAlert'] ? kRed : Color(0xFF4CAF50))
                          : kMutedGold,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    cctvUrl.isNotEmpty ? 'LIVE' : 'NO SIGNAL',
                    style: TextStyle(
                      fontSize: 10,
                      color: kGold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 8,
              right: 10,
              child: Text(
                '${hive['name']} CAM',
                style: TextStyle(
                  fontSize: 10,
                  color: kMutedGold,
                  letterSpacing: 1,
                ),
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
    final hiveIsAutoMode = hive['isAutoMode'] as bool? ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${hive['name']} 상태',
          style: TextStyle(fontSize: 12, color: kMutedGold, letterSpacing: 1),
        ),
        SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _infoCard(
                label: '온도',
                value: '${temp.toStringAsFixed(1)}°',
                status: _tempStatus(temp),
                statusColor: _tempColor(temp),
                isAlert: false,
              ),
            ),
            SizedBox(width: 6),
            Expanded(
              child: _infoCard(
                label: '습도',
                value: '${humidity.toStringAsFixed(0)}%',
                status: _humidityStatus(humidity),
                statusColor: _humidityColor(humidity),
                isAlert: false,
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Row(
          children: [
            Expanded(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '소문 상태',
                          style: TextStyle(fontSize: 11, color: kMutedGold),
                        ),
                        Row(
                          children: [
                            Text(
                              hiveIsAutoMode ? '자동' : '수동',
                              style: TextStyle(fontSize: 10, color: kMutedGold),
                            ),
                            SizedBox(width: 4),
                            Transform.scale(
                              scale: 0.6,
                              child: Switch(
                                value: hiveIsAutoMode,
                                onChanged: (v) {
                                  setState(() {
                                    _currentHive!['isAutoMode'] = v;
                                  });
                                },
                                activeColor: kGold,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () async {
                        if (!hiveIsAutoMode) {
                          final ip =
                              _currentHive!['raspberryPiIp'] as String? ?? '';
                          if (ip.isNotEmpty) {
                            try {
                              final endpoint = isDoorOpen ? 'close' : 'open';
                              await http.post(
                                Uri.parse('http://$ip:8000/door/$endpoint'),
                                headers: {'x-api-key': Config.apiKey},
                              );
                            } catch (e) {
                              print('소문 제어 실패: $e');
                            }
                          }
                          setState(() {
                            _currentHive!['isDoorOpen'] = !isDoorOpen;
                          });
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDoorOpen ? '열림' : '닫힘',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: isDoorOpen ? Color(0xFF4CAF50) : kRed,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            hiveIsAutoMode ? '자동 모드' : '탭하여 변경',
                            style: TextStyle(
                              fontSize: 10,
                              color: hiveIsAutoMode ? kMutedGold : kGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 6),
            Expanded(
              child: _infoCard(
                label: '마지막 감지',
                value: _timeAgo(hive['lastDetected']),
                status: hive['confidence'] > 0
                    ? '탐지율 ${(hive['confidence'] * 100).toStringAsFixed(0)}%'
                    : '이상 없음',
                statusColor: isAlert ? Color(0xFFE57373) : kMutedGold,
                isAlert: isAlert,
              ),
            ),
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
          Text(label, style: TextStyle(fontSize: 11, color: kMutedGold)),
          SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: kDarkBrown,
            ),
          ),
          SizedBox(height: 3),
          Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 3),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(fontSize: 10, color: statusColor),
                  overflow: TextOverflow.ellipsis,
                ),
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
            Text(
              '오늘 탐지 현황',
              style: TextStyle(
                fontSize: 12,
                color: kMutedGold,
                letterSpacing: 1,
              ),
            ),
            Text(
              '${logs.length}회',
              style: TextStyle(
                fontSize: 12,
                color: kRed,
                fontWeight: FontWeight.w500,
              ),
            ),
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
                    child: Text(
                      '탐지 기록 없음',
                      style: TextStyle(fontSize: 13, color: kMutedGold),
                    ),
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
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: kRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                _formatLogTime(log['time']),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: kDarkBrown,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '탐지율 : ${(log['confidence'] * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFE57373),
                            ),
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
      top: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showDetailScreen = true;
          });
        },
        child: Container(
          color: kRed,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '${hive['name']} — 말벌 침입 감지',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              Spacer(),
              Text(
                '${(hive['confidence'] * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: Color(0xFFFFCDD2), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailScreen(Map<String, dynamic> hive) {
    return Column(
      children: [
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
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(0xFFF0EBE0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kLightBorder, width: 0.5),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios,
                    size: 14,
                    color: kMutedGold,
                  ),
                ),
              ),
              Text(
                'AI 예측 결과',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  letterSpacing: 1,
                  color: kDarkBrown,
                  fontWeight: FontWeight.normal,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kRed,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '말벌 감지',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
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
                          Text(
                            '감지 시각',
                            style: TextStyle(fontSize: 11, color: kMutedGold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            hive['lastDetected'] != null
                                ? hive['lastDetected'].toString().substring(
                                    0,
                                    19,
                                  )
                                : '-',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: kRed,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '신뢰도',
                            style: TextStyle(fontSize: 11, color: kMutedGold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '${(hive['confidence'] * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: kRed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14),
                _graphLabel('AI 분석 이미지'),
                SizedBox(height: 6),
                (hive['predictionImageUrl'] as String? ?? '').isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          hive['predictionImageUrl'],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 200,
                              color: kDarkBrown,
                              child: Center(
                                child: CircularProgressIndicator(color: kGold),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stack) => Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: kDarkBrown,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '이미지를 불러올 수 없어요',
                                style: TextStyle(
                                  color: kMutedGold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: kDarkBrown,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '분석 이미지 없음',
                            style: TextStyle(color: kMutedGold, fontSize: 14),
                          ),
                        ),
                      ),
                SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      final hives =
                          _groups[_selectedGroupIndex]['hives'] as List;
                      hives[_selectedHiveIndex]['isAlert'] = false;
                      hives[_selectedHiveIndex]['confidence'] = 0.0;
                      if (hives[_selectedHiveIndex]['isAutoMode'] == true) {
                        hives[_selectedHiveIndex]['isDoorOpen'] = true;
                      }
                      _showDetailScreen = false;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: kDarkBrown,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGold, width: 0.8),
                    ),
                    child: Text(
                      '조치 완료',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 16,
                        letterSpacing: 2,
                        color: kGold,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
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
    return Text(
      label,
      style: TextStyle(fontSize: 12, color: kMutedGold, letterSpacing: 1.5),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class HexLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = Color(0xFF1C1207)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = Color(0xFFE8A820)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * pi / 180;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(_) => false;
}

class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFE8A820)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < size.width.toInt(); i++) {
      final y =
          size.height / 2 +
          (size.height * 0.35) *
              (i % 40 < 20 ? (i % 20 - 10) / 10 : (10 - i % 20) / 10);
      if (i == 0)
        path.moveTo(i.toDouble(), y);
      else
        path.lineTo(i.toDouble(), y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class FFTPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final heights = [
      15,
      30,
      45,
      90,
      100,
      95,
      70,
      50,
      35,
      22,
      15,
      10,
      8,
      6,
      4,
      3,
      2,
      2,
      1,
      1,
    ];
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
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 3, 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
