import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart'; // 假设你的首页在 main.dart，用于删除好友后跳转

class UserInfoMorePage extends StatefulWidget {
  final int currentUserId;
  final int targetUserId;
  final String nickname;     // 传入当前显示的名称
  final String introduction; // 传入完整的简介
  final String avatarUrl;

  const UserInfoMorePage({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    required this.nickname,
    required this.introduction,
    required this.avatarUrl,
  });

  @override
  State<UserInfoMorePage> createState() => _UserInfoMorePageState();
}

class _UserInfoMorePageState extends State<UserInfoMorePage> {
  bool _isBlacklisted = false;
  bool _isLoading = false;

  // 1. 【新增】用于存储详细信息的变量
  String _gender = "加载中...";
  String _region = "加载中...";
  String _fullIntroduction = ""; // 用于存储最新拉取的完整简介

  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    _fullIntroduction = widget.introduction;
    _fetchTargetUserInfo(); // 拉取详细资料
    _checkBlacklistStatus(); // 1. 【新增】进来就查黑名单状态
  }

  // 3. 【核心】获取目标用户的详细信息 (包含性别、地区)
  Future<void> _fetchTargetUserInfo() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/profile/${widget.targetUserId}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        if (mounted) {
          setState(() {
            // 解析后端返回的字段，注意字段名要和数据库/后端一致
            _gender = data['gender'] ?? '保密';
            _region = data['region'] ?? '未知';
            _fullIntroduction = data['introduction'] ?? '暂无签名';
          });
        }
      }
    } catch (e) {
      if(mounted) setState(() { _gender = "未知"; _region = "未知"; });
    }
  }

  // --- 【新增】查询初始黑名单状态 ---
  Future<void> _checkBlacklistStatus() async {
    try {
      final uri = Uri.parse('$_apiUrl/api/blacklist/check?userId=${widget.currentUserId}&targetId=${widget.targetUserId}');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _isBlacklisted = data['isBlacklisted'] == true;
          });
        }
      }
    } catch (e) {
      print("检查黑名单状态失败: $e");
    }
  }

  // --- 【完善】功能 1: 加入/移出黑名单 ---
  Future<void> _toggleBlacklist(bool value) async {
    // 1. 乐观更新 UI (让开关立马变，体验好)
    setState(() => _isBlacklisted = value);

    try {
      // 2. 调用后端 API
      final response = await http.post(
        Uri.parse('$_apiUrl/api/blacklist/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.currentUserId,
          'targetId': widget.targetUserId,
          'action': value ? 'block' : 'unblock', // value为true代表要拉黑
        }),
      );

      // 3. 检查结果
      if (response.statusCode != 200) {
        // 如果失败了，把开关拨回去
        if (mounted) {
          setState(() => _isBlacklisted = !value);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("操作失败，请检查网络")));
        }
      } else {
        // 成功提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(value ? "已加入黑名单，将不再接收对方消息" : "已移出黑名单")),
          );
        }
      }
    } catch (e) {
      // 网络异常，回滚状态
      if (mounted) {
        setState(() => _isBlacklisted = !value);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("网络错误")));
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? "已加入黑名单" : "已移出黑名单")),
    );
  }

  // --- 功能 2: 删除好友 ---
  // --- 功能 2: 删除好友 (修正版) ---
  Future<void> _deleteFriend() async {
    // 1. 弹窗确认
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("删除联系人"),
          content: Text("将联系人“${widget.nickname}”删除，同时删除与该联系人的聊天记录。"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("删除", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    // 如果用户点了取消，直接返回
    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // 2. 调用后端 API
      // 注意：这里必须使用 delete 方法，且 header 要设置 JSON
      final response = await http.delete(
        Uri.parse('$_apiUrl/api/friends/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          // ！！！关键点：这里必须和你的 Node.js 后端 req.body 里的 key 完全一致 ！！！
          'myUserId': widget.currentUserId,
          'friendUserId': widget.targetUserId,
        }),
      );

      // 解析返回结果
      final resBody = jsonDecode(response.body);

      // 你的后端成功返回的是 { code: 200, msg: '已删除好友' }
      if (response.statusCode == 200 && resBody['code'] == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已删除好友")));

        // 3. 删除成功后，跳转回首页
        // (route) => false 表示清空之前的所有路由，防止点返回键又回到这个人的页面
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } else {
        throw Exception(resBody['msg'] ?? "删除失败");
      }
    } catch (e) {
      if (!mounted) return;
      print("删除错误: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("操作失败，请检查网络")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 适配深色模式颜色
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      appBar: AppBar(title: const Text("更多信息")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          const SizedBox(height: 10),

          // --- 第一组：基础信息 ---
          Container(
            color: cardColor,
            child: Column(
              children: [
                // 1. 完整的个人简介
                ListTile(
                  title: Text("个性签名", style: TextStyle(fontSize: 15, color: textColor)),
                  subtitle: Text(
                      widget.introduction.isEmpty ? "暂无签名" : widget.introduction,
                      style: TextStyle(fontSize: 13, color: subTextColor)
                  ),
                ),
                _buildDivider(context),

                // 2. 性别 (示例数据)
                _buildInfoRow(context, "性别", _gender),
                _buildDivider(context),

                // 3. 地区 (示例数据)
                _buildInfoRow(context, "地区", _region),
                _buildDivider(context),

                // 4. 用户ID (方便查找)
                ListTile(
                  title: Text("晗伴号", style: TextStyle(fontSize: 15, color: textColor)),
                  trailing: Text("${widget.targetUserId}", style: TextStyle(color: subTextColor, fontSize: 14)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- 第二组：权限管理 ---
          Container(
            color: cardColor,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text("加入黑名单", style: TextStyle(fontSize: 15, color: textColor)),
                  value: _isBlacklisted,
                  onChanged: _toggleBlacklist,
                  activeColor: Theme.of(context).primaryColor,
                ),
                _buildDivider(context),
                ListTile(
                  title: Text("投诉", style: TextStyle(fontSize: 15, color: textColor)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: subTextColor),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("投诉功能开发中")));
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // --- 第三组：危险操作 ---
          Container(
            color: cardColor,
            child: ListTile(
              title: const Center(
                child: Text("删除好友", style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              onTap: _deleteFriend,
            ),
          ),

          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // 辅助方法：构建纯展示的行
  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      title: Text(label, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
      trailing: Text(value, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
    );
  }

  // 辅助方法：构建分割线
  Widget _buildDivider(BuildContext context) {
    return Divider(height: 1, indent: 16, color: Theme.of(context).dividerColor.withOpacity(0.1));
  }
}