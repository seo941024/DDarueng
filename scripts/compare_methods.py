# 분류 방식 비교: 규칙 기반 vs 군집화(k-means), 상·하반기 분류 일치율
# 사용: python scripts/compare_methods.py  (build_diagnosis.py 다음, diag_h1·diag_h2 표 사용)
import itertools
import sys
from pathlib import Path

import duckdb
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "ddareungi.duckdb"
OUT = ROOT / "analysis" / "method_compare.md"
K = 4  # 저이용 제외 규칙 분류 수 (공급 부족·배치 부족·과잉·적정)


def kmeans(x, k, seed, iters=100):
    """k-means++ 초기화 + 반복 갱신"""
    rng = np.random.default_rng(seed)
    centers = [x[rng.integers(len(x))]]
    for _ in range(k - 1):
        d = np.min(((x[:, None, :] - np.array(centers)[None]) ** 2).sum(-1), axis=1)
        centers.append(x[rng.choice(len(x), p=d / d.sum())])
    c = np.array(centers)
    for _ in range(iters):
        label = ((x[:, None, :] - c[None]) ** 2).sum(-1).argmin(1)
        new = np.array([x[label == j].mean(0) if (label == j).any() else c[j] for j in range(k)])
        if np.allclose(new, c):
            break
        c = new
    return label, c


def best_agreement(a, b, k):
    """묶음 번호가 달라도 같은 묶음이면 일치로 보는 최대 일치율 (번호 대응 전수 탐색)"""
    return max(np.mean(a == np.array(p)[b]) for p in itertools.permutations(range(k)))


def features(rows):
    rent, empty, bikes = (np.array(c, dtype=float) for c in zip(*rows))
    x = np.column_stack([np.log1p(rent), empty, bikes])
    return (x - x.mean(0)) / x.std(0)


def main():
    con = duckdb.connect(str(DB), read_only=True)
    rows = con.execute("""
        SELECT h1.station_id, h1.class, h2.class,
               h1.rent_day, h1.empty_rate, h1.avg_bikes, h2.rent_day, h2.empty_rate, h2.avg_bikes
        FROM diag_h1 h1 JOIN diag_h2 h2 USING (station_id)
        WHERE h1.class <> '저이용' AND h2.class <> '저이용'
        ORDER BY h1.station_id  -- 행 순서 고정: k-means 초기값 선택이 순서에 따라 달라짐""").fetchall()
    n = len(rows)
    rule = np.mean([r[1] == r[2] for r in rows])

    x1 = features([(r[3], r[4], r[5]) for r in rows])
    x2 = features([(r[6], r[7], r[8]) for r in rows])
    halves = []
    for seed in range(10):
        l1, _ = kmeans(x1, K, seed)
        l2, _ = kmeans(x2, K, seed)
        halves.append(best_agreement(l1, l2, K))

    # 같은 데이터(상반기)에서 초기값만 바꿨을 때 결과가 얼마나 달라지는지
    runs = [kmeans(x1, K, s)[0] for s in range(10)]
    seeds = [best_agreement(runs[0], r, K) for r in runs[1:]]

    # 상반기 군집별 평균값 (원래 단위)
    l1, _ = kmeans(x1, K, 0)
    raw = np.array([(r[3], r[4] * 100, r[5]) for r in rows])
    centers = [(j, int((l1 == j).sum()), *raw[l1 == j].mean(0)) for j in range(K)]

    lines = ["# 분류 방식 비교: 규칙 기반 vs 군집화(k-means)", "",
             f"대상: 상·하반기 모두 저이용이 아닌 대여소 {n:,}곳, 지표 3개(하루 평균 대여·공백률·평균 주차 대수)", "",
             "| 방식 | 상·하반기 분류 일치율 | 같은 데이터 재실행 시 결과 | 조치 연결 |", "|---|---|---|---|",
             f"| 규칙 기반 (중앙값·상위 25% 기준선) | {rule * 100:.1f}% | 항상 같음 | 분류 이름이 곧 조치 |",
             f"| 군집화 k-means (k={K}, 초기값 10가지) | 평균 {np.mean(halves) * 100:.1f}% (최소 {min(halves) * 100:.1f}%, 최대 {max(halves) * 100:.1f}%) "
             f"| 초기값에 따라 일치율 {min(seeds) * 100:.1f}~{max(seeds) * 100:.1f}% | 군집 해석 후 조치 별도 지정 필요 |", "",
             "## 상반기 군집별 평균 (초기값 0)", "", "| 군집 | 대여소 | 하루 평균 대여 | 공백률 | 평균 주차 대수 |", "|---|---|---|---|---|"]
    lines += [f"| {j} | {c:,} | {r:.1f}건 | {e:.1f}% | {b:.1f}대 |" for j, c, r, e, b in centers]
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    con.close()


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
