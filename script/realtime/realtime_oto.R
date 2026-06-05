# Real-time Oto.com.vn delta fetch.
suppressPackageStartupMessages({
  library(httr)
  library(rvest)
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(stringr)
  library(purrr)
})

source("script/utils.R")

SCRIPT_NAME <- "realtime_oto.R"
DB_FILE <- "data/master_data.db"
TABLE_NAME <- "car_listings"
LISTING_URL <- "https://oto.com.vn/mua-ban-xe"
SOURCE_NAME <- "oto.com.vn"

absolute_url <- function(path) ifelse(str_detect(path, "^https?://"), path, paste0("https://oto.com.vn", path))
extract_first_text <- function(page, selector) {
  value <- page %>% html_element(selector) %>% html_text2()
  if (length(value) == 0) NA_character_ else value
}

scrape_detail_page <- function(url) {
  detail <- read_html(url)
  tibble(
    brand = extract_first_text(detail, ".brand, [data-brand]"),
    model = extract_first_text(detail, ".model, [data-model]"),
    trim = extract_first_text(detail, "h1, .title"),
    year = extract_first_text(detail, ".year, [data-year]"),
    body_type = extract_first_text(detail, ".body-type, .style"),
    fuel_type = extract_first_text(detail, ".fuel, .fuel-type"),
    transmission = extract_first_text(detail, ".transmission, .gearbox"),
    engine_size = extract_first_text(detail, ".engine, .engine-size"),
    seat_count = extract_first_text(detail, ".seats, .seat-count"),
    drivetrain = extract_first_text(detail, ".drivetrain, .drive-type"),
    price = extract_first_text(detail, ".price"),
    mileage = extract_first_text(detail, ".mileage, .odo"),
    origin = extract_first_text(detail, ".origin"),
    color = extract_first_text(detail, ".color"),
    city = extract_first_text(detail, ".location, .city"),
    posted_date = extract_first_text(detail, ".posted-date, time"),
    source = SOURCE_NAME,
    url = url
  )
}

insert_new_oto_records <- function() {
  cat("\nStarting Oto.com.vn real-time delta fetch...\n")
  log_message(SCRIPT_NAME, "Starting Oto.com.vn real-time delta fetch.")

  if (!file.exists(DB_FILE)) stop("Database does not exist.")
  con <- DBI::dbConnect(RSQLite::SQLite(), DB_FILE)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  listing_page <- tryCatch(read_html(LISTING_URL), error = function(e) NULL)
  if (is.null(listing_page)) return(0L)

  links <- listing_page %>%
    html_elements("a") %>% html_attr("href") %>% na.omit() %>% unique() %>%
    keep(~ str_detect(.x, "mua-ban-xe|/xe-")) %>% absolute_url()

  inserted <- 0L
  cat(sprintf("Found %s candidate links. Checking database...\n", length(links)))

  for (url in links) {
    if (DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s WHERE url = ?", TABLE_NAME), params = list(url))$n > 0) {
      cat(sprintf("Encountered existing record (%s). Breaking loop.\n", url))
      break
    }

    raw_row <- tryCatch(scrape_detail_page(url), error = function(e) NULL)
    if (!is.null(raw_row) && nrow(raw_row) > 0) {
      clean_row <- standardize_car_data(raw_row) %>% mutate(posted_date = as.character(posted_date))
      DBI::dbWriteTable(con, TABLE_NAME, clean_row, append = TRUE)
      inserted <- inserted + 1L
      cat(sprintf("Inserted: %s\n", url))
    }
  }
  cat(sprintf("Real-time fetch completed. %s new records inserted.\n", inserted))
}
insert_new_oto_records()