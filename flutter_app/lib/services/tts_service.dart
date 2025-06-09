import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;

  TTSService() {
    _init();
  }

  Future<void> _init() async {
    await flutterTts.setLanguage("ko-KR");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(2.0);
    await flutterTts.awaitSpeakCompletion(true);

    // TTS 상태 모니터링
    flutterTts.setStartHandler(() {
      _isSpeaking = true;
      print("🔊 TTS 시작");
    });

    flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      print("✅ TTS 완료");
    });

    flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      print("❌ TTS 오류: $msg");
    });

    // 웹 환경에서 음성 설정
    try {
      List<dynamic> voices = await flutterTts.getVoices;
      if (voices.isNotEmpty) {
        var koreanVoice = voices.firstWhere(
              (v) => v['locale'] == "ko-KR",
          orElse: () => voices.first,
        );
        await flutterTts.setVoice({
          "name": koreanVoice['name'],
          "locale": koreanVoice['locale']
        });
        print("🔊 음성 설정 완료: ${koreanVoice['name']}");
      }
    } catch (e) {
      print("⚠️ TTS 음성 설정 실패: $e");
    }
  }

  Future<void> speak(String text) async {
    try {
      // 기존 TTS 중단 후 새로운 TTS 시작
      if (_isSpeaking) {
        await stop();
        await Future.delayed(Duration(milliseconds: 100)); // 잠시 대기
      }

      print("🔊 말하기: $text");
      await flutterTts.speak(text);
    } catch (e) {
      print("❌ TTS 오류: $e");
      _isSpeaking = false;
    }
  }

  Future<void> stop() async {
    try {
      await flutterTts.stop();
      _isSpeaking = false;
      print("🛑 TTS 중단");
    } catch (e) {
      print("❌ TTS 중단 오류: $e");
    }
  }

  bool get isSpeaking => _isSpeaking;
}
