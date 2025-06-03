import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import 'voice_command_screen.dart';

class MyPageScreen extends StatefulWidget {
  final bool isHeavyRain;

  const MyPageScreen({Key? key, this.isHeavyRain = false}) : super(key: key);

  @override
  _MyPageScreenState createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> with TickerProviderStateMixin {
  final SpeechService _speechService = SpeechService();
  final TTSService _ttsService = TTSService();

  String name = '';
  String phone = '';
  String address = '';
  String guardianPhone = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadUserInfo();
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
        "마이페이지입니다. "
            "상단에는 등록된 개인정보가 표시되고, "
            "하단의 음성 명령 버튼을 터치하여 정보를 등록하거나 수정할 수 있습니다."
    );
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
    HapticFeedback.heavyImpact();
    await _ttsService.speak('명령을 말씀해주세요.');
    final command = await _speechService.listen();

    print('음성 인식 결과: $command');

    final cleanCommand = command.toLowerCase().trim();

    if (cleanCommand.contains('등록')) {
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
              isHeavyRain: widget.isHeavyRain,
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
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '마이페이지',
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
        child: SafeArea(
          child: Column(
            children: [
              // 정보 표시 영역 (40% 비율)
              Expanded(
                flex: 40,
                child: _buildCompactInfoDisplay(),
              ),

              // 음성 명령 버튼 (60% 비율)
              Expanded(
                flex: 60,
                child: _buildVoiceCommandButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactInfoDisplay() {
    return Container(
      margin: EdgeInsets.fromLTRB(15, 10, 15, 10),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green[300]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 5),
            spreadRadius: 1,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.person_rounded, color: Colors.green[700], size: 24),
                  SizedBox(width: 10),
                  Text(
                    '내 정보',
                    style: GoogleFonts.roboto(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ],
              ),
            ),

            // 구분선
            Divider(color: Colors.green[300], thickness: 1),
            SizedBox(height: 12),

            // 정보 목록
            _buildInfoItem('이름', name),
            _buildInfoItem('전화번호', phone),
            _buildInfoItem('주소', address),
            _buildInfoItem('보호자 연락처', guardianPhone),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    bool isRegistered = value != '미등록';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라벨 - 너비 증가 및 텍스트 줄바꿈 방지
          Container(
            width: 130,
            child: Text(
              '$label:',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green[800],
              ),
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
            ),
          ),

          // 값
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isRegistered ? Colors.green[700] : Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),

          // 상태 아이콘
          SizedBox(width: 8),
          Icon(
            isRegistered ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isRegistered ? Colors.green[600] : Colors.grey[400],
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceCommandButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GestureDetector(
            onTap: _handleVoiceCommand,
            child: Container(
              margin: EdgeInsets.fromLTRB(15, 5, 15, 15),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green[300]!, Colors.green[500]!, Colors.green[700]!],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white, width: 5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    blurRadius: 25,
                    offset: Offset(0, 10),
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 마이크 아이콘
                  Container(
                    padding: EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),

                  SizedBox(height: 20),

                  // 메인 텍스트
                  Text(
                    '음성 명령',
                    style: GoogleFonts.roboto(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),

                  SizedBox(height: 10),

                  // 설명 텍스트
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      '터치하여 정보 등록 또는\n음성 명령을 시작하세요',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.4,
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
