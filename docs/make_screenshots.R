# Regenerate the README screenshots in docs/screenshots/ from a running copy of the app.
#
#   1. start the app:   Rscript -e "shiny::runApp('app', port = 8799)"
#   2. in a second window, from the project root:
#        conda install -n mdo-niger -c conda-forge r-chromote   (once)
#        Rscript docs/make_screenshots.R 8799                       (all screenshots)
#        Rscript docs/make_screenshots.R 8799 overview.png          (just some)
#
# Uses Microsoft Edge (or set CHROMOTE_CHROME to another Chromium browser).

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args)) args[1] else "8799"
edge <- "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
if (Sys.getenv("CHROMOTE_CHROME") == "" && file.exists(edge)) Sys.setenv(CHROMOTE_CHROME = edge)
library(chromote)

out <- file.path("docs", "screenshots")
dir.create(out, showWarnings = FALSE, recursive = TRUE)
W <- 1440

# file, tab, element whose card row starts the crop (NULL = top of page), crop height, left crop (skips the sidebar)
shots <- list(
  list("overview.png", "Overview", NULL, 860, 0),
  list("disease-explorer.png", "Disease explorer", NULL, 700, 0),
  list("disease-explorer-maps.png", "Disease explorer", "disease_map", 900, 300),
  list("meningitis-thresholds.png", "Meningitis thresholds", NULL, 1240, 0),
  list("reporting-performance.png", "Reporting performance", NULL, 640, 0),
  list("dhis2-comparison.png", "DHIS2 2024 comparison", "dh_weekly", 520, 300)
)
only <- if (length(args) > 1) args[-1] else NULL
if (!is.null(only)) shots <- Filter(function(sh) sh[[1]] %in% only, shots)

wait_idle <- function(s) {
  for (i in 1:120) {
    busy <- s$Runtime$evaluate("(document.documentElement.classList.contains('shiny-busy') || !window.Shiny || !Shiny.shinyapp || !Shiny.shinyapp.isConnected()) ? 1 : 0")$result$value
    if (identical(as.integer(busy), 0L)) return(invisible(TRUE))
    Sys.sleep(0.5)
  }
}

for (sh in shots) {
  s <- ChromoteSession$new(width = W, height = 1000)
  s$Page$navigate(paste0("http://127.0.0.1:", port, "/?tab=", utils::URLencode(sh[[2]], reserved = TRUE)))
  s$Page$loadEventFired(wait_ = TRUE)
  Sys.sleep(3); wait_idle(s); Sys.sleep(4); wait_idle(s)
  top <- if (is.null(sh[[3]])) 0 else s$Runtime$evaluate(sprintf(
    "(() => { const e = document.getElementById('%s').closest('.bslib-grid') || document.getElementById('%s').closest('.card');
      return Math.max(0, e.getBoundingClientRect().top + window.scrollY - 12); })()", sh[[3]], sh[[3]]))$result$value
  f <- file.path(out, sh[[1]])
  s$screenshot(f, selector = "html", cliprect = c(sh[[5]], top, W - sh[[5]], sh[[4]]), scale = 1, show = FALSE)
  cat(sh[[1]], "\n")
  s$close()
}
