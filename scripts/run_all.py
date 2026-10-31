"""Run the whole pipeline: raw workbooks -> data/processed/. Usage: python scripts/run_all.py"""
import importlib

STEPS = ["parse_diseases", "parse_completeness", "parse_maternal", "parse_dhis2", "validate", "build_tables",
         "build_geo", "build_app_data"]

if __name__ == "__main__":
    for step in STEPS:
        print(f"== {step}")
        importlib.import_module(step).main()
