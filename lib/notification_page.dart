// === notification_page.dart (新建) ===
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'photo_gallery_page.dart';
import 'media_viewer_page.dart';

class NotificationPage extends StatefulWidget {
  final int userId;
  const NotificationPage({super.key, required this.userId});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  final String _apiUrl = 'http://192.168.23.18:3000'; // 替换IP

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _markAllRead(); // 进页面就标记已读
  }

  Future<void> _fetchNotifications() async {
    try {
      final res = await http.get(Uri.parse('$_apiUrl/api/notifications/list?userId=${widget.userId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        if(mounted) setState(() {
          _notifications = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await http.post(Uri.parse('$_apiUrl/api/notifications/mark-all-read'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': widget.userId}));
    } catch (e) {}
  }

  void _jumpToPhoto(dynamic note) {
    // 构造一个临时的 MediaItem 跳转查看
    // 注意：这里需要获取完整的 MediaItem 才能完美跳转，
    // 简单起见，我们直接跳到 MediaViewerPage，并让它自己去加载详情
    final item = MediaItem(
      id: note['photo_id'],
      mediaUrl: note['media_url'], // 封面图
      mediaType: note['media_type'],
      userNickname: "加载中...", // 详情页会自动更新
      userAvatarUrl: "",
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerPage(
          mediaItems: [item],
          initialIndex: 0,
          viewerId: widget.userId,
          apiUrl: _apiUrl,
          isPureView: false, // 允许互动
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("消息")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(child: Text("暂无新消息"))
          : ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final note = _notifications[index];
          final isLike = note['type'] == 'like';

          return ListTile(
            leading: CircleAvatar(backgroundImage: NetworkImage(note['avatar_url'])),
            title: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(text: note['nickname'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: isLike ? " 赞了你的作品" : " 评论了你"),
                ],
              ),
            ),
            subtitle: isLike ? null : Text(note['content'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
            // 👇👇👇 核心修改：判断类型，如果是视频则使用缩略图组件 👇👇👇
            trailing: SizedBox(
              width: 50, height: 50,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4), // 顺便加个圆角更好看
                child: note['media_type'] == 'video'
                    ? GalleryVideoThumbnail(videoUrl: note['media_url']) // 复用照片墙的组件
                    : Image.network(note['media_url'], fit: BoxFit.cover),
              ),
            ),
            onTap: () => _jumpToPhoto(note),
          );
        },
      ),
    );
  }
}