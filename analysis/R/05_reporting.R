# Timeliness of weekly district reports, 2015-2023: mixed-effects logit (methodology section 10.1)
#   logit Pr(on time) = year + rainy season + region + district created in 2017 + u_district
suppressPackageStartupMessages(library(lme4))

rep <- rd("completeness_weekly.csv")
old_districts <- rep |> filter(year <= 2017) |> distinct(district) |> pull()
rep <- rep |>
  mutate(year_f = factor(year), rainy = as.integer(week >= 27 & week <= 39),
         new_district = as.integer(!district %in% old_districts),
         region = relevel(factor(region), ref = "Niamey"))

m <- glmer(on_time ~ year_f + rainy + region + new_district + (1 | district), data = rep, family = binomial,
           control = glmerControl(optimizer = "bobyqa"))
co <- summary(m)$coefficients
ci <- confint(m, method = "Wald", parm = "beta_")
keep <- rownames(co)[rownames(co) != "(Intercept)"]
lab <- function(x) {
  x <- sub("^year_f", "Year ", x); x <- sub("^region", "Region: ", x)
  x <- sub("^rainy$", "Rainy season (weeks 27–39)", x); sub("^new_district$", "District created in 2017", x)
}
or_tbl <- tibble(term = lab(keep), or = exp(co[keep, "Estimate"]), lo = exp(ci[keep, 1]), hi = exp(ci[keep, 2]),
                 p = co[keep, "Pr(>|z|)"])
save_table(or_tbl |> transmute(Variable = term, `Odds ratio (95% CI)` = fmt_ci(or, lo, hi), p = p_fmt(p)),
           "t13_reporting_logit")

s2 <- as.numeric(VarCorr(m)$district)
icc <- s2 / (s2 + pi^2 / 3)
# districts with the lowest and highest timeliness, conditional on year and season (random effects)
re <- ranef(m, condVar = TRUE)$district
pv <- attr(re, "postVar")[1, 1, ]
dre <- tibble(district = rownames(re), u = re[, 1], se = sqrt(pv)) |>
  left_join(regions_of, by = "district") |> arrange(u)
p <- ggplot(dre, aes(u, reorder(district, u))) +
  geom_vline(xintercept = 0, colour = "grey60") +
  geom_errorbar(aes(xmin = u - 1.96 * se, xmax = u + 1.96 * se), width = 0, orientation = "y", colour = "grey55") +
  geom_point(aes(colour = region), size = 1.4) +
  scale_colour_manual(values = c(Agadez = "#0072B2", Diffa = "#E69F00", Dosso = "#009E73", Maradi = "#CC79A7",
                                 Niamey = "#56B4E9", Tahoua = "#D55E00", "Tillabéri" = "#999933", Zinder = "#332288"),
                      name = NULL) +
  labs(x = "District effect on the log-odds of an on-time report (95% interval)", y = NULL) +
  theme_report() + theme(axis.text.y = element_text(size = 7))
save_fig(p, "f07_reporting_district_effects", w = 6.5, h = 9.2)

timeliness_by_year <- rep |> group_by(year) |> summarise(on_time = mean(on_time), received = mean(received), n = n())
RESULTS$reporting <- list(or = or_tbl, icc = icc, sigma2 = s2, by_year = timeliness_by_year,
                          worst = head(dre, 5), best = tail(dre, 5), n = nrow(rep), districts = n_distinct(rep$district))
cat(sprintf("reporting logit: n=%d districts=%d ICC=%.3f\n", nrow(rep), n_distinct(rep$district), icc))
