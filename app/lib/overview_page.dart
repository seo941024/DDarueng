// 현황: 조치별 추천 대여소 수, 자치구별 분포
import 'package:flutter/material.dart';

import 'diagnosis.dart';
import 'style.dart';

class OverviewPage extends StatelessWidget {
  final DiagnosisData diag;
  final ValueChanged<Act> onAct;
  const OverviewPage({super.key, required this.diag, required this.onAct});

  @override
  Widget build(BuildContext context) {
    final counts = diag.actCounts();
    final total = diag.byId.length;
    const acts = [Act.expand, Act.more, Act.less, Act.close];
    final rows = [
      for (final g in diag.gus) (g, diag.actCounts(gu: g)),
    ]..sort((a, b) {
        int sum(Map<Act, int> m) => acts.fold(0, (s, x) => s + m[x]!);
        return sum(b.$2).compareTo(sum(a.$2));
      });
    final maxSum = rows.map((r) => acts.fold(0, (s, x) => s + r.$2[x]!)).fold(1, (a, b) => a > b ? a : b);
    const flex = [14, 12, 12, 12, 14, 8, 26];

    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      PageHeader('현황', '전체 대여소 ${comma(total)}곳 · 추천 조치별 대여소 수, 자치구별 분포'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final a in Act.values) ...[
              Expanded(child: _ActCard(a, counts[a]!, diag.criteria(a), () => onAct(a))),
              if (a != Act.keep) const SizedBox(width: 14),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Panel(
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SectionTitle('자치구별 추천 대여소 수', note: '현 상태 유지 제외 · 합계 많은 순'),
            ),
            TableRowCells([
              headText('자치구'),
              for (final a in acts) headText(a.label, align: TextAlign.right, lines: 2),
              headText('합계', align: TextAlign.right),
              const SizedBox(),
            ], flex, head: true),
            for (final (g, m) in rows)
              TableRowCells([
                cellText(g, bold: true),
                for (final a in acts) cellText(comma(m[a]!), align: TextAlign.right, color: a.color),
                cellText(comma(acts.fold(0, (s, x) => s + m[x]!)), bold: true, align: TextAlign.right),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: _StackBar([for (final a in acts) (m[a]!, a.color)], maxSum),
                ),
              ], flex),
          ]),
        ),
      ),
    ]);
  }
}

class _ActCard extends StatelessWidget {
  final Act act;
  final int count;
  final String criteria;
  final VoidCallback onTap;
  const _ActCard(this.act, this.count, this.criteria, this.onTap);

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(height: 6, color: act.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(act.label,
                          maxLines: 1, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: ink)),
                    ),
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                      Text(comma(count), style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: act.color)),
                      const SizedBox(width: 4),
                      const Text('곳', style: TextStyle(fontSize: 15, color: ink)),
                    ]),
                    const SizedBox(height: 6),
                    Text(criteria, style: const TextStyle(fontSize: 12, height: 1.45, color: gray)),
                    const Spacer(),
                    const SizedBox(height: 10),
                    Text(act == Act.keep ? '대여소 조회 →' : '추천 목록 →',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: act.color == const Color(0xFF111111) ? ink : act.color)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
}

/// 자치구별 조치 구성 막대
class _StackBar extends StatelessWidget {
  final List<(int, Color)> parts;
  final int max;
  const _StackBar(this.parts, this.max);

  @override
  Widget build(BuildContext context) {
    final sum = parts.fold(0, (s, p) => s + p.$1);
    return LayoutBuilder(
      builder: (context, c) => Row(children: [
        SizedBox(
          width: c.maxWidth * sum / max,
          height: 12,
          child: Row(children: [
            for (final (n, color) in parts)
              if (n > 0) Expanded(flex: n, child: Container(color: color)),
          ]),
        ),
      ]),
    );
  }
}
