"""Parse maternal death surveillance sheets (2015-2021; later workbooks have none).

2015: deaths per week plus expected live births. 2016-2021: deaths notified and deaths investigated per week.
Output: data/processed/maternal_deaths.csv (year, week, region, district, live_births, deaths_notified, deaths_investigated)
"""
import re
import pandas as pd
from mdo_common import FILES, TOTAL_RE, canon_district, canon_region, norm, out_path, raw_path


def parse(df, year):
    hdr = next(i for i in range(10) if any(re.fullmatch(r"semaine 0?1", norm(v)) for v in df.iloc[i] if pd.notna(v)))
    weeks = {int(re.fullmatch(r"semaine 0?(\d+)", norm(v)).group(1)): j
             for j, v in df.iloc[hdr].items() if pd.notna(v) and re.fullmatch(r"semaine 0?\d+", norm(v))}
    lab = hdr + 1
    labels = {j: norm(v) for j, v in df.iloc[lab].items() if pd.notna(v)}
    births_col = next((j for j, l in labels.items() if "naissance" in l), None)
    first = min(weeks.values())
    investigated = "enquet" in labels.get(first + 1, "")
    recs, cur = [], None
    for i in range(lab + 1, len(df)):
        reg, dis = df.iat[i, 0], df.iat[i, 1]
        if pd.notna(reg) and TOTAL_RE.search(norm(reg)):
            cur = None
            continue
        if pd.notna(reg) and canon_region(reg):
            cur = canon_region(reg)
        if pd.isna(dis) or TOTAL_RE.search(norm(dis)):
            continue
        d = canon_district(dis)
        if d is None:
            raise ValueError(f"{year}: unknown district {dis!r}")
        births = pd.to_numeric(df.iat[i, births_col], errors="coerce") if births_col is not None else None
        for w, j in weeks.items():
            n = pd.to_numeric(df.iat[i, j], errors="coerce")
            inv = pd.to_numeric(df.iat[i, j + 1], errors="coerce") if investigated else None
            recs.append((year, w, cur, d, births, n, inv))
    return recs


def main():
    regions = pd.read_csv(out_path("district_regions.csv")).set_index("district").region
    recs = []
    for year, fname in FILES.items():
        xl = pd.ExcelFile(raw_path(fname))
        sheet = next((s for s in xl.sheet_names if re.match(r"dc ", norm(s) + " ")), None)
        if sheet is None:
            print(year, "no maternal death sheet")
            continue
        recs += parse(xl.parse(sheet, header=None), year)
        print(year, sheet)
    out = pd.DataFrame(recs, columns=["year", "week", "region", "district", "live_births",
                                      "deaths_notified", "deaths_investigated"])
    out["region"] = out.region.fillna(out.district.map(regions))
    assert out.region.notna().all()
    out.to_csv(out_path("maternal_deaths.csv"), index=False, encoding="utf-8")
    print(out.groupby("year")[["deaths_notified", "deaths_investigated"]].sum())


if __name__ == "__main__":
    main()
