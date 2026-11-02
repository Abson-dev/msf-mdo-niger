# National weekly forecasting with rolling-origin evaluation (methodology sections 6 and 12)
#   NB autoregression (log-linear INGARCH without feedback, q = 0):
#     log mu_t = b0 + a1 log(1+y_t-1) + a2 log(1+y_t-2) + a52 log(1+y_t-52) + Fourier(K=2) + trend [+ 2021 shift]
#   Benchmarks: seasonal naive (same week last year) and NB harmonic regression without autoregression.
#   Evaluation: 2023 week 1 to 2024 week 43, horizons 1 and 4 weeks, refit every 4 weeks (expanding window).
suppressPackageStartupMessages(library(MASS, exclude = "select"))

nat <- rd("mdo_weekly.csv") |> inner_join(years_tbl |> select(year, last_week), by = "year") |>
  filter(week <= last_week) |> arrange(year, week)
series <- c("Méningite", "Rougeole", "Paludisme confirmé")
set.seed(20261102)
NSIM <- 1000

make_frame <- function(y, week, year) {
  tibble(y = y, week = week, year = year, t = seq_along(y),
         l1 = log1p(lag(y, 1)), l2 = log1p(lag(y, 2)), l52 = log1p(lag(y, 52)),
         shift = as.integer(year >= 2021)) |>
    bind_cols(as.data.frame(fourier(week)))
}
f_ar <- y ~ l1 + l2 + l52 + s1 + c1 + s2 + c2 + t
f_harm <- y ~ s1 + c1 + s2 + c2 + t

fc_rows <- list(); path_rows <- list()
for (dz in series) {
  s <- nat |> filter(disease == dz)
  fr <- make_frame(s$cases, s$week, s$year)
  fa <- f_ar; fh <- f_harm
  if (dz == "Paludisme confirmé") { fa <- update(fa, . ~ . + shift); fh <- update(fh, . ~ . + shift) }
  test_idx <- which(fr$year >= 2023)
  origins <- (min(test_idx) - 1):(max(test_idx) - 1)
  m_ar <- m_h <- NULL
  for (o in origins) {
    if (is.null(m_ar) || (o - origins[1]) %% 4 == 0) {
      train <- fr |> filter(t <= o, !is.na(l52))
      m_ar <- glm.nb(fa, data = train); m_h <- glm.nb(fh, data = train)
    }
    for (h in c(1, 4)) {
      target <- o + h
      if (target > nrow(fr)) next
      # AR model: simulate h steps ahead, feeding simulated counts back into the lags
      sims <- matrix(NA_real_, NSIM, h)
      ypath <- matrix(rep(fr$y, each = NSIM), NSIM)
      for (k in 1:h) {
        tt <- o + k
        nd <- fr[rep(tt, NSIM), ]
        nd$l1 <- log1p(ypath[, tt - 1]); nd$l2 <- log1p(ypath[, tt - 2]); nd$l52 <- log1p(ypath[, tt - 52])
        mu <- predict(m_ar, newdata = nd, type = "response")
        draw <- rnbinom(NSIM, size = m_ar$theta, mu = mu)
        ypath[, tt] <- draw
        sims[, k] <- draw
      }
      yh <- sims[, h]
      mu_h <- predict(m_h, newdata = fr[target, ], type = "response")
      obs <- fr$y[target]
      fc_rows[[length(fc_rows) + 1]] <- tibble(
        disease = en(dz), h = h, origin = o, target = target, obs = obs,
        ar_mean = mean(yh), ar_lo = quantile(yh, 0.05), ar_hi = quantile(yh, 0.95),
        ar_logs = if (h == 1) -dnbinom(obs, size = m_ar$theta, mu = mean(yh), log = TRUE) else NA_real_,
        harm_mean = mu_h, harm_lo = qnbinom(0.05, size = m_h$theta, mu = mu_h), harm_hi = qnbinom(0.95, size = m_h$theta, mu = mu_h),
        harm_logs = -dnbinom(obs, size = m_h$theta, mu = mu_h, log = TRUE),
        naive = fr$y[target - 52])
    }
  }
  cat(sprintf("forecast %-20s origins %d\n", en(dz), length(origins)))
}
fc <- bind_rows(fc_rows)
write_csv(fc, file.path(OUT, "tables", "t11_forecasts_long.csv"))

acc <- fc |> group_by(disease, h) |>
  summarise(`MAE NB autoregression` = mean(abs(obs - ar_mean)),
            `MAE harmonic NB` = mean(abs(obs - harm_mean)),
            `MAE seasonal naive` = mean(abs(obs - naive)),
            `90% coverage NB autoregression` = mean(obs >= ar_lo & obs <= ar_hi),
            `90% coverage harmonic NB` = mean(obs >= harm_lo & obs <= harm_hi),
            `Log score NB autoregression` = mean(ar_logs), `Log score harmonic NB` = mean(harm_logs),
            weeks = n(), .groups = "drop") |>
  mutate(`Skill vs seasonal naive` = 1 - `MAE NB autoregression` / `MAE seasonal naive`)
save_table(acc |> transmute(Disease = disease, Horizon = paste(h, ifelse(h == 1, "week", "weeks")), Weeks = weeks,
                            `MAE: NB autoregression` = fmt(`MAE NB autoregression`, 1),
                            `MAE: harmonic NB` = fmt(`MAE harmonic NB`, 1),
                            `MAE: seasonal naive` = fmt(`MAE seasonal naive`, 1),
                            `Skill vs naive` = percent(`Skill vs seasonal naive`, 1),
                            `90% interval coverage (NB autoregression)` = percent(`90% coverage NB autoregression`, 1)),
           "t12_forecast_accuracy")

wk <- nat |> distinct(year, week) |> mutate(target = row_number())
pf <- fc |> filter(h == 1) |> left_join(wk, by = "target") |>
  mutate(date = as.Date(paste(year, 1, 1, sep = "-")) + (week - 1) * 7, disease = factor(disease, en(series)))
p <- ggplot(pf, aes(date)) +
  geom_ribbon(aes(ymin = ar_lo, ymax = ar_hi), fill = PRIMARY, alpha = 0.2) +
  geom_line(aes(y = ar_mean), colour = PRIMARY, linewidth = 0.7) +
  geom_point(aes(y = obs), size = 0.6, colour = INK) +
  facet_wrap(~disease, ncol = 1, scales = "free_y") +
  scale_y_continuous(labels = label_comma()) +
  labs(x = NULL, y = "Weekly cases, Niger", caption = "Line and band: one-week-ahead forecast and 90% interval; dots: observed.") +
  theme_report()
save_fig(p, "f06_forecasts", h = 5)

RESULTS$forecast <- acc
