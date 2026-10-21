// 대여소 진단 데이터: build_diagnosis.py가 만든 diagnosis.json (분류·지표·재배치 상대)
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

/// 분류 순서: 조치가 급한 순
const classOrder = ['공급 부족', '배치 부족', '과잉', '저이용', '적정'];

/// 추천 조치: 분류 코드 → 장표·Power BI와 같은 이름·색
enum Act {
  expand('공급 부족', '대여소 증설 검토', Color(0xFF2E9E44)),
  more('배치 부족', '자전거 배치 확대', Color(0xFF12239E)),
  less('과잉', '자전거 배치 축소', Color(0xFFD62728)),
  close('저이용', '대여소 이전·폐쇄 검토', Color(0xFF111111)),
  keep('적정', '현 상태 유지', Color(0xFF118DFF));

  final String code;
  final String label;
  final Color color;
  const Act(this.code, this.label, this.color);

  static Act of(String code) => values.firstWhere((a) => a.code == code);
}

/// 목록 정렬 기준
enum SortKey {
  empty('전량 대여 비율 높은 순'),
  rent('하루 평균 대여 많은 순'),
  rentAsc('하루 평균 대여 적은 순'),
  bikes('평균 거치 자전거 수 많은 순');

  final String label;
  const SortKey(this.label);

  double score(Diagnosis d) => switch (this) {
        empty => d.empty ?? -1,
        rent => d.rent,
        rentAsc => -d.rent,
        bikes => d.bikes ?? -1,
      };

  /// 조치별 기본 정렬
  static SortKey defaultFor(Act a) => switch (a) {
        Act.expand || Act.more => empty,
        Act.less => bikes,
        Act.close => rentAsc,
        Act.keep => rent,
      };
}

class Diagnosis {
  final int id;
  final String cls;
  final double rent; // 일평균 대여
  final double ret; // 일평균 반납
  final double? empty; // 공백률(%)
  final double? bikes; // 평균 거치 자전거 수
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

  Act get act => Act.of(cls);

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

  /// 기준선: 하루 평균 대여 중앙값(건), 전량 대여 비율 상위 25% 경계(%), 평균 거치 자전거 수 중앙값(대)
  double get rentMedian => thresholds['rent_day_median']!;
  double get emptyQ3 => thresholds['empty_rate_q3']! * 100;
  double get bikesMedian => thresholds['avg_bikes_median']!;
  static const minRent = 1.0;

  String f1(double v) => v.toStringAsFixed(1);

  /// 조치별 추천 기준 문장
  String criteria(Act a) => switch (a) {
        Act.expand => '하루 평균 대여 중앙값 ${f1(rentMedian)}건 이상 · 전량 대여 비율 상위 25% 기준 ${f1(emptyQ3)}% 이상',
        Act.more => '하루 평균 대여 중앙값 ${f1(rentMedian)}건 미만 · 전량 대여 비율 상위 25% 기준 ${f1(emptyQ3)}% 이상',
        Act.less =>
          '전량 대여 비율 ${f1(emptyQ3)}% 미만 · 하루 평균 대여 중앙값 미만 · 평균 거치 자전거 수 중앙값 ${f1(bikesMedian)}대 이상',
        Act.close => '하루 평균 대여 ${f1(minRent)}건 미만 또는 운영 기록 부재',
        Act.keep => '추천 조치 조건 미해당',
      };

  /// 대여소별 추천 근거: 지표값과 기준 비교
  List<String> reasons(Diagnosis d) {
    String rentCmp() => '하루 평균 대여 ${f1(d.rent)}건: 중앙값 ${f1(rentMedian)}건 ${d.rent >= rentMedian ? '이상' : '미만'}';
    String emptyCmp() =>
        '전량 대여 비율 ${n(d.empty)}%: 기준 ${f1(emptyQ3)}% ${(d.empty ?? 0) >= emptyQ3 ? '이상' : '미만'}';
    String bikesCmp() =>
        '평균 거치 자전거 수 ${n(d.bikes)}대: 중앙값 ${f1(bikesMedian)}대 ${(d.bikes ?? 0) >= bikesMedian ? '이상' : '미만'}';
    return switch (d.act) {
      Act.expand || Act.more => [rentCmp(), emptyCmp()],
      Act.less => [emptyCmp(), rentCmp(), bikesCmp()],
      Act.close => d.empty == null ? ['운영 기록 부재: 운영 기간 판별 기준 미충족'] : [rentCmp()],
      Act.keep => [rentCmp(), emptyCmp(), bikesCmp()],
    };
  }

  String n(double? v) => v == null ? '-' : v.toStringAsFixed(1);

  /// 조치별 목록: 자치구·검색어 필터, 정렬 기준 적용, 같으면 대여소 번호 순
  List<Diagnosis> listOf(Act? a, {String? gu, String query = '', SortKey? sort}) {
    final q = query.replaceAll(RegExp(r'\s+'), '');
    final id = int.tryParse(q);
    final list = byId.values
        .where((d) => a == null || d.act == a)
        .where((d) => gu == null || d.gu == gu)
        .where((d) => q.isEmpty || d.id == id || d.name.replaceAll(RegExp(r'\s+'), '').contains(q))
        .toList();
    list.sort((x, y) {
      if (sort != null) {
        final c = sort.score(y).compareTo(sort.score(x));
        if (c != 0) return c;
      }
      return x.id.compareTo(y.id);
    });
    return list;
  }

  /// 자치구 목록 (가나다순)
  List<String> get gus => (byId.values.map((d) => d.gu).toSet().toList()..sort());

  /// 조치별 대여소 수
  Map<Act, int> actCounts({String? gu}) {
    final m = {for (final a in Act.values) a: 0};
    for (final d in byId.values.where((d) => gu == null || d.gu == gu)) {
      m[d.act] = m[d.act]! + 1;
    }
    return m;
  }

  /// 반경 1km 내 연결 대여소: 증설·확대 추천 → 배치 축소 추천 대여소, 배치 축소 추천 → 증설·확대 추천 대여소
  List<Diagnosis> linked(Diagnosis d) {
    if (d.act == Act.expand || d.act == Act.more) {
      return [for (final p in d.partners) if (byId[p] != null) byId[p]!];
    }
    if (d.act == Act.less) {
      final list = byId.values.where((o) => o.partners.contains(d.id)).toList()
        ..sort((a, b) => meters(d, a).compareTo(meters(d, b)));
      return list;
    }
    return const [];
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
