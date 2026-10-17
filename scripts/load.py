# 원본 zip·xlsx를 DuckDB로 적재
# 사용: python scripts/load.py
# DuckDB: 서버 없는 파일 DB, 열 단위 저장이라 수천만 행 집계에 유리
import sys
import time
import zipfile
from pathlib import Path

import duckdb
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
DB = ROOT / "data" / "ddareungi.duckdb"
# 수량 데이터 기간(2025년) 말 기준 대여소 정보
STATIONS_FILE = "stations_2512.xlsx"

# 원본 칼럼명 "거치대수량"은 실제로 시간대별 주차 자전거 수
COLUMNS = {"일시": "date", "대여소번호": "station_id", "대여소명": "station_name",
           "시간대": "hour", "거치대수량": "bikes"}

SCHEMA = """
CREATE TABLE availability (
    date       DATE     NOT NULL,
    hour       TINYINT  NOT NULL,   -- 0~23
    station_id INTEGER  NOT NULL,
    bikes      SMALLINT NOT NULL    -- 그 시간 주차 자전거 수
);
CREATE TABLE station_names (        -- 수량 파일에 적힌 대여소명 (대여소 정보에 없는 번호 대비)
    station_id INTEGER PRIMARY KEY,
    name       VARCHAR
);
CREATE TABLE stations (             -- 대여소 정보 (위치·거치대 수)
    station_id INTEGER PRIMARY KEY,
    name       VARCHAR,
    gu         VARCHAR,
    address    VARCHAR,
    lat        DOUBLE,
    lon        DOUBLE,
    racks      INTEGER              -- LCD + QR 거치대 수
);
"""


def read_month(z, info):
    with z.open(info) as f:
        df = pd.read_csv(f, encoding="cp949")
    df = df.rename(columns=COLUMNS)
    missing = set(COLUMNS.values()) - set(df.columns)
    if missing:
        raise ValueError(f"{info.filename}: 칼럼 없음 {missing}")
    return df


def load_availability(con):
    names = {}
    for zpath in sorted(RAW.glob("2025_q*/*.zip")):
        with zipfile.ZipFile(zpath) as z:
            for info in sorted(z.infolist(), key=lambda i: i.filename):
                if not info.filename.endswith(".csv"):
                    continue
                df = read_month(z, info)
                con.register("month_df", df)
                con.execute("INSERT INTO availability SELECT CAST(date AS DATE), hour, station_id, bikes FROM month_df")
                con.unregister("month_df")
                # 대여소명 "102. 망원역 1번출구 앞" 앞 번호 제거
                for sid, name in df.drop_duplicates("station_id")[["station_id", "station_name"]].values:
                    names[int(sid)] = str(name).split(". ", 1)[-1].strip()
                print(f"{zpath.name} {Path(info.filename).name}: {len(df):,}행", flush=True)
    con.executemany("INSERT INTO station_names VALUES (?, ?)", sorted(names.items()))


def load_stations(con):
    # 머리글 5줄 (병합 셀) 건너뛰고 위치로 읽기
    df = pd.read_excel(RAW / "stations" / STATIONS_FILE, header=None, skiprows=5)
    df = df.iloc[:, :9]
    df.columns = ["station_id", "name", "gu", "address", "lat", "lon", "installed", "racks_lcd", "racks_qr"]
    df = df.dropna(subset=["station_id"])
    df["station_id"] = df["station_id"].astype(int)
    for col in ("name", "gu", "address"):
        df[col] = df[col].astype(str).str.strip()   # 원본 이름 앞 공백 제거
    df["racks"] = df["racks_lcd"].fillna(0).astype(int) + df["racks_qr"].fillna(0).astype(int)
    df = df[["station_id", "name", "gu", "address", "lat", "lon", "racks"]]
    con.register("stations_df", df)
    con.execute("INSERT INTO stations SELECT * FROM stations_df")
    con.unregister("stations_df")
    print(f"대여소 정보: {len(df):,}곳", flush=True)


def main():
    started = time.perf_counter()
    DB.parent.mkdir(parents=True, exist_ok=True)
    DB.unlink(missing_ok=True)
    con = duckdb.connect(str(DB))
    con.execute(SCHEMA)
    load_stations(con)
    load_availability(con)
    n = con.execute("SELECT COUNT(*) FROM availability").fetchone()[0]
    con.close()
    print(f"적재 완료: {n:,}행, {time.perf_counter() - started:.0f}초, "
          f"파일 {DB.stat().st_size / 2**20:,.0f}MB → {DB}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
