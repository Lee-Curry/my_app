// === auth_service.dart (完整代码) ===

import 'package:shared_preferences/shared_preferences.dart';

// 这是一个静态类，意味着我们不需要创建它的实例就可以直接使用它的方法
// 例如： await AuthService.saveLoginInfo(...);
class AuthService {
  // 定义存储时使用的“钥匙”(key)，确保它们不会写错
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  /// 保存用户的登录信息 (Token 和 UserID) 到手机本地存储
  static Future<void> saveLoginInfo(String token, int userId) async {
    // 1. 获取本地存储的实例
    final prefs = await SharedPreferences.getInstance();

    // 2. 使用对应的 key 来分别保存 token 和 userId
    await prefs.setString(_tokenKey, token);
    await prefs.setInt(_userIdKey, userId);

    print('登录信息已保存: UserID=$userId, Token=$token');
  }

  /// 从手机本地存储中读取登录信息
  static Future<Map<String, dynamic>?> getLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. 尝试使用 key 来读取 token 和 userId
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getInt(_userIdKey);

    print('正在读取本地登录信息: UserID=$userId, Token=$token');

    // 2. 如果 token 和 userId 都存在，就将它们打包成一个 Map 返回
    if (token != null && userId != null) {
      return {'token': token, 'userId': userId};
    }

    // 3. 如果有任何一个不存在，就返回 null，表示用户未登录
    return null;
  }

  /// 清除手机本地存储的所有登录信息 (用于退出登录)
  static Future<void> clearLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();

    // 分别移除 token 和 userId
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);

    print('本地登录信息已清除');
  }
}