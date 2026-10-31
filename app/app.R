# Niger MDO surveillance dashboard, 2015-2024
# Run from the project root:  conda activate mdo-niger ; Rscript -e "shiny::runApp('app')"
# Reads the tables built by scripts/run_all.py (data/processed), including regions.geojson made from data/shp.

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

ROOT <- normalizePath(file.path(getwd(), ".."), mustWork = TRUE)
if (!dir.exists(file.path(ROOT, "data", "processed"))) ROOT <- getwd()
rd <- function(f) read_csv(file.path(ROOT, "data", "processed", f), show_col_types = FALSE,
                           locale = locale(encoding = "UTF-8"))

years_tbl     <- rd("mdo_years.csv")
annual        <- rd("mdo_annual.csv")
weekly        <- rd("mdo_weekly.csv")
weekly_region <- rd("mdo_weekly_region.csv")
regional      <- rd("mdo_regional.csv")
district      <- rd("mdo_district.csv")
summary_tbl   <- rd("mdo_summary.csv")
comp          <- rd("completeness_weekly.csv")
comp24        <- rd("completeness_2024_cumulative.csv")
dhis          <- rd("dhis2_2024_weekly.csv")
dhis_vs_wb    <- rd("dhis2_vs_workbook_2024.csv")
maternal      <- rd("maternal_deaths.csv")
checks        <- rd("validation_checks.csv")
inventory     <- read_csv(file.path(ROOT, "data", "data_inventory.csv"), show_col_types = FALSE)

regions_geo <- read_json(file.path(ROOT, "data", "processed", "regions.geojson"))
region_names <- vapply(regions_geo$features, function(f) f$properties$region, "")

diseases <- summary_tbl |> filter(total_cases > 0) |> pull(disease)
last_week_2024 <- years_tbl$last_week[years_tbl$year == 2024]
pop_by_region <- regional |> filter(disease == "Rougeole") |> select(year, region, population)

# ---- helpers ------------------------------------------------------------------------------------

ACCENT <- "#1f5f8b"
num <- function(x, d = 0) ifelse(is.na(x), "–", comma(x, accuracy = 10^-d))
pct <- function(x, d = 1) ifelse(is.na(x), "–", paste0(number(x, accuracy = 10^-d), "%"))
rate_fmt <- function(x) ifelse(is.na(x), "–", ifelse(x >= 100, comma(x, accuracy = 1),
                                                     ifelse(x >= 1, number(x, accuracy = 0.1), number(x, accuracy = 0.01))))
no_bar <- function(p) config(p, displaylogo = FALSE, modeBarButtonsToRemove = c("lasso2d", "select2d"))

region_map <- function(df, value, label, fmt = num, low = "#eef3f8", high = ACCENT) {
  m <- tibble(region = region_names) |> left_join(df, by = "region")
  z <- m[[value]]
  plot_ly(type = "choropleth", geojson = regions_geo, featureidkey = "properties.region",
          locations = m$region, z = ifelse(is.na(z), 0, z),
          colorscale = list(c(0, low), c(1, high)), zmin = 0,
          text = paste0(m$region, "<br>", label, ": ", fmt(z)), hoverinfo = "text",
          marker = list(line = list(color = "white", width = 1)),
          colorbar = list(title = "", thickness = 12)) |>
    layout(geo = list(fitbounds = "locations", visible = FALSE),
           margin = list(l = 0, r = 0, t = 0, b = 0)) |> no_bar()
}

dt <- function(df, ...) {
  datatable(df, rownames = FALSE, filter = "top", extensions = "Buttons",
            options = list(pageLength = 15, scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv", "excel"), ...))
}

# ---- UI -----------------------------------------------------------------------------------------

# system fonts only, so the app also runs offline
theme <- bs_theme(version = 5, primary = ACCENT,
                  base_font = font_collection("Segoe UI", "Helvetica Neue", "Arial", "sans-serif"),
                  heading_font = font_collection("Georgia", "Cambria", "Times New Roman", "serif"))

card_plot <- function(title, output, note = NULL, height = "380px") {
  card(full_screen = TRUE, card_header(title),
       if (!is.null(note)) p(class = "text-muted small mb-1", note),
       plotlyOutput(output, height = height))
}

ui <- page_navbar(
  title = "Niger MDO surveillance 2015–2024",
  theme = theme,
  fillable = FALSE,

  nav_panel(
    "Overview",
    layout_column_wrap(
      width = 1 / 4,
      value_box("Years covered", "2015–2024", p(paste0("2024 up to week ", last_week_2024))),
      value_box("Diseases tracked", length(unique(annual$disease)), p("Sheets in the weekly workbooks")),
      value_box("Health districts", max(years_tbl$districts), p("72 since the 2017 split")),
      value_box("Population 2024", number(max(years_tbl$population) / 1e6, accuracy = 0.1, suffix = " M"),
                p("Sum of district populations"))
    ),
    card(card_header("All diseases at a glance"),
         p(class = "text-muted small", "Totals over the years each disease appears in the workbooks."),
         DTOutput("overview_table")),
    card_plot("Cases per year, main epidemic-prone diseases", "overview_trends",
              "Each panel has its own scale. 2024 covers weeks 1 to the last reported week only.", "560px")
  ),

  nav_panel(
    "Disease explorer",
    layout_sidebar(
      sidebar = sidebar(
        selectInput("disease", "Disease", diseases, selected = "Rougeole"),
        selectInput("year", "Year (map, regions, districts)", sort(unique(annual$year), decreasing = TRUE), selected = 2023),
        radioButtons("metric", "Map metric", c("Cases per 100,000" = "incidence_per_100k", "Cases" = "cases",
                                                "Deaths" = "deaths")),
        p(class = "text-muted small", "Incidence uses the district populations listed in each year's workbook.")
      ),
      layout_column_wrap(
        width = 1 / 4,
        value_box("Cases, all years", textOutput("vb_cases")),
        value_box("Deaths, all years", textOutput("vb_deaths")),
        value_box("Case fatality", textOutput("vb_cfr")),
        value_box("Peak year", textOutput("vb_peak"))
      ),
      layout_column_wrap(
        width = 1 / 2,
        card_plot("Cases per year", "annual_plot", "Bars: cases. Line: case fatality (%). The 2024 bar is lighter (partial year)."),
        card_plot("Weekly cases by year", "week_heat", "Each cell is one epidemiological week (square-root colour scale).")
      ),
      layout_column_wrap(
        width = 1 / 2,
        card_plot("Map by region", "disease_map"),
        card_plot("Weekly cases by region", "region_curve", "Selected year.")
      ),
      card(card_header("Districts"), p(class = "text-muted small", "Selected year, ranked by incidence."),
           DTOutput("district_table"))
    )
  ),

  nav_panel(
    "Reporting",
    layout_sidebar(
      sidebar = sidebar(
        selectInput("rep_year", "Year", 2015:2023, selected = 2023),
        p(class = "text-muted small",
          "2015–2023: each district's weekly report is coded on time (T), late (L) or not received (N). ",
          "Timeliness = share on time; completeness = share received."),
        p(class = "text-muted small",
          "2024 comes from other measures (cumulative % in the S43 workbook, weekly facility % in DHIS2) ",
          "and is shown separately below.")
      ),
      layout_column_wrap(
        width = 1 / 2,
        card_plot("National timeliness and completeness by year", "rep_trend"),
        card_plot("Timeliness by region", "rep_map", "Selected year, % of weekly reports on time.")
      ),
      card_plot("Weekly report status by district", "rep_heat",
                "Green: on time. Orange: late. Red: not received. Grey: no code.", "820px"),
      layout_column_wrap(
        width = 1 / 2,
        card(card_header(paste0("2024 cumulative completeness and timeliness (to week ", last_week_2024, ")")),
             DTOutput("rep_2024")),
        card_plot("2024 weekly completeness in DHIS2 (% of facilities), by region", "rep_dhis",
                  "Average of district percentages.")
      )
    )
  ),

  nav_panel(
    "Maternal deaths",
    layout_sidebar(
      sidebar = sidebar(
        selectInput("mat_year", "Year", 2015:2021, selected = 2021),
        p(class = "text-muted small",
          "Weekly maternal death notifications, 2015–2021. The workbooks from 2022 on have no maternal-death sheet. ",
          "2015 has no 'investigated' column.")
      ),
      layout_column_wrap(
        width = 1 / 2,
        card_plot("Deaths notified and investigated per year", "mat_trend"),
        card_plot("Deaths notified by region", "mat_map", "Selected year.")
      ),
      layout_column_wrap(
        width = 1 / 2,
        card_plot("Weekly deaths notified", "mat_weekly", "Selected year."),
        card(card_header("Districts"), DTOutput("mat_table"))
      )
    )
  ),

  nav_panel(
    "DHIS2 2024",
    layout_sidebar(
      sidebar = sidebar(
        selectInput("dh_disease", "Disease", sort(unique(dhis$disease)), selected = "Choléra"),
        p(class = "text-muted small",
          "The DHIS2 extract (18 Sept 2024) covers weeks 1–37. It is compared here with the 2024 workbook ",
          "over the same weeks. The workbook is used everywhere else in the app.")
      ),
      card(card_header("Weeks 1–37: DHIS2 extract vs 2024 workbook"), DTOutput("dh_table")),
      layout_column_wrap(
        width = 1 / 2,
        card_plot("Weekly national cases, both sources", "dh_weekly"),
        card_plot("DHIS2 cases by region, weeks 1–37", "dh_map")
      )
    )
  ),

  nav_panel(
    "Data & checks",
    card(card_header("What each source file contributes"), DTOutput("inventory")),
    card(card_header("Cross-checks against the totals in the source files"),
         p(class = "text-muted small",
           "'parsed' is this app's number; 'reference' is the total written in the source file. ",
           "Where they differ, the source file's own total row is usually wrong (e.g. 2019 influenza: districts add up to 14, the total cell says 127)."),
         DTOutput("checks")),
    card(card_header("Caveats"),
         tags$ul(
           tags$li("2024 workbook stops at week ", last_week_2024, "; the DHIS2 extract stops at week 37."),
           tags$li("Health districts were reorganised in 2017 (44–48 before, 72 after). Compare districts only from 2017; regions are comparable across all years."),
           tags$li("Confirmed malaria 2015–2020 is the number of positive rapid tests or slides; from 2021 it is the confirmed-case column. Malaria deaths move from 'suspected' to 'confirmed' in 2021."),
           tags$li("Suspected malaria in 2018 looks incomplete (lower than confirmed malaria that year)."),
           tags$li("Malnutrition is reported until 2021, malaria in pregnant women is missing in 2020–2021, COVID-19 starts in 2021, dengue in 2023. MERS-CoV, SARS and Guinea worm have no cases."),
           tags$li("The DHIS2 'Synthèse' sheet is older than the extract's weekly sheets (lower cholera and malaria totals); the weekly sheets match the extract's cumulative sheet exactly."),
           tags$li("Viral haemorrhagic fever cases in the 2024 workbook appear as Rift Valley fever in DHIS2.")
         ))
  ),
  nav_spacer(),
  nav_item(tags$span(class = "text-muted small", "Source: MDO weekly workbooks, Niger"))
)

# ---- server -------------------------------------------------------------------------------------

server <- function(input, output, session) {

  # Overview
  output$overview_table <- renderDT({
    summary_tbl |>
      transmute(Disease = disease, Cases = total_cases, Deaths = total_deaths, `Case fatality %` = cfr_pct,
                `Peak year` = ifelse(total_cases > 0, peak_year, NA), `Years reported` = years_reported,
                From = first_year, To = last_year) |>
      dt() |> formatRound(c("Cases", "Deaths"), 0) |> formatRound("Case fatality %", 2)
  })

  output$overview_trends <- renderPlotly({
    keep <- c("Rougeole", "Méningite", "Choléra", "Diphtérie", "Paludisme confirmé", "Malnutrition sévère",
              "Coqueluche", "Fièvre jaune (suspect)", "PFA")
    d <- annual |> filter(disease %in% keep) |> mutate(disease = factor(disease, keep))
    p <- ggplot(d, aes(year, cases, text = paste0(disease, " ", year, "<br>Cases: ", num(cases), "<br>Deaths: ", num(deaths)))) +
      geom_col(aes(fill = partial_year)) +
      scale_fill_manual(values = c(`FALSE` = ACCENT, `TRUE` = "#9fbad0"), guide = "none") +
      scale_y_continuous(labels = label_comma()) +
      scale_x_continuous(breaks = seq(2015, 2024, 3)) +
      facet_wrap(~disease, scales = "free_y", ncol = 3) +
      labs(x = NULL, y = NULL) + theme_minimal(base_size = 11)
    ggplotly(p, tooltip = "text") |> no_bar()
  })

  # Disease explorer
  sel_sum <- reactive(summary_tbl |> filter(disease == input$disease))
  output$vb_cases  <- renderText(num(sel_sum()$total_cases))
  output$vb_deaths <- renderText(num(sel_sum()$total_deaths))
  output$vb_cfr    <- renderText(pct(sel_sum()$cfr_pct, 2))
  output$vb_peak   <- renderText(paste0(sel_sum()$peak_year, " (", num(sel_sum()$peak_cases), " cases)"))

  output$annual_plot <- renderPlotly({
    d <- annual |> filter(disease == input$disease)
    plot_ly(d, x = ~year) |>
      add_bars(y = ~cases, name = "Cases", marker = list(color = ACCENT, opacity = ifelse(d$partial_year, 0.45, 1)),
               text = ~paste0(year, ifelse(partial_year, " (partial)", ""), "<br>Cases: ", num(cases),
                              "<br>Deaths: ", num(deaths), "<br>Per 100,000: ", rate_fmt(incidence_per_100k)),
               hoverinfo = "text", textposition = "none") |>
      add_lines(y = ~cfr_pct, name = "Case fatality %", yaxis = "y2", line = list(color = "#c0392b", width = 2),
                hoverinfo = "skip") |>
      layout(yaxis = list(title = "Cases"), xaxis = list(title = "", dtick = 1),
             yaxis2 = list(title = "Case fatality %", overlaying = "y", side = "right", rangemode = "tozero"),
             legend = list(orientation = "h", y = -0.15)) |> no_bar()
  })

  output$week_heat <- renderPlotly({
    d <- weekly |> filter(disease == input$disease)
    plot_ly(d, x = ~week, y = ~factor(year), z = ~sqrt(cases), type = "heatmap",
            colors = colorRamp(c("#f4f6f8", ACCENT, "#0b2a40")), showscale = FALSE,
            text = ~paste0(year, " week ", week, "<br>Cases: ", num(cases), "<br>Deaths: ", num(deaths)),
            hoverinfo = "text") |>
      layout(xaxis = list(title = "Epidemiological week"), yaxis = list(title = "", autorange = "reversed")) |> no_bar()
  })

  output$disease_map <- renderPlotly({
    d <- regional |> filter(disease == input$disease, year == input$year)
    lab <- c(incidence_per_100k = "Cases per 100,000", cases = "Cases", deaths = "Deaths")[[input$metric]]
    region_map(d, input$metric, lab, if (input$metric == "incidence_per_100k") rate_fmt else num)
  })

  output$region_curve <- renderPlotly({
    d <- weekly_region |> filter(disease == input$disease, year == input$year)
    plot_ly(d, x = ~week, y = ~cases, color = ~region, type = "scatter", mode = "lines",
            text = ~paste0(region, ", week ", week, "<br>Cases: ", num(cases)), hoverinfo = "text") |>
      layout(xaxis = list(title = "Epidemiological week"), yaxis = list(title = "Cases"),
             legend = list(orientation = "h", y = -0.2)) |> no_bar()
  })

  output$district_table <- renderDT({
    district |> filter(disease == input$disease, year == input$year) |>
      arrange(desc(incidence_per_100k)) |>
      transmute(District = district, Region = region, Population = population, Cases = cases, Deaths = deaths,
                `Case fatality %` = cfr_pct, `Per 100,000` = incidence_per_100k) |>
      dt() |> formatRound(c("Population", "Cases", "Deaths"), 0) |> formatRound(c("Case fatality %", "Per 100,000"), 2)
  })

  # Reporting
  rep_year_tbl <- comp |> group_by(year) |>
    summarise(Timeliness = 100 * mean(on_time), Completeness = 100 * mean(received), .groups = "drop")

  output$rep_trend <- renderPlotly({
    d <- rep_year_tbl |> pivot_longer(-year, names_to = "measure", values_to = "pct")
    plot_ly(d, x = ~year, y = ~pct, color = ~measure, colors = c(ACCENT, "#e08e0b"), type = "scatter",
            mode = "lines+markers", text = ~paste0(measure, " ", year, ": ", pct(pct)), hoverinfo = "text") |>
      layout(yaxis = list(title = "% of weekly district reports", range = c(0, 101)), xaxis = list(title = "", dtick = 1),
             legend = list(orientation = "h", y = -0.15)) |> no_bar()
  })

  output$rep_map <- renderPlotly({
    d <- comp |> filter(year == input$rep_year) |> group_by(region) |>
      summarise(timeliness = 100 * mean(on_time), .groups = "drop")
    region_map(d, "timeliness", "On time", function(x) pct(x))
  })

  output$rep_heat <- renderPlotly({
    d <- comp |> filter(year == input$rep_year) |>
      mutate(code = unname(c(N = 0, L = 1, T = 2)[status]), label = paste0(district, " (", region, ")")) |>
      arrange(region, district)
    lv <- unique(d$label)
    plot_ly(d, x = ~week, y = ~factor(label, levels = rev(lv)), z = ~code, type = "heatmap", zmin = 0, zmax = 2,
            colorscale = list(c(0, "#d7301f"), c(0.5, "#fdae61"), c(1, "#1a9850")), showscale = FALSE,
            text = ~paste0(district, ", week ", week, ": ", c(T = "on time", L = "late", N = "not received")[status]),
            hoverinfo = "text", xgap = 1, ygap = 1) |>
      layout(xaxis = list(title = "Epidemiological week"), yaxis = list(title = "", tickfont = list(size = 10))) |> no_bar()
  })

  output$rep_2024 <- renderDT({
    comp24 |> transmute(Level = level, Name = name, Region = region, `Completeness %` = completeness_pct,
                        `Timeliness %` = timeliness_pct) |>
      dt() |> formatRound(c("Completeness %", "Timeliness %"), 1)
  })

  output$rep_dhis <- renderPlotly({
    d <- dhis |> distinct(week, region, district, completeness_pct) |>
      group_by(week, region) |> summarise(pct = mean(completeness_pct, na.rm = TRUE), .groups = "drop")
    plot_ly(d, x = ~week, y = ~pct, color = ~region, type = "scatter", mode = "lines",
            text = ~paste0(region, ", week ", week, ": ", pct(pct)), hoverinfo = "text") |>
      layout(yaxis = list(title = "% completeness", range = c(0, 101)), xaxis = list(title = "Week 2024"),
             legend = list(orientation = "h", y = -0.2)) |> no_bar()
  })

  # Maternal deaths
  output$mat_trend <- renderPlotly({
    d <- maternal |> group_by(year) |>
      summarise(Notified = sum(deaths_notified, na.rm = TRUE),
                Investigated = if (all(is.na(deaths_investigated))) NA_real_ else sum(deaths_investigated, na.rm = TRUE),
                .groups = "drop") |>
      mutate(share = 100 * Investigated / Notified)
    plot_ly(d, x = ~year) |>
      add_bars(y = ~Notified, name = "Notified", marker = list(color = ACCENT),
               text = ~paste0(year, "<br>Notified: ", num(Notified), "<br>Investigated: ", num(Investigated),
                              " (", pct(share), ")"), hoverinfo = "text", textposition = "none") |>
      add_bars(y = ~Investigated, name = "Investigated", marker = list(color = "#e08e0b"), hoverinfo = "skip") |>
      layout(barmode = "group", xaxis = list(title = "", dtick = 1), yaxis = list(title = "Maternal deaths"),
             legend = list(orientation = "h", y = -0.15)) |> no_bar()
  })

  output$mat_map <- renderPlotly({
    d <- maternal |> filter(year == input$mat_year) |> group_by(region) |>
      summarise(deaths = sum(deaths_notified, na.rm = TRUE), .groups = "drop")
    region_map(d, "deaths", "Deaths notified")
  })

  output$mat_weekly <- renderPlotly({
    d <- maternal |> filter(year == input$mat_year) |> group_by(week) |>
      summarise(n = sum(deaths_notified, na.rm = TRUE), .groups = "drop")
    plot_ly(d, x = ~week, y = ~n, type = "bar", marker = list(color = ACCENT),
            text = ~paste0("Week ", week, ": ", num(n)), hoverinfo = "text", textposition = "none") |>
      layout(xaxis = list(title = "Epidemiological week"), yaxis = list(title = "Deaths notified")) |> no_bar()
  })

  output$mat_table <- renderDT({
    maternal |> filter(year == input$mat_year) |> group_by(District = district, Region = region) |>
      summarise(Notified = sum(deaths_notified, na.rm = TRUE),
                Investigated = if (all(is.na(deaths_investigated))) NA_real_ else sum(deaths_investigated, na.rm = TRUE),
                .groups = "drop") |>
      arrange(desc(Notified)) |> dt()
  })

  # DHIS2
  output$dh_table <- renderDT({
    dhis_vs_wb |> group_by(Disease = disease) |>
      summarise(`Workbook cases` = sum(workbook_cases, na.rm = TRUE), `DHIS2 cases` = sum(dhis2_cases, na.rm = TRUE),
                .groups = "drop") |>
      mutate(Difference = `DHIS2 cases` - `Workbook cases`,
             `Difference %` = ifelse(`Workbook cases` > 0, 100 * Difference / `Workbook cases`, NA)) |>
      arrange(desc(`Workbook cases`)) |>
      dt() |> formatRound(c("Workbook cases", "DHIS2 cases", "Difference"), 0) |> formatRound("Difference %", 1)
  })

  output$dh_weekly <- renderPlotly({
    d <- dhis_vs_wb |> filter(disease == input$dh_disease)
    plot_ly(d, x = ~week) |>
      add_lines(y = ~workbook_cases, name = "2024 workbook", line = list(color = ACCENT, width = 2)) |>
      add_lines(y = ~dhis2_cases, name = "DHIS2 extract", line = list(color = "#e08e0b", width = 2, dash = "dot")) |>
      layout(xaxis = list(title = "Week 2024"), yaxis = list(title = "Cases"), hovermode = "x unified",
             legend = list(orientation = "h", y = -0.15)) |> no_bar()
  })

  output$dh_map <- renderPlotly({
    d <- dhis |> filter(disease == input$dh_disease) |> group_by(region) |>
      summarise(cases = sum(cases, na.rm = TRUE), .groups = "drop")
    region_map(d, "cases", "Cases")
  })

  # Data & checks
  output$inventory <- renderDT(datatable(inventory, rownames = FALSE, options = list(dom = "t", pageLength = 50, scrollX = TRUE)))
  output$checks <- renderDT({
    checks |> mutate(status = factor(status)) |> dt() |> formatRound(c("reference", "parsed", "diff"), 2)
  })
}

shinyApp(ui, server)
