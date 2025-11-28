// === web_socket_service.dart (支持多媒体消息通知版) ===

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// 1. 【核心修改】扩展事件模型，支持媒体类型
class NewMessageEvent {
  final int conversationId;
  final int senderId;
  final String content;
  final String messageType; // 'text', 'image', 'video'
  final String? mediaUrl;

  NewMessageEvent({
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.mediaUrl,
  });
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  final ValueNotifier<NewMessageEvent?> newMessageNotifier = ValueNotifier(null);
  bool _isConnected = false;
  Timer? _heartbeatTimer;

  void connect(int userId) {
    if (_isConnected) {
      print("--- [WebSocket] 连接已存在，无需重复连接。");
      return;
    }

    // ！！！！请务必确认 IP 地址正确！！！！
    final uri = Uri.parse('ws://192.168.23.18:3000?userId=$userId');
    print("--- [WebSocket][探针] 准备连接到地址: $uri");

    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      print("--- [WebSocket] 连接成功，等待消息...");

      _startHeartbeat();

      _channel!.stream.listen(
            (data) {
          // print("--- [WebSocket] 收到数据: $data"); // 调试用，太长可以注释掉
          try {
            final message = json.decode(data);

            // 2. 【核心修改】解析 newMessage 并提取多媒体字段
            if (message['type'] == 'newMessage') {
              print("--- [WebSocket] 收到新消息通知");
              final payload = message['payload'];

              newMessageNotifier.value = NewMessageEvent(
                conversationId: payload['conversationId'],
                senderId: payload['senderId'],
                content: payload['content'], // 这里的 content 是 "[图片]" 或 "[视频]"
                messageType: payload['messageType'] ?? 'text', // 获取类型
                mediaUrl: payload['mediaUrl'], // 获取链接
              );

              // 重置通知，确保连续收到相同消息也能触发监听
              newMessageNotifier.value = null;
            }
            else if (message['type'] == 'notification') {
              // 这里其实不需要 payload 存什么，只要触发一下 value 变动，
              // PhotoGalleryPage 监听到变动就会去 fetch unread count
              // 为了方便，你可以复用 newMessageNotifier，或者新建一个 notificationNotifier
              // 偷懒做法：发一个空的事件触发监听
              newMessageNotifier.value = NewMessageEvent(conversationId: 0, senderId: 0, content: "");
              newMessageNotifier.value = null;
            }
          } catch (e) {
            print("--- [WebSocket][错误] 解析数据失败: $e");
          }
        },
        onDone: () {
          print("--- [WebSocket] 连接断开(onDone)");
          _handleDisconnect();
        },
        onError: (error) {
          print("--- [WebSocket] 连接错误: $error");
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      print("--- [WebSocket] 连接异常: $e");
      _isConnected = false;
    }
  }

  void disconnect() {
    if (_isConnected) {
      print("--- [WebSocket] 主动断开");
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _stopHeartbeat();
    _channel?.sink.close();
    _isConnected = false;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_isConnected) {
        // 发送简单的心跳包
        _channel?.sink.add(json.encode({'type': 'ping'}));
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}