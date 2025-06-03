import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../services/websocket_service.dart';
import '../services/tts_service.dart';
import '../services/voice_command_service.dart';
import 'voice_command_screen.dart';
import 'emergency_screen.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final WebSocketService _webSocketService = WebSocketService();
  final TTSService _ttsService = TTSService();
  final VoiceCommandService _voiceService = VoiceCommandService();

  String _status = '연결 안됨';
  String _speed = '0 km/h';
  String _battery = '100%';
  String _mode = '대기 중';
  bool isHeavyRain = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _connectToWebSocket();
    _initTTS();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.98,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initTTS() async {
    await _ttsService.speak(
        "톡톡카에 오신 것을 환영합니다. "
            "화면의 거의 전체 영역이 음성 명령 버튼입니다. "
            "화면을 터치하여 음성 명령을 시작하세요."
    );
  }

  void _connectToWebSocket() {
    _webSocketService.connect();
    _webSocketService.stream.listen((message) {
      try {
        Map<String, dynamic> data = jsonDecode(message);
        setState(() {
          _status = '연결됨';
          _speed = data.containsKey('speed') ? '${data['speed']} km/h' : '- km/h';
          _battery = data.containsKey('battery') ? '${data['battery']}%' : '- %';
          _mode = data.containsKey('engine_on')
              ? (data['engine_on'] ? '켜짐' : '꺼짐')
              : '대기 중';
        });

        _ttsService.speak("차량 연결됨. 속도 $_speed, 배터리 $_battery, 모드 $_mode");
      } catch (e) {
        print('❌ 데이터 파싱 오류: $e');
        setState(() {
          _status = '데이터 수신 오류';
          _speed = '- km/h';
          _battery = '- %';
          _mode = '-';
        });
        _ttsService.speak("데이터 수신 오류가 발생했습니다");
      }
    }, onError: (error) {
      print('❌ WebSocket 에러: $error');
      setState(() {
        _status = '연결 실패';
      });
      _ttsService.speak("차량 연결에 실패했습니다");
    });
  }

  void _handleMainButtonPress() async {
    HapticFeedback.heavyImpact();

    if (isHeavyRain) {
      await _ttsService.speak("현재 폭우로 인해 자율주행 관련 기능은 사용할 수 없습니다.");
      return;
    }

    await _ttsService.speak("음성 명령 화면으로 이동합니다");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceCommandScreen(isHeavyRain: isHeavyRain),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _webSocketService.disconnect();
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 시연용 작은 버튼들만 (화면의 10%)
            Container(
              height: screenHeight * 0.1,
              child: _buildTopControls(),
            ),

            // 메인 음성 명령 버튼 (화면의 90%)
            Container(
              height: screenHeight * 0.9,
              child: _buildMainVoiceButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border(
          bottom: BorderSide(color: Colors.green[200]!, width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 시연용 비상 버튼 (작게)
          GestureDetector(
            onTap: () async {
              await _voiceService.processCommand("응급상황 발생");
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EmergencyScreen()),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[300]!),
              ),
              child: Text(
                '비상',
                style: TextStyle(color: Colors.red[700], fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // 톡톡카 로고 (중앙)
          Text(
            '톡톡카',
            style: GoogleFonts.orbitron(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
              letterSpacing: 2,
            ),
          ),

          // 시연용 날씨 버튼 (작게)
          GestureDetector(
            onTap: () {
              setState(() {
                isHeavyRain = !isHeavyRain;
              });
              _ttsService.speak(
                  isHeavyRain
                      ? "폭우 모드가 활성화되었습니다"
                      : "폭우 모드가 해제되었습니다"
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isHeavyRain
                    ? Colors.red[100]
                    : Colors.green[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isHeavyRain
                        ? Colors.red[300]!
                        : Colors.green[300]!
                ),
              ),
              child: Text(
                isHeavyRain ? '폭우' : '맑음',
                style: TextStyle(
                  color: isHeavyRain ? Colors.red[700] : Colors.green[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainVoiceButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GestureDetector(
            onTap: _handleMainButtonPress,
            child: Container(
              margin: EdgeInsets.all(10),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isHeavyRain
                      ? [Colors.grey[400]!, Colors.grey[600]!]
                      : [Colors.green[400]!, Colors.green[600]!, Colors.green[800]!],
                ),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: isHeavyRain ? Colors.grey[700]! : Colors.white,
                  width: 8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isHeavyRain ? Colors.grey : Colors.green).withOpacity(0.4),
                    blurRadius: 60,
                    offset: Offset(0, 25),
                    spreadRadius: 15,
                  ),
                  // 내부 하이라이트 효과
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 30,
                    offset: Offset(-10, -10),
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 초대형 마이크 아이콘
                  Container(
                    padding: EdgeInsets.all(80),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      isHeavyRain ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 150,
                    ),
                  ),

                  SizedBox(height: 50),

                  // 메인 텍스트
                  Text(
                    isHeavyRain ? '사용 불가' : '음성 명령',
                    style: GoogleFonts.roboto(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: Colors.green[900]!.withOpacity(0.5),
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),

                  // 설명 텍스트
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 60),
                    child: Text(
                      isHeavyRain
                          ? '폭우로 인해 기능이 제한됩니다\n날씨가 좋아지면 다시 시도하세요'
                          : '화면을 터치하여\n음성 명령을 시작하세요',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        fontSize: 28,
                        color: Colors.white,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.green[900]!.withOpacity(0.3),
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
