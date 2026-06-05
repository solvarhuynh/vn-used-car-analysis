# Scrape Chợ Tốt used-car listings via API.
# Output: data/data_chotot_raw.csv with the canonical 18-column schema.

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(dplyr)
  library(readr)
  library(stringr)
})

source("script/utils.R")

SCRIPT_NAME <- "scrap_chotot.R"
OUTPUT_FILE <- "data/data_chotot_raw.csv"
API_ENDPOINT <- "https://gateway.chotot.com/v1/public/ad-listing-video?cg=2010&st=s%2Ck&source=listing&limit=20&o=0"
SOURCE_NAME <- "xe.chotot.com"
DISPLAY_NAME <- "Chợ Tốt"

scrape_chotot <- function() {
  cat(sprintf("\nStarting %s API scraping...\n", DISPLAY_NAME))
  log_message(SCRIPT_NAME, "Starting Chợ Tốt API scrape.")

  tryCatch({
    cat(sprintf("Requesting API endpoint: %s\n", API_ENDPOINT))
    response <- httr::GET(API_ENDPOINT, httr::user_agent("R used-car data pipeline"))
    httr::stop_for_status(response)
    cat("API request completed successfully. Parsing JSON response...\n")

    payload <- jsonlite::fromJSON(httr::content(response, as = "text", encoding = "UTF-8"), flatten = TRUE)
    ads <- payload$ads %||% payload$data %||% data.frame()
    fetched_count <- nrow(ads)
    cat(sprintf("Fetched %s records from %s API.\n", fetched_count, DISPLAY_NAME))

    if (fetched_count == 0) {
      cat("No API records returned. Writing an empty raw CSV with the required schema.\n")
      log_message(SCRIPT_NAME, "API returned zero records.", "WARN")
      df <- empty_car_data()
      safe_write_csv(df, OUTPUT_FILE)
      cat(sprintf("Successfully saved %s raw rows for %s to %s.\n", nrow(df), DISPLAY_NAME, OUTPUT_FILE))
      return(df)
    }

    cat("Mapping API fields into the canonical 18-column schema...\n")
    pb <- txtProgressBar(min = 0, max = 3, style = 3)
    setTxtProgressBar(pb, 1)

    df <- tibble(
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
    )

    setTxtProgressBar(pb, 2)
    df <- align_schema(df)
    safe_write_csv(df, OUTPUT_FILE)
    setTxtProgressBar(pb, 3)
    close(pb)
    cat("\n")

    log_message(SCRIPT_NAME, sprintf("Finished Chợ Tốt scrape with %s records.", nrow(df)))
    cat(sprintf("Successfully saved %s raw rows for %s to %s.\n", nrow(df), DISPLAY_NAME, OUTPUT_FILE))
    df
  }, error = function(e) {
    cat(sprintf("Scraping failed for %s: %s\n", DISPLAY_NAME, e$message))
    log_message(SCRIPT_NAME, e$message, "ERROR")
    df <- empty_car_data()
    safe_write_csv(df, OUTPUT_FILE)
    cat(sprintf("Wrote empty fallback raw file to %s.\n", OUTPUT_FILE))
    df
  })
}

chotot_raw <- scrape_chotot()
