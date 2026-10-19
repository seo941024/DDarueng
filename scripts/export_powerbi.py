# Power BI용 CSV 내보내기 (UTF-8, 한글 칼럼명, 파일명은 영문)
# stations: 대여소진단 · hourly: 시간대 공백률 · monthly: 월별 추이 · partners: 재배치 상대
# 사용: python scripts/export_powerbi.py  (build_diagnosis.py 다음)
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "ddareungi.duckdb"
OUT = ROOT / "powerbi" / "data"

# 분류 → 조치 (대상+조치 형태, 장표·앱과 같은 이름)
ACTION = """CASE class WHEN '공급 부족' THEN '대여소 증설 검토' WHEN '배치 부족' THEN '자전거 배치 확대'
                        WHEN '과잉' THEN '자전거 배치 축소' WHEN '저이용' THEN '대여소 이전·폐쇄 검토'
                        ELSE '현 상태 유지' END"""

OPERATING = """
FROM availability a
JOIN station_span sp ON sp.station_id = a.station_id AND a.date BETWEEN sp.first_day AND sp.last_day
JOIN station_month m ON m.station_id = a.station_id AND m.month = strftime(a.date, '%Y-%m') AND m.active
"""

QUERIES = {
    # 진단 대상 전체(장표 분류 수와 같게), 대여소 정보 미등록 대여소는 이름만 원본에서, 위치 없음
    "stations": f"""
        SELECT d.station_id AS 대여소번호, COALESCE(s.name, n.name) AS 대여소명,
               COALESCE(s.gu, '위치 미등록') AS 자치구, s.lat AS 위도, s.lon AS 경도,
               s.racks AS 거치대수, {ACTION} AS 조치, d.class AS 분류,
               ROUND(d.rent_day, 1) AS 하루평균대여, ROUND(d.ret_day, 1) AS 하루평균반납,
               ROUND(d.empty_rate * 100, 1) AS 공백률, ROUND(d.avg_bikes, 1) AS 평균주차대수,
               ROUND(d.am_out, 1) AS 아침순유출, d.days AS 운영일수
        FROM diagnosis d LEFT JOIN stations s USING (station_id) LEFT JOIN station_names n USING (station_id)
        ORDER BY d.station_id""",
    "hourly": """
        SELECT station_id AS 대여소번호, CASE day_type WHEN 'weekday' THEN '평일' ELSE '휴일' END AS 요일구분,
               hour AS 시간, ROUND(empty_rate * 100, 2) AS 공백률, records AS 기록수
        FROM empty_rate
        WHERE station_id IN (SELECT station_id FROM stations)
        ORDER BY 1, 2, 3""",
    "monthly": f"""
        WITH e AS (SELECT strftime(a.date, '%Y-%m') AS ym, s.gu, AVG((a.bikes = 0)::INTEGER) AS empty_rate
                   {OPERATING} JOIN stations s ON s.station_id = a.station_id GROUP BY ALL),
             f AS (SELECT strftime(f.date, '%Y-%m') AS ym, s.gu, SUM(f.rentals) AS rentals, SUM(f.returns) AS returns
                   FROM flows f JOIN stations s USING (station_id) GROUP BY ALL)
        SELECT e.ym AS 월, e.gu AS 자치구, COALESCE(f.rentals, 0) AS 대여건수, COALESCE(f.returns, 0) AS 반납건수,
               ROUND(e.empty_rate * 100, 2) AS 공백률
        FROM e LEFT JOIN f USING (ym, gu)
        ORDER BY 1, 2""",
    "partners": """
        SELECT p.station_id AS 대여소번호, p.partner_id AS 상대대여소번호, s.name AS 상대대여소명,
               ROUND(p.meters) AS 거리m, p.rk AS 순위
        FROM partners p JOIN stations s ON s.station_id = p.partner_id
        ORDER BY 1, 5""",
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB), read_only=True)
    for name, sql in QUERIES.items():
        path = OUT / f"{name}.csv"
        con.execute(f"COPY ({sql}) TO '{path.as_posix()}' (HEADER, DELIMITER ',')")
        n = con.execute(f"SELECT COUNT(*) FROM ({sql})").fetchone()[0]
        print(f"{name}.csv: {n:,}행")
    con.close()


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
