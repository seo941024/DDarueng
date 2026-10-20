// 조치 추천: 조치별 탭, 추천 기준, 자치구·정렬 선택, 목록 행 선택 시 상세 화면
import 'package:flutter/material.dart';

import 'diagnosis.dart';
import 'station_list_page.dart';
import 'style.dart';

class RecommendPage extends StatefulWidget {
  final DiagnosisData diag;
  final Act act;
  final ValueChanged<Act> onAct;
  final ValueChanged<Diagnosis> onOpen;
  const RecommendPage({super.key, required this.diag, required this.act, required this.onAct, required this.onOpen});

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  String? gu;
  String query = '';
  late SortKey sort = SortKey.defaultFor(widget.act);

  static const acts = [Act.expand, Act.more, Act.less, Act.close];

  @override
  Widget build(BuildContext context) {
    final diag = widget.diag;
    final act = widget.act;
    final counts = diag.actCounts();
    final list = diag.listOf(act, gu: gu, query: query, sort: sort);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('조치 추천', '조치별 추천 대여소 목록 · 행 선택 시 대여소 상세 화면'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          for (final a in acts) _ActTab(a, counts[a]!, a == act, () => widget.onAct(a)),
        ]),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Panel(
          accent: act.color,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(children: [
            const Text('추천 기준', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: navy)),
            const SizedBox(width: 16),
            Expanded(child: Text(diag.criteria(act), style: const TextStyle(fontSize: 14, color: ink))),
            const SizedBox(width: 12),
            const Text('참고용 추천\n최종 결정: 운영 담당자', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: gray)),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(children: [
          Flexible(child: SearchBox('대여소 이름·번호 검색', (v) => setState(() => query = v))),
          const SizedBox(width: 10),
          Picker<String?>('자치구', gu, [(null, '전체'), for (final g in diag.gus) (g, g)], (v) => setState(() => gu = v)),
          const SizedBox(width: 10),
          Picker<SortKey>('정렬', sort, [for (final s in SortKey.values) (s, s.label)], (v) => setState(() => sort = v)),
          const Spacer(),
          Text('대상 ${comma(list.length)}곳', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: navy)),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
          child: StationTable(list: list, sort: sort, showRank: true, onOpen: widget.onOpen),
        ),
      ),
    ]);
  }
}

class _ActTab extends StatelessWidget {
  final Act act;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _ActTab(this.act, this.count, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? act.color : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? act.color : line),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!selected) ...[
                Container(width: 9, height: 9, decoration: BoxDecoration(color: act.color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
              ],
              Text(act.label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: selected ? Colors.white : ink)),
              const SizedBox(width: 8),
              Text('${comma(count)}곳', style: TextStyle(fontSize: 13, color: selected ? Colors.white : gray)),
            ]),
          ),
        ),
      );
}
