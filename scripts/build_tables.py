"""Build the aggregated tables the Shiny app reads, from data/processed/mdo_long.csv.

Output (data/processed/): mdo_years, mdo_annual, mdo_weekly, mdo_weekly_region, mdo_regional, mdo_district,
mdo_summary (.csv)
"""
import pandas as pd
from mdo_common import out_path


def rates(t):
    t["cases"] = t.cases.astype(int)
    t["deaths"] = t.deaths.astype(int)
    t["cfr_pct"] = (100 * t.deaths / t.cases).where(t.cases > 0).round(2)
    t["incidence_per_100k"] = (1e5 * t.cases / t.population).round(2)
    return t


def main():
    df = pd.read_csv(out_path("mdo_long.csv"))
    df["cases"] = df.cases.fillna(0)
    df["deaths"] = df.deaths.fillna(0)

    # trailing weeks with no report anywhere are empty template columns (2024 stops at week 43)
    wk = df.groupby(["year", "week"]).cases.sum()
    last_week = {y: int(s[s > 0].index.get_level_values(1).max()) for y, s in wk.groupby(level=0)}
    df = df[df.week <= df.year.map(last_week)]

    # population denominators: district populations as given on the measles sheet, week 1
    base = df[(df.disease == "Rougeole") & (df.week == 1)]
    dpop = base.groupby(["year", "district"]).population.sum().round().reset_index()
    rpop = base.groupby(["year", "region"]).population.sum().round().reset_index()
    npop = dpop.groupby("year").population.sum()

    ys = sorted(last_week)
    years = pd.DataFrame({
        "year": ys,
        "last_week": [last_week[y] for y in ys],
        "districts": [df[df.year == y].district.nunique() for y in ys],
        "population": [int(npop[y]) for y in ys],
    })
    years["complete"] = years.last_week >= 52

    annual = df.groupby(["disease", "year"])[["cases", "deaths"]].sum().reset_index()
    annual["population"] = annual.year.map(npop)
    annual = rates(annual)
    annual["partial_year"] = annual.year.map(dict(zip(years.year, ~years.complete)))

    weekly = df.groupby(["disease", "year", "week"])[["cases", "deaths"]].sum().reset_index()
    weekly[["cases", "deaths"]] = weekly[["cases", "deaths"]].astype(int)
    weekly_region = df.groupby(["disease", "year", "week", "region"])[["cases", "deaths"]].sum().reset_index()
    weekly_region[["cases", "deaths"]] = weekly_region[["cases", "deaths"]].astype(int)

    regional = rates(df.groupby(["disease", "year", "region"])[["cases", "deaths"]].sum().reset_index().merge(rpop, how="left"))
    district = rates(df.groupby(["disease", "year", "region", "district"])[["cases", "deaths"]].sum().reset_index()
                     .merge(dpop, how="left"))

    g = annual.groupby("disease")
    summary = pd.DataFrame({
        "years_reported": g.year.count(), "first_year": g.year.min(), "last_year": g.year.max(),
        "total_cases": g.cases.sum(), "total_deaths": g.deaths.sum(),
    }).reset_index()
    summary["cfr_pct"] = (100 * summary.total_deaths / summary.total_cases).where(summary.total_cases > 0).round(2)
    peak = annual.loc[annual.groupby("disease").cases.idxmax(), ["disease", "year", "cases"]]
    summary = summary.merge(peak.rename(columns={"year": "peak_year", "cases": "peak_cases"}))
    summary = summary.sort_values("total_cases", ascending=False)

    for name, t in [("years", years), ("annual", annual), ("weekly", weekly), ("weekly_region", weekly_region),
                    ("regional", regional), ("district", district), ("summary", summary)]:
        t.to_csv(out_path(f"mdo_{name}.csv"), index=False, encoding="utf-8")
        print(f"mdo_{name}.csv", t.shape)


if __name__ == "__main__":
    main()
