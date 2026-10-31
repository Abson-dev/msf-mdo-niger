# Niger MDO surveillance, 2015–2024

Weekly notifiable-disease surveillance data for Niger (*Maladies à Déclaration Obligatoire*, IDSR), cleaned into tidy tables and explored in an R Shiny dashboard.

Every source file and sheet is used. [`data/data_inventory.csv`](data/data_inventory.csv) lists what each one contributes.

| Source | Content | Used for |
|---|---|---|
| 10 yearly MDO workbooks (`data/raw`) | Weekly cases and deaths per health district, one sheet per disease | All disease tabs |
| Completeness sheets in each workbook | Weekly report status per district (on time / late / not received) | Reporting tab |
| Maternal death sheets (2015–2021) | Weekly maternal deaths notified and investigated per district | Maternal deaths tab |
| DHIS2 extract, 2024 weeks 1–37 | Weekly district cases, deaths, completeness | DHIS2 2024 tab, 2024 completeness |
| Summary sheets (*Synthèse*, *analyse mas*, *Cumul*) | Totals derived by the ministry | Cross-checks |
| Region shapefile (`data/shp`, IGNN 2023) | Admin-1 boundaries | Maps |

## Setup

Everything runs in one Miniforge environment with Python (data processing) and R (dashboard):

```powershell
conda env create -f environment.yml
conda activate mdo-niger
```

## Rebuild the data

```powershell
python scripts/run_all.py
```

This reads `data/raw` and `data/shp` and writes `data/processed`. The processed tables are committed, so this step is only needed after the raw files change.

| Script | Output |
|---|---|
| `parse_diseases.py` | `mdo_long.csv`: one row per year, week, district and disease |
| `parse_completeness.py` | `completeness_weekly.csv`, `completeness_2024_cumulative.csv` |
| `parse_maternal.py` | `maternal_deaths.csv` |
| `parse_dhis2.py` | `dhis2_2024_weekly.csv` and the extract's own totals |
| `validate.py` | `validation_checks.csv`, `dhis2_vs_workbook_2024.csv` |
| `build_tables.py` | `mdo_annual.csv`, `mdo_weekly.csv`, `mdo_regional.csv`, `mdo_district.csv`, … |
| `build_geo.py` | `regions.geojson` from the shapefile |

## Run the dashboard

```powershell
Rscript -e "shiny::runApp('app', launch.browser = TRUE)"
```

Tabs: **Overview**, **Disease explorer** (trend, weekly heatmap, region map, district ranking), **Reporting** (timeliness and completeness), **Maternal deaths**, **DHIS2 2024** (extract vs workbook), **Data & checks**.

Test that every output renders: `Rscript app/tests/test_app.R`.

## What was cleaned

- Region cells left blank for new districts are filled in; district spellings are harmonised to 72 districts (73 names including the pre-2017 Tahoua).
- Confirmed malaria 2015–2020 is read from the testing layout (positive rapid tests or slides).
- 2015–16 meningitis rows that repeat a parent district (`DOUTCHI DS`, `GAYA DS`) are removed.

## Checks

`validation_checks.csv` compares the parsed numbers with every total written in the source files. 173 of 197 disease-year totals match the sheets' own total rows exactly, and most of the rest are within 1%. Where they differ, the sheet's total row is usually what is wrong. In the 2019 influenza sheet, for example, the districts add up to 14 but the total cell says 127. The DHIS2 *Synthèse* sheet is older than the extract's weekly sheets.

## Caveats

- 2024 stops at week 43 (workbook) and week 37 (DHIS2).
- Districts were reorganised in 2017 (44–48 before, 72 after). Regions are comparable across all years; districts only from 2017.
- Confirmed malaria changes definition in 2021; malaria deaths move from *suspected* to *confirmed* the same year.
- Suspected malaria in 2018 looks incomplete.
- Malnutrition is reported until 2021; maternal deaths until 2021; malaria in pregnant women is missing in 2020–2021.

Data: Ministry of Public Health of Niger, weekly MDO reports. This repository is private; check with the data owner before sharing it.
