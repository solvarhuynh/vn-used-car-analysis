# Scrape Bán Xe Hơi Cũ used-car listings by HTML parsing.
# Output: data/data_banxehoicu_raw.csv with the canonical 18-column schema.

suppressPackageStartupMessages({
  library(httr)
  library(rvest)
  library(dplyr)
  library(readr)
  library(stringr)
  library(purrr)
})

source("script/utils.R")

SCRIPT_NAME <- "scrap_banxehoicu.R"
OUTPUT_FILE <- "data/data_banxehoicu_raw.csv"
LISTING_URL <- "https://banxehoicu.vn/ban-oto-cu"
SOURCE_NAME <- "banxehoicu.vn"
DISPLAY_NAME <- "Bán Xe Hơi Cũ"

absolute_url <- function(path) {
  ifelse(str_detect(path, "^https?://"), path, paste0("https://banxehoicu.vn", path))
}

extract_first_text <- function(page, selector) {
  value <- page %>% html_element(selector) %>% html_text2()
  if (length(value) == 0) NA_character_ else value
}

scrape_detail_page <- function(url) {
  detail <- read_html(url)

  # Selectors are intentionally broad boilerplate selectors and should be refined
  # after inspecting the live website markup.
  tibble(
    brand = extract_first_text(detail, ".brand, [data-brand]"),
    model = extract_first_text(detail, ".model, [data-model]"),
    trim = extract_first_text(detail, "h1, .title"),
    year = extract_first_text(detail, ".year, [data-year]"),
    body_type = extract_first_text(detail, ".body-type"),
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

scrape_banxehoicu <- function(max_pages = 1) {
  cat(sprintf("\nStarting %s HTML scraping...\n", DISPLAY_NAME))
  log_message(SCRIPT_NAME, "Starting Bán Xe Hơi Cũ HTML scrape.")

  tryCatch({
    seen_urls <- character()
    rows <- list()

    page_pb <- NULL
    if (max_pages > 0) {
      cat(sprintf("Scanning %s listing page(s)...\n", max_pages))
      page_pb <- txtProgressBar(min = 0, max = max_pages, style = 3)
    }

    for (page_num in seq_len(max_pages)) {
      page_url <- if (page_num == 1) LISTING_URL else paste0(LISTING_URL, "/page/", page_num)
      cat(sprintf("\nReading listing page %s: %s\n", page_num, page_url))
      listing_page <- read_html(page_url)

      links <- listing_page %>%
        html_elements("a") %>%
        html_attr("href") %>%
        na.omit() %>%
        unique() %>%
        keep(~ str_detect(.x, "oto|xe|ban")) %>%
        absolute_url()

      new_links <- setdiff(links, seen_urls)
      seen_urls <- union(seen_urls, new_links)
      cat(sprintf("Found %s new candidate detail links on page %s.\n", length(new_links), page_num))

      if (length(new_links) > 0) {
        detail_pb <- txtProgressBar(min = 0, max = length(new_links), style = 3)
        for (idx in seq_along(new_links)) {
          url <- new_links[[idx]]
          rows[[length(rows) + 1]] <- tryCatch(scrape_detail_page(url), error = function(e) {
            log_message(SCRIPT_NAME, sprintf("Failed detail page %s: %s", url, e$message), "WARN")
            NULL
          })
          setTxtProgressBar(detail_pb, idx)
        }
        close(detail_pb)
        cat("\n")
      } else {
        cat("No detail links to process on this page.\n")
      }

      if (!is.null(page_pb)) setTxtProgressBar(page_pb, page_num)
    }

    if (!is.null(page_pb)) {
      close(page_pb)
      cat("\n")
    }

    df <- if (length(rows) == 0) empty_car_data() else bind_rows(rows) %>% align_schema()
    safe_write_csv(df, OUTPUT_FILE)
    log_message(SCRIPT_NAME, sprintf("Finished Bán Xe Hơi Cũ scrape with %s records.", nrow(df)))
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

banxehoicu_raw <- scrape_banxehoicu()
