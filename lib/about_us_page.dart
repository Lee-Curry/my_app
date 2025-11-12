// === about_us_page.dart (完整代码) ===

import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 假设的版本号，未来可以从包信息中动态获取
    const String appVersion = '1.0.0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('关于我们'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 1),
            // App Logo
            Icon(
              Icons.memory,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),

            // App 名称
            const Text(
              '智能助手App',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // 版本号
            Text(
              'Version $appVersion',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // App 介绍
            const Text(
              '这是一款集成了先进AI技术的智能助手应用，致力于为您提供便捷的问答服务、高效的信息管理和个性化的用户体验。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5), // height 是行高
            ),
            const Spacer(flex: 2),

            // 版权信息 (小彩蛋)
            Text(
              '© 2025 liyiming. All Rights Reserved.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}