# Shared setup for the models: packages, data, panel construction, helpers.
# Run from the project root (scripts are sourced by analysis/run_models.R).

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(ggplot2); library(scales)
})

PROC <- file.path("data", "processed")
OUT <- file.path("analysis", "output")
dir.create(file.path(OUT, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(OUT, "figures"), recursive = TRUE, showWarnings = FALSE)
rd <- function(f) read_csv(file.path(PROC, f), show_col_types = FALSE, locale = locale(encoding = "UTF-8"))

PERIOD <- 52.18          # mean length of an epidemiological year in weeks
INK <- "#1d2733"; PRIMARY <- "#0b5e7e"; WARM <- "#d98c10"; DANGER <- "#b03a2e"

DISEASE_EN <- c("Paludisme confirmé" = "Malaria (confirmed)", "Paludisme suspect" = "Malaria (suspected)",
                "Rougeole" = "Measles", "Méningite" = "Meningitis", "Choléra" = "Cholera",
                "Diphtérie" = "Diphtheria", "Coqueluche" = "Pertussis",
                "Malnutrition sévère" = "Severe acute malnutrition")
en <- function(x) unname(ifelse(x %in% names(DISEASE_EN), DISEASE_EN[x], x))

years_tbl <- rd("mdo_years.csv")
regions_of <- rd("district_regions.csv")

# ---- district-week panel, 2017-2024 (72 districts, stable boundaries) --------------------------
long <- rd("mdo_long.csv") |>
  inner_join(years_tbl |> select(year, last_week), by = "year") |>
  filter(week <= last_week, year >= 2017) |>
  select(-last_week)

# weeks whose district report was not received are unknown, not zero (grid available 2018-2023)
missing_reports <- rd("completeness_weekly.csv") |> filter(status == "N") |> select(year, week, district)
long <- long |>
  left_join(missing_reports |> mutate(not_received = TRUE), by = c("year", "week", "district")) |>
  mutate(cases = ifelse(!is.na(not_received), NA, cases), deaths = ifelse(!is.na(not_received), NA, deaths)) |>
  select(-not_received)

# continuous week index from week 1 of 2017, and Fourier terms
week_index <- long |> distinct(year, week) |> arrange(year, week) |> mutate(t = row_number())
# Fourier terms s1, c1, ..., sK, cK for week-of-year w (equation 7 of the methodology note)
fourier <- function(w, K = 2) {
  out <- do.call(cbind, lapply(seq_len(K), function(k) cbind(sin(2 * pi * k * w / PERIOD), cos(2 * pi * k * w / PERIOD))))
  colnames(out) <- paste0(rep(c("s", "c"), K), rep(seq_len(K), each = 2))
  out
}

# One denominator for every disease: total district population as listed on the measles sheet (complete in
# every year). The disease sheets are not consistent: severe malnutrition uses the under-5 population from 2019
# and none before, confirmed malaria has none for 2017-2020, AFP and neonatal tetanus use target populations.
pop_total <- long |> filter(disease == "Rougeole", week == 1) |> distinct(year, district, pop_total = population)

panel_for <- function(dz) {
  d <- long |> filter(disease == dz) |> left_join(week_index, by = c("year", "week")) |>
    left_join(pop_total, by = c("year", "district")) |>
    mutate(population = pop_total) |> select(-pop_total) |>
    arrange(district, t) |>
    group_by(district) |>
    mutate(lag1 = lag(cases)) |>
    ungroup() |>
    mutate(log_exposure = log(population / 1e5), year_f = factor(year))
  # cases last week in the other districts of the same region, and in the rest of Niger
  reg <- d |> group_by(region, t) |> summarise(reg_cases = sum(cases, na.rm = TRUE), .groups = "drop")
  nat <- d |> group_by(t) |> summarise(nat_cases = sum(cases, na.rm = TRUE), .groups = "drop")
  d <- d |>
    left_join(reg |> mutate(t = t + 1) |> rename(reg_lag1 = reg_cases), by = c("region", "t")) |>
    left_join(nat |> mutate(t = t + 1) |> rename(nat_lag1 = nat_cases), by = "t") |>
    mutate(reg_other_lag1 = reg_lag1 - coalesce(lag1, 0), rest_lag1 = nat_lag1 - reg_lag1)
  bind_cols(d, as.data.frame(fourier(d$week)))
}

# ---- helpers --------------------------------------------------------------------------------------
fmt <- function(x, d = 2) formatC(x, format = "f", digits = d, big.mark = ",")
fmt_ci <- function(est, lo, hi, d = 2) sprintf("%s (%s–%s)", fmt(est, d), fmt(lo, d), fmt(hi, d))
p_fmt <- function(p) ifelse(p < 0.001, "<0.001", formatC(p, format = "f", digits = 3))

# write a table both as CSV and as a pandoc pipe table (for the report)
save_table <- function(df, name, align = NULL) {
  write_csv(df, file.path(OUT, "tables", paste0(name, ".csv")))
  if (is.null(align)) align <- ifelse(vapply(df, is.numeric, TRUE), "r", "l")
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(ifelse(align == "r", "---:", "---"), collapse = "|"), "|")
  body <- apply(df, 1, function(r) paste0("| ", paste(ifelse(is.na(r), "–", r), collapse = " | "), " |"))
  writeLines(c(header, sep, body), file.path(OUT, "tables", paste0(name, ".md")), useBytes = TRUE)
  invisible(df)
}

save_fig <- function(p, name, w = 6.5, h = 3.6) {
  ggsave(file.path(OUT, "figures", paste0(name, ".png")), p, width = w, height = h, dpi = 200, bg = "white")
}

theme_report <- function() {
  theme_minimal(base_size = 9.5) +
    theme(panel.grid.minor = element_blank(), strip.text = element_text(face = "bold", hjust = 0),
          plot.title = element_text(face = "bold", size = 10), legend.position = "bottom")
}

# key results collected across scripts, written to analysis/output/results.json at the end
RESULTS <- list()
