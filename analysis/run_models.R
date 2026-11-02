# Run every model and save the results used in the report.
#   conda activate mdo-models
#   Rscript analysis/run_models.R            (from the project root; about 15 minutes)
# Needs data/processed (built by scripts/run_all.py) and app/data/meningitis_district_week.csv.

t_start <- Sys.time()
source("analysis/R/00_setup.R")
for (f in c("01_nb_panel.R", "02_hurdle.R", "03_hhh4.R", "04_forecast.R", "05_reporting.R", "06_cfr.R", "07_outbreak.R")) {
  message("== ", f)
  source(file.path("analysis", "R", f))
}
saveRDS(RESULTS, file.path(OUT, "results.rds"))
writeLines(capture.output(sessionInfo()), file.path(OUT, "session_info.txt"))
message(sprintf("All models done in %.1f minutes.", as.numeric(difftime(Sys.time(), t_start, units = "mins"))))
