// 대여소 진단 목록: 분류별 우선순위, 자치구 필터
import 'package:flutter/material.dart';

import 'data.dart';
import 'diagnosis.dart';
import 'diagnosis_detail_page.dart';
import 'style.dart';

class DiagnosisPage extends StatefulWidget {
  final AppData data;
  final DiagnosisData diag;
  const DiagnosisPage({super.key, required this.data, required this.diag});

  @override
  State<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends State<DiagnosisPage> {
  String _cls = classOrder.first;
  String? _gu; // null: 전체

  @override
  Widget build(BuildContext context) {
    final diag = widget.diag;
    final counts = diag.counts(gu: _gu);
    final list = diag.ranked(_cls, gu: _gu);
    final gus = (diag.byId.values.map((d) => d.gu).toSet().toList())..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('대여소 진단')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('${diag.period[0]} ~ ${diag.period[1]} 기록 · 수요(대여) × 공백률 분류',
                style: const TextStyle(fontSize: 12, color: gray)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              for (final c in classOrder)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('$c ${counts[c]}'),
                    selected: _cls == c,
                    onSelected: (_) => setState(() => _cls = c),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Expanded(
                child: Text('제안 조치: ${diag.actions[_cls]}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: navy)),
              ),
              DropdownButton<String?>(
                value: _gu,
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('전체 자치구')),
                  for (final g in gus) DropdownMenuItem(value: g, child: Text(g)),
                ],
                onChanged: (v) => setState(() => _gu = v),
              ),
            ]),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('해당 대여소 없음', style: TextStyle(color: gray)))
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (context, i) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = list[i];
                      return ListTile(
                        leading: Text('${i + 1}', style: const TextStyle(color: gray)),
                        minLeadingWidth: 28,
                        title: Text(d.name),
                        subtitle: Text(_cls == '공급 부족' || _cls == '배치 부족'
                            ? '${d.gu} · 놓친 대여(추정) ${_fmt(d.lost)}건'
                            : '${d.gu} · 일평균 대여 ${d.rent.toStringAsFixed(1)}건'),
                        trailing: Text(d.empty == null ? '기록 없음' : '공백률 ${d.empty!.toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: gray)),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => DiagnosisDetailPage(data: widget.data, diag: diag, d: d)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 천 단위 쉼표
String _fmt(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
