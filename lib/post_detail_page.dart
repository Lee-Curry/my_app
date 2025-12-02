// === post_detail_page.dart (带图片轮播指示点版) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'media_viewer_page.dart'; // 导入大图查看器
import 'photo_gallery_page.dart'; // 导入 MediaItem 和 GalleryVideoThumbnail

class PostDetailPage extends StatefulWidget {
  final int postId;
  final int viewerId;
  final String apiUrl;

  const PostDetailPage({
    super.key,
    required this.postId,
    required this.viewerId,
    required this.apiUrl,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  Map<String, dynamic>? _postData;
  bool _isLoading = true;
  String _errorMessage = '';

  // 交互状态
  bool _isLiked = false;
  int _likeCount = 0;
  List _comments = [];

  // 👇👇👇 1. 新增：记录当前轮播图的索引 👇👇👇
  int _currentMediaIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final uri = Uri.parse('${widget.apiUrl}/api/posts/detail/${widget.postId}?viewerId=${widget.viewerId}');
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        if(mounted) setState(() {
          _postData = data;
          _isLiked = data['isLiked'];
          _likeCount = data['likes'].length;
          _comments = data['comments'];
          _isLoading = false;
        });
      } else {
        final errorBody = jsonDecode(res.body);
        throw Exception(errorBody['msg'] ?? "HTTP ${res.statusCode}");
      }
    } catch (e) {
      if(mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      await http.post(
          Uri.parse('${widget.apiUrl}/api/photos/like'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'photoId': widget.postId, 'userId': widget.viewerId})
      );
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _CommentsBottomSheet(
        comments: _comments,
        photoId: widget.postId,
        viewerId: widget.viewerId,
        apiUrl: widget.apiUrl,
        onCommentSuccess: _fetchDetail,
      ),
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      return "${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
    } catch (e) {
      return isoTime;
    }
  }

  void _openFullScreen(int initialIndex, List mediaList, Map post) {
    final List<MediaItem> items = mediaList.map<MediaItem>((m) {
      return MediaItem(
        id: 0,
        mediaUrl: m['media_url'],
        mediaType: m['media_type'],
        userNickname: post['nickname'],
        userAvatarUrl: post['avatar_url'],
      );
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaViewerPage(
          mediaItems: items,
          initialIndex: initialIndex,
          viewerId: widget.viewerId,
          apiUrl: widget.apiUrl,
          isPureView: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    if (_isLoading) return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));

    if (_postData == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(backgroundColor: bgColor, elevation: 0, leading: const BackButton()),
        body: Center(child: Text(_errorMessage, style: TextStyle(color: Colors.grey))),
      );
    }

    final post = _postData!['post'];
    final List media = _postData!['media'];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: const BackButton(),
        title: Row(
          children: [
            CircleAvatar(radius: 15, backgroundImage: NetworkImage(post['avatar_url'])),
            const SizedBox(width: 8),
            Text(post['nickname'], style: TextStyle(fontSize: 14, color: textColor)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. 【核心修改】使用 Stack 包裹 PageView 和 指示点
                  if (media.isNotEmpty)
                    SizedBox(
                      height: 400,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          PageView.builder(
                            itemCount: media.length,
                            // 👇 监听滑动，更新索引
                            onPageChanged: (index) {
                              setState(() {
                                _currentMediaIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final item = media[index];
                              return GestureDetector(
                                onTap: () => _openFullScreen(index, media, post),
                                child: item['media_type'] == 'video'
                                    ? GalleryVideoThumbnail(videoUrl: item['media_url'])
                                    : Image.network(item['media_url'], fit: BoxFit.contain),
                              );
                            },
                          ),

                          // 👇👇👇 指示点 (只有多张图时才显示) 👇👇👇
                          if (media.length > 1)
                            Positioned(
                              bottom: 10,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(media.length, (index) {
                                  return Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        // 选中的是白色，未选中的是半透明白
                                        color: _currentMediaIndex == index
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.4),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))
                                        ]
                                    ),
                                  );
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (post['title'] != null && post['title'].isNotEmpty)
                          Text(post['title'], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 10),
                        Text(
                            post['content'] ?? '',
                            style: TextStyle(fontSize: 16, height: 1.6, color: isDark ? Colors.white70 : Colors.black87)
                        ),
                        const SizedBox(height: 20),
                        Text("发布于 ${_formatTime(post['created_at'])}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  InkWell(
                    onTap: _showComments,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text("共 ${_comments.length} 条评论", style: const TextStyle(color: Colors.grey)),
                          const Spacer(),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _comments.length > 2 ? 2 : _comments.length,
                    itemBuilder: (context, index) {
                      final c = _comments[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RichText(
                            text: TextSpan(
                              style: TextStyle(color: textColor, fontSize: 14),
                              children: [
                                TextSpan(text: "${c['nickname']}: ", style: const TextStyle(color: Colors.grey)),
                                TextSpan(text: c['content']),
                              ],
                            )
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _showComments,
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20)
                        ),
                        alignment: Alignment.centerLeft,
                        child: const Text("说点什么...", style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : Colors.grey, size: 24),
                        if (_likeCount > 0)
                          Text("$_likeCount", style: const TextStyle(fontSize: 10, color: Colors.grey))
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: _showComments,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 24),
                        if (_comments.isNotEmpty)
                          Text("${_comments.length}", style: const TextStyle(fontSize: 10, color: Colors.grey))
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 底部评论弹窗 (保持不变)
class _CommentsBottomSheet extends StatefulWidget {
  final List comments;
  final int photoId;
  final int viewerId;
  final String apiUrl;
  final VoidCallback onCommentSuccess;

  const _CommentsBottomSheet({required this.comments, required this.photoId, required this.viewerId, required this.apiUrl, required this.onCommentSuccess});

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  Map<String, dynamic>? _replyToUser;
  late List _localComments;

  @override
  void initState() {
    super.initState();
    _localComments = widget.comments;
  }

  // 刷新评论列表
  Future<void> _refreshLocalComments() async {
    try {
      final res = await http.get(Uri.parse('${widget.apiUrl}/api/posts/detail/${widget.photoId}?viewerId=${widget.viewerId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        if (mounted) {
          setState(() { _localComments = data['comments']; });
        }
      }
    } catch (e) { print("刷新评论失败: $e"); }
  }

  Future<void> _sendComment() async {
    if (_textController.text.trim().isEmpty) return;
    try {
      final body = { 'photoId': widget.photoId, 'userId': widget.viewerId, 'content': _textController.text };
      if (_replyToUser != null) body['replyToUserId'] = _replyToUser!['user_id'];

      final res = await http.post(
          Uri.parse('${widget.apiUrl}/api/photos/comment'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body)
      );

      if (res.statusCode == 200) {
        _textController.clear();
        setState(() => _replyToUser = null);
        FocusScope.of(context).unfocus();

        await _refreshLocalComments(); // 刷新本地列表
        widget.onCommentSuccess(); // 刷新外部页面
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
            child: Text("${_localComments.length} 条评论", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _localComments.length,
              itemBuilder: (context, index) {
                final c = _localComments[index];
                return InkWell(
                  onTap: () => setState(() => _replyToUser = {'user_id': c['user_id'], 'nickname': c['nickname']}),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(radius: 16, backgroundImage: NetworkImage(c['avatar_url'] ?? '')),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c['nickname'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 4),
                            RichText(text: TextSpan(style: const TextStyle(color: Colors.white, fontSize: 14), children: [
                              if (c['reply_nickname'] != null) ...[
                                const TextSpan(text: "回复 "),
                                TextSpan(text: "@${c['reply_nickname']} ", style: const TextStyle(color: Colors.blueGrey)),
                              ],
                              TextSpan(text: c['content']),
                            ])),
                          ]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_replyToUser != null)
            Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.white10,
              child: Row(children: [Text("回复 @${_replyToUser!['nickname']}", style: const TextStyle(color: Colors.grey, fontSize: 12)), const Spacer(), GestureDetector(onTap: () => setState(() => _replyToUser = null), child: const Icon(Icons.close, size: 16, color: Colors.grey))]),
            ),
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF2C2C2C),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _replyToUser != null ? "回复 @${_replyToUser!['nickname']}..." : "说点什么...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Colors.black38,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(onPressed: _sendComment, icon: const Icon(Icons.send, color: Colors.blue)),
              ],
            ),
          )
        ],
      ),
    );
  }
}