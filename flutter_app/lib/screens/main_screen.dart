import 'package:flutter/material.dart';
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

class _MainScreenState extends State<MainScreen> {
  final WebSocketService _webSocketService = WebSocketService();
  final TTSService _ttsService = TTSService();
  final VoiceCommandService _voiceService = VoiceCommandService();

  String _status = '연결 안됨';
  String _speed = '0 km/h';
  String _battery = '100%';
  String _mode = '대기 중';

  bool isHeavyRain = false;

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
    _initTTS();
  }

  Future<void> _initTTS() async {
    await _ttsService.speak("톡톡카 입니다. 버튼을 눌러 음성 명령을 시작하세요.");
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
      } catch (e) {
        print('❌ 데이터 파싱 오류: $e');
        setState(() {
          _status = '데이터 수신 오류';
          _speed = '- km/h';
          _battery = '- %';
          _mode = '-';
        });
      }
    }, onError: (error) {
      print('❌ WebSocket 에러: $error');
      setState(() {
        _status = '연결 실패';
      });
    });
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('톡톡카 - 실시간 차량 모니터링'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        leadingWidth: 100,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.warning, color: Colors.redAccent),
              tooltip: '비상',
              onPressed: () async {
                await _voiceService.processCommand("응급상황 발생");
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EmergencyScreen()),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.cloud, color: isHeavyRain ? Colors.red : Colors.green),
              tooltip: '폭우 On/Off',
              onPressed: () {
                setState(() {
                  isHeavyRain = !isHeavyRain;
                });
              },
            ),
          ],
        ),
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
              child: Column(
                children: [
                  Text(_status, style: _statusStyle()),
                  SizedBox(height: 16),
                  Icon(Icons.speed, color: Colors.white, size: 36),
                  Text('속도: $_speed', style: _infoStyle()),
                  SizedBox(height: 16),
                  Icon(Icons.battery_full, color: Colors.white, size: 36),
                  Text('배터리: $_battery', style: _infoStyle()),
                  SizedBox(height: 16),
                  Icon(Icons.directions_car, color: Colors.white, size: 36),
                  Text('주행 모드: $_mode', style: _infoStyle()),
                ],
              ),
            ),
            SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                if (isHeavyRain) {
                  await _ttsService.speak("현재 폭우로 인해 자율주행 관련 기능은 사용 불가합니다.");
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VoiceCommandScreen(isHeavyRain: isHeavyRain),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '🎤 음성 명령 실행하기',
                    style: GoogleFonts.roboto(fontSize: 26),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _statusStyle() => GoogleFonts.roboto(
    color: Colors.white,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  TextStyle _infoStyle() => GoogleFonts.roboto(
    color: Colors.white,
    fontSize: 20,
  );
}
