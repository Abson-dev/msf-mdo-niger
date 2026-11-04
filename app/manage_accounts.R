# Create or replace the login accounts. Run from the project root:
#   Rscript app/manage_accounts.R first.last other.account     (or manage_accounts.bat first.last other.account)
#
# Replaces the WHOLE database: list every account to keep. Each account gets a new random password,
# written to app/accounts_passwords.csv and never shown on screen. Send each password individually,
# then delete that file. None of this is committed (see .gitignore).

accounts <- commandArgs(trailingOnly = TRUE)
if (!file.exists("app/app.R")) stop("Run this from the project root.", call. = FALSE)
if (!length(accounts)) stop("Give at least one account name.", call. = FALSE)
if (anyDuplicated(accounts)) stop("Duplicate account names.", call. = FALSE)
if (any(!grepl("^[A-Za-z0-9._-]{3,}$", accounts))) stop("Names: at least 3 characters; letters, digits, dot, dash.", call. = FALSE)

random_string <- function(n) {
  alphabet <- c(letters, LETTERS, 0:9)
  # Rejecting bytes outside the range keeps the draw uniform over the alphabet
  bytes <- as.integer(openssl::rand_bytes(n * 4L))
  bytes <- bytes[bytes < 248L]
  paste(alphabet[bytes[seq_len(n)] %% 62L + 1L], collapse = "")
}

env_file <- "app/.Renviron"
if (file.exists(env_file)) readRenviron(env_file)
secret <- Sys.getenv("MDO_ACCOUNTS_SECRET")
if (!nzchar(secret)) {
  secret <- random_string(48L)
  cat(sprintf("MDO_ACCOUNTS_SECRET=%s\n", secret), file = env_file, append = TRUE)
}

passwords <- vapply(accounts, function(.) random_string(20L), character(1))
db <- "app/accounts.sqlite"
if (file.exists(db)) file.remove(db)
shinymanager::create_db(
  credentials_data = data.frame(user = accounts, password = unname(passwords), admin = FALSE, stringsAsFactors = FALSE),
  sqlite_path = db, passphrase = secret
)
utils::write.csv(data.frame(account = accounts, password = unname(passwords)), "app/accounts_passwords.csv", row.names = FALSE)
message(length(accounts), " account(s) created. Passwords: app/accounts_passwords.csv (delete after sending them).")
