import 'dart:convert';
import 'package:http/http.dart' as http;

class VoiceCommandService {
  Future<void> processCommand(String command) async {
    await Future.delayed(Duration(seconds: 1));
  }

  Future<void> sendCommand(String cmd) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.10:8000/command'), // ✅ 실제 서버 IP 사용
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': cmd}),
      );

      if (response.statusCode == 200) {
        print("📤 명령 전송 성공: $cmd");
      } else {
        print("⚠️ 명령 전송 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ 명령 전송 오류: $e");
    }
  }

  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.10:8000/status'), // ✅ 실제 서버 IP 사용
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
