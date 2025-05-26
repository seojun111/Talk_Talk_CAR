import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/voice_command_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import 'mypage.dart';
import 'dart:async';

class VoiceCommandScreen extends StatefulWidget {
  final String? passedCommand;
  final bool isHeavyRain; // ✅ 폭우 상태 추가

  const VoiceCommandScreen({Key? key, this.passedCommand, this.isHeavyRain = false})
      : super(key: key);

  @override
  _VoiceCommandScreenState createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen>
    with SingleTickerProviderStateMixin {
  final VoiceCommandService _voiceService = VoiceCommandService();
  final TTSService _ttsService = TTSService();
  final SpeechService _speechService = SpeechService();

  String _state = 'listening';
  String _recognizedText = '';
  bool _isListening = false;
  Timer? _listeningTimer;
  int _remainingSeconds = 10;

  late AnimationController _micAnimationController;
  late Animation<Color?> _micColorAnimation;

  @override
  void initState() {
    super.initState();

    _micAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _micColorAnimation = ColorTween(
      begin: Colors.white,
      end: Colors.redAccent,
    ).animate(_micAnimationController);

    if (widget.passedCommand != null) {
      _handlePassedCommand(widget.passedCommand!);
    } else {
      _startFlowAfterTTS();
    }
  }

  Future<void> _startFlowAfterTTS() async {
    // ✅ 폭우 상태일 때 경고 안내 추가
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
    return text.contains("마이페이지") && text.contains("이동");
  }

  Future<void> _navigateToMyPage() async {
    await _ttsService.speak("마이페이지로 이동했습니다.");
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyPageScreen()),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('음성 명령 처리 중'),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildStatusBox(),
            ),
            SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                if (_isListening) {
                  _cancelListeningTimer();
                  await _ttsService.speak("명령이 취소되었습니다.");
                  if (mounted) Navigator.pop(context);
                }
              },
              child: Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '음성 명령 취소 🎤',
                        style: GoogleFonts.roboto(fontSize: 26),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '$_remainingSeconds초 남음',
                        style: TextStyle(fontSize: 20, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
              animation: _micColorAnimation,
              builder: (context, child) {
                return Icon(
                  Icons.mic,
                  size: 120,
                  color: _micColorAnimation.value,
                );
              },
            ),
            SizedBox(height: 20),
            Text('음성 인식 중...', style: _statusTextStyle()),
            SizedBox(height: 10),
            CircularProgressIndicator(color: Colors.white),
          ],
        );
        break;
      case 'recognized':
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hearing, size: 100, color: Colors.white),
            SizedBox(height: 20),
            Text(
              '인식 결과: $_recognizedText',
              textAlign: TextAlign.center,
              style: _statusTextStyle(),
            ),
          ],
        );
        break;
      case 'executing':
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 100, color: Colors.white),
            SizedBox(height: 16),
            Text('$_recognizedText 명령을 수행 중입니다.', style: _statusTextStyle()),
          ],
        );
        break;
      default:
        content = SizedBox.shrink();
    }
    return content;
  }

  TextStyle _statusTextStyle() => GoogleFonts.roboto(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
}
