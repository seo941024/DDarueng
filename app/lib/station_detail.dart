// 대여소 상세: 추천 조치와 근거, 지표 3개와 기준선, 시간대별 대여 불가 비율, 연결 대여소, 참고 지표
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'data.dart';
import 'diagnosis.dart';
import 'style.dart';

class StationDetail extends StatefulWidget {
  final Diagnosis d;
  final DiagnosisData diag;
  final AppData data;
  final String backLabel;
  final VoidCallback onBack;
  final ValueChanged<Diagnosis> onOpen;
  const StationDetail(
      {super.key,
      required this.d,
      required this.diag,
      required this.data,
      required this.backLabel,
      required this.onBack,
      required this.onOpen});

  @override
  State<StationDetail> createState() => _StationDetailState();
}

class _StationDetailState extends State<StationDetail> {
  DayType day = DayType.weekday;

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final diag = widget.diag;
    final act = d.act;
    final linked = diag.linked(d);
    final hasLink = act == Act.expand || act == Act.more || act == Act.less;

    return ListView(padding: const EdgeInsets.fromLTRB(32, 18, 32, 32), children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(widget.backLabel, style: const TextStyle(fontSize: 13.5)),
          style: TextButton.styleFrom(foregroundColor: navy, padding: const EdgeInsets.symmetric(horizontal: 8)),
        ),
      ),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(
          child: Text(d.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: navy)),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text('${d.gu} · 대여소 번호 ${d.id} · 거치대 ${d.racks}개',
              overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, color: gray)),
        ),
      ]),
      const SizedBox(height: 16),
      // 추천 조치와 근거
      Panel(
        accent: act.color,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 240,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('추천 조치', style: TextStyle(fontSize: 12.5, color: gray)),
              const SizedBox(height: 8),
              ActionBadge(act.label, act.color, size: 16),
              const SizedBox(height: 10),
              const Text('참고용 추천 · 최종 결정: 운영 담당자', style: TextStyle(fontSize: 11.5, color: gray)),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('추천 근거', style: TextStyle(fontSize: 12.5, color: gray)),
              const SizedBox(height: 8),
              for (final r in diag.reasons(d))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $r', style: const TextStyle(fontSize: 14, color: ink)),
                ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      // 지표 3개: 같은 크기, 기준선 위치 표시
      Row(children: [
        Expanded(
          child: _MetricCard(
            label: '하루 평균 대여',
            value: d.rent,
            unit: '건',
            base: diag.rentMedian,
            baseLabel: '중앙값',
            scale: [diag.rentMedian * 3, d.rent * 1.1].reduce((a, b) => a > b ? a : b),
            color: act.color,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _MetricCard(
            label: '대여 불가 비율',
            value: d.empty,
            unit: '%',
            base: diag.emptyQ3,
            baseLabel: '상위 25% 기준',
            scale: 100,
            color: act.color,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _MetricCard(
            label: '평균 주차 대수',
            value: d.bikes,
            unit: '대',
            base: diag.bikesMedian,
            baseLabel: '중앙값',
            scale: [diag.bikesMedian * 3, (d.bikes ?? 0) * 1.1].reduce((a, b) => a > b ? a : b),
            color: act.color,
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: _HourlyPanel(d: d, data: widget.data, base: diag.emptyQ3, day: day, onDay: (v) => setState(() => day = v))),
        if (hasLink) ...[
          const SizedBox(width: 14),
          Expanded(flex: 2, child: _LinkedPanel(d: d, linked: linked, onOpen: widget.onOpen)),
        ],
      ]),
      const SizedBox(height: 16),
      _RefPanel(d: d),
    ]);
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final double? value;
  final String unit;
  final double base;
  final String baseLabel;
  final double scale;
  final Color color;
  const _MetricCard(
      {required this.label,
      required this.value,
      required this.unit,
      required this.base,
      required this.baseLabel,
      required this.scale,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final v = value;
    final over = v != null && v >= base;
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: SizedBox(
        height: 128,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: gray)),
          const SizedBox(height: 6),
          Text(v == null ? '기록 부재' : '${n1(v)}$unit',
              maxLines: 1, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: ink)),
          const Spacer(),
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            final x = (base / scale).clamp(0.0, 1.0) * w;
            final fill = v == null ? 0.0 : (v / scale).clamp(0.0, 1.0) * w;
            return SizedBox(
              height: 22,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(left: 0, right: 0, top: 6, child: Container(height: 10, decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(5)))),
                Positioned(left: 0, top: 6, child: Container(width: fill, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)))),
                Positioned(left: x - 1, top: 0, child: Container(width: 2, height: 22, color: navy)),
              ]),
            );
          }),
          const SizedBox(height: 6),
          Text(
            v == null ? '$baseLabel ${n1(base)}$unit' : '$baseLabel ${n1(base)}$unit ${over ? '이상' : '미만'}',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: over ? navy : gray),
          ),
        ]),
      ),
    );
  }
}

class _HourlyPanel extends StatelessWidget {
  final Diagnosis d;
  final AppData data;
  final double base;
  final DayType day;
  final ValueChanged<DayType> onDay;
  const _HourlyPanel({required this.d, required this.data, required this.base, required this.day, required this.onDay});

  @override
  Widget build(BuildContext context) {
    final station = data.stations.where((s) => s.id == d.id).firstOrNull;
    final rates = station == null ? null : data.rates(d.id, day);
    const small = TextStyle(fontSize: 11, color: gray);
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: SectionTitle('시간대별 대여 불가 비율',
                note: station == null ? null : '${day.label} 기록 ${station.daysOf(day)}일 기준'),
          ),
          SegmentedButton<DayType>(
            segments: [for (final t in DayType.values) ButtonSegment(value: t, label: Text(t.label))],
            selected: {day},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onDay(s.first),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 230,
          child: rates == null
              ? const Center(child: Text('시간대별 기록 부재', style: TextStyle(color: gray)))
              : BarChart(BarChartData(
                  minY: 0,
                  maxY: 100,
                  barGroups: [
                    for (var h = 0; h < 24; h++)
                      BarChartGroupData(x: h, barRods: [
                        BarChartRodData(
                          toY: rates[h].toDouble(),
                          width: 14,
                          color: rates[h] >= base ? d.act.color : barIdle,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ]),
                  ],
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y: base,
                      color: navy,
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                    ),
                  ]),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => navy,
                      getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                          '${g.x}시 ${rod.toY.toInt()}%', const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 25,
                        getTitlesWidget: (v, meta) => Text('${v.toInt()}%', style: small),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, meta) =>
                            v.toInt() % 3 == 0 ? Text('${v.toInt()}시', style: small) : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  gridData: const FlGridData(drawVerticalLine: false, horizontalInterval: 25),
                  borderData: FlBorderData(show: false),
                )),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Container(width: 10, height: 10, color: d.act.color),
          const SizedBox(width: 6),
          const Text('추천 기준 이상 시간대', style: small),
          const SizedBox(width: 14),
          Container(width: 10, height: 10, color: barIdle),
          const SizedBox(width: 6),
          const Text('추천 기준 미만 시간대', style: small),
          const SizedBox(width: 14),
          for (var i = 0; i < 3; i++) Container(width: 4, height: 2, margin: const EdgeInsets.only(right: 2), color: navy),
          const SizedBox(width: 4),
          Text('추천 기준 ${n1(base)}%', style: small),
        ]),
      ]),
    );
  }
}

class _LinkedPanel extends StatelessWidget {
  final Diagnosis d;
  final List<Diagnosis> linked;
  final ValueChanged<Diagnosis> onOpen;
  const _LinkedPanel({required this.d, required this.linked, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final toLess = d.act != Act.less;
    final title = toLess ? '반경 1km 내 자전거 배치 축소 추천 대여소' : '반경 1km 내 증설 검토·배치 확대 추천 대여소';
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(title, note: '가까운 순'),
        if (linked.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('반경 1km 내 해당 대여소 부재', style: TextStyle(fontSize: 13.5, color: gray)),
          )
        else
          for (final o in linked.take(6))
            InkWell(
              onTap: () => onOpen(o),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: line))),
                child: Row(children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: o.act.color, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: cellText(o.name, bold: true)),
                  Text('${comma(meters(d, o))}m', style: const TextStyle(fontSize: 12.5, color: gray)),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 120,
                    child: Text(
                      toLess ? '평균 주차 ${n1(o.bikes)}대' : '대여 불가 ${n1(o.empty)}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12.5, color: ink),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: lightGray),
                ]),
              ),
            ),
      ]),
    );
  }
}

class _RefPanel extends StatelessWidget {
  final Diagnosis d;
  const _RefPanel({required this.d});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('하루 평균 반납', '${n1(d.ret)}건', '운영일 기준 일평균 반납 건수'),
      ('추정 미충족 대여', '${comma(d.lost)}건', '대여 불가 시간대 평균 대여 기준 추정, 분석 기간 합계'),
      ('평일 07~09시 순유출', '${d.am >= 0 ? '+' : ''}${n1(d.am)}대', '대여 − 반납 일평균, 양수: 자전거 유출'),
      ('거치대 1개당 하루 평균 대여', d.turnover == null ? '-' : '${n1(d.turnover)}건', '하루 평균 대여 ÷ 거치대 수'),
    ];
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('참고 지표', note: '추천 기준 외 지표'),
        Row(children: [
          for (final (i, (label, value, note)) in items.indexed) ...[
            if (i > 0) Container(width: 1, height: 64, color: line, margin: const EdgeInsets.symmetric(horizontal: 18)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: gray)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ink)),
                const SizedBox(height: 4),
                Text(note, style: const TextStyle(fontSize: 11.5, color: gray)),
              ]),
            ),
          ],
        ]),
      ]),
    );
  }
}
