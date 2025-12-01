// === main.dart (最终整合版 - 完整代码) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';
import 'edit_profile_page.dart' as edit_page; // 1. 使用别名导入，避免类名冲突
import 'auth_service.dart';
import 'main.dart' as edit_page;
import 'mood_tracker_page.dart';
import 'photo_gallery_page.dart';
import 'settings_page.dart';
import 'about_us_page.dart';
import 'chat_sessions_list_page.dart';
import 'set_password_page.dart'; // 2. 【新增】导入新页面
import 'conversations_list_page.dart'; // 1. 【新增】导入新页面
import 'web_socket_service.dart';
import 'contacts_page.dart'; // 👈 新增导入
import 'avatar_viewer_page.dart'; // 👈 记得加这行

// --- 新的数据模型 (UserProfileData) ---
// 在 main.dart 的顶部

// --- 【最终完整版】数据模型 (UserProfileData) ---
class UserProfileData {
  final int id;
  final String? username; // 1. 【新增】接收 username，设为可空
  final String nickname;
  final String introduction;
  final String? birthDate;
  final String avatarUrl;
  final bool hasPassword;

  UserProfileData({
    required this.id,
    this.username, // 2. 【新增】在构造函数里添加
    required this.nickname,
    required this.introduction,
    this.birthDate,
    required this.avatarUrl,
    required this.hasPassword,
  });
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  late Future<Map<String, dynamic>?> _checkLoginFuture;

  @override
  void initState() {
    super.initState();
    _checkLoginFuture = AuthService.getLoginInfo();
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void _handleLogout() async {
    // 【新增】断开 WebSocket 连接
    WebSocketService().disconnect();

    await AuthService.clearLoginInfo();
    setState(() {
      _checkLoginFuture = AuthService.getLoginInfo();
    });
  }

  void _onLoginSuccess() {
    // 【新增】登录成功后，立即建立 WebSocket 连接
    // 我们需要 userId，所以从 AuthService 中再次获取
    AuthService.getLoginInfo().then((loginInfo) {
      if (loginInfo != null && loginInfo['userId'] != null) {
        WebSocketService().connect(loginInfo['userId']);
      }
    });

    setState(() {
      _checkLoginFuture = AuthService.getLoginInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '晗伴',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<Map<String, dynamic>?>(
        future: _checkLoginFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data != null) {
            final loginInfo = snapshot.data!;
            return MainScreen(
              onThemeModeChanged: _toggleTheme,
              onLogout: _handleLogout,
              userId: loginInfo['userId'],
            );
          }
          return WelcomePage(onLoginSuccess: _onLoginSuccess);
        },
      ),
    );
  }
}

// --- 【核心改造】App 主框架 ---
class MainScreen extends StatefulWidget {
  final VoidCallback onThemeModeChanged;
  final VoidCallback onLogout;
  final int userId;
  const MainScreen({
    super.key,
    required this.onThemeModeChanged,
    required this.onLogout,
    required this.userId,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// === 在 main.dart 中，用这个新版本替换旧的 _MainScreenState ===

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  // 1. 【新增】创建一个 ValueNotifier 作为“信箱”，初始值为0
  final ValueNotifier<int> _totalUnreadCount = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    // 2. 【新增】监听“信箱”的变化，一旦有新值，就调用 setState 刷新UI
    _totalUnreadCount.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    // 3. 【新增】页面销毁时，释放监听器
    _totalUnreadCount.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 【核心修复】不再使用 late final。我们将在 build 方法中构建 _pages 列表，
  // 或者直接在声明时构建，但这需要访问 widget，所以 build 方法是最佳位置。


  // 在 _MainScreenState 类中替换 build 方法

  @override
  Widget build(BuildContext context) {
    //【新增】先判断当前是不是深色模式
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // 1. 更新页面列表：首页 -> 聊天 -> 通讯录 -> 我
    final List<Widget> pages = <Widget>[
      HomePage(userId: widget.userId),
      ConversationsListPage(
        currentUserId: widget.userId,
        unreadCountNotifier: _totalUnreadCount,
      ),
      // 👇👇👇 新增：通讯录页面 👇👇👇
      ContactsPage(currentUserId: widget.userId),
      // 👆👆👆 新增结束 👆👆👆
      ProfilePage(onLogout: widget.onLogout, userId: widget.userId),
    ];

    String getTitle() {
      switch (_selectedIndex) {
        case 0: return '首页';
        case 1: return '';
        case 2: return '通讯录'; // 新标题
        case 3: return '我';
        default: return '晗伴';
      }
    }

    // 只有聊天页不需要 AppBar，其他都需要 (通讯录页其实有自己的AppBar，这里可以隐藏主AppBar，或者统一管理)
    // 简单做法：只要不是聊天页，就显示主 AppBar (通讯录如果不想要主AppBar，可以在ContactsPage里把Scaffold的appBar去掉，或者在这里控制)
    // 推荐做法：ContactsPage 用自己的 AppBar，所以这里 index 2 也不显示主 AppBar
    final showMainAppBar = _selectedIndex != 1 && _selectedIndex != 2;

    return Scaffold(
      // 如果页面自己有AppBar，这里就设为null，防止双重标题栏
      // 我们之前的HomePage和ProfilePage没有自带AppBar，所以这里显示
      // 现在 ContactsPage 自带了 AppBar，所以 _selectedIndex == 2 时也不显示
      appBar: (_selectedIndex == 0 || _selectedIndex == 3)
          ? AppBar(
        title: Text(getTitle()),
        actions: [
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: widget.onThemeModeChanged,
          ),
        ],
      )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 👈 关键：超过3个Tab必须设置这个，否则会变成白色背景且图标乱跑
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        // 👇👇👇 【核心修改在这里】 👇👇👇
        // 如果是深色模式，选中变成白色(高亮)；浅色模式则用主色调(蓝色)
        selectedItemColor: isDarkMode ? Colors.white : Theme.of(context).primaryColor,

        // 顺便确保未选中的颜色在深色模式下也能看清
        unselectedItemColor: isDarkMode ? Colors.grey[400] : Colors.grey,

        // 👆👆👆 修改结束 👆👆👆

        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: '首页'),

          // 聊天 Tab
          BottomNavigationBarItem(
            label: '聊天',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble_outline),
                if (_totalUnreadCount.value > 0)
                  Positioned(
                    top: -2, right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                    ),
                  ),
              ],
            ),
            activeIcon: const Icon(Icons.chat_bubble),
          ),

          // 👇👇👇 新增：通讯录 Tab 👇👇👇
          const BottomNavigationBarItem(
              icon: Icon(Icons.contacts_outlined),
              activeIcon: Icon(Icons.contacts),
              label: '通讯录'
          ),
          // 👆👆👆 新增结束 👆👆👆

          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: '我'),
        ],
      ),
    );
  }
  }

// === 替换原本的 HomePage ===

class HomePage extends StatefulWidget {
  final int userId;
  const HomePage({super.key, required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _nickname = "朋友";
  String _greeting = "你好";
  // 👇 1. 新增变量：默认显示加载中，或者一句通用的兜底文案
  String _dailyQuote = "正在获取今日份的治愈...";
  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _fetchUserInfo();
    _fetchDailyQuote(); // 👇 2. 调用获取寄语
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) {
      _greeting = "夜深了";
    } else if (hour < 12) {
      _greeting = "早上好";
    } else if (hour < 18) {
      _greeting = "下午好";
    } else {
      _greeting = "晚上好";
    }
  }

  Future<void> _fetchUserInfo() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/profile/${widget.userId}'));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        setState(() {
          _nickname = data['nickname'] ?? "朋友";
        });
      }
    } catch (e) {
      // ignore
    }
  }

  // 👇 3. 新增获取寄语的方法
  Future<void> _fetchDailyQuote() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/daily-quote'));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _dailyQuote = data['data'];
        });
      }
    } catch (e) {
      // 如果报错，保持默认文案或者设置一个静态文案
      if (mounted) setState(() => _dailyQuote = "生活明朗，万物可爱。");
    }
  }


  @override
  Widget build(BuildContext context) {
    // 判断当前主题是否是深色模式
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      // 首页不需要标准的 AppBar，用 SafeArea 自己写一个头部
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: // 👇👇👇 优化后的头部设计 👇👇👇
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 问候语：变小，颜色变淡，作为一种温柔的提醒
              Text(
                "$_greeting,",
                style: TextStyle(
                  fontSize: 16, // 从 28 降到 16，精致很多
                  fontWeight: FontWeight.normal, // 去掉粗体，更轻盈
                  color: subTextColor, // 使用副文本颜色（灰色），不抢眼
                ),
              ),
              const SizedBox(height: 4), // 间距稍微拉近一点

              // 2. 名字：作为视觉重心，保留辨识度，但不用巨型字体
              Text(
                _nickname,
                style: TextStyle(
                  fontSize: 24, // 从 28 降到 24，刚好够大
                  fontWeight: FontWeight.bold, // 加粗，强调身份
                  // 颜色逻辑保持不变
                  color: isDark ? Colors.blue[200] : Theme.of(context).primaryColor,
                  letterSpacing: 1.0, // 加一点字间距，更有呼吸感
                ),
              ),
              // 👆👆👆 修改结束 👆👆👆
              const SizedBox(height: 8), // 缩小名字和副标题的间距
              Text(
                "今天想聊点什么，还是看看回忆？",
                style: TextStyle(fontSize: 14, color: subTextColor?.withOpacity(0.7)), // 稍微再小一点
              ),

              const SizedBox(height: 30), // 这里的间距可以适当调整

              // 2. AI 助手大卡片 (暖色渐变)
              _buildHeroCard(
                context,
                title: "AI 助手",
                subtitle: "你的全天候智能伙伴",
                icon: Icons.chat_bubble_outline,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)], // 暖粉橙色
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatSessionsListPage(userId: widget.userId)),
                  );
                },
              ),

              const SizedBox(height: 20),

              // 3. 功能区 Grid (照片墙 + 心情)
              Row(
                children: [
                  // 左边：照片墙 (冷色渐变)
                  Expanded(
                    flex: 3, // 占 3 份宽
                    child: _buildGridCard(
                      context,
                      title: "照片墙",
                      subtitle: "定格美好瞬间",
                      icon: Icons.photo_library_outlined,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA18CD1), Color(0xFFFBC2EB)], // 紫色系
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      height: 190,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PhotoGalleryPage(
                              userId: widget.userId,
                              viewerId: widget.userId,
                              isMe: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  // 右边：心情日记 (或者其他功能)
                  Expanded(
                    flex: 2, // 占 2 份宽
                    child: _buildGridCard(
                      context,
                      title: "心情",
                      subtitle: "记录当下",
                      icon: Icons.mood,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF84FAB0), Color(0xFF8FD3F4)], // 青蓝色系
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      height: 190,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MoodTrackerPage(userId: widget.userId),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 4. 每日寄语卡片 (使用 _dailyQuote 变量)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text("每日寄语", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    ]),
                    const SizedBox(height: 10),
                    // 👇👇👇 这里使用动态获取的文字 👇👇👇
                    Text(
                      _dailyQuote,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: subTextColor,
                        fontSize: 15,
                        height: 1.5, // 增加一点行高，更好看
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建通用的英雄大卡片
  Widget _buildHeroCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 170,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 背景装饰图标
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(icon, size: 150, color: Colors.white.withOpacity(0.2)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建 Grid 小卡片
  Widget _buildGridCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required double height,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Icon(icon, size: 100, color: Colors.white.withOpacity(0.2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(icon, color: Colors.white, size: 28),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final VoidCallback onLogout;
  final int userId;
  const ProfilePage({super.key, required this.onLogout, required this.userId});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserProfileData? _profileData;
  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // 4. 【已升级】_fetchProfile 函数
  Future<void> _fetchProfile() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/profile/${widget.userId}'));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        setState(() {
          _profileData = UserProfileData(
            id: data['id'],
            username: data['username'], // 3. 【新增】在这里接收后端传来的 username
            nickname: data['nickname'] ?? '未设置昵称',
            introduction: data['introduction'] ?? '这家伙很酷，什么也没留下...',
            birthDate: data['birth_date'],
            avatarUrl: data['avatar_url'] ?? '',
            hasPassword: data['password_hash'] != null && data['password_hash'].isNotEmpty,
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加载个人信息失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络错误，无法加载信息')));
    }
  }

  // 在 main.dart 的 _ProfilePageState 内部

  Future<void> _navigateToEditProfile() async {
    if (_profileData == null) return;

    final result = await Navigator.push<UserProfileData>(
      context,
      MaterialPageRoute(
        builder: (context) => edit_page.EditProfilePage(
          initialData: _profileData!,
          userId: widget.userId,
          // 4. 【新增】把当前的密码状态传递给编辑页
          hasPassword: _profileData!.hasPassword,
        ),
      ),
    );

    if (result != null) {
      // 这里就不需要再手动拼接了，因为返回的 result 已经是一个完整的 UserProfileData 对象
      setState(() {
        _profileData = result;
      });
    }
  }

  Future<void> _navigateToSetPassword() async {
    if (_profileData == null) return;

    final bool? passwordHasBeenSet = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SetPasswordPage(
          userId: widget.userId,
          currentUsername: _profileData!.username, // 【修改】把用户名传过去
          hasPassword: _profileData!.hasPassword, // 【修改】把密码状态传过去
        ),
      ),
    );

    if (passwordHasBeenSet == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在刷新用户信息...')));
      _fetchProfile();
    }
  }

  // 显示退出确认弹窗
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("退出登录"),
          content: const Text("确定要退出当前账号吗？"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // 关闭弹窗
              child: const Text("取消", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 先关闭弹窗
                widget.onLogout();      // 再执行原本的退出逻辑
              },
              child: const Text("退出", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_profileData == null) {
      return const Center(child: CircularProgressIndicator());
    } else {
      return Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 👇👇👇 修改这里：包裹 GestureDetector 并添加 Hero 动画 👇👇👇
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AvatarViewerPage(
                          imageUrl: _profileData!.avatarUrl,
                          heroTag: 'my_avatar', // 唯一的动画标签
                        ),
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'my_avatar', // 必须和上面一致
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(_profileData!.avatarUrl),
                    ),
                  ),
                ),
                // 👆👆👆 修改结束 👆👆👆
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_profileData!.nickname, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_profileData!.introduction, style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Theme.of(context).hintColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 40, indent: 16, endIndent: 16),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('编辑资料'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _navigateToEditProfile,
                ),
                ListTile(
                  leading: const Icon(Icons.mood, color: Colors.amber),
                  title: const Text('每日心情'),
                  subtitle: const Text('记录此刻感受，获取 AI 暖心鼓励'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // 关键点：把当前用户的 ID 传过去
                        builder: (context) => MoodTrackerPage(userId: widget.userId),
                      ),
                    );
                  },
                ),

                // 7. 【新增】智能显示“设置密码”入口
                if (!_profileData!.hasPassword)
                  ListTile(
                    leading: Icon(Icons.password, color: Theme.of(context).colorScheme.primary),
                    title: Text('设置登录密码', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                    subtitle: const Text('为您的账号增加一道安全防线'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _navigateToSetPassword,
                  ),

                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('设置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsPage(userId: widget.userId)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('关于我们'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AboutUsPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('退出登录'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showLogoutDialog, // 👈 现在改成调用弹窗函数
                ),
              ],
            ),
          ),
        ],
      );
    }
  }
}