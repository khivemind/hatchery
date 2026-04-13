import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  const SettingsScreen({Key? key, required this.isDarkMode}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isAutoMode = true;
  bool _isDarkMode = false;

  // 컬러 팔레트
  static const cream = Color(0xFFFFFEF5);
  static const gold = Color(0xFFE8A820);
  static const darkBrown = Color(0xFF1C1207);
  static const lightBorder = Color(0xFFE0D8C8);
  static const mutedGold = Color(0xFFA08040);

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? Color(0xFF1a1200) : cream,
      appBar: AppBar(
        backgroundColor: _isDarkMode ? Color(0xFF1a1200) : cream,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: darkBrown, size: 18),
          onPressed: () => Navigator.pop(context, {
            'isAutoMode': _isAutoMode,
            'isDarkMode': _isDarkMode,
          }),
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
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            _sectionLabel('소문 개폐'),
            SizedBox(height: 10),

            // 자동/수동 모드
            _settingCard(
              title: '자동 모드',
              subtitle: '말벌 감지 시 소문 자동 차단',
              trailing: Switch(
                value: _isAutoMode,
                onChanged: (v) => setState(() => _isAutoMode = v),
                activeColor: gold,
              ),
            ),

            // 자동 모드 안내
            if (_isAutoMode) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF8E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Color(0xFFF0D080), width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: gold, size: 16),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '말벌 감지 시 소문이 자동으로 닫힙니다.',
                        style: TextStyle(fontSize: 12, color: mutedGold),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 24),
            _sectionLabel('디스플레이'),
            SizedBox(height: 10),

            // 다크 모드
            _settingCard(
              title: '다크 모드',
              subtitle: '어두운 테마로 전환',
              trailing: Switch(
                value: _isDarkMode,
                onChanged: (v) => setState(() => _isDarkMode = v),
                activeColor: gold,
              ),
            ),
          ],
        ),
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

  Widget _settingCard({
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lightBorder, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: darkBrown,
                ),
              ),
              SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: mutedGold),
              ),
            ],
          ),
          trailing,
        ],
      ),
    );
  }
}