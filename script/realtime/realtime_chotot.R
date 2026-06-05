# Real-time Chợ Tốt delta fetch example.
# Rule: scrape Page 1 only, check each URL against SQLite, INSERT new rows,
# and break immediately when an existing URL is encountered.

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(stringr)
})

source("script/utils.R")

SCRIPT_NAME <- "realtime_chotot.R"
DB_FILE <- "data/master_data.db"
TABLE_NAME <- "car_listings"
API_ENDPOINT_PAGE_1 <- "https://gateway.chotot.com/v1/public/ad-listing-video?cg=2010&st=s%2Ck&source=listing&limit=20&o=0"
SOURCE_NAME <- "xe.chotot.com"

fetch_chotot_page_1 <- function() {
  response <- httr::GET(API_ENDPOINT_PAGE_1, httr::user_agent("R used-car realtime delta fetch"))
  httr::stop_for_status(response)

  payload <- jsonlite::fromJSON(httr::content(response, as = "text", encoding = "UTF-8"), flatten = TRUE)
  ads <- payload$ads %||% payload$data %||% data.frame()

  if (nrow(ads) == 0) {
    return(empty_car_data())
  }

  tibble(
    brand = ads$brand %||% NA_character_,
    model = ads$model %||% NA_character_,
    trim = ads$subject %||% ads$title %||% NA_character_,
    year = ads$caryear %||% ads$year %||% NA_integer_,
    body_type = ads$cartype %||% NA_character_,
    fuel_type = ads$fuel %||% NA_character_,
    transmission = ads$gearbox %||% ads$transmission %||% NA_character_,
    engine_size = ads$engine_capacity %||% NA_real_,
    seat_count = ads$seats %||% NA_integer_,
    drivetrain = ads$drive_type %||% NA_character_,
    price = ads$price %||% NA_real_,
    mileage = ads$mileage %||% ads$mileage_v2 %||% NA_integer_,
    origin = ads$origin %||% NA_character_,
    color = ads$carcolor %||% ads$color %||% NA_character_,
    city = ads$region_name %||% ads$area_name %||% NA_character_,
    posted_date = ads$date %||% ads$list_time %||% NA_character_,
    source = SOURCE_NAME,
    url = ifelse(!is.na(ads$list_id), paste0("https://xe.chotot.com/", ads$list_id, ".htm"), NA_character_)
  ) %>%
    standardize_car_data()
}

insert_new_chotot_records <- function() {
  log_message(SCRIPT_NAME, "Starting Chợ Tốt real-time delta fetch.")

  if (!file.exists(DB_FILE)) {
    log_message(SCRIPT_NAME, "Database does not exist. Run script/init_database.R first.", "ERROR")
    stop("Database does not exist. Run script/init_database.R first.")
  }

  con <- DBI::dbConnect(RSQLite::SQLite(), DB_FILE)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  new_rows <- fetch_chotot_page_1()
  inserted <- 0L

  for (i in seq_len(nrow(new_rows))) {
    row <- new_rows[i, ]

    if (is.na(row$url) || row$url == "") {
      log_message(SCRIPT_NAME, sprintf("Skipping row %s because URL is missing.", i), "WARN")
      next
    }

    existing_count <- DBI::dbGetQuery(
      con,
      sprintf("SELECT COUNT(*) AS n FROM %s WHERE url = ?", TABLE_NAME),
      params = list(row$url)
    )$n

    if (existing_count > 0) {
      log_message(SCRIPT_NAME, sprintf("Existing URL found; breaking delta loop: %s", row$url))
      break
    }

    row <- row %>% mutate(posted_date = as.character(posted_date))
    DBI::dbWriteTable(con, TABLE_NAME, row, append = TRUE)
    inserted <- inserted + 1L
    log_message(SCRIPT_NAME, sprintf("Inserted new listing: %s", row$url))
  }

  log_message(SCRIPT_NAME, sprintf("Completed Chợ Tốt delta fetch. Inserted %s new records.", inserted))
  invisible(inserted)
}

insert_new_chotot_records()
