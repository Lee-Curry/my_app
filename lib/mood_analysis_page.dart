import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'mood_model.dart';
import 'mood_detail_page.dart'; // 用于日历点击跳转详情

class MoodAnalysisPage extends StatefulWidget {
  final List<MoodRecord> records; // 直接从上一页传数据过来，不用重新请求

  const MoodAnalysisPage({super.key, required this.records});

  @override
  State<MoodAnalysisPage> createState() => _MoodAnalysisPageState();
}

class _MoodAnalysisPageState extends State<MoodAnalysisPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 日历相关状态
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late ValueNotifier<List<MoodRecord>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_focusedDay));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _selectedEvents.dispose();
    super.dispose();
  }

  // --- 数据处理辅助方法 ---

  // 1. 获取某天的所有心情记录
  List<MoodRecord> _getEventsForDay(DateTime day) {
    return widget.records.where((record) {
      // 解析数据库的时间字符串
      final recordDate = DateTime.parse(record.createdAt).toLocal();
      return isSameDay(recordDate, day);
    }).toList();
  }

  // 2. 心情转数值（用于折线图：越高越开心）
  double _getMoodScore(String mood) {
    switch (mood) {
      case "开心": return 5;
      case "平静": return 3; // 平静居中
      case "焦虑": return 2;
      case "难过": return 1;
      case "生气": return 0;
      default: return 3;
    }
  }

  // 3. 心情转颜色
  Color _getMoodColor(String mood) {
    switch (mood) {
      case "开心": return Colors.orange;
      case "平静": return Colors.blue;
      case "焦虑": return Colors.purple;
      case "难过": return Colors.grey;
      case "生气": return Colors.red;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("心情足迹"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "趋势图表", icon: Icon(Icons.insights)),
            Tab(text: "心情日历", icon: Icon(Icons.calendar_month)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChartsTab(),
          _buildCalendarTab(),
        ],
      ),
    );
  }

  // ================= Tab 1: 图表视图 =================
  Widget _buildChartsTab() {
    if (widget.records.isEmpty) {
      return const Center(child: Text("暂无数据，快去记录一条吧~"));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("情绪分布 (Pie Chart)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          // --- 饼图 ---
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: _getPieSections(),
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildPieLegend(), // 图例

          const Divider(height: 40),

          const Text("情绪波动趋势 (最近7条)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          // --- 折线图 ---
          SizedBox(
            height: 250,
            child: LineChart(
              _getLineChartData(),
            ),
          ),
        ],
      ),
    );
  }

  // 饼图数据生成
  List<PieChartSectionData> _getPieSections() {
    Map<String, int> moodCounts = {};
    for (var r in widget.records) {
      moodCounts[r.moodType] = (moodCounts[r.moodType] ?? 0) + 1;
    }

    int total = widget.records.length;
    return moodCounts.entries.map((entry) {
      final isLarge = entry.value / total > 0.3; // 占比大的稍微突出一点
      return PieChartSectionData(
        color: _getMoodColor(entry.key),
        value: entry.value.toDouble(),
        title: '${(entry.value / total * 100).toStringAsFixed(0)}%',
        radius: isLarge ? 60 : 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  // 饼图图例
  Widget _buildPieLegend() {
    Map<String, int> moodCounts = {};
    for (var r in widget.records) {
      moodCounts[r.moodType] = (moodCounts[r.moodType] ?? 0) + 1;
    }

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: moodCounts.keys.map((mood) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, color: _getMoodColor(mood)),
            const SizedBox(width: 4),
            Text("$mood (${moodCounts[mood]})"),
          ],
        );
      }).toList(),
    );
  }

  // 折线图数据生成
  LineChartData _getLineChartData() {
    // 1. 按时间排序，取最近的10条（避免图表太挤）
    List<MoodRecord> sorted = List.from(widget.records);
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (sorted.length > 10) sorted = sorted.sublist(sorted.length - 10);

    List<FlSpot> spots = [];
    for (int i = 0; i < sorted.length; i++) {
      spots.add(FlSpot(i.toDouble(), _getMoodScore(sorted[i].moodType)));
    }

    return LineChartData(
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        // Y轴自定义：显示心情文字而不是数字
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              switch (value.toInt()) {
                case 5: return const Text('😄');
                case 3: return const Text('☕');
                case 2: return const Text('🌀');
                case 1: return const Text('😢');
                case 0: return const Text('😡');
                default: return const Text('');
              }
            },
            reservedSize: 30,
          ),
        ),
        // X轴：显示日期
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              int index = value.toInt();
              if (index >= 0 && index < sorted.length) {
                DateTime date = DateTime.parse(sorted[index].createdAt).toLocal();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(DateFormat('MM-dd').format(date), style: const TextStyle(fontSize: 10)),
                );
              }
              return const Text('');
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true, // 平滑曲线
          color: Colors.blueAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.1)),
        ),
      ],
      minY: -0.5,
      maxY: 5.5,
    );
  }

  // ================= Tab 2: 日历视图 =================
  Widget _buildCalendarTab() {
    return Column(
      children: [
        TableCalendar<MoodRecord>(
          firstDay: DateTime.utc(2023, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),

          // 1. 【修改】这里不要写死，而是使用变量
          calendarFormat: _calendarFormat,

          // 2. 【新增】这一段是核心：点击按钮时切换视图
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() {
                _calendarFormat = format;
              });
            }
          },

          // 3. 【推荐】自定义按钮显示的文字和支持的格式
          // 如果你不写这一段，默认会有 Month, 2 weeks, Week 三种
          // 下面这样写，就只会有 "Month" 和 "Week" 两种切换，更符合习惯
          availableCalendarFormats: const {
            CalendarFormat.month: '月视图', // 按钮上显示的文字
            CalendarFormat.twoWeeks: '双周',
            CalendarFormat.week: '周视图',
          },

          // 如果你之前加了 headerStyle 把 formatButtonVisible 设为 false 了
          // 记得删掉或者改回 true
          headerStyle: const HeaderStyle(
            formatButtonVisible: true, // 确保按钮是可见的
            titleCentered: true,
            formatButtonShowsNext: false, // false=显示当前模式，true=显示下一个模式
          ),

          eventLoader: _getEventsForDay,
          startingDayOfWeek: StartingDayOfWeek.monday,

          // 样式自定义
          calendarStyle: CalendarStyle(
            markerDecoration: const BoxDecoration(
              color: Colors.pinkAccent, // 标记点的颜色
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),

          // 点击事件
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
              _selectedEvents.value = _getEventsForDay(selectedDay);
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text("当选日期的记录", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        // 选中日期的列表
        Expanded(
          child: ValueListenableBuilder<List<MoodRecord>>(
            valueListenable: _selectedEvents,
            builder: (context, value, _) {
              if (value.isEmpty) {
                return const Center(child: Text("这一天没有记录心情哦"));
              }
              return ListView.builder(
                itemCount: value.length,
                itemBuilder: (context, index) {
                  final record = value[index];
                  return ListTile(
                    leading: Text(
                      _getMoodEmoji(record.moodType),
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(record.moodType),
                    subtitle: Text(
                        record.content.isEmpty ? "无内容" : record.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // 跳转详情
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MoodDetailPage(record: record)),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _getMoodEmoji(String mood) {
    const map = {"开心": "😄", "平静": "☕", "难过": "😢", "焦虑": "🌀", "生气": "😡"};
    return map[mood] ?? "😐";
  }
}