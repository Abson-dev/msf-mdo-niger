# Assemble the results report: replaces {{table_name}} in report_template.md with the tables written by
# analysis/run_models.R (analysis/output/tables/*.md) and a few values computed here, and writes
# analysis/report/results_report.md, which pandoc turns into Word (analysis/report/build_report.ps1).
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(readr) })
tab_dir <- file.path("analysis", "output", "tables")

pipe_table <- function(df) {
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}

# values and tables built here rather than in the model scripts
extra <- list()
yr <- read_csv(file.path(tab_dir, "t03_year_irr_long.csv"), show_col_types = FALSE) |>
  filter(disease != "Cholera") |>
  mutate(cell = sprintf("%s (%s–%s)", formatC(irr, format = "f", digits = 2), formatC(lo, format = "f", digits = 2),
                        formatC(hi, format = "f", digits = 2)))
ann <- yr |> mutate(disease = factor(disease, unique(disease))) |> arrange(disease, year) |>
  transmute(Disease = as.character(disease), Year = as.character(year), `IRR vs 2017 (95% CI)` = cell)
extra[["{{t03_year_irr_wide}}"]] <- paste(pipe_table(ann), collapse = "\n")
comp <- read_csv(file.path("data", "processed", "completeness_weekly.csv"), show_col_types = FALSE)
extra[["{{received_share}}"]] <- sprintf("%.1f%%", 100 * mean(comp$received))

txt <- paste(readLines("analysis/report/report_template.md", encoding = "UTF-8"), collapse = "\n")
for (k in names(extra)) txt <- gsub(k, extra[[k]], txt, fixed = TRUE)
keys <- unique(regmatches(txt, gregexpr("\\{\\{[a-z0-9_]+\\}\\}", txt))[[1]])
for (k in keys) {
  f <- file.path(tab_dir, paste0(gsub("[{}]", "", k), ".md"))
  if (!file.exists(f)) stop("missing table for ", k)
  txt <- gsub(k, paste(readLines(f, encoding = "UTF-8"), collapse = "\n"), txt, fixed = TRUE)
}
writeLines(enc2utf8(txt), "analysis/report/results_report.md", useBytes = TRUE)
cat("filled", length(keys) + length(extra), "placeholders\n")
