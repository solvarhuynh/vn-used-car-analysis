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

# ==============================================================================
# Hàm clean_and_rebuild: fix numeric + trim rồi rebuild CSV.
# Dùng function riêng để on.exit() đóng connection đúng scope,
# tránh "Invalid or closed connection" từ con của script con bên trên.
# ==============================================================================
clean_and_rebuild <- function(db_file, output_csv, script_name) {

  # Mở kết nối mới hoàn toàn độc lập với con bên ngoài
  cx <- DBI::dbConnect(RSQLite::SQLite(), db_file)
  on.exit(DBI::dbDisconnect(cx), add = TRUE)

  if (!DBI::dbExistsTable(cx, "car_listings")) {
    log_message(script_name, "Bảng 'car_listings' không tồn tại. Bỏ qua.", "WARN")
    return(invisible(NULL))
  }

  df <- DBI::dbReadTable(cx, "car_listings")
  log_message(script_name, sprintf("Clean & rebuild: đọc %d dòng từ master DB.", nrow(df)))

  # ── Bước 1: Fix numeric quality ───────────────────────────────────────────
  # engine_size: sửa lỗi parse 0.16→1.6 (cc bị chia 10 thay vì 1000)
  engine_num <- suppressWarnings(as.numeric(df$engine_size))
  fix_small  <- !is.na(engine_num) & engine_num > 0 & engine_num < 0.5
  engine_num[fix_small]                            <- round(engine_num[fix_small] * 10, 2)
  engine_num[!is.na(engine_num) & engine_num > 8] <- NA_real_
  df$engine_size <- engine_num

  # [MỤC 1] Impute engine_size theo brand+model (group >=3 mẫu),
  # fallback theo brand (group >=3 mẫu), fallback cuối là median toàn cục.
  global_med <- suppressWarnings(median(df$engine_size, na.rm = TRUE))
  df <- df %>%
    dplyr::group_by(brand, model) %>%
    dplyr::mutate(
      .n_bm = sum(!is.na(engine_size)),
      engine_size = ifelse(is.na(engine_size) & .n_bm >= 3,
                            median(engine_size, na.rm = TRUE), engine_size)
    ) %>%
    dplyr::ungroup() %>%
    dplyr::group_by(brand) %>%
    dplyr::mutate(
      .n_b = sum(!is.na(engine_size)),
      engine_size = ifelse(is.na(engine_size) & .n_b >= 3,
                            median(engine_size, na.rm = TRUE), engine_size)
    ) %>%
    dplyr::ungroup() %>%
    dplyr::select(-.n_bm, -.n_b) %>%
    as.data.frame(stringsAsFactors = FALSE)
  if (!is.na(global_med))
    df$engine_size[is.na(df$engine_size)] <- global_med

  # seat_count: xoá xe >= 10 chỗ (xe khách thương mại)
  seat_num <- suppressWarnings(as.integer(df$seat_count))
  n_before <- nrow(df)
  df       <- df[is.na(seat_num) | seat_num < 10, , drop = FALSE]
  if (nrow(df) < n_before)
    log_message(script_name, sprintf("  Xoá %d dòng xe >= 10 chỗ.", n_before - nrow(df)), "WARN")

  # mileage: đặt NA nếu <= 0 hoặc > 500 000 km
  mileage_num <- suppressWarnings(as.numeric(df$mileage))
  mileage_num[!is.na(mileage_num) & mileage_num <= 0]     <- NA_real_
  mileage_num[!is.na(mileage_num) & mileage_num > 500000] <- NA_real_

  # [MỤC 2] Mileage bất thường theo tuổi xe (2 chiều)
  current_year <- as.integer(format(Sys.Date(), "%Y"))
  age <- current_year - suppressWarnings(as.integer(df$year))
  bad_low  <- !is.na(age) & age >= 5 & !is.na(mileage_num) & mileage_num < 100
  bad_high <- !is.na(age) & age <= 3 & !is.na(mileage_num) & mileage_num > 150000
  bad_abs_low <- !is.na(mileage_num) & mileage_num < 50
  if (sum(bad_low, na.rm = TRUE) > 0)
    log_message(script_name, sprintf("  Đặt NA %d xe >=5 tuổi, km < 100.", sum(bad_low, na.rm = TRUE)), "WARN")
  if (sum(bad_high, na.rm = TRUE) > 0)
    log_message(script_name, sprintf("  Đặt NA %d xe <=3 tuổi, km > 150k.", sum(bad_high, na.rm = TRUE)), "WARN")
  if (sum(bad_abs_low, na.rm = TRUE) > 0)
    log_message(script_name, sprintf("  Đặt NA %d xe km < 50 (bất kể tuổi).", sum(bad_abs_low, na.rm = TRUE)), "WARN")
  mileage_num[bad_low | bad_high | bad_abs_low] <- NA_real_
  df$mileage <- as.integer(mileage_num)

  # origin + is_imported: đồng bộ lại
  df$origin <- clean_origin(df$origin)

  # [MỤC 5] Fill origin rule-based cho brand luôn nhập khẩu 100%
  always_imported_brands <- c("BENTLEY", "CADILLAC", "HAVAL", "GEELY", "GAC",
                               "ROLLS-ROYCE", "MASERATI", "LAMBORGHINI", "FERRARI",
                               "MCLAREN", "ASTON MARTIN")
  fill_idx <- is.na(df$origin) & toupper(df$brand) %in% always_imported_brands
  if (sum(fill_idx, na.rm = TRUE) > 0) {
    df$origin[fill_idx] <- "Nhập khẩu"
    log_message(script_name, sprintf("  Fill origin 'Nhập khẩu' cho %d xe (rule-based).", sum(fill_idx, na.rm = TRUE)))
  }

  if ("is_imported" %in% names(df)) {
    df$is_imported <- ifelse(is.na(df$origin), NA_integer_,
                             as.integer(df$origin == "Nhập khẩu"))
  }

  # brand / model / trim / color
  df$brand <- clean_brand(df$brand)
  # Gộp "LAND ROVER" và "LANDROVER" thành 1 brand chuẩn để tránh loãng data,
  # giúp z-score lọc outlier ổn định hơn (n_grp tăng ~2x cho dòng này).
  df$brand[toupper(trimws(df$brand)) %in% c("LAND ROVER", "LAND-ROVER")] <- "LANDROVER"
  df$model <- clean_model(df$model)
  df$trim  <- normalize_na(df$trim)
  df$color <- normalize_na(df$color)

  # ── Dedup URL (giữ dòng cũ nhất cho mỗi URL) ─────────────────────────────
  n_before_dedup <- nrow(df)
  if ("url" %in% names(df) && !all(is.na(df$url))) {
    df <- df[!duplicated(df$url) | is.na(df$url), , drop = FALSE]
    n_dup <- n_before_dedup - nrow(df)
    if (n_dup > 0)
      log_message(script_name, sprintf("  Xoá %d dòng trùng URL.", n_dup), "WARN")
  }

  # [MỤC 3] Dedup tin đăng lại: trùng brand+model+year+price+mileage,
  # URL khác nhau (đăng lại từ nguồn/lần đăng khác) — giữ 1 dòng.
  n_before_repost <- nrow(df)
  has_full_key <- !is.na(df$brand) & !is.na(df$model) & !is.na(df$year) &
                  !is.na(df$price) & !is.na(df$mileage)
  repost_key <- paste(df$brand, df$model, df$year, df$price, df$mileage, sep = "||")
  is_repost_dup <- has_full_key & duplicated(ifelse(has_full_key, repost_key, NA))
  df <- df[!is_repost_dup, , drop = FALSE]
  n_repost_dup <- n_before_repost - nrow(df)
  if (n_repost_dup > 0)
    log_message(script_name, sprintf("  Xoá %d dòng trùng brand+model+year+price+mileage (đăng lại).", n_repost_dup), "WARN")

  log_message(script_name, "  Bước 1 (numeric fix) hoàn thành.")

  # ── Bước 2: Canonicalize trim theo majority-vote (cần toàn bộ dataset) ───────
  df <- clean_trim_column(df)
  log_message(script_name, "  Bước 2 (trim canonicalization) hoàn thành.")

  # ── Bước 3: Ghi lại DB ───────────────────────────────────────────────────────
  DBI::dbWriteTable(cx, "car_listings", df, overwrite = TRUE, row.names = FALSE)
  log_message(script_name, sprintf("  Đã ghi lại %d dòng vào master DB.", nrow(df)))

  # ── Bước 4: Rebuild CSV ───────────────────────────────────────────────────────
  master_df <- df %>%
    align_schema() %>%
    dplyr::arrange(source, brand, model, year)

  dir.create(dirname(output_csv), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(master_df, output_csv, na = "")
  log_message(script_name, sprintf("  Đã rebuild %s (%d dòng). CSV sẵn sàng cho visual/model.",
                                    basename(output_csv), nrow(master_df)))

  invisible(nrow(master_df))
}

# ==============================================================================
# Chạy clean & rebuild nếu có dữ liệu mới
# ==============================================================================
if (inserted_total > 0) {
  log_message(SCRIPT_NAME, sprintf(
    "Có %d dòng mới — bắt đầu clean master DB và rebuild CSV...", inserted_total))

  tryCatch(
    clean_and_rebuild(DB_FILE, OUTPUT_CSV, SCRIPT_NAME),
    error = function(e) {
      log_message(SCRIPT_NAME, sprintf("Lỗi clean & rebuild: %s", e$message), "ERROR")
    }
  )
} else {
  log_message(SCRIPT_NAME, sprintf("Không có dòng mới, giữ nguyên %s.", OUTPUT_CSV))
}

cat("\n========================================\n")
cat("   REAL-TIME UPDATE COMPLETED\n")
cat("========================================\n")

# Dọn dẹp cờ để tránh ảnh hưởng đến các tác vụ khác trong cùng phiên làm việc
assign(".is_realtime_sourcing", FALSE, envir = globalenv())
assign("REALTIME_MODE", FALSE, envir = globalenv())