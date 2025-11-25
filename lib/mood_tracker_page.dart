import 'package:flutter/material.dart';
import 'mood_detail_page.dart';
import 'mood_service.dart';
import 'mood_model.dart';

class MoodTrackerPage extends StatefulWidget {
  final int userId; // 必须传入 userId

  const MoodTrackerPage({super.key, required this.userId});

  @override
  State<MoodTrackerPage> createState() => _MoodTrackerPageState();
}

class _MoodTrackerPageState extends State<MoodTrackerPage> {
  final MoodService _moodService = MoodService();
  final TextEditingController _contentController = TextEditingController();

  String _selectedMood = "平静";
  bool _isSubmitting = false;

  // 本次提交后的 AI 回复（临时展示）
  String? _currentAiResponse;

  // 历史记录列表
  List<MoodRecord> _historyList = [];
  bool _isLoadingHistory = true;

  final Map<String, String> _moodOptions = {
    "开心": "😄", "平静": "☕", "难过": "😢", "焦虑": "🌀", "生气": "😡",
  };

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // 加载历史
  Future<void> _loadHistory() async {
    try {
      final list = await _moodService.getHistory(widget.userId);
      setState(() {
        _historyList = list;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() => _isLoadingHistory = false);
      // 这里可以加个 Toast 提示失败
    }
  }

  // 提交新心情
  void _submit() async {
    if (_contentController.text.trim().isEmpty && _selectedMood == "平静") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("写点什么吧~")));
      return;
    }

    setState(() {
      _isSubmitting = true;
      _currentAiResponse = null;
    });

    try {
      // 1. 发送给后端
      final aiReply = await _moodService.submitMood(
        userId: widget.userId,
        moodType: _selectedMood,
        content: _contentController.text,
      );

      // 2. 更新 UI
      setState(() {
        _currentAiResponse = aiReply;
        _contentController.clear();
        _selectedMood = "平静"; // 重置
      });

      // 3. 重新刷新历史列表，把刚存的那条拉回来
      _loadHistory();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("提交失败: $e")));
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // 处理列表页的时间显示（转为本地时区）
  String _formatDateForList(String isoString) {
    try {
      final DateTime dt = DateTime.parse(isoString).toLocal(); // 关键：转为本地时间

      // 补零操作，比如把 9 变成 09
      String year = dt.year.toString();
      String month = dt.month.toString().padLeft(2, '0');
      String day = dt.day.toString().padLeft(2, '0');

      // 如果你想在列表也显示几点几分，可以加上这两行：
      // String hour = dt.hour.toString().padLeft(2, '0');
      // String minute = dt.minute.toString().padLeft(2, '0');
      // return "$year-$month-$day $hour:$minute";

      return "$year-$month-$day"; // 列表页只显示日期看起来比较清爽
    } catch (e) {
      // 解析失败兜底，防止崩溃
      return isoString.length > 10 ? isoString.substring(0, 10) : isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text("心情日记")),
      body: Column(
        children: [
          // === 上半部分：输入区 ===
          Expanded(
            flex: 6, // 占 60% 高度
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("此刻心情如何？", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  // 心情选择器
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _moodOptions.keys.map((key) {
                        final isSelected = _selectedMood == key;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text("${_moodOptions[key]} $key"),
                            selected: isSelected,
                            selectedColor: primaryColor.withOpacity(0.2),
                            onSelected: (bool selected) {
                              if (selected) setState(() => _selectedMood = key);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 输入框
                  TextField(
                    controller: _contentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "记录当下的想法...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 提交按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                      label: Text(_isSubmitting ? "AI 正在生成温暖..." : "记录并获取鼓励"),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),

                  // === 本次 AI 回复展示 (仅当次显示) ===
                  if (_currentAiResponse != null)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(Icons.auto_awesome, color: Colors.amber), SizedBox(width: 8), Text("AI 暖心回信", style: TextStyle(fontWeight: FontWeight.bold))]),
                          const SizedBox(height: 8),
                          Text(_currentAiResponse!, style: const TextStyle(height: 1.5)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // === 下半部分：历史记录列表 ===
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            width: double.infinity,
            color: Theme.of(context).cardColor,
            child: const Text("历史足迹", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 4, // 占 40% 高度
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _historyList.isEmpty
                ? Center(child: Text("还没有记录哦，开始第一条吧~", style: TextStyle(color: Colors.grey[400])))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _historyList.length,
              itemBuilder: (context, index) {
                final item = _historyList[index];
                // 👇👇👇 修改开始：包裹 GestureDetector 或 InkWell 👇👇👇
                return GestureDetector(
                  onTap: () {
                    // 跳转到详情页
                    // 记得在文件顶部 import 'mood_detail_page.dart';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MoodDetailPage(record: item),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2, // 稍微加点阴影更有质感
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                // 添加 Hero 动画标签，和详情页对应
                                Hero(
                                  tag: 'mood_icon_${item.id}',
                                  child: Text(
                                    _moodOptions[item.moodType] ?? "😐",
                                    style: const TextStyle(fontSize: 24, decoration: TextDecoration.none), // 确保 Hero 动画没下划线
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(item.moodType, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ]),
                              Text(
                                //调用转换时区函数
                                _formatDateForList(item.createdAt),
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                          if (item.content.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              item.content,
                              maxLines: 2, // 列表页只显示 2 行，多余的省略
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8)),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // 列表页简单展示 AI 回复的前面一部分
                          Container(
                            padding: const EdgeInsets.all(8),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "AI: ${item.aiResponse}",
                              maxLines: 1, // AI 回复也只显示一行
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                            ),
                          ),

                          // 增加一个小箭头提示可以点击
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[400]),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}