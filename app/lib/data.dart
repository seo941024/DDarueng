// 앱 데이터: 대여소 정보와 시간대별 공백률 (build_metrics.py가 만든 JSON)
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class Station {
  final int id;
  final String name;
  final String gu;
  final double lat;
  final double lon;
  final int racks;

  const Station(this.id, this.name, this.gu, this.lat, this.lon, this.racks);

  factory Station.fromJson(Map<String, dynamic> j) => Station(
        j['id'] as int,
        j['name'] as String,
        j['gu'] as String,
        (j['lat'] as num).toDouble(),
        (j['lon'] as num).toDouble(),
        j['racks'] as int,
      );
}

/// 평일 / 휴일(주말·공휴일)
enum DayType {
  weekday('weekday', '평일'),
  holiday('holiday', '휴일');

  final String key;
  final String label;
  const DayType(this.key, this.label);

  // 공휴일 목록은 없으므로 오늘이 토·일이면 휴일
  static DayType of(DateTime t) =>
      t.weekday >= DateTime.saturday ? DayType.holiday : DayType.weekday;
}

class Nearby {
  final Station station;
  final double meters;
  const Nearby(this.station, this.meters);
}

class AppData {
  final List<Station> stations;
  final Map<int, Map<String, List<int>>> _rates; // 대여소 번호 → 요일 구분 → 24시간 공백률(%)

  AppData._(this.stations, this._rates);

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
    return AppData._(stations, rates);
  }

  List<int> rates(int stationId, DayType day) => _rates[stationId]![day.key]!;

  int rateAt(int stationId, DayType day, int hour) => rates(stationId, day)[hour];

  /// 이름·자치구 검색
  List<Station> search(String query) {
    final q = query.trim();
    return stations.where((s) => s.name.contains(q) || s.gu.contains(q)).toList();
  }

  /// 지금 시간 공백률 높은 대여소
  List<Station> emptiest(DayType day, int hour, {int limit = 20}) {
    final list = [...stations]..sort((a, b) => rateAt(b.id, day, hour).compareTo(rateAt(a.id, day, hour)));
    return list.take(limit).toList();
  }

  /// 반경 안 대여소, 공백률 낮은 순 (같으면 가까운 순)
  List<Nearby> nearby(Station from, DayType day, int hour, {double radius = 500}) {
    final list = <Nearby>[
      for (final s in stations)
        if (s.id != from.id && distance(from, s) <= radius) Nearby(s, distance(from, s)),
    ];
    list.sort((a, b) {
      final r = rateAt(a.station.id, day, hour).compareTo(rateAt(b.station.id, day, hour));
      return r != 0 ? r : a.meters.compareTo(b.meters);
    });
    return list;
  }
}

/// 서울 위도(약 37.5도) 기준 근사 거리(m): 경도 1도 약 88.2km, 위도 1도 약 111km
double distance(Station a, Station b) {
  final dx = (a.lon - b.lon) * 88200;
  final dy = (a.lat - b.lat) * 111000;
  return sqrt(dx * dx + dy * dy);
}
