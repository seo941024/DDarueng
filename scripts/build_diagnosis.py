# 대여소 진단: 수요(대여) × 공급 상태(전량 대여 비율)로 분류, 조치 제안, 상·하반기 안정성 검증, 앱용 JSON
# 사용: python scripts/build_diagnosis.py  (load.py · build_metrics.py · load_rentals.py 다음)
import json
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "ddareungi.duckdb"
ASSET = ROOT / "app" / "assets" / "diagnosis.json"
REPORT = ROOT / "analysis" / "diagnosis_summary.md"

MIN_RENT_DAY = 1.0      # 일평균 대여 1건 미만: 저이용
PARTNER_RADIUS = 1000   # 재배치 상대 대여소 탐색 반경(m)

ACTIONS = {
    "공급 부족": "증설·재배치 우선",
    "배치 부족": "재배치 점검",
    "과잉": "재배치 출발지·축소 검토",
    "적정": "유지",
    "저이용": "이전·폐쇄 검토",
}

# 운영 중인 기록: build_metrics.py와 같은 판별 (운영 기간 안 + 운영 중인 달)
OPERATING = """
SELECT a.* FROM availability a
JOIN station_span sp  ON sp.station_id = a.station_id AND a.date BETWEEN sp.first_day AND sp.last_day
JOIN station_month m  ON m.station_id = a.station_id AND m.month = strftime(a.date, '%Y-%m') AND m.active
"""


def metrics(con, start, end):
    """기간 [start, end]의 대여소별 지표 (운영 중인 날만)"""
    con.execute(f"""
    CREATE OR REPLACE TEMP TABLE met AS
    WITH op AS ({OPERATING} WHERE a.date BETWEEN DATE '{start}' AND DATE '{end}'),
         st AS (SELECT station_id, COUNT(DISTINCT date) AS days,
                       AVG((bikes = 0)::INTEGER) AS empty_rate, AVG(bikes) AS avg_bikes
                FROM op GROUP BY station_id),
         days AS (SELECT DISTINCT station_id, date FROM op),
         fl AS (SELECT f.station_id, SUM(f.rentals) AS rentals, SUM(f.returns) AS returns
                FROM flows f JOIN days d USING (station_id, date) GROUP BY f.station_id),
         am AS (SELECT f.station_id, SUM(f.rentals - f.returns) AS out_sum, COUNT(DISTINCT f.date) AS wd
                FROM flows f JOIN days d USING (station_id, date) JOIN calendar c ON c.date = f.date
                WHERE c.day_type = 'weekday' AND f.hour BETWEEN 7 AND 9 GROUP BY f.station_id),
         -- 놓친 대여(추정): 자전거 있던 시간의 평균 대여를 같은 요일 구분·시간대의 0대 시간에 적용, 실제 대여와의 차이
         hr AS (SELECT o.station_id, c.day_type, o.hour, o.bikes, COALESCE(f.rentals, 0) AS rentals
                FROM op o JOIN calendar c ON c.date = o.date
                LEFT JOIN flows f ON f.station_id = o.station_id AND f.date = o.date AND f.hour = o.hour),
         ex AS (SELECT station_id, day_type, hour, AVG(rentals) AS exp_rent
                FROM hr WHERE bikes > 0 GROUP BY ALL),
         lost AS (SELECT h.station_id, SUM(greatest(e.exp_rent - h.rentals, 0)) AS lost_sum
                  FROM hr h JOIN ex e USING (station_id, day_type, hour)
                  WHERE h.bikes = 0 GROUP BY h.station_id)
    SELECT st.station_id, st.days, st.empty_rate, st.avg_bikes,
           COALESCE(fl.rentals, 0) / st.days AS rent_day,
           COALESCE(fl.returns, 0) / st.days AS ret_day,
           COALESCE(am.out_sum / NULLIF(am.wd, 0), 0) AS am_out,
           COALESCE(lost.lost_sum, 0) / st.days AS lost_day
    FROM st LEFT JOIN fl USING (station_id) LEFT JOIN am USING (station_id) LEFT JOIN lost USING (station_id)
    """)


def classify(con, table):
    """met → table: 기준선은 대여소 분포에서 산출 (수요 중앙값, 전량 대여 비율 상위 25%, 거치 대수 중앙값)"""
    th = con.execute(f"""
        SELECT median(rent_day), quantile_cont(empty_rate, 0.75), median(avg_bikes)
        FROM met WHERE rent_day >= {MIN_RENT_DAY}""").fetchone()
    con.execute(f"""
    CREATE OR REPLACE TABLE {table} AS
    SELECT *,
    -- th: 대여소 분포 기준선 (수요 중앙값 28.2건,
    --     전량 대여 비율 상위 25% 13.0%, 거치 대수 중앙값 10.5대)
    CASE
        WHEN rent_day < {MIN_RENT_DAY} THEN '저이용'
        WHEN empty_rate >= {th[1]} AND rent_day >= {th[0]} THEN '공급 부족'
        WHEN empty_rate >= {th[1]} THEN '배치 부족'
        WHEN rent_day < {th[0]} AND avg_bikes >= {th[2]} THEN '과잉'
        ELSE '적정' END AS class
    FROM met""")
    return {"rent_day_median": th[0], "empty_rate_q3": th[1], "avg_bikes_median": th[2]}


def main():
    con = duckdb.connect(str(DB))
    start, end = [str(d) for d in con.execute("SELECT MIN(date), MAX(date) FROM flows").fetchone()]
    print(f"분석 기간: {start} ~ {end}")

    # 전체 기간 분류
    metrics(con, start, end)
    th = classify(con, "diagnosis")
    # 미운영(운영 판별 제외) 대여소: 대여소 정보에 있지만 운영 기록이 없는 곳
    con.execute(f"""
    INSERT INTO diagnosis (station_id, days, empty_rate, avg_bikes, rent_day, ret_day, am_out, lost_day, class)
    SELECT s.station_id, 0, NULL, NULL, 0, 0, 0, 0, '저이용'
    FROM stations s WHERE s.station_id NOT IN (SELECT station_id FROM diagnosis)
      AND s.station_id IN (SELECT DISTINCT station_id FROM availability)""")

    # 상·하반기 안정성: 각 반기 따로 기준선 산출·분류 후 같은 분류 비율
    halves = [("2025-01-01", "2025-06-30"), ("2025-07-01", "2025-12-31")]
    stable = None
    if start <= halves[0][1] and end >= halves[1][0]:
        for k, (a, b) in enumerate(halves, 1):
            metrics(con, a, b)
            classify(con, f"diag_h{k}")
        stable = con.execute("""
            SELECT COUNT(*) FILTER (WHERE h1.class = h2.class) * 1.0 / COUNT(*), COUNT(*)
            FROM diag_h1 h1 JOIN diag_h2 h2 USING (station_id)""").fetchone()
        by_class = con.execute("""
            SELECT h1.class, COUNT(*), AVG((h1.class = h2.class)::INTEGER)
            FROM diag_h1 h1 JOIN diag_h2 h2 USING (station_id) GROUP BY 1 ORDER BY 2 DESC""").fetchall()

    # 재배치 상대: 공급·배치 부족 대여소별 1km 안 과잉 대여소 (가까운 순 3곳)
    con.execute(f"""
    CREATE OR REPLACE TABLE partners AS
    WITH d AS (SELECT d.station_id, d.class, s.lat, s.lon FROM diagnosis d JOIN stations s USING (station_id)),
         pairs AS (
            SELECT a.station_id, b.station_id AS partner_id,
                   sqrt(((a.lon - b.lon) * 88200) ** 2 + ((a.lat - b.lat) * 111000) ** 2) AS meters
            FROM d a JOIN d b ON a.class IN ('공급 부족', '배치 부족') AND b.class = '과잉'
             AND abs(a.lat - b.lat) < 0.01 AND abs(a.lon - b.lon) < 0.012)
    SELECT * FROM (SELECT *, row_number() OVER (PARTITION BY station_id ORDER BY meters, partner_id) AS rk
                   FROM pairs WHERE meters <= {PARTNER_RADIUS}) WHERE rk <= 3""")

    # 결과 요약
    counts = con.execute("""SELECT class, COUNT(*), SUM(lost_day * days), SUM(rent_day * days)
                             FROM diagnosis GROUP BY 1 ORDER BY 2 DESC""").fetchall()
    with_partner = con.execute("""
        SELECT COUNT(DISTINCT d.station_id) FILTER (WHERE p.station_id IS NOT NULL), COUNT(DISTINCT d.station_id)
        FROM diagnosis d LEFT JOIN partners p USING (station_id)
        WHERE d.class IN ('공급 부족', '배치 부족')""").fetchone()
    corr = con.execute("SELECT corr(rent_day, empty_rate) FROM diagnosis WHERE class <> '저이용'").fetchone()[0]

    lines = ["# 대여소 진단 결과", "", f"분석 기간: {start} ~ {end}", "",
             "## 기준선 (대여소 분포에서 산출)", "",
             f"- 수요 기준: 일평균 대여 중앙값 {th['rent_day_median']:.1f}건",
             f"- 공백 기준: 공백률 상위 25% 경계 {th['empty_rate_q3'] * 100:.1f}%",
             f"- 과잉 기준: 평균 거치 자전거 수 중앙값 {th['avg_bikes_median']:.1f}대",
             f"- 저이용: 일평균 대여 {MIN_RENT_DAY:.0f}건 미만 또는 운영 기록 없음", "",
             "## 분류별 대여소 수", "",
             "| 분류 | 대여소 | 제안 조치 | 실제 대여 | 놓친 대여(추정) |", "|---|---|---|---|---|"]
    lines += [f"| {c} | {n:,} | {ACTIONS[c]} | {r or 0:,.0f}건 | {l or 0:,.0f}건 |" for c, n, l, r in counts]
    top = con.execute("""SELECT s.name, s.gu, d.class, d.lost_day * d.days, d.rent_day, d.empty_rate
                         FROM diagnosis d JOIN stations s USING (station_id)
                         WHERE d.class IN ('공급 부족', '배치 부족') ORDER BY 4 DESC, d.station_id LIMIT 10""").fetchall()
    lines += ["", "## 놓친 대여(추정) 상위 10곳", "", "| 대여소 | 자치구 | 분류 | 놓친 대여 | 일평균 대여 | 공백률 |",
              "|---|---|---|---|---|---|"]
    lines += [f"| {n} | {g} | {c} | {l:,.0f}건 | {r:.1f}건 | {e * 100:.1f}% |" for n, g, c, l, r, e in top]
    lines += ["", f"- 수요·공백률 상관계수: {corr:.3f}",
              f"- 공급·배치 부족 {with_partner[1]:,}곳 중 1km 안 과잉 대여소 있는 곳: {with_partner[0]:,}곳"]
    if stable:
        lines += ["", "## 검증: 상·하반기 분류 안정성", "",
                  f"- 상반기·하반기 각각 기준선 산출 후 분류, 같은 분류 유지 비율 {stable[0] * 100:.1f}% ({stable[1]:,}곳)",
                  "", "| 상반기 분류 | 대여소 | 하반기 같은 분류 비율 |", "|---|---|---|"]
        lines += [f"| {c} | {n:,} | {r * 100:.1f}% |" for c, n, r in by_class]
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))

    # 앱용 JSON: 위치 있는 대여소만
    rows = con.execute("""
        SELECT d.station_id, d.class, d.rent_day, d.ret_day, d.empty_rate, d.avg_bikes, d.am_out,
               s.racks, list(p.partner_id ORDER BY p.rk) FILTER (WHERE p.partner_id IS NOT NULL),
               s.name, s.gu, s.lat, s.lon, d.lost_day * d.days
        FROM diagnosis d JOIN stations s USING (station_id) LEFT JOIN partners p USING (station_id)
        WHERE s.lat IS NOT NULL
        GROUP BY ALL ORDER BY d.station_id""").fetchall()
    out = {
        "period": [start, end],
        "thresholds": {k: round(v, 4) for k, v in th.items()},
        "actions": ACTIONS,
        "stations": {str(r[0]): {
            "c": r[1], "rent": round(r[2], 1), "ret": round(r[3], 1),
            "empty": None if r[4] is None else round(r[4] * 100, 1),
            "bikes": None if r[5] is None else round(r[5], 1), "am": round(r[6], 1),
            "racks": r[7], "p": r[8] or [],
            "n": r[9], "g": r[10], "lat": r[11], "lon": r[12], "lost": round(r[13] or 0)} for r in rows},
    }
    ASSET.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"\n앱용 JSON: {len(rows):,}곳 → {ASSET.relative_to(ROOT)}")
    con.close()


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
