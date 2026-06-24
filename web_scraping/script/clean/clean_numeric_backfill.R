# ==============================================================================
# Script: clean_numeric_backfill.R
# Purpose: Backfill numeric quality issues in init_db/*.db
# Run    : source("web_scraping/script/clean/clean_numeric_backfill.R")
# ==============================================================================

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
})

source("web_scraping/script/utils.R")

SCRIPT_NAME <- "web_scraping/script/clean/clean_numeric_backfill.R"
INIT_DB_DIR  <- "web_scraping/data/init_db"
TABLE_NAME   <- "car_listings"
fix_numeric_quality <- function(df) {
  df <- align_schema(df)

  if (!"source" %in% names(df)) df$source <- NA_character_
  if (!"origin" %in% names(df)) df$origin <- NA_character_
  if (!"is_imported" %in% names(df)) df$is_imported <- NA_integer_

  # engine_size: sửa lỗi parse 0.16 -> 1.6, 0.18 -> 1.8, 0.1 -> 1.0
  # Chỉ áp dụng cho các giá trị bất thường nhỏ hơn 0.5L.
  engine_num <- suppressWarnings(as.numeric(df$engine_size))
  fix_small_engine <- !is.na(engine_num) & engine_num > 0 & engine_num < 0.5
  engine_num[fix_small_engine] <- round(engine_num[fix_small_engine] * 10, 2)
  engine_num[!is.na(engine_num) & engine_num > 8] <- NA_real_
  df$engine_size <- engine_num

  # seat_count: xe khách/xe bus/outlier lớn hơn 16 chỗ không phù hợp model xe con
  # -> xóa hẳn dòng để không làm nhiễu model giá xe con
  seat_num <- suppressWarnings(as.integer(df$seat_count))
  drop_seat <- !is.na(seat_num) & seat_num >= 16
  df <- df[!drop_seat, , drop = FALSE]

  # mileage: giá trị > 500 (tức > 500,000 km nếu đang tính theo nghìn km)
  # hoặc cực lớn đều đưa về NA để tránh kéo lệch model.
  mileage_num <- suppressWarnings(as.numeric(df$mileage))

  mileage_num[!is.na(mileage_num) & mileage_num < 0] <- NA_real_
  mileage_num[!is.na(mileage_num) & mileage_num > 500000] <- NA_real_ # Giữ nguyên giá trị nếu hợp lý, đặt NA nếu quá cao (ví dụ > 500,000 km)

  df$mileage <- as.integer(mileage_num)

  # origin / is_imported: chuẩn hóa lại cờ nhập khẩu
  df$origin <- clean_origin(df$origin)
  df$is_imported <- ifelse(
    is.na(df$origin),
    NA_integer_,
    as.integer(df$origin == "Nhập khẩu")
  )

  # Đảm bảo model/brand/trim không quay lại trạng thái lỏng
  df$brand <- clean_brand(df$brand)
  df$model <- clean_model(df$model)
  df$trim  <- normalize_na(df$trim)
  df$color <- normalize_na(df$color)

  df
}

count_changed_rows <- function(before, after, cols) {
  cols <- intersect(cols, intersect(names(before), names(after)))
  if (!length(cols)) return(0L)

  changed <- logical(nrow(before))
  for (col in cols) {
    b <- before[[col]]
    a <- after[[col]]
    same_na  <- is.na(b) & is.na(a)
    same_val <- !is.na(b) & !is.na(a) & b == a
    changed <- changed | !(same_na | same_val)
  }
  sum(changed)
}

count_na <- function(x) sum(is.na(x))

summarise_file <- function(before, after) {
  data.frame(
    engine_small_before = sum(suppressWarnings(as.numeric(before$engine_size)) > 0 & suppressWarnings(as.numeric(before$engine_size)) < 0.5, na.rm = TRUE),
    engine_gt8_before   = sum(suppressWarnings(as.numeric(before$engine_size)) > 8, na.rm = TRUE),
    engine_small_after  = sum(suppressWarnings(as.numeric(after$engine_size)) > 0 & suppressWarnings(as.numeric(after$engine_size)) < 0.5, na.rm = TRUE),
    engine_gt8_after    = sum(suppressWarnings(as.numeric(after$engine_size)) > 8, na.rm = TRUE),
    seat_gt16_before    = sum(suppressWarnings(as.integer(before$seat_count)) > 16, na.rm = TRUE),
    seat_gt16_after     = sum(suppressWarnings(as.integer(after$seat_count)) > 16, na.rm = TRUE),
    mileage_gt500_before = sum(suppressWarnings(as.numeric(before$mileage)) > 500, na.rm = TRUE),
    mileage_gt500_after  = sum(suppressWarnings(as.numeric(after$mileage)) > 500, na.rm = TRUE),
    mileage_lt0_before    = sum(suppressWarnings(as.numeric(before$mileage)) < 0, na.rm = TRUE),
    mileage_lt0_after     = sum(suppressWarnings(as.numeric(after$mileage)) < 0, na.rm = TRUE),
    is_imported_na_before = if ("is_imported" %in% names(before)) count_na(before$is_imported) else NA_integer_,
    is_imported_na_after  = if ("is_imported" %in% names(after)) count_na(after$is_imported) else NA_integer_
  )
}

db_files <- list.files(INIT_DB_DIR, pattern = "\\.db$", full.names = TRUE)

if (!length(db_files)) {
  log_message(SCRIPT_NAME, "No init_db files found.", "WARN")
  stop("No init_db files found.")
}

log_message(SCRIPT_NAME, sprintf("Found %d init_db files. Starting numeric backfill...", length(db_files)))

total_rows_changed <- 0L
total_files_changed <- 0L

for (db_path in db_files) {
  db_name <- basename(db_path)
  con <- NULL

  tryCatch({
    con <- dbConnect(SQLite(), db_path)

    if (!dbExistsTable(con, TABLE_NAME)) {
      log_message(SCRIPT_NAME, sprintf("Skip %s: missing table %s.", db_name, TABLE_NAME), "WARN")
      next
    }

    df <- dbReadTable(con, TABLE_NAME)
    df_fixed <- fix_numeric_quality(df)

    changed <- count_changed_rows(df, df_fixed, c("engine_size", "mileage", "origin", "is_imported", "model", "brand", "trim"))
    if (changed > 0) {
      dbWriteTable(con, TABLE_NAME, df_fixed, overwrite = TRUE, row.names = FALSE)
      total_rows_changed <- total_rows_changed + changed
      total_files_changed <- total_files_changed + 1L
    }

    stats <- summarise_file(df, df_fixed)
    log_message(SCRIPT_NAME, sprintf(
      "[%s] %d rows updated | engine<0.5: %d->%d | engine>8: %d->%d | seat>16: %d->%d | mileage<0: %d->%d | mileage>500: %d->%d | is_imported NA: %d->%d",
      db_name, changed,
      stats$engine_small_before, stats$engine_small_after,
      stats$engine_gt8_before, stats$engine_gt8_after,
      stats$seat_gt16_before, stats$seat_gt16_after,
      stats$mileage_lt0_before, stats$mileage_lt0_after,
      stats$mileage_gt500_before, stats$mileage_gt500_after,
      stats$is_imported_na_before, stats$is_imported_na_after
    ))
  }, error = function(e) {
    log_message(SCRIPT_NAME, sprintf("Failed on %s: %s", db_name, e$message), "ERROR")
  }, finally = {
    if (!is.null(con)) {
      try(dbDisconnect(con), silent = TRUE)
    }
  })
}

log_message(SCRIPT_NAME, sprintf(
  "Numeric backfill complete. %d file(s) changed, %d row(s) updated.",
  total_files_changed, total_rows_changed
))
