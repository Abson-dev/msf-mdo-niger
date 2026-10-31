"""Parse the DHIS2 extract for 2024 (weeks 1-37): one sheet per week, plus a cumulative sheet and a spare copy.

Output: data/processed/dhis2_2024_weekly.csv   district rows: week, region, district, population,
                                                completeness_pct, timeliness_pct, disease, cases, deaths
        data/processed/dhis2_2024_totals.csv   the extract's own region and national rows (for checks)
        data/processed/dhis2_2024_cumulative.csv  the "Cumul S1-S37" sheet, district rows
"""
import re
import pandas as pd
from mdo_common import DHIS2_FILE, canon_district, canon_region, disease_of, norm, out_path, raw_path


def parse(df, week):
    head = [str(v) if pd.notna(v) else "" for v in df.iloc[0]]
    col = {norm(h): j for j, h in enumerate(head)}
    reg_c = next(j for j, h in enumerate(head) if norm(h).startswith("region"))
    dis_c = next(j for j, h in enumerate(head) if norm(h).startswith("district"))
    pop_c = next(j for j, h in enumerate(head) if norm(h).startswith("population"))
    comp_c, prom_c = col.get("completude"), col.get("promptitude")
    pairs = [(disease_of(h), j) for j, h in enumerate(head) if re.search(r"\bcas$", norm(h))]
    assert all(d for d, _ in pairs), [head[j] for d, j in pairs if not d]
    rows, totals = [], []
    for i in range(1, len(df)):
        name = df.iat[i, dis_c]
        if pd.isna(name):
            continue
        base = {
            "week": week,
            "population": pd.to_numeric(df.iat[i, pop_c], errors="coerce"),
            "completeness_pct": pd.to_numeric(df.iat[i, comp_c], errors="coerce") if comp_c is not None else None,
            "timeliness_pct": pd.to_numeric(df.iat[i, prom_c], errors="coerce") if prom_c is not None else None,
        }
        if str(name).strip().upper().startswith("DS "):
            d = canon_district(name)
            if d is None:
                raise ValueError(f"week {week}: unknown district {name!r}")
            target, base = rows, {**base, "region": canon_region(df.iat[i, reg_c]), "district": d}
        else:
            target, base = totals, {**base, "level": "region" if canon_region(name) else "national",
                                    "name": canon_region(name) or "Niger"}
        for dz, j in pairs:
            target.append({**base, "disease": dz, "cases": pd.to_numeric(df.iat[i, j], errors="coerce"),
                           "deaths": pd.to_numeric(df.iat[i, j + 1], errors="coerce")})
    return rows, totals


def main():
    xl = pd.ExcelFile(raw_path(DHIS2_FILE))
    rows, totals = [], []
    for s in xl.sheet_names:
        m = re.fullmatch(r"S(\d+)", s.strip())
        if m:
            r, t = parse(xl.parse(s, header=None), int(m.group(1)))
            rows += r
            totals += t
    weekly = pd.DataFrame(rows)
    weekly.to_csv(out_path("dhis2_2024_weekly.csv"), index=False, encoding="utf-8")
    pd.DataFrame(totals).to_csv(out_path("dhis2_2024_totals.csv"), index=False, encoding="utf-8")

    cum_sheet = next(s for s in xl.sheet_names if norm(s).startswith("cumul"))
    cum, _ = parse(xl.parse(cum_sheet, header=None), None)
    cum = pd.DataFrame(cum).drop(columns=["week", "completeness_pct", "timeliness_pct"])
    cum.to_csv(out_path("dhis2_2024_cumulative.csv"), index=False, encoding="utf-8")

    # "Feuil2" holds one week again; record which so the check step can compare it
    spare = xl.parse("Feuil2", header=None)
    wk = int(re.search(r"W(\d+)", str(spare.iat[1, 0])).group(1))
    sp, _ = parse(spare, wk)
    pd.DataFrame(sp).to_csv(out_path("dhis2_2024_spare_sheet.csv"), index=False, encoding="utf-8")
    print("weeks:", weekly.week.nunique(), "districts:", weekly.district.nunique(),
          "diseases:", weekly.disease.nunique(), "| spare sheet is week", wk)


if __name__ == "__main__":
    main()
