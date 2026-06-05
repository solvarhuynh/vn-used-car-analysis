# Initialize SQLite database and import data/master_data.csv.
# Output: data/master_data.db containing table car_listings.

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(readr)
  library(dplyr)
})

source("script/utils.R")

SCRIPT_NAME <- "init_database.R"
DB_FILE <- "data/master_data.db"
MASTER_FILE <- "data/master_data.csv"
TABLE_NAME <- "car_listings"

init_database <- function() {
  log_message(SCRIPT_NAME, "Starting SQLite database initialization.")

  con <- DBI::dbConnect(RSQLite::SQLite(), DB_FILE)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  tryCatch({
    DBI::dbExecute(con, sprintf("DROP TABLE IF EXISTS %s", TABLE_NAME))

    DBI::dbExecute(con, sprintf(
      "CREATE TABLE %s (
        brand TEXT,
        model TEXT,
        trim TEXT,
        year INTEGER,
        body_type TEXT,
        fuel_type TEXT,
        transmission TEXT,
        engine_size REAL,
        seat_count INTEGER,
        drivetrain TEXT,
        price INTEGER,
        mileage INTEGER,
        origin TEXT,
        color TEXT,
        city TEXT,
        posted_date TEXT,
        source TEXT,
        url TEXT PRIMARY KEY
      )",
      TABLE_NAME
    ))

    master <- if (file.exists(MASTER_FILE)) {
      readr::read_csv(MASTER_FILE, show_col_types = FALSE, locale = locale(encoding = "UTF-8")) %>% align_schema()
    } else {
      empty_car_data()
    }

    if (nrow(master) > 0) {
      master <- master %>% mutate(posted_date = as.character(posted_date))
      DBI::dbWriteTable(con, TABLE_NAME, master, append = TRUE)
    }

    log_message(SCRIPT_NAME, sprintf("Initialized database with %s records.", nrow(master)))
    invisible(TRUE)
  }, error = function(e) {
    log_message(SCRIPT_NAME, e$message, "ERROR")
    invisible(FALSE)
  })
}

init_database()
