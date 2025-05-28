// ✅ WebSocketService (singleton)
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();

  factory WebSocketService() {
    return _instance;
  }

  WebSocketService._internal();

  WebSocketChannel? _channel;
  final _controller = StreamController<String>.broadcast();
  bool _isConnected = false;

  final String _url = 'ws://172.31.89.39:8000/ws?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyIiwiZXhwIjoxNzQ4NDE3ODk4fQ.e0RJ6DcvRsUsCOCf-auSSz2m4vE9c-s8ANJRPyXOziQ';

  void connect() {
    if (_isConnected) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url));
      _isConnected = true;
      print("✅ WebSocket 연결됨: $_url");

      _channel!.stream.listen(
            (message) {
          print("📥 수신된 메시지: $message");
          _controller.add(message);
        },
        onError: (error) {
          print("❌ WebSocket 오류: $error");
          _isConnected = false;
          _controller.addError(error);
        },
        onDone: () {
          print("🛑 WebSocket 연결 종료됨");
          _isConnected = false;
        },
      );
    } catch (e) {
      print("🚫 WebSocket 연결 실패: $e");
    }
  }

  void send(String message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(message);
      print("📤 WebSocket 전송: $message");
    } else {
      print("⚠️ WebSocket 연결 안 됨: 메시지 전송 실패");
    }
  }

  void disconnect() {
    if (_isConnected && _channel != null) {
      _channel!.sink.close(status.goingAway);
      _isConnected = false;
      print("🔌 WebSocket 연결 해제됨");
    }
  }

  Stream<String> get stream => _controller.stream;
  bool get isConnected => _isConnected;
}
