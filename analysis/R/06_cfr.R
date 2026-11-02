# Case fatality by region (methodology section 10.3)
#   Quasi-binomial regression on district-year counts:  logit E[deaths/cases] = region + year,
#   weights = cases, Var = phi * binomial variance (phi estimated: over-dispersion).
#   F-test: do regions differ once years are accounted for?  Region CFRs are standardised to the national
#   case mix (each district-year predicted with the region switched), with parametric-bootstrap intervals.
#   Regions without any death cannot be estimated (separation) and are reported as crude counts.
# A mixed model with district and observation-level random effects (lme4) was also fitted; it puts the
# between-region variance at zero for meningitis, measles and diphtheria (see the report).

cfr_diseases <- c("Méningite", "Rougeole", "Choléra", "Diphtérie")
pred_rows <- list(); fit_rows <- list()
set.seed(11)
for (dz in cfr_diseases) {
  d <- long |> filter(disease == dz) |>
    group_by(year, region, district) |>
    summarise(cases = sum(cases, na.rm = TRUE), deaths = sum(deaths, na.rm = TRUE), .groups = "drop") |>
    filter(cases > 0) |>
    mutate(deaths = pmin(deaths, cases))
  if (dz == "Diphtérie") d <- d |> filter(year >= 2022)
  reg_tot <- d |> group_by(region) |> summarise(cases = sum(cases), deaths = sum(deaths), .groups = "drop")
  est_regions <- reg_tot$region[reg_tot$deaths > 0]
  dm <- d |> filter(region %in% est_regions) |>
    mutate(region = factor(region), year_f = factor(year))
  # drop years without any death in the modelled regions (their effect is not identified either)
  dm <- dm |> group_by(year_f) |> filter(sum(deaths) > 0) |> ungroup() |> mutate(year_f = droplevels(year_f))
  m <- glm(cbind(deaths, cases - deaths) ~ region + year_f, data = dm, family = quasibinomial)
  m0 <- update(m, . ~ year_f)
  ft <- anova(m0, m, test = "F")
  phi <- summary(m)$dispersion

  X <- model.matrix(m)
  B <- MASS::mvrnorm(1000, coef(m), vcov(m))
  for (r in levels(dm$region)) {
    nd <- dm; nd$region <- factor(r, levels = levels(dm$region))
    Xr <- model.matrix(delete.response(terms(m)), nd)
    std <- function(b) sum(plogis(Xr %*% b) * dm$cases) / sum(dm$cases)
    draws <- apply(B, 1, std)
    pred_rows[[paste(dz, r)]] <- tibble(disease = en(dz), region = r, cfr = std(coef(m)),
                                        lo = quantile(draws, 0.025), hi = quantile(draws, 0.975),
                                        cases = reg_tot$cases[reg_tot$region == r], deaths = reg_tot$deaths[reg_tot$region == r])
  }
  for (r in setdiff(reg_tot$region, est_regions)) {
    pred_rows[[paste(dz, r)]] <- tibble(disease = en(dz), region = r, cfr = NA, lo = NA, hi = NA,
                                        cases = reg_tot$cases[reg_tot$region == r], deaths = 0)
  }
  fit_rows[[dz]] <- tibble(Disease = en(dz), Years = paste0(min(d$year), "–", max(d$year)), `District-years` = nrow(d),
                           Cases = sum(d$cases), Deaths = sum(d$deaths), `Crude CFR` = sum(d$deaths) / sum(d$cases),
                           `Dispersion φ` = phi, `F (regions)` = ft$F[2], `df` = ft$Df[2], `p (regions)` = ft$`Pr(>F)`[2],
                           `Regions without deaths` = length(setdiff(reg_tot$region, est_regions)))
  cat(sprintf("CFR %-11s crude %.2f%% phi %.2f F %.2f p %.3g\n", en(dz), 100 * sum(d$deaths) / sum(d$cases), phi,
              ft$F[2], ft$`Pr(>F)`[2]))
}
pred <- bind_rows(pred_rows)
fits <- bind_rows(fit_rows)
save_table(fits |> transmute(Disease = paste0(Disease, ifelse(Years == "2017–2024", "", paste0(" (", Years, ")"))),
                             `District-years`, Cases = fmt(Cases, 0), Deaths = fmt(Deaths, 0),
                             `Crude CFR` = percent(`Crude CFR`, 0.1), `Dispersion φ` = fmt(`Dispersion φ`, 2),
                             `F (regions)` = sprintf("%s (%d df)", fmt(`F (regions)`, 2), df),
                             `p (regions)` = ifelse(`p (regions)` < 0.001, "< 0.001", p_fmt(`p (regions)`))),
           "t14_cfr_models")
save_table(pred |> mutate(cell = case_when(cases == 0 ~ "no cases",
                                           is.na(cfr) ~ sprintf("0 deaths / %s cases", fmt(cases, 0)),
                                           TRUE ~ sprintf("%s (%s–%s)", percent(cfr, 0.1), percent(lo, 0.1), percent(hi, 0.1)))) |>
             select(region, disease, cell) |> pivot_wider(names_from = disease, values_from = cell, values_fill = "no cases") |>
             arrange(region) |> rename(Region = region),
           "t15_cfr_by_region")

p <- ggplot(pred |> filter(!is.na(cfr)), aes(cfr, region)) +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0, orientation = "y", colour = PRIMARY) +
  geom_point(colour = PRIMARY, size = 1.8) +
  scale_x_continuous(labels = label_percent(accuracy = 1), n.breaks = 3) +
  facet_wrap(~factor(disease, en(cfr_diseases)), ncol = 4, scales = "free_x") +
  labs(x = "Case fatality standardised to the national case mix (95% interval)", y = NULL) + theme_report()
save_fig(p, "f08_cfr_by_region", h = 3)

RESULTS$cfr <- list(fits = fits, by_region = pred)
