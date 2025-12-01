// === avatar_viewer_page.dart (新建文件) ===
import 'package:flutter/material.dart';

class AvatarViewerPage extends StatelessWidget {
  final String imageUrl;
  final String heroTag; // 用于 Hero 动画，让头像飞出来

  const AvatarViewerPage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // 沉浸式，点击任意地方关闭
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            Center(
              // 允许双指缩放
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Hero(
                  tag: heroTag, // 动画标签
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    // 加载时的占位符
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                    // 错误处理
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                  ),
                ),
              ),
            ),
            // 右上角关闭按钮 (可选，为了交互明确)
            Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}