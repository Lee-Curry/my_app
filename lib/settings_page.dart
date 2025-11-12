// 在 settings_page.dart 的顶部

import 'package:flutter/material.dart';
import 'account_security_page.dart'; // 1. 【新增】导入我们刚刚创建的页面

class SettingsPage extends StatefulWidget {
  // 2. 【修改】原来的 const SettingsPage({super.key});
  final int userId;
  const SettingsPage({super.key, required this.userId});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _receiveNotifications = true; // 模拟一个开关状态

  // 一个辅助方法，用于构建带标题的分组
  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        // 使用 Card 包裹，让列表更有层次感
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(children: children),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          _buildSection(
            title: '通用',
            children: [
              // --- 接收通知 ---
              SwitchListTile(
                title: const Text('接收新消息通知'),
                secondary: const Icon(Icons.notifications_outlined),
                value: _receiveNotifications,
                onChanged: (bool value) {
                  setState(() {
                    _receiveNotifications = value;
                    print('接收通知状态: $_receiveNotifications');
                  });
                },
              ),
              const Divider(height: 1, indent: 16),
              // --- 清理缓存 ---
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('清理缓存'),
                trailing: const Text('24.5 MB', style: TextStyle(color: Colors.grey)), // 示例大小
                onTap: () {
                  print('点击了清理缓存');
                  // 在这里可以添加清理缓存的逻辑和弹窗确认
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('缓存已清理！')),
                  );
                },
              ),
            ],
          ),
          _buildSection(
            title: '账户',
            children: [
              // --- 账号与安全 ---
              // --- 账号与安全 ---
              ListTile(
                leading: const Icon(Icons.security_outlined),
                title: const Text('账号与安全'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // 3. 【核心修改】替换这里的逻辑
                  print('点击了账号与安全, 用户ID: ${widget.userId}');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccountSecurityPage(userId: widget.userId),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 16),
              // --- 隐私政策 ---
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('隐私政策'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  print('点击了隐私政策');
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}