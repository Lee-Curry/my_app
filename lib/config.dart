import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  // 你的局域网 IP (真机调试必须用这个)
  static const String _lanIp = "192.168.156.18";

  static String get baseUrl {
    // 1. 如果是 iOS 模拟器，可以使用 localhost
    if (!kIsWeb && Platform.isIOS && !kReleaseMode) {
      // 注意：虽然 iOS 模拟器支持 localhost，但为了统一，建议还是用局域网 IP
      // 或者你可以写 return "http://127.0.0.1:3000";
      return "http://$_lanIp:3000";
    }
    // 2. 如果是 Android 模拟器，必须用 10.0.2.2
    else if (!kIsWeb && Platform.isAndroid && !kReleaseMode) {
      // 如果是模拟器想访问本机，可以用这个特殊 IP
      // return "http://10.0.2.2:3000";
      return "http://$_lanIp:3000"; // 统一用局域网 IP 最稳
    }
    // 3. 真机调试 / 默认情况
    return "http://$_lanIp:3000";
  }
}