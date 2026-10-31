"""Write the slim, self-contained data folder the Shiny app ships with (app/data/), so app/ can be deployed alone.

Copies the aggregated tables from data/processed and adds:
  meningitis_district_week.csv  district weekly meningitis rates and WHO threshold status
  dhis2_cases_region_week.csv   DHIS2 2024 cases and deaths by region, disease and week
  dhis2_completeness_region_week.csv  DHIS2 2024 mean facility completeness by region and week
"""
import os
import shutil
import pandas as pd
from mdo_common import ROOT, out_path

APP_DATA = os.path.join(ROOT, "app", "data")

COPY = ["mdo_years.csv", "mdo_annual.csv", "mdo_weekly.csv", "mdo_weekly_region.csv", "mdo_regional.csv",
        "mdo_district.csv", "mdo_summary.csv", "completeness_weekly.csv", "completeness_2024_cumulative.csv",
        "maternal_deaths.csv", "validation_checks.csv", "dhis2_vs_workbook_2024.csv", "regions.geojson"]

# WHO meningitis thresholds (2014 guideline), applied to whole districts:
# population >= 30,000: alert 3 and epidemic 10 cases per 100,000 per week; smaller: alert 2 and epidemic 5 cases per week
POP_CUTOFF, ALERT_RATE, EPIDEMIC_RATE, ALERT_CASES, EPIDEMIC_CASES = 30_000, 3, 10, 2, 5


def meningitis(years):
    df = pd.read_csv(out_path("mdo_long.csv"))
    m = df[df.disease == "Méningite"].copy()
    m = m[m.week <= m.year.map(years.set_index("year").last_week)]
    m["cases"] = m.cases.fillna(0).astype(int)
    measles_pop = (df[(df.disease == "Rougeole") & (df.week == 1)]
                   .set_index(["year", "district"]).population.groupby(level=[0, 1]).first())
    fill = pd.Series(list(zip(m.year, m.district)), index=m.index).map(measles_pop)
    m["population"] = m.population.fillna(fill)
    m["rate_per_100k"] = (1e5 * m.cases / m.population).round(2)
    big = m.population >= POP_CUTOFF
    epi = (big & (m.rate_per_100k >= EPIDEMIC_RATE)) | (~big & (m.cases >= EPIDEMIC_CASES))
    alert = (big & (m.rate_per_100k >= ALERT_RATE)) | (~big & (m.cases >= ALERT_CASES))
    m["status"] = "below"
    m.loc[alert, "status"] = "alert"
    m.loc[epi, "status"] = "epidemic"
    return m[["year", "week", "region", "district", "population", "cases", "rate_per_100k", "status"]]


def main():
    os.makedirs(APP_DATA, exist_ok=True)
    for f in COPY:
        shutil.copy2(out_path(f), os.path.join(APP_DATA, f))
    shutil.copy2(os.path.join(ROOT, "data", "data_inventory.csv"), os.path.join(APP_DATA, "data_inventory.csv"))

    years = pd.read_csv(out_path("mdo_years.csv"))
    men = meningitis(years)
    men.to_csv(os.path.join(APP_DATA, "meningitis_district_week.csv"), index=False, encoding="utf-8")

    dh = pd.read_csv(out_path("dhis2_2024_weekly.csv"))
    dh.groupby(["disease", "week", "region"])[["cases", "deaths"]].sum().reset_index() \
        .to_csv(os.path.join(APP_DATA, "dhis2_cases_region_week.csv"), index=False, encoding="utf-8")
    dh.drop_duplicates(["week", "district"]).groupby(["week", "region"]).completeness_pct.mean().round(1) \
        .reset_index().to_csv(os.path.join(APP_DATA, "dhis2_completeness_region_week.csv"), index=False, encoding="utf-8")

    print(men.groupby("year").status.value_counts().unstack(fill_value=0))
    total = sum(os.path.getsize(os.path.join(APP_DATA, f)) for f in os.listdir(APP_DATA))
    print(f"app/data: {len(os.listdir(APP_DATA))} files, {total / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
