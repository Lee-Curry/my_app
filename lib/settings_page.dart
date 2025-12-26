// 在 settings_page.dart 的顶部

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:my_app/privacy_policy_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account_security_page.dart';
import 'biometric_service.dart'; // 1. 【新增】导入我们刚刚创建的页面

class SettingsPage extends StatefulWidget {
  // 2. 【修改】原来的 const SettingsPage({super.key});
  final int userId;
  const SettingsPage({super.key, required this.userId});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _receiveNotifications = true; // 模拟一个开关状态
  bool _isBiometricEnabled = false; // 开关状态

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  // 👇👇👇 你可能漏掉了这一段，请补上 👇👇👇
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // 读取本地存储的开关状态，如果没有则默认为 false
      _isBiometricEnabled = prefs.getBool('app_lock_enabled') ?? false;
    });
  }
  // 👆👆👆 补全结束 👆👆👆


  // 1. 加载当前开关状态
  // 修改切换开关的方法
  Future<void> _toggleAppLock(bool value) async {
    // 1. 如果是开启，先验一下指纹
    if (value) {
      bool success = await BiometricService.authenticate();
      if (!success) return; // 没通过就不开启
    }

    // 2. 保存设置并更新全局状态
    await BiometricService.setEnabled(value);

    // 3. 更新 UI
    setState(() {
      _isBiometricEnabled = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? "应用锁已开启" : "应用锁已关闭")),
      );
    }
  }


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
          // 👇👇👇 新增：安全设置组 👇👇👇
          _buildSection(
            title: '隐私与安全',
            children: [
              SwitchListTile(
                title: const Text('生物识别应用锁'),
                subtitle: const Text('启动时验证面容或指纹'),
                secondary: const Icon(Icons.fingerprint),
                value: _isBiometricEnabled,
                activeColor: Theme.of(context).primaryColor,
                onChanged: _toggleAppLock,
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
                  // print('点击了隐私政策'); // 旧代码

                  // --- 新代码开始 ---
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyPage(),
                    ),
                  );
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