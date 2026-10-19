// 운영자용 PC 화면: 상단 요약, 왼쪽 우선순위 목록, 오른쪽 대여소 진단
import 'package:flutter/material.dart';

import 'data.dart';
import 'detail_page.dart' show HourChart;
import 'diagnosis.dart';
import 'style.dart';

const line = Color(0xFFDEE2E6);

/// 분류 판정 근거
String reason(String cls) => switch (cls) {
      '공급 부족' => '수요 중앙값 이상 + 공백률 상위 25%',
      '배치 부족' => '수요 중앙값 미만 + 공백률 상위 25%',
      '과잉' => '수요 중앙값 미만 + 공백률 상위 25% 밖 + 평균 대수 중앙값 이상',
      '저이용' => '일평균 대여 1건 미만 또는 운영 기록 없음',
      _ => '공백률 상위 25% 밖',
    };

/// 천 단위 쉼표
String fmt(num n) => n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

class DesktopShell extends StatefulWidget {
  final AppData data;
  final DiagnosisData diag;
  const DesktopShell({super.key, required this.data, required this.diag});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  String _cls = classOrder.first;
  String? _gu;
  String _query = '';
  Diagnosis? _selected;

  List<Diagnosis> get _list {
    final q = _query.replaceAll(' ', '');
    final list = widget.diag.ranked(_cls, gu: _gu);
    return q.isEmpty ? list : list.where((d) => d.name.replaceAll(' ', '').contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final diag = widget.diag;
    final list = _list;
    final selected = _selected ?? (list.isNotEmpty ? list.first : null);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        _Header(
          diag: diag,
          gu: _gu,
          cls: _cls,
          onClass: (c) => setState(() {
            _cls = c;
            _selected = null;
          }),
        ),
        const Divider(height: 1, color: line),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 560,
              child: _StationList(
                diag: diag,
                cls: _cls,
                gu: _gu,
                list: list,
                selected: selected,
                onGu: (g) => setState(() {
                  _gu = g;
                  _selected = null;
                }),
                onQuery: (q) => setState(() => _query = q),
                onSelect: (d) => setState(() => _selected = d),
              ),
            ),
            const VerticalDivider(width: 1, color: line),
            Expanded(
              child: selected == null
                  ? const Center(child: Text('해당 대여소 없음', style: TextStyle(color: gray)))
                  : _Detail(
                      key: ValueKey(selected.id),
                      data: widget.data,
                      diag: diag,
                      d: selected,
                      onSelect: (d) => setState(() {
                        _cls = d.cls;
                        _selected = d;
                      }),
                    ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// 상단: 제목, 기간, 분류별 대여소 수·놓친 대여 합계 (누르면 분류 선택)
class _Header extends StatelessWidget {
  final DiagnosisData diag;
  final String? gu;
  final String cls;
  final ValueChanged<String> onClass;
  const _Header({required this.diag, required this.gu, required this.cls, required this.onClass});

  @override
  Widget build(BuildContext context) {
    final counts = diag.counts(gu: gu);
    final lost = {for (final c in classOrder) c: 0};
    for (final d in diag.byId.values.where((d) => gu == null || d.gu == gu)) {
      lost[d.cls] = lost[d.cls]! + d.lost;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('따릉이 대여소 진단', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navy)),
          const SizedBox(width: 12),
          Text('${diag.period[0]} ~ ${diag.period[1]} 기록 · 수요(대여) × 공백률 분류${gu == null ? '' : ' · $gu'}',
              style: const TextStyle(color: gray)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          for (final c in classOrder)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () => onClass(c),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: c == cls ? navy : line, width: c == cls ? 2 : 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c, style: TextStyle(fontWeight: FontWeight.bold, color: c == cls ? navy : gray)),
                      Text('${fmt(counts[c]!)}곳',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
                      Text(
                          c == '공급 부족' || c == '배치 부족'
                              ? '놓친 대여(추정) ${fmt(lost[c]!)}건'
                              : diag.actions[c]!,
                          style: const TextStyle(fontSize: 12, color: gray)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// 왼쪽: 이름 검색·자치구 선택, 우선순위 표
class _StationList extends StatelessWidget {
  final DiagnosisData diag;
  final String cls;
  final String? gu;
  final List<Diagnosis> list;
  final Diagnosis? selected;
  final ValueChanged<String?> onGu;
  final ValueChanged<String> onQuery;
  final ValueChanged<Diagnosis> onSelect;
  const _StationList({
    required this.diag,
    required this.cls,
    required this.gu,
    required this.list,
    required this.selected,
    required this.onGu,
    required this.onQuery,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final gus = (diag.byId.values.map((d) => d.gu).toSet().toList())..sort();
    final shortage = cls == '공급 부족' || cls == '배치 부족';
    const head = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: gray);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: '대여소 이름',
                border: OutlineInputBorder(),
              ),
              onChanged: onQuery,
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String?>(
            value: gu,
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem(value: null, child: Text('전체 자치구')),
              for (final g in gus) DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: onGu,
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: Text('$cls ${fmt(list.length)}곳 · 제안 조치: ${diag.actions[cls]} · 우선순위 순',
            style: const TextStyle(fontWeight: FontWeight.bold, color: navy)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFFF8F9FA),
        child: Row(children: [
          const SizedBox(width: 36, child: Text('순위', style: head)),
          const Expanded(child: Text('대여소', style: head)),
          const SizedBox(width: 72, child: Text('자치구', style: head)),
          const SizedBox(width: 70, child: Text('일평균 대여', style: head, textAlign: TextAlign.right)),
          const SizedBox(width: 62, child: Text('공백률', style: head, textAlign: TextAlign.right)),
          SizedBox(
              width: 82, child: Text(shortage ? '놓친 대여' : '평균 대수', style: head, textAlign: TextAlign.right)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final d = list[i];
            final on = selected?.id == d.id;
            return InkWell(
              onTap: () => onSelect(d),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: on ? const Color(0xFFEEF2F7) : null,
                  border: const Border(bottom: BorderSide(color: line)),
                ),
                child: Row(children: [
                  SizedBox(width: 36, child: Text('${i + 1}', style: const TextStyle(color: gray))),
                  Expanded(
                    child: Text(d.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: on ? FontWeight.bold : FontWeight.normal)),
                  ),
                  SizedBox(width: 72, child: Text(d.gu, style: const TextStyle(color: gray))),
                  SizedBox(width: 70, child: Text(d.rent.toStringAsFixed(1), textAlign: TextAlign.right)),
                  SizedBox(
                      width: 62,
                      child: Text(d.empty == null ? '-' : '${d.empty!.toStringAsFixed(1)}%',
                          textAlign: TextAlign.right)),
                  SizedBox(
                    width: 82,
                    child: Text(shortage ? fmt(d.lost) : (d.bikes?.toStringAsFixed(1) ?? '-'),
                        textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

/// 오른쪽: 선택 대여소 진단
class _Detail extends StatelessWidget {
  final AppData data;
  final DiagnosisData diag;
  final Diagnosis d;
  final ValueChanged<Diagnosis> onSelect;
  const _Detail({super.key, required this.data, required this.diag, required this.d, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final th = diag.thresholds;
    List<int>? rates;
    try {
      rates = data.rates(d.id, DayType.weekday);
    } catch (_) {
      rates = null; // 운영 판별 제외 대여소: 공백률 기록 없음
    }
    final turnover = d.turnover;
    const sectionTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navy);

    return ListView(padding: const EdgeInsets.fromLTRB(28, 20, 28, 28), children: [
      Text(d.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('${d.gu} · 거치대 ${d.racks}개 · 대여소 번호 ${d.id}', style: const TextStyle(color: gray)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration:
            BoxDecoration(border: Border.all(color: navy, width: 1.5), borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${d.cls} · ${diag.actions[d.cls]}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
          const SizedBox(height: 4),
          Text('판정 근거: ${reason(d.cls)}', style: const TextStyle(color: gray)),
          if (d.lost > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('자전거 0대로 놓친 대여(추정): ${diag.period[0].substring(0, 4)}년 ${fmt(d.lost)}건',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: navy)),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        _Metric('일평균 대여', '${d.rent.toStringAsFixed(1)}건', '기준 중앙값 ${th['rent_day_median']!.toStringAsFixed(1)}건'),
        _Metric('공백률', d.empty == null ? '기록 없음' : '${d.empty!.toStringAsFixed(1)}%',
            '기준 상위 25% ${(th['empty_rate_q3']! * 100).toStringAsFixed(1)}%'),
        _Metric('평일 아침 순유출', '${d.am > 0 ? '+' : ''}${d.am.toStringAsFixed(1)}대', '7~9시 대여 - 반납, + 빠져나감'),
        _Metric('거치대당 대여', turnover == null ? '-' : '${turnover.toStringAsFixed(1)}건',
            '평균 주차 ${d.bikes?.toStringAsFixed(1) ?? '-'}대'),
      ]),
      const SizedBox(height: 22),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('평일 시간대별 공백률', style: sectionTitle),
            const SizedBox(height: 10),
            rates == null
                ? const Text('공백률 기록 없음 (운영 판별 제외)', style: TextStyle(color: gray))
                : SizedBox(height: 220, child: HourChart(rates: rates, highlight: -1)),
          ]),
        ),
        const SizedBox(width: 28),
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('재배치 상대: 1km 안 과잉 대여소', style: sectionTitle),
            const SizedBox(height: 6),
            if (d.cls != '공급 부족' && d.cls != '배치 부족')
              const Text('부족 분류에만 표시', style: TextStyle(color: gray))
            else if (d.partners.isEmpty)
              const Text('1km 안 과잉 대여소 없음: 증설 검토 대상', style: TextStyle(color: gray)),
            for (final pid in d.partners)
              if (diag.byId[pid] case final p?)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.name),
                  subtitle: Text('${meters(d, p).round()}m · 평균 주차 ${p.bikes?.toStringAsFixed(1) ?? '-'}대'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onSelect(p),
                ),
          ]),
        ),
      ]),
    ]);
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String note;
  const _Metric(this.label, this.value, this.note);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: line), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: gray)),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navy)),
            Text(note, style: const TextStyle(fontSize: 11, color: gray)),
          ]),
        ),
      );
}
