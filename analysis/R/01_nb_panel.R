# Over-dispersion tests and negative binomial panel models (methodology sections 3.1-3.4)
#   log mu_it = log e_it + alpha_i + tau_year + s(week), district fixed effects, district-clustered SEs
suppressPackageStartupMessages(library(fixest))

nb_diseases <- c("Paludisme confirmé", "Paludisme suspect", "Malnutrition sévère", "Rougeole", "Méningite",
                 "Choléra", "Diphtérie", "Coqueluche")

seasonal_profile <- function(b) {
  w <- 1:52
  s <- b["s1"] * sin(2 * pi * w / PERIOD) + b["c1"] * cos(2 * pi * w / PERIOD) +
    b["s2"] * sin(4 * pi * w / PERIOD) + b["c2"] * cos(4 * pi * w / PERIOD)
  list(peak_week = w[which.max(s)], trough_week = w[which.min(s)], ratio = exp(max(s) - min(s)), s = s)
}

disp_rows <- list(); nb_rows <- list(); year_rows <- list(); season_rows <- list()

for (dz in nb_diseases) {
  d <- panel_for(dz)
  if (dz == "Paludisme suspect") d <- d |> filter(year != 2018)          # incomplete year
  if (dz == "Malnutrition sévère") d <- d |> filter(year <= 2021)        # series ends in 2021
  d <- d |> filter(!is.na(cases), population > 0)
  fml <- cases ~ i(year_f, ref = "2017") + s1 + c1 + s2 + c2 | district

  pois <- fepois(fml, data = d, offset = ~log_exposure, cluster = ~district)
  nb <- fenegbin(fml, data = d, offset = ~log_exposure, cluster = ~district)

  # Cameron-Trivedi test on the Poisson fit: ((y - mu)^2 - y) / mu = delta * mu + e
  used <- d[obs(pois), ]
  mu <- fitted(pois)
  aux <- ((used$cases - mu)^2 - used$cases) / mu
  ct <- lm(aux ~ 0 + mu)
  ct_t <- coef(ct)[[1]] / sqrt(sandwich::vcovHC(ct, type = "HC1")[1, 1])
  disp_rows[[dz]] <- tibble(Disease = en(dz), `District-weeks` = nobs(pois),
                            `Variance ÷ mean` = var(used$cases) / mean(used$cases),
                            `CT delta` = coef(ct)[[1]], `CT t-statistic` = ct_t,
                            `NB theta` = nb$theta,
                            `Log-lik. Poisson` = as.numeric(logLik(pois)), `Log-lik. NB` = as.numeric(logLik(nb)))

  b <- coef(nb)
  sp <- seasonal_profile(b)
  yrs <- grep("^year_f::", names(b), value = TRUE)
  ci_nb <- confint(nb)
  ci_p <- confint(pois)
  year_rows[[dz]] <- tibble(disease = en(dz), year = as.integer(sub("year_f::", "", yrs)),
                            irr = exp(b[yrs]), lo = exp(ci_nb[yrs, 1]), hi = exp(ci_nb[yrs, 2]),
                            irr_ppml = exp(coef(pois)[yrs]), lo_ppml = exp(ci_p[yrs, 1]), hi_ppml = exp(ci_p[yrs, 2]))
  last <- tail(yrs, 1)
  nb_rows[[dz]] <- tibble(Disease = en(dz), Years = paste0(min(d$year), "–", max(d$year)),
                          Districts = length(unique(used$district)), `District-weeks` = nobs(nb),
                          `Peak week` = sp$peak_week, `Peak ÷ trough` = sp$ratio,
                          `IRR last year vs 2017` = fmt_ci(exp(b[last]), exp(ci_nb[last, 1]), exp(ci_nb[last, 2])),
                          `Last year` = as.integer(sub("year_f::", "", last)),
                          `NB theta` = nb$theta)
  season_rows[[dz]] <- tibble(disease = en(dz), week = 1:52, effect = exp(sp$s - mean(sp$s)))
  cat(sprintf("NB %-22s n=%6d theta=%.3f peak=%d ratio=%.1f CT t=%.1f\n", en(dz), nobs(nb), nb$theta,
              sp$peak_week, sp$ratio, ct_t))
}

disp <- bind_rows(disp_rows)
save_table(disp |> transmute(Disease, `District-weeks` = fmt(`District-weeks`, 0),
                             `Variance ÷ mean` = fmt(`Variance ÷ mean`, 0),
                             `Cameron–Trivedi δ` = fmt(`CT delta`, 3), `t-statistic` = fmt(`CT t-statistic`, 1),
                             `NB θ` = fmt(`NB theta`, 3),
                             `LR statistic NB vs Poisson` = fmt(2 * (`Log-lik. NB` - `Log-lik. Poisson`), 0)),
           "t01_overdispersion")

nbres <- bind_rows(nb_rows)
# a near-zero trough (no cases at all out of season) makes the ratio meaningless above ~1,000
# district-weeks and theta are in the over-dispersion table; the last year is in the column name
save_table(nbres |> mutate(`Peak ÷ trough` = ifelse(`Peak ÷ trough` > 1000, "> 1,000", fmt(`Peak ÷ trough`, 1)),
                           Years = gsub("–", "–⁠", Years)) |>
             transmute(Disease, Years, Districts, `Peak week`, `Peak ÷ trough`,
                       `IRR in last year vs 2017 (95% CI)` = paste0(`IRR last year vs 2017`, ifelse(`Last year` == 2024, "", " [2021]"))),
           "t02_nb_summary")

yr <- bind_rows(year_rows)
write_csv(yr, file.path(OUT, "tables", "t03_year_irr_long.csv"))
# robustness: NB vs PPML year effects
rob <- yr |> group_by(disease) |>
  summarise(`Years compared` = n(), `Largest difference in log IRR, NB vs PPML` = max(abs(log(irr) - log(irr_ppml))),
            `Correlation of year effects` = cor(log(irr), log(irr_ppml)), .groups = "drop")
save_table(rob |> mutate(across(where(is.numeric) & !`Years compared`, ~fmt(.x, 3))) |> rename(Disease = disease),
           "t04_nb_vs_ppml")

# figure: year effects relative to 2017 (NB, 95% CI), log scale. Cholera is left out: years without any case
# have effects tending to zero, which says nothing beyond "no outbreak that year".
ord <- en(nb_diseases)
p <- ggplot(yr |> filter(disease != "Cholera") |> mutate(disease = factor(disease, setdiff(ord, "Cholera"))), aes(year, irr)) +
  geom_hline(yintercept = 1, colour = "grey60", linewidth = 0.4) +
  geom_ribbon(aes(ymin = lo, ymax = hi), fill = PRIMARY, alpha = 0.18) +
  geom_line(colour = PRIMARY, linewidth = 0.7) + geom_point(colour = PRIMARY, size = 1.2) +
  scale_y_log10(labels = label_number(accuracy = 0.1)) +
  scale_x_continuous(breaks = c(2018, 2020, 2022, 2024)) +
  facet_wrap(~disease, ncol = 4, scales = "free_y", labeller = label_wrap_gen(22)) +
  labs(x = NULL, y = "Incidence rate ratio vs 2017 (log scale)") + theme_report()
save_fig(p, "f01_year_effects", h = 4)

# figure: estimated seasonal profile (multiplicative effect relative to the annual mean)
p <- ggplot(bind_rows(season_rows) |> mutate(disease = factor(disease, ord)), aes(week, effect)) +
  geom_hline(yintercept = 1, colour = "grey60", linewidth = 0.4) +
  geom_line(colour = PRIMARY, linewidth = 0.8) +
  scale_y_log10(labels = function(x) format(x, scientific = FALSE, drop0trailing = TRUE, trim = TRUE)) +
  scale_x_continuous(breaks = c(1, 13, 26, 39, 52)) +
  facet_wrap(~disease, ncol = 4, scales = "free_y", labeller = label_wrap_gen(22)) +
  labs(x = "Epidemiological week", y = "Seasonal rate ratio (log scale)") + theme_report()
save_fig(p, "f02_seasonality", h = 4)

# regional seasonality: harmonics interacted with region (K = 1), malaria, meningitis, measles
reg_rows <- list()
for (dz in c("Paludisme confirmé", "Méningite", "Rougeole")) {
  d <- panel_for(dz) |> filter(!is.na(cases))
  m <- fenegbin(cases ~ i(year_f, ref = "2017") + i(region, s1) + i(region, c1) | district, data = d,
                offset = ~log_exposure, cluster = ~district)
  b <- coef(m)
  for (r in sort(unique(d$region))) {
    g <- b[paste0("region::", r, ":s1")]; h <- b[paste0("region::", r, ":c1")]
    pk <- (atan2(g, h) * PERIOD / (2 * pi)) %% PERIOD
    reg_rows[[paste(dz, r)]] <- tibble(disease = en(dz), region = r, peak_week = pk,
                                       ratio = exp(2 * sqrt(g^2 + h^2)))
  }
}
regs <- bind_rows(reg_rows)
# peak week only: with one harmonic, the peak/trough ratio explodes where off-season counts are near zero
save_table(regs |> mutate(cell = fmt(peak_week, 0)) |>
             select(region, disease, cell) |> pivot_wider(names_from = disease, values_from = cell) |>
             rename(Region = region),
           "t05_regional_seasonality")

RESULTS$nb <- list(disp = disp, summary = nbres, years = yr, regional = regs)
