# Hurdle negative binomial models for outbreak-driven diseases (methodology section 4)
#   zero part:  Pr(any case) depends on last week's cases in the district, the rest of its region and
#               the rest of Niger, seasonality and year; count part: size of the count given > 0.
#   Compared with NB and zero-inflated NB on the same predictors. District effects enter as fixed
#   dummies in both parts (pscl).
suppressPackageStartupMessages({ library(pscl); library(MASS, exclude = "select") })

hurdle_diseases <- c("Méningite", "Rougeole", "Choléra", "Diphtérie")
x <- "l_own + l_reg + l_rest + s1 + c1 + s2 + c2 + year_f + district"
# the count part only sees weeks with cases (a few hundred for cholera and diphtheria): region effects
# instead of district dummies keep it identified
x_count <- "l_own + l_reg + l_rest + s1 + c1 + s2 + c2 + year_f + region"

cmp_rows <- list(); eff_rows <- list()
for (dz in hurdle_diseases) {
  d <- panel_for(dz) |>
    filter(!is.na(cases), !is.na(lag1), population > 0) |>
    mutate(l_own = log1p(lag1), l_reg = log1p(reg_other_lag1), l_rest = log1p(rest_lag1))
  if (dz == "Diphtérie") d <- d |> filter(year >= 2020)   # almost no cases before 2022
  # districts with no case at all add nothing but separation problems
  d <- d |> group_by(district) |> filter(sum(cases) > 0) |> ungroup() |>
    mutate(district = factor(district), year_f = droplevels(year_f))

  xz <- x; xc <- x_count
  if (dz == "Choléra") {
    # no cholera case at all in 2019, 2020 or 2023: year effects are not identified; the lagged-case
    # terms carry the outbreak years instead
    xz <- sub(" + year_f", "", x, fixed = TRUE)
    xc <- "l_own + l_reg + l_rest + s1 + c1 + region"
  }
  f2 <- as.formula(paste("cases ~", xc, "+ offset(log_exposure) |", xz))
  m_nb <- tryCatch(glm.nb(as.formula(paste("cases ~", xz, "+ offset(log_exposure)")), data = d), error = function(e) NULL)
  m_zinb <- tryCatch(zeroinfl(f2, data = d, dist = "negbin"), error = function(e) NULL)
  m_hnb <- tryCatch(hurdle(f2, data = d, dist = "negbin", zero.dist = "binomial"), error = function(e) NULL)
  a <- sapply(list(NB = m_nb, ZINB = m_zinb, Hurdle = m_hnb), function(m) if (is.null(m)) NA else AIC(m))
  cmp_rows[[dz]] <- tibble(Disease = en(dz), Districts = nlevels(d$district), `District-weeks` = nrow(d),
                           `Zero weeks` = mean(d$cases == 0),
                           `AIC NB` = a[["NB"]], `AIC ZINB` = a[["ZINB"]], `AIC hurdle` = a[["Hurdle"]])

  if (!is.null(m_hnb)) {
    s <- summary(m_hnb)$coefficients
    for (v in c("l_own", "l_reg", "l_rest")) {
      # zero part is a logit of Pr(y > 0); effects per doubling of (1 + last week's cases)
      bz <- s$zero[v, "Estimate"]; sz <- s$zero[v, "Std. Error"]
      bc <- s$count[v, "Estimate"]; sc <- s$count[v, "Std. Error"]
      eff_rows[[paste(dz, v)]] <- tibble(
        disease = en(dz), term = v,
        or_any = exp(bz * log(2)), or_lo = exp((bz - 1.96 * sz) * log(2)), or_hi = exp((bz + 1.96 * sz) * log(2)),
        irr_size = exp(bc * log(2)), irr_lo = exp((bc - 1.96 * sc) * log(2)), irr_hi = exp((bc + 1.96 * sc) * log(2)),
        p_any = s$zero[v, "Pr(>|z|)"], p_size = s$count[v, "Pr(>|z|)"])
    }
    RESULTS[[paste0("hurdle_theta_", dz)]] <- m_hnb$theta[["count"]]
  }
  cat(sprintf("hurdle %-12s n=%d AIC NB %.0f ZINB %.0f hurdle %.0f\n", en(dz), nrow(d), a[["NB"]], a[["ZINB"]], a[["Hurdle"]]))
}

cmp <- bind_rows(cmp_rows)
best <- function(r) { v <- c(NB = r[["AIC NB"]], ZINB = r[["AIC ZINB"]], `Hurdle NB` = r[["AIC hurdle"]]); names(v)[which.min(v)] }
save_table(cmp |> rowwise() |> mutate(`Best (AIC)` = best(pick(everything()))) |> ungroup() |>
             transmute(Disease, Districts, `District-weeks` = fmt(`District-weeks`, 0), `Zero weeks` = percent(`Zero weeks`, 0.1),
                       `AIC NB` = fmt(`AIC NB`, 0), `AIC ZINB` = fmt(`AIC ZINB`, 0), `AIC hurdle NB` = fmt(`AIC hurdle`, 0),
                       `Best (AIC)`),
           "t06_hurdle_comparison")

eff <- bind_rows(eff_rows) |>
  mutate(term = factor(recode(term, l_own = "Same district", l_reg = "Rest of the region", l_rest = "Rest of Niger"),
                       c("Rest of Niger", "Rest of the region", "Same district")))
save_table(eff |> arrange(factor(disease, en(hurdle_diseases)), desc(term)) |>
             transmute(Disease = disease, `Last week's cases in` = as.character(term),
                       `OR of any case` = fmt_ci(or_any, or_lo, or_hi), `p (any)` = p_fmt(p_any),
                       `IRR of case count` = fmt_ci(irr_size, irr_lo, irr_hi), `p (count)` = p_fmt(p_size)),
           "t07_hurdle_effects")

p <- ggplot(eff, aes(or_any, term)) +
  geom_vline(xintercept = 1, colour = "grey60") +
  geom_errorbar(aes(xmin = or_lo, xmax = or_hi), width = 0.2, orientation = "y", colour = PRIMARY) +
  geom_point(colour = PRIMARY, size = 2) +
  scale_x_log10() + facet_wrap(~factor(disease, en(hurdle_diseases)), ncol = 4) +
  labs(x = "Odds ratio of at least one case this week, per doubling of last week's cases (log scale)", y = NULL) +
  theme_report()
save_fig(p, "f03_hurdle_effects", h = 2.6)

RESULTS$hurdle <- list(comparison = cmp, effects = eff)
