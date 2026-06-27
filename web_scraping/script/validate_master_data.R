# ==============================================================================
# Script: validate_master_data.R
# Purpose: Validate cleaned CSV files before database initialization and merging
# Output: web_scraping/data/quality_report/*.csv and *.txt
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
})

source("web_scraping/script/utils.R")

SCRIPT_NAME <- "web_scraping/script/validate_clean_data.R"
MASTER_DATA_FILE <- "web_scraping/data/master_data.csv"
REPORT_DIR <- "web_scraping/data/quality_report"
CURRENT_YEAR <- as.integer(format(Sys.Date(), "%Y"))

validate_clean_data <- function() {
  dir.create(REPORT_DIR, recursive = TRUE, showWarnings = FALSE)
  log_message(SCRIPT_NAME, "=== Bắt đầu validation dữ liệu master_data.csv ===")

  if (!file.exists(MASTER_DATA_FILE)) {
    stop("Master data file not found: ", MASTER_DATA_FILE)
  }

  path <- MASTER_DATA_FILE

  issue_summary <- tryCatch({
    df <- readr::read_csv(
      path,
      col_types = cols(.default = "c"),
      locale = locale(encoding = "UTF-8"),
      show_col_types = FALSE
    )

    missing_cols <- setdiff(CANONICAL_COLS, names(df))
    extra_cols   <- setdiff(names(df), CANONICAL_COLS)

    numeric_df <- df %>%
      mutate(
        year    = suppressWarnings(as.integer(year)),
        price   = suppressWarnings(as.numeric(price)),
        mileage = suppressWarnings(as.numeric(mileage))
      )

    tibble(
      file         = path,
      source_name  = "master_data",
      rows         = nrow(df),
      schema_ok = length(missing_cols) == 0 && length(extra_cols) == 0,
      missing_cols = paste(missing_cols, collapse = ";"),
      extra_cols   = paste(extra_cols, collapse = ";"),
      duplicate_url = sum(duplicated(df$url[!is.na(df$url) & df$url != ""])),
      missing_brand = sum(is.na(df$brand) | df$brand == ""),
      missing_model = sum(is.na(df$model) | df$model == ""),
      missing_url   = sum(is.na(df$url) | df$url == ""),
      bad_year      = sum(is.na(numeric_df$year) | numeric_df$year < 1990 | numeric_df$year > CURRENT_YEAR),
      bad_price     = sum(is.na(numeric_df$price) | numeric_df$price < 5e7 | numeric_df$price > 1.5e10),
      bad_mileage   = sum(!is.na(numeric_df$mileage) & (numeric_df$mileage < 0 | numeric_df$mileage > 1e6))
    ) %>%
    mutate(
      total_issues = (!schema_ok) + duplicate_url + missing_brand + missing_model +
                     missing_url + bad_year + bad_price + bad_mileage,
      status       = ifelse(total_issues == 0, "OK", "CHECK")
    )
  }, error = function(e) {
    log_message(SCRIPT_NAME, paste("ERROR validating file:", path, "-", e$message), "error")
    return(NULL)
  })

  if (is.null(issue_summary)) {
    stop("Validation failed for master_data.csv. Check logs.")
  }

  readr::write_csv(issue_summary, file.path(REPORT_DIR, "master_data_validation_summary.csv"), na = "")

  report_path <- file.path(REPORT_DIR, "master_data_validation_report.txt")
  report_lines <- capture.output({
    cat("MASTER DATA VALIDATION REPORT\n")
    cat("Generated at: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
    cat("Current year rule: <= ", CURRENT_YEAR, "\n\n", sep = "")
    print(issue_summary)
    cat("\nTotal rows: ", sum(issue_summary$rows), "\n", sep = "")
    cat("Schema OK: ", all(issue_summary$schema_ok), "\n", sep = "")
    cat("Status: ", issue_summary$status[1], "\n", sep = "")
  })
  writeLines(report_lines, report_path, useBytes = TRUE)

  log_message(SCRIPT_NAME, sprintf(
    "=== Validation hoàn thành. %d dòng trong master data, report tại %s ===",
    sum(issue_summary$rows), REPORT_DIR
  ))

  invisible(issue_summary)
}

validate_clean_data()
