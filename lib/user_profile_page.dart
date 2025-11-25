// === user_profile_page.dart (UI重构 & 深色模式适配版) ===
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'private_chat_page.dart';
import 'photo_gallery_page.dart';

class UserProfilePage extends StatefulWidget {
  final int currentUserId; // 我
  final int targetUserId;  // 对方
  final String nickname;
  final String avatarUrl;
  final String introduction;
  final String myAvatarUrl; // 传给聊天页用

  const UserProfilePage({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    required this.nickname,
    required this.avatarUrl,
    required this.introduction,
    required this.myAvatarUrl,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  // 简单的预览照片列表
  List<String> _previewPhotos = [];
  final String _apiUrl = 'http://192.168.23.18:3000'; // 替换IP

  @override
  void initState() {
    super.initState();
    _fetchPreviewPhotos();
  }

  // 预取几张照片用于展示在资料页
  Future<void> _fetchPreviewPhotos() async {
    try {
      final res = await http.get(Uri.parse('$_apiUrl/api/photos/user/${widget.targetUserId}?currentUserId=${widget.currentUserId}'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body)['data'];
        // 只取前4张图片做预览
        setState(() {
          _previewPhotos = data
              .where((item) => item['media_type'] == 'image' || item['media_type'] == null) // 只要图片
              .take(4)
              .map<String>((item) => item['url'] ?? item['media_url'])
              .toList();
        });
      }
    } catch (e) {
      // 忽略错误，预览加载失败不影响主功能
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前主题亮度，用于手动微调颜色
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      appBar: AppBar(
        title: const Text("详细资料"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 1. 个人信息卡片
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? [] : [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              child: Row(
                children: [
                  // 头像
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.network(
                        widget.avatarUrl,
                        width: 70, height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(width: 70, height: 70, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // 名字和简介
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.nickname,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.introduction.isEmpty ? "暂无简介" : widget.introduction,
                          style: TextStyle(fontSize: 14, color: subTextColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. 照片墙入口 (带预览)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PhotoGalleryPage(
                        userId: widget.targetUserId,
                        viewerId: widget.currentUserId,
                        isMe: widget.targetUserId == widget.currentUserId,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("照片墙", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                          Icon(Icons.chevron_right, color: subTextColor),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 预览缩略图区域
                      if (_previewPhotos.isNotEmpty)
                        SizedBox(
                          height: 60,
                          child: Row(
                            children: _previewPhotos.map((url) {
                              return Container(
                                margin: const EdgeInsets.only(right: 10),
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      else
                        Text("暂无公开照片", style: TextStyle(color: subTextColor, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. 更多设置/信息 (可选，为了让页面丰满一点)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildSettingsItem(context, "设置备注和标签", showDivider: true),
                  _buildSettingsItem(context, "更多信息", showDivider: false),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 4. 发消息按钮
            if (widget.targetUserId != widget.currentUserId)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text("发消息", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrivateChatPage(
                            currentUserId: widget.currentUserId,
                            otherUserId: widget.targetUserId,
                            otherUserNickname: widget.nickname,
                            otherUserAvatar: widget.avatarUrl,
                            currentUserAvatar: widget.myAvatarUrl,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(BuildContext context, String title, {bool showDivider = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        ListTile(
          title: Text(title, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
          trailing: Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[300]),
          onTap: () {
            // 待开发功能
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("功能开发中...")));
          },
        ),
        if (showDivider)
          Divider(height: 1, indent: 16, endIndent: 16, color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ],
    );
  }
}