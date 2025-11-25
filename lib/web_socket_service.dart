// === web_socket_service.dart (最终心跳版 - 完整代码) ===

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// 定义一个简单的新消息模型，用于事件传递
class NewMessageEvent {
  final int conversationId;
  final int senderId;
  final String content;

  NewMessageEvent({
    required this.conversationId,
    required this.senderId,
    required this.content,
  });
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  final ValueNotifier<NewMessageEvent?> newMessageNotifier = ValueNotifier(null);
  bool _isConnected = false;
  Timer? _heartbeatTimer; // 心跳定时器

  void connect(int userId) {
    if (_isConnected) {
      print("--- [WebSocket] 连接已存在，无需重复连接。");
      return;
    }

    final uri = Uri.parse('ws://192.168.23.18:3000?userId=$userId');
    // 【新增日志】
    print("--- [WebSocket][探针] 准备连接到地址: $uri");

    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      print("--- [WebSocket] WebSocketChannel.connect() 调用成功，正在等待流事件...");

      _startHeartbeat();

      _channel!.stream.listen(
            (data) {
          print("--- [WebSocket] 前端收到原始数据: $data");
          try {
            final message = json.decode(data);
            if (message['type'] == 'newMessage') {
              print("--- [WebSocket] 确认是新消息类型，准备通知监听者...");
              final payload = message['payload'];
              newMessageNotifier.value = NewMessageEvent(
                conversationId: payload['conversationId'],
                senderId: payload['senderId'],
                content: payload['content'],
              );
              // 重置 notifier 的值，以便下次相同内容的通知也能被触发
              newMessageNotifier.value = null;
            }
          } catch (e) {
            print("--- [WebSocket][错误] 前端解析数据失败: $e");
          }
            },
        onDone: () {
          print("--- [WebSocket][探针] onDone 事件触发：连接已正常关闭。");
          _handleDisconnect();
        },
        onError: (error) {
          // 【核心改造】打印更详细的错误
          print("--- [WebSocket][探针][严重错误] onError 事件触发: $error");
          _handleDisconnect();
        },
        cancelOnError: true, // 【新增】一旦出错，就自动取消订阅
      );
    } catch (e) {
      print("--- [WebSocket][探针][严重错误] WebSocketChannel.connect() 调用时直接抛出异常: $e");
      _isConnected = false;
    }
  }

  void disconnect() {
    if (_isConnected) {
      print("--- [WebSocket] 已主动断开连接");
      _handleDisconnect();
    }
  }

  // 【新增】统一处理断开连接的逻辑
  void _handleDisconnect() {
    _stopHeartbeat();
    _channel?.sink.close();
    _isConnected = false;
  }

  // 【新增】启动心跳的函数
  void _startHeartbeat() {
    // 先取消可能存在的旧定时器
    _heartbeatTimer?.cancel();
    // 创建新的定时器
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_isConnected) {
        final pingMessage = json.encode({'type': 'ping'});
        _channel?.sink.add(pingMessage);
        print("--- [WebSocket] >-- 发送心跳: $pingMessage");
      }
    });
  }

  // 【新增】停止心跳的函数
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    print("--- [WebSocket] 心跳已停止。");
  }
}