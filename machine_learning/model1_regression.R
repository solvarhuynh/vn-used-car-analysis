df_reg <- df[complete.cases(df[, c("log_price", "car_age", "mileage_k",
                                    "engine_non_ev", "fuel", "is_auto", "is_imported",
                                    "seat_count")]), ]

set.seed(42)
idx_reg   <- sample(seq_len(nrow(df_reg)), size = floor(0.8 * nrow(df_reg)))
train_reg <- df_reg[idx_reg, ]
test_reg  <- df_reg[-idx_reg, ]

model_regression <- lm(
  log_price ~ car_age + mileage_k + engine_non_ev + fuel + is_auto + is_imported + seat_count,
  data = train_reg
)

pred_log <- predict(model_regression, newdata = test_reg)

reg_metrics <- list(
  r_squared    = round(summary(model_regression)$r.squared, 4),
  adj_r2       = round(summary(model_regression)$adj.r.squared, 4),
  rmse_billion = round(sqrt(mean((exp(pred_log) - test_reg$price_billion * 1e9)^2)) / 1e9, 4),
  mae_billion  = round(mean(abs(exp(pred_log) - test_reg$price_billion * 1e9)) / 1e9, 4),
  n_train      = nrow(train_reg),
  n_test       = nrow(test_reg)
)

coef_raw <- as.data.frame(summary(model_regression)$coefficients)
term_map <- c(
  "(Intercept)" = "Hằng số",
  "car_age" = "Tuổi xe (năm)",
  "mileage_k" = "Số km đã đi (nghìn km)",
  "engine_non_ev" = "Dung tích động cơ (L, xe xăng/dầu)",
  "fuelDầu" = "Nhiên liệu: Dầu",
  "fuelHybrid" = "Nhiên liệu: Hybrid",
  "fuelĐiện" = "Nhiên liệu: Điện",
  "is_auto" = "Hộp số tự động",
  "is_imported" = "Nhập khẩu",
  "seat_count" = "Số chỗ ngồi"
)

coef_df <- data.frame(
  term = rownames(coef_raw),
  term_vn = unname(term_map[rownames(coef_raw)]),
  estimate = round(coef_raw[, 1], 6),
  std_error = round(coef_raw[, 2], 6),
  t_value = round(coef_raw[, 3], 4),
  p_value = round(coef_raw[, 4], 6),
  significant = ifelse(coef_raw[, 4] < 0.05, "***", ""),
  row.names = NULL,
  stringsAsFactors = FALSE
)

coef_df$term_vn[is.na(coef_df$term_vn)] <- coef_df$term[is.na(coef_df$term_vn)]

reg_test_result <- data.frame(
  actual_billion    = round(test_reg$price_billion, 3),
  predicted_billion = round(exp(pred_log) / 1e9, 3),
  residual          = round((test_reg$price_billion * 1e9 - exp(pred_log)) / 1e9, 3)
)
