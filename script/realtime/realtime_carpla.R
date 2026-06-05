# Real-time Carpla delta fetch.
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

SCRIPT_NAME <- "realtime_carpla.R"
DB_FILE <- "data/master_data.db"
TABLE_NAME <- "car_listings"
API_ENDPOINT_PAGE_1 <- "https://api-ecom.carpla.vn/app-server/search/car?offset=0&limit=15&saleState=1&type=1"
SOURCE_NAME <- "carpla.vn"

fetch_carpla_page_1 <- function() {
  response <- httr::GET(API_ENDPOINT_PAGE_1, httr::user_agent("R used-car realtime delta fetch"))
  httr::stop_for_status(response)

  payload <- jsonlite::fromJSON(httr::content(response, as = "text", encoding = "UTF-8"), flatten = TRUE)
  cars <- payload$data$content %||% payload$data$items %||% payload$data %||% data.frame()

  if (nrow(cars) == 0) {
    return(empty_car_data())
  }

  slug <- cars$slug %||% cars$url %||% NA_character_

  tibble(
    brand = cars$brand.name %||% cars$brandName %||% cars$brand %||% NA_character_,
    model = cars$model.name %||% cars$modelName %||% cars$model %||% NA_character_,
    trim = cars$versionName %||% cars$name %||% cars$title %||% NA_character_,
    year = cars$year %||% cars$manufactureYear %||% NA_integer_,
    body_type = cars$bodyStyle %||% cars$bodyType %||% NA_character_,
    fuel_type = cars$fuelType %||% NA_character_,
    transmission = cars$transmission %||% NA_character_,
    engine_size = cars$engineCapacity %||% cars$engineSize %||% NA_real_,
    seat_count = cars$seatNumber %||% cars$seatCount %||% NA_integer_,
    drivetrain = cars$driveType %||% NA_character_,
    price = cars$sellingPrice %||% cars$price %||% NA_real_,
    mileage = cars$odo %||% cars$mileage %||% NA_integer_,
    origin = cars$origin %||% NA_character_,
    color = cars$exteriorColor %||% cars$color %||% NA_character_,
    city = cars$province.name %||% cars$city %||% NA_character_,
    posted_date = cars$createdAt %||% cars$publishedAt %||% NA_character_,
    source = SOURCE_NAME,
    url = ifelse(str_detect(slug, "^https?://"), slug, paste0("https://carpla.vn/", slug))
  ) %>%
    standardize_car_data()
}

insert_new_carpla_records <- function() {
  cat("\nStarting Carpla real-time delta fetch...\n")
  log_message(SCRIPT_NAME, "Starting Carpla real-time delta fetch.")

  if (!file.exists(DB_FILE)) stop("Database does not exist. Run script/init_database.R first.")
  con <- DBI::dbConnect(RSQLite::SQLite(), DB_FILE)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  new_rows <- fetch_carpla_page_1()
  inserted <- 0L
  cat(sprintf("Found %s candidate records on Page 1. Checking database...\n", nrow(new_rows)))

  for (i in seq_len(nrow(new_rows))) {
    row <- new_rows[i, ]
    if (is.na(row$url) || row$url == "") next
    if (DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s WHERE url = ?", TABLE_NAME), params = list(row$url))$n > 0) {
      cat(sprintf("Encountered existing record (%s). Breaking loop.\n", row$url))
      break
    }
    DBI::dbWriteTable(con, TABLE_NAME, row %>% mutate(posted_date = as.character(posted_date)), append = TRUE)
    inserted <- inserted + 1L
  }
  cat(sprintf("Real-time fetch completed. %s new records inserted.\n", inserted))
}
insert_new_carpla_records()