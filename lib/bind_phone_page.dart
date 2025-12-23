// === bind_phone_page.dart (全新文件) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class BindPhonePage extends StatefulWidget {
  final int userId;
  const BindPhonePage({super.key, required this.userId});

  @override
  State<BindPhonePage> createState() => _BindPhonePageState();
}

class _BindPhonePageState extends State<BindPhonePage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSendingCode = false;
  bool _isBinding = false;

  final String _apiUrl = AppConfig.baseUrl; // ！！！！请务必替换为您自己的IP地址！！！！

  // 发送验证码 (复用 login_page.dart 的逻辑)
  Future<void> _sendCode() async {
    if (_isSendingCode || _phoneController.text.isEmpty) return;
    setState(() { _isSendingCode = true; });
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/send-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': _phoneController.text}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.statusCode == 200 ? '验证码已发送' : '发送失败')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('网络错误: $e')));
    } finally {
      if (mounted) setState(() { _isSendingCode = false; });
    }
  }

  // 绑定手机号
  Future<void> _bindPhone() async {
    if (_isBinding || _phoneController.text.isEmpty || _codeController.text.isEmpty) return;
    setState(() { _isBinding = true; });

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/user/bind-phone'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'phone': _phoneController.text,
          'code': _codeController.text,
        }),
      );

      if (!mounted) return;
      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('绑定成功！'), backgroundColor: Colors.green),
        );
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.of(context).pop(true); // 返回 true 表示绑定成功
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('绑定失败: ${responseBody['message']}')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('网络错误: $e')));
    } finally {
      if (mounted) setState(() { _isBinding = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('绑定手机号')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("绑定手机号后，可用于登录或找回密码，增强账户安全。"),
            const SizedBox(height: 40),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '手机号',
                prefixIcon: const Icon(Icons.phone_iphone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isSendingCode ? null : _sendCode,
                  child: _isSendingCode ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('获取验证码'),
                ),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isBinding ? null : _bindPhone,
              child: _isBinding ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('确认绑定'),
            ),
          ],
        ),
      ),
    );
  }
}