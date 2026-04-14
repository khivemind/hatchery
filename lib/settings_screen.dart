import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> groups;

  const SettingsScreen({Key? key, required this.groups}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late List<Map<String, dynamic>> _groups;
  final ApiService _api = ApiService();

  static const cream = Color(0xFFF8F6F0);
  static const gold = Color(0xFFE8A820);
  static const darkBrown = Color(0xFF1C1207);
  static const lightBorder = Color(0xFFE0D8C8);
  static const mutedGold = Color(0xFFA08040);
  static const kRed = Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    _groups = widget.groups
        .map(
          (g) => {
            'name': g['name'],
            'hives': (g['hives'] as List)
                .map((h) => Map<String, dynamic>.from(h))
                .toList(),
          },
        )
        .toList();
  }

  // ───────────────────────── FCM 토큰 가져오기 ─────────────────────────
  Future<String> _getFcmToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    return token ?? '';
  }

  // ───────────────────────── 구역 추가 ─────────────────────────
  void _addGroup() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '구역 추가',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 16,
            letterSpacing: 1,
            color: darkBrown,
            fontWeight: FontWeight.normal,
          ),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '구역 이름',
            hintStyle: TextStyle(fontSize: 13, color: mutedGold),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: lightBorder),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: gold),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: mutedGold)),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  _groups.add({
                    'name': nameController.text.trim(),
                    'hives': [],
                  });
                });
                Navigator.pop(context);
              }
            },
            child: Text('추가', style: TextStyle(color: gold)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 벌통 추가 ─────────────────────────
  void _addHive(int groupIndex) {
    final nameController = TextEditingController();
    final cctvController = TextEditingController();
    final ipController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '벌통 추가',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 16,
            letterSpacing: 1,
            color: darkBrown,
            fontWeight: FontWeight.normal,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '벌통 이름',
                  hintText: '예: 벌통 1',
                  hintStyle: TextStyle(fontSize: 13, color: mutedGold),
                  labelStyle: TextStyle(fontSize: 12, color: mutedGold),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: lightBorder),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: gold),
                  ),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: cctvController,
                decoration: InputDecoration(
                  labelText: 'CCTV URL (선택)',
                  hintText: '예: rtsp://192.168.0.10:554/stream',
                  hintStyle: TextStyle(fontSize: 11, color: mutedGold),
                  labelStyle: TextStyle(fontSize: 12, color: mutedGold),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: lightBorder),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: gold),
                  ),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  labelText: '라즈베리파이 IP (선택)',
                  hintText: '예: 192.168.0.20',
                  hintStyle: TextStyle(fontSize: 11, color: mutedGold),
                  labelStyle: TextStyle(fontSize: 12, color: mutedGold),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: lightBorder),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: gold),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: mutedGold)),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final deviceId =
                    DateTime.now().millisecondsSinceEpoch.toString();
                final groupName = _groups[groupIndex]['name'] as String;
                final deviceName = nameController.text.trim();

                // 앱에 먼저 추가
                setState(() {
                  final hives = _groups[groupIndex]['hives'] as List;
                  hives.add({
                    'id': int.parse(deviceId),
                    'name': deviceName,
                    'cctvUrl': cctvController.text.trim(),
                    'raspberryPiIp': ipController.text.trim(),
                    'isAlert': false,
                    'confidence': 0.0,
                    'isDoorOpen': true,
                    'isAutoMode': true,
                    'temp': 35.0,
                    'humidity': 60.0,
                    'lastDetected': null,
                    'logs': [],
                  });
                });

                Navigator.pop(context);

                // 서버에 등록
                final token = await _getFcmToken();
                final success = await _api.registerDevice(
                  deviceId: deviceId,
                  userId: 'khivemind',
                  appToken: token,
                  deviceName: deviceName,
                  group: groupName,
                );

                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('서버 등록 실패 — 나중에 다시 시도해주세요'),
                      backgroundColor: kRed,
                    ),
                  );
                }
              }
            },
            child: Text('추가', style: TextStyle(color: gold)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 벌통 수정 ─────────────────────────
  void _editHive(int groupIndex, int hiveIndex) {
    final hive = (_groups[groupIndex]['hives'] as List)[hiveIndex];
    final nameController =
        TextEditingController(text: hive['name'] as String);
    final cctvController =
        TextEditingController(text: (hive['cctvUrl'] as String?) ?? '');
    final ipController =
        TextEditingController(text: (hive['raspberryPiIp'] as String?) ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '벌통 수정',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 16,
            letterSpacing: 1,
            color: darkBrown,
            fontWeight: FontWeight.normal,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '벌통 이름',
                  labelStyle: TextStyle(fontSize: 12, color: mutedGold),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: lightBorder),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: gold),
                  ),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: cctvController,
                decoration: InputDecoration(
                  labelText: 'CCTV URL (선택)',
                  hintText: '예: rtsp://192.168.0.10:554/stream',
                  hintStyle: TextStyle(fontSize: 11, color: mutedGold),
                  labelStyle: TextStyle(fontSize: 12, color: mutedGold),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: lightBorder),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: gold),
                  ),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  labelText: '라즈베리파이 IP (선택)',
                  hintText: '예: 192.168.0.20',
                  hintStyle: TextStyle(fontSize: 11, color: mutedGold),
                  labelStyle: TextStyle(fontSize: 12, color: mutedGold),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: lightBorder),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: gold),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: mutedGold)),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final deviceId = hive['id'].toString();
                final groupName = _groups[groupIndex]['name'] as String;
                final deviceName = nameController.text.trim();

                // 앱에 먼저 반영
                setState(() {
                  final h = (_groups[groupIndex]['hives'] as List)[hiveIndex];
                  h['name'] = deviceName;
                  h['cctvUrl'] = cctvController.text.trim();
                  h['raspberryPiIp'] = ipController.text.trim();
                });

                Navigator.pop(context);

                // 서버에 수정 요청
                final success = await _api.updateDevice(
                  deviceId: deviceId,
                  deviceName: deviceName,
                  group: groupName,
                );

                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('서버 수정 실패 — 나중에 다시 시도해주세요'),
                      backgroundColor: kRed,
                    ),
                  );
                }
              }
            },
            child: Text('저장', style: TextStyle(color: gold)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 구역 삭제 ─────────────────────────
  void _deleteGroup(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('구역 삭제', style: TextStyle(fontSize: 15, color: darkBrown)),
        content: Text(
          '${_groups[index]['name']} 구역을 삭제할까요?',
          style: TextStyle(fontSize: 13, color: mutedGold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: mutedGold)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _groups.removeAt(index));
              Navigator.pop(context);
            },
            child: Text('삭제', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 벌통 삭제 ─────────────────────────
  void _deleteHive(int groupIndex, int hiveIndex) {
    final hive = (_groups[groupIndex]['hives'] as List)[hiveIndex];
    final hiveName = hive['name'] as String;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('벌통 삭제', style: TextStyle(fontSize: 15, color: darkBrown)),
        content: Text(
          '$hiveName 을(를) 삭제할까요?',
          style: TextStyle(fontSize: 13, color: mutedGold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: mutedGold)),
          ),
          TextButton(
            onPressed: () async {
              final deviceId = hive['id'].toString();

              // 앱에서 먼저 삭제
              setState(() {
                (_groups[groupIndex]['hives'] as List).removeAt(hiveIndex);
              });

              Navigator.pop(context);

              // 서버에 해제 요청
              final success =
                  await _api.unregisterDevice(deviceId: deviceId);

              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('서버 해제 실패 — 나중에 다시 시도해주세요'),
                    backgroundColor: kRed,
                  ),
                );
              }
            },
            child: Text('삭제', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: darkBrown, size: 18),
          onPressed: () => Navigator.pop(context, {'groups': _groups}),
        ),
        title: Text(
          'SETTINGS',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 16,
            letterSpacing: 3,
            color: darkBrown,
            fontWeight: FontWeight.normal,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(height: 1, color: lightBorder),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('구역 관리'),
              GestureDetector(
                onTap: _addGroup,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF8E0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: gold, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 14, color: gold),
                      SizedBox(width: 4),
                      Text('구역 추가',
                          style: TextStyle(fontSize: 11, color: gold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          if (_groups.isEmpty)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: lightBorder, width: 0.5),
              ),
              child: Center(
                child: Text('구역을 추가해주세요',
                    style: TextStyle(fontSize: 13, color: mutedGold)),
              ),
            ),

          ..._groups.asMap().entries.map((groupEntry) {
            final gi = groupEntry.key;
            final group = groupEntry.value;
            final hives = group['hives'] as List;

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: lightBorder, width: 0.5),
              ),
              child: Column(
                children: [
                  // 구역 헤더
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              group['name'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: darkBrown,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text('${hives.length}개',
                                style: TextStyle(
                                    fontSize: 11, color: mutedGold)),
                          ],
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _addHive(gi),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Color(0xFFFFF8E0),
                                  borderRadius: BorderRadius.circular(6),
                                  border:
                                      Border.all(color: gold, width: 0.5),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.add, size: 12, color: gold),
                                    SizedBox(width: 3),
                                    Text('벌통',
                                        style: TextStyle(
                                            fontSize: 10, color: gold)),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _deleteGroup(gi),
                              child: Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red[300]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 벌통 리스트
                  if (hives.isNotEmpty) ...[
                    Divider(height: 1, color: lightBorder),
                    ...hives.asMap().entries.map((hiveEntry) {
                      final hi = hiveEntry.key;
                      final hive = hiveEntry.value;
                      return Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(width: 16),
                                    Icon(Icons.hexagon_outlined,
                                        size: 14, color: mutedGold),
                                    SizedBox(width: 8),
                                    Text(
                                      hive['name'],
                                      style: TextStyle(
                                          fontSize: 13, color: darkBrown),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    // ✏️ 수정 버튼 (신규 추가)
                                    GestureDetector(
                                      onTap: () => _editHive(gi, hi),
                                      child: Icon(Icons.edit_outlined,
                                          size: 16, color: mutedGold),
                                    ),
                                    SizedBox(width: 12),
                                    // 삭제 버튼
                                    GestureDetector(
                                      onTap: () => _deleteHive(gi, hi),
                                      child: Icon(Icons.close,
                                          size: 16, color: Colors.red[300]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (hi < hives.length - 1)
                            Divider(
                              height: 1,
                              color: lightBorder,
                              indent: 40,
                              endIndent: 16,
                            ),
                        ],
                      );
                    }).toList(),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: mutedGold,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}