"""Parse reporting completeness and timeliness.

2015-2023 workbooks: a week x district grid of T (on time), L (late), N (not received).
2024 workbook: cumulative completeness and timeliness (%) per district up to the last week.

Output: data/processed/completeness_weekly.csv  (year, week, region, district, status, received, on_time)
        data/processed/completeness_national_reported.csv (the sheet's own national % per week)
        data/processed/completeness_2024_cumulative.csv
"""
import re
import pandas as pd
from mdo_common import FILES, canon_district, canon_region, norm, out_path, raw_path

SHEET_RE = re.compile(r"compl|prompt")


def parse_grid(df, year):
    hdr = next(i for i in range(len(df)) if norm(df.iat[i, 0]) == "semaine")
    cols, nat = {}, {}
    for j in range(1, df.shape[1]):
        v = df.iat[hdr, j]
        if pd.isna(v):
            continue
        n = norm(v)
        if "prompt" in n:
            nat["timeliness_pct"] = j
        elif "complet" in n:
            nat["completeness_pct"] = j
        else:
            d = canon_district(v)
            if d is None:
                raise ValueError(f"{year}: unknown district column {v!r}")
            cols[j] = d
    recs, natl = [], []
    for i in range(hdr + 1, len(df)):
        w = pd.to_numeric(df.iat[i, 0], errors="coerce")
        if pd.isna(w):
            break
        for j, d in cols.items():
            code = str(df.iat[i, j]).strip().upper() if pd.notna(df.iat[i, j]) else ""
            if code in ("T", "L", "N"):
                recs.append((year, int(w), d, code, int(code != "N"), int(code == "T")))
        natl.append({"year": year, "week": int(w),
                     **{k: pd.to_numeric(df.iat[i, j], errors="coerce") for k, j in nat.items()}})
    return recs, natl


def parse_2024(df, year):
    title = str(df.iat[0, 0])
    through = int(re.search(r"(\d+)", title).group(1))
    out, region = [], None
    for i in range(2, len(df)):
        name = df.iat[i, 0]
        if pd.isna(name):
            continue
        comp, prom = pd.to_numeric(df.iat[i, 1], errors="coerce"), pd.to_numeric(df.iat[i, 2], errors="coerce")
        if str(name).strip().upper().startswith("DS "):
            level, label = "district", canon_district(name)
            if label is None:
                raise ValueError(f"2024: unknown district {name!r}")
        elif canon_region(name):
            level, label = "region", canon_region(name)
        else:
            level, label = "national", "Niger"
        out.append({"year": year, "through_week": through, "level": level, "name": label,
                    "completeness_pct": comp, "timeliness_pct": prom})
    return out


def main():
    regions = pd.read_csv(out_path("district_regions.csv")).set_index("district").region
    recs, natl, cum = [], [], []
    for year, fname in FILES.items():
        xl = pd.ExcelFile(raw_path(fname))
        sheet = next(s for s in xl.sheet_names if SHEET_RE.search(norm(s)))
        df = xl.parse(sheet, header=None)
        if year == 2024:
            cum += parse_2024(df, year)
        else:
            r, n = parse_grid(df, year)
            recs += r
            natl += n
        print(year, sheet)

    weekly = pd.DataFrame(recs, columns=["year", "week", "district", "status", "received", "on_time"])
    weekly.insert(2, "region", weekly.district.map(regions))
    assert weekly.region.notna().all(), weekly[weekly.region.isna()].district.unique()
    weekly.to_csv(out_path("completeness_weekly.csv"), index=False, encoding="utf-8")
    pd.DataFrame(natl).to_csv(out_path("completeness_national_reported.csv"), index=False, encoding="utf-8")
    cum = pd.DataFrame(cum)
    cum["region"] = cum.apply(lambda r: regions.get(r["name"]) if r.level == "district" else
                              (r["name"] if r.level == "region" else None), axis=1)
    cum.to_csv(out_path("completeness_2024_cumulative.csv"), index=False, encoding="utf-8")
    print(weekly.groupby("year").status.value_counts().unstack(fill_value=0))


if __name__ == "__main__":
    main()
