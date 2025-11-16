// === ai_chat_page.dart (最终多会话版 - 完整代码) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 消息模型
class ChatMessage {
  final String role; // 'user' 或 'assistant'
  final String content;

  ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AiChatPage extends StatefulWidget {
  final int sessionId; // 【核心变化】接收会话ID，而不是用户ID
  final String sessionTitle; // 接收会话标题，用于显示在顶部

  const AiChatPage({
    super.key,
    required this.sessionId,
    required this.sessionTitle
  });

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isSending = false;
  bool _isHistoryLoading = true;

  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // 【核心改造】根据 sessionId 加载历史记录
  Future<void> _loadHistory() async {
    print("--- [前端探针] 正在加载会话 ${widget.sessionId} 的历史记录...");
    try {
      final response = await http.get(
          Uri.parse('$_apiUrl/api/chat/history/${widget.sessionId}')
      );

      if(mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List history = data['history'];
        if (history.isNotEmpty) {
          setState(() {
            _messages.clear();
            for (var item in history) {
              // 转换数据库中的 'model' 或 'assistant' 为统一格式
              String role = item['role'] == 'model' ? 'assistant' : item['role'];
              _messages.add(ChatMessage(role: role, content: item['content']));
            }
          });
          print("--- [前端探针] 历史记录加载完成，共 ${_messages.length} 条");
        }
      }
    } catch(e) {
      print("--- [前端探针][错误] 加载历史失败: $e");
    } finally {
      if(mounted) {
        setState(() { _isHistoryLoading = false; });
        _scrollToBottom();
      }
    }
  }

  // === 在 ai_chat_page.dart 中，用这个新函数替换旧的 _sendMessage 函数 ===

  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty || _isSending) return;

    final userMessage = ChatMessage(role: 'user', content: _textController.text);

    setState(() {
      _messages.add(userMessage);
      _isSending = true;
    });

    _textController.clear();
    _scrollToBottom();

    try {
      print("--- [前端探针] 正在向会话 ${widget.sessionId} 发送消息...");

      final response = await http.post(
        Uri.parse('$_apiUrl/api/chat/${widget.sessionId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'messages': _messages.map((msg) => msg.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 60)); // 保持60秒超时

      // --- 【核心改造 1：处理后端返回的非200错误】 ---
      if (mounted) {
        if (response.statusCode == 200) {
          final replyContent = json.decode(response.body)['reply'];
          final aiMessage = ChatMessage(role: 'assistant', content: replyContent);
          setState(() {
            _messages.add(aiMessage);
          });
        } else {
          // 如果后端返回了错误码（如 500），我们也显示一条错误消息
          final errorBody = json.decode(response.body);
          final errorMessage = ChatMessage(
              role: 'assistant',
              content: '抱歉，服务器开小差了 (错误: ${errorBody['message'] ?? '未知'})'
          );
          setState(() {
            _messages.add(errorMessage);
          });
        }
      }

    } catch (e) {
      // --- 【核心改造 2：处理网络连接等异常】 ---
      print("--- [前端探针][错误] 发送消息失败: $e");
      if (mounted) {
        // 捕获到任何网络异常时，显示一条人性化的提示
        final errorMessage = ChatMessage(
            role: 'assistant',
            content: '哎呀，网络好像断开了… 请检查网络后重试。'
        );
        setState(() {
          _messages.add(errorMessage);
        });
      }
    } finally {
      if (mounted) {
        setState(() { _isSending = false; });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 标题显示当前会话的名称
      appBar: AppBar(title: Text(widget.sessionTitle)),
      body: Column(
        children: [
          Expanded(
            child: _isHistoryLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(child: Text('向我提问，开启新的对话吧！', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? Radius.zero : null,
                        bottomLeft: !isUser ? Radius.zero : null,
                      ),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isSending) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: !_isSending,
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      onSubmitted: _isSending ? null : (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    mini: true,
                    onPressed: _isSending ? null : _sendMessage,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}