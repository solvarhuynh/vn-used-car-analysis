suppressPackageStartupMessages({
  library(readr)
})

source("web_scraping/script/utils.R")

SCRIPT_NAME <- "web_scraping/run_pipeline.R"
RUN_SCRAPE <- identical(tolower(Sys.getenv("RUN_SCRAPE", "false")), "true")

ensure_directories <- function() {
  dirs <- c(
    "web_scraping/data/raw",
    "web_scraping/data/clean",
    "web_scraping/data/init_db",
    "web_scraping/data/quality_report"
  )
  invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))
}

run_task <- function(file, desc) {
  if (!file.exists(file)) stop(sprintf("Missing pipeline task file: %s", file))
  cat(sprintf("\n---> %s\n", desc))
  log_message(SCRIPT_NAME, desc)
  source(file, local = new.env(parent = globalenv()))
}

ensure_directories()
log_message(SCRIPT_NAME, sprintf("Starting pipeline. RUN_SCRAPE=%s", RUN_SCRAPE))

scrape_tasks <- list(
  list(file = "web_scraping/script/scrap/scrap_chotot.R", desc = "Scraping raw data from Chotot"),
  list(file = "web_scraping/script/scrap/scrap_carpla.R", desc = "Scraping raw data from Carpla"),
  list(file = "web_scraping/script/scrap/scrap_banxehoicu.R", desc = "Scraping raw data from Banxehoicu"),
  list(file = "web_scraping/script/scrap/scrap_bonbanh.R", desc = "Scraping raw data from BonBanh")
)

batch_tasks <- list(
  list(file = "web_scraping/script/clean/clean_chotot.R", desc = "Cleaning Chotot data"),
  list(file = "web_scraping/script/clean/clean_carpla.R", desc = "Cleaning Carpla data"),
  list(file = "web_scraping/script/clean/clean_banxehoicu.R", desc = "Cleaning BanXeHoiCu data"),
  list(file = "web_scraping/script/clean/clean_bonbanh.R", desc = "Cleaning BonBanh data"),
  list(file = "web_scraping/script/validate_clean_data.R", desc = "Validating cleaned data"),
  list(file = "web_scraping/script/init_database.R", desc = "Initializing per-source SQLite databases"),
  list(file = "web_scraping/script/merge_data.R", desc = "Merging master database and CSV")
)

tryCatch({
  cat("\n========================================\n")
  cat("   STARTING USED-CAR DATA PIPELINE\n")
  cat("========================================\n")

  tasks <- if (RUN_SCRAPE) c(scrape_tasks, batch_tasks) else batch_tasks
  for (task in tasks) run_task(task$file, task$desc)

  log_message(SCRIPT_NAME, "Pipeline completed successfully.")
  cat("\nPipeline completed successfully.\n")
}, error = function(e) {
  log_message(SCRIPT_NAME, e$message, "ERROR")
  stop(e)
})
