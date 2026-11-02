# Figures for the methodology note. Run from the project root: Rscript docs/methodology/make_figures.R
suppressPackageStartupMessages({ library(dplyr); library(readr); library(ggplot2) })

w <- read_csv("data/processed/mdo_weekly.csv", show_col_types = FALSE)
keep <- c("Paludisme confirmé" = "Malaria (confirmed)", "Méningite" = "Meningitis", "Rougeole" = "Measles",
          "Choléra" = "Cholera", "Diphtérie" = "Diphtheria", "Malnutrition sévère" = "Severe acute malnutrition")

prof <- w |>
  filter(disease %in% names(keep), year >= 2017, year <= 2023, week <= 52) |>
  group_by(disease, week) |> summarise(cases = sum(cases), .groups = "drop") |>
  group_by(disease) |> mutate(share = 100 * cases / sum(cases)) |> ungroup() |>
  mutate(disease = factor(keep[disease], keep))

p <- ggplot(prof, aes(week, share)) +
  geom_col(fill = "#0b5e7e", width = 0.8) +
  facet_wrap(~disease, ncol = 3, scales = "free_y") +
  scale_x_continuous(breaks = c(1, 13, 26, 39, 52)) +
  labs(x = "Epidemiological week", y = "Share of 2017–2023 cases (%)") +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        strip.text = element_text(face = "bold", hjust = 0))
ggsave("docs/methodology/fig_seasonality.png", p, width = 6.5, height = 3.6, dpi = 200, bg = "white")
cat("docs/methodology/fig_seasonality.png\n")
