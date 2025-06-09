import 'package:http/http.dart' as http;
import 'websocket_service.dart';
import 'tts_service.dart';

class VoiceCommandService {
  final WebSocketService _webSocketService = WebSocketService();
  final TTSService _ttsService = TTSService();

  // 연결 상태 확인 후 명령 처리
  Future<CommandResult> processCommand(String command) async {
    print("🎯 명령 처리 시작: $command");

    // 1. 연결 상태 확인
    if (!_webSocketService.isConnected) {
      print("❌ WebSocket 연결되지 않음");
      return CommandResult(
        success: false,
        error: "서버에 연결되지 않았습니다.",
        errorType: CommandErrorType.connectionError,
      );
    }

    // 2. 연결 테스트
    bool connectionTest = await _webSocketService.testConnection();
    if (!connectionTest) {
      print("❌ 연결 테스트 실패");
      return CommandResult(
        success: false,
        error: "서버 연결이 불안정합니다.",
        errorType: CommandErrorType.connectionError,
      );
    }

    // 3. 텍스트 명령 전송
    bool sendSuccess = _webSocketService.send(command);
    if (!sendSuccess) {
      print("❌ 명령 전송 실패");
      return CommandResult(
        success: false,
        error: "명령 전송에 실패했습니다.",
        errorType: CommandErrorType.sendError,
      );
    }

    print("✅ 명령 전송 성공");
    return CommandResult(success: true);
  }

  // 서버 상태 확인 (텍스트 응답)
  Future<String?> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('http://172.31.88.189:8000/status'),
        headers: {'Accept': 'text/plain'}, // JSON 대신 텍스트
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        print("📥 상태 수신: ${response.body}");
        return response.body; // 텍스트 그대로 반환
      } else {
        print("⚠️ 상태 요청 실패: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ 상태 요청 오류: $e");
      return null;
    }
  }

  // 연결 상태 확인
  Future<bool> checkServerConnection() async {
    try {
      final response = await http.get(
        Uri.parse('http://172.31.88.189:8000/status'),
        headers: {'Accept': 'text/plain'}, // JSON 대신 텍스트
      ).timeout(Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print("❌ 서버 연결 확인 실패: $e");
      return false;
    }
  }
}

// 명령 결과 클래스
class CommandResult {
  final bool success;
  final String? error;
  final CommandErrorType? errorType;

  CommandResult({
    required this.success,
    this.error,
    this.errorType,
  });
}

// 오류 타입 열거형
enum CommandErrorType {
  connectionError,  // 연결 오류
  sendError,       // 전송 오류
  timeoutError,    // 타임아웃 오류
  serverError,     // 서버 오류
}
