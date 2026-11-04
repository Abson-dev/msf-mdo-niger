# Regenerate the README screenshots in docs/screenshots/ from a running copy of the app.
#
#   1. start the app without login:   run_app.bat --no-browser --no-login     (note the address it prints)
#   2. in a second window, from the project root:
#        conda install -n mdo-models -c conda-forge r-chromote   (once)
#        conda run -n mdo-models Rscript docs/make_screenshots.R 8802
#        conda run -n mdo-models Rscript docs/make_screenshots.R 8802 overview.png    (just some)
#
# Uses Microsoft Edge (or set CHROMOTE_CHROME to another Chromium browser).

args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args)) args[1] else "8802"
only <- if (length(args) > 1) args[-1] else NULL
edge <- "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
if (Sys.getenv("CHROMOTE_CHROME") == "" && file.exists(edge)) Sys.setenv(CHROMOTE_CHROME = edge)
suppressMessages(library(chromote))

out <- file.path("docs", "screenshots")
dir.create(out, showWarnings = FALSE, recursive = TRUE)

# file, tab, window height (the page scrolls inside the window, so a taller window shows more)
shots <- list(
  list("overview.png", "Overview", 1000),
  list("disease-explorer.png", "Disease explorer", 1000),
  list("disease-explorer-full.png", "Disease explorer", 2300),
  list("meningitis-thresholds.png", "Meningitis thresholds", 1400),
  list("reporting-performance.png", "Reporting performance", 1000),
  list("maternal-deaths.png", "Maternal deaths", 1000),
  list("dhis2-comparison.png", "DHIS2 2024", 1000),
  list("sources-and-checks.png", "Sources and checks", 1000),
  list("methods.png", "Methods", 1000)
)
if (!is.null(only)) shots <- Filter(function(sh) sh[[1]] %in% only, shots)

for (sh in shots) {
  s <- ChromoteSession$new(width = 1440, height = sh[[3]])
  js <- function(code) s$Runtime$evaluate(code, returnByValue = TRUE)$result$value
  invisible(s$Page$navigate(paste0("http://127.0.0.1:", port, "/?tab=", utils::URLencode(sh[[2]], reserved = TRUE)), wait_ = FALSE))
  for (i in 1:120) {
    idle <- tryCatch(js("!!window.Shiny && !!Shiny.shinyapp && Shiny.shinyapp.isConnected() && !document.documentElement.classList.contains('shiny-busy') && document.querySelectorAll('.navbar .nav-link').length > 0"), error = function(e) FALSE)
    if (isTRUE(idle) && i > 6) break
    Sys.sleep(0.5)
  }
  Sys.sleep(4)   # plotly and DataTables draw after the data arrives
  writeBin(jsonlite::base64_dec(s$Page$captureScreenshot(format = "png")$data), file.path(out, sh[[1]]))
  cat(sh[[1]], "\n")
  s$close()
}
