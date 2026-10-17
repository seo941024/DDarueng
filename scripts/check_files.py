# 내려받은 따릉이 파일의 인코딩·칼럼·앞부분 확인
# 사용: python scripts/check_files.py data/raw
import sys
import zipfile
from pathlib import Path

import pandas as pd

ENCODINGS = ("utf-8-sig", "cp949")


def read_head(src, name):
    # 서울시 파일은 UTF-8과 CP949가 섞여 있어 둘 다 시도
    for enc in ENCODINGS:
        try:
            with src() as f:
                return enc, pd.read_csv(f, encoding=enc, nrows=5)
        except UnicodeDecodeError:
            continue
    raise ValueError(f"인코딩 확인 실패: {name}")


def show(name, enc, df):
    print(f"\n=== {name} ({enc})")
    print("칼럼:", list(df.columns))
    print(df.to_string(index=False))


def main(folder):
    for path in sorted(Path(folder).rglob("*")):
        if path.suffix == ".zip":
            with zipfile.ZipFile(path) as z:
                for info in z.infolist():
                    if info.filename.lower().endswith(".csv"):
                        enc, df = read_head(lambda: z.open(info), info.filename)
                        show(f"{path.name} / {info.filename}", enc, df)
        elif path.suffix == ".csv":
            enc, df = read_head(lambda: open(path, "rb"), path.name)
            show(path.name, enc, df)
        elif path.suffix == ".xlsx":
            df = pd.read_excel(path, nrows=5)
            show(path.name, "xlsx", df)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "data/raw")
