// === media_viewer_page.dart (完整代码) ===

import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'photo_gallery_page.dart'; // 导入 MediaItem 和 VideoPlayerWidget

// === 在 media_viewer_page.dart 中，替换旧的 FullScreenVideoPlayer 和 _FullScreenVideoPlayerState ===

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const FullScreenVideoPlayer({super.key, required this.videoUrl});

  @override
  _FullScreenVideoPlayerState createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _showControls = true; // 是否显示控制UI

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        // 视频初始化后刷新UI并自动播放
        setState(() {});
        _controller.play();
      })
    // 【核心改动】添加一个监听器，每当播放状态改变时（播放、暂停、进度更新），就刷新UI
      ..addListener(() {
        setState(() {}); // 这会不断触发 build 方法，从而更新进度条
      });
    _controller.setLooping(true); // 循环播放
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 切换播放/暂停的函数
  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _controller.value.isInitialized
          ? GestureDetector(
        // 点击视频区域，切换控制UI的显示/隐藏
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter, // 将控制条对齐到底部
            children: [
              // 视频播放器本体
              VideoPlayer(_controller),

              // 【核心改动】一个动画容器，用于平滑地显示/隐藏控制UI
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  // 底部渐变遮罩，让控制条更清晰
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        // 播放/暂停按钮
                        IconButton(
                          icon: Icon(
                            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                        // 播放时间
                        Text(
                          _formatDuration(_controller.value.position),
                          style: const TextStyle(color: Colors.white),
                        ),
                        // 进度条
                        Expanded(
                          child: VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true, // 允许用户拖动
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            colors: const VideoProgressColors(
                              playedColor: Colors.white,
                              bufferedColor: Colors.grey,
                              backgroundColor: Colors.black26,
                            ),
                          ),
                        ),
                        // 总时长
                        Text(
                          _formatDuration(_controller.value.duration),
                          style: const TextStyle(color: Colors.white),
                        ),
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

  // 一个辅助函数，用于将 Duration 格式化为 "mm:ss" 的字符串
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
// 媒体预览主页面
class MediaViewerPage extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final int initialIndex;

  const MediaViewerPage({
    super.key,
    required this.mediaItems,
    required this.initialIndex,
  });

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使用黑色背景，更有沉浸感
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white, // 让返回按钮和标题变成白色
        elevation: 0,
        // 动态显示页码，例如 "2 / 5"
        title: Text('${_currentIndex + 1} / ${widget.mediaItems.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.mediaItems.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final item = widget.mediaItems[index];
          if (item.mediaType == 'image') {
            // 对于图片，使用 InteractiveViewer 可以支持双指缩放和拖动
            return InteractiveViewer(
              child: Image.network(
                item.mediaUrl,
                fit: BoxFit.contain, // contain 模式保证图片完整显示
              ),
            );
          } else if (item.mediaType == 'video') {
            // 对于视频，使用我们自定义的全屏播放器
            // 使用 Key 来确保滑动页面时，旧的播放器被销毁，新的被创建
            return FullScreenVideoPlayer(
              key: ValueKey(item.mediaUrl),
              videoUrl: item.mediaUrl,
            );
          }
          return const SizedBox.shrink(); // 理论上不会执行到这里
        },
      ),
    );
  }
}