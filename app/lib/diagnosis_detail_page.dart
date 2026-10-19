// 대여소 진단 상세: 분류·제안 조치, 기준선 대비 지표, 시간대별 공백률, 재배치 상대
import 'package:flutter/material.dart';

import 'data.dart';
import 'detail_page.dart' show HourChart;
import 'diagnosis.dart';
import 'style.dart';

/// 분류 판정 근거 문구
String reason(String cls) => switch (cls) {
      '공급 부족' => '수요 중앙값 이상 + 공백률 상위 25%',
      '배치 부족' => '수요 중앙값 미만 + 공백률 상위 25%',
      '과잉' => '수요 중앙값 미만 + 공백률 상위 25% 밖 + 평균 대수 중앙값 이상',
      '저이용' => '일평균 대여 1건 미만 또는 운영 기록 없음',
      _ => '공백률 상위 25% 밖',
    };

class DiagnosisDetailPage extends StatelessWidget {
  final AppData data;
  final DiagnosisData diag;
  final Diagnosis d;
  const DiagnosisDetailPage({super.key, required this.data, required this.diag, required this.d});

  @override
  Widget build(BuildContext context) {
    final th = diag.thresholds;
    List<int>? rates;
    try {
      rates = data.rates(d.id, DayType.weekday);
    } catch (_) {
      rates = null; // 운영 판별에서 제외된 대여소: 공백률 기록 없음
    }
    final turnover = d.turnover;

    return Scaffold(
      appBar: AppBar(title: Text(d.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${d.gu} · 거치대 ${d.racks}개 · 대여소 번호 ${d.id}', style: const TextStyle(color: gray)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: navy, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${d.cls} · ${diag.actions[d.cls]}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
              const SizedBox(height: 4),
              Text('판정 근거: ${reason(d.cls)}', style: const TextStyle(fontSize: 12, color: gray)),
              if (d.lost > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('자전거 0대로 놓친 대여(추정): ${diag.period[0].substring(0, 4)}년 ${d.lost}건',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: navy)),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.9,
            children: [
              _Metric('일평균 대여', '${d.rent.toStringAsFixed(1)}건',
                  '기준 중앙값 ${th['rent_day_median']!.toStringAsFixed(1)}건'),
              _Metric('공백률', d.empty == null ? '기록 없음' : '${d.empty!.toStringAsFixed(1)}%',
                  '기준 상위 25% ${(th['empty_rate_q3']! * 100).toStringAsFixed(1)}%'),
              _Metric('평일 아침 순유출', '${d.am > 0 ? '+' : ''}${d.am.toStringAsFixed(1)}대',
                  '7~9시 대여 - 반납, + 빠져나감'),
              _Metric('거치대당 대여', turnover == null ? '-' : '${turnover.toStringAsFixed(1)}건',
                  '평균 주차 ${d.bikes?.toStringAsFixed(1) ?? '-'}대'),
            ],
          ),
          if (rates != null) ...[
            const SizedBox(height: 20),
            const Text('평일 시간대별 공백률',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navy)),
            const SizedBox(height: 8),
            SizedBox(height: 180, child: HourChart(rates: rates, highlight: -1)),
          ],
          if (d.cls == '공급 부족' || d.cls == '배치 부족') ...[
            const SizedBox(height: 20),
            const Text('재배치 상대: 1km 안 과잉 대여소',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navy)),
            if (d.partners.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('1km 안 과잉 대여소 없음: 증설 검토 대상', style: TextStyle(color: gray)),
              ),
            for (final pid in d.partners)
              if (diag.byId[pid] case final p?)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.name),
                  subtitle: Text('${meters(d, p).round()}m · 평균 주차 ${p.bikes?.toStringAsFixed(1) ?? '-'}대'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DiagnosisDetailPage(data: data, diag: diag, d: p)),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String note;
  const _Metric(this.label, this.value, this.note);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDEE2E6)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: gray)),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
          Text(note, style: const TextStyle(fontSize: 11, color: gray)),
        ]),
      );
}
