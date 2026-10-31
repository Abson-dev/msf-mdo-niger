"""Parse the weekly disease sheets of every yearly MDO workbook into one long table.

Output: data/processed/mdo_long.csv (year, week, region, district, population, disease, cases, deaths, tested)
        data/processed/check_sheet_totals.csv (parsed totals vs each sheet's own grand-total row)
"""
import re
import pandas as pd
from mdo_common import FILES, TOTAL_RE, canon_district, canon_region, disease_of, norm, out_path, raw_path

# 2015-16 meningitis sheets add aggregate rows ("DOUTCHI DS" = Dogon-Doutchi + Tibiri)
SUBDISTRICT_DUPES = {"DOUTCHI DS", "GAYA DS"}


def parse_sheet(df, year, disease, file_totals):
    hdr = next((i for i in range(min(15, len(df)))
                if any(re.fullmatch(r"semaine 0?1", norm(v)) for v in df.iloc[i] if pd.notna(v))), None)
    if hdr is None:
        return []
    row = df.iloc[hdr]
    weeks = {}
    for j, v in row.items():
        m = re.fullmatch(r"semaine 0?(\d+)", norm(v)) if pd.notna(v) else None
        if m:
            weeks[int(m.group(1))] = j
    pop_col = next((j for j, v in row.items() if pd.notna(v) and norm(v).startswith("pop")), None)
    first_wk = min(weeks.values())

    # 2015-2020 confirmed-malaria sheets: presumed / tests done / positives / % positive
    case_off, death_off, test_off = 0, 1, None
    for r in range(hdr + 1, min(hdr + 4, len(df))):
        labels = [norm(df.iat[r, first_wk + k]) for k in range(4)]
        if any("positif" in l for l in labels):
            case_off = next(k for k, l in enumerate(labels) if "positif" in l and "%" not in str(df.iat[r, first_wk + k]))
            test_off = next(k for k, l in enumerate(labels) if "realis" in l)
            death_off = None
            break

    start = hdr + 1
    while start < len(df) and (pd.isna(df.iat[start, 0]) or norm(df.iat[start, 0]) in ("region", "")):
        start += 1

    def cell(i, j):
        return pd.to_numeric(df.iat[i, j], errors="coerce") if j < df.shape[1] else None

    recs, cur_reg = [], None
    for i in range(start, len(df)):
        reg, dis = df.iat[i, 0], df.iat[i, 1]
        if pd.notna(reg) and TOTAL_RE.search(norm(reg)):
            cur_reg = None
            if re.search(r"total g|niger|pays|national", norm(reg)):
                file_totals.append((year, disease, sum(cell(i, j + case_off) or 0 for j in weeks.values())))
            continue
        if pd.notna(reg) and re.search(r"[a-z]", norm(reg)):
            cur_reg = reg  # new districts often have a blank region cell
        if pd.isna(dis) or TOTAL_RE.search(norm(dis)):
            continue
        if year <= 2016 and str(dis).strip() in SUBDISTRICT_DUPES:
            continue
        district = canon_district(dis)
        if district is None:
            raise ValueError(f"{year} {disease}: unknown district {dis!r}")
        pop = cell(i, pop_col) if pop_col is not None else None
        for w, j in weeks.items():
            recs.append((year, w, canon_region(cur_reg) if cur_reg is not None else None, district, pop, disease,
                         cell(i, j + case_off),
                         cell(i, j + death_off) if death_off is not None else None,
                         cell(i, j + test_off) if test_off is not None else None))
    return recs


def main():
    rows, file_totals = [], []
    for year, fname in FILES.items():
        xl = pd.ExcelFile(raw_path(fname))
        seen = set()
        for sheet in xl.sheet_names:
            dz = disease_of(sheet)
            if dz is None or dz in seen:
                continue
            recs = parse_sheet(xl.parse(sheet, header=None), year, dz, file_totals)
            if recs:
                seen.add(dz)
                rows += recs
        print(year, "diseases:", len(seen))

    cols = ["year", "week", "region", "district", "population", "disease", "cases", "deaths", "tested"]
    out = pd.DataFrame(rows, columns=cols)
    lookup = out.dropna(subset=["region"]).groupby("district").region.agg(lambda s: s.mode()[0])
    out["region"] = out.region.fillna(out.district.map(lookup))
    assert out.region.notna().all(), out[out.region.isna()].district.unique()
    out.to_csv(out_path("mdo_long.csv"), index=False, encoding="utf-8")
    lookup.rename("region").reset_index().to_csv(out_path("district_regions.csv"), index=False, encoding="utf-8")

    ft = pd.DataFrame(file_totals, columns=["year", "disease", "sheet_total"]).drop_duplicates(["year", "disease"])
    cmp = out.groupby(["year", "disease"]).cases.sum().rename("parsed_total").reset_index().merge(ft, how="left")
    cmp["diff"] = cmp.parsed_total - cmp.sheet_total
    cmp.to_csv(out_path("check_sheet_totals.csv"), index=False, encoding="utf-8")
    print("rows:", len(out), "| totals matching sheet exactly:", int((cmp["diff"].abs() < 0.5).sum()), "of", len(cmp))


if __name__ == "__main__":
    main()
