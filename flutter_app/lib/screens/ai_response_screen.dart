import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/tts_service.dart';
import 'main_screen.dart';
import 'dart:async';
import 'dart:math' as math;

class AiResponseScreen extends StatefulWidget {
  final String aiReply;

  const AiResponseScreen({Key? key, required this.aiReply}) : super(key: key);

  @override
  _AiResponseScreenState createState() => _AiResponseScreenState();
}

class _AiResponseScreenState extends State<AiResponseScreen>
    with TickerProviderStateMixin {
  final TTSService _ttsService = TTSService();

  // 애니메이션 컨트롤러들
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _glowController;
  late AnimationController _typewriterController;

  // 애니메이션들
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _typewriterAnimation;

  Timer? _returnTimer;
  String _displayedText = '';
  bool _isTyping = true;
  bool _isSpeaking = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _validateInput();
    _initAnimations();
    _startTypewriterEffect();
  }

  // 입력값 검증
  void _validateInput() {
    if (widget.aiReply.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = '응답 내용이 없습니다.';
      });
      _returnToMainWithDelay();
      return;
    }

    // 너무 긴 메시지 처리 (예: 1000자 이상)
    if (widget.aiReply.length > 1000) {
      print('⚠️ 긴 메시지 감지: ${widget.aiReply.length}자');
    }
  }

  void _initAnimations() {
    // AI 아바타 펄스 애니메이션
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // 음성 파형 애니메이션
    _waveController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));

    // 글로우 효과 애니메이션
    _glowController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // 타이핑 효과 애니메이션 (최소 1초, 최대 5초)
    final typingDuration = math.min(
        math.max(widget.aiReply.length * 50, 1000),
        5000
    );

    _typewriterController = AnimationController(
      duration: Duration(milliseconds: typingDuration),
      vsync: this,
    );

    _typewriterAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _typewriterController,
      curve: Curves.easeOut,
    ));
  }

  void _startTypewriterEffect() {
    if (_hasError) return;

    _typewriterController.addListener(() {
      if (mounted) {
        final progress = _typewriterAnimation.value;
        final targetLength = (widget.aiReply.length * progress).round();

        setState(() {
          _displayedText = widget.aiReply.substring(0, targetLength);
        });
      }
    });

    _typewriterController.forward().then((_) {
      if (mounted && !_hasError) {
        setState(() {
          _isTyping = false;
        });
        _speakAndReturn();
      }
    });
  }

  Future<void> _speakAndReturn() async {
    if (!mounted || _hasError) return;

    setState(() {
      _isSpeaking = true;
    });

    try {
      _waveController.repeat();

      // TTS 재생 시도
      await _ttsService.speak(widget.aiReply);

      print('✅ TTS 재생 완료: ${widget.aiReply.substring(0, math.min(50, widget.aiReply.length))}...');

    } catch (e) {
      print('❌ TTS 재생 오류: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'TTS 재생 중 오류가 발생했습니다.';
      });
    } finally {
      if (mounted) {
        _waveController.stop();
        setState(() {
          _isSpeaking = false;
        });

        // 성공/실패 관계없이 메인으로 복귀
        _returnToMainWithDelay();
      }
    }
  }

  void _returnToMainWithDelay() {
    _returnTimer = Timer(Duration(seconds: _hasError ? 3 : 1), () {
      if (mounted) {
        print('🔄 메인 화면으로 복귀');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainScreen()),
              (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    print('🗑️ AiResponseScreen dispose 호출');
    _pulseController.dispose();
    _waveController.dispose();
    _glowController.dispose();
    _typewriterController.dispose();
    _ttsService.stop();
    _returnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'AI 어시스턴트',
          style: GoogleFonts.orbitron(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.green[700] ?? Colors.green,
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
            colors: [
              Colors.green[50] ?? Colors.green.shade50,
              Colors.white,
              Colors.green[50] ?? Colors.green.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                SizedBox(height: 20),

                // AI 아바타 섹션
                _buildAiAvatar(),

                SizedBox(height: 40),

                // AI 응답 말풍선 또는 오류 메시지
                Expanded(
                  child: _hasError ? _buildErrorMessage() : _buildResponseBubble(),
                ),

                SizedBox(height: 30),

                // 음성 파형 표시
                if (_isSpeaking) _buildVoiceWave(),

                // 상태별 안내 텍스트
                _buildStatusMessage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.red[200] ?? Colors.red, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red[600],
          ),
          SizedBox(height: 20),
          Text(
            _errorMessage,
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.red[800],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage() {
    String message = '';
    Color color = Colors.green[600] ?? Colors.green;

    if (_hasError) {
      message = "오류가 발생했습니다. 잠시 후 메인 화면으로 돌아갑니다...";
      color = Colors.red[600] ?? Colors.red;
    } else if (_isSpeaking) {
      message = "AI가 응답을 읽어드리고 있습니다...";
    } else if (!_isTyping) {
      message = "잠시 후 메인 화면으로 돌아갑니다...";
    }

    if (message.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          message,
          style: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: color,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SizedBox.shrink();
  }

  Widget _buildAiAvatar() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              final avatarColor = _hasError ? Colors.red : Colors.green;
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (avatarColor[400] ?? avatarColor).withOpacity(_glowAnimation.value),
                      (avatarColor[600] ?? avatarColor).withOpacity(_glowAnimation.value * 0.7),
                      (avatarColor[800] ?? avatarColor).withOpacity(_glowAnimation.value * 0.5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: avatarColor.withOpacity(_glowAnimation.value * 0.6),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Container(
                  margin: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: avatarColor[300] ?? avatarColor, width: 3),
                  ),
                  child: Icon(
                    _hasError ? Icons.error_outline : Icons.psychology_rounded,
                    size: 60,
                    color: avatarColor[700] ?? avatarColor,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildResponseBubble() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(0),
      child: Stack(
        children: [
          // 말풍선 배경
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: 15),
            padding: EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green[50] ?? Colors.green.shade50,
                  Colors.white,
                  Colors.green[50] ?? Colors.green.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.green[200] ?? Colors.green, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.15),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI 라벨
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[100] ?? Colors.green.shade100,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.green[300] ?? Colors.green, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Colors.green[700] ?? Colors.green,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'AI 응답',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700] ?? Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // 응답 텍스트
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayedText,
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.green[900] ?? Colors.green.shade900,
                            height: 1.5,
                          ),
                        ),

                        // 타이핑 커서
                        if (_isTyping)
                          AnimatedBuilder(
                            animation: _glowController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _glowAnimation.value,
                                child: Text(
                                  '|',
                                  style: GoogleFonts.roboto(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green[700] ?? Colors.green,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 말풍선 꼬리
          Positioned(
            top: 0,
            left: 40,
            child: CustomPaint(
              size: Size(30, 20),
              painter: BubbleTailPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceWave() {
    return Container(
      height: 60,
      child: AnimatedBuilder(
        animation: _waveAnimation,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final delay = index * 0.2;
              final animationValue = (_waveAnimation.value + delay) % 1.0;
              final height = 10 + (math.sin(animationValue * math.pi * 2) * 20).abs();

              return Container(
                width: 4,
                height: height,
                margin: EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.green[600] ?? Colors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// 말풍선 꼬리를 그리는 커스텀 페인터
class BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green[50] ?? Colors.green.shade50
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.green[200] ?? Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
