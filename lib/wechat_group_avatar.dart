import 'package:flutter/material.dart';

class WeChatGroupAvatar extends StatelessWidget {
  final List<String> avatars;
  final double size;

  const WeChatGroupAvatar({
    super.key,
    required this.avatars,
    this.size = 50.0, // 默认大小
  });

  @override
  Widget build(BuildContext context) {
    // 背景色通常是浅灰色
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFEEEEEE),
      padding: const EdgeInsets.all(2), // 内边距
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    int count = avatars.length;
    // 微信逻辑：最多显示9个
    if (count > 9) count = 9;

    // 根据数量确定布局模式 (列数)
    int columnCount;
    if (count <= 4) {
      columnCount = 2; // 2x2
    } else {
      columnCount = 3; // 3x3
    }

    // 计算每个小头像的大小
    // (总宽 - (间隙 * (列数-1))) / 列数
    double gap = 2.0;
    double itemSize = (size - 4 - (gap * (columnCount - 1))) / columnCount;

    // 构建网格
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: gap,
      runSpacing: gap,
      children: List.generate(count, (index) {
        return SizedBox(
          width: itemSize,
          height: itemSize,
          child: Image.network(
            avatars[index],
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
          ),
        );
      }),
    );
  }
}