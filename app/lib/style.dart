// 색·공통 위젯 (남색 하나 + 회색)
import 'package:flutter/material.dart';

const navy = Color(0xFF1E3A5F);
const gray = Color(0xFF6C757D);
const lightGray = Color(0xFFADB5BD);

/// 공백률 표시: 50% 이상은 남색 강조
class RateText extends StatelessWidget {
  final int rate;
  const RateText(this.rate, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        '공백률 $rate%',
        style: TextStyle(fontWeight: FontWeight.bold, color: rate >= 50 ? navy : gray),
      );
}
