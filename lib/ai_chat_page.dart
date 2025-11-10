// === ai_chat_page.dart (最终修复版 - 完整代码) ===

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
  final int userId; // 接收 userId
  const AiChatPage({super.key, required this.userId}); // 在构造函数中接收

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = []; // 存储所有对话消息的列表

  bool _isSending = false; // 状态：是否正在等待AI回复
  bool _isHistoryLoading = true; // 状态：是否正在加载历史记录

  final String _apiUrl = 'http://10.61.193.166:3000'; // ！！！！请务必替换为您自己的IP地址！！！！

  @override
  void initState() {
    super.initState();
    _loadHistory(); // 页面加载时，尝试获取历史记录
  }

  // 加载历史记录的函数
  Future<void> _loadHistory() async {
    // 页面一进来，历史记录肯定是正在加载的，所以初始值为 true
    // 我们不再需要在这里调用 setState({ _isHistoryLoading = true; })
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/chat/history/${widget.userId}'));
      if(mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List history = data['history'];
        if (history.isNotEmpty) {
          setState(() {
            _messages.clear();
            for (var item in history) {
              _messages.add(ChatMessage(role: item['role'], content: item['content']));
            }
          });
        }
      }
    } catch(e) {
      print("加载历史记录失败: $e");
    } finally {
      // 无论成功、失败、或没有历史记录，最后都把历史加载状态设为 false
      if(mounted) {
        setState(() { _isHistoryLoading = false; });
        _scrollToBottom();
      }
    }
  }


  // 发送消息并获取AI回复的函数
  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty || _isSending) return;

    final userMessage = ChatMessage(role: 'user', content: _textController.text);

    setState(() {
      _messages.add(userMessage);
      _isSending = true; // 开始发送，禁用输入
    });

    _textController.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/chat/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          // 为了优化，可以只发送最近的几条消息作为上下文
          'messages': _messages.map((msg) => msg.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 60)); // 延长超时时间以等待AI响应

      if (mounted && response.statusCode == 200) {
        final replyContent = json.decode(response.body)['reply'];
        final aiMessage = ChatMessage(role: 'assistant', content: replyContent);
        setState(() {
          _messages.add(aiMessage);
        });
      } else if (mounted) {
        final errorMessage = ChatMessage(role: 'assistant', content: '抱歉，服务器响应异常...');
        setState(() { _messages.add(errorMessage); });
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
          _isSending = false; // 结束发送，恢复输入
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
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手')),
      body: Column(
        children: [
          // 聊天消息列表
          Expanded(
            child: _isHistoryLoading
                ? const Center(child: CircularProgressIndicator()) // 正在加载历史，显示圆圈
                : _messages.isEmpty
                ? const Center(child: Text('开始对话吧！')) // 历史加载完，但没消息，显示提示
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.role == 'user'
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
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

          // 只有在“发送”新消息时，才显示线性进度条
          if (_isSending) const LinearProgressIndicator(),

          // 底部输入框区域
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: !_isSending, // 正在发送时禁用输入框
                      decoration: InputDecoration(
                        hintText: '开始对话...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      ),
                      onSubmitted: _isSending ? null : (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    icon: const Icon(Icons.send),
                    onPressed: _isSending ? null : _sendMessage, // 正在发送时禁用按钮
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