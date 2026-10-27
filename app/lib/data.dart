// 앱 데이터: 대여소 정보와 시간대별 공백률 (build_metrics.py가 만든 JSON)
import 'dart:convert';

import 'package:flutter/services.dart';

class Station {
  final int id;
  final String name;
  final String gu;
  final double lat;
  final double lon;
  final int racks;
  final Map<String, int> days; // 요일 구분 → 공백률 계산에 쓴 기록 일수

  const Station(this.id, this.name, this.gu, this.lat, this.lon, this.racks, this.days);

  factory Station.fromJson(Map<String, dynamic> j) => Station(
        j['id'] as int,
        j['name'] as String,
        j['gu'] as String,
        (j['lat'] as num).toDouble(),
        (j['lon'] as num).toDouble(),
        j['racks'] as int,
        (j['days'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int)),
      );

  int daysOf(DayType day) => days[day.key] ?? 0;
}

/// 평일 / 휴일(주말·공휴일)
enum DayType {
  weekday('weekday', '평일'),
  holiday('holiday', '휴일');

  final String key;
  final String label;
  const DayType(this.key, this.label);
}

class AppData {
  final List<Station> stations;
  final Map<int, Map<String, List<int>>> _rates; // 대여소 번호 → 요일 구분 → 24시간 공백률(%)

  AppData(this.stations, this._rates);

  static Future<AppData> load() async {
    final stationJson = jsonDecode(await rootBundle.loadString('assets/stations.json')) as List;
    final rateJson = jsonDecode(await rootBundle.loadString('assets/empty_rate.json')) as Map<String, dynamic>;
    final stations = stationJson.map((j) => Station.fromJson(j as Map<String, dynamic>)).toList();
    final rates = <int, Map<String, List<int>>>{
      for (final e in rateJson.entries)
        int.parse(e.key): {
          for (final d in (e.value as Map<String, dynamic>).entries)
            d.key: (d.value as List).map((v) => v as int).toList(),
        },
    };
    return AppData(stations, rates);
  }

  List<int> rates(int stationId, DayType day) => _rates[stationId]![day.key]!;
}
