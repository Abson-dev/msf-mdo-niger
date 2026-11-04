# Visual identity, matching the Ituri dashboard: brand block, page headers, key figures.

# Font Awesome inline SVG (bundled with Shiny, works offline); colour and size come from the CSS
ico <- function(name) shiny::HTML(as.character(fontawesome::fa(name, fill = "currentColor", height = "1em", width = "1em")))

brand <- function(logo) {
  shiny::div(
    class = "marque",
    if (!is.null(logo)) shiny::img(src = logo, alt = "Médecins Sans Frontières", class = "marque-logo"),
    shiny::div(class = "marque-texte",
               shiny::span(class = "marque-titre", "Notifiable disease surveillance"),
               shiny::span(class = "marque-lieu", "Niger, 2015–2024"))
  )
}

page_body <- function(...) shiny::div(class = "page", ...)

page_head <- function(title, text, icon, right = NULL) {
  shiny::div(
    class = "entete-page",
    shiny::div(class = "entete-icone", ico(icon)),
    shiny::div(class = "entete-texte", shiny::h2(title), shiny::p(text)),
    right
  )
}

# tone: bleu, vert, orange, rouge, ambre, ardoise (see style.css)
kpi <- function(title, value, detail, icon, tone = "ardoise") {
  bslib::value_box(title, value, shiny::div(class = "kpi-detail", detail), class = paste0("kpi ton-", tone),
                   showcase = ico(icon), showcase_layout = bslib::showcase_left_center(width = 0.22))
}

kpi_row <- function(...) bslib::layout_column_wrap(width = "200px", fill = FALSE, heights_equal = "row", ...)

# A rise is not coloured as "bad" in green/red: a fall can also come from less reporting
change_tag <- function(ch, label) {
  shiny::tagList(
    shiny::span(class = if (ch >= 0) "hausse" else "baisse",
                sprintf("%s %s%s", if (ch >= 0) "▲" else "▼", if (ch >= 0) "+" else "−", scales::percent(abs(ch), 1))),
    " ", label
  )
}

finding <- function(title, detail) {
  shiny::div(class = "attention", ico("circle-info"), shiny::div(shiny::strong(title), shiny::div(class = "detail", detail)))
}
