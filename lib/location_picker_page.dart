import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final MapController _mapController = MapController();

  // 默认位置 (北京天安门)，防止定位失败没地儿去
  LatLng _center = const LatLng(39.9055, 116.3976);
  String _address = "正在获取位置...";
  bool _isLocating = true; // 是否正在初始定位
  bool _isResolvingAddress = false; // 是否正在解析地址

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // 1. 获取当前 GPS 位置并移动地图
  Future<void> _getCurrentLocation() async {
    try {
      // 检查权限 (简化版，假设上一页已经检查过，或者由 geolocator 自动申请)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      if (mounted) {
        setState(() {
          _center = LatLng(position.latitude, position.longitude);
          _isLocating = false;
        });
        // 移动地图视角
        _mapController.move(_center, 15.0);
        // 解析当前坐标地址
        _resolveAddress(_center.latitude, _center.longitude);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _address = "定位失败，请手动拖动地图";
        });
      }
    }
  }

  // 2. 将经纬度转为文字地址
  Future<void> _resolveAddress(double lat, double lng) async {
    setState(() => _isResolvingAddress = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng, localeIdentifier: "zh_CN");
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // 拼接地址逻辑
        String result = "";
        if (place.administrativeArea != null) result += place.administrativeArea!;
        if (place.locality != null && place.locality != place.administrativeArea) {
          result += place.locality!;
        }
        if (place.subLocality != null) result += place.subLocality!;
        if (place.thoroughfare != null) result += " ${place.thoroughfare!}"; // 街道

        setState(() => _address = result);
      }
    } catch (e) {
      setState(() => _address = "无法解析该位置");
    } finally {
      setState(() => _isResolvingAddress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("选择位置"),
        actions: [
          TextButton(
            onPressed: _isResolvingAddress
                ? null
                : () {
              // 点击确定，返回地址给上一页
              Navigator.pop(context, _address);
            },
            child: const Text("确定", style: TextStyle(fontSize: 16)),
          )
        ],
      ),
      body: Stack(
        children: [
          // 1. 地图层
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center, // 初始中心
              initialZoom: 15.0,
              // 当地图停止移动时，获取中心点坐标
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && position.center != null) {
                  // 这里只记录坐标，不频繁解析，避免卡顿
                  _center = position.center!;
                }
              },
              // 只有当用户松手停止拖动时，才去解析地址
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _resolveAddress(_center.latitude, _center.longitude);
                }
              },
            ),
            children: [
              // 👇👇👇 方案 A: 高德地图 (彩色版) 👇👇👇
              TileLayer(
                // style=7 是矢量彩色版，style=6 是卫星图
                urlTemplate: 'http://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=7&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.example.app',
              ),
            ],
          ),

          // 2. 屏幕中心的大头针 (永远固定在中间)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 30), // 让针尖对准中心
              child: Icon(Icons.location_on, size: 40, color: Colors.red),
            ),
          ),

          // 3. 底部信息面板
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.all(20),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("当前选中位置", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.my_location, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _isResolvingAddress
                              ? const Text("正在解析...", style: TextStyle(color: Colors.grey))
                              : Text(_address, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 一个按钮：回到当前定位
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: _isLocating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.gps_fixed),
                        label: const Text("重新定位到我的位置"),
                        onPressed: _getCurrentLocation,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 辅助方法：深色模式地图滤镜
  Widget _darkModeTileBuilder(BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -1,  0,  0, 0, 255,
        0, -1,  0, 0, 255,
        0,  0, -1, 0, 255,
        0,  0,  0, 1,   0,
      ]),
      child: tileWidget,
    );
  }
}