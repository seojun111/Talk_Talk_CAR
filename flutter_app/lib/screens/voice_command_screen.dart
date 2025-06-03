import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/voice_command_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../services/websocket_service.dart';
import 'mypage.dart';
import 'dart:async';

class VoiceCommandScreen extends StatefulWidget {
  final String? passedCommand;
  final bool isHeavyRain;

  const VoiceCommandScreen({Key? key, this.passedCommand, this.isHeavyRain = false}) : super(key: key);

  @override
  _VoiceCommandScreenState createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen> with SingleTickerProviderStateMixin {
  final VoiceCommandService _voiceService = VoiceCommandService();
  final TTSService _ttsService = TTSService();
  final SpeechService _speechService = SpeechService();
  final WebSocketService _webSocketService = WebSocketService();

  String _state = 'listening';
  String _recognizedText = '';
  bool _isListening = false;
  Timer? _listeningTimer;
  int _remainingSeconds = 10;
  StreamSubscription<String>? _webSocketSubscription;

  late AnimationController _micAnimationController;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _micColorAnimation;

  @override
  void initState() {
    super.initState();

    _micAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _micAnimationController,
      curve: Curves.easeInOut,
    ));

    _micColorAnimation = ColorTween(
      begin: Colors.green[400],
      end: Colors.green[700],
    ).animate(_micAnimationController);

    // WebSocket 메시지 구독
    _webSocketSubscription = _webSocketService.stream.listen((message) async {
      print("✅ 서버 응답 수신: $message");
      await _ttsService.speak("서버 응답: $message");
    });

    if (widget.passedCommand != null) {
      _handlePassedCommand(widget.passedCommand!);
    } else {
      _startFlowAfterTTS();
    }
  }

  Future<void> _startFlowAfterTTS() async {
    if (widget.isHeavyRain) {
      await _ttsService.speak("현재 폭우로 인해 자율주행 관련 기능은 사용 불가합니다.");
      await Future.delayed(Duration(milliseconds: 300));
    }

    await _ttsService.speak("명령을 말씀해주세요.");
    await Future.delayed(Duration(milliseconds: 100));
    _startListeningTimer();
    _startSTT();
  }

  Future<void> _startSTT() async {
    final result = await _speechService.listen();
    if (result.isNotEmpty) {
      _recognizedText = result;
      _cancelListeningTimer();
      _startVoiceCommandFlow();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _handlePassedCommand(String command) async {
    if (_checkNavigateToMyPage(command)) {
      await _navigateToMyPage();
      return;
    }

    setState(() {
      _state = 'recognized';
      _recognizedText = command;
      _isListening = false;
    });

    await _ttsService.speak("인식 결과는 $command 입니다.");
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      _state = 'executing';
    });

    await _ttsService.speak("$command 명령을 수행 중입니다.");
    await _voiceService.processCommand(command);

    await _ttsService.speak("명령을 처리했습니다.");
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _startVoiceCommandFlow() async {
    if (_checkNavigateToMyPage(_recognizedText)) {
      await _navigateToMyPage();
      return;
    }

    setState(() {
      _state = 'recognized';
      _isListening = false;
    });

    await _ttsService.speak("인식 결과는 $_recognizedText 입니다.");
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      _state = 'executing';
    });

    await _ttsService.speak("$_recognizedText 명령을 수행 중입니다.");
    await _voiceService.processCommand(_recognizedText);

    await _ttsService.speak("명령을 처리했습니다.");
    if (mounted) {
      Navigator.pop(context);
    }
  }

  bool _checkNavigateToMyPage(String text) {
    return text.contains("마이페이지");
  }

  Future<void> _navigateToMyPage() async {
    await _ttsService.speak("마이페이지로 이동했습니다.");
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyPageScreen(isHeavyRain: widget.isHeavyRain)),
      );
    }
  }

  void _startListeningTimer() {
    _isListening = true;
    _remainingSeconds = 10;
    _listeningTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        if (mounted) Navigator.pop(context);
      }
    });
  }

  void _cancelListeningTimer() {
    _listeningTimer?.cancel();
    _listeningTimer = null;
    setState(() {
      _remainingSeconds = 10;
    });
  }

  @override
  void dispose() {
    _ttsService.stop();
    _cancelListeningTimer();
    _micAnimationController.dispose();
    _webSocketSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '음성 명령',
          style: GoogleFonts.orbitron(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () async {
            HapticFeedback.mediumImpact();
            await _ttsService.speak("이전 화면으로 돌아갑니다.");
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[50]!, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // 상태 표시 영역
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.green[400]!, Colors.green[600]!, Colors.green[800]!],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white, width: 5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: _buildStatusBox(),
              ),

              SizedBox(height: 30),

              // 남은 시간 표시
              if (_isListening)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green[300]!, width: 2),
                  ),
                  child: Text(
                    '남은 시간: $_remainingSeconds초',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ),

              SizedBox(height: 30),

              // 취소 버튼
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.heavyImpact();
                    if (_isListening) {
                      _cancelListeningTimer();
                      await _ttsService.speak("명령이 취소되었습니다.");
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.red[300]!, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.2),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cancel_rounded,
                            size: 80,
                            color: Colors.red[400],
                          ),
                          SizedBox(height: 20),
                          Text(
                            '음성 명령 취소',
                            style: GoogleFonts.roboto(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBox() {
    Widget content;
    switch (_state) {
      case 'listening':
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: AnimatedBuilder(
                      animation: _micColorAnimation,
                      builder: (context, child) {
                        return Icon(
                          Icons.mic,
                          size: 100,
                          color: Colors.white,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 30),
            Text(
              '음성 인식 중...',
              style: _statusTextStyle(),
            ),
            SizedBox(height: 15),
            Container(
              width: 200,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        );
        break;
      case 'recognized':
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Icon(
                Icons.hearing,
                size: 80,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 30),
            Text(
              '인식 결과:',
              style: _statusTextStyle(),
            ),
            SizedBox(height: 15),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                _recognizedText,
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
        break;
      case 'executing':
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 30),
            Text(
              '명령 실행 중',
              style: _statusTextStyle(),
            ),
            SizedBox(height: 15),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                _recognizedText,
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: 200,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        );
        break;
      default:
        content = SizedBox.shrink();
    }
    return content;
  }

  TextStyle _statusTextStyle() => GoogleFonts.roboto(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 1,
    shadows: [
      Shadow(
        color: Colors.green[900]!.withOpacity(0.5),
        offset: Offset(1, 1),
        blurRadius: 2,
      ),
    ],
  );
}
