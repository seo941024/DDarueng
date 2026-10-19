# 대여이력(건별) → 대여소·날짜·시간대별 대여·반납 건수 집계 후 DuckDB 적재
# 사용: python scripts/load_rentals.py  (load.py 다음)
# 원본 건수가 수천만 건이라 건별 저장 대신 시간대 집계만 저장 (분류·순유출 계산에 충분)
import sys
import time
import zipfile
from pathlib import Path

import duckdb
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "ddareungi.duckdb"
ZIP = ROOT / "data" / "raw" / "rentals_2025" / "rentals_2025.zip"
USECOLS = ["대여일시", "대여 대여소번호", "반납일시", "반납대여소번호"]
CHUNK = 1_000_000


def hourly_counts(chunk, ts_col, station_col):
    """'2025-05-01 00:00:14' · '04514' → (station_id, date, hour, 건수)"""
    df = chunk[[ts_col, station_col]].dropna()
    df = df[df[ts_col].str.len() >= 13]
    out = pd.DataFrame({
        "station_id": pd.to_numeric(df[station_col], errors="coerce"),
        "date": df[ts_col].str.slice(0, 10),
        "hour": df[ts_col].str.slice(11, 13).astype(int),
    }).dropna()
    out["station_id"] = out["station_id"].astype(int)
    return out.groupby(["station_id", "date", "hour"]).size().rename("n").reset_index()


def aggregate(csv_file):
    """CSV 하나(파일 객체) → 대여·반납 시간대 집계 DataFrame 2개"""
    rents, returns, rows = [], [], 0
    for chunk in pd.read_csv(csv_file, encoding="cp949", usecols=USECOLS, dtype=str, chunksize=CHUNK):
        rows += len(chunk)
        rents.append(hourly_counts(chunk, "대여일시", "대여 대여소번호"))
        returns.append(hourly_counts(chunk, "반납일시", "반납대여소번호"))
    keys = ["station_id", "date", "hour"]
    rent = pd.concat(rents).groupby(keys, as_index=False)["n"].sum()
    ret = pd.concat(returns).groupby(keys, as_index=False)["n"].sum()
    return rent, ret, rows


def main(zip_path=ZIP):
    started = time.perf_counter()
    con = duckdb.connect(str(DB))
    con.execute("""CREATE OR REPLACE TABLE flows (
        station_id INTEGER, date DATE, hour TINYINT, rentals INTEGER, returns INTEGER)""")
    total = 0
    with zipfile.ZipFile(zip_path) as z:
        for info in sorted(z.infolist(), key=lambda i: i.filename):
            if not info.filename.endswith(".csv"):
                continue
            with z.open(info) as f:
                rent, ret, rows = aggregate(f)
            total += rows
            con.register("rent_df", rent)
            con.register("ret_df", ret)
            # 대여·반납 집계를 대여소·날짜·시간 기준으로 합치기 (한쪽만 있는 칸은 0)
            con.execute("""
                INSERT INTO flows
                SELECT COALESCE(a.station_id, b.station_id), CAST(COALESCE(a.date, b.date) AS DATE),
                       COALESCE(a.hour, b.hour), COALESCE(a.n, 0), COALESCE(b.n, 0)
                FROM rent_df a FULL OUTER JOIN ret_df b
                  ON a.station_id = b.station_id AND a.date = b.date AND a.hour = b.hour""")
            print(f"{Path(info.filename).name}: {rows:,}건", flush=True)
    # 2025년 외 날짜(전년 대여·익년 반납 등) 제외
    con.execute("DELETE FROM flows WHERE date < DATE '2025-01-01' OR date > DATE '2025-12-31'")
    n = con.execute("SELECT COUNT(*), SUM(rentals), SUM(returns) FROM flows").fetchone()
    con.close()
    print(f"적재 완료: 원본 {total:,}건 → 집계 {n[0]:,}칸 (대여 {n[1]:,} · 반납 {n[2]:,}), "
          f"{time.perf_counter() - started:.0f}초")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main(Path(sys.argv[1]) if len(sys.argv) > 1 else ZIP)
