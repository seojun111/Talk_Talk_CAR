import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../services/tts_service.dart';

class EmergencyScreen extends StatefulWidget {
  @override
  _EmergencyScreenState createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  String guardianPhone = '';
  final TTSService _ttsService = TTSService();
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _loadGuardianInfo();
    _setupAnimation();
    _announceEmergency();
    _vibrateOnStart();
    // ✅ 서버 전송 기능 제거됨
  }

  Future<void> _loadGuardianInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      guardianPhone = prefs.getString('guardianPhone') ?? '';
    });
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.redAccent,
      end: Colors.white,
    ).animate(_animationController);
  }

  Future<void> _announceEmergency() async {
    await _ttsService.speak(
      '비상 상황이 발생했습니다. 보호자에게 연락하려면 화면을 아무 곳이나 터치하세요.',
    );
  }

  Future<void> _vibrateOnStart() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 1000);
    }
  }

  Future<void> _makeEmergencyCall() async {
    final uri = Uri.parse('tel:$guardianPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      print('전화 발신 실패');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.redAccent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _makeEmergencyCall();
        },
        child: Center(
          child: AnimatedBuilder(
            animation: _colorAnimation,
            builder: (context, child) {
              return Container(
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _colorAnimation.value,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 10,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, size: 100, color: Colors.redAccent),
                    SizedBox(height: 20),
                    Text(
                      '비상 상황',
                      style: TextStyle(
                        fontSize: 36,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '화면을 터치하면 보호자에게 전화를 겁니다.',
                      style: TextStyle(fontSize: 20, color: Colors.black),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    Text(
                      '등록된 보호자 번호:\n$guardianPhone',
                      style: TextStyle(fontSize: 18, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
