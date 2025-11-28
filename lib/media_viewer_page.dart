// === media_viewer_page.dart (完美缩放 + 手势防冲突版) ===

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'photo_gallery_page.dart';

// ==========================================
// 1. 视频播放器组件 (保持不变)
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
                        IconButton(icon: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white), onPressed: _togglePlayPause),
                        Text(_formatDuration(_controller.value.position), style: const TextStyle(color: Colors.white)),
                        Expanded(
                          child: VideoProgressIndicator(_controller, allowScrubbing: true, padding: const EdgeInsets.symmetric(horizontal: 8.0), colors: const VideoProgressColors(playedColor: Colors.white, bufferedColor: Colors.grey, backgroundColor: Colors.black26)),
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
// 2. 【核心新增】可缩放图片组件 (解决手势冲突)
// ==========================================
class _ZoomableImage extends StatefulWidget {
  final String imageUrl;
  final Function(bool) onZoomStateChanged; // 通知父组件是否正在缩放

  const _ZoomableImage({
    required this.imageUrl,
    required this.onZoomStateChanged,
  });

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))
      ..addListener(() {
        _transformationController.value = _animation!.value;
      });

    // 监听缩放变化
    _transformationController.addListener(() {
      final scale = _transformationController.value.getMaxScaleOnAxis();
      // 如果缩放比例 > 1.01 (给一点点容错)，说明放大了，通知父组件锁死翻页
      if (scale > 1.01) {
        widget.onZoomStateChanged(true); // 锁死翻页
      } else {
        widget.onZoomStateChanged(false); // 允许翻页
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 双击放大/缩小逻辑
  void _handleDoubleTap() {
    if (_animationController.isAnimating) return;

    final double scale = _transformationController.value.getMaxScaleOnAxis();
    final Matrix4 endMatrix;

    if (scale > 1.0) {
      // 如果已经是放大的，双击还原
      endMatrix = Matrix4.identity();
    } else {
      // 如果是原图，双击放大 2 倍
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      endMatrix = Matrix4.identity()
        ..translate(-position.dx, -position.dy)
        ..scale(2.0)
        ..translate(-position.dx, -position.dy); // 简单的居中放大算法，可根据需要优化

      // 更精准的点击点放大算法（简化版）：
      // 这里直接还原 Identity 或者放大即可，不用搞太复杂，微信也是简单的放大
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: scale > 1.0 ? Matrix4.identity() : Matrix4.identity()..scale(2.5)..translate(-100.0, -100.0), // 简单处理，实际可以用更复杂的矩阵计算
    ).animate(CurveTween(curve: Curves.easeInOut).animate(_animationController));

    // 简单的重置逻辑：直接重置或者简单放大
    if (scale > 1.0) {
      _transformationController.value = Matrix4.identity();
    } else {
      // 简单放大一点
      _transformationController.value = Matrix4.identity()..scale(2.0);
    }
    // 注：上面的动画代码只是演示，为了流畅性，直接用下面的简单逻辑即可
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: () {
        // 简易版双击：放大/还原
        final scale = _transformationController.value.getMaxScaleOnAxis();
        if (scale > 1.0) {
          _transformationController.value = Matrix4.identity();
        } else {
          // 放大2倍
          final Matrix4 matrix = Matrix4.identity()..scale(2.0);
          _transformationController.value = matrix;
        }
      },
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0, // 最小缩放
        maxScale: 5.0, // 最大缩放
        panEnabled: true, // 允许拖动
        scaleEnabled: true, // 允许缩放
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          alignment: Alignment.center,
          child: Image.network(widget.imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ==========================================
// 3. 媒体预览主页面
// ==========================================
class MediaViewerPage extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final int initialIndex;
  final int viewerId;
  final String apiUrl;
  final bool isPureView;

  const MediaViewerPage({
    super.key,
    required this.mediaItems,
    required this.initialIndex,
    required this.viewerId,
    required this.apiUrl,
    this.isPureView = false,
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

  String _dynamicNickname = "";
  String _dynamicAvatarUrl = "";

  Map<int, Map<String, dynamic>> _socialCache = {};

  // 【核心修改】控制 PageView 是否可以滚动
  ScrollPhysics _pageScrollPhysics = const BouncingScrollPhysics();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    final initialItem = widget.mediaItems[_currentIndex];
    _dynamicNickname = initialItem.userNickname;
    _dynamicAvatarUrl = initialItem.userAvatarUrl;

    _fetchSocialDetails(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 【核心修改】切换滚动状态
  void _setScrollEnabled(bool enabled) {
    setState(() {
      _pageScrollPhysics = enabled
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(); // 禁止滚动
    });
  }

  Future<void> _fetchSocialDetails(int index) async {
    final photoId = widget.mediaItems[index].id;
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
      // ignore
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
          onCommentSuccess: () { _fetchSocialDetails(_currentIndex); },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 强制黑色背景
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 1. 滑动浏览区域
          PageView.builder(
            // 【核心修改】应用动态的 physics
            physics: _pageScrollPhysics,
            controller: _pageController,
            itemCount: widget.mediaItems.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _fetchSocialDetails(index);
            },
            itemBuilder: (context, index) {
              final item = widget.mediaItems[index];
              if (item.mediaType == 'image') {
                // 【核心修改】使用自定义的 _ZoomableImage
                return _ZoomableImage(
                  imageUrl: item.mediaUrl,
                  onZoomStateChanged: (isZooming) {
                    // 当正在缩放（scale > 1）时，isZooming 为 true -> 禁止滚动
                    // 当恢复原样（scale == 1）时，isZooming 为 false -> 允许滚动
                    _setScrollEnabled(!isZooming);
                  },
                );
              } else if (item.mediaType == 'video') {
                return FullScreenVideoPlayer(key: ValueKey(item.mediaUrl), videoUrl: item.mediaUrl);
              }
              return const SizedBox.shrink();
            },
          ),

          if (!widget.isPureView) ...[
            Positioned(
              bottom: 30, right: 20,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Column(
                      children: [
                        Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : Colors.white, size: 35),
                        const SizedBox(height: 4),
                        Text("${_currentLikes.length}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  GestureDetector(
                    onTap: _showCommentsModal,
                    child: Column(
                      children: [
                        const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 32),
                        const SizedBox(height: 4),
                        Text("${_currentComments.length}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 30, left: 20, right: 80,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(_dynamicAvatarUrl),
                    backgroundColor: Colors.grey[300],
                    onBackgroundImageError: (_, __) {},
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "@$_dynamicNickname",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2, color: Colors.black54, offset: Offset(0, 0))]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}

// ==========================================
// ==========================================
// 3. 评论底部弹窗组件 (自动刷新版)
// ==========================================
class _CommentsBottomSheet extends StatefulWidget {
  final List<dynamic> comments; // 初始评论数据
  final int photoId;
  final int viewerId;
  final String apiUrl;
  final VoidCallback onCommentSuccess; // 通知父组件刷新

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

  // 👇 1. 本地维护一个评论列表，初始化时使用父组件传进来的数据
  late List<dynamic> _localComments;

  // 回复状态
  Map<String, dynamic>? _replyToUser;

  @override
  void initState() {
    super.initState();
    // 初始化列表
    _localComments = widget.comments;
  }

  // 👇 2. 新增：自己在弹窗内部获取最新评论的方法
  Future<void> _refreshLocalComments() async {
    try {
      // 复用获取详情的接口，只取 comments 部分
      final res = await http.get(Uri.parse('${widget.apiUrl}/api/photos/detail/${widget.photoId}?viewerId=${widget.viewerId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        if (mounted) {
          setState(() {
            _localComments = data['comments'];
          });
        }
      }
    } catch (e) {
      print("刷新评论失败: $e");
    }
  }

  Future<void> _sendComment() async {
    if (_textController.text.trim().isEmpty) return;
    try {
      final Map<String, dynamic> body = {
        'photoId': widget.photoId,
        'userId': widget.viewerId,
        'content': _textController.text
      };

      if (_replyToUser != null) {
        body['replyToUserId'] = _replyToUser!['user_id'];
      }

      final res = await http.post(
          Uri.parse('${widget.apiUrl}/api/photos/comment'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body)
      );

      if (res.statusCode == 200) {
        _textController.clear();
        setState(() => _replyToUser = null);
        FocusScope.of(context).unfocus();

        // 👇 3. 核心修改：发送成功后，先刷新自己(弹窗)的列表，再通知父组件
        await _refreshLocalComments();
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
          // 顶部标题 (使用 _localComments 的长度)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
            child: Text("${_localComments.length} 条评论", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ),

          // 评论列表 (使用 _localComments)
          Expanded(
            child: _localComments.isEmpty
                ? const Center(child: Text("暂无评论，快来抢沙发~", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _localComments.length,
              itemBuilder: (context, index) {
                final c = _localComments[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _replyToUser = {
                        'user_id': c['user_id'],
                        'nickname': c['nickname']
                      };
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(c['avatar_url'] ?? ''),
                            backgroundColor: Colors.grey
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['nickname'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 4),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  children: [
                                    if (c['reply_nickname'] != null) ...[
                                      const TextSpan(text: "回复 "),
                                      TextSpan(
                                          text: "@${c['reply_nickname']} ",
                                          style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)
                                      ),
                                    ],
                                    TextSpan(text: c['content']),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 底部输入区域
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyToUser != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.white10,
                  child: Row(
                    children: [
                      Text(
                          "回复 @${_replyToUser!['nickname']}",
                          style: const TextStyle(color: Colors.grey, fontSize: 12)
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _replyToUser = null),
                        child: const Icon(Icons.close, size: 16, color: Colors.grey),
                      )
                    ],
                  ),
                ),

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
                          decoration: InputDecoration(
                              hintText: _replyToUser != null
                                  ? "回复 @${_replyToUser!['nickname']}..."
                                  : "说点什么...",
                              hintStyle: const TextStyle(color: Colors.white38),
                              border: InputBorder.none
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(onPressed: _sendComment, icon: const Icon(Icons.send, color: Colors.blue)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}