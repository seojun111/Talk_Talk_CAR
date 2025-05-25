// lib/services/speech_service.dart (Completer 완료 보장 강화 버전)
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'dart:async';
import 'tts_service.dart';

class SpeechService {
  final stt.SpeechToText _speech;
  final TTSService _ttsService = TTSService();
  bool _isInitialized = false;
  bool _serviceIsListening = false; // 서비스 내부 리스닝 상태 플래그

  Completer<String>? _speechCompleter; // 현재 listen() 호출에 대한 Completer

  SpeechService() : _speech = stt.SpeechToText() {
    _initialize();
  }

  // 전역 상태 변경 콜백 (initialize에 전달)
  void _onSttStatus(String status) {
    print('STT 전역 상태: $status');
    _serviceIsListening = _speech.isListening; // 플러그인 상태로 업데이트
    if (status == stt.SpeechToText.notListeningStatus || status == stt.SpeechToText.doneStatus) {
      if (_serviceIsListening) _serviceIsListening = false; // 상태 동기화
    }
  }

  // 전역 오류 콜백 (initialize에 전달)
  void _onSttError(SpeechRecognitionError errorNotification) {
    print('!!! STT 전역 오류: ${errorNotification.errorMsg}, 영구적: ${errorNotification.permanent}');
    _completeListenSession(error: errorNotification.errorMsg ?? "STT System Error");
    if (errorNotification.permanent) {
      _isInitialized = false;
    }
  }

  Future<bool> _initialize() async {
    if (_isInitialized && _speech.isAvailable) return true;
    print("STT 초기화 시도...");
    _isInitialized = await _speech.initialize(
      onError: _onSttError,
      onStatus: _onSttStatus,
    );
    print(_isInitialized ? "STT 초기화 성공" : "STT 초기화 실패");
    return _isInitialized;
  }

  bool get isListening => _serviceIsListening;
  bool get isAvailable => _isInitialized && _speech.isAvailable;

  void _completeListenSession({String? words, dynamic error}) {
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      if (error != null) {
        print("STT Completer 오류로 완료: $error");
        _speechCompleter!.completeError(error);
      } else {
        print("STT Completer 성공으로 완료: '${words ?? ""}'");
        _speechCompleter!.complete(words ?? "");
      }
    }
    _serviceIsListening = false;
  }

  Future<String> listen({String localeId = "ko_KR", int listenTimeOutInSeconds = 12}) async {
    if (!_isInitialized || !_speech.isAvailable) {
      print("STT 준비 안됨. 초기화 시도...");
      bool success = await _initialize();
      if (!success || !_speech.isAvailable) {
        print("STT 초기화/사용 불가");
        await _ttsService.speak("음성 인식 서비스를 사용할 수 없습니다.");
        return Future.error("STT_UNAVAILABLE");
      }
    }

    if (_serviceIsListening) {
      print("이미 리스닝 중. 이전 세션 취소.");
      await cancelListening();
    }

    _speechCompleter = Completer<String>();
    _serviceIsListening = true;
    print("STT 리스닝 시작...");

    final timeoutTimer = Timer(Duration(seconds: listenTimeOutInSeconds), () {
      print("자체 타임아웃 ($listenTimeOutInSeconds초) 발생.");
      if (_speech.isListening) {
        _speech.stop();
      }
      _completeListenSession(words: "");
    });

    try {
      _speech.listen(
        localeId: localeId,
        onResult: (result) {
          print('STT onResult: words="${result.recognizedWords}", final=${result.finalResult}');
          if (result.finalResult) {
            timeoutTimer.cancel();
            _completeListenSession(words: result.recognizedWords);
          }
        },
        listenFor: Duration(seconds: 10),
        pauseFor: Duration(seconds: 3),
        onSoundLevelChange: (level) {},
        cancelOnError: true,
      );
    } catch (e, s) {
      print("!!! _speech.listen 호출 중 오류: $e");
      print(s);
      timeoutTimer.cancel();
      _completeListenSession(error: "_speech.listen_CALL_FAILED: $e");
    }

    return _speechCompleter!.future.whenComplete(() {
      print("listen() Future 완료됨.");
      if (timeoutTimer.isActive) {
        timeoutTimer.cancel();
      }
    });
  }

  Future<void> stopListening() async {
    print("stopListening 호출됨");
    if (_speech.isListening) {
      _speech.stop();
    }
    _completeListenSession(words: "");
  }

  Future<void> cancelListening() async {
    print("cancelListening 호출됨");
    if (_speech.isListening) {
      _speech.cancel();
    }
    _completeListenSession(error: "사용자에 의해 취소됨");
  }
}