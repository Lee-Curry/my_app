// === account_security_page.dart (最终修复版 - 完整代码) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'bind_phone_page.dart'; // 1. 【新增】导入新页面

class AccountSecurityPage extends StatefulWidget {
  final int userId;
  const AccountSecurityPage({super.key, required this.userId});

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  bool _isLoading = true;
  String? _phoneNumber;
  String? _registrationDate;
  String _errorMessage = '';

  final String _apiUrl = 'http://192.168.23.18:3000'; // ！！！！请务必替换为您自己的IP地址！！！！

  @override
  void initState() {
    super.initState();
    _fetchAccountInfo();
  }
  // 2. 【新增】跳转到绑定手机页的函数
  Future<void> _navigateToBindPhone() async {
    final bool? phoneHasBeenBound = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BindPhonePage(userId: widget.userId),
      ),
    );
    // 如果绑定成功，返回后自动刷新本页面信息
    if (phoneHasBeenBound == true && mounted) {
      _fetchAccountInfo();
    }
  }

  // --- 【核心改造】_fetchAccountInfo 函数 ---
  Future<void> _fetchAccountInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/api/account/security/${widget.userId}'),
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body)['data'];
          setState(() {
            _phoneNumber = data['phoneNumber'];
            _registrationDate = data['registrationDate'];
            _isLoading = false;
          });
        } else {
          // 【核心修改】不再抛出异常，而是直接从后端响应中提取错误信息并设置
          final errorBody = json.decode(response.body);
          setState(() {
            _errorMessage = '加载失败: ${errorBody['message'] ?? '未知服务器错误'}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // 捕获网络连接等异常
      if (mounted) {
        setState(() {
          _errorMessage = '网络错误: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账号与安全')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(child: Text('出错了: $_errorMessage'))
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_iphone),
                  title: const Text('手机号码'),
                  subtitle: Text(
                    _phoneNumber ?? '未获取到',
                    style: TextStyle(
                      fontSize: 16,
                      // 3. 【新增】如果是未绑定状态，显示不同颜色
                      color: _phoneNumber == "未绑定手机号" ? Colors.orange[700] : null,
                    ),
                  ),
                  // 4. 【新增】智能显示“去绑定”或“更换”的尾部按钮
                  trailing: _phoneNumber == "未绑定手机号"
                      ? Icon(Icons.chevron_right, color: Colors.orange[700])
                      : null, // 如果已绑定，就不显示箭头
                  onTap: _phoneNumber == "未绑定手机号"
                      ? _navigateToBindPhone // 如果未绑定，点击就跳转
                      : null, // 如果已绑定，点击无效果 (未来可以做更换手机号)
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('注册日期'),
                  subtitle: Text(
                    _registrationDate ?? '未获取到',
                    style: const TextStyle(fontSize: 16),
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