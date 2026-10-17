# analysis/queries.sql 실행 → analysis/query_results.md (쿼리별 결과·소요 시간)
# 사용: python scripts/run_queries.py
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "ddareungi.duckdb"
SQL = ROOT / "analysis" / "queries.sql"
OUT = ROOT / "analysis" / "query_results.md"


def blocks(text):
    # 빈 줄 + "-- 번호." 주석으로 시작하는 덩어리 단위로 나누기
    for part in text.split(";"):
        lines = [l for l in part.strip().splitlines() if l.strip()]
        titles = [l[3:] for l in lines if l.startswith("-- ") and l[3:4].isdigit()]
        if titles and any(not l.startswith("--") for l in lines):
            yield titles[0], part


def main():
    con = duckdb.connect(str(DB), read_only=True)
    out = ["# 분석 쿼리 결과", ""]
    for title, sql in blocks(SQL.read_text(encoding="utf-8")):
        started = time.perf_counter()
        rel = con.execute(sql)
        cols = [d[0] for d in rel.description]
        rows = rel.fetchall()
        sec = time.perf_counter() - started
        out += [f"## {title} ({sec:.2f}초)", "", "| " + " | ".join(cols) + " |",
                "|" + "---|" * len(cols)]
        out += ["| " + " | ".join(str(v) for v in r) + " |" for r in rows]
        out.append("")
        print(f"{title}: {len(rows)}행, {sec:.2f}초", flush=True)
    OUT.write_text("\n".join(out), encoding="utf-8")
    con.close()


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
