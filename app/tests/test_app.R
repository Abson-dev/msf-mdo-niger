# Renders every output of the app for several inputs. Run from the project root:
#   Rscript app/tests/test_app.R
setwd("app")
app <- source("app.R", local = TRUE)$value

outputs <- c("overview_table", "overview_trends", "vb_cases", "vb_deaths", "vb_cfr", "vb_peak", "annual_plot",
             "week_heat", "disease_map", "region_curve", "district_table", "rep_trend", "rep_map", "rep_heat",
             "rep_2024", "rep_dhis", "mat_trend", "mat_map", "mat_weekly", "mat_table", "dh_table", "dh_weekly",
             "dh_map", "inventory", "checks")

shiny::testServer(app, {
  cases <- list(
    list(disease = "Rougeole", year = 2023, metric = "incidence_per_100k", rep_year = 2023, mat_year = 2021, dh_disease = "Choléra"),
    list(disease = "Méningite", year = 2015, metric = "deaths", rep_year = 2015, mat_year = 2015, dh_disease = "Rougeole"),
    list(disease = "Paludisme confirmé", year = 2024, metric = "cases", rep_year = 2020, mat_year = 2018, dh_disease = "Paludisme suspect"),
    list(disease = "Malnutrition sévère", year = 2016, metric = "incidence_per_100k", rep_year = 2017, mat_year = 2016, dh_disease = "Fièvre de la vallée du Rift")
  )
  for (inp in cases) {
    do.call(session$setInputs, inp)
    for (o in outputs) {
      val <- tryCatch(output[[o]], error = function(e) stop(sprintf("%s failed for %s: %s", o, inp$disease, conditionMessage(e))))
      if (is.null(val)) stop(o, " returned NULL")
    }
    cat("ok:", inp$disease, inp$year, "| peak:", output$vb_peak, "\n")
  }
})
cat("All", length(outputs), "outputs rendered.\n")
