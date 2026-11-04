# Niger notifiable disease surveillance (MDO / IDSR), 2015-2024
#
# Double-click run_app.bat, or from the project root:   conda activate mdo-niger
#                              Rscript -e "shiny::runApp('app', launch.browser = TRUE)"
# The app is self-contained: it reads only app/data/, built by scripts/run_all.py.

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(plotly)
  library(jsonlite)
  library(DT)
  library(scales)
})

# ---- data ---------------------------------------------------------------------------------------

DATA <- if (dir.exists("data")) "data" else file.path("app", "data")
rd <- function(f) read_csv(file.path(DATA, f), show_col_types = FALSE, locale = locale(encoding = "UTF-8"))

years_tbl     <- rd("mdo_years.csv")
annual        <- rd("mdo_annual.csv")
weekly        <- rd("mdo_weekly.csv")
weekly_region <- rd("mdo_weekly_region.csv")
regional      <- rd("mdo_regional.csv")
district      <- rd("mdo_district.csv")
summary_tbl   <- rd("mdo_summary.csv")
comp          <- rd("completeness_weekly.csv")
comp24        <- rd("completeness_2024_cumulative.csv")
maternal      <- rd("maternal_deaths.csv")
menin         <- rd("meningitis_district_week.csv")
dhis_vs_wb    <- rd("dhis2_vs_workbook_2024.csv")
dhis_cases    <- rd("dhis2_cases_region_week.csv")
dhis_comp     <- rd("dhis2_completeness_region_week.csv")
checks        <- rd("validation_checks.csv")
inventory     <- rd("data_inventory.csv")
regions_geo   <- read_json(file.path(DATA, "regions.geojson"))
region_names  <- vapply(regions_geo$features, function(f) f$properties$region, "")

LAST_WEEK_2024 <- years_tbl$last_week[years_tbl$year == 2024]
FULL_YEARS     <- years_tbl$year[years_tbl$complete]
ALL_YEARS      <- sort(years_tbl$year)
LATEST_FULL    <- max(FULL_YEARS)

# English names for the French disease labels used in the source files
DISEASE_EN <- c(
  "Paludisme suspect" = "Malaria (suspected)", "Paludisme confirmé" = "Malaria (confirmed)",
  "Paludisme (femmes enceintes)" = "Malaria in pregnant women",
  "Malnutrition modérée" = "Moderate acute malnutrition", "Malnutrition sévère" = "Severe acute malnutrition",
  "Rougeole" = "Measles", "Méningite" = "Meningitis", "Choléra" = "Cholera", "Diphtérie" = "Diphtheria",
  "Coqueluche" = "Pertussis", "Tétanos néonatal" = "Neonatal tetanus", "Autre tétanos" = "Tetanus (other)",
  "Fièvre jaune (suspect)" = "Yellow fever (suspected)", "PFA" = "Acute flaccid paralysis",
  "Diarrhée sanglante" = "Bloody diarrhoea", "Rage" = "Rabies", "Ver de Guinée" = "Guinea worm",
  "Grippe" = "Influenza", "Ebola" = "Ebola virus disease", "Fièvres hémorragiques virales" = "Viral haemorrhagic fevers",
  "Hépatite virale E" = "Hepatitis E", "COVID-19" = "COVID-19", "Dengue" = "Dengue", "SRAS" = "SARS",
  "MERS-CoV" = "MERS-CoV", "Fièvre de la vallée du Rift" = "Rift Valley fever"
)
en <- function(x) unname(ifelse(x %in% names(DISEASE_EN), DISEASE_EN[x], x))

disease_choices <- summary_tbl |> filter(total_cases > 0) |> mutate(label = en(disease)) |> arrange(label)
disease_choices <- setNames(disease_choices$disease, disease_choices$label)

# ---- look ---------------------------------------------------------------------------------------
# Same identity as the Ituri dashboard: www/style.css (shared), same theme, same chart colours.

for (f in list.files(file.path(dirname(DATA), "R"), pattern = "\\.R$", full.names = TRUE)) source(f, encoding = "UTF-8")
check_auth()
LOGO <- if (file.exists(file.path(dirname(DATA), "www", "logo_msf.png"))) "logo_msf.png"

INK     <- "#17191c"
MUTED   <- "#6b6d70"
GRID    <- "#e1e0d9"
AXIS    <- "#c3c2b7"
PRIMARY <- "#2a78d6"
DARK    <- "#184f95"
LIGHT   <- "#a9cbf3"
WARM    <- "#eb6834"
AMBER   <- "#e5a50a"
GREEN   <- "#1baf7a"
DANGER  <- "#c62f2f"
FONT    <- "'Segoe UI', system-ui, sans-serif"
SEQ     <- c("#eaf2fc", "#86b6ef", PRIMARY, DARK, "#0d366b")
# Okabe-Ito based, colour-blind safe, one colour per region everywhere
REGION_COL <- c(Agadez = "#0072B2", Diffa = "#E69F00", Dosso = "#009E73", Maradi = "#CC79A7",
                Niamey = "#56B4E9", Tahoua = "#D55E00", "Tillabéri" = "#999933", Zinder = "#332288")

theme <- bs_theme(
  version = 5, primary = "#c40000", secondary = "#4d4f53", bg = "#ffffff", fg = INK,
  base_font = font_collection("Segoe UI", "system-ui", "-apple-system", "sans-serif"),
  "font-size-base" = "0.92rem", "border-radius" = "0.5rem"
)

num <- function(x, d = 0) ifelse(is.na(x), "–", comma(x, accuracy = 10^-d))
pct <- function(x, d = 1) ifelse(is.na(x), "–", paste0(number(x, accuracy = 10^-d), "%"))
rate_fmt <- function(x) ifelse(is.na(x), "–", ifelse(x >= 100, comma(x, accuracy = 1),
                                                     ifelse(x >= 1, number(x, accuracy = 0.1), number(x, accuracy = 0.01))))

# common plotly styling: readable fonts, light grid, PNG export only
polish <- function(p, filename = "niger-mdo-chart", legend = TRUE) {
  p |>
    layout(font = list(family = FONT, size = 12, color = INK), separators = ".,",
           paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
           hoverlabel = list(bgcolor = "white", bordercolor = AXIS, font = list(family = FONT, size = 12, color = INK)),
           xaxis = list(gridcolor = GRID, zeroline = FALSE, linecolor = AXIS, tickfont = list(color = MUTED)),
           yaxis = list(gridcolor = GRID, zeroline = FALSE, tickfont = list(color = MUTED), separatethousands = TRUE),
           legend = list(orientation = "h", y = -0.18, font = list(size = 11)), showlegend = legend,
           margin = list(l = 10, r = 10, t = 10, b = 10)) |>
    config(displaylogo = FALSE, modeBarButtons = list(list("toImage")),
           toImageButtonOptions = list(format = "png", filename = filename, scale = 3))
}

region_map <- function(df, value, label, fmt = num, filename = "niger-map", zmin = 0, zmax = NULL) {
  m <- tibble(region = region_names) |> left_join(df, by = "region")
  z <- m[[value]]
  if (is.null(zmax)) zmax <- max(z, zmin + 1, na.rm = TRUE)
  # white labels on the darker half of the colour scale
  dark <- setNames(!is.na(z) & (z - zmin) / (zmax - zmin) > 0.55, m$region)
  dark["Niamey"] <- dark["Tillabéri"]   # its label sits over Tillabéri (see REGION_LABEL_POS)
  label_col <- ifelse(dark[REGION_LABEL_POS$region], "#ffffff", INK)
  plot_ly(type = "choropleth", geojson = regions_geo, featureidkey = "properties.region",
          locations = m$region, z = ifelse(is.na(z), zmin, z), zmin = zmin, zmax = zmax,
          colorscale = lapply(seq_along(SEQ), function(i) list((i - 1) / (length(SEQ) - 1), SEQ[i])),
          text = paste0("<b>", m$region, "</b><br>", label, ": ", fmt(z)), hoverinfo = "text",
          marker = list(line = list(color = "white", width = 1.2)),
          colorbar = list(title = list(text = label, font = list(size = 11)), thickness = 10, len = 0.8,
                          tickformat = ",~r")) |>
    add_trace(type = "scattergeo", mode = "text", lon = REGION_LABEL_POS$lon, lat = REGION_LABEL_POS$lat,
              text = REGION_LABEL_POS$region, textfont = list(size = 10, color = label_col), hoverinfo = "skip",
              inherit = FALSE, showlegend = FALSE) |>
    layout(geo = list(fitbounds = "locations", visible = FALSE, projection = list(type = "mercator"))) |>
    polish(filename, legend = FALSE)
}

# label position: the vertex average of each region's largest ring
REGION_LABEL_POS <- bind_rows(lapply(regions_geo$features, function(f) {
  rings <- lapply(f$geometry$coordinates, function(poly) poly[[1]])
  ring <- rings[[which.max(lengths(rings))]]
  xy <- do.call(rbind, lapply(ring, function(p) c(p[[1]], p[[2]])))
  tibble(region = f$properties$region, lon = mean(xy[, 1]), lat = mean(xy[, 2]))
}))
# Niamey is an enclave inside Tillabéri: move the two labels apart
REGION_LABEL_POS$lat[REGION_LABEL_POS$region == "Tillabéri"] <- REGION_LABEL_POS$lat[REGION_LABEL_POS$region == "Tillabéri"] + 1
REGION_LABEL_POS$lat[REGION_LABEL_POS$region == "Niamey"] <- REGION_LABEL_POS$lat[REGION_LABEL_POS$region == "Niamey"] - 0.45
# the vertex average falls on Diffa's southern edge, which clips its label
REGION_LABEL_POS$lat[REGION_LABEL_POS$region == "Diffa"] <- REGION_LABEL_POS$lat[REGION_LABEL_POS$region == "Diffa"] + 1.5

MAP_NOTE <- p(class = "map-note",
              "Boundaries: IGNN 2023 (admin level 1). The boundaries and names shown do not imply official endorsement or acceptance.")

# tables are rendered client-side so CSV/Excel exports contain every row, not just the visible page
render_table <- function(expr) DT::renderDT(substitute(expr), server = FALSE, env = parent.frame(), quoted = TRUE)

dt <- function(df, filename = "niger-mdo", page = 12, escape = TRUE, ...) {
  datatable(df, rownames = FALSE, class = "compact hover stripe", extensions = "Buttons", escape = escape,
            options = list(pageLength = page, scrollX = TRUE, dom = "Bfrtip", autoWidth = FALSE,
                           buttons = list(list(extend = "csv", filename = filename, text = "Download CSV", className = "btn btn-sm btn-outline-primary"), list(extend = "excel", filename = filename, text = "Excel", className = "btn btn-sm btn-outline-primary")),
                           language = list(search = "Filter:"), ...))
}

spark_svg <- function(years, values, w = 120, h = 26) {
  ok <- !is.na(values)
  if (!any(ok) || max(values[ok]) == 0) return("")
  x <- (years[ok] - min(ALL_YEARS)) / (max(ALL_YEARS) - min(ALL_YEARS)) * (w - 4) + 2
  y <- h - 2 - values[ok] / max(values[ok]) * (h - 4)
  sprintf('<svg width="%d" height="%d" viewBox="0 0 %d %d" role="img" aria-label="Cases per year, 2015-2024"><polyline fill="none" stroke="%s" stroke-width="1.6" stroke-linejoin="round" points="%s"/><circle cx="%.1f" cy="%.1f" r="2.2" fill="%s"/></svg>',
          w, h, w, h, PRIMARY, paste(sprintf("%.1f,%.1f", x, y), collapse = " "), tail(x, 1), tail(y, 1), PRIMARY)
}

# height = NULL: the server sizes the plot (output "<id>_ui"), for heatmaps with one row per district
card_plot <- function(title, output, note = NULL, height = "360px", footer = NULL) {
  plot <- if (is.null(height)) uiOutput(paste0(output, "_ui")) else plotlyOutput(output, height = height)
  card(full_screen = TRUE, card_header(title),
       card_body(if (!is.null(note)) p(class = "card-note", note), plot, footer, gap = "0.25rem"))
}

# ---- overview content (static: computed once from the data) ------------------------------------

kpi_box <- function(key, icon, tone) {
  a <- annual |> filter(disease == key)
  cur <- a |> filter(year == LATEST_FULL)
  prev <- a |> filter(year == LATEST_FULL - 1)
  ch <- if (nrow(prev) && prev$cases > 0) (cur$cases - prev$cases) / prev$cases else NA
  kpi(paste0(en(key), ", ", LATEST_FULL), num(cur$cases),
      tagList(if (!is.na(ch)) change_tag(ch, sprintf("vs %d", LATEST_FULL - 1)), br(), paste0(num(cur$deaths), " deaths")),
      icon, tone)
}

peak <- function(key) annual |> filter(disease == key) |> slice_max(cases, n = 1, with_ties = FALSE)
men_epi_years <- menin |> filter(status == "epidemic") |> distinct(year, district) |> count(year)
key_findings <- local({
  m <- peak("Rougeole"); mg <- peak("Méningite"); ch <- peak("Choléra")
  dip <- annual |> filter(disease == "Diphtérie")
  mal <- annual |> filter(disease == "Paludisme suspect")
  mal_conf <- annual |> filter(disease == "Paludisme confirmé", year == LATEST_FULL)
  epi24 <- men_epi_years$n[men_epi_years$year == 2024]
  epi_between <- max(c(0, men_epi_years$n[men_epi_years$year > 2015 & men_epi_years$year < 2024]))
  div(class = "pile-alertes",
    finding("Malaria dominates the caseload",
            sprintf("Suspected malaria rose from %s cases in %d to %s in %d; %s cases were confirmed in %d.",
                    num(mal$cases[mal$year == min(mal$year)]), min(mal$year), num(mal$cases[mal$year == LATEST_FULL]),
                    LATEST_FULL, num(mal_conf$cases), LATEST_FULL)),
    finding("Meningitis",
            paste0(sprintf("The %d epidemic reached %s cases and %s deaths. ", mg$year, num(mg$cases), num(mg$deaths)),
                   if (length(epi24)) sprintf("In 2024 (to week %d), %d districts crossed the WHO epidemic threshold%s.",
                                              LAST_WEEK_2024, epi24, if (epi24 > epi_between) ", the most since 2015" else ""))),
    finding("Measles", sprintf("Peaked in %d with %s cases, after large outbreaks in 2019 and 2021.", m$year, num(m$cases))),
    finding("Diphtheria re-emerged",
            sprintf("Under 60 cases a year until 2021, then %s cases and %s deaths in %d.",
                    num(dip$cases[dip$year == LATEST_FULL]), num(dip$deaths[dip$year == LATEST_FULL]), LATEST_FULL)),
    finding("Cholera", sprintf("Outbreaks occurred in 2018, %d (%s cases, %s deaths) and 2024.", ch$year, num(ch$cases), num(ch$deaths)))
  )
})

overview_table <- summary_tbl |>
  left_join(annual |> group_by(disease) |> summarise(spark = spark_svg(year, cases), .groups = "drop"), by = "disease") |>
  transmute(Disease = en(disease), `French name` = disease, `Cases` = total_cases, `Deaths` = total_deaths,
            `Case fatality (%)` = cfr_pct, `Peak year` = ifelse(total_cases > 0, peak_year, NA),
            `Trend 2015–2024` = spark, `Years reported` = paste0(first_year, "–", last_year))

# ---- UI -----------------------------------------------------------------------------------------

period_chip <- div(class = "puce-semaine", ico("calendar-days"), strong("2015–2024"), span(sprintf("to week %d of 2024", LAST_WEEK_2024)))
# controls appear in the shared sidebar only on the tab they belong to
for_tab <- function(tab, ...) conditionalPanel(sprintf("input.nav == '%s'", tab), ...)
dhis_choices <- local({ k <- unique(dhis_cases$disease); k <- k[order(en(k))]; setNames(k, en(k)) })

app_ui <- page_navbar(
  id = "nav",
  title = brand(LOGO),
  window_title = "Niger · Notifiable disease surveillance",
  theme = theme,
  fillable = FALSE,
  header = tagList(tags$head(tags$link(rel = "stylesheet", href = "style.css"), tags$link(rel = "stylesheet", href = "mdo.css")),
                   useBusyIndicators()),
  sidebar = sidebar(
    width = 250, gap = "0.5rem",
    # On a narrow screen the controls stay available above the content
    open = list(desktop = "open", mobile = "always-above"),
    for_tab("Disease explorer",
      selectInput("disease", "Disease", disease_choices, selected = "Rougeole"),
      selectInput("year", "Year", rev(ALL_YEARS), selected = LATEST_FULL),
      radioButtons("metric", "Map shows", c("Cases per 100,000" = "incidence_per_100k", "Cases" = "cases", "Deaths" = "deaths")),
      uiOutput("disease_caveat"),
      downloadButton("dl_disease", "District data (CSV)", class = "btn-primary"),
      hr()
    ),
    for_tab("Meningitis thresholds",
      selectInput("men_year", "Year", rev(ALL_YEARS), selected = 2024),
      div(class = "note", strong("WHO weekly thresholds"), " for districts of 30,000 people or more: ",
          strong("alert"), " 3 cases per 100,000, ", strong("epidemic"), " 10 cases per 100,000. Smaller districts: 2 and 5 cases."),
      div(class = "note", "Applied here to whole health districts, after the fact. WHO recommends applying them at health-area level, so district-level crossings understate local outbreaks."),
      hr()
    ),
    for_tab("Reporting performance",
      selectInput("rep_year", "Year", rev(2015:2023), selected = 2023),
      div(class = "note", strong("Timeliness: "), "share of weekly district reports received on time. ",
          strong("Completeness: "), "share received at all."),
      hr()
    ),
    for_tab("Maternal deaths",
      selectInput("mat_year", "Year", rev(2015:2021), selected = 2021),
      div(class = "note", "Investigated: deaths reviewed by a maternal death audit. Not recorded in 2015."),
      hr()
    ),
    for_tab("DHIS2 2024",
      selectInput("dh_disease", "Disease", dhis_choices, selected = "Choléra"),
      hr()
    ),
    div(class = "note",
        strong("Source: "), "Ministry of Public Health of Niger, weekly MDO/IDSR reports", br(),
        strong("Data to: "), sprintf("week %d of 2024", LAST_WEEK_2024), br(),
        strong("Level: "), "health district; no individual data")
  ),

  nav_panel(
    "Overview", icon = ico("gauge-high"),
    page_body(
      page_head("Overview",
                sprintf("Cases and deaths for %d notifiable diseases, reported every week by Niger's %d health districts",
                        n_distinct(annual$disease), max(years_tbl$districts)),
                "gauge-high", period_chip),
      kpi_row(kpi_box("Paludisme confirmé", "mosquito", "bleu"), kpi_box("Rougeole", "virus", "vert"),
              kpi_box("Méningite", "brain", "orange"), kpi_box("Diphtérie", "lungs", "rouge")),
      layout_columns(
        col_widths = c(5, 7),
        card(card_header("Key findings"), card_body(key_findings)),
        card_plot("Cases per year, epidemic-prone diseases", "overview_trends",
                  "Each panel has its own scale. Lighter bar: 2024, partial year.", height = "400px")
      ),
      card(card_header("All notifiable diseases"),
           card_body(p(class = "card-note", "Totals over the years each disease is in the weekly reports. Click a column to sort."),
                     DTOutput("overview_table", fill = FALSE)))
    )
  ),

  nav_panel(
    "Disease explorer", icon = ico("wave-square"),
    page_body(
      page_head("Disease explorer", "Trend, season and geography of one disease in the selected year", "wave-square"),
      kpi_row(
        kpi("Cases", textOutput("vb_cases"), uiOutput("vb_cases_sub"), "virus", "bleu"),
        kpi("Deaths", textOutput("vb_deaths"), uiOutput("vb_deaths_sub"), "heart-pulse", "rouge"),
        kpi("Case fatality", textOutput("vb_cfr"), "Deaths ÷ cases", "percent", "ambre"),
        kpi("Cases per 100,000", textOutput("vb_inc"), uiOutput("vb_inc_sub"), "users", "ardoise")
      ),
      layout_column_wrap(width = "420px",
        card_plot("Weekly cases compared with previous years", "channel",
                  "Line: selected year. Band: lowest to highest of the other complete years; dashed: their median."),
        card_plot("Cases and case fatality per year", "annual_plot",
                  "Bars: cases (lighter: 2024, partial). Line: case fatality (%), right axis.")
      ),
      layout_column_wrap(width = "420px",
        card_plot("By region", "disease_map", footer = MAP_NOTE),
        card_plot("Weekly cases by region", "region_curve")
      ),
      card_plot("Weekly cases, all years", "week_heat", "Darker cells: more cases (square-root scale).", height = "300px"),
      card(card_header("Health districts"),
           card_body(p(class = "card-note", "Selected year, ranked by cases per 100,000."), DTOutput("district_table", fill = FALSE)))
    )
  ),

  nav_panel(
    "Meningitis thresholds", icon = ico("triangle-exclamation"),
    page_body(
      page_head("Meningitis thresholds", "Weekly district attack rates compared with WHO thresholds for the African meningitis belt", "triangle-exclamation"),
      kpi_row(
        kpi("Districts at epidemic level", textOutput("men_epi_d"), "at least one week", "triangle-exclamation", "rouge"),
        kpi("Districts at alert level", textOutput("men_alert_d"), "at least one week", "bell", "ambre"),
        kpi("District-weeks at epidemic level", textOutput("men_epi_w"), "selected year", "calendar-week", "orange"),
        kpi("Highest weekly rate", textOutput("men_peak"), uiOutput("men_peak_sub"), "arrow-trend-up", "ardoise")
      ),
      layout_column_wrap(width = "420px",
        card_plot("Districts reaching each threshold, by year", "men_years",
                  "Number of districts with at least one week at or above the threshold."),
        card_plot("Weekly meningitis cases, selected year", "men_curve")
      ),
      card_plot("Weekly status of districts that reached the alert threshold", "men_heat",
                tagList(span(class = "legend-swatch", style = paste0("background:", AMBER)), "Alert",
                        span(class = "legend-swatch", style = paste0("background:", DANGER)), "Epidemic",
                        span(class = "legend-swatch", style = "background:#eef0f3"), "Below alert"),
                height = NULL),
      card(card_header("Districts that reached the alert threshold"), card_body(DTOutput("men_table", fill = FALSE)))
    )
  ),

  nav_panel(
    "Reporting performance", icon = ico("clipboard-check"),
    page_body(
      page_head("Reporting performance", "Timeliness and completeness of weekly district reports", "clipboard-check"),
      kpi_row(
        kpi("Timeliness", textOutput("rep_t"), uiOutput("rep_t_sub"), "clock", "bleu"),
        kpi("Completeness", textOutput("rep_c"), uiOutput("rep_c_sub"), "circle-check", "vert"),
        kpi("Reports not received", textOutput("rep_n"), "district-weeks", "circle-xmark", "rouge")
      ),
      layout_column_wrap(width = "420px",
        card_plot("National timeliness and completeness by year", "rep_trend"),
        card_plot("Timeliness by region", "rep_map", "Selected year. Colour scale runs from 80% to 100%.", footer = MAP_NOTE)
      ),
      card_plot("Weekly report status by district", "rep_heat",
                tagList(span(class = "legend-swatch", style = paste0("background:", GREEN)), "On time",
                        span(class = "legend-swatch", style = paste0("background:", AMBER)), "Late",
                        span(class = "legend-swatch", style = paste0("background:", DANGER)), "Not received"),
                height = NULL),
      layout_column_wrap(width = "420px",
        card(card_header(sprintf("2024: cumulative completeness and timeliness to week %d", LAST_WEEK_2024)),
             card_body(DTOutput("rep_2024", fill = FALSE))),
        card_plot("2024: weekly facility completeness in DHIS2, by region", "rep_dhis",
                  "2024 uses different measures from the years above. Average of district percentages, weeks 1–37.")
      )
    )
  ),

  nav_panel(
    "Maternal deaths", icon = ico("person-pregnant"),
    page_body(
      page_head("Maternal deaths", "Deaths notified through weekly surveillance, 2015–2021; reports from 2022 onwards have no maternal-death section", "person-pregnant"),
      kpi_row(
        kpi("Deaths notified", textOutput("mat_n"), "selected year", "heart-pulse", "rouge"),
        kpi("Deaths investigated", textOutput("mat_i"), uiOutput("mat_i_sub"), "magnifying-glass", "bleu")
      ),
      layout_column_wrap(width = "420px",
        card_plot("Deaths notified and investigated per year", "mat_trend", "Bars: deaths. Line: share investigated (%), right axis."),
        card_plot("Deaths notified by region", "mat_map", footer = MAP_NOTE)
      ),
      card_plot("Weekly deaths notified", "mat_weekly", "Selected year.", height = "280px"),
      card(card_header("Health districts"), card_body(DTOutput("mat_table", fill = FALSE)))
    )
  ),

  nav_panel(
    "DHIS2 2024", icon = ico("code-compare"),
    page_body(
      page_head("DHIS2 2024", "The DHIS2 extract of 18 September 2024 (weeks 1–37) compared with the weekly reports used everywhere else", "code-compare"),
      card(card_header("Weeks 1–37 of 2024: weekly reports vs DHIS2"), card_body(DTOutput("dh_table", fill = FALSE))),
      layout_column_wrap(width = "420px",
        card_plot("Weekly national cases, both sources", "dh_weekly"),
        card_plot("DHIS2 cases by region, weeks 1–37", "dh_map", footer = MAP_NOTE)
      )
    )
  ),

  nav_panel(
    "Sources and checks", icon = ico("table-list"),
    page_body(
      page_head("Sources and checks", "Every sheet of every source file is either used in this dashboard or used to check it", "table-list"),
      card(card_header("Source files"), card_body(DTOutput("inventory", fill = FALSE))),
      card(card_header("Cross-checks against totals written in the source files"),
           card_body(p(class = "card-note", "'Parsed' is this dashboard's figure; 'reference' is the total in the source file. Where they differ, the source's own total row is usually the error: in the 2019 influenza sheet, districts add up to 14 but the total cell says 127."),
                     DTOutput("checks", fill = FALSE)))
    )
  ),

  nav_panel(
    "Methods", icon = ico("book-open"),
    page_body(
      page_head("Methods and definitions", "How the figures are built, and what to keep in mind when reading them", "book-open"),
      card(card_body(class = "methods",
        tags$dl(
          tags$dt("Data"), tags$dd("Weekly notifiable disease reports (MDO, Integrated Disease Surveillance and Response) compiled by the Ministry of Public Health of Niger: one workbook per year, one sheet per disease, one row per health district. Weekly cases and deaths were extracted from every sheet and checked against the totals written in the files."),
          tags$dt("Cases per 100,000"), tags$dd("Cases ÷ total district population × 100,000, using the population on the measles sheet of each year's reports. The disease sheets' own population columns are not consistent (some use target populations). 2024 rates cover a partial year."),
          tags$dt("Case fatality"), tags$dd("Deaths ÷ cases among reported cases. Deaths can be reported in a different week than cases."),
          tags$dt("Comparison with previous years"), tags$dd("For each week, the band spans the lowest and highest weekly count of the other complete years (2015–2023) in which the disease was reported; the dashed line is their median."),
          tags$dt("Meningitis thresholds"), tags$dd("WHO (2014), Meningitis outbreak response in sub-Saharan Africa: for populations of 30,000 or more, alert 3 and epidemic 10 cases per 100,000 per week; below 30,000, alert 2 and epidemic 5 cases per week. Applied here to whole districts."),
          tags$dt("Timeliness and completeness"), tags$dd("2015–2023: each district's weekly report is recorded as on time, late or not received; timeliness is the share on time, completeness the share received. 2024: cumulative percentages from the weekly reports, and DHIS2 facility completeness.")
        ),
        h3("Caveats"),
        tags$ul(
          tags$li(sprintf("The 2024 weekly reports stop at week %d; the DHIS2 extract at week 37.", LAST_WEEK_2024)),
          tags$li("Health districts were reorganised in 2017 (44–48 districts before, 72 after). Regions are comparable across all years; districts only from 2017."),
          tags$li("Confirmed malaria 2015–2020 is the number of positive rapid tests or slides; from 2021 it is the confirmed-case count. Malaria deaths are recorded under suspected malaria until 2020 and under confirmed malaria from 2021."),
          tags$li("Suspected malaria in 2018 looks incomplete: it is lower than confirmed malaria that year."),
          tags$li("Malnutrition and maternal deaths are reported until 2021; malaria in pregnant women is missing in 2020–2021; COVID-19 starts in 2021 and dengue in 2023. MERS-CoV, SARS and Guinea worm have no reported cases."),
          tags$li("Viral haemorrhagic fever cases in the 2024 weekly reports appear as Rift Valley fever in DHIS2.")
        ),
        h3("Map"),
        p("Region boundaries from the Institut Géographique National du Niger (2023), admin level 1. The boundaries and names shown and the designations used do not imply official endorsement or acceptance.")
      ))
    )
  )
)

ui <- protect_ui(app_ui, logo = LOGO)

# ---- server -------------------------------------------------------------------------------------

server <- function(input, output, session) {

  protect_server()

  # deep links: ?tab=Meningitis%20thresholds opens that tab; the address follows the open tab
  observeEvent(session$clientData$url_search, {
    tab <- parseQueryString(session$clientData$url_search)$tab
    if (!is.null(tab)) nav_select("nav", tab)
  }, once = TRUE)
  # only the tab: url_search still holds the login token, which must not return to the address bar
  observeEvent(input$nav, updateQueryString(paste0("?tab=", utils::URLencode(input$nav, reserved = TRUE)), mode = "replace"),
               ignoreInit = TRUE)

  # Overview ---------------------------------------------------------------------------------------
  output$overview_table <- render_table({
    # column 7 holds the SVG sparklines built above, so it alone is not escaped
    dt(overview_table, "niger-mdo-diseases", page = 30, escape = c(1:6, 8), order = list(list(2, "desc")),
       columnDefs = list(list(orderable = FALSE, targets = 6))) |>
      formatRound(c("Cases", "Deaths"), 0) |> formatRound("Case fatality (%)", 2)
  })

  output$overview_trends <- renderPlotly({
    keep <- c("Rougeole", "Méningite", "Choléra", "Diphtérie", "Coqueluche", "Fièvre jaune (suspect)")
    d <- annual |> filter(disease %in% keep) |> mutate(label = factor(en(disease), en(keep)))
    p <- ggplot(d, aes(year, cases, fill = partial_year,
                       text = paste0("<b>", label, " ", year, "</b><br>Cases: ", num(cases), "<br>Deaths: ", num(deaths)))) +
      geom_col(width = 0.75) +
      scale_fill_manual(values = c(`FALSE` = PRIMARY, `TRUE` = LIGHT), guide = "none") +
      scale_y_continuous(labels = label_comma(), expand = expansion(mult = c(0, 0.08))) +
      scale_x_continuous(breaks = c(2015, 2018, 2021, 2024)) +
      facet_wrap(~label, scales = "free_y", ncol = 3) +
      labs(x = NULL, y = NULL) +
      theme_minimal(base_size = 11) +
      theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
            strip.text = element_text(face = "bold", hjust = 0, colour = INK), axis.text = element_text(colour = MUTED))
    ggplotly(p, tooltip = "text") |> polish("niger-mdo-epidemic-prone", legend = FALSE)
  })

  # Disease explorer -----------------------------------------------------------------------------
  sel <- reactive(list(d = input$disease, y = as.integer(input$year)))
  wk_cov <- reactive(years_tbl$last_week[years_tbl$year == sel()$y])
  cur <- reactive(annual |> filter(disease == sel()$d, year == sel()$y))
  # previous year over the same weeks, so a partial year compares like with like
  prev <- reactive(weekly |> filter(disease == sel()$d, year == sel()$y - 1, week <= wk_cov()) |>
                     summarise(cases = sum(cases), deaths = sum(deaths), n = n()))

  delta <- function(now, before, label) {
    if (is.na(before) || before == 0 || length(now) == 0) return(p(class = "kpi-detail", "No comparison"))
    ch <- (now - before) / before
    p(class = "kpi-detail", change_tag(ch, label))
  }
  cmp_label <- reactive(if (wk_cov() < 52) sprintf("vs %d, weeks 1–%d", sel()$y - 1, wk_cov()) else sprintf("vs %d", sel()$y - 1))

  output$vb_cases <- renderText(if (nrow(cur())) num(cur()$cases) else "Not reported")
  output$vb_cases_sub <- renderUI(if (nrow(cur()) && prev()$n > 0) delta(cur()$cases, prev()$cases, cmp_label()) else p(class = "kpi-detail", "No comparison"))
  output$vb_deaths <- renderText(if (nrow(cur())) num(cur()$deaths) else "–")
  output$vb_deaths_sub <- renderUI(if (nrow(cur()) && prev()$n > 0) delta(cur()$deaths, prev()$deaths, cmp_label()) else p(class = "kpi-detail", "No comparison"))
  output$vb_cfr <- renderText(if (nrow(cur())) pct(cur()$cfr_pct, 2) else "–")
  output$vb_inc <- renderText(if (nrow(cur())) rate_fmt(cur()$incidence_per_100k) else "–")
  output$vb_inc_sub <- renderUI(p(class = "kpi-detail", if (wk_cov() < 52) sprintf("Weeks 1–%d only", wk_cov()) else "Full year"))

  output$disease_caveat <- renderUI({
    notes <- c(
      "Paludisme confirmé" = "2015–2020: positive rapid tests or slides. From 2021: confirmed cases, which also carry malaria deaths.",
      "Paludisme suspect" = "2018 looks incomplete (lower than confirmed malaria). Deaths are recorded here until 2020 only.",
      "Malnutrition modérée" = "Reported until 2021.", "Malnutrition sévère" = "Reported until 2021.",
      "Paludisme (femmes enceintes)" = "Missing in 2020 and 2021.")
    if (sel()$d %in% names(notes)) div(class = "attention", ico("circle-info"), div(class = "detail", notes[[sel()$d]]))
  })

  output$channel <- renderPlotly({
    d <- weekly |> filter(disease == sel()$d)
    hist <- d |> filter(year != sel()$y, year %in% FULL_YEARS, week <= 52) |>
      group_by(week) |> summarise(lo = min(cases), hi = max(cases), med = median(cases), n = n_distinct(year), .groups = "drop")
    now <- d |> filter(year == sel()$y)
    if (!nrow(now)) {
      return(plotly_empty(type = "scatter", mode = "markers") |> config(displayModeBar = FALSE) |>
               layout(title = list(text = sprintf("Not reported in %d", sel()$y), font = list(size = 13, color = MUTED))))
    }
    p <- plot_ly()
    if (nrow(hist)) {
      p <- p |>
        add_ribbons(data = hist, x = ~week, ymin = ~lo, ymax = ~hi, name = "Range, other years",
                    fillcolor = "rgba(42,120,214,.16)", line = list(color = "rgba(0,0,0,0)"), hoverinfo = "skip") |>
        add_lines(data = hist, x = ~week, y = ~med, name = "Median, other years",
                  line = list(color = PRIMARY, dash = "dash", width = 1.5),
                  text = ~paste0("Week ", week, "<br>Median: ", num(med), "<br>Range: ", num(lo), "–", num(hi)), hoverinfo = "text")
    }
    p |>
      add_lines(data = now, x = ~week, y = ~cases, name = as.character(sel()$y), line = list(color = DANGER, width = 2.5),
                text = ~paste0("<b>", year, ", week ", week, "</b><br>Cases: ", num(cases), "<br>Deaths: ", num(deaths)),
                hoverinfo = "text") |>
      layout(xaxis = list(title = "Epidemiological week", range = c(0.5, 53.5)), yaxis = list(title = "Cases", rangemode = "tozero")) |>
      polish(paste0("niger-", en(sel()$d), "-weekly-", sel()$y))
  })

  output$annual_plot <- renderPlotly({
    d <- annual |> filter(disease == sel()$d) |> mutate(col = ifelse(partial_year, LIGHT, ifelse(year == sel()$y, DARK, PRIMARY)))
    plot_ly(d, x = ~year) |>
      add_bars(y = ~cases, name = "Cases", marker = list(color = ~col),
               text = ~paste0("<b>", year, ifelse(partial_year, sprintf(" (weeks 1–%d)", LAST_WEEK_2024), ""), "</b><br>Cases: ", num(cases),
                              "<br>Deaths: ", num(deaths), "<br>Per 100,000: ", rate_fmt(incidence_per_100k)),
               hoverinfo = "text", textposition = "none") |>
      add_trace(y = ~cfr_pct, name = "Case fatality (%)", yaxis = "y2", type = "scatter", mode = "lines+markers",
                line = list(color = WARM, width = 2), marker = list(color = WARM, size = 6), connectgaps = FALSE,
                hoverinfo = "skip") |>
      layout(xaxis = list(title = "", dtick = 1), yaxis = list(title = "Cases"),
             yaxis2 = list(title = "Case fatality (%)", overlaying = "y", side = "right", rangemode = "tozero",
                           showgrid = FALSE, tickfont = list(color = MUTED), tickformat = ".2~f", ticksuffix = "%"),
             bargap = 0.3) |>
      polish(paste0("niger-", en(sel()$d), "-annual")) |>
      layout(margin = list(l = 10, r = 60, t = 10, b = 10))
  })

  output$disease_map <- renderPlotly({
    d <- regional |> filter(disease == sel()$d, year == sel()$y)
    lab <- c(incidence_per_100k = "Per 100,000", cases = "Cases", deaths = "Deaths")[[input$metric]]
    region_map(d, input$metric, lab, if (input$metric == "incidence_per_100k") rate_fmt else num,
               paste0("niger-", en(sel()$d), "-map-", sel()$y))
  })

  output$region_curve <- renderPlotly({
    d <- weekly_region |> filter(disease == sel()$d, year == sel()$y)
    plot_ly(d, x = ~week, y = ~cases, color = ~region, colors = REGION_COL, type = "scatter", mode = "lines",
            line = list(width = 1.8),
            text = ~paste0("<b>", region, "</b>, week ", week, "<br>Cases: ", num(cases)), hoverinfo = "text") |>
      layout(xaxis = list(title = "Epidemiological week"), yaxis = list(title = "Cases", rangemode = "tozero")) |>
      polish(paste0("niger-", en(sel()$d), "-regions-", sel()$y))
  })

  output$week_heat <- renderPlotly({
    d <- weekly |> filter(disease == sel()$d)
    plot_ly(d, x = ~week, y = ~factor(year), z = ~sqrt(cases), type = "heatmap", xgap = 1, ygap = 1,
            colorscale = lapply(seq_along(SEQ), function(i) list((i - 1) / (length(SEQ) - 1), SEQ[i])), showscale = FALSE,
            text = ~paste0("<b>", year, ", week ", week, "</b><br>Cases: ", num(cases), "<br>Deaths: ", num(deaths)),
            hoverinfo = "text") |>
      layout(xaxis = list(title = "Epidemiological week", showgrid = FALSE), yaxis = list(title = "", autorange = "reversed", showgrid = FALSE)) |>
      polish(paste0("niger-", en(sel()$d), "-heatmap"), legend = FALSE)
  })

  district_sel <- reactive({
    district |> filter(disease == sel()$d, year == sel()$y) |> arrange(desc(incidence_per_100k)) |>
      transmute(District = district, Region = region, Population = population, Cases = cases, Deaths = deaths,
                `Case fatality (%)` = cfr_pct, `Per 100,000` = incidence_per_100k)
  })
  output$district_table <- render_table({
    d <- district_sel()
    dt(d, paste0("niger-", en(sel()$d), "-districts-", sel()$y)) |>
      formatRound(c("Population", "Cases", "Deaths"), 0) |> formatRound(c("Case fatality (%)", "Per 100,000"), 2) |>
      formatStyle("Per 100,000", background = styleColorBar(c(0, max(d$`Per 100,000`, 1, na.rm = TRUE)), "#cde2fb"),
                  backgroundSize = "98% 70%", backgroundRepeat = "no-repeat", backgroundPosition = "center")
  })
  output$dl_disease <- downloadHandler(
    filename = function() sprintf("niger-%s-districts-%d.csv", gsub("[^a-z0-9]+", "-", tolower(en(sel()$d))), sel()$y),
    content = function(file) write_csv(district |> filter(disease == sel()$d, year == sel()$y) |>
                                         mutate(disease_en = en(disease), .after = disease), file)
  )

  # Meningitis thresholds ------------------------------------------------------------------------
  men_y <- reactive(menin |> filter(year == as.integer(input$men_year)))
  men_hit <- reactive(men_y() |> group_by(district, region) |>
                        summarise(alert = any(status != "below"), epi = any(status == "epidemic"),
                                  first_alert = suppressWarnings(min(week[status != "below"])),
                                  first_epi = suppressWarnings(min(week[status == "epidemic"])),
                                  epi_weeks = sum(status == "epidemic"), cases = sum(cases),
                                  peak_rate = max(rate_per_100k, na.rm = TRUE), population = first(population),
                                  .groups = "drop"))
  output$men_epi_d <- renderText(num(sum(men_hit()$epi)))
  output$men_alert_d <- renderText(num(sum(men_hit()$alert)))
  output$men_epi_w <- renderText(num(sum(men_y()$status == "epidemic")))
  output$men_peak <- renderText({ r <- men_y() |> slice_max(rate_per_100k, n = 1, with_ties = FALSE); paste0(rate_fmt(r$rate_per_100k), " /100k") })
  output$men_peak_sub <- renderUI({ r <- men_y() |> slice_max(rate_per_100k, n = 1, with_ties = FALSE)
    p(class = "kpi-detail", sprintf("%s, week %d (%s cases)", r$district, r$week, num(r$cases))) })

  output$men_years <- renderPlotly({
    d <- menin |> group_by(year, district) |>
      summarise(alert = any(status != "below"), epi = any(status == "epidemic"), .groups = "drop") |>
      group_by(year) |> summarise(Alert = sum(alert), Epidemic = sum(epi), .groups = "drop")
    plot_ly(d, x = ~year) |>
      add_bars(y = ~Alert, name = "Alert or above", marker = list(color = AMBER),
               text = ~paste0("<b>", year, "</b><br>Districts at alert or above: ", Alert), hoverinfo = "text", textposition = "none") |>
      add_bars(y = ~Epidemic, name = "Epidemic", marker = list(color = DANGER),
               text = ~paste0("<b>", year, "</b><br>Districts at epidemic level: ", Epidemic), hoverinfo = "text", textposition = "none") |>
      layout(barmode = "group", xaxis = list(title = "", dtick = 1), yaxis = list(title = "Districts")) |>
      polish("niger-meningitis-thresholds-by-year")
  })

  output$men_curve <- renderPlotly({
    d <- men_y() |> group_by(week, region) |> summarise(cases = sum(cases), .groups = "drop")
    plot_ly(d, x = ~week, y = ~cases, color = ~region, colors = REGION_COL, type = "bar",
            text = ~paste0("<b>", region, "</b>, week ", week, "<br>Cases: ", num(cases)), hoverinfo = "text", textposition = "none") |>
      layout(barmode = "stack", xaxis = list(title = "Epidemiological week"), yaxis = list(title = "Cases")) |>
      polish(paste0("niger-meningitis-weekly-", input$men_year))
  })

  men_alert_rows <- reactive(men_hit() |> filter(alert) |> arrange(first_alert, region))
  output$men_heat_ui <- renderUI(plotlyOutput("men_heat", height = paste0(max(140, 24 * nrow(men_alert_rows()) + 70), "px")))
  output$men_heat <- renderPlotly({
    hit <- men_alert_rows()
    if (!nrow(hit)) {
      return(plotly_empty(type = "scatter", mode = "markers") |> config(displayModeBar = FALSE) |>
               layout(title = list(text = "No district reached the alert threshold this year.", font = list(size = 13, color = MUTED))))
    }
    lv <- paste0(hit$district, " (", hit$region, ")")
    d <- men_y() |> filter(district %in% hit$district) |>
      mutate(label = factor(paste0(district, " (", region, ")"), levels = rev(lv)),
             code = unname(c(below = 0, alert = 1, epidemic = 2)[status]))
    plot_ly(d, x = ~week, y = ~label, z = ~code, type = "heatmap", zmin = 0, zmax = 2, xgap = 1, ygap = 1, showscale = FALSE,
            colorscale = list(list(0, "#eef0f3"), list(0.33, "#eef0f3"), list(0.34, AMBER), list(0.66, AMBER),
                              list(0.67, DANGER), list(1, DANGER)),
            text = ~paste0("<b>", district, "</b>, week ", week, "<br>Cases: ", num(cases), "<br>Per 100,000: ", rate_fmt(rate_per_100k),
                           "<br>Status: ", status), hoverinfo = "text") |>
      layout(xaxis = list(title = "Epidemiological week", showgrid = FALSE, range = c(0.5, 53.5)),
             yaxis = list(title = "", showgrid = FALSE, tickfont = list(size = 11))) |>
      polish(paste0("niger-meningitis-district-status-", input$men_year), legend = FALSE)
  })

  output$men_table <- render_table({
    d <- men_hit() |> filter(alert) |> arrange(desc(epi_weeks), first_alert) |>
      transmute(District = district, Region = region, Population = population, `First alert week` = first_alert,
                `First epidemic week` = ifelse(is.finite(first_epi), first_epi, NA), `Weeks at epidemic level` = epi_weeks,
                `Cases in year` = cases, `Highest weekly rate /100k` = peak_rate)
    dt(d, paste0("niger-meningitis-districts-", input$men_year)) |>
      formatRound(c("Population", "Cases in year"), 0) |> formatRound("Highest weekly rate /100k", 1)
  })

  # Reporting performance -------------------------------------------------------------------------
  rep_year_tbl <- comp |> group_by(year) |>
    summarise(Timeliness = 100 * mean(on_time), Completeness = 100 * mean(received), missing = sum(status == "N"), .groups = "drop")
  rep_cur <- reactive(rep_year_tbl |> filter(year == as.integer(input$rep_year)))
  rep_prev <- reactive(rep_year_tbl |> filter(year == as.integer(input$rep_year) - 1))
  pp <- function(now, before, yr) {
    if (!length(before)) return(p(class = "kpi-detail", "No comparison"))
    ch <- now - before
    p(class = "kpi-detail", span(class = if (ch >= 0) "baisse" else "hausse", sprintf("%s %+.1f points", if (ch >= 0) "▲" else "▼", ch)), sprintf(" vs %d", yr - 1))
  }
  output$rep_t <- renderText(pct(rep_cur()$Timeliness))
  output$rep_t_sub <- renderUI(pp(rep_cur()$Timeliness, rep_prev()$Timeliness, as.integer(input$rep_year)))
  output$rep_c <- renderText(pct(rep_cur()$Completeness))
  output$rep_c_sub <- renderUI(pp(rep_cur()$Completeness, rep_prev()$Completeness, as.integer(input$rep_year)))
  output$rep_n <- renderText(num(rep_cur()$missing))

  output$rep_trend <- renderPlotly({
    d <- rep_year_tbl |> select(-missing) |> pivot_longer(-year, names_to = "measure", values_to = "value")
    plot_ly(d, x = ~year, y = ~value, color = ~measure, colors = c(Completeness = GREEN, Timeliness = PRIMARY),
            type = "scatter", mode = "lines+markers", line = list(width = 2.2), marker = list(size = 7),
            text = ~paste0("<b>", measure, ", ", year, "</b><br>", pct(value)), hoverinfo = "text") |>
      layout(yaxis = list(title = "% of weekly district reports", range = c(50, 101), ticksuffix = "%"),
             xaxis = list(title = "", dtick = 1)) |>
      polish("niger-reporting-trend")
  })

  output$rep_map <- renderPlotly({
    d <- comp |> filter(year == as.integer(input$rep_year)) |> group_by(region) |>
      summarise(timeliness = 100 * mean(on_time), .groups = "drop")
    region_map(d, "timeliness", "% on time", function(x) pct(x), paste0("niger-timeliness-", input$rep_year),
               zmin = 80, zmax = 100)
  })

  output$rep_heat_ui <- renderUI({
    n <- comp |> filter(year == as.integer(input$rep_year)) |> distinct(district) |> nrow()
    plotlyOutput("rep_heat", height = paste0(15 * n + 80, "px"))
  })
  output$rep_heat <- renderPlotly({
    d <- comp |> filter(year == as.integer(input$rep_year)) |>
      mutate(code = unname(c(N = 0, L = 1, T = 2)[status]), label = paste0(district, " (", region, ")")) |>
      arrange(region, district)
    lv <- unique(d$label)
    plot_ly(d, x = ~week, y = ~factor(label, levels = rev(lv)), z = ~code, type = "heatmap", zmin = 0, zmax = 2,
            colorscale = list(list(0, DANGER), list(0.33, DANGER), list(0.34, AMBER), list(0.66, AMBER),
                              list(0.67, GREEN), list(1, GREEN)), showscale = FALSE, xgap = 1, ygap = 1,
            text = ~paste0("<b>", district, "</b>, week ", week, ": ", c(T = "on time", L = "late", N = "not received")[status]),
            hoverinfo = "text") |>
      layout(xaxis = list(title = "Epidemiological week", showgrid = FALSE),
             yaxis = list(title = "", tickfont = list(size = 10), showgrid = FALSE)) |>
      polish(paste0("niger-report-status-", input$rep_year), legend = FALSE)
  })

  output$rep_2024 <- render_table({
    d <- comp24 |> mutate(level = factor(level, c("national", "region", "district"))) |> arrange(level, region, name) |>
      transmute(Name = ifelse(level == "district", name, toupper(name)), Region = region,
                `Completeness (%)` = completeness_pct, `Timeliness (%)` = timeliness_pct)
    dt(d, "niger-reporting-2024", page = 10) |> formatRound(c("Completeness (%)", "Timeliness (%)"), 1)
  })

  output$rep_dhis <- renderPlotly({
    plot_ly(dhis_comp, x = ~week, y = ~completeness_pct, color = ~region, colors = REGION_COL, type = "scatter",
            mode = "lines", line = list(width = 1.8),
            text = ~paste0("<b>", region, "</b>, week ", week, "<br>", pct(completeness_pct)), hoverinfo = "text") |>
      layout(yaxis = list(title = "Facility completeness", range = c(0, 101), ticksuffix = "%"),
             xaxis = list(title = "Week of 2024")) |>
      polish("niger-dhis2-completeness-2024")
  })

  # Maternal deaths -------------------------------------------------------------------------------
  mat_year_tbl <- maternal |> group_by(year) |>
    summarise(notified = sum(deaths_notified, na.rm = TRUE),
              investigated = if (all(is.na(deaths_investigated))) NA_real_ else sum(deaths_investigated, na.rm = TRUE),
              .groups = "drop") |>
    mutate(share = 100 * investigated / notified)
  mat_cur <- reactive(mat_year_tbl |> filter(year == as.integer(input$mat_year)))
  output$mat_n <- renderText(num(mat_cur()$notified))
  output$mat_i <- renderText(if (is.na(mat_cur()$investigated)) "Not recorded" else num(mat_cur()$investigated))
  output$mat_i_sub <- renderUI(p(class = "kpi-detail", if (is.na(mat_cur()$share)) "" else paste0(pct(mat_cur()$share), " of notified deaths")))

  output$mat_trend <- renderPlotly({
    plot_ly(mat_year_tbl, x = ~year) |>
      add_bars(y = ~notified, name = "Notified", marker = list(color = PRIMARY),
               text = ~paste0("<b>", year, "</b><br>Notified: ", num(notified), "<br>Investigated: ", num(investigated)),
               hoverinfo = "text", textposition = "none") |>
      add_bars(y = ~investigated, name = "Investigated", marker = list(color = LIGHT), hoverinfo = "skip") |>
      add_trace(y = ~share, name = "Share investigated (%)", yaxis = "y2", type = "scatter", mode = "lines+markers",
                line = list(color = WARM, width = 2), marker = list(color = WARM, size = 6),
                text = ~paste0(year, ": ", pct(share), " investigated"), hoverinfo = "text") |>
      layout(barmode = "group", xaxis = list(title = "", dtick = 1), yaxis = list(title = "Maternal deaths"),
             yaxis2 = list(title = "Share investigated (%)", overlaying = "y", side = "right", range = c(0, 100),
                           showgrid = FALSE, ticksuffix = "%")) |>
      polish("niger-maternal-deaths") |>
      layout(margin = list(l = 10, r = 60, t = 10, b = 10))
  })

  output$mat_map <- renderPlotly({
    d <- maternal |> filter(year == as.integer(input$mat_year)) |> group_by(region) |>
      summarise(deaths = sum(deaths_notified, na.rm = TRUE), .groups = "drop")
    region_map(d, "deaths", "Deaths", num, paste0("niger-maternal-deaths-map-", input$mat_year))
  })

  output$mat_weekly <- renderPlotly({
    d <- maternal |> filter(year == as.integer(input$mat_year)) |> group_by(week) |>
      summarise(n = sum(deaths_notified, na.rm = TRUE), .groups = "drop")
    plot_ly(d, x = ~week, y = ~n, type = "bar", marker = list(color = PRIMARY),
            text = ~paste0("Week ", week, ": ", num(n), " deaths"), hoverinfo = "text", textposition = "none") |>
      layout(xaxis = list(title = "Epidemiological week"), yaxis = list(title = "Deaths notified"), bargap = 0.2) |>
      polish(paste0("niger-maternal-deaths-weekly-", input$mat_year), legend = FALSE)
  })

  output$mat_table <- render_table({
    d <- maternal |> filter(year == as.integer(input$mat_year)) |> group_by(District = district, Region = region) |>
      summarise(Notified = sum(deaths_notified, na.rm = TRUE),
                Investigated = if (all(is.na(deaths_investigated))) NA_real_ else sum(deaths_investigated, na.rm = TRUE),
                .groups = "drop") |>
      arrange(desc(Notified))
    dt(d, paste0("niger-maternal-deaths-districts-", input$mat_year), page = 10)
  })

  # DHIS2 2024 ------------------------------------------------------------------------------------
  output$dh_table <- render_table({
    d <- dhis_vs_wb |> group_by(disease) |>
      summarise(wb = sum(workbook_cases, na.rm = TRUE), dh = sum(dhis2_cases, na.rm = TRUE), .groups = "drop") |>
      transmute(Disease = en(disease), `Weekly reports` = wb, DHIS2 = dh, Difference = dh - wb,
                `Difference (%)` = ifelse(wb > 0, 100 * (dh - wb) / wb, NA)) |>
      arrange(desc(`Weekly reports`))
    dt(d, "niger-dhis2-vs-weekly-reports-2024", page = 25) |>
      formatRound(c("Weekly reports", "DHIS2", "Difference"), 0) |> formatRound("Difference (%)", 1) |>
      formatStyle("Difference (%)", color = styleInterval(c(-5, 5), c(DANGER, INK, DANGER)), fontWeight = styleInterval(c(-5, 5), c("600", "400", "600")))
  })

  output$dh_weekly <- renderPlotly({
    d <- dhis_vs_wb |> filter(disease == input$dh_disease)
    plot_ly(d, x = ~week) |>
      add_lines(y = ~workbook_cases, name = "Weekly reports", line = list(color = PRIMARY, width = 2.2)) |>
      add_lines(y = ~dhis2_cases, name = "DHIS2 extract", line = list(color = WARM, width = 2.2, dash = "dot")) |>
      layout(xaxis = list(title = "Week of 2024"), yaxis = list(title = "Cases", rangemode = "tozero"), hovermode = "x unified") |>
      polish(paste0("niger-", en(input$dh_disease), "-dhis2-comparison"))
  })

  output$dh_map <- renderPlotly({
    d <- dhis_cases |> filter(disease == input$dh_disease) |> group_by(region) |> summarise(cases = sum(cases, na.rm = TRUE), .groups = "drop")
    region_map(d, "cases", "Cases", num, paste0("niger-", en(input$dh_disease), "-dhis2-map"))
  })

  # Sources and checks ---------------------------------------------------------------------------
  output$inventory <- render_table({
    d <- inventory |> rename(File = file, Sheets = sheets, Content = content, `How it is used` = how_it_is_used, Output = output)
    datatable(d, rownames = FALSE, class = "compact stripe", options = list(dom = "t", pageLength = 50, scrollX = TRUE))
  })
  output$checks <- render_table({
    d <- checks |> transmute(Check = check, Year = year, Item = item, Reference = reference, Parsed = parsed,
                             Difference = diff, Status = status)
    dt(d, "niger-mdo-validation", page = 15) |>
      formatRound(c("Reference", "Parsed", "Difference"), 0) |>
      formatStyle("Status", fontWeight = "600",
                  color = styleEqual(c("match", "within 1%", "differs", "no reference"), c("#0b7a0b", "#1c5cab", DANGER, MUTED)))
  })
}

shinyApp(ui, server)
