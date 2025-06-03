import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../services/tts_service.dart';
import 'package:google_fonts/google_fonts.dart';

class EmergencyScreen extends StatefulWidget {
  @override
  _EmergencyScreenState createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with TickerProviderStateMixin {
  String guardianPhone = '';
  final TTSService _ttsService = TTSService();

  // 배경 애니메이션 컨트롤러
  late AnimationController _backgroundAnimationController;
  late Animation<Color?> _backgroundColorAnimation;

  // 경고 아이콘 애니메이션 컨트롤러
  late AnimationController _iconAnimationController;
  late Animation<double> _iconSizeAnimation;

  // 텍스트 깜빡임 애니메이션 컨트롤러
  late AnimationController _textAnimationController;
  late Animation<double> _textOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _loadGuardianInfo();
    _setupAnimations();
    _announceEmergency();
    _vibrateEmergency();
  }

  Future<void> _loadGuardianInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          guardianPhone = prefs.getString('guardianPhone') ?? '등록된 번호가 없습니다';
        });
      }
    } catch (e) {
      print('보호자 정보 로드 오류: $e');
    }
  }

  void _setupAnimations() {
    // 배경 색상 애니메이션
    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _backgroundColorAnimation = ColorTween(
      begin: Color(0xFFD50000), // 진한 빨간색
      end: Color(0xFFFF5252),   // 밝은 빨간색
    ).animate(_backgroundAnimationController);

    // 경고 아이콘 크기 애니메이션
    _iconAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _iconSizeAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _iconAnimationController,
      curve: Curves.easeInOut,
    ));

    // 텍스트 깜빡임 애니메이션
    _textAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _textOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _announceEmergency() async {
    await _ttsService.speak(
      '비상 상황이 발생했습니다. 보호자에게 연락하려면 화면을 아무 곳이나 터치하세요.',
    );
  }

  Future<void> _vibrateEmergency() async {
    if (await Vibration.hasVibrator() ?? false) {
      // SOS 모스 부호 패턴 (... --- ...)
      final pattern = [300, 200, 300, 200, 300, 500, 600, 200, 600, 200, 600, 500, 300, 200, 300, 200, 300];
      Vibration.vibrate(pattern: pattern, intensities: List.filled(pattern.length, 255));
    }
  }

  Future<void> _makeEmergencyCall() async {
    if (guardianPhone == '등록된 번호가 없습니다') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('등록된 보호자 번호가 없습니다.'),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    final uri = Uri.parse('tel:$guardianPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await _ttsService.speak('보호자에게 전화를 겁니다.');
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('전화 발신에 실패했습니다.'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      print('전화 발신 오류: $e');
    }
  }

  @override
  void dispose() {
    _backgroundAnimationController.dispose();
    _iconAnimationController.dispose();
    _textAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _backgroundColorAnimation,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _backgroundColorAnimation.value,
          body: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _makeEmergencyCall,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 상단 경고 표시
                    _buildEmergencyHeader(),

                    SizedBox(height: 40),

                    // 메인 비상 버튼
                    _buildEmergencyButton(),

                    SizedBox(height: 40),

                    // 하단 보호자 정보
                    _buildGuardianInfo(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmergencyHeader() {
    return AnimatedBuilder(
      animation: _textOpacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _textOpacityAnimation.value,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 15, horizontal: 25),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red[900],
                  size: 30,
                ),
                SizedBox(width: 12),
                Text(
                  '비상 상황',
                  style: GoogleFonts.notoSans(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmergencyButton() {
    return AnimatedBuilder(
      animation: _iconSizeAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _iconSizeAnimation.value,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
              border: Border.all(
                color: Colors.red[900]!,
                width: 8,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.call_rounded,
                  size: 80,
                  color: Colors.red[900],
                ),
                SizedBox(height: 15),
                Text(
                  '터치하여\n보호자에게 전화',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuardianInfo() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            '등록된 보호자 번호',
            style: GoogleFonts.notoSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            guardianPhone,
            style: GoogleFonts.roboto(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.red[900],
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 15),
          Text(
            '화면을 터치하면 즉시 연결됩니다',
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
