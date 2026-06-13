# ==============================================================================
# Script: validate_clean_data.R
# Purpose: Validate cleaned CSV files against canonical schema and business rules
# Output: web_scraping/data/quality_report/*
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("web_scraping/script/utils.R")

SCRIPT_NAME <- "web_scraping/script/validate_clean_data.R"
CLEAN_DIR <- "web_scraping/data/clean"
REPORT_DIR <- "web_scraping/data/quality_report"
CURRENT_YEAR <- as.integer(format(Sys.Date(), "%Y"))

dir.create(REPORT_DIR, recursive = TRUE, showWarnings = FALSE)
log_message(SCRIPT_NAME, "Starting clean data validation.")

clean_files <- list.files(CLEAN_DIR, pattern = "^data_.*_clean\\.csv$", full.names = TRUE)

if (!length(clean_files)) {
  log_message(SCRIPT_NAME, "No cleaned CSV files found.", "WARN")
  quit(save = "no", status = 0)
}

source_reports <- lapply(clean_files, function(path) {
  df <- read_clean_csv(path)
  missing_cols <- setdiff(CANONICAL_COLS, names(df))
  extra_cols <- setdiff(names(df), CANONICAL_COLS)
  source_name <- sub("^data_(.*)_clean\\.csv$", "\\1", basename(path))

  numeric_df <- df %>%
    mutate(
      year = suppressWarnings(as.integer(year)),
      price = suppressWarnings(as.numeric(price)),
      mileage = suppressWarnings(as.numeric(mileage))
    )

  data.frame(
    source = source_name,
    file = path,
    rows = nrow(df),
    schema_ok = identical(names(df), CANONICAL_COLS),
    missing_cols = paste(missing_cols, collapse = ";"),
    extra_cols = paste(extra_cols, collapse = ";"),
    duplicate_url = sum(duplicated(df$url[!is.na(df$url) & df$url != ""])),
    invalid_year = sum(is.na(numeric_df$year) | numeric_df$year < 1990 | numeric_df$year > CURRENT_YEAR),
    invalid_price = sum(is.na(numeric_df$price) | numeric_df$price < 5e7 | numeric_df$price > 1.5e10),
    invalid_mileage = sum(is.na(numeric_df$mileage) | numeric_df$mileage < 0 | numeric_df$mileage > 1e6),
    blank_identity = sum(is.na(df$brand) | df$brand == "" | is.na(df$model) | df$model == "" | is.na(df$url) | df$url == ""),
    stringsAsFactors = FALSE
  )
})

quality_summary <- bind_rows(source_reports)
all_clean <- bind_rows(lapply(clean_files, read_clean_csv))

duplicate_urls <- all_clean %>%
  filter(!is.na(url), url != "") %>%
  count(url, sort = TRUE) %>%
  filter(n > 1)

outlier_rows <- all_clean %>%
  mutate(
    year = suppressWarnings(as.integer(year)),
    price = suppressWarnings(as.numeric(price)),
    mileage = suppressWarnings(as.numeric(mileage))
  ) %>%
  filter(
    is.na(year) | year < 1990 | year > CURRENT_YEAR |
      is.na(price) | price < 5e7 | price > 1.5e10 |
      is.na(mileage) | mileage < 0 | mileage > 1e6
  )

readr::write_csv(quality_summary, file.path(REPORT_DIR, "quality_summary.csv"), na = "")
readr::write_csv(duplicate_urls, file.path(REPORT_DIR, "duplicate_urls.csv"), na = "")
readr::write_csv(outlier_rows, file.path(REPORT_DIR, "outlier_rows.csv"), na = "")

report_txt <- c(
  "Clean Data Quality Report",
  paste("Generated at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  paste("Files checked:", length(clean_files)),
  paste("Total clean rows:", nrow(all_clean)),
  paste("Duplicate URLs:", nrow(duplicate_urls)),
  paste("Outlier rows:", nrow(outlier_rows)),
  "",
  capture.output(print(quality_summary))
)

writeLines(report_txt, file.path(REPORT_DIR, "quality_report.txt"), useBytes = TRUE)
log_message(SCRIPT_NAME, sprintf("Validation complete. Reports written to %s.", REPORT_DIR))
