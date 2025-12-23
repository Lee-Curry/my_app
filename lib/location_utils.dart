// lib/location_utils.dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationUtils {
  /// 获取当前位置的城市描述 (例如: "北京市, 海淀区")
  static Future<String?> getCurrentLocationAddress() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. 检查手机定位服务是否开启
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('手机定位服务未开启');
    }

    // 2. 检查权限
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('定位权限被拒绝');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('定位权限被永久拒绝，请在设置中开启');
    }

    // 3. 获取经纬度 (高精度)
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // 4. 将经纬度转为文字地址 (逆地理编码)
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        localeIdentifier: "zh_CN", // 强制中文
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // 拼接地址：省/市 + 区/县
        // administrativeArea: 省/直辖市 (如 Beijing)
        // locality: 城市 (可能为空)
        // subLocality: 区 (如 Haidian District)

        String result = "";
        if (place.administrativeArea != null) {
          result += place.administrativeArea!;
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          if (result.isNotEmpty) result += " ";
          result += place.subLocality!;
        }

        return result.isNotEmpty ? result : "未知位置";
      }
    } catch (e) {
      print("地址解析失败: $e");
      throw Exception('无法解析地址名称');
    }
    return null;
  }
}