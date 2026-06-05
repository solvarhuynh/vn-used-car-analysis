# Merge all cleaned source CSV files into one master dataset.
# Output: data/master_data.csv

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("script/utils.R")

SCRIPT_NAME <- "merge_data.R"
OUTPUT_FILE <- "data/master_data.csv"

merge_clean_data <- function() {
  log_message(SCRIPT_NAME, "Starting merge of cleaned datasets.")

  tryCatch({
    clean_files <- list.files("data", pattern = "^data_.*_clean\\.csv$", full.names = TRUE)

    if (length(clean_files) == 0) {
      log_message(SCRIPT_NAME, "No clean CSV files found; writing empty master dataset.", "WARN")
      master <- empty_car_data()
    } else {
      master <- clean_files %>%
        lapply(function(path) readr::read_csv(path, show_col_types = FALSE, locale = locale(encoding = "UTF-8")) %>% align_schema()) %>%
        bind_rows() %>%
        distinct(url, .keep_all = TRUE) %>%
        align_schema()
    }

    safe_write_csv(master, OUTPUT_FILE)
    log_message(SCRIPT_NAME, sprintf("Merged %s files into %s master records.", length(clean_files), nrow(master)))
    master
  }, error = function(e) {
    log_message(SCRIPT_NAME, e$message, "ERROR")
    master <- empty_car_data()
    safe_write_csv(master, OUTPUT_FILE)
    master
  })
}

master_data <- merge_clean_data()
