# Scrape Carpla used-car listings via API.
# Output: data/data_carpla_raw.csv with the canonical 18-column schema.

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(dplyr)
  library(readr)
  library(stringr)
})

source("script/utils.R")

SCRIPT_NAME <- "scrap_carpla.R"
OUTPUT_FILE <- "data/data_carpla_raw.csv"
API_ENDPOINT <- "https://api-ecom.carpla.vn/app-server/search/car?offset=0&limit=15&saleState=1&type=1"
SOURCE_NAME <- "carpla.vn"
DISPLAY_NAME <- "Carpla"

scrape_carpla <- function() {
  cat(sprintf("\nStarting %s API scraping...\n", DISPLAY_NAME))
  log_message(SCRIPT_NAME, "Starting Carpla API scrape.")

  tryCatch({
    cat(sprintf("Requesting API endpoint: %s\n", API_ENDPOINT))
    response <- httr::GET(API_ENDPOINT, httr::user_agent("R used-car data pipeline"))
    httr::stop_for_status(response)
    cat("API request completed successfully. Parsing JSON response...\n")

    payload <- jsonlite::fromJSON(httr::content(response, as = "text", encoding = "UTF-8"), flatten = TRUE)
    cars <- payload$data$content %||% payload$data$items %||% payload$data %||% data.frame()
    fetched_count <- nrow(cars)
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

    slug <- cars$slug %||% cars$url %||% NA_character_

    df <- tibble(
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
    )

    setTxtProgressBar(pb, 2)
    df <- align_schema(df)
    safe_write_csv(df, OUTPUT_FILE)
    setTxtProgressBar(pb, 3)
    close(pb)
    cat("\n")

    log_message(SCRIPT_NAME, sprintf("Finished Carpla scrape with %s records.", nrow(df)))
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

carpla_raw <- scrape_carpla()
