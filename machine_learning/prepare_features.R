# ==============================================================================
# Script: prepare_features.R
# Purpose: Feature engineering cho ML, dùng chung cho cả 3 model
#          (regression, clustering, decision tree).
#
# Tại sao tách riêng khỏi run_all.R?
#   - Đây KHÔNG phải data cleaning ở mức DB (đã có clean_master_db.R /
#     run_realtime.R xử lý lỗi nhập liệu, dedup — chạy 1 lần, dùng chung
#     cho dashboard + model).
#   - Đây là feature engineering CHỈ phục vụ mục đích train model: tạo cột
#     mới (car_age, log_price, price_segment...), filter range hợp lệ để
#     train, impute riêng cho model — không ghi ngược vào DB gốc.
#   - Trước đây đoạn fix mileage_k == 0 còn bị lặp lại 1 lần nữa trong
#     model1_regression.R — đã gộp về đây, xoá đoạn lặp trong model1.
#
# Input : đọc từ read_master_data() (master_data.db / .csv)
# Output: data.frame `df` sẵn sàng cho model1/model2/model3
# ==============================================================================

median_safe <- function(x, default = NA_real_) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) return(default)
  median(x, na.rm = TRUE)
}

normalize_transmission_ml <- function(x) {
  y <- str_to_lower(str_squish(as.character(x)))
  case_when(
    y %in% c("automatic", "auto", "at", "số tự động", "so tu dong", "tự động", "tu dong") ~ "Tự động",
    y %in% c("manual", "mt", "số sàn", "so san", "sàn", "san", "số tay") ~ "Số sàn",
    y == "cvt" ~ "CVT",
    TRUE ~ NA_character_
  )
}

normalize_origin_ml <- function(x) {
  y <- str_to_lower(str_squish(as.character(x)))
  case_when(
    str_detect(y, "nhập|nhap|import") ~ "Nhập khẩu",
    str_detect(y, "trong nước|trong nuoc|lắp ráp|lap rap|việt nam|viet nam") ~ "Trong nước",
    TRUE ~ NA_character_
  )
}

normalize_fuel_ml <- function(x) {
  y <- str_to_lower(str_squish(as.character(x)))
  case_when(
    y %in% c("petrol", "gasoline", "xăng", "xang") ~ "Xăng",
    y %in% c("diesel", "dầu", "dau") ~ "Dầu",
    y %in% c("hybrid") ~ "Hybrid",
    y %in% c("electric", "điện", "dien") ~ "Điện",
    TRUE ~ NA_character_
  )
}

df <- read_master_data() %>%
  mutate(
    year = suppressWarnings(as.integer(year)),
    price = suppressWarnings(as.numeric(price)),
    mileage = suppressWarnings(as.numeric(mileage)),
    engine_size = suppressWarnings(as.numeric(engine_size)),
    seat_count = suppressWarnings(as.integer(seat_count)),
    transmission = normalize_transmission_ml(transmission),
    origin = normalize_origin_ml(origin),
    fuel_type = normalize_fuel_ml(fuel_type)
  ) %>%
  filter(
    !is.na(year), year >= 1990, year <= CURRENT_YEAR,
    !is.na(price), price >= 5e7, price <= 1.5e10,
    !is.na(brand), brand != "",
    !is.na(model), model != ""
  ) %>%
  mutate(
    car_age = CURRENT_YEAR - year,
    price_billion = price / 1e9,
    log_price = log(price),
    # Fix mileage = 0 (lỗi nhập liệu) — gán NA, sẽ impute theo body_type ở dưới
    mileage = ifelse(!is.na(mileage) & mileage <= 0, NA_real_, mileage),
    mileage_k = mileage / 1000,
    is_electric = as.integer(fuel_type == "Điện"),
    fuel = factor(fuel_type, levels = c("Xăng", "Dầu", "Hybrid", "Điện")),
    engine_non_ev = ifelse(is_electric == 1, 0, engine_size),
    is_auto = as.integer(transmission %in% c("Tự động", "Số tự động", "CVT")),
    is_imported = as.integer(origin == "Nhập khẩu"),
    price_segment = factor(
      case_when(
        price_billion < 0.5 ~ "Phổ thông",
        price_billion < 1.0 ~ "Tầm trung",
        price_billion < 2.5 ~ "Khá",
        TRUE ~ "Cao cấp"
      ),
      levels = c("Phổ thông", "Tầm trung", "Khá", "Cao cấp")
    ),
    body_type_clean = case_when(
      body_type %in% c("SUV", "Crossover") ~ "SUV/Crossover",
      body_type == "Sedan" ~ "Sedan",
      body_type %in% c("Hatchback", "Wagon") ~ "Hatchback/Wagon",
      body_type %in% c("Van/Minibus", "Van/Minivan") ~ "Van/Minibus",
      body_type %in% c("Bán tải", "Bán tải / Pickup", "Pickup", "Truck") ~ "Bán tải/Truck",
      TRUE ~ "Khác"
    ),
    cluster_id = NA_integer_,
    cluster_name = NA_character_
  ) %>%
  group_by(body_type_clean) %>%
  mutate(mileage_k = ifelse(is.na(mileage_k), median_safe(mileage_k), mileage_k)) %>%
  ungroup() %>%
  group_by(brand) %>%
  mutate(engine_size = ifelse(is.na(engine_size), median_safe(engine_size), engine_size)) %>%
  ungroup() %>%
  mutate(
    mileage_k = ifelse(is.na(mileage_k), median_safe(mileage_k, 0), mileage_k),
    engine_size = ifelse(is.na(engine_size) & is_electric == 1, 0, engine_size),
    engine_size = ifelse(is.na(engine_size), median_safe(engine_size, 1.5), engine_size),
    engine_non_ev = ifelse(is_electric == 1, 0, engine_size),
    seat_count = ifelse(is.na(seat_count), round(median_safe(seat_count, 5)), seat_count)
  ) %>%
  # ── [MỤC 4] Loại outlier giá theo Z-score trong nhóm brand+model ──────────
  # Vd: VinFast Fadil 2020 giá gấp 5x giá thị trường, Xpander Cross giá ảo...
  # Chỉ tính z-score khi nhóm có >= 5 mẫu (nhóm nhỏ hơn z-score không ổn định,
  # giữ nguyên để tránh loại nhầm xe hiếm/đắt thật).
  group_by(brand, model) %>%
  mutate(
    .n_grp        = n(),
    .price_mean   = mean(price, na.rm = TRUE),
    .price_sd     = sd(price, na.rm = TRUE),
    price_zscore  = ifelse(.n_grp >= 5 & !is.na(.price_sd) & .price_sd > 0,
                            (price - .price_mean) / .price_sd, 0)
  ) %>%
  ungroup() %>%
  select(-.n_grp, -.price_mean, -.price_sd) %>%
  filter(abs(price_zscore) <= 3) %>%
  select(-price_zscore) %>%
  # ── [MỤC 4b] Đánh dấu xe dùng để train regression ──────────────────────────
  # Xe > 5 tỷ (Bentley, Rolls-Royce...) variance giá 2-4 tỷ/model, Linear
  # Regression không fit được → loại khỏi tập train, giữ trong df để
  # clustering và decision tree vẫn dùng được.
  mutate(
    log_price_cap   = log_price,         # alias, model1 vẫn dùng tên này
    is_train_sample = price_billion <= 5 # FALSE = xe cực sang, bỏ qua khi train
  ) %>%
  # ───────────────────────────────────────────────────────────────────────────
  filter(
    is.finite(log_price),
    is.finite(car_age),
    is.finite(mileage_k),
    is.finite(engine_non_ev),
    is.finite(seat_count),
    !is.na(is_electric)
  )

if (nrow(df) < 100) {
  stop(sprintf("Not enough valid rows for ML training: %d", nrow(df)))
}