// 대여소 상세: 24시간 공백률 그래프 + 500m 안 대체 대여소
import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'data.dart';
import 'style.dart';

class DetailPage extends StatefulWidget {
  final AppData data;
  final Station station;
  const DetailPage({super.key, required this.data, required this.station});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  DayType _day = DayType.of(DateTime.now());
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 화면을 켜 둔 동안 시간대가 바뀌면 현재 시각 막대·대체 대여소 다시 계산
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.station;
    final hour = DateTime.now().hour;
    final rates = widget.data.rates(s.id, _day);
    final nearby = widget.data.nearby(s, _day, hour);

    return Scaffold(
      appBar: AppBar(title: Text(s.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${s.gu} · 거치대 ${s.racks}개', style: const TextStyle(color: gray)),
          const SizedBox(height: 12),
          SegmentedButton<DayType>(
            segments: [for (final d in DayType.values) ButtonSegment(value: d, label: Text(d.label))],
            selected: {_day},
            onSelectionChanged: (v) => setState(() => _day = v.first),
          ),
          const SizedBox(height: 20),
          Text(
            '${_day.label} $hour시 공백률 ${rates[hour]}%',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navy),
          ),
          const Text('2025년 같은 요일 구분·시간대 기록 중 자전거 0대 비율',
              style: TextStyle(fontSize: 12, color: gray)),
          if (s.daysOf(_day) < AppData.minDays)
            Text('${_day.label} 기록 ${s.daysOf(_day)}일: ${AppData.minDays}일 미만, 참고용 수치',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: navy)),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: HourChart(rates: rates, highlight: hour)),
          const SizedBox(height: 24),
          const Text('500m 안 대체 대여소',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navy)),
          Text('$hour시 공백률 낮은 순', style: const TextStyle(fontSize: 12, color: gray)),
          if (nearby.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('500m 안 대여소 없음')),
          for (final n in nearby.take(10))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(n.station.name),
              subtitle: Text('${n.meters.round()}m'),
              trailing: RateText(widget.data.rateAt(n.station.id, _day, hour)),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailPage(data: widget.data, station: n.station)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 0~23시 공백률 막대그래프, 현재 시각만 남색
class HourChart extends StatelessWidget {
  final List<int> rates;
  final int highlight;
  const HourChart({super.key, required this.rates, required this.highlight});

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(fontSize: 10, color: gray);
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 100,
        barGroups: [
          for (var h = 0; h < 24; h++)
            BarChartGroupData(x: h, barRods: [
              BarChartRodData(
                toY: rates[h].toDouble(),
                width: 8,
                color: h == highlight ? navy : lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ]),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 25,
              getTitlesWidget: (v, meta) => Text('${v.toInt()}%', style: small),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, meta) =>
                  v.toInt() % 3 == 0 ? Text('${v.toInt()}시', style: small) : const SizedBox.shrink(),
            ),
          ),
        ),
        gridData: const FlGridData(drawVerticalLine: false, horizontalInterval: 25),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
