import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/voice_command_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../services/websocket_service.dart';
import 'mypage.dart';
import 'ai_response_screen.dart';
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
  Timer? _responseTimeout;
  int _remainingSeconds = 10;
  StreamSubscription<String>? _webSocketSubscription;

  // 화면 상태 추적
  bool _isDisposed = false;
  bool _isNavigating = false;

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

    // WebSocket 메시지 구독 - 안전한 처리
    _webSocketSubscription = _webSocketService.stream.listen(
          (message) async {
        print("📥 WebSocket 메시지 수신: $message");

        // 안전성 체크
        if (_isDisposed || _isNavigating || !mounted) {
          print("⚠️ 화면이 이미 dispose되었거나 네비게이션 중입니다.");
          return;
        }

        _cancelResponseTimeout();
        _setNavigating(true);

        try {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AiResponseScreen(aiReply: message),
            ),
          );
        } catch (e) {
          print("❌ 네비게이션 오류: $e");
          _setNavigating(false);
        }
      },
      onError: (error) {
        print("❌ WebSocket 스트림 오류: $error");
        if (!_isDisposed && mounted) {
          _handleConnectionError();
        }
      },
    );

    if (widget.passedCommand != null) {
      _handlePassedCommand(widget.passedCommand!);
    } else {
      _startFlowAfterTTS();
    }
  }

  // 네비게이션 상태 설정
  void _setNavigating(bool navigating) {
    if (!_isDisposed) {
      _isNavigating = navigating;
    }
  }

  // 안전한 setState
  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  Future<void> _startFlowAfterTTS() async {
    if (_isDisposed) return;

    if (widget.isHeavyRain) {
      await _ttsService.speak("현재 폭우로 인해 자율주행 관련 기능은 사용 불가합니다.");
      await Future.delayed(Duration(milliseconds: 300));
    }

    if (_isDisposed) return;
    await _ttsService.speak("명령을 말씀해주세요.");

    if (_isDisposed) return;
    await Future.delayed(Duration(milliseconds: 100));

    if (_isDisposed) return;
    _startListeningTimer();
    _startSTT();
  }

  Future<void> _startSTT() async {
    if (_isDisposed) return;

    final result = await _speechService.listen();

    if (_isDisposed) return;

    if (result.isNotEmpty) {
      _recognizedText = result;
      _cancelListeningTimer();
      _startVoiceCommandFlow();
    } else {
      _safeNavigateBack();
    }
  }

  Future<void> _handlePassedCommand(String command) async {
    if (_isDisposed) return;

    if (_checkNavigateToMyPage(command)) {
      await _navigateToMyPage();
      return;
    }

    _safeSetState(() {
      _state = 'recognized';
      _recognizedText = command;
      _isListening = false;
    });

    if (_isDisposed) return;
    await _ttsService.speak("인식 결과는 $command 입니다.");

    if (_isDisposed) return;
    await Future.delayed(Duration(seconds: 2));

    if (_isDisposed) return;
    await _executeCommandWithConnectionCheck();
  }

  void _startVoiceCommandFlow() async {
    if (_isDisposed) return;

    if (_checkNavigateToMyPage(_recognizedText)) {
      await _navigateToMyPage();
      return;
    }

    _safeSetState(() {
      _state = 'recognized';
      _isListening = false;
    });

    if (_isDisposed) return;
    await _ttsService.speak("인식 결과는 $_recognizedText 입니다.");

    if (_isDisposed) return;
    await Future.delayed(Duration(seconds: 2));

    if (_isDisposed) return;
    await _executeCommandWithConnectionCheck();
  }

  Future<void> _executeCommandWithConnectionCheck() async {
    if (_isDisposed) return;

    // 1. 연결 상태 사전 확인
    if (!_webSocketService.isConnected) {
      await _handleConnectionError();
      return;
    }

    // 2. 서버 연결 테스트
    bool serverConnected = await _voiceService.checkServerConnection();
    if (_isDisposed) return;

    if (!serverConnected) {
      await _ttsService.speak("서버에 연결할 수 없습니다. 네트워크 상태를 확인해주세요.");
      if (_isDisposed) return;

      _safeSetState(() {
        _state = 'connection_error';
      });
      _returnToMainAfterDelay();
      return;
    }

    _safeSetState(() {
      _state = 'executing';
    });

    if (_isDisposed) return;
    await _ttsService.speak("$_recognizedText 명령을 수행 중입니다.");

    if (_isDisposed) return;
    _startResponseTimeout();

    CommandResult result = await _voiceService.processCommand(_recognizedText);

    if (_isDisposed) return;

    if (!result.success) {
      _cancelResponseTimeout();
      await _handleCommandError(result);
    }
  }

  void _startResponseTimeout() {
    if (_isDisposed) return;

    _responseTimeout = Timer(Duration(seconds: 15), () {
      if (!_isDisposed && mounted && !_isNavigating) {
        print("⏰ 서버 응답 타임아웃");
        _handleTimeoutError();
      }
    });
  }

  void _cancelResponseTimeout() {
    _responseTimeout?.cancel();
    _responseTimeout = null;
  }

  Future<void> _handleTimeoutError() async {
    if (_isDisposed) return;

    _safeSetState(() {
      _state = 'timeout_error';
    });

    await _ttsService.speak("서버 응답이 없습니다. 잠시 후 다시 시도해주세요.");
    if (_isDisposed) return;

    _returnToMainAfterDelay();
  }

  Future<void> _handleConnectionError() async {
    if (_isDisposed) return;

    _safeSetState(() {
      _state = 'connection_error';
    });

    await _ttsService.speak("서버에 연결되지 않았습니다. 연결 상태를 확인해주세요.");
    if (_isDisposed) return;

    _returnToMainAfterDelay();
  }

  Future<void> _handleCommandError(CommandResult result) async {
    if (_isDisposed) return;

    _safeSetState(() {
      _state = 'command_error';
    });

    String errorMessage;
    switch (result.errorType) {
      case CommandErrorType.connectionError:
        errorMessage = "서버 연결에 문제가 있습니다.";
        break;
      case CommandErrorType.sendError:
        errorMessage = "명령 전송에 실패했습니다.";
        break;
      case CommandErrorType.timeoutError:
        errorMessage = "서버 응답 시간이 초과되었습니다.";
        break;
      case CommandErrorType.serverError:
        errorMessage = "서버에서 오류가 발생했습니다.";
        break;
      default:
        errorMessage = "알 수 없는 오류가 발생했습니다.";
    }

    await _ttsService.speak("$errorMessage 잠시 후 다시 시도해주세요.");
    if (_isDisposed) return;

    _returnToMainAfterDelay();
  }

  void _returnToMainAfterDelay() {
    if (_isDisposed || _isNavigating) return;

    Timer(Duration(seconds: 3), () {
      if (!_isDisposed && mounted && !_isNavigating) {
        _safeNavigateBack();
      }
    });
  }

  void _safeNavigateBack() {
    if (_isDisposed || _isNavigating) return;

    _setNavigating(true);
    try {
      Navigator.pop(context);
    } catch (e) {
      print("❌ 네비게이션 오류: $e");
    }
  }

  bool _checkNavigateToMyPage(String text) {
    return text.contains("마이페이지");
  }

  Future<void> _navigateToMyPage() async {
    if (_isDisposed || _isNavigating) return;

    await _ttsService.speak("마이페이지로 이동했습니다.");
    if (_isDisposed) return;

    _setNavigating(true);
    try {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyPageScreen(isHeavyRain: widget.isHeavyRain)),
      );
    } catch (e) {
      print("❌ 네비게이션 오류: $e");
      _setNavigating(false);
    }
  }

  void _startListeningTimer() {
    if (_isDisposed) return;

    _isListening = true;
    _remainingSeconds = 10;
    _listeningTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds > 0) {
        _safeSetState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        if (!_isDisposed && mounted && !_isNavigating) {
          _safeNavigateBack();
        }
      }
    });
  }

  void _cancelListeningTimer() {
    _listeningTimer?.cancel();
    _listeningTimer = null;
    if (!_isDisposed) {
      _safeSetState(() {
        _remainingSeconds = 10;
      });
    }
  }

  @override
  void dispose() {
    print('🗑️ VoiceCommandScreen dispose 시작');

    // 1. dispose 상태 설정 (가장 먼저!)
    _isDisposed = true;

    // 2. TTS 중지
    _ttsService.stop();

    // 3. 모든 타이머 취소
    _cancelListeningTimer();
    _cancelResponseTimeout();

    // 4. 애니메이션 컨트롤러 dispose
    _micAnimationController.dispose();

    // 5. WebSocket 구독 취소
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;

    print('🗑️ VoiceCommandScreen dispose 완료');
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
            if (_isNavigating) return; // 이미 네비게이션 중이면 무시

            HapticFeedback.mediumImpact();
            _cancelResponseTimeout();
            await _ttsService.speak("이전 화면으로 돌아갑니다.");

            if (!_isDisposed && mounted) {
              _safeNavigateBack();
            }
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
                    colors: _getStateColors(),
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white, width: 5),
                  boxShadow: [
                    BoxShadow(
                      color: _getStateColors()[0].withOpacity(0.3),
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
                    if (_isNavigating) return; // 이미 네비게이션 중이면 무시

                    HapticFeedback.heavyImpact();
                    _cancelListeningTimer();
                    _cancelResponseTimeout();
                    await _ttsService.speak("명령이 취소되었습니다.");

                    if (!_isDisposed && mounted) {
                      _safeNavigateBack();
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

  // 상태별 색상 반환
  List<Color> _getStateColors() {
    switch (_state) {
      case 'connection_error':
      case 'timeout_error':
      case 'command_error':
        return [Colors.red[400]!, Colors.red[600]!, Colors.red[800]!];
      default:
        return [Colors.green[400]!, Colors.green[600]!, Colors.green[800]!];
    }
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
                    child: Icon(
                      Icons.mic,
                      size: 100,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 30),
            Text('음성 인식 중...', style: _statusTextStyle()),
            SizedBox(height: 15),
            _buildProgressBar(),
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
              child: Icon(Icons.hearing, size: 80, color: Colors.white),
            ),
            SizedBox(height: 30),
            Text('인식 결과:', style: _statusTextStyle()),
            SizedBox(height: 15),
            _buildRecognizedTextBox(),
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
              child: Icon(Icons.settings, size: 80, color: Colors.white),
            ),
            SizedBox(height: 30),
            Text('명령 실행 중', style: _statusTextStyle()),
            SizedBox(height: 15),
            _buildRecognizedTextBox(),
            SizedBox(height: 20),
            _buildProgressBar(),
          ],
        );
        break;
      case 'connection_error':
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
              child: Icon(Icons.wifi_off, size: 80, color: Colors.white),
            ),
            SizedBox(height: 30),
            Text('연결 오류', style: _statusTextStyle()),
            SizedBox(height: 15),
            Text(
              '서버에 연결할 수 없습니다',
              style: GoogleFonts.roboto(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
        break;
      case 'timeout_error':
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
              child: Icon(Icons.timer_off, size: 80, color: Colors.white),
            ),
            SizedBox(height: 30),
            Text('응답 시간 초과', style: _statusTextStyle()),
            SizedBox(height: 15),
            Text(
              '서버 응답이 없습니다',
              style: GoogleFonts.roboto(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
        break;
      case 'command_error':
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
              child: Icon(Icons.error_outline, size: 80, color: Colors.white),
            ),
            SizedBox(height: 30),
            Text('명령 실행 오류', style: _statusTextStyle()),
            SizedBox(height: 15),
            Text(
              '명령 처리 중 오류가 발생했습니다',
              style: GoogleFonts.roboto(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
        break;
      default:
        content = SizedBox.shrink();
    }
    return content;
  }

  Widget _buildProgressBar() {
    return Container(
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
    );
  }

  Widget _buildRecognizedTextBox() {
    return Container(
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
    );
  }

  TextStyle _statusTextStyle() => GoogleFonts.roboto(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 1,
    shadows: [
      Shadow(
        color: Colors.black.withOpacity(0.5),
        offset: Offset(1, 1),
        blurRadius: 2,
      ),
    ],
  );
}
