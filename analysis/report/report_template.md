---
title: "Statistical modelling of notifiable disease surveillance in Niger, 2017–2024"
subtitle: "Results report: trends, transmission dynamics, forecasting, reporting performance and case fatality"
date: "November 2026"
---

# Summary

This report presents the first estimates from the models set out in the companion methodology note (*Econometric and statistical models for Niger's weekly notifiable disease data*). It uses the weekly MDO/IDSR reports of Niger's 72 health districts from week 1 of 2017 to week 43 of 2024: about 29,000 district-weeks per disease. Seven model families were estimated; three others need data not yet available and are described as next steps.

**Main findings**

- **The counts are strongly over-dispersed** for every disease (Cameron–Trivedi tests, t = 3.2 to 35.2), so Poisson-based inference would understate uncertainty; all results use negative binomial or robust methods.
- **Malaria and malnutrition rose.** After adjusting for seasonality and district, confirmed malaria in 2024 was 1.74 times its 2017 level (95% CI 1.55–1.96) and suspected malaria 2.64 times (2.28–3.06). Severe acute malnutrition was 1.21 times its 2017 level in 2021 (1.08–1.35), its last reported year.
- **Diphtheria has re-emerged.** Seasonally adjusted incidence in 2024 was about 175 times the 2017 level (95% CI 36–855); the outbreak-detection algorithm flagged 74 of the 147 weeks from 2022 to week 43 of 2024.
- **Meningitis fell, then returned.** Incidence dropped to 0.12 times the 2017 level in 2020, then rose back to 1.39 times in 2024; 6 districts crossed the WHO epidemic threshold in 2024.
- **Transmission is local.** For meningitis and measles, about three quarters of expected cases come from last week's cases in the same district and under 10% from other districts, almost all from districts in the same region. One more doubling of last week's cases in a district multiplies the odds of at least one case this week by 2.3 to 3.9, depending on the disease.
- **Short-term forecasts are informative.** One week ahead, a negative binomial autoregression reduces the forecast error of a seasonal benchmark by 49% (meningitis), 85% (measles) and 65% (confirmed malaria), with well-calibrated 90% intervals; four weeks ahead the gain is small or absent for meningitis.
- **Reporting is timely but uneven.** The share of district reports received on time rose from 84% (2016–2017) to 99.6% (2023); it is lower in the rainy season (odds ratio 0.80) and in every region compared with Niamey.
- **Case fatality differs by region for meningitis** (F-test p < 0.001), from 3.5% in Diffa to 12.6% in Agadez after standardising to the national case mix.
- **The population denominators in the source files are inconsistent** between diseases and years (Section 2.2). All rates here use total district population; anyone computing rates directly from the workbooks should do the same.

# Introduction

Niger's weekly notifiable disease reports cover 25 diseases in 72 health districts. The companion methodology note set out which models suit these data and why: counts are over-dispersed, mostly zero for epidemic-prone diseases, strongly persistent from week to week and sharply seasonal. This report applies those models to answer six questions:

1. How have incidence levels, trends and seasonality changed since 2017? (Section 4.2)
2. What predicts whether a district reports any case of an outbreak-prone disease in a given week? (Section 4.3)
3. How much of meningitis and measles incidence comes from local transmission, from spread between districts, or from background cases? (Section 4.4)
4. How accurately can national weekly cases be forecast? (Section 4.5)
5. What explains late reporting? (Section 4.6)
6. Does case fatality differ between regions? (Section 4.7)

Section 4.8 tests an automated outbreak-detection algorithm on 2022–2024.

# Data

## Analytic sample

The analysis uses the processed weekly district table (`mdo_long.csv`) for 2017 to week 43 of 2024: the period with Niger's current 72 health districts. Each disease contributes about 29,000 district-weeks (fewer where a disease was not reported in every year). Reporting status (on time, late, not received) comes from the completeness sheets for 2015–2023.

Three adjustments were made before estimation:

- **Missing reports.** District-weeks whose report was not received (status N, 2018–2023) are treated as missing rather than zero: 78 district-weeks for meningitis and 117 for measles. The endemic–epidemic model cannot handle gaps and sets them to zero (0.3% of observations).
- **Series that change.** Suspected malaria in 2018 is excluded (it is lower than confirmed malaria that year); severe acute malnutrition is analysed for 2017–2021, the years it is reported. Confirmed malaria changes definition in 2021 (positive tests before, confirmed cases after); its year effects for 2021 onward include that change.
- **Partial year.** 2024 covers weeks 1–43. Year effects are estimated from weekly data with seasonal terms, so 2024 is comparable with full years; totals are not.

## Population denominators

The disease sheets do not share one population denominator. Severe acute malnutrition uses the under-5 population from 2019 (about 20% of the total) and none for 2017–2018; confirmed malaria has no population for 2017–2020; acute flaccid paralysis, neonatal tetanus and malaria in pregnancy use target populations. Using each sheet's own column produced an artificial six-fold jump in malnutrition incidence in 2019. All models therefore use the **total district population listed on the measles sheet**, which is complete in every year. Rates are per 100,000 total population.

# Models estimated

Table 1 lists the models, with their specification in the methodology note. All were estimated in R 4.5 (conda-forge); code is in `analysis/R/` and runs in about 10–15 minutes (Section 7).

**Table 1.** Models estimated.

| Section | Model | Outcome and unit | Estimator (R package) |
|---|---|---|---|
| 4.1–4.2 | Negative binomial (NB2) panel, district fixed effects, year effects, Fourier seasonality; Poisson PML as check | Weekly cases, district | ML (`fixest`) |
| 4.3 | Hurdle NB, zero-inflated NB, NB with lagged cases in the district, region and rest of Niger | Weekly cases, district | ML (`pscl`, `MASS`) |
| 4.4 | Endemic–epidemic multivariate model (hhh4) | Weekly cases, district | Penalised ML (`surveillance`) |
| 4.5 | NB autoregression with Fourier seasonality; harmonic NB; seasonal naive | Weekly cases, national | ML, rolling origin (`MASS`) |
| 4.6 | Mixed-effects logit | On-time report, district-week | Laplace ML (`lme4`) |
| 4.7 | Quasi-binomial regression | Deaths among cases, district-year | Quasi-likelihood (`stats`) |
| 4.8 | Improved Farrington algorithm | Weekly cases, national | Quasi-Poisson / NB (`surveillance`) |

The main specifications are, for district $i$ and week $t$:

$$
\log \mu_{it} = \log e_{it} + \alpha_i + \tau_{a(t)} + \sum_{k=1}^{2}\left[\gamma_k \sin\left(\frac{2\pi k\, w(t)}{52.18}\right) + \delta_k \cos\left(\frac{2\pi k\, w(t)}{52.18}\right)\right], \qquad y_{it} \sim \operatorname{NB}\left(\mu_{it}, \theta\right) \qquad (1)
$$

for trends and seasonality, where $e_{it}$ is population in units of 100,000, $\alpha_i$ district effects and $\tau_{a(t)}$ year effects relative to 2017;

$$
\operatorname{logit} \Pr(y_{it} > 0) = \mathbf{z}_{it}'\boldsymbol{\gamma}, \qquad \mathbf{z}_{it} \ni \log\left(1 + y_{i,t-1}\right),\ \log\left(1 + y^{\text{region}}_{-i,t-1}\right),\ \log\left(1 + y^{\text{Niger}}_{-r(i),t-1}\right) \qquad (2)
$$

for the zero part of the hurdle model, with a truncated NB for positive counts; and

$$
\mu_{it} = e_{it}\,\nu_{it} + \lambda_{it}\, y_{i,t-1} + \phi_{it} \sum_{j \neq i} w_{ji}\, y_{j,t-1}, \qquad w_{ji} \propto o_{ji}^{-d} \qquad (3)
$$

for the endemic–epidemic model, with seasonal terms in $\nu_{it}$ and $\lambda_{it}$, district random intercepts and a power-law decay $d$ in the neighbourhood order $o_{ji}$.

## Changes from the methodology note

Four changes were needed; none alters the substance of the planned analysis.

- **Neighbourhood for spatial spread.** District boundaries are not available. The neighbourhood order between districts is taken from their regions: order 1 for districts in the same region, 2 for districts in regions that share a border, and 1 + the number of region borders crossed otherwise. Region borders were derived from the IGNN 2023 region boundaries.
- **Hurdle and zero-inflated models** were fitted with `pscl`, with district effects as fixed dummies in the zero part and region effects in the count part, instead of random effects (`glmmTMB` does not load on the available Windows build).
- **Case fatality** uses a quasi-binomial model with region and year effects. A binomial mixed model with district and observation-level random effects was fitted first; it estimated the between-region variance at zero for meningitis, measles and diphtheria and was unstable for cholera, which has 68 district-years with cases.
- **Forecasting** uses a NB autoregression on lagged log counts (the log-linear count autoregression of the methodology note without the feedback term), estimated with `MASS::glm.nb`, because the `tscount` package could not be installed.

## Not yet estimated

The distributed lag non-linear models (climate), Bayesian spatial risk maps (BYM2) and impact evaluation (interrupted time series, difference-in-differences) need data that are not in the surveillance files: climate series, district boundaries, and dates and locations of interventions. They are listed with data sources in Section 6.

# Results

## Over-dispersion

Every disease rejects the Poisson variance assumption (Table 2). The variance of district-week counts is 25 to 3,200 times the mean; the Cameron–Trivedi auxiliary regression gives positive and significant $\delta$ for all eight diseases, and the likelihood-ratio statistic for NB against Poisson is above 11,000 for every disease. The dispersion parameter $\theta$ is around 2.4–2.7 for malaria and malnutrition and between 0.03 and 0.23 for the outbreak-prone diseases, which means extreme clustering of cases in a few district-weeks.

**Table 2.** Over-dispersion tests (NB θ: smaller values mean more over-dispersion).

{{t01_overdispersion}}

## Trends and seasonality

**Table 3.** Negative binomial panel models: seasonality and change since 2017.

{{t02_nb_summary}}

*IRR: incidence rate ratio of 2024 (weeks 1–43) relative to 2017, adjusted for district and season, with 95% confidence interval (standard errors clustered by district); [2021]: last year reported. Peak ÷ trough: ratio of the highest to the lowest point of the fitted seasonal curve. District-weeks and θ are in Table 2.*

![Figure 1. Year effects relative to 2017 (NB, 95% CI, log scale). Cholera is omitted: years without any case have effects tending to zero.](../output/figures/f01_year_effects.png){width=100%}

Four patterns stand out (Figure 1, Annex Table A1):

- **Malaria** rose steadily. Suspected malaria doubled by 2022 (IRR 2.00) and reached 2.64 in 2024; confirmed malaria was 1.43 times the 2017 level in 2020 and 1.74 in 2024. Part of the confirmed-malaria increase from 2021 reflects the change of definition.
- **Measles** follows an epidemic cycle: IRRs of 4.2–4.5 in 2019, 2021 and 2022, 0.92 in 2023, then 2.39 in 2024.
- **Meningitis** declined to 0.12 times the 2017 level in 2020 and has risen since, to 1.39 in 2024 (95% CI 0.83–2.33).
- **Diphtheria** was sporadic until 2021 and re-emerged from 2022: IRR 9 in 2022, 65 in 2023 and 175 in 2024. **Pertussis** shows no significant trend.

![Figure 2. Fitted seasonal profile: rate ratio relative to the annual mean (log scale).](../output/figures/f02_seasonality.png){width=100%}

Seasonality is strong and disease-specific (Figure 2): malaria peaks in week 39 with a 13-fold peak-to-trough ratio; meningitis and measles peak in the dry season (weeks 14–15) with ratios of 73 and 31; severe acute malnutrition is only mildly seasonal (peak week 35, ratio 1.5). The meningitis season peaks earliest in Zinder (week 9) and latest in Agadez (week 18); malaria peaks in weeks 39–41 in every region (Table 4).

**Table 4.** Peak week of the fitted seasonal curve by region (one harmonic, region-specific).

{{t05_regional_seasonality}}

**Robustness.** Year effects from the Poisson PML estimator, which is consistent under weaker assumptions, are highly correlated with the NB estimates for malaria, measles, meningitis and diphtheria (r = 0.92–0.99, Table 5). Agreement is weaker for pertussis (r = 0.61), whose counts are very sparse, and for cholera, whose year effects are unbounded in years without cases; trends for those two diseases should not be interpreted.

**Table 5.** Year effects: negative binomial against Poisson PML.

{{t04_nb_vs_ppml}}

## Outbreak occurrence and local spread

For the four outbreak-prone diseases, models that treat zeros separately fit much better than the NB model (Table 6): the hurdle NB has the lowest AIC for meningitis and measles, the zero-inflated NB for cholera and diphtheria.

**Table 6.** Model comparison for outbreak-prone diseases (lower AIC is better).

{{t06_hurdle_comparison}}

*The NB model for cholera did not converge.*

**Table 7.** Hurdle NB: effect of last week's cases, per doubling of (1 + cases).

{{t07_hurdle_effects}}

*OR: odds ratio of at least one case this week (zero part). IRR: rate ratio of the number of cases when there is at least one (count part). 95% confidence intervals. Models include district (zero part) or region (count part) effects, year effects and seasonal terms.*

Last week's cases in the same district are the strongest predictor of any case this week: one more doubling multiplies the odds by 3.0 for meningitis, 2.3 for measles, 3.9 for cholera and 2.6 for diphtheria (Table 7, Figure 3). Cases elsewhere in the same region add a smaller but significant effect (OR 1.14–1.34). Cases in the rest of Niger matter for cholera (1.32) and diphtheria (1.12), little for measles (1.05) and not for meningitis (0.99, p = 0.73). Once an outbreak has started, its size depends mostly on the district's own previous week.

![Figure 3. Odds ratio of at least one case per doubling of last week's cases, by source.](../output/figures/f03_hurdle_effects.png){width=100%}

## Transmission dynamics: endemic–epidemic model

The endemic–epidemic model decomposes expected cases into three components (Table 8, Figure 4).

**Table 8.** Share of expected cases from each component, 2017–2024.

{{t09_hhh4_shares}}

![Figure 4. Fitted components of weekly national cases (areas) and observed cases (dots).](../output/figures/f04_hhh4_components.png){width=100%}

About three quarters of expected meningitis (74%) and measles (73%) cases come from last week's cases in the same district; background (endemic) incidence accounts for 18–22% and spread between districts for 4–9%. Of the between-district component, 84% (meningitis) and 73% (measles) of the weight falls on districts in the same region: the estimated power-law decay is so steep that spread beyond the region is negligible (Table 9).

**Table 9.** Endemic–epidemic model parameters.

{{t08_hhh4_parameters}}

*λ: expected new cases per case in the same district the previous week, for the median district. φ: the same for cases in other districts, weighted by neighbourhood. d: power-law decay with neighbourhood order. ψ: over-dispersion. Peak weeks refer to the seasonal terms of each component.*

The within-district component peaks earlier in the year (week 7 for meningitis, week 6 for measles) than the endemic component (weeks 10 and 13), consistent with transmission building up before the peak of reported cases. The dominant eigenvalue of the epidemic part, a measure of epidemic potential, ranges over the year from 0.52 to 1.06 for meningitis and from 0.58 to 1.15 for measles: it exceeds 1, the threshold for self-sustaining growth, only during the dry-season peak (Figure 5). Background incidence rises by 5–6% a year for both diseases.

![Figure 5. Dominant eigenvalue of the epidemic component through the year (2019 shown).](../output/figures/f05_hhh4_eigenvalue.png){width=75%}

**Validation.** Parameters were estimated on 2017–2022 and one-week-ahead forecasts scored on 2023–2024 (Table 10). Adding the within-district component greatly improves on the endemic-only model, and the full model, which adds spread between districts, gives the best log score and ranked probability score for both diseases.

**Table 10.** Out-of-sample one-week-ahead forecast scores, 2023–2024 (lower is better).

{{t10_hhh4_scores}}

## Forecasting national weekly cases

**Table 11.** Rolling-origin forecast accuracy, 2023 week 1 to 2024 week 43.

{{t12_forecast_accuracy}}

*MAE: mean absolute error in cases. Skill: reduction in MAE of the NB autoregression against the seasonal naive forecast (same week of the previous year). Models refitted every four weeks on all data up to the forecast date.*

One week ahead, the NB autoregression is much more accurate than both benchmarks for all three series, reducing the error of the seasonal naive forecast by 49–85% (Table 11, Figure 6). Its 90% prediction intervals contain the observed value 92–95% of the time. Four weeks ahead, the gain falls to 66% for measles and 23% for malaria, and disappears for meningitis (−4%), whose four-week forecasts are no better than the seasonal pattern; intervals become slightly too narrow (84–85% coverage) for malaria and measles. Weekly forecasting is therefore useful for operational planning one to two weeks ahead.

![Figure 6. One-week-ahead forecasts and 90% intervals against observed cases.](../output/figures/f06_forecasts.png){width=100%}

## Reporting timeliness

From 2015 to 2023, {{received_share}} of district-weeks had a report. Between 84% and 96% of reports arrived on time each year from 2015 to 2022, and 99.6% in 2023. The mixed logit (Table 12) estimates the factors associated with an on-time report among 29,515 district-weeks.

**Table 12.** Mixed-effects logit for an on-time weekly report, 2015–2023 (reference: 2015, dry season, Niamey, district existing before 2017).

{{t13_reporting_logit}}

- **Years.** Timeliness was lowest in 2016–2017 (odds ratios about 0.4 against 2015), improved in 2021 and was almost universal in 2023 (OR 20.5).
- **Season.** Reports were less likely to be on time in the rainy season (OR 0.80, 95% CI 0.72–0.88), when road access is hardest.
- **Regions.** Every region had lower odds of timely reporting than Niamey, most markedly Agadez (0.07), Dosso (0.09) and Zinder (0.17).
- **New districts.** Districts created in 2017 reported as well as older ones (OR 1.06, p = 0.43).

Once region, year and season are accounted for, districts differ little (intra-class correlation 1.0%); the lowest district effect is Bilma, the most remote district of Agadez (Figure 7).

![Figure 7. District effects on timely reporting (log-odds, 95% intervals).](../output/figures/f07_reporting_district_effects.png){width=90%}

## Case fatality

**Table 13.** Case fatality models.

{{t14_cfr_models}}

**Table 14.** Case fatality by region, standardised to the national case mix (95% interval).

{{t15_cfr_by_region}}

Meningitis case fatality differs clearly between regions (F-test p < 0.001): standardised to the national case mix, it ranges from 3.5% in Diffa and 4.4% in Niamey to 8.6% in Dosso and 12.6% in Agadez (Tables 13–14, Figure 8). Measles case fatality is low everywhere (0.2–1.0%) but also varies (p = 0.005), highest in Diffa. Cholera estimates are very imprecise, and diphtheria case fatality (overall 6.0%) does not differ significantly between regions (p = 0.06). Over-dispersion is moderate to high (φ = 1.7–5.7), so district-years are far more variable than binomial sampling would imply. Differences in case fatality can reflect severity, access to care, case definitions or under-reporting of mild cases, and do not by themselves measure quality of care.

![Figure 8. Case fatality by region, standardised to the national case mix.](../output/figures/f08_cfr_by_region.png){width=100%}

## Outbreak detection

The improved Farrington algorithm was applied to national weekly series for 2022 to week 43 of 2024, each week compared with the same period of the previous five years (Table 15, Figure 9).

**Table 15.** Weeks flagged as aberrant (alarm threshold: upper 99% limit of expected cases).

{{t16_outbreak_alarms}}

- **Diphtheria** raised alarms in 74 of 147 weeks: against a baseline of near-zero incidence, the re-emergence from 2022 is detected throughout.
- **Meningitis** raised 12 alarms, in the dry seasons of 2022–2024. Over the same period, 24 weeks had at least one district above the WHO epidemic threshold; 9 of them were also flagged by the national algorithm. A national series misses outbreaks confined to a few districts, so district-level thresholds remain essential.
- **Cholera** was flagged in weeks 39–40 of 2024, the start of that year's outbreak.
- **Measles** raised no alarm: the large epidemics of 2019, 2021 and 2022 are part of the five-year baseline, so even the high incidence of 2024 was within the expected range.

![Figure 9. National weekly cases, alarm threshold and alarm weeks, 2022–2024.](../output/figures/f09_outbreak_detection.png){width=100%}

# Discussion

## Main findings

The surveillance data are informative well beyond the counts they report. Five findings matter for public health action:

1. **Malaria incidence has risen** by roughly 75% (confirmed) to 165% (suspected) since 2017, after adjusting for population, season and district; the increase continued into 2024. Changes in testing, case definitions and health-facility attendance contribute to this trend and should be examined before attributing it to transmission.
2. **Diphtheria is a re-emerging threat**, with a 175-fold increase in seasonally adjusted incidence by 2024 and a case fatality of 6%, pointing to gaps in vaccination coverage.
3. **Outbreaks of meningitis, measles, cholera and diphtheria are driven by local transmission.** Most expected cases arise from the same district's previous week, with spread mainly within regions. Response capacity concentrated at district and regional level, triggered by the first cases, matches this dynamic.
4. **Short-term forecasting is feasible.** Weekly counts can be forecast one week ahead with useful accuracy and honest uncertainty, which supports planning of drugs, staff and beds during epidemic seasons.
5. **Reporting is now timely almost everywhere,** but Agadez, Dosso and Zinder lag, and timeliness drops in the rainy season.

## Limitations

- **Surveillance data, not incidence.** The models describe reported cases. Changes in care-seeking, testing, case definitions and reporting completeness affect the counts; the confirmed-malaria definition change in 2021 is one documented example.
- **Ecological associations.** Results are at district level and associational; none of the estimates is a causal effect.
- **Approximate neighbourhood.** Spatial spread is measured with region-based neighbourhoods. True district adjacency may show more spread between neighbouring districts in different regions.
- **Denominators.** Populations are projections listed in the reports, and the disease-specific denominators in the source files are inconsistent (Section 2.2).
- **Rare diseases.** Estimates for cholera and pertussis rest on few events; their trend and fatality estimates are imprecise.
- **Multiple comparisons.** Many effects are reported; isolated p-values near 0.05 should be read with caution.
- **2024** is a partial year (weeks 1–43).

# Recommendations and next steps

**For surveillance and response**

- Use district-level WHO thresholds as the primary meningitis alert; national aberration detection is a complement, not a substitute.
- Monitor the first cases of an outbreak-prone disease in a district as a strong signal for the following weeks, and pre-position response at regional level.
- Investigate the diphtheria re-emergence alongside vaccination coverage data.
- Harmonise population denominators across disease sheets, or document target populations explicitly.

**For further analysis** (methodology note, Sections 5, 7–9)

| Analysis | Data needed | Source |
|---|---|---|
| District-level spatial spread and BYM2 risk maps | Health-district boundaries | Ministry of Public Health; OCHA COD-AB (admin 2) as a starting point |
| Climate effects on malaria and meningitis (DLNM) | Weekly rainfall, temperature, humidity, dust | CHIRPS, ERA5, MERRA-2 |
| Effect of vaccination campaigns, seasonal malaria chemoprevention and conflict | Dates and districts of campaigns; conflict events | National programmes; ACLED |
| Underlying trends in malaria | Number of tests performed, facility attendance | DHIS2 |

# Reproducibility

All results can be reproduced from the project repository.

- **Data preparation:** `python scripts/run_all.py` (environment `mdo-niger`, `environment.yml`) builds `data/processed/` from the raw workbooks.
- **Models:** `Rscript analysis/run_models.R` (environment `mdo-models`, `analysis/environment-models.yml`) runs the seven model scripts in `analysis/R/` in about 10–15 minutes and writes every table and figure in this report to `analysis/output/`.
- **Report:** `analysis/report/build_report.R` inserts the tables into this text, and pandoc converts it to Word.

The R session information (package versions) is saved in `analysis/output/session_info.txt`. Random seeds are fixed for the forecast simulations and bootstrap intervals.

# References

Cameron, A. C. and Trivedi, P. K. (1990). Regression-based tests for overdispersion in the Poisson model. *Journal of Econometrics*, 46(3), 347–364.

Held, L., Höhle, M. and Hofmann, M. (2005). A statistical framework for the analysis of multivariate infectious disease surveillance counts. *Statistical Modelling*, 5(3), 187–199.

Meyer, S. and Held, L. (2014). Power-law models for infectious disease spread. *Annals of Applied Statistics*, 8(3), 1612–1639.

Meyer, S., Held, L. and Höhle, M. (2017). Spatio-temporal analysis of epidemic phenomena using the R package surveillance. *Journal of Statistical Software*, 77(11), 1–55.

Noufaily, A., Enki, D. G., Farrington, P., Garthwaite, P., Andrews, N. and Charlett, A. (2013). An improved algorithm for outbreak detection in multiple surveillance systems. *Statistics in Medicine*, 32(7), 1206–1222.

Santos Silva, J. M. C. and Tenreyro, S. (2006). The log of gravity. *Review of Economics and Statistics*, 88(4), 641–658.

Zeileis, A., Kleiber, C. and Jackman, S. (2008). Regression models for count data in R. *Journal of Statistical Software*, 27(8), 1–25.

World Health Organization (2014). Meningitis outbreak response in sub-Saharan Africa: WHO guideline. Geneva: WHO.

# Annex

**Table A1.** Year effects relative to 2017: incidence rate ratios (95% CI) from the negative binomial panel models.

{{t03_year_irr_wide}}
