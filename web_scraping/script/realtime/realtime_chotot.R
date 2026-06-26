# ==============================================================================
# Script: realtime_chotot.R
# Purpose: Delta scrape xe.chotot.com — chỉ cào các URL chưa có trong DB
#
# Logic phát hiện URL mới:
#   - Cào trang 1 (20 URL), so ngược từ URL cuối lên URL đầu với DB
#   - Nếu URL cuối cùng của trang CHƯA có trong DB → cả trang chưa cào → sang trang 2
#   - Nếu URL cuối đã có → so từng URL từ cuối lên, dừng khi gặp URL đã có
#   - Ghi URLs mới vào CUỐI urls_chotot.txt (append, không prepend, không ghi đè)
#     -> bắt buộc append vì Step B của scrap_chotot.R dùng checkpoint dạng
#        "đã xử lý N dòng đầu file" để resume; prepend sẽ làm lệch vị trí
#        toàn bộ URL cũ và khiến chúng bị bỏ qua vĩnh viễn.
#   - Cào chi tiết từng URL mới
#   - INSERT OR IGNORE vào init_db/data_chotot.db và master_data.db
#
# Output: Dữ liệu ghi thẳng vào init_db/data_chotot.db và master_data.db.
#         File CSV trung gian (data_chotot_rt.csv) đã bị vô hiệu hóa.
# ==============================================================================
# Lưu ý: việc dò đường dẫn Chrome/Edge (CHROMOTE_CHROME) đã được xử lý trong
# scrap_chotot.R (đặt ngoài guard REALTIME_MODE) nên sẽ tự chạy khi source()
# bên dưới, không cần lặp lại ở đây.

suppressPackageStartupMessages({
  library(chromote)
  library(rvest)
  library(dplyr)
  library(stringr)
  library(DBI)
  library(RSQLite)
  library(readr)
})

source("web_scraping/script/utils.R")

# Flag báo scrap_chotot.R chỉ load hàm/config, không chạy Step A+B
REALTIME_MODE <- TRUE
source("web_scraping/script/scrap/scrap_chotot.R")

SCRIPT_NAME   <- "realtime_chotot.R"
SOURCE_NAME   <- "xe.chotot.com"
TABLE_NAME    <- "car_listings"
INIT_DB_FILE  <- "web_scraping/data/init_db/data_chotot.db"
MASTER_DB     <- "web_scraping/data/master_data.db"
URLS_FILE     <- file.path(OUTPUT_DIR, "meta", "urls_chotot.txt")
RT_OUTPUT_DIR <- "web_scraping/data/realtime"
RT_OUTPUT     <- file.path(RT_OUTPUT_DIR, "data_chotot_rt.csv")
MAX_PAGES_RT  <- 10   # Giới hạn số trang kiểm tra trong 1 lần realtime

# ── Rút gọn URL để log cho gọn ───────────────────────────────────────────────
short_url <- function(url) {
  u <- sub("^https?://[^/]+/", "", url)
  if (nchar(u) > 60) paste0(substr(u, 1, 57), "...") else u
}

# ── Lấy URLs từ 1 trang listing ───────────────────────────────────────────────
fetch_listing_page_urls <- function(sess, page_num) {
  url <- if (page_num == 1) LISTING_URL else
    paste0("https://xe.chotot.com/mua-ban-oto?page=", page_num)

  nav <- safe_navigate(sess, url)
  if (!nav$ok) {
    log_message(SCRIPT_NAME, sprintf("Không navigate được trang %d", page_num), "WARN")
    return(character(0))
  }
  sess <- nav$session

  for (i in seq_len(5)) {
    tryCatch(sess$Runtime$evaluate('window.scrollBy(0, window.innerHeight)'), error = function(e) NULL)
    Sys.sleep(1)
  }

  html_raw <- tryCatch(
    sess$Runtime$evaluate('document.documentElement.outerHTML')$result$value,
    error = function(e) NULL)
  if (is.null(html_raw)) return(character(0))

  pg <- tryCatch(read_html(html_raw, encoding = "UTF-8"), error = function(e) NULL)
  if (is.null(pg)) return(character(0))

  links <- pg |> html_nodes("a.c15fd2pn") |> html_attr("href") |> na.omit()
  links <- links[str_detect(links, "\\/\\d+\\.htm")]
  links <- str_replace(links, "#.*$", "")
  unique(paste0(BASE_URL, links))
}

# ── Kiểm tra URL có trong DB chưa ────────────────────────────────────────────
url_in_db <- function(con, url) {
  res <- DBI::dbGetQuery(con,
    sprintf("SELECT 1 FROM %s WHERE url = ? LIMIT 1", TABLE_NAME),
    params = list(url))
  nrow(res) > 0
}

# ── INSERT OR IGNORE 1 dòng (tránh lỗi UNIQUE constraint khi URL đã tồn tại) ──
# dbWriteTable(..., append = TRUE) không hỗ trợ "OR IGNORE" nên nếu URL đã có
# trong bảng sẽ throw lỗi UNIQUE constraint. Dùng dbExecute với câu lệnh
# INSERT OR IGNORE thay thế. Trả về số dòng thực sự được insert (0 nếu đã tồn tại).
insert_or_ignore <- function(con, table, df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)  # tránh lỗi [[i,j]] với tibble
  cols <- names(df)
  placeholders <- paste(rep("?", length(cols)), collapse = ", ")
  sql <- sprintf("INSERT OR IGNORE INTO %s (%s) VALUES (%s)",
                  table, paste(sprintf('"%s"', cols), collapse = ", "), placeholders)
  # Lấy từng cột (df[[i]]) rồi lấy phần tử đầu ([[1]]) -> an toàn cho cả
  # tibble và data.frame, tránh lỗi "Can't use matrix-style subsetting in [["
  params <- lapply(seq_along(cols), function(i) df[[i]][[1]])
  DBI::dbExecute(con, sql, params = params)
}

# ── Main realtime function ────────────────────────────────────────────────────
run_realtime_chotot <- function(con_master = NULL) {
  log_message(SCRIPT_NAME, "=== Bắt đầu realtime Chợ Tốt ===")
  dir.create(RT_OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

  # Kết nối DB
  owns_master <- is.null(con_master)
  master_conns_created <- list()
  if (owns_master) {
    con_master <- DBI::dbConnect(RSQLite::SQLite(), MASTER_DB)
    master_conns_created[[length(master_conns_created) + 1L]] <- con_master
  }
  on.exit({
    for (cc in master_conns_created) {
      if (DBI::dbIsValid(cc)) DBI::dbDisconnect(cc)
    }
  }, add = TRUE)

  # Tự reconnect master DB nếu connection bị đóng/invalid giữa chừng
  # (vd: do code sourced từ scrap_chotot.R mở/đóng connection riêng làm
  # "Invalid or closed connection" khi insert)
  ensure_master_con <- function(con) {
    if (is.null(con) || !DBI::dbIsValid(con)) {
      new_con <- DBI::dbConnect(RSQLite::SQLite(), MASTER_DB)
      master_conns_created[[length(master_conns_created) + 1L]] <<- new_con
      return(new_con)
    }
    con
  }

  # Init DB riêng của chotot
  if (!file.exists(INIT_DB_FILE)) {
    log_message(SCRIPT_NAME, paste("Không tìm thấy init DB:", INIT_DB_FILE), "ERROR")
    return(0L)
  }
  con_init <- DBI::dbConnect(RSQLite::SQLite(), INIT_DB_FILE)
  on.exit(DBI::dbDisconnect(con_init), add = TRUE)

  # Dọn dẹp session/browser cũ còn sót từ lần chạy trước (nếu có).
  # Dùng chromote API thay vì taskkill để tránh kill nhầm Edge đang dùng bình thường.
  # Thứ tự: đóng session global `b` → đóng default Chromote browser → tạo session mới.
  tryCatch({
    if (exists("b", envir = .GlobalEnv) && !is.null(get("b", envir = .GlobalEnv))) {
      tryCatch(get("b", envir = .GlobalEnv)$close(), error = function(e) NULL)
      assign("b", NULL, envir = .GlobalEnv)
    }
    cb <- tryCatch(chromote::default_chromote_object(), error = function(e) NULL)
    if (!is.null(cb)) {
      tryCatch(cb$close(), error = function(e) NULL)
      chromote::set_default_chromote_object(NULL)
    }
    Sys.sleep(2)
  }, error = function(e) NULL)

  # Khởi session Chromote
  sess <- make_session()
  on.exit({ close_session(sess); log_message(SCRIPT_NAME, "Đã đóng session.") }, add = TRUE)

  # ── BƯỚC 1: Phát hiện URLs mới ──────────────────────────────────────────────
  new_urls <- character(0)

  for (pg_num in seq_len(MAX_PAGES_RT)) {
    log_message(SCRIPT_NAME, sprintf("Kiểm tra trang %d...", pg_num))
    page_urls <- fetch_listing_page_urls(sess, pg_num)

    if (length(page_urls) == 0) {
      log_message(SCRIPT_NAME, sprintf("Trang %d không có URL, dừng.", pg_num), "WARN")
      break
    }

    # Kiểm tra URL CUỐI của trang (URL cũ nhất trong trang này)
    last_url <- page_urls[length(page_urls)]
    last_in_db <- url_in_db(con_init, last_url)

    if (!last_in_db) {
      # Cả trang chưa cào → lấy tất cả, sang trang tiếp
      log_message(SCRIPT_NAME, sprintf("Trang %d: URL cuối chưa có trong DB → lấy hết %d URL, sang trang tiếp.", pg_num, length(page_urls)))
      new_urls <- c(new_urls, page_urls)
      next
    }

    # URL cuối đã có → so ngược từ cuối lên để tìm ranh giới
    log_message(SCRIPT_NAME, sprintf("Trang %d: URL cuối đã có trong DB → so ngược từng URL.", pg_num))
    for (i in rev(seq_along(page_urls))) {
      if (!url_in_db(con_init, page_urls[i])) {
        new_urls <- c(new_urls, page_urls[i])
      } else {
        break  # Gặp URL đã cào → dừng (những URL trước đó cũng đã cào rồi)
      }
    }
    break  # Đã xác định ranh giới, không cần kiểm tra trang tiếp
  }

  n_new <- length(new_urls)
  log_message(SCRIPT_NAME, sprintf("Phát hiện %d URL mới cần cào.", n_new))

  if (n_new == 0) {
    log_message(SCRIPT_NAME, "Không có URL mới. Kết thúc.")
    return(0L)
  }

  # ── BƯỚC 2: Ghi URLs mới vào CUỐI urls_chotot.txt (append) ──────────────────
  # QUAN TRỌNG: phải APPEND vào cuối file, KHÔNG prepend.
  # scrap_chotot.R (Step B) dùng checkpoint dạng "đã xử lý N dòng đầu của file"
  # để biết phải resume từ đâu (log: "checkpoint = 19777 → resume từ #19778").
  # Nếu prepend URL mới lên đầu, toàn bộ URL cũ sẽ bị lệch vị trí xuống dưới
  # -> checkpoint cũ trỏ sai chỗ -> một phần URL cũ bị bỏ qua vĩnh viễn
  # (đây là nguyên nhân "ghi đè URL cũ"). Append vào cuối giữ nguyên vị trí
  # các URL cũ (checkpoint cũ vẫn đúng), URL mới sẽ được Step B xử lý ở
  # lượt kế tiếp.
  urls_to_write <- rev(new_urls)  # giữ thứ tự mới nhất -> cũ nhất
  dir.create(dirname(URLS_FILE), recursive = TRUE, showWarnings = FALSE)
  con_urls <- file(URLS_FILE, open = if (file.exists(URLS_FILE)) "a" else "w")
  writeLines(urls_to_write, con_urls)
  close(con_urls)
  log_message(SCRIPT_NAME, sprintf("Đã ghi %d URL mới vào cuối file: %s", n_new, URLS_FILE))

  # ── BƯỚC 3: Cào chi tiết từng URL mới ───────────────────────────────────────
  assign("b", sess, envir = .GlobalEnv)
  batch <- list()
  inserted_init <- 0L
  inserted_master <- 0L

  for (i in seq_along(new_urls)) {
    u <- new_urls[i]
    cat(sprintf("[chotot-rt] %d/%d\n", i, n_new))

    raw_row <- tryCatch(scrape_car(u), error = function(e) {
      log_message(SCRIPT_NAME, sprintf("Lỗi cào %s: %s", short_url(u), e$message), "WARN")
      NULL
    })

    if (is.null(raw_row) || nrow(raw_row) == 0) next

    clean_row <- tryCatch(
      standardize_car_data(raw_row) %>% apply_business_rules(),
      error = function(e) NULL)
    if (is.null(clean_row) || nrow(clean_row) == 0) next

    batch[[length(batch) + 1]] <- clean_row

    # INSERT vào init_db (OR IGNORE -> không lỗi khi URL đã tồn tại)
    n_ins_init <- tryCatch(
      insert_or_ignore(con_init, TABLE_NAME, clean_row),
      error = function(e) {
        log_message(SCRIPT_NAME, sprintf("init_db INSERT lỗi (%s): %s", short_url(u), e$message), "WARN")
        0L
      })
    if (n_ins_init > 0) {
      inserted_init <- inserted_init + 1L
    } else {
      log_message(SCRIPT_NAME, sprintf("init_db: URL đã tồn tại, bỏ qua (%s)", short_url(u)))
    }

    # INSERT vào master_data.db (tự reconnect nếu connection bị đóng/invalid)
    con_master <- ensure_master_con(con_master)
    n_ins_master <- tryCatch(
      insert_or_ignore(con_master, TABLE_NAME, clean_row),
      error = function(e) {
        log_message(SCRIPT_NAME, sprintf("master INSERT lỗi (%s): %s", short_url(u), e$message), "WARN")
        0L
      })
    if (n_ins_master > 0) inserted_master <- inserted_master + 1L

    Sys.sleep(runif(1, 1, 2))
  }

  # ── BƯỚC 4: Ghi ra rt.csv (đã vô hiệu hóa — dữ liệu đã có trong DB) ──────────
  # Bỏ qua việc ghi file CSV trung gian để tiết kiệm dung lượng lưu trữ.
  # Dữ liệu đã được INSERT trực tiếp vào init_db và master_data.db ở Bước 3.
  # if (length(batch) > 0) {
  #   rt_df <- bind_rows(batch)
  #   # Append vào rt.csv (tạo mới nếu chưa có, thêm header chỉ lần đầu)
  #   if (!file.exists(RT_OUTPUT)) {
  #     readr::write_csv(rt_df, RT_OUTPUT, na = "")
  #   } else {
  #     readr::write_csv(rt_df, RT_OUTPUT, na = "", append = TRUE, col_names = FALSE)
  #   }
  #   log_message(SCRIPT_NAME, sprintf("Đã ghi %d dòng vào: %s", nrow(rt_df), RT_OUTPUT))
  # }

  log_message(SCRIPT_NAME, sprintf(
    "=== Hoàn thành. %d URL mới | %d dòng vào init_db | %d dòng vào master ===",
    n_new, inserted_init, inserted_master))
  return(inserted_init)
}
# if (!exists("RUN_REALTIME_ORCHESTRATOR") || !isTRUE(RUN_REALTIME_ORCHESTRATOR)) {
#   run_realtime_chotot()
# }