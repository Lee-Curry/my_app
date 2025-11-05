// === login_page.dart (黄金版 - 真实网络请求，非持久化 - 完整代码) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- 欢迎页 ---
class WelcomePage extends StatelessWidget {
  final VoidCallback onLoginSuccess;
  const WelcomePage({super.key, required this.onLoginSuccess});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.memory,
                size: 80,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 24),
              const Text(
                '欢迎回来',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Text(
                '登录以继续您的智能之旅',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const Spacer(flex: 3),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PhoneLoginPage(
                            onLoginSuccess: onLoginSuccess)),
                  );
                },
                icon: const Icon(Icons.phone_iphone),
                label: const Text('手机号登录/注册'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => print('调用微信登录'),
                icon: const Icon(Icons.wechat, color: Colors.white),
                label: const Text('微信一键登录'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09B659),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 手机号登录页 ---
class PhoneLoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const PhoneLoginPage({super.key, required this.onLoginSuccess});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final String _apiUrl =
      'http://10.61.193.166:3000'; // ！！！！请务必替换为您自己的IP地址！！！！
  bool _isSendingCode = false;
  bool _isLoggingIn = false;

  Future<void> _sendCode() async {
    if (_isSendingCode) return;
    if (_phoneController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入手机号')));
      return;
    }
    setState(() {
      _isSendingCode = true;
    });
    try {
      final response = await http
          .post(
        Uri.parse('$_apiUrl/api/send-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': _phoneController.text}),
      )
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('验证码已发送(请查看后端控制台)')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
              Text('发送失败: ${json.decode(response.body)['message']}')));
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('网络错误或连接超时: $e')));
    } finally {
      if (mounted)
        setState(() {
          _isSendingCode = false;
        });
    }
  }

  Future<void> _login() async {
    if (_isLoggingIn) return;
    if (_phoneController.text.isEmpty || _codeController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入手机号和验证码')));
      return;
    }
    setState(() {
      _isLoggingIn = true;
    });
    try {
      final response = await http
          .post(
        Uri.parse('$_apiUrl/api/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': _phoneController.text,
          'code': _codeController.text
        }),
      )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        // 调用回调，通知 MyApp 登录成功！
        widget.onLoginSuccess();

        // 移除所有登录页面，确保用户无法返回
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        final responseBody = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('登录失败: ${responseBody['message']}')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('网络错误或连接超时: $e')));
    } finally {
      if (mounted)
        setState(() {
          _isLoggingIn = false;
        });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('手机号登录'),
          backgroundColor: Colors.transparent,
          elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '手机号',
                prefixIcon: const Icon(Icons.phone_iphone),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '验证码',
                      prefixIcon: const Icon(Icons.password),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isSendingCode ? null : _sendCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSendingCode
                      ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('获取验证码'),
                ),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoggingIn ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: _isLoggingIn
                  ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('登 录'),
            ),
          ],
        ),
      ),
    );
  }
}