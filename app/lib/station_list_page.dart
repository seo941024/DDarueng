// 대여소 조회: 이름·번호 검색, 자치구·추천 조치 선택 · 공통 대여소 표
import 'package:flutter/material.dart';

import 'diagnosis.dart';
import 'style.dart';

class StationListPage extends StatefulWidget {
  final DiagnosisData diag;
  final Act? initialAct;
  final ValueChanged<Diagnosis> onOpen;
  const StationListPage({super.key, required this.diag, this.initialAct, required this.onOpen});

  @override
  State<StationListPage> createState() => _StationListPageState();
}

class _StationListPageState extends State<StationListPage> {
  String? gu;
  late Act? act = widget.initialAct;
  String query = '';

  @override
  Widget build(BuildContext context) {
    final diag = widget.diag;
    final list = diag.listOf(act, gu: gu, query: query);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('대여소 조회', '전체 대여소 지표·추천 조치 · 행 선택 시 대여소 상세 화면'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(children: [
          Flexible(child: SearchBox('대여소 이름·번호 검색', (v) => setState(() => query = v))),
          const SizedBox(width: 10),
          Picker<String?>('자치구', gu, [(null, '전체'), for (final g in diag.gus) (g, g)], (v) => setState(() => gu = v)),
          const SizedBox(width: 10),
          Picker<Act?>('추천 조치', act, [(null, '전체'), for (final a in Act.values) (a, a.label)],
              (v) => setState(() => act = v)),
          const Spacer(),
          Text('검색 결과 ${comma(list.length)}곳',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: navy)),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
          child: StationTable(list: list, showAct: true, onOpen: widget.onOpen),
        ),
      ),
    ]);
  }
}

/// 대여소 표: 정렬 기준 칼럼 강조, 행 선택 시 상세 화면
class StationTable extends StatelessWidget {
  final List<Diagnosis> list;
  final SortKey? sort;
  final bool showRank;
  final bool showAct;
  final ValueChanged<Diagnosis> onOpen;
  const StationTable(
      {super.key, required this.list, this.sort, this.showRank = false, this.showAct = false, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final flex = [if (showRank) 5, 7, 26, 9, if (showAct) 17, 11, 11, 11];
    bool on(SortKey k) => sort == k || (k == SortKey.rent && sort == SortKey.rentAsc);
    String mark(SortKey k) => !on(k) ? '' : (sort == SortKey.rentAsc ? ' ▲' : ' ▼');
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        TableRowCells([
          if (showRank) headText('순위'),
          headText('대여소 번호'),
          headText('대여소'),
          headText('자치구'),
          if (showAct) headText('추천 조치'),
          headText('하루 평균 대여${mark(SortKey.rent)}', active: on(SortKey.rent), align: TextAlign.right),
          headText('대여 불가 비율${mark(SortKey.empty)}', active: on(SortKey.empty), align: TextAlign.right),
          headText('평균 주차 대수${mark(SortKey.bikes)}', active: on(SortKey.bikes), align: TextAlign.right),
        ], flex, head: true),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('검색 조건 해당 대여소 부재', style: TextStyle(color: gray)))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final d = list[i];
                    return InkWell(
                      onTap: () => onOpen(d),
                      hoverColor: navy.withValues(alpha: 0.05),
                      child: TableRowCells([
                        if (showRank) cellText('${i + 1}', color: gray),
                        cellText('${d.id}', color: gray),
                        cellText(d.name, bold: true),
                        cellText(d.gu),
                        if (showAct) Align(alignment: Alignment.centerLeft, child: ActionBadge(d.act.label, d.act.color, size: 12)),
                        cellText('${n1(d.rent)}건', align: TextAlign.right, bold: on(SortKey.rent)),
                        cellText(d.empty == null ? '-' : '${n1(d.empty)}%', align: TextAlign.right, bold: on(SortKey.empty)),
                        cellText(d.bikes == null ? '-' : '${n1(d.bikes)}대', align: TextAlign.right, bold: on(SortKey.bikes)),
                      ], flex),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
