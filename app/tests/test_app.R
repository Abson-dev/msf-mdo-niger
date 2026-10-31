# Renders every output of the app for several inputs. Run from the project root:
#   Rscript app/tests/test_app.R
setwd("app")
app <- source("app.R", local = TRUE)$value

outputs <- c(
  "overview_table", "overview_trends",
  "vb_cases", "vb_cases_sub", "vb_deaths", "vb_deaths_sub", "vb_cfr", "vb_inc", "vb_inc_sub", "disease_caveat",
  "channel", "annual_plot", "disease_map", "region_curve", "week_heat", "district_table",
  "men_epi_d", "men_alert_d", "men_epi_w", "men_peak", "men_peak_sub", "men_years", "men_curve", "men_heat_ui", "men_heat",
  "men_table",
  "rep_t", "rep_t_sub", "rep_c", "rep_c_sub", "rep_n", "rep_trend", "rep_map", "rep_heat_ui", "rep_heat", "rep_2024", "rep_dhis",
  "mat_n", "mat_i", "mat_i_sub", "mat_trend", "mat_map", "mat_weekly", "mat_table",
  "dh_table", "dh_weekly", "dh_map", "inventory", "checks"
)

shiny::testServer(app, {
  cases <- list(
    list(disease = "Rougeole", year = 2023, metric = "incidence_per_100k", men_year = 2024, rep_year = 2023, mat_year = 2021, dh_disease = "Choléra"),
    list(disease = "Méningite", year = 2015, metric = "deaths", men_year = 2015, rep_year = 2015, mat_year = 2015, dh_disease = "Rougeole"),
    list(disease = "Paludisme confirmé", year = 2024, metric = "cases", men_year = 2019, rep_year = 2020, mat_year = 2018, dh_disease = "Paludisme suspect"),
    # a disease not reported in the selected year, and a year with no meningitis alert
    list(disease = "Malnutrition sévère", year = 2023, metric = "incidence_per_100k", men_year = 2020, rep_year = 2017, mat_year = 2016, dh_disease = "Fièvre de la vallée du Rift"),
    list(disease = "Dengue", year = 2016, metric = "cases", men_year = 2018, rep_year = 2016, mat_year = 2019, dh_disease = "Dengue")
  )
  for (inp in cases) {
    do.call(session$setInputs, inp)
    for (o in outputs) {
      val <- tryCatch(output[[o]], error = function(e) stop(sprintf("%s failed for %s %s: %s", o, inp$disease, inp$year, conditionMessage(e))))
      # the caveat box is empty for diseases that have no caveat
      if (is.null(val) && o != "disease_caveat") stop(o, " returned NULL")
    }
    cat(sprintf("ok: %-20s %d | cases %s (%s) | meningitis %d: %s districts at epidemic level\n",
                inp$disease, inp$year, output$vb_cases, gsub("<[^>]+>", "", output$vb_cases_sub$html),
                inp$men_year, output$men_epi_d))
  }
})
cat("All", length(outputs), "outputs rendered for 5 input sets.\n")
