"""Cross-check the parsed tables against every summary the source files carry.

Checks (one row each in data/processed/validation_checks.csv):
  sheet_total        district sums vs each disease sheet's grand-total row (all years)
  synthese           national totals vs the "Synthèse" sheets (2022-2024 workbooks, DHIS2 extract)
  mas_2016_region    2016 severe-malnutrition totals by region vs the "analyse mas" sheet
  mas_2016_rate      weekly regional attack rates vs "Sheet3"; Filingué vs "Sheet4"
  completeness_nat   weekly national timeliness/completeness vs the grid's own % columns
  dhis2_cumul        sum of DHIS2 weekly sheets vs the "Cumul S1-S37" sheet
  dhis2_spare        "Feuil2" vs the weekly sheet of the same week
  dhis2_totals       DHIS2 district sums vs the extract's own national rows
Also writes data/processed/dhis2_vs_workbook_2024.csv: weekly national cases, DHIS2 vs 2024 workbook.
"""
import re
import pandas as pd
from mdo_common import DHIS2_FILE, FILES, canon_region, disease_of, norm, out_path, raw_path

CHECKS = []


def add(check, year, item, reference, parsed):
    CHECKS.append({"check": check, "year": year, "item": item, "reference": reference, "parsed": parsed})


def read_synthese(path, sheet):
    df = pd.read_excel(path, sheet_name=sheet, header=None)
    r0, c0 = next((i, j) for i in range(len(df)) for j in range(df.shape[1]) if norm(df.iat[i, j]) == "maladies")
    head = {norm(v): j for j, v in df.iloc[r0].items() if pd.notna(v)}
    cc, dc = head["cas"], head["deces"]
    out = {}
    for i in range(r0 + 1, len(df)):
        dz = disease_of(df.iat[i, c0]) if pd.notna(df.iat[i, c0]) else None
        if dz and dz not in out:
            out[dz] = (pd.to_numeric(df.iat[i, cc], errors="coerce"), pd.to_numeric(df.iat[i, dc], errors="coerce"))
    return out


def main():
    long = pd.read_csv(out_path("mdo_long.csv"))
    annual = long.groupby(["year", "disease"])[["cases", "deaths"]].sum()

    for r in pd.read_csv(out_path("check_sheet_totals.csv")).itertuples():
        add("sheet_total", r.year, r.disease, r.sheet_total, r.parsed_total)

    for year in (2022, 2023, 2024):
        xl = pd.ExcelFile(raw_path(FILES[year]))
        sheet = next(s for s in xl.sheet_names if norm(s).startswith("synth"))
        for dz, (c, d) in read_synthese(raw_path(FILES[year]), sheet).items():
            if (year, dz) in annual.index:
                add("synthese", year, f"{dz} cases", c, annual.loc[(year, dz), "cases"])
                add("synthese", year, f"{dz} deaths", d, annual.loc[(year, dz), "deaths"])

    # 2016 severe acute malnutrition analysis sheets
    xl = pd.ExcelFile(raw_path(FILES[2016]))
    mas = xl.parse("analyse mas", header=None)
    gap = next(i for i in range(4, len(mas)) if pd.isna(mas.iat[i, 0]))
    sam = long[(long.year == 2016) & (long.disease == "Malnutrition sévère")]
    reg_cases = sam.groupby("region").cases.sum()
    pops = {}
    for i in range(gap, len(mas)):
        name = mas.iat[i, 0]
        reg = canon_region(re.sub(r"(?i)total", "", str(name))) if pd.notna(name) else None
        if reg:
            add("mas_2016_region", 2016, reg, pd.to_numeric(mas.iat[i, 2], errors="coerce"), reg_cases.get(reg))
            pops[reg] = pd.to_numeric(mas.iat[i, 1], errors="coerce")
    s3 = xl.parse("Sheet3", header=None)
    wk = sam.groupby(["region", "week"]).cases.sum()
    for i in range(1, len(s3)):
        reg = canon_region(s3.iat[i, 0])
        if not reg:
            continue
        diffs = [abs(pd.to_numeric(s3.iat[i, j], errors="coerce") - 1e5 * wk.get((reg, j), 0) / pops[reg])
                 for j in range(1, s3.shape[1]) if pd.notna(s3.iat[i, j])]
        add("mas_2016_rate", 2016, f"{reg} weekly rate, largest gap per 100k", 0, round(max(diffs), 3))
    s4 = xl.parse("Sheet4", header=None)
    fil = sam[sam.district == "Filingué"]
    fpop = fil.population.iloc[0]
    fw = fil.groupby("week").cases.sum()
    diffs = [abs(pd.to_numeric(s4.iat[1, j], errors="coerce") - 1e5 * fw.get(j, 0) / fpop)
             for j in range(1, s4.shape[1]) if pd.notna(s4.iat[1, j])]
    add("mas_2016_rate", 2016, "Filingué weekly rate, largest gap per 100k", 0, round(max(diffs), 3))

    # completeness: recompute the grid's national % per week
    cw = pd.read_csv(out_path("completeness_weekly.csv"))
    nat = pd.read_csv(out_path("completeness_national_reported.csv"))
    g = cw.groupby(["year", "week"])
    calc = pd.DataFrame({"timeliness": 100 * g.on_time.mean(), "completeness": 100 * g.received.mean()}).reset_index()
    m = nat.merge(calc, on=["year", "week"])
    for year, t in m.groupby("year"):
        t = t.dropna(subset=["timeliness_pct"])
        add("completeness_nat", year, "weekly timeliness %, largest gap", 0,
            round((t.timeliness_pct - t.timeliness).abs().max(), 3))
        add("completeness_nat", year, "weekly completeness %, largest gap", 0,
            round((t.completeness_pct - t.completeness).abs().max(), 3))

    # DHIS2 internal consistency
    dw = pd.read_csv(out_path("dhis2_2024_weekly.csv"))
    cum = pd.read_csv(out_path("dhis2_2024_cumulative.csv"))
    s = dw.groupby("disease")[["cases", "deaths"]].sum()
    c = cum.groupby("disease")[["cases", "deaths"]].sum()
    for dz in s.index:
        add("dhis2_cumul", 2024, f"{dz} cases", c.loc[dz, "cases"], s.loc[dz, "cases"])
    spare = pd.read_csv(out_path("dhis2_2024_spare_sheet.csv"))
    same = dw[dw.week == spare.week.iloc[0]].merge(spare, on=["district", "disease"], suffixes=("", "_spare"))
    add("dhis2_spare", 2024, f"Feuil2 vs week {spare.week.iloc[0]}, total cases", same.cases_spare.sum(), same.cases.sum())
    tot = pd.read_csv(out_path("dhis2_2024_totals.csv"))
    nat_t = tot[tot.level == "national"].groupby("disease").cases.sum()
    for dz in s.index:
        add("dhis2_totals", 2024, f"{dz} cases", nat_t.get(dz), s.loc[dz, "cases"])
    for dz, (cc, dd) in read_synthese(raw_path(DHIS2_FILE), "Synthèse").items():
        if dz in s.index:
            add("synthese", 2024, f"DHIS2 {dz} cases", cc, s.loc[dz, "cases"])

    # DHIS2 vs the 2024 workbook, weeks both cover
    wb = long[(long.year == 2024) & (long.week <= dw.week.max())].groupby(["disease", "week"]).cases.sum()
    dh = dw.groupby(["disease", "week"]).cases.sum()
    both = pd.concat([wb.rename("workbook_cases"), dh.rename("dhis2_cases")], axis=1).reset_index()
    both.to_csv(out_path("dhis2_vs_workbook_2024.csv"), index=False, encoding="utf-8")

    out = pd.DataFrame(CHECKS)
    out["diff"] = out.parsed - out.reference
    rel = (out["diff"].abs() / out.reference.abs().where(out.reference != 0)).fillna(0)
    out["status"] = "match"
    out.loc[out["diff"].abs() >= 0.5, "status"] = "within 1%"
    out.loc[(out["diff"].abs() >= 0.5) & (rel > 0.01), "status"] = "differs"
    out.loc[out.reference.isna(), "status"] = "no reference"
    out.to_csv(out_path("validation_checks.csv"), index=False, encoding="utf-8")
    pd.set_option("display.width", 200)
    print(out.groupby(["check", "status"]).size().unstack(fill_value=0))
    print(out[out.status == "differs"].to_string())


if __name__ == "__main__":
    main()
