# Outbreak detection with the improved Farrington algorithm (Noufaily et al., 2013), methodology section 11
#   National weekly series; alarms for 2022 week 1 to 2024 week 43, reference values from the previous 5 years.
suppressPackageStartupMessages(library(surveillance))

nat <- rd("mdo_weekly.csv") |> inner_join(years_tbl |> select(year, last_week), by = "year") |>
  filter(week <= last_week) |> arrange(year, week)
od_diseases <- c("Méningite", "Rougeole", "Choléra", "Diphtérie")
alarm_rows <- list(); plot_rows <- list()

for (dz in od_diseases) {
  s <- nat |> filter(disease == dz)
  # consecutive weekly dates from the Monday starting week 1 of 2015, so 53-week years stay aligned
  dates <- as.Date("2014-12-29") + 7 * (seq_len(nrow(s)) - 1)
  st <- sts(observed = matrix(s$cases, ncol = 1), epoch = as.numeric(dates), epochAsDate = TRUE, frequency = 52)
  rng <- which(s$year >= 2022)
  ctrl <- list(range = rng, b = 5, w = 3, noPeriods = 10, pastWeeksNotIncluded = 26, alpha = 0.01,
               thresholdMethod = "nbPlugin", populationOffset = FALSE, weightsThreshold = 2.58, glmWarnings = FALSE)
  res <- farringtonFlexible(st, control = ctrl)
  out <- tibble(disease = en(dz), year = s$year[rng], week = s$week[rng], date = dates[rng],
                observed = as.vector(observed(res)), threshold = as.vector(upperbound(res)),
                alarm = as.vector(alarms(res)))
  plot_rows[[dz]] <- out
  alarm_rows[[dz]] <- out |> group_by(disease, year) |>
    summarise(weeks = n(), alarms = sum(alarm, na.rm = TRUE),
              first = if (any(alarm, na.rm = TRUE)) min(week[alarm %in% TRUE]) else NA_integer_,
              last = if (any(alarm, na.rm = TRUE)) max(week[alarm %in% TRUE]) else NA_integer_, .groups = "drop")
}
al <- bind_rows(alarm_rows)
save_table(al |> transmute(Disease = disease, Year = as.character(year), `Weeks monitored` = weeks, `Alarm weeks` = alarms,
                           `First alarm week` = ifelse(is.na(first), "–", as.character(first)),
                           `Last alarm week` = ifelse(is.na(last), "–", as.character(last))),
           "t16_outbreak_alarms")

# agreement with the WHO district thresholds for meningitis: weeks with >= 1 district at epidemic level
who <- read_csv(file.path("app", "data", "meningitis_district_week.csv"), show_col_types = FALSE) |>
  filter(year >= 2022) |> group_by(year, week) |> summarise(who_epidemic = any(status == "epidemic"), .groups = "drop")
men <- plot_rows[["Méningite"]] |> left_join(who, by = c("year", "week"))
agree <- men |> summarise(who_weeks = sum(who_epidemic, na.rm = TRUE),
                          farrington_weeks = sum(alarm, na.rm = TRUE),
                          both = sum(who_epidemic & alarm, na.rm = TRUE))

pd <- bind_rows(plot_rows) |> mutate(disease = factor(disease, en(od_diseases)))
p <- ggplot(pd, aes(date)) +
  geom_col(aes(y = observed, fill = alarm), width = 6) +
  geom_step(aes(y = threshold), colour = INK, linewidth = 0.45, direction = "mid") +
  scale_fill_manual(values = c(`FALSE` = "#9ec5d6", `TRUE` = DANGER), labels = c("No alarm", "Alarm"), name = NULL) +
  facet_wrap(~disease, ncol = 1, scales = "free_y") +
  labs(x = NULL, y = "Weekly cases, Niger", caption = "Line: alarm threshold (upper 99% limit of expected cases).") +
  theme_report()
save_fig(p, "f09_outbreak_detection", h = 5.6)

RESULTS$outbreak <- list(alarms = al, meningitis_vs_who = agree)
cat("outbreak detection done\n")
