// === chat_sessions_list_page.dart (全新文件) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ai_chat_page.dart'; // 导入聊天页
import 'config.dart';

class ChatSessionsListPage extends StatefulWidget {
  final int userId;
  const ChatSessionsListPage({super.key, required this.userId});

  @override
  State<ChatSessionsListPage> createState() => _ChatSessionsListPageState();
}

class _ChatSessionsListPageState extends State<ChatSessionsListPage> {
  List<dynamic> _sessions = [];
  bool _isLoading = true;

  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  // 获取会话列表
  Future<void> _fetchSessions() async {
    setState(() { _isLoading = true; });
    try {
      print("--- [前端探针] 正在获取用户 ${widget.userId} 的会话列表...");
      final response = await http.get(Uri.parse('$_apiUrl/api/sessions/${widget.userId}'));

      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _sessions = data['data'];
        });
        print("--- [前端探针] 成功获取 ${_sessions.length} 个会话");
      }
    } catch (e) {
      print("--- [前端探针][错误] 获取会话列表失败: $e");
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // 创建新会话
  Future<void> _createNewSession() async {
    try {
      print("--- [前端探针] 正在创建新会话...");
      final response = await http.post(Uri.parse('$_apiUrl/api/sessions/create/${widget.userId}'));

      if (mounted && response.statusCode == 201) {
        final data = json.decode(response.body);
        final newSessionId = data['sessionId'];

        print("--- [前端探针] 新会话创建成功，ID: $newSessionId，准备跳转...");

        // 跳转到聊天页
        await _navigateToChat(newSessionId, '新对话');
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
    }
  }

  // 跳转到聊天页的通用方法
  Future<void> _navigateToChat(int sessionId, String title) async {
    // 使用 await Navigator.push，这样当用户从聊天页返回时，我们可以刷新列表
    // 因为用户可能聊了几句，标题变了，或者是新创建的对话需要显示在列表中
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiChatPage(sessionId: sessionId, sessionTitle: title),
      ),
    );
    // 返回后刷新列表
    _fetchSessions();
  }

  // 在 _ChatSessionsListPageState 类的内部

  // --- 【新增】函数1: 弹出确认对话框 ---
  Future<bool?> _confirmAndDeleteSession(int sessionId, String title) async {
    final bool? isConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('您确定要永久删除对话“$title”吗？此操作无法撤销。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // 返回 false
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true), // 返回 true
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    // 如果用户确认了，才执行真正的删除操作
    if (isConfirmed == true) {
      await _deleteSessionOnServer(sessionId);
      return true; // 告诉 Dismissible 可以执行滑动消失动画
    }

    return false; // 告诉 Dismissible 不要消失，恢复原位
  }

  // --- 【新增】函数2: 调用后端API进行删除 ---
  Future<void> _deleteSessionOnServer(int sessionId) async {
    try {
      print("--- [前端探针] 正在删除会话 $sessionId ...");
      final response = await http.delete(
        Uri.parse('$_apiUrl/api/sessions/delete/$sessionId'),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('对话已删除'), duration: Duration(seconds: 2)),
          );
          // 在UI上立即移除这一项，而不是等待下一次网络刷新
          setState(() {
            _sessions.removeWhere((session) => session['id'] == sessionId);
          });
        } else {
          final errorBody = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: ${errorBody['message']}')));
        }
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('网络错误: $e')));
    }
  }

  // 简单的日期格式化辅助函数
  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      return "${dt.month}月${dt.day}日 ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的对话'),
        actions: [
          IconButton(onPressed: _fetchSessions, icon: const Icon(Icons.refresh))
        ],
      ),
      // 悬浮按钮：开启新对话
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewSession,
        icon: const Icon(Icons.add),
        label: const Text('新对话'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('还没有对话记录', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _createNewSession, child: const Text('开始第一次对话'))
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchSessions,
        child: ListView.builder(
          itemCount: _sessions.length,
          itemBuilder: (context, index) {
            final session = _sessions[index];
            final sessionId = session['id'];
            final sessionTitle = session['title'];

            // --- 【核心改造：使用 Dismissible 组件包裹 ListTile】 ---
            return Dismissible(
              // Key 是必须的，它让Flutter知道要删除的是哪个Widget
              key: Key(sessionId.toString()),

              // 从右向左滑动
              direction: DismissDirection.endToStart,

              // 滑动时的背景
              background: Container(
                color: Colors.red[700],
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerRight,
                child: const Icon(Icons.delete_sweep, color: Colors.white),
              ),

              // 确认删除的逻辑
              confirmDismiss: (direction) async {
                // 在这里调用我们下面将要创建的删除函数
                return await _confirmAndDeleteSession(sessionId, sessionTitle);
              },

              // 正常显示的列表项
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  child: const Icon(Icons.smart_toy_outlined),
                ),
                title: Text(
                  sessionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "最后更新: ${_formatTime(session['updated_at'])}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                onTap: () {
                  _navigateToChat(sessionId, sessionTitle);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}