# Endemic-epidemic multivariate model (hhh4), methodology section 5
#   mu_it = e_it nu_it + lambda_it y_i,t-1 + phi_it sum_j w_ji y_j,t-1
# Neighbourhood: district boundaries are not available, so the adjacency order between districts is
# taken from their regions: 1 = same region, 2 = bordering regions, 3+ = further (region graph distance + 1).
suppressPackageStartupMessages(library(surveillance))

adj <- rd("region_adjacency.csv")
regs <- sort(unique(regions_of$region))
A <- matrix(FALSE, length(regs), length(regs), dimnames = list(regs, regs))
for (k in seq_len(nrow(adj))) { A[adj$region_a[k], adj$region_b[k]] <- TRUE; A[adj$region_b[k], adj$region_a[k]] <- TRUE }
# shortest path between regions (breadth-first)
rdist <- matrix(Inf, length(regs), length(regs), dimnames = list(regs, regs))
for (r in regs) {
  rdist[r, r] <- 0; frontier <- r; dd <- 0
  while (length(frontier)) {
    dd <- dd + 1
    nxt <- setdiff(regs[colSums(A[frontier, , drop = FALSE]) > 0], regs[is.finite(rdist[r, ])])
    rdist[r, nxt] <- dd; frontier <- nxt
  }
}

hhh4_diseases <- c("Méningite", "Rougeole")
par_rows <- list(); share_rows <- list(); score_rows <- list(); ev_rows <- list(); comp_series <- list()

for (dz in hhh4_diseases) {
  d <- panel_for(dz)
  wide <- d |> select(t, district, cases) |> pivot_wider(names_from = district, values_from = cases) |> arrange(t)
  Y <- as.matrix(wide[, -1])
  n_missing <- sum(is.na(Y))
  Y[is.na(Y)] <- 0       # district-weeks without a report (about 0.2%): set to 0 for this model
  units <- colnames(Y)
  popw <- d |> select(t, district, population) |> pivot_wider(names_from = district, values_from = population) |>
    arrange(t) |> select(all_of(units)) |> as.matrix()
  popfrac <- popw / rowSums(popw)

  ureg <- regions_of$region[match(units, regions_of$district)]
  nbo <- outer(seq_along(units), seq_along(units), function(i, j) rdist[cbind(ureg[i], ureg[j])] + 1)
  diag(nbo) <- 0
  dimnames(nbo) <- list(units, units)
  storage.mode(nbo) <- "integer"

  s <- sts(observed = Y, start = c(2017, 1), frequency = 52, population = popfrac, neighbourhood = nbo)
  ctrl <- list(
    # ri() carries the overall intercept itself, hence -1
    end = list(f = addSeason2formula(~ -1 + ri(type = "iid") + t, S = 1, period = PERIOD), offset = population(s)),
    ar = list(f = addSeason2formula(~ -1 + ri(type = "iid"), S = 1, period = PERIOD)),
    ne = list(f = ~ 1, weights = W_powerlaw(maxlag = max(nbo))),
    family = "NegBin1", subset = 2:nrow(Y), optimizer = list(variance = list(method = "Nelder-Mead")))
  fit <- hhh4(s, ctrl)
  if (!fit$convergence) warning(dz, ": hhh4 did not converge")

  # parameters on the natural scale
  co <- fit$coefficients; se <- fit$se
  ar_int <- grep("^ar\\.ri", names(co), value = TRUE)[1]   # mean of the district random intercepts
  rows <- list(
    c("Endemic: trend per year", exp(co[["end.t"]] * PERIOD), exp((co[["end.t"]] - 1.96 * se[["end.t"]]) * PERIOD), exp((co[["end.t"]] + 1.96 * se[["end.t"]]) * PERIOD)),
    c("Within-district: λ (median district)", exp(co[[ar_int]]), exp(co[[ar_int]] - 1.96 * se[[ar_int]]), exp(co[[ar_int]] + 1.96 * se[[ar_int]])),
    c("Between-district: φ",exp(co[["ne.1"]]), exp(co[["ne.1"]] - 1.96 * se[["ne.1"]]), exp(co[["ne.1"]] + 1.96 * se[["ne.1"]])),
    c("Distance decay (power law): d",exp(co[["neweights.d"]]), exp(co[["neweights.d"]] - 1.96 * se[["neweights.d"]]), exp(co[["neweights.d"]] + 1.96 * se[["neweights.d"]])),
    c("Share of between-district weight on the same region", NA, NA, NA),
    c("Over-dispersion: ψ", exp(-co[["-log(overdisp)"]]), exp(-co[["-log(overdisp)"]] - 1.96 * se[["-log(overdisp)"]]), exp(-co[["-log(overdisp)"]] + 1.96 * se[["-log(overdisp)"]])))
  # seasonal amplitude and peak week of each component
  for (cmp in c("end", "ar")) {
    g <- co[[paste0(cmp, ".sin(2 * pi * t/", PERIOD, ")")]]; h <- co[[paste0(cmp, ".cos(2 * pi * t/", PERIOD, ")")]]
    pk <- (atan2(g, h) * PERIOD / (2 * pi)) %% PERIOD
    rows[[length(rows) + 1]] <- c(paste0(ifelse(cmp == "end", "Endemic", "Within-district"), ": seasonal peak-to-trough ratio (peak week ",
                                         round(pk), ")"), exp(2 * sqrt(g^2 + h^2)), NA, NA)
  }
  # average share of a district's incoming between-district weight that comes from its own region (order 1)
  W <- getNEweights(fit)
  own_share <- mean(sapply(seq_along(units), function(i) sum(W[nbo[, i] == 1, i]) / sum(W[, i])))
  par_rows[[dz]] <- as_tibble(do.call(rbind, rows), .name_repair = ~c("parameter", "est", "lo", "hi")) |>
    mutate(across(c(est, lo, hi), as.numeric), disease = en(dz),
           est = ifelse(grepl("same region", parameter), own_share, est))

  # decomposition of the fitted mean into the three components
  m <- meanHHH(fit$coefficients, terms(fit))
  tot <- c(endemic = sum(m$endemic), within = sum(m$epi.own), between = sum(m$epi.neighbours))
  share_rows[[dz]] <- tibble(disease = en(dz), component = names(tot), share = tot / sum(tot))
  tt <- wide$t[fit$control$subset]
  comp_series[[dz]] <- tibble(disease = en(dz), t = tt, Endemic = rowSums(m$endemic),
                              `Within district` = rowSums(m$epi.own), `Between districts` = rowSums(m$epi.neighbours),
                              observed = rowSums(Y[fit$control$subset, , drop = FALSE]))
  ev <- getMaxEV(fit)
  if (length(ev) == nrow(Y)) ev <- ev[fit$control$subset]   # one value per week; the first week is not modelled
  ev_rows[[dz]] <- tibble(disease = en(dz), t = tt, max_ev = ev)

  # out-of-sample one-step-ahead forecasts for 2023-2024 (parameters estimated on data up to 2022)
  t0 <- min(which(wide$t %in% week_index$t[week_index$year == 2023])) - 1
  models <- list(`Endemic only` = update(fit, ar = list(f = ~ -1), ne = list(f = ~ -1)),
                 `Endemic + within-district` = update(fit, ne = list(f = ~ -1)),
                 `Full endemic-epidemic` = fit)
  for (nm in names(models)) {
    osa <- oneStepAhead(models[[nm]], tp = c(t0, nrow(Y) - 1), type = "first", verbose = FALSE)
    sc <- colMeans(scores(osa, which = c("logs", "dss", "rps"), individual = FALSE))
    # AIC is not defined for hhh4 with random effects (penalised likelihood): compare forecasts instead
    score_rows[[paste(dz, nm)]] <- tibble(disease = en(dz), model = nm,
                                          logs = sc[["logs"]], dss = sc[["dss"]], rps = sc[["rps"]])
  }
  cat(sprintf("hhh4 %-11s missing set to 0: %d | shares end %.2f own %.2f ne %.2f | maxEV range %.2f-%.2f\n",
              en(dz), n_missing, tot[1] / sum(tot), tot[2] / sum(tot), tot[3] / sum(tot), min(ev), max(ev)))
}

pars <- bind_rows(par_rows)
save_table(pars |> transmute(Disease = disease, Parameter = parameter,
                             Estimate = case_when(grepl("same region", parameter) ~ percent(est, 0.1),
                                                  grepl("decay", parameter) & est > 10 ~ "> 10 (all weight on order 1)",
                                                  is.na(lo) ~ fmt(est, 2),
                                                  TRUE ~ fmt_ci(est, lo, hi, 2))),
           "t08_hhh4_parameters")
shares <- bind_rows(share_rows)
save_table(shares |> mutate(component = recode(component, endemic = "Endemic (background)", within = "Within district",
                                               between = "Between districts")) |>
             pivot_wider(names_from = disease, values_from = share) |>
             mutate(across(-component, ~percent(.x, 0.1))) |> rename(Component = component),
           "t09_hhh4_shares")
scores_tbl <- bind_rows(score_rows)
save_table(scores_tbl |> group_by(disease) |> mutate(best = logs == min(logs)) |> ungroup() |>
             transmute(Disease = disease, Model = model, `Log score` = fmt(logs, 3),
                       `Dawid–Sebastiani` = fmt(dss, 3), `Ranked prob. score` = fmt(rps, 3),
                       `Best log score` = ifelse(best, "yes", "")),
           "t10_hhh4_scores")

# figure: national fitted components vs observed
cs <- bind_rows(comp_series) |> left_join(week_index, by = "t") |>
  mutate(date = as.Date(paste(year, 1, 1, sep = "-")) + (week - 1) * 7)
long_cs <- cs |> pivot_longer(c(Endemic, `Within district`, `Between districts`), names_to = "component", values_to = "mean") |>
  mutate(component = factor(component, c("Between districts", "Within district", "Endemic")))
p <- ggplot(long_cs, aes(date, mean, fill = component)) +
  geom_area(alpha = 0.85) +
  geom_point(data = cs, aes(date, observed), inherit.aes = FALSE, size = 0.35, colour = INK) +
  scale_fill_manual(values = c(Endemic = "#9ec5d6", `Within district` = PRIMARY, `Between districts` = WARM), name = NULL) +
  facet_wrap(~disease, ncol = 1, scales = "free_y") +
  labs(x = NULL, y = "Weekly cases, Niger (fitted components; dots = observed)") + theme_report()
save_fig(p, "f04_hhh4_components", h = 4.6)

# figure: dominant eigenvalue (epidemic potential) over the year
evs <- bind_rows(ev_rows) |> left_join(week_index, by = "t") |> filter(year == 2019)
p <- ggplot(evs, aes(week, max_ev, colour = disease)) +
  geom_hline(yintercept = 1, linetype = "dashed", colour = "grey50") + geom_line(linewidth = 0.9) +
  scale_colour_manual(values = c(Meningitis = PRIMARY, Measles = WARM), name = NULL) +
  scale_x_continuous(breaks = c(1, 13, 26, 39, 52)) +
  labs(x = "Epidemiological week", y = "Dominant eigenvalue of the epidemic part") + theme_report()
save_fig(p, "f05_hhh4_eigenvalue", h = 3)

RESULTS$hhh4 <- list(parameters = pars, shares = shares, scores = scores_tbl,
                     ev = bind_rows(ev_rows) |> group_by(disease) |> summarise(min = min(max_ev), max = max(max_ev)))
