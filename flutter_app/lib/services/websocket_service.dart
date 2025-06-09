import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();

  factory WebSocketService() {
    return _instance;
  }

  WebSocketService._internal();

  WebSocketChannel? _channel;
  final _controller = StreamController<String>.broadcast();
  bool _isConnected = false;

  final String _url = 'ws://172.31.88.189:8000/ws?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyIiwiZXhwIjoxNzQ5NDYwNzc0fQ.FtlQHYA6c47zVIqFahe2U3V2AqvJ8Ei0VmE4h5fgn6I';

  // 연결 상태 확인
  bool get isConnected => _isConnected && _channel != null;

  void connect() {
    if (_isConnected) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url));
      _isConnected = true;
      print("✅ WebSocket 연결됨: $_url");

      _channel!.stream.listen(
            (message) {
          print("📥 수신된 텍스트 메시지: $message");
          // 텍스트 메시지 그대로 전달
          _controller.add(message.toString());
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
      _isConnected = false;
    }
  }

  // 텍스트 메시지 전송
  bool send(String message) {
    if (!isConnected) {
      print("⚠️ WebSocket 연결 안 됨: 메시지 전송 실패");
      return false;
    }

    try {
      _channel!.sink.add(message); // 텍스트 그대로 전송
      print("📤 WebSocket 텍스트 전송 성공: $message");
      return true;
    } catch (e) {
      print("❌ WebSocket 전송 오류: $e");
      _isConnected = false;
      return false;
    }
  }

  // 연결 상태 테스트 (ping 없이 연결 상태만 확인)
  Future<bool> testConnection() async {
    // ping 전송 없이 단순히 연결 상태만 확인
    bool connectionStatus = isConnected;
    print(connectionStatus ? "✅ 연결 테스트 성공" : "❌ 연결 테스트 실패");
    return connectionStatus;
  }

  void disconnect() {
    if (_isConnected && _channel != null) {
      _channel!.sink.close(1000); // 정상 종료 코드
      _isConnected = false;
      print("🔌 WebSocket 연결 해제됨");
    }
  }

  Stream<String> get stream => _controller.stream;
}
