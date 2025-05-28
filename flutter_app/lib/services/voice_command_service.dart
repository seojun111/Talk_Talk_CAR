
// ✅ VoiceCommandService
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'websocket_service.dart';

class VoiceCommandService {
  final WebSocketService _webSocketService = WebSocketService();

  Future<void> processCommand(String command) async {
    // REST 전송
    //await sendCommand(command);
    // WebSocket 전송
    _webSocketService.send(command);
    await Future.delayed(Duration(seconds: 1));
  }
/*
  Future<void> sendCommand(String cmd) async {
    try {
      final response = await http.post(
        Uri.parse('http://172.31.89.39:8000/ai_command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ai_command': cmd}),
      );

      if (response.statusCode == 200) {
        print("📤 REST 전송 성공: $cmd");
      } else {
        print("⚠️ REST 전송 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ REST 전송 오류: $e");
    }
  }
*/
  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('http://172.31.89.39:8000/status'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("📥 상태 수신: $data");
        return data;
      } else {
        print("⚠️ 상태 요청 실패: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ 상태 요청 오류: $e");
      return null;
    }
  }
}
