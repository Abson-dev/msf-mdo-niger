# Data (not in this repository)

The data belong to the Ministry of Public Health of Niger and are not stored on GitHub. Get them from the project team and put them in these folders before running the pipeline or the dashboard:

```
data/
├── raw/
│   ├── MDO_Niger Semaine_2015-53.xls
│   ├── MDO_Niger Semaine_52 2016.xls
│   ├── MDO_Niger Semaine_2017-52.xls
│   ├── MDO_Niger Semaines 1 à 52 2018.xls
│   ├── MDO_Niger Semaine 52 2019.xlsx
│   ├── MDO_Niger Semaine 53 2020.xls
│   ├── MDO_Niger Semaine 52 2021.xlsx
│   ├── MDO_NIGER 2022 S52.xlsx
│   ├── MDO 2023 S52.xls
│   ├── MDO 2024 S43.xls
│   └── MDO_S1-S37_2024_Extrait_DHIS2-18-09-24.xls
└── shp/
    └── NER_admbnda_adm1_IGNN_20230720.*   (.shp, .shx, .dbf, .prj and the other parts)
```

The file names must match: [`scripts/mdo_common.py`](../scripts/mdo_common.py) lists them. Then run `rebuild_data.bat` (or `python scripts/run_all.py`), which writes `data/processed/` and `app/data/`. `run_app.bat` does this automatically the first time.

`data/raw/`, `data/shp/`, `data/processed/` and `app/data/` are listed in `.gitignore`, so git will not pick them up. [`data_inventory.csv`](data_inventory.csv) describes what each file and sheet contains; it holds no data.
