// 대여소 진단 데이터: build_diagnosis.py가 만든 diagnosis.json (분류·지표·재배치 상대)
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

/// 분류 순서: 조치가 급한 순
const classOrder = ['공급 부족', '배치 부족', '과잉', '저이용', '적정'];

class Diagnosis {
  final int id;
  final String cls;
  final double rent; // 일평균 대여
  final double ret; // 일평균 반납
  final double? empty; // 공백률(%)
  final double? bikes; // 평균 주차 대수
  final double am; // 평일 7~9시 순유출(대여 - 반납)
  final int racks;
  final List<int> partners; // 1km 안 과잉 대여소 (가까운 순)
  final String name;
  final String gu;
  final double lat;
  final double lon;
  final int lost; // 놓친 대여(추정, 기간 합계)

  const Diagnosis(this.id, this.cls, this.rent, this.ret, this.empty, this.bikes, this.am, this.racks,
      this.partners, this.name, this.gu, this.lat, this.lon, this.lost);

  /// 거치대 1개당 일평균 대여
  double? get turnover => racks > 0 ? rent / racks : null;

  factory Diagnosis.fromJson(int id, Map<String, dynamic> j) => Diagnosis(
        id,
        j['c'] as String,
        (j['rent'] as num).toDouble(),
        (j['ret'] as num).toDouble(),
        (j['empty'] as num?)?.toDouble(),
        (j['bikes'] as num?)?.toDouble(),
        (j['am'] as num).toDouble(),
        j['racks'] as int,
        (j['p'] as List).map((v) => v as int).toList(),
        j['n'] as String,
        j['g'] as String,
        (j['lat'] as num).toDouble(),
        (j['lon'] as num).toDouble(),
        (j['lost'] as num?)?.toInt() ?? 0,
      );
}

class DiagnosisData {
  final List<String> period;
  final Map<String, double> thresholds;
  final Map<String, String> actions;
  final Map<int, Diagnosis> byId;

  DiagnosisData._(this.period, this.thresholds, this.actions, this.byId);

  static Future<DiagnosisData> load() async {
    final j = jsonDecode(await rootBundle.loadString('assets/diagnosis.json')) as Map<String, dynamic>;
    final stations = j['stations'] as Map<String, dynamic>;
    return DiagnosisData._(
      (j['period'] as List).cast<String>(),
      (j['thresholds'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble())),
      (j['actions'] as Map<String, dynamic>).cast<String, String>(),
      {
        for (final e in stations.entries)
          int.parse(e.key): Diagnosis.fromJson(int.parse(e.key), e.value as Map<String, dynamic>),
      },
    );
  }

  Map<String, int> counts({String? gu}) {
    final m = {for (final c in classOrder) c: 0};
    for (final d in byId.values.where((d) => gu == null || d.gu == gu)) {
      m[d.cls] = (m[d.cls] ?? 0) + 1;
    }
    return m;
  }

  /// 분류별 우선순위 점수 (클수록 먼저)
  static double priority(Diagnosis d) => switch (d.cls) {
        '공급 부족' || '배치 부족' => d.lost.toDouble(), // 놓친 대여(추정) 많은 순
        '과잉' => d.bikes ?? 0, // 평균 대수 많은 순
        '저이용' => -d.rent, // 대여 적은 순
        _ => d.rent,
      };

  /// 분류별 우선순위 정렬, 같으면 대여소 번호 순
  List<Diagnosis> ranked(String cls, {String? gu}) {
    final list = byId.values.where((d) => d.cls == cls && (gu == null || d.gu == gu)).toList();
    list.sort((a, b) {
      final c = priority(b).compareTo(priority(a));
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return list;
  }
}

/// 근사 거리(m): data.dart와 같은 방식 (서울 기준 경도 1도 약 88.2km, 위도 1도 약 111km)
double meters(Diagnosis a, Diagnosis b) {
  final dx = (a.lon - b.lon) * 88200;
  final dy = (a.lat - b.lat) * 111000;
  return sqrt(dx * dx + dy * dy);
}
