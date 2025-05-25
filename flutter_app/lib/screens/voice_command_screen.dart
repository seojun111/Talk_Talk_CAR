// 수정된 voice_command_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/voice_command_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import 'mypage.dart';
import 'dart:async';
import '../widget/voice_wave_animation_widget.dart';

class VoiceCommandService {
  /// 명령을 처리하는 중이라는 시뮬레이션용 딜레이 후 실제 전송
  Future<void> processCommand(String command) async {
    await Future.delayed(Duration(seconds: 1));
    await sendCommand(command); // ✅ 실제 명령 전송
  }

  /// 명령을 백엔드 서버로 전송
  Future<void> sendCommand(String cmd) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8080/command'),
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

  /// 센서 상태 조회 요청 (예: 연료 상태, 전압 등)
  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/status'),
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
