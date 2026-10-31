# Data dictionary

All tables are UTF-8 CSV files in `data/processed/`, written by `scripts/run_all.py`. Disease names are the French labels used in the source workbooks (the dashboard shows English names). Weeks are epidemiological weeks as numbered in the source files; a year has 52 or 53.

Region and district names are harmonised across years: 8 regions and 72 health districts, plus `Tahoua` for the single Tahoua district that existed before the 2017 split. `district_regions.csv` maps each district to its region.

## Disease surveillance

### `mdo_long.csv`: the full table

One row per year, week, district and disease (679,126 rows). Everything else on this page is built from it.

| Column | Description |
|---|---|
| `year`, `week` | Reporting year and epidemiological week |
| `region`, `district` | Harmonised names |
| `population` | District population written on that disease sheet for that year |
| `disease` | French disease label |
| `cases`, `deaths` | Weekly counts; empty where the sheet has no value (weeks not yet reported) |
| `tested` | Confirmed malaria 2015–2020 only: rapid tests or slides done. `cases` is then the number positive |

### Aggregates

| File | One row per | Columns |
|---|---|---|
| `mdo_annual.csv` | disease, year | `cases`, `deaths`, `population` (national), `cfr_pct`, `incidence_per_100k`, `partial_year` (TRUE for 2024) |
| `mdo_weekly.csv` | disease, year, week | `cases`, `deaths` (national) |
| `mdo_weekly_region.csv` | disease, year, week, region | `cases`, `deaths` |
| `mdo_regional.csv` | disease, year, region | `cases`, `deaths`, `population`, `cfr_pct`, `incidence_per_100k` |
| `mdo_district.csv` | disease, year, district | `region`, `cases`, `deaths`, `population`, `cfr_pct`, `incidence_per_100k` |
| `mdo_summary.csv` | disease | `years_reported`, `first_year`, `last_year`, `total_cases`, `total_deaths`, `cfr_pct`, `peak_year`, `peak_cases` |
| `mdo_years.csv` | year | `last_week` reported, number of `districts`, national `population`, `complete` (FALSE for 2024) |

`cfr_pct` = 100 × deaths ÷ cases. `incidence_per_100k` = 100,000 × cases ÷ population, with the district populations from the measles sheet of each year. Aggregates stop at each year's last reported week.

## Reporting completeness and timeliness

| File | Description |
|---|---|
| `completeness_weekly.csv` | 2015–2023, one row per year, week and district: `status` T (on time), L (late) or N (not received); `received` and `on_time` as 0/1 |
| `completeness_national_reported.csv` | The national weekly `timeliness_pct` and `completeness_pct` written in the source grids (used as a check) |
| `completeness_2024_cumulative.csv` | 2024 cumulative `completeness_pct` and `timeliness_pct` to `through_week`, at `level` district, region or national |

## Maternal deaths

`maternal_deaths.csv`: 2015–2021, one row per year, week and district.

| Column | Description |
|---|---|
| `live_births` | Expected live births (2015 and 2016 sheets only) |
| `deaths_notified` | Maternal deaths notified that week |
| `deaths_investigated` | Of those, deaths investigated by a maternal death audit (not recorded in 2015) |

## DHIS2 extract, 2024 weeks 1–37

| File | Description |
|---|---|
| `dhis2_2024_weekly.csv` | One row per week, district and disease: `population`, facility `completeness_pct` and `timeliness_pct`, `cases`, `deaths` |
| `dhis2_2024_totals.csv` | The extract's own region and national rows (`level`, `name`) |
| `dhis2_2024_cumulative.csv` | The extract's "Cumul S1-S37" sheet, district rows |
| `dhis2_2024_spare_sheet.csv` | The extract's "Feuil2" sheet: a second copy of week 35 |
| `dhis2_vs_workbook_2024.csv` | National weekly cases per disease in the 2024 workbook (`workbook_cases`) and in DHIS2 (`dhis2_cases`) |

## Checks

| File | Description |
|---|---|
| `check_sheet_totals.csv` | Parsed yearly total per disease vs the grand-total row of each source sheet |
| `validation_checks.csv` | Every cross-check (`check`, `year`, `item`, `reference` from the source, `parsed`, `diff`, `status`: match, within 1%, differs, no reference) |

## Map

`regions.geojson`: Niger's 8 regions (admin level 1) from the IGNN 2023 shapefile in `data/shp/`, WGS84, property `region`. Rings keep the shapefile's clockwise winding, which plotly requires.

## App data

`app/data/` holds copies of the tables the dashboard reads, plus three built only for it:

| File | Description |
|---|---|
| `meningitis_district_week.csv` | Weekly meningitis `cases`, `rate_per_100k` and WHO threshold `status` (below, alert, epidemic) per district |
| `dhis2_cases_region_week.csv` | DHIS2 2024 cases and deaths by disease, week and region |
| `dhis2_completeness_region_week.csv` | DHIS2 2024 mean facility completeness by week and region |
