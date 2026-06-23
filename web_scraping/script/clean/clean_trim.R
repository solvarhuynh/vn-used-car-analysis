# ==============================================================================
# Script: clean.R
# Purpose: Clean trim directly inside every SQLite file in init_db/*.db
# Run    : source("clean.R")
# Notes  : This script writes back to the source init databases directly.
#          It does NOT merge data or rebuild master outputs.
# ==============================================================================

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
})

source("web_scraping/script/utils.R")

SCRIPT_NAME <- "clean.R"
INIT_DB_DIR <- "web_scraping/data/init_db"
TABLE_NAME  <- "car_listings"

count_changes <- function(before, after, cols = c("model", "trim")) {
  cols <- intersect(cols, intersect(names(before), names(after)))
  if (!length(cols)) return(0L)

  changed <- logical(nrow(before))
  for (col in cols) {
    b <- before[[col]]
    a <- after[[col]]

    same_na  <- is.na(b) & is.na(a)
    same_val <- !is.na(b) & !is.na(a) & b == a
    changed <- changed | !(same_na | same_val)
  }

  sum(changed)
}

normalize_db_rows <- function(df) {
  df$brand <- clean_brand(df$brand)
  df$model <- clean_model(df$model)
  df$trim  <- normalize_na(df$trim)
  df$color <- normalize_na(df$color)
  df
}

log_message(SCRIPT_NAME, "=== Start cleaning trim directly in init_db/*.db ===")

db_files <- list.files(INIT_DB_DIR, pattern = "\\.db$", full.names = TRUE)

if (!length(db_files)) {
  log_message(SCRIPT_NAME, "No .db files found in init_db/. Nothing to clean.", "WARN")
  stop("No init_db files found.")
}

log_message(SCRIPT_NAME, sprintf("Found %d .db files. Processing...", length(db_files)))

cleaned_files <- 0L
updated_rows <- 0L

for (db_path in db_files) {
  db_name <- basename(db_path)
  con <- NULL

  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), db_path)

    if (!DBI::dbExistsTable(con, TABLE_NAME)) {
      log_message(SCRIPT_NAME, sprintf("Skip %s: table '%s' not found.", db_name, TABLE_NAME), "WARN")
      next
    }

    df <- DBI::dbReadTable(con, TABLE_NAME)
    if (!nrow(df)) {
      log_message(SCRIPT_NAME, sprintf("[%s] Empty table, skipping.", db_name), "INFO")
      next
    }

    if (!all(c("brand", "model", "trim") %in% names(df))) {
      log_message(SCRIPT_NAME, sprintf("[%s] Missing brand/model/trim columns, skipping.", db_name), "WARN")
      next
    }

    df_cleaned <- normalize_db_rows(df)
    df_cleaned <- clean_trim_column(df_cleaned)
    changed <- count_changes(df, df_cleaned, cols = c("model", "trim"))

    DBI::dbWriteTable(con, TABLE_NAME, df_cleaned, overwrite = TRUE, row.names = FALSE)

    log_message(SCRIPT_NAME, sprintf("[%s] Updated %d rows out of %d.", db_name, changed, nrow(df_cleaned)))

    cleaned_files <- cleaned_files + 1L
    updated_rows <- updated_rows + changed
  }, error = function(e) {
    log_message(SCRIPT_NAME, sprintf("Failed on %s: %s", db_name, e$message), "ERROR")
  }, finally = {
    if (!is.null(con)) {
      try(DBI::dbDisconnect(con), silent = TRUE)
    }
  })
}

log_message(SCRIPT_NAME, sprintf(
  "=== Done. Cleaned %d file(s), updated %d row(s) in init_db ===",
  cleaned_files, updated_rows
))

invisible(list(cleaned_files = cleaned_files, updated_rows = updated_rows))
