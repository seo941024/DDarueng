import 'package:ddareungi_app/data.dart';
import 'package:flutter_test/flutter_test.dart';

const full = {'weekday': 245, 'holiday': 118};

void main() {
  const a = Station(102, '망원역 1번출구 앞', '마포구', 37.5556488, 126.91062927, 15, full);
  const b = Station(103, '망원역 2번 출구 앞', '마포구', 37.554951, 126.910835, 14, full);

  test('근사 거리: 망원역 1번·2번 출구 대여소 약 80m', () {
    expect(distance(a, b), closeTo(80, 5));
  });

  test('요일 구분: 토·일은 휴일', () {
    expect(DayType.of(DateTime(2026, 10, 17)), DayType.holiday); // 토요일
    expect(DayType.of(DateTime(2026, 10, 19)), DayType.weekday); // 월요일
  });

  test('검색: 띄어쓰기 무시, 대여소 번호 일치', () {
    final data = AppData([a, b], {});
    expect(data.search('1번 출구').map((s) => s.id), [102]);
    expect(data.search('2번출구').map((s) => s.id), [103]);
    expect(data.search('103').map((s) => s.id), [103]);
    expect(data.search('마 포 구').length, 2);
  });

  test('상위 목록: 기록 30일 미만 제외, 동률 시 대여소 번호 순', () {
    const short = Station(1, '휴일 기록 짧은 대여소', '마포구', 37.55, 126.91, 10, {'weekday': 60, 'holiday': 20});
    const c = Station(2, '대여소 C', '마포구', 37.55, 126.91, 10, full);
    const d = Station(3, '대여소 D', '마포구', 37.55, 126.91, 10, full);
    List<int> day(int rate) => List.filled(24, rate);
    final data = AppData([d, short, c], {
      1: {'weekday': day(90), 'holiday': day(90)},
      2: {'weekday': day(50), 'holiday': day(50)},
      3: {'weekday': day(50), 'holiday': day(50)},
    });
    expect(data.emptiest(DayType.weekday, 8).map((s) => s.id), [1, 2, 3]);
    expect(data.emptiest(DayType.holiday, 8).map((s) => s.id), [2, 3]);
  });
}
