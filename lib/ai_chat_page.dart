// === ai_chat_page.dart (完整代码) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 定义一个简单的数据模型来表示一条消息
class ChatMessage {
  final String role; // 'user' 或 'assistant'
  final String content;

  ChatMessage({required this.role, required this.content});

  // 方便我们将消息列表转换为JSON
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = []; // 存储所有对话消息的列表
  bool _isLoading = false; // 是否正在等待AI回复

  final String _apiUrl = 'http://192.168.23.128:3000'; // ！！！！请务必替换为您自己的IP地址！！！！

  // 发送消息并获取AI回复的函数
  Future<void> _sendMessage() async {
    if (_textController.text.isEmpty) return;

    final userMessage = ChatMessage(role: 'user', content: _textController.text);

    setState(() {
      _messages.add(userMessage); // 将用户消息添加到列表中
      _isLoading = true; // 开始加载
    });

    _textController.clear(); // 清空输入框
    _scrollToBottom(); // 滚动到底部

    try {
      // 将完整的消息历史发送给后端
      final response = await http.post(
        Uri.parse('$_apiUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'messages': _messages.map((msg) => msg.toJson()).toList(),
        }),
      );

      if (mounted && response.statusCode == 200) {
        final replyContent = json.decode(response.body)['reply'];
        final aiMessage = ChatMessage(role: 'assistant', content: replyContent);
        setState(() {
          _messages.add(aiMessage); // 将AI的回复添加到列表中
        });
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = ChatMessage(role: 'assistant', content: '抱歉，我好像断线了... ($e)');
        setState(() {
          _messages.add(errorMessage);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // 结束加载
        });
        _scrollToBottom();
      }
    }
  }

  // 滚动到聊天列表的底部
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
      appBar: AppBar(title: const Text('AI 助手')),
      body: Column(
        children: [
          // 聊天消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                // 根据角色（用户或AI）显示不同的气泡样式
                return Align(
                  alignment: message.role == 'user'
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: message.role == 'user'
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: message.role == 'user'
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(), // 正在加载时显示进度条

          // 底部输入框区域
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: '开始对话...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(), // 按回车发送
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendMessage, // 正在加载时禁用发送按钮
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}