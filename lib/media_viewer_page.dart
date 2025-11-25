// === media_viewer_page.dart (头像显示 + 主题适配版 - 完整代码) ===

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'photo_gallery_page.dart'; // 导入 MediaItem

// ==========================================
// 1. 视频播放器组件
// ==========================================
class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const FullScreenVideoPlayer({super.key, required this.videoUrl});

  @override
  _FullScreenVideoPlayerState createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      })
      ..addListener(() {
        if(mounted) setState(() {});
      });
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _controller.value.isInitialized
          ? GestureDetector(
        onTap: () {
          setState(() { _showControls = !_showControls; });
        },
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(_controller),
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 20),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                          onPressed: _togglePlayPause,
                        ),
                        Text(_formatDuration(_controller.value.position), style: const TextStyle(color: Colors.white)),
                        Expanded(
                          child: VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            colors: const VideoProgressColors(playedColor: Colors.white, bufferedColor: Colors.grey, backgroundColor: Colors.black26),
                          ),
                        ),
                        Text(_formatDuration(_controller.value.duration), style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          : const CircularProgressIndicator(color: Colors.white),
    );
  }
}

// ==========================================
// 2. 媒体预览主页面
// ==========================================
class MediaViewerPage extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final int initialIndex;
  final int viewerId;
  final String apiUrl;

  const MediaViewerPage({
    super.key,
    required this.mediaItems,
    required this.initialIndex,
    required this.viewerId,
    required this.apiUrl,
  });

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;

  List<dynamic> _currentLikes = [];
  List<dynamic> _currentComments = [];
  bool _isLiked = false;

  // 动态数据
  String _dynamicNickname = "";
  String _dynamicAvatarUrl = ""; // 【新增】头像URL

  Map<int, Map<String, dynamic>> _socialCache = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // 初始化时从列表数据获取
    final initialItem = widget.mediaItems[_currentIndex];
    _dynamicNickname = initialItem.userNickname;
    _dynamicAvatarUrl = initialItem.userAvatarUrl; // 【新增】初始化头像

    _fetchSocialDetails(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchSocialDetails(int index) async {
    final photoId = widget.mediaItems[index].id;

    // 切换时先重置为列表里的基础信息
    if(mounted) {
      setState(() {
        _dynamicNickname = widget.mediaItems[index].userNickname;
        _dynamicAvatarUrl = widget.mediaItems[index].userAvatarUrl;
      });
    }

    if (_socialCache.containsKey(photoId)) {
      final cache = _socialCache[photoId]!;
      if(mounted) {
        setState(() {
          _currentLikes = cache['likes'];
          _currentComments = cache['comments'];
          _isLiked = cache['isLiked'];
          if (cache['nickname'] != null) _dynamicNickname = cache['nickname'];
          if (cache['avatar_url'] != null) _dynamicAvatarUrl = cache['avatar_url'];
        });
      }
    }

    try {
      final res = await http.get(Uri.parse('${widget.apiUrl}/api/photos/detail/$photoId?viewerId=${widget.viewerId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        if (mounted && _currentIndex == index) {
          setState(() {
            _currentLikes = data['likes'];
            _currentComments = data['comments'];
            _isLiked = data['isLiked'];

            // 从详情接口更新最新的昵称和头像
            if (data['photo'] != null) {
              if (data['photo']['nickname'] != null) _dynamicNickname = data['photo']['nickname'];
              if (data['photo']['avatar_url'] != null) _dynamicAvatarUrl = data['photo']['avatar_url'];
            }

            _socialCache[photoId] = {
              'likes': _currentLikes,
              'comments': _currentComments,
              'isLiked': _isLiked,
              'nickname': _dynamicNickname,
              'avatar_url': _dynamicAvatarUrl,
            };
          });
        }
      }
    } catch (e) {
      print("获取详情失败: $e");
    }
  }

  Future<void> _toggleLike() async {
    final photoId = widget.mediaItems[_currentIndex].id;
    setState(() => _isLiked = !_isLiked);
    try {
      final res = await http.post(
          Uri.parse('${widget.apiUrl}/api/photos/like'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'photoId': photoId, 'userId': widget.viewerId})
      );
      if (res.statusCode == 200) {
        _fetchSocialDetails(_currentIndex);
      } else {
        setState(() => _isLiked = !_isLiked);
      }
    } catch (e) {
      setState(() => _isLiked = !_isLiked);
    }
  }

  void _showCommentsModal() {
    // 弹窗背景颜色也需要适配（虽然通常评论区用深色背景看起来更像抖音/小红书，但这里可以根据喜好调整）
    // 这里保持深色背景，因为评论区独立于底色
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return _CommentsBottomSheet(
          comments: _currentComments,
          photoId: widget.mediaItems[_currentIndex].id,
          viewerId: widget.viewerId,
          apiUrl: widget.apiUrl,
          onCommentSuccess: () {
            _fetchSocialDetails(_currentIndex);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 【核心改动】判断主题模式
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 定义颜色策略
    // 深色模式：背景黑，字/图标白
    // 浅色模式：背景白，字/图标黑
    final Color bgColor = isDark ? Colors.black : Colors.white;
    final Color contentColor = isDark ? Colors.white : Colors.black;
    final Color iconColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor, // 动态背景色
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        // AppBar 的返回箭头和标题颜色也要跟随
        foregroundColor: contentColor,
        elevation: 0,
        title: Text('${_currentIndex + 1} / ${widget.mediaItems.length}'),
      ),
      body: Stack(
        children: [
          // 1. 滑动浏览区域
          PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaItems.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _fetchSocialDetails(index);
            },
            itemBuilder: (context, index) {
              final item = widget.mediaItems[index];
              if (item.mediaType == 'image') {
                return InteractiveViewer(
                  // 保证图片在任何背景下都能看清
                  child: Image.network(item.mediaUrl, fit: BoxFit.contain),
                );
              } else if (item.mediaType == 'video') {
                return FullScreenVideoPlayer(key: ValueKey(item.mediaUrl), videoUrl: item.mediaUrl);
              }
              return const SizedBox.shrink();
            },
          ),

          // 2. 底部浮层 (点赞和评论)
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              children: [
                // 点赞
                GestureDetector(
                  onTap: _toggleLike,
                  child: Column(
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        // 已赞永远是红色，未赞跟随主题色
                        color: _isLiked ? Colors.red : iconColor,
                        size: 35,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${_currentLikes.length}",
                        style: TextStyle(color: contentColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                // 评论
                GestureDetector(
                  onTap: _showCommentsModal,
                  child: Column(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: iconColor, size: 32),
                      const SizedBox(height: 4),
                      Text(
                        "${_currentComments.length}",
                        style: TextStyle(color: contentColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. 底部文案 (显示头像 + 昵称)
          Positioned(
            bottom: 30,
            left: 20,
            right: 80,
            child: Row(
              children: [
                // 【新增】显示头像
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(_dynamicAvatarUrl),
                  backgroundColor: Colors.grey[300], // 加载时的占位色
                  onBackgroundImageError: (_, __) {}, // 防止加载失败崩溃
                ),
                const SizedBox(width: 10),
                // 显示昵称
                Expanded(
                  child: Text(
                    "@$_dynamicNickname",
                    style: TextStyle(
                        color: contentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: isDark ? [] : [ // 浅色模式下加一点点阴影防止背景是白色图片看不清字
                          const Shadow(blurRadius: 2, color: Colors.white, offset: Offset(0, 0))
                        ]
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. 评论底部弹窗组件
// ==========================================
class _CommentsBottomSheet extends StatefulWidget {
  final List<dynamic> comments;
  final int photoId;
  final int viewerId;
  final String apiUrl;
  final VoidCallback onCommentSuccess;

  const _CommentsBottomSheet({
    required this.comments,
    required this.photoId,
    required this.viewerId,
    required this.apiUrl,
    required this.onCommentSuccess,
  });

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final TextEditingController _textController = TextEditingController();

  Future<void> _sendComment() async {
    if (_textController.text.trim().isEmpty) return;
    try {
      final res = await http.post(
          Uri.parse('${widget.apiUrl}/api/photos/comment'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'photoId': widget.photoId,
            'userId': widget.viewerId,
            'content': _textController.text
          })
      );
      if (res.statusCode == 200) {
        _textController.clear();
        FocusScope.of(context).unfocus();
        widget.onCommentSuccess();
      }
    } catch (e) { print(e); }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Text(
                "${widget.comments.length} 条评论",
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)
            ),
          ),

          // 评论列表
          Expanded(
            child: widget.comments.isEmpty
                ? const Center(child: Text("暂无评论，快来抢沙发~", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.comments.length,
              itemBuilder: (context, index) {
                final c = widget.comments[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(c['avatar_url'] ?? ''),
                        backgroundColor: Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['nickname'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(c['content'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 输入框
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12))),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "说点什么...",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                    onPressed: _sendComment,
                    icon: const Icon(Icons.send, color: Colors.blue)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}