import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取当前主题的文字颜色，适配深色/浅色模式
    final titleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
    );

    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6);

    return Scaffold(
      appBar: AppBar(
        title: const Text('隐私政策与功能介绍'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 顶部 Logo 或 标题 (可选) ---
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      // 如果你的图片是透明底的，可以在这里保留背景色；如果图片自带背景，可以去掉 color 这一行
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20), // 圆角
                    ),
                    // 这一行很重要，确保图片会被裁剪成圆角
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      "assets/icon/icon.png", // ✅ 正确：这是相对路径
                      fit: BoxFit.cover,
                    ),
                  ),
                  // --- 替换结束 ---
                  const SizedBox(height: 12),
                  Text(
                    '晗伴',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '你的智能AI伙伴与生活记录空间',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- 功能介绍 ---
            Text('功能介绍', style: titleStyle),
            const SizedBox(height: 12),
            Text(
              '“晗伴”是一款集成了先进AI技术的智能助手应用，致力于为您提供：',
              style: bodyStyle,
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(context, '多会话AI助手：随时开启新对话，与智能AI进行多轮、有上下文的深度交流。'),
            _buildBulletPoint(context, '私人照片墙：记录和分享生活中的美好瞬间，打造属于你的个人记忆画廊。'),
            _buildBulletPoint(context, '个性化主页：编辑你的个人资料，展示独特的你。'),

            const SizedBox(height: 32),

            // --- 隐私政策 ---
            Text('隐私政策', style: titleStyle),
            const SizedBox(height: 12),
            Text('我们非常重视您的隐私。本应用承诺：', style: bodyStyle),
            const SizedBox(height: 8),
            _buildNumberedPoint(context, 1, '我们仅在您注册/登录时收集您的手机号码，用于身份验证。'),
            _buildNumberedPoint(context, 2, '您与AI的对话内容、您上传的个人资料和照片，均存储在安全的云服务器上，仅您本人可见。'),
            _buildNumberedPoint(context, 3, '我们不会将您的个人数据分享、出售或透露给任何第三方。'),
            _buildNumberedPoint(context, 4, '您可以随时删除您的对话记录和照片墙内容。'),

            const SizedBox(height: 40),

            // --- 底部联系方式 ---
            const Divider(),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Text('联系我们', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SelectableText( // 使用 SelectableText 让用户可以复制邮箱
                    '23301127@bjtu.edu.cn',
                    style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    '手机号: 15110187267',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 辅助方法：构建圆点列表项
  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }

  // 辅助方法：构建数字列表项
  Widget _buildNumberedPoint(BuildContext context, int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number. ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }
}