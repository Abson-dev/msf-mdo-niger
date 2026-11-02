# Changelog

## 1.2.0 (2026-11-02)

- Data removed from the repository and its history; `data/raw`, `data/shp`, `data/processed` and `app/data` are git-ignored. `data/README.md` lists the files to obtain and where to put them.
- `run_app.bat` builds the dashboard data on first run when it is missing.

## 1.1.0 (2026-10-31)

- Windows launchers: `run_app.bat` (start the dashboard) and `rebuild_data.bat` (rebuild the data and test the app).
- Dashboard reworked for an international audience: English labels, key findings, weekly comparison with previous years, WHO meningitis thresholds by district and week, colour-blind-safe palette, PNG and CSV/Excel export, links to individual tabs, methods page, map disclaimer.
- `app/` is self-contained (`app/data/`) and can be deployed on its own.
- Fixed the map drawing (polygon winding).
- Added the data dictionary and README screenshots.

## 1.0.0 (2026-10-30)

- Data pipeline for all ten yearly MDO workbooks, completeness sheets, maternal death sheets, the 2024 DHIS2 extract and the region shapefile.
- Cross-checks against every total written in the source files.
- First Shiny dashboard and Miniforge environment.
