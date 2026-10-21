// 분석: 대여소 위치별 추천 조치 분포, 자치구 선택 시 해당 범위 확대와 조치 구성 비율
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'diagnosis.dart';
import 'style.dart';

/// 그리는 순서: 대여소 수가 많은 조치를 아래, 적은 조치를 위
const _drawOrder = [Act.keep, Act.more, Act.less, Act.expand, Act.close];

class AnalysisPage extends StatefulWidget {
  final DiagnosisData diag;
  final ValueChanged<Diagnosis> onOpen;
  const AnalysisPage({super.key, required this.diag, required this.onOpen});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  String? gu;

  @override
  Widget build(BuildContext context) {
    final diag = widget.diag;
    final inRange = diag.byId.values.where((d) => gu == null || d.gu == gu).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('분석', '대여소 위치별 추천 조치 분포 · 자치구 선택 시 범위 확대'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(children: [
          Picker<String?>('자치구', gu, [(null, '서울 전체'), for (final g in diag.gus) (g, g)], (v) => setState(() => gu = v)),
          const SizedBox(width: 16),
          const Text('지도 점 선택 시 대여소 상세 화면', style: TextStyle(fontSize: 12.5, color: gray)),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 3, child: _MapPanel(diag: diag, gu: gu, onOpen: widget.onOpen)),
            const SizedBox(width: 16),
            SizedBox(width: 340, child: _MixPanel(title: gu ?? '서울 전체', list: inRange)),
          ]),
        ),
      ),
    ]);
  }
}

class _MapPanel extends StatelessWidget {
  final DiagnosisData diag;
  final String? gu;
  final ValueChanged<Diagnosis> onOpen;
  const _MapPanel({required this.diag, required this.gu, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final all = diag.byId.values.where((d) => d.lat > 37 && d.lon > 126).toList();
    final focus = gu == null ? all : all.where((d) => d.gu == gu).toList();
    double lo(Iterable<double> v) => v.reduce((a, b) => a < b ? a : b);
    double hi(Iterable<double> v) => v.reduce((a, b) => a > b ? a : b);
    var minX = lo(focus.map((d) => d.lon)), maxX = hi(focus.map((d) => d.lon));
    var minY = lo(focus.map((d) => d.lat)), maxY = hi(focus.map((d) => d.lat));
    final padX = ((maxX - minX) * 0.08).clamp(0.004, 1.0), padY = ((maxY - minY) * 0.08).clamp(0.004, 1.0);
    minX -= padX;
    maxX += padX;
    minY -= padY;
    maxY += padY;

    final ordered = <Diagnosis>[for (final a in _drawOrder) ...all.where((d) => d.act == a)];
    // 선택 자치구 대여소를 맨 위에
    if (gu != null) ordered.sort((a, b) => (a.gu == gu ? 1 : 0).compareTo(b.gu == gu ? 1 : 0));
    final spots = <ScatterSpot>[];
    final byspot = Map<ScatterSpot, Diagnosis>.identity();
    for (final d in ordered) {
      final on = gu == null || d.gu == gu;
      final s = ScatterSpot(d.lon, d.lat,
          dotPainter: FlDotCirclePainter(
            radius: gu == null ? 2.6 : (on ? 5 : 2.6),
            color: on ? d.act.color : d.act.color.withValues(alpha: 0.12),
            strokeWidth: 0,
          ));
      spots.add(s);
      byspot[s] = d;
    }

    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle('대여소 위치와 추천 조치', note: gu == null ? '서울 전체 범위' : '$gu 범위 확대'),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            // 위도 37.5도 기준 경도 1도 거리 비율 0.79: 지도 비율 유지
            final ratio = (maxX - minX) * 0.79 / (maxY - minY);
            var w = c.maxWidth, h = w / ratio;
            if (h > c.maxHeight) {
              h = c.maxHeight;
              w = h * ratio;
            }
            return Center(
              child: SizedBox(
                width: w,
                height: h,
                child: ScatterChart(ScatterChartData(
                  scatterSpots: spots,
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
                  borderData: FlBorderData(show: true, border: Border.all(color: line)),
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  scatterTouchData: ScatterTouchData(
                    touchSpotThreshold: 4,
                    touchCallback: (e, r) {
                      final t = r?.touchedSpot;
                      if (e is FlTapUpEvent && t != null) {
                        final d = byspot[t.spot] ?? ordered[t.spotIndex];
                        onOpen(d);
                      }
                    },
                    touchTooltipData: ScatterTouchTooltipData(
                      getTooltipColor: (_) => navy,
                      getTooltipItems: (s) {
                        final d = byspot[s];
                        if (d == null) return null;
                        return ScatterTooltipItem('${d.name}\n${d.act.label}',
                            textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600));
                      },
                    ),
                  ),
                )),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 16, runSpacing: 6, children: [
          for (final a in _drawOrder)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: a.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(a.label, style: const TextStyle(fontSize: 12, color: ink)),
            ]),
        ]),
      ]),
    );
  }
}

/// 선택 범위 내 추천 조치 구성
class _MixPanel extends StatelessWidget {
  final String title;
  final List<Diagnosis> list;
  const _MixPanel({required this.title, required this.list});

  @override
  Widget build(BuildContext context) {
    final total = list.length;
    final counts = {for (final a in Act.values) a: list.where((d) => d.act == a).length};
    final shortage = counts[Act.expand]! + counts[Act.more]!;
    final surplus = counts[Act.less]!;
    String pct(int n) => total == 0 ? '-' : '${(n / total * 100).toStringAsFixed(1)}%';
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle('$title 조치 구성'),
        Text('대여소 ${comma(total)}곳', style: const TextStyle(fontSize: 13, color: gray)),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 16,
            child: Row(children: [
              for (final a in Act.values)
                if (counts[a]! > 0) Expanded(flex: counts[a]!, child: Container(color: a.color)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        for (final a in Act.values)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: line))),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: a.color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(a.label, style: const TextStyle(fontSize: 13.5, color: ink))),
              SizedBox(
                width: 56,
                child: Text('${comma(counts[a]!)}곳',
                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ink)),
              ),
              SizedBox(
                width: 64,
                child: Text(pct(counts[a]!), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: gray)),
              ),
            ]),
          ),
        const SizedBox(height: 18),
        // 방향이 반대인 조치는 합치지 않음: 자전거 부족과 잉여를 나눠 구 내 재배치 여지 표시
        _SideBox('자전거 부족', shortage, pct(shortage), '증설 검토 + 배치 확대', Act.more.color),
        const SizedBox(height: 10),
        _SideBox('자전거 잉여', surplus, pct(surplus), '배치 축소', Act.less.color),
      ]),
    );
  }
}

class _SideBox extends StatelessWidget {
  final String label;
  final int count;
  final String pct;
  final String note;
  final Color color;
  const _SideBox(this.label, this.count, this.pct, this.note, this.color);

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: panel,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  // 이름·건수·비율 한 줄, 설명은 아래 한 줄
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                      Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ink)),
                      const Spacer(),
                      Text('${comma(count)}곳', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 52,
                          child: Text(pct, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: gray))),
                    ]),
                    const SizedBox(height: 2),
                    Text(note, maxLines: 1, style: const TextStyle(fontSize: 11.5, color: gray)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
}
