# Login, same approach as the Ituri dashboard: shinymanager with an encrypted accounts database.
# A server without accounts refuses to start rather than show the data. Only an explicit
# run_app.bat --no-login on this computer (MDO_LOCAL=1) skips it.

auth_required <- function() !identical(Sys.getenv("MDO_LOCAL"), "1")

accounts_path <- function() {
  other <- Sys.getenv("MDO_ACCOUNTS_DB")
  if (nzchar(other)) other else "accounts.sqlite"
}

accounts_secret <- function() {
  # R only reads .Renviron from where it started; the app runs from app/, including once deployed
  if (!nzchar(Sys.getenv("MDO_ACCOUNTS_SECRET")) && file.exists(".Renviron")) readRenviron(".Renviron")
  Sys.getenv("MDO_ACCOUNTS_SECRET")
}

check_auth <- function() {
  if (!auth_required()) return(invisible(TRUE))
  if (!file.exists(accounts_path())) stop("No accounts database: refusing to start. See manage_accounts.bat.", call. = FALSE)
  if (!nzchar(accounts_secret())) stop("MDO_ACCOUNTS_SECRET is missing: refusing to start. See manage_accounts.bat.", call. = FALSE)
  invisible(TRUE)
}

protect_ui <- function(ui, logo = NULL) {
  if (!auth_required()) return(ui)
  shinymanager::secure_app(
    ui, language = "en", enable_admin = FALSE,
    head_auth = shiny::tagList(shiny::tags$link(rel = "stylesheet", href = "style.css"),
                               shiny::tags$link(rel = "stylesheet", href = "mdo.css")),
    tags_top = shiny::tagList(
      if (!is.null(logo)) shiny::img(src = logo, alt = "Médecins Sans Frontières", class = "connexion-logo"),
      shiny::h1(class = "connexion-titre", "Notifiable disease surveillance"),
      shiny::p(class = "connexion-lieu", "Niger, 2015–2024")
    ),
    tags_bottom = shiny::p(class = "connexion-pied", "Access restricted to authorised users.")
  )
}

protect_server <- function() {
  if (!auth_required()) return(invisible(NULL))
  shinymanager::secure_server(
    check_credentials = shinymanager::check_credentials(accounts_path(), passphrase = accounts_secret()),
    timeout = 30
  )
}
