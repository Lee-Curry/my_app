// === photo_gallery_page.dart (小红书瀑布流 + 消息通知 + 兼容旧代码版) ===

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart'; // 👈 必须引入这个来实现瀑布流

import 'web_socket_service.dart';
import 'notification_page.dart';
import 'create_post_page.dart'; // 导入发布页
import 'post_detail_page.dart'; // 导入详情页
import 'config.dart';

// ==========================================
// 1. 保留这些类，防止 private_chat_page 报错
// ==========================================

class MediaItem {
  final int id;
  final String mediaUrl;
  final String mediaType;
  final String userNickname;
  final String userAvatarUrl;
  final int likeCount;

  MediaItem({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    required this.userNickname,
    required this.userAvatarUrl,
    this.likeCount = 0,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'],
      mediaUrl: json['url'] ?? json['media_url'] ?? '',
      mediaType: json['media_type'] ?? 'image',
      userNickname: json['nickname'] ?? '未知用户',
      userAvatarUrl: json['avatar_url'] ?? '',
      likeCount: json['like_count'] ?? 0,
    );
  }
}

// 【核心修正】增强版视频缩略图组件
// 【核心修正】视频缩略图组件 (修复 Layout 报错 + 黑屏问题)
class GalleryVideoThumbnail extends StatefulWidget {
  final String videoUrl;
  const GalleryVideoThumbnail({super.key, required this.videoUrl});

  @override
  State<GalleryVideoThumbnail> createState() => _GalleryVideoThumbnailState();
}

class _GalleryVideoThumbnailState extends State<GalleryVideoThumbnail> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _controller!.initialize();
      _controller!.setVolume(0); // 静音

      // 👇 核心：往后跳 100ms 截取第一帧，防止黑屏
      await _controller!.seekTo(const Duration(milliseconds: 100));

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("视频加载失败: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. 计算宽高比：如果视频加载好了用视频的，没加载好默认 1.0 (正方形)
    // 这一步彻底解决了 'hasSize' 报错，因为它给了组件一个明确的高度
    final double aspectRatio = (_isInitialized && _controller != null)
        ? _controller!.value.aspectRatio
        : 1.0;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 2. 视频画面
            if (_isInitialized && _controller != null)
              VideoPlayer(_controller!)
            else
            // 加载中显示转圈，而不是纯黑，体验更好
              const Center(child: CircularProgressIndicator(color: Colors.white30, strokeWidth: 2)),

            // 3. 播放图标遮罩
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. 照片墙主页面 (升级为瀑布流 + 帖子模式)
// ==========================================

class PhotoGalleryPage extends StatefulWidget {
  final int userId;
  final int viewerId;
  final bool isMe;

  const PhotoGalleryPage({
    super.key,
    required this.userId,
    required this.viewerId,
    this.isMe = false,
  });

  @override
  State<PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  List<dynamic> _posts = []; // 这里改存帖子数据
  bool _isLoading = true;
  int _unreadCount = 0;
  final String _apiUrl = AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchPosts(); // 改为拉取帖子
    _fetchUnreadCount();

    WebSocketService().newMessageNotifier.addListener(_onWsNotification);
  }

  @override
  void dispose() {
    WebSocketService().newMessageNotifier.removeListener(_onWsNotification);
    super.dispose();
  }

  void _onWsNotification() {
    // 简单处理：有通知就刷新未读数
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await http.get(Uri.parse('$_apiUrl/api/notifications/unread/count?userId=${widget.viewerId}'));
      if (res.statusCode == 200) {
        final count = jsonDecode(res.body)['count'];
        if(mounted) setState(() => _unreadCount = count);
      }
    } catch(e){}
  }

  // 👇👇👇 核心修改：改为调用 /api/posts/list 接口 👇👇👇
  Future<void> _fetchPosts() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    try {
      final uri = Uri.parse('$_apiUrl/api/posts/list?userId=${widget.userId}&viewerId=${widget.viewerId}');
      final response = await http.get(uri);

      if (mounted && response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        setState(() {
          _posts = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isMe ? '我的笔记' : 'TA的笔记'), // 改个名字更贴切
        actions: [
          if (widget.isMe)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationPage(userId: widget.viewerId)));
                    _fetchUnreadCount();
                  },
                ),
                if (_unreadCount > 0)
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text("$_unreadCount", style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  )
              ],
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
          ? Center(child: Text('暂无动态', style: TextStyle(color: Colors.grey[600])))
          : RefreshIndicator(
        onRefresh: _fetchPosts,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          // 👇👇👇 核心修改：使用 MasonryGridView 实现瀑布流 👇👇👇
          child: MasonryGridView.count(
            crossAxisCount: 2, // 双列
            mainAxisSpacing: 10, // 垂直间距
            crossAxisSpacing: 10, // 水平间距
            itemCount: _posts.length,
            itemBuilder: (context, index) {
              return _buildPostCard(_posts[index]);
            },
          ),
        ),
      ),
      // 👇👇👇 核心修改：点击跳转到 CreatePostPage 👇👇👇
      floatingActionButton: widget.isMe
          ? FloatingActionButton(
        onPressed: () async {
          final needRefresh = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreatePostPage(userId: widget.userId))
          );
          if (needRefresh == true) _fetchPosts();
        },
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  // 单个瀑布流卡片组件
  Widget _buildPostCard(dynamic post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String coverUrl = post['cover_url'] ?? '';
    final String title = post['title'] ?? post['content'] ?? '';
    final String nickname = post['nickname'] ?? '未知';
    final String avatarUrl = post['avatar_url'] ?? '';
    final int likeCount = post['like_count'] ?? 0;
    bool isVideo = post['cover_type'] == 'video';
    // 👇👇👇 核心修复：双重判断是否为视频 👇👇👇
    // 2. 如果字段没对上，检查链接后缀 (兜底策略)
    if (!isVideo && coverUrl.isNotEmpty) {
      isVideo = coverUrl.toLowerCase().contains('.mp4') ||
          coverUrl.toLowerCase().contains('.mov');
    }
    // 👆👆👆 修复结束 👆👆👆

    return GestureDetector(
      onTap: () {
        // 跳转到新的帖子详情页
        Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailPage(
          postId: post['id'],
          viewerId: widget.viewerId,
          apiUrl: _apiUrl,
        )));
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 封面图 (修复视频显示)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: Stack(
                children: [
                  // 👇👇👇 核心修复：根据 isVideo 决定显示什么 👇👇👇
                  isVideo
                      ? GalleryVideoThumbnail(videoUrl: coverUrl) // 用缩略图组件
                      : Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                        height: 150,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey)
                    ),
                  ),
                ],
              ),
            ),

            // 2. 内容区
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    title.isEmpty ? "分享图片" : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 底部用户行
                  Row(
                    children: [
                      CircleAvatar(radius: 8, backgroundImage: NetworkImage(avatarUrl)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(nickname, style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
                      ),
                      const Icon(Icons.favorite_border, size: 12, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text("$likeCount", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}