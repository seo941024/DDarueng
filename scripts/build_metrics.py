# 정제 규칙 적용 + 공백률 집계 + 데이터 점검 결과 + 앱용 JSON
# 사용: python scripts/build_metrics.py  (load.py 다음)
# 공백률 = 대여소·요일 구분·시간대별 "자전거 0대" 기록 수 / 전체 기록 수
import json
import sys
import time
from datetime import date, timedelta
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "ddareungi.duckdb"
ASSETS = ROOT / "app" / "assets"
REPORT = ROOT / "analysis" / "data_quality.md"

# 2025년 관공서 공휴일 (주말과 같은 "휴일"로 분류)
HOLIDAYS_2025 = {
    "2025-01-01", "2025-01-27", "2025-01-28", "2025-01-29", "2025-01-30",  # 신정, 임시공휴일, 설날
    "2025-03-03", "2025-05-05", "2025-05-06", "2025-06-03", "2025-06-06",  # 삼일절 대체, 어린이날·부처님오신날, 대체, 대선, 현충일
    "2025-08-15", "2025-10-03", "2025-10-05", "2025-10-06", "2025-10-07",  # 광복절, 개천절, 추석
    "2025-10-08", "2025-10-09", "2025-12-25",                              # 추석 대체, 한글날, 성탄절
}

# 자전거가 있던 날이 한 달의 약 1/3 미만인 달은 운영 중단으로 제외 (자주 비는 대여소도 최소 13일)
MIN_BIKE_DAYS = 10  # 기준값 1곳 관리, 변경 시 재집계

STEPS = f"""
-- 운영 기간: 처음 ~ 마지막으로 자전거가 기록된 날 (개설 전·폐쇄 후 제외)
CREATE OR REPLACE TABLE station_span AS
SELECT station_id, MIN(date) AS first_day, MAX(date) AS last_day
FROM availability
WHERE bikes > 0
GROUP BY station_id;

-- 대여소·월별 기록: 자전거가 있던 날이 {MIN_BIKE_DAYS}일 미만이면 운영 중단으로 보고 그달 제외
-- (한 달 내내 0대뿐 아니라, 1년에 1~2번만 자전거가 찍힌 사실상 미운영 대여소까지 거르기 위함)
CREATE OR REPLACE TABLE station_month AS
SELECT station_id, strftime(date, '%Y-%m') AS month, COUNT(*) AS records,
       COUNT(DISTINCT date) FILTER (WHERE bikes > 0) AS bike_days,
       COUNT(DISTINCT date) FILTER (WHERE bikes > 0)
           >= {MIN_BIKE_DAYS} AS active  -- 월별 운영 여부
FROM availability
GROUP BY station_id, month;

-- 공백률: 운영 기간 안 + 운영 중인 달만, 빠진 시간은 채우지 않고 있는 기록만으로 계산
-- 운영 기간 안의 "하루 종일 0대"는 이용자가 실제로 겪는 공백이라 그대로 포함
CREATE OR REPLACE TABLE empty_rate AS
SELECT a.station_id, c.day_type, a.hour,
       COUNT(*)                                AS records,
       ROUND(AVG((a.bikes = 0)::INTEGER), 4)   AS empty_rate,
       ROUND(AVG(a.bikes), 2)                  AS avg_bikes
FROM availability a
JOIN calendar c      ON c.date = a.date
JOIN station_span sp ON sp.station_id = a.station_id AND a.date BETWEEN sp.first_day AND sp.last_day
JOIN station_month m ON m.station_id = a.station_id AND m.month = strftime(a.date, '%Y-%m') AND m.active
GROUP BY a.station_id, c.day_type, a.hour;
"""

CHECKS = [
    ("전체 기록 수", "SELECT COUNT(*) FROM availability"),
    ("대여소 수 (수량 파일)", "SELECT COUNT(DISTINCT station_id) FROM availability"),
    ("중복 기록 (대여소·날짜·시간)",
     "SELECT COUNT(*) FROM (SELECT 1 FROM availability GROUP BY station_id, date, hour HAVING COUNT(*) > 1)"),
    ("음수 자전거 수", "SELECT COUNT(*) FROM availability WHERE bikes < 0"),
    ("24시간 중 빠진 시간이 있는 대여소·날짜",
     "SELECT COUNT(*) FROM (SELECT 1 FROM availability GROUP BY station_id, date HAVING COUNT(*) < 24)"),
    ("그중 전 대여소 공통으로 1시간이 빠진 날짜",
     "SELECT COUNT(*) FROM (SELECT date FROM availability GROUP BY date HAVING COUNT(DISTINCT hour) < 24)"),
    ("1년 내내 0대인 대여소 (제외)",
     "SELECT COUNT(DISTINCT station_id) FROM availability "
     "WHERE station_id NOT IN (SELECT station_id FROM station_span)"),
    ("운영 기간(첫·마지막 자전거 기록) 밖 기록 (제외)",
     "SELECT COUNT(*) FROM availability a JOIN station_span sp USING (station_id) "
     "WHERE a.date NOT BETWEEN sp.first_day AND sp.last_day"),
    (f"자전거가 있던 날이 {MIN_BIKE_DAYS}일 미만인 대여소·월 (제외)", "SELECT COUNT(*) FROM station_month WHERE NOT active"),
    ("대여소 정보에 없는 대여소 번호 (위치 없음, 앱 제외)",
     "SELECT COUNT(DISTINCT station_id) FROM availability "
     "WHERE station_id NOT IN (SELECT station_id FROM stations)"),
    ("자전거 수가 거치대 수의 3배 초과인 기록",
     "SELECT COUNT(*) FROM availability a JOIN stations s USING (station_id) "
     "WHERE s.racks > 0 AND a.bikes > 3 * s.racks"),
]


def build_calendar(con):
    rows, d = [], date(2025, 1, 1)
    while d.year == 2025:
        s = d.isoformat()
        rows.append((s, d.weekday(), "holiday" if d.weekday() >= 5 or s in HOLIDAYS_2025 else "weekday"))
        d += timedelta(days=1)
    con.execute("CREATE OR REPLACE TABLE calendar (date DATE PRIMARY KEY, weekday TINYINT, day_type VARCHAR)")
    con.executemany("INSERT INTO calendar VALUES (?, ?, ?)", rows)


def write_report(con):
    lines = ["# 데이터 점검 결과 (2025년 대여가능 수량)", "", "| 항목 | 값 |", "|---|---|"]
    for label, sql in CHECKS:
        v = con.execute(sql).fetchone()[0]
        lines.append(f"| {label} | {v:,} |")
        print(f"{label}: {v:,}", flush=True)
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")


def export_assets(con):
    # days: 요일 구분별 공백률 계산에 쓴 기록 일수 (앱: 30일 미만 상위 목록 제외·참고용 표기)
    days = {}
    for sid, day_type, n in con.execute(
            "SELECT a.station_id, c.day_type, COUNT(DISTINCT a.date) FROM availability a "
            "JOIN calendar c ON c.date = a.date "
            "JOIN station_span sp ON sp.station_id = a.station_id AND a.date BETWEEN sp.first_day AND sp.last_day "
            "JOIN station_month m ON m.station_id = a.station_id "
            "    AND m.month = strftime(a.date, '%Y-%m') AND m.active "
            "GROUP BY ALL ORDER BY ALL").fetchall():
        days.setdefault(sid, {})[day_type] = n
    # 위치가 있는 대여소만 (대여소 정보와 연결되는 번호)
    stations = [{**dict(zip(("id", "name", "gu", "lat", "lon", "racks"), r)), "days": days[r[0]]}
                for r in con.execute(
        "SELECT station_id, name, gu, lat, lon, racks FROM stations "
        "WHERE station_id IN (SELECT station_id FROM empty_rate) ORDER BY station_id").fetchall()]
    ids = {s["id"] for s in stations}
    rates = {}
    for sid, day_type, hour, rate in con.execute(
            "SELECT station_id, day_type, hour, empty_rate FROM empty_rate ORDER BY ALL").fetchall():
        if sid in ids:
            rates.setdefault(str(sid), {}).setdefault(day_type, [None] * 24)[hour] = round(rate * 100)
    ASSETS.mkdir(parents=True, exist_ok=True)
    (ASSETS / "stations.json").write_text(json.dumps(stations, ensure_ascii=False), encoding="utf-8")
    (ASSETS / "empty_rate.json").write_text(json.dumps(rates, separators=(",", ":")), encoding="utf-8")
    print(f"앱용 JSON: 대여소 {len(stations):,}곳 (공백률 단위 %)", flush=True)


def main():
    started = time.perf_counter()
    con = duckdb.connect(str(DB))
    build_calendar(con)
    con.execute(STEPS)
    write_report(con)
    export_assets(con)
    con.close()
    print(f"정제·집계 {time.perf_counter() - started:.0f}초")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
