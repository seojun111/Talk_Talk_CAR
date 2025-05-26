import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import 'voice_command_screen.dart';

class MyPageScreen extends StatefulWidget {
  final bool isHeavyRain; // ✅ 폭우 상태 전달

  const MyPageScreen({Key? key, this.isHeavyRain = false}) : super(key: key);

  @override
  _MyPageScreenState createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final SpeechService _speechService = SpeechService();
  final TTSService _ttsService = TTSService();

  String name = '';
  String phone = '';
  String address = '';
  String guardianPhone = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString('name') ?? '미등록';
      phone = prefs.getString('phone') ?? '미등록';
      address = prefs.getString('address') ?? '미등록';
      guardianPhone = prefs.getString('guardianPhone') ?? '미등록';
    });
  }

  Future<void> _handleVoiceCommand() async {
    await _ttsService.speak('명령을 말씀해주세요.');
    final command = await _speechService.listen();

    print('음성 인식 결과: $command');

    final cleanCommand = command.toLowerCase().trim();

    if (cleanCommand.contains('입력')) {
      // ✅ 이제 '입력'이라는 단어만 있어도 정보 입력 활성화
      await _startInfoRegistration();
    } else if (cleanCommand.contains('내 정보') && cleanCommand.contains('알려')) {
      if (name == '미등록' || phone == '미등록' || address == '미등록' || guardianPhone == '미등록') {
        await _ttsService.speak('아직 사용자 정보가 등록되지 않았습니다.');
      } else {
        await _ttsService.speak(
            '등록된 정보는 다음과 같습니다. 이름은 $name, 전화번호는 $phone, 주소는 $address, 보호자 연락처는 $guardianPhone 입니다.');
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VoiceCommandScreen(
              passedCommand: command,
              isHeavyRain: widget.isHeavyRain, // ✅ 폭우 상태 전달
            ),
          ),
        );
      }
    }
  }

  Future<String?> _listenWithCancelCheck(String prompt) async {
    await _ttsService.speak(prompt);
    final input = await _speechService.listen();
    if (input.toLowerCase().contains('입력 취소')) {
      await _ttsService.speak('입력이 취소되었습니다.');
      return null;
    }
    return input;
  }

  Future<void> _startInfoRegistration() async {
    final prefs = await SharedPreferences.getInstance();

    final newName = await _listenWithCancelCheck('내 정보를 등록 합니다. 이름을 말씀해주세요.');
    if (newName == null) return;
    prefs.setString('name', newName);

    final newPhone = await _listenWithCancelCheck('전화번호를 말씀해주세요.');
    if (newPhone == null) return;
    prefs.setString('phone', newPhone);

    final newAddress = await _listenWithCancelCheck('주소를 말씀해주세요.');
    if (newAddress == null) return;
    prefs.setString('address', newAddress);

    final newGuardianPhone = await _listenWithCancelCheck('보호자 연락처를 말씀해주세요.');
    if (newGuardianPhone == null) return;
    prefs.setString('guardianPhone', newGuardianPhone);

    setState(() {
      name = newName;
      phone = newPhone;
      address = newAddress;
      guardianPhone = newGuardianPhone;
    });

    await _ttsService.speak(
        '모든 정보가 등록되었습니다. 등록된 정보는 다음과 같습니다. 이름은 $name, 전화번호는 $phone, 주소는 $address, 보호자 연락처는 $guardianPhone 입니다.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('마이페이지'),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('내 정보',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 20),
                  _infoRow(Icons.person, '이름', name),
                  _infoRow(Icons.phone, '전화번호', phone),
                  _infoRow(Icons.home, '주소', address),
                  _infoRow(Icons.shield, '보호자 연락처', guardianPhone),
                ],
              ),
            ),
            SizedBox(height: 24),
            GestureDetector(
              onTap: _handleVoiceCommand,
              child: Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '🎤 음성 명령 실행하기',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Text(
            '$label: $value',
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
