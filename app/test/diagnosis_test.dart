import 'package:ddareungi_app/diagnosis.dart';
import 'package:flutter_test/flutter_test.dart';

// 기준선: 하루 평균 대여 중앙값 10건, 전량 대여 비율 상위 25% 경계 25%, 평균 거치 자전거 수 중앙값 5대
const thresholds = {'rent_day_median': 10.0, 'empty_rate_q3': 0.25, 'avg_bikes_median': 5.0};

Diagnosis st(int id, String cls,
        {String name = '대여소',
        String gu = '마포구',
        double rent = 10,
        double? empty = 10,
        double? bikes = 5,
        List<int> partners = const [],
        double lat = 37.55,
        double lon = 126.91}) =>
    Diagnosis(id, cls, rent, rent, empty, bikes, 0, 10, partners, name, gu, lat, lon, 0);

DiagnosisData data(List<Diagnosis> list) =>
    DiagnosisData(['2025-01-01', '2025-12-31'], thresholds, {}, {for (final d in list) d.id: d});

void main() {
  test('근사 거리: 망원역 1번·2번 출구 대여소 약 80m', () {
    final a = st(102, '적정', lat: 37.5556488, lon: 126.91062927);
    final b = st(103, '적정', lat: 37.554951, lon: 126.910835);
    expect(meters(a, b), closeTo(80, 5));
  });

  test('검색: 띄어쓰기 무시, 대여소 번호 일치', () {
    final diag = data([
      st(102, '적정', name: '망원역 1번출구 앞'),
      st(103, '적정', name: '망원역 2번 출구 앞'),
    ]);
    expect(diag.listOf(null, query: '1번 출구').map((d) => d.id), [102]);
    expect(diag.listOf(null, query: '2번출구').map((d) => d.id), [103]);
    expect(diag.listOf(null, query: '103').map((d) => d.id), [103]);
    expect(diag.listOf(null, query: '망 원 역').map((d) => d.id), [102, 103]);
  });

  test('목록 정렬: 조치·자치구 필터, 정렬 기준 순, 같으면 대여소 번호 순', () {
    final diag = data([
      st(9, '공급 부족', empty: 50, rent: 10),
      st(5, '공급 부족', empty: 70, rent: 20),
      st(3, '공급 부족', empty: 50, rent: 10),
      st(7, '공급 부족', empty: 90, gu: '서대문구'),
      st(2, '과잉', empty: 99),
    ]);
    List<int> ids(SortKey? sort) => diag.listOf(Act.expand, gu: '마포구', sort: sort).map((d) => d.id).toList();
    expect(ids(null), [3, 5, 9]);
    expect(ids(SortKey.empty), [5, 3, 9]);
    expect(ids(SortKey.rentAsc), [3, 9, 5]);
  });

  test('추천 근거: 기준선 이상·미만 문구, 기준선과 같으면 이상', () {
    final diag = data([]);
    expect(diag.reasons(st(1, '공급 부족', rent: 12, empty: 25)), [
      '하루 평균 대여 12.0건: 중앙값 10.0건 이상',
      '전량 대여 비율 25.0%: 기준 25.0% 이상',
    ]);
    expect(diag.reasons(st(2, '과잉', rent: 8, empty: 15, bikes: 7.5)), [
      '전량 대여 비율 15.0%: 기준 25.0% 미만',
      '하루 평균 대여 8.0건: 중앙값 10.0건 미만',
      '평균 거치 자전거 수 7.5대: 중앙값 5.0대 이상',
    ]);
    expect(diag.reasons(st(3, '적정', rent: 10, empty: 24.9, bikes: 4.9)), [
      '하루 평균 대여 10.0건: 중앙값 10.0건 이상',
      '전량 대여 비율 24.9%: 기준 25.0% 미만',
      '평균 거치 자전거 수 4.9대: 중앙값 5.0대 미만',
    ]);
    expect(diag.reasons(st(4, '저이용', rent: 0.5)), ['하루 평균 대여 0.5건: 중앙값 10.0건 미만']);
    expect(diag.reasons(st(5, '저이용', rent: 0, empty: null)), ['운영 기록 부재: 운영 기간 판별 기준 미충족']);
  });

  test('추천 기준 문장: 기준선 값 표시', () {
    final diag = data([]);
    expect(diag.criteria(Act.expand), '하루 평균 대여 중앙값 10.0건 이상 · 전량 대여 비율 상위 25% 기준 25.0% 이상');
    expect(diag.criteria(Act.close), '하루 평균 대여 1.0건 미만 또는 운영 기록 부재');
  });

  test('연결 대여소: 증설·확대 → 축소, 축소 → 증설·확대 양방향', () {
    final diag = data([
      st(10, '공급 부족', partners: [30, 20, 99], lat: 37.555, lon: 126.910), // 99: 없는 대여소
      st(11, '배치 부족', partners: [20], lat: 37.551, lon: 126.910),
      st(20, '과잉', lat: 37.550, lon: 126.910),
      st(30, '과잉', lat: 37.552, lon: 126.912),
      st(40, '적정', lat: 37.550, lon: 126.910),
    ]);
    List<int> ids(int id) => diag.linked(diag.byId[id]!).map((d) => d.id).toList();
    expect(ids(10), [30, 20]); // 상대 목록 순서 유지
    expect(ids(11), [20]);
    expect(ids(20), [11, 10]); // 가까운 순
    expect(ids(30), [10]);
    expect(ids(40), isEmpty);
  });
}
