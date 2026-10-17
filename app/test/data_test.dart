import 'package:ddareungi_app/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('근사 거리: 망원역 1번·2번 출구 대여소 약 80m', () {
    const a = Station(102, '망원역 1번출구 앞', '마포구', 37.5556488, 126.91062927, 15);
    const b = Station(103, '망원역 2번출구 앞', '마포구', 37.554951, 126.910835, 14);
    expect(distance(a, b), closeTo(80, 5));
  });

  test('요일 구분: 토·일은 휴일', () {
    expect(DayType.of(DateTime(2026, 10, 17)), DayType.holiday); // 토요일
    expect(DayType.of(DateTime(2026, 10, 19)), DayType.weekday); // 월요일
  });
}
