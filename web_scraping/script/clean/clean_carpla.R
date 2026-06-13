# Clean Carpla raw data.
# Output: data/clean/data_carpla_clean.csv

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
})

source("web_scraping/script/utils.R")

SCRIPT_NAME <- "clean_carpla.R"
INPUT_FILE <- "web_scraping/data/raw/data_carpla_raw.csv"
OUTPUT_FILE <- "web_scraping/data/clean/data_carpla_clean.csv"
DISPLAY_NAME <- "Carpla"

clean_carpla <- function() {
  dir.create(dirname(OUTPUT_FILE), showWarnings = FALSE, recursive = TRUE)
  log_message(SCRIPT_NAME, sprintf("Starting %s cleaning.", DISPLAY_NAME))

  if (!file.exists(INPUT_FILE)) {
    log_message(SCRIPT_NAME, "Input file not found.", "ERROR")
    return(invisible(NULL))
  }

  raw <- readr::read_csv(
    INPUT_FILE,
    col_types = cols(.default = "c"),
    show_col_types = FALSE,
    locale = locale(encoding = "UTF-8")
  )

  if (nrow(raw) == 0) {
    log_message(SCRIPT_NAME, "Raw data is empty.", "WARN")
    return(invisible(NULL))
  }

  df_final <- standardize_car_data(raw) %>%
    filter_clean_business_rules() %>%
    distinct(url, .keep_all = TRUE)

  safe_write_csv(df_final, OUTPUT_FILE)
  log_message(SCRIPT_NAME, sprintf("Finished %s cleaning with %s rows.", DISPLAY_NAME, nrow(df_final)))
  return(df_final)
}

# Execute automatically when sourced
carpla_clean <- clean_carpla()
