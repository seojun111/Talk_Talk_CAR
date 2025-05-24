// 수정된 voice_command_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../widget/voice_wave_animation_widget.dart';
import 'dart:async';

class VoiceCommandService {
  /// 명령을 처리하는 중이라는 시뮬레이션용 딜레이 후 실제 전송
  Future<void> processCommand(String command) async {
    await Future.delayed(Duration(seconds: 1));
    await sendCommand(command); // ✅ 실제 명령 전송
  }

  /// 명령을 백엔드 서버로 전송
  Future<void> sendCommand(String cmd) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8080/command'), // ⚠ 실제 환경에 따라 IP 변경 필요
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': cmd}),
      );

      if (response.statusCode == 200) {
        print("📤 명령 전송 성공: \$cmd");
      } else {
        print("⚠️ 명령 전송 실패: \${response.statusCode}");
      }
    } catch (e) {
      print("❌ 명령 전송 오류: \$e");
    }
  }

  /// 센서 상태 조회 요청 (예: 연료 상태, 전압 등)
  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/status'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("📥 상태 수신: \$data");
        return data;
      } else {
        print("⚠️ 상태 요청 실패: \${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ 상태 요청 오류: \$e");
      return null;
    }
  }
}

// voice_command_screen.dart과 연계된 사용 예시 추가
class VoiceCommandScreen extends StatefulWidget {
  @override
  _VoiceCommandScreenState createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen> {
  final VoiceCommandService _voiceService = VoiceCommandService();
  final TTSService _ttsService = TTSService();
  final SpeechService _speechService = SpeechService();

  String _state = 'listening';
  String _recognizedText = '';
  bool _isListening = false;
  Timer? _listeningTimer;
  int _remainingSeconds = 10;

  @override
  void initState() {
    super.initState();
    _startFlowAfterTTS();
  }

  Future<void> _startFlowAfterTTS() async {
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
      await _ttsService.speak("명령을 인식하지 못했습니다.");
      if (mounted) Navigator.pop(context);
    }
  }

  void _startVoiceCommandFlow() async {
    setState(() {
      _state = 'recognized';
      _isListening = false;
    });

    await _ttsService.speak("인식 결과는 \$_recognizedText 입니다.");
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      _state = 'executing';
    });

    await _ttsService.speak("\$_recognizedText 명령을 수행 중입니다.");
    await _voiceService.processCommand(_recognizedText);

    await _ttsService.speak("명령을 처리했습니다.");
    if (mounted) {
      Navigator.pop(context);
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
        await _ttsService.speak("명령이 취소되었습니다.");
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildStatusBox(),
              SizedBox(height: 24),
              _buildMicButton(),
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
            SizedBox(
              width: 150,
              height: 150,
              child: VoiceWaveAnimationWidget(),
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
              '인식 결과: \$_recognizedText',
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
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('\$_recognizedText 명령을 수행 중입니다.', style: _statusTextStyle()),
          ],
        );
        break;
      default:
        content = SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: content,
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: () async {
        if (_isListening) {
          _cancelListeningTimer();
          await _ttsService.speak("명령이 취소되었습니다.");
          if (mounted) Navigator.pop(context);
        }
      },
      child: Container(
        width: double.infinity,
        height: 300,
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
                '\$_remainingSeconds초 남음',
                style: TextStyle(fontSize: 20, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _statusTextStyle() => GoogleFonts.roboto(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
}
