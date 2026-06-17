# ==============================================================================
# Script: run_realtime.R
# Purpose: Fetch page-1 deltas and append valid new records to master SQLite DB
# ==============================================================================

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(readr)
})

source("web_scraping/script/utils.R")

SCRIPT_NAME <- "web_scraping/run_realtime.R"
DB_FILE     <- "web_scraping/data/master_data.db"
OUTPUT_CSV  <- "web_scraping/data/master_data.csv"
INIT_DB_DIR <- "web_scraping/data/init_db"

log_message(SCRIPT_NAME, "Starting real-time delta fetch cycle.")
cat("\n========================================\n")
cat("   STARTING REAL-TIME UPDATE CYCLE\n")
cat("========================================\n")

if (!file.exists(DB_FILE)) {
  stop("Master database not found. Run web_scraping/run_pipeline.R first.")
}

# Danh sách đầy đủ 3 nguồn — script tự bỏ qua nếu file chưa có
realtime_scripts <- list(
  list(file = "web_scraping/script/realtime/realtime_chotot.R",     fn = "run_realtime_chotot",     enabled = TRUE),
  list(file = "web_scraping/script/realtime/realtime_banxehoicu.R", fn = "run_realtime_banxehoicu", enabled = FALSE),
  list(file = "web_scraping/script/realtime/realtime_bonbanh.R",    fn = "run_realtime_bonbanh",    enabled = TRUE)
)

con <- DBI::dbConnect(RSQLite::SQLite(), DB_FILE)
on.exit(DBI::dbDisconnect(con), add = TRUE)

# Báo cho các script realtime_*.R biết đang được orchestrator source() —
# để chúng KHÔNG tự gọi hàm run_realtime_xxx() của mình (tránh chạy 2 lần:
# 1 lần tự động khi source, 1 lần do for loop dưới gọi get(task$fn)(con)).
RUN_REALTIME_ORCHESTRATOR <- TRUE

# Bật cờ realtime ở mức Global để các file scrap_xxx.R bỏ qua luồng batch (Step A+B)
assign(".is_realtime_sourcing", TRUE, envir = globalenv())
assign("REALTIME_MODE", TRUE, envir = globalenv())

inserted_total <- 0L

for (task in realtime_scripts) {
  if (isFALSE(task$enabled)) {
    log_message(SCRIPT_NAME, sprintf("Task disabled: %s — skipping.", task$file), "INFO")
    next
  }

  if (!file.exists(task$file)) {
    log_message(SCRIPT_NAME, sprintf("Script not found: %s — skipping.", task$file), "WARN")
    next
  }

  env <- new.env(parent = globalenv())
  source(task$file, local = env)

  if (!exists(task$fn, envir = env)) {
    log_message(SCRIPT_NAME, sprintf("Function not found: %s in %s", task$fn, task$file), "ERROR")
    next
  }

  inserted <- tryCatch(
    get(task$fn, envir = env)(con),
    error = function(e) {
      log_message(SCRIPT_NAME, sprintf("%s failed: %s", task$fn, e$message), "ERROR")
      0L
    }
  )

  inserted_total <- inserted_total + as.integer(inserted)
}

log_message(SCRIPT_NAME, sprintf("Real-time update cycle completed with %d new rows.", inserted_total))

# Rebuild master_data.csv từ tất cả init_db files (an toàn hơn append từng dòng)
# Với ~27k dòng thì gộp lại nhanh hơn nhiều so với đọc từ master_data.db khi có lỗi kết nối
if (inserted_total > 0) {
  db_files <- list.files(INIT_DB_DIR, pattern = "\\.db$", full.names = TRUE)

  if (length(db_files) == 0) {
    log_message(SCRIPT_NAME, "Không tìm thấy file .db nào trong init_db/", "WARN")
  } else {
    all_data <- lapply(db_files, function(db_path) {
      tryCatch({
        con_src <- DBI::dbConnect(RSQLite::SQLite(), db_path)
        on.exit(DBI::dbDisconnect(con_src), add = TRUE)
        if (DBI::dbExistsTable(con_src, "car_listings")) {
          DBI::dbReadTable(con_src, "car_listings")
        } else {
          NULL
        }
      }, error = function(e) {
        log_message(SCRIPT_NAME, sprintf("Không đọc được %s: %s", basename(db_path), e$message), "WARN")
        NULL
      })
    })

    all_data <- Filter(Negate(is.null), all_data)

    if (length(all_data) > 0) {
      master_df <- dplyr::bind_rows(all_data) %>%
        align_schema() %>%
        dplyr::arrange(source, brand, model, year)

      readr::write_csv(master_df, OUTPUT_CSV, na = "")
      log_message(SCRIPT_NAME, sprintf("Đã rebuild %s từ %d init_db files (%d dòng).",
        OUTPUT_CSV, length(db_files), nrow(master_df)))
    } else {
      log_message(SCRIPT_NAME, "Không có data nào đọc được từ init_db.", "WARN")
    }
  }
} else {
  log_message(SCRIPT_NAME, sprintf("Không có dòng mới, giữ nguyên %s.", OUTPUT_CSV))
}

cat("\n========================================\n")
cat("   REAL-TIME UPDATE COMPLETED\n")
cat("========================================\n")

# Dọn dẹp cờ để tránh ảnh hưởng đến các tác vụ khác trong cùng phiên làm việc
assign(".is_realtime_sourcing", FALSE, envir = globalenv())
assign("REALTIME_MODE", FALSE, envir = globalenv())