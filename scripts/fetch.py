# 서울 열린데이터광장에서 새로 올라온 파일만 내려받기
# 사용: python scripts/fetch.py [--since 2025]
# 대여가능 수량 파일은 공개 시기가 일정하지 않아(수시) 한 달에 한 번 실행 권장
import argparse
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
PAGE = "https://data.seoul.go.kr/dataList/{}/F/1/datasetView.do"
DOWNLOAD = "https://datafile.seoul.go.kr/bigfile/iot/inf/nio_download.do?&useCache=false"
HEADERS = {"User-Agent": "Mozilla/5.0"}

FILE_RE = re.compile(r"title=\"([^\"]+)\" onclick=\"javascript:downloadFile\('(\d+)'\)")
INF_SEQ_RE = re.compile(r'name="frmFile".*?name="infSeq" value="(\d+)"', re.S)


def availability_target(title, since):
    # "..._2025년도_4분기.zip" → data/raw/2025_q4/2025_q4.zip
    m = re.search(r"(\d{4})년도[_ ](\d)분기\.zip$", title)
    if not m or int(m[1]) < since:
        return None
    name = f"{m[1]}_q{m[2]}"
    return RAW / name / f"{name}.zip"


def stations_target(title, since):
    # "공공자전거 대여소 정보(25.12월 기준).xlsx" → data/raw/stations/stations_2512.xlsx
    m = re.search(r"\((\d{2})\.(\d{1,2})월 기준\)\.xlsx$", title)
    if not m or 2000 + int(m[1]) < since:
        return None
    return RAW / "stations" / f"stations_{m[1]}{int(m[2]):02d}.xlsx"


def rentals_target(title, since):
    # "서울특별시 공공자전거 대여이력 정보_2025.zip" → data/raw/rentals_2025/rentals_2025.zip (연 단위 파일만)
    m = re.search(r"대여이력 정보_(\d{4})\.zip$", title)
    if not m or int(m[1]) < since:
        return None
    name = f"rentals_{m[1]}"
    return RAW / name / f"{name}.zip"


DATASETS = [("OA-22382", availability_target), ("OA-13252", stations_target), ("OA-15182", rentals_target)]


def get(url, data=None):
    body = urllib.parse.urlencode(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=HEADERS)
    return urllib.request.urlopen(req, timeout=900)


def main(since):
    new = 0
    for inf_id, target_of in DATASETS:
        html = get(PAGE.format(inf_id)).read().decode("utf-8", "replace")
        inf_seq = INF_SEQ_RE.search(html)[1]
        for title, seq in dict(FILE_RE.findall(html)).items():
            target = target_of(title, since)
            if target is None or target.exists():
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            tmp = target.with_suffix(target.suffix + ".part")
            with get(DOWNLOAD, {"infId": inf_id, "seq": seq, "infSeq": inf_seq}) as r, open(tmp, "wb") as f:
                while chunk := r.read(1 << 20):
                    f.write(chunk)
            tmp.rename(target)
            new += 1
            print(f"받음: {title} → {target.relative_to(ROOT)}", flush=True)
    print(f"새 파일 {new}개" if new else "새 파일 없음")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", type=int, default=2025, help="이 연도부터 받기")
    main(ap.parse_args().since)
