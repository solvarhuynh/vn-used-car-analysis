suppressPackageStartupMessages({
  library(ggplot2)
  library(scales)
})

reg_image_dir <- "machine_learning/images"
dir.create(reg_image_dir, recursive = TRUE, showWarnings = FALSE)

# Chỉ train trên xe <= 5B: xe cực sang (>5B) variance quá cao, Linear Regression
# không fit được, để median fallback trong app.R xử lý.
df_reg <- df[!is.na(df$is_train_sample) & df$is_train_sample == TRUE, ]
df_reg <- df_reg[complete.cases(df_reg[, c("log_price", "car_age", "mileage_k",
                                           "engine_non_ev", "fuel", "is_auto",
                                           "is_imported", "seat_count", "brand")]), ]
# (Fix mileage = 0 và impute mileage_k theo body_type đã xử lý tập trung
#  trong prepare_features.R — không lặp lại ở đây.)

# Encode brand: giữ top 20 hãng có nhiều mẫu nhất, còn lại gom vào "Other"
top_brands_reg <- names(sort(table(df_reg$brand), decreasing = TRUE))[1:20]
df_reg$brand_grp <- factor(
  ifelse(df_reg$brand %in% top_brands_reg, df_reg$brand, "Other"),
  levels = c("Other", top_brands_reg)
)

set.seed(42)
idx_reg   <- sample(seq_len(nrow(df_reg)), size = floor(0.8 * nrow(df_reg)))
train_reg <- df_reg[idx_reg, ]
test_reg  <- df_reg[-idx_reg, ]

plot_regression_heatmap <- function(source_df = train_reg) {
  fuel_levels <- levels(source_df$fuel)
  if (is.null(fuel_levels)) fuel_levels <- sort(unique(as.character(source_df$fuel)))
  fuel_levels <- setdiff(fuel_levels, fuel_levels[1])
  fuel_terms <- as.data.frame(lapply(fuel_levels, function(level) {
    as.integer(as.character(source_df$fuel) == level)
  }))
  fuel_labels <- fuel_levels
  fuel_labels[is.na(fuel_labels) | !nzchar(fuel_labels)] <- paste0("Loại ", seq_along(fuel_levels))
  names(fuel_terms) <- paste0("Nhiên liệu: ", fuel_labels)
  
  heatmap_vars <- data.frame(
    "Log giá" = source_df$log_price_cap,
    "Tuổi xe" = source_df$car_age,
    "Odo (nghìn km)" = source_df$mileage_k,
    "Động cơ (L)" = source_df$engine_non_ev,
    "Hộp số tự động" = source_df$is_auto,
    "Nhập khẩu" = source_df$is_imported,
    "Số chỗ" = source_df$seat_count,
    check.names = FALSE
  )
  heatmap_vars <- cbind(heatmap_vars, fuel_terms)
  heatmap_vars <- heatmap_vars[, vapply(heatmap_vars, function(x) {
    is.numeric(x) && is.finite(sd(x, na.rm = TRUE)) && sd(x, na.rm = TRUE) > 0
  }, logical(1)), drop = FALSE]
  
  corr_mat <- cor(heatmap_vars, use = "pairwise.complete.obs")
  corr_mat[!is.finite(corr_mat)] <- NA_real_
  
  corr_df <- as.data.frame(as.table(corr_mat), stringsAsFactors = FALSE)
  names(corr_df) <- c("bien_x", "bien_y", "tuong_quan")
  var_levels <- colnames(corr_mat)
  corr_df$bien_x <- factor(corr_df$bien_x, levels = var_levels)
  corr_df$bien_y <- factor(corr_df$bien_y, levels = rev(var_levels))
  corr_df$label <- ifelse(is.na(corr_df$tuong_quan), "", sprintf("%.2f", corr_df$tuong_quan))
  corr_df$label_color <- ifelse(abs(corr_df$tuong_quan) >= 0.55, "white", "#222222")
  
  ggplot(corr_df, aes(x = bien_x, y = bien_y, fill = tuong_quan)) +
    geom_tile(color = "white", linewidth = 1) +
    geom_text(aes(label = label, color = label_color), size = 4.1, fontface = "bold") +
    scale_color_identity() +
    scale_fill_gradient2(
      low = "#2C7BB6",
      mid = "#FAFAFA",
      high = "#D7191C",
      midpoint = 0,
      limits = c(-1, 1),
      breaks = c(-1, -0.5, 0, 0.5, 1),
      labels = label_number(accuracy = 0.1),
      name = "T\u01b0\u01a1ng quan\nPearson",
      na.value = "gray92"
    ) +
    coord_fixed() +
    labs(
      title = "Heatmap tương quan các biến trong Linear Regression",
      subtitle = sprintf(
        "Tập train hồi quy: %s xe | Biến mục tiêu: log(giá)",
        comma(nrow(source_df), accuracy = 1)
      ),
      x = NULL,
      y = NULL,
      caption = paste(strwrap(
        "Ghi chú: giá trị gần +1/-1 thể hiện tương quan tuyến tính mạnh. Dummy hãng xe không hiển thị để biểu đồ ngắn gọn, dễ đọc.",
        width = 110
      ), collapse = "\n")
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(face = "bold", size = 19, color = "#1F2933"),
      plot.subtitle = element_text(size = 12.5, color = "#52606D", margin = margin(b = 16)),
      plot.caption = element_text(size = 10.5, color = "#616E7C", hjust = 0, margin = margin(t = 14)),
      axis.text.x = element_text(angle = 35, hjust = 1, vjust = 1, size = 12, color = "#243B53"),
      axis.text.y = element_text(size = 12, color = "#243B53"),
      panel.grid = element_blank(),
      legend.position = "right",
      legend.title = element_text(face = "bold", size = 12),
      legend.text = element_text(size = 10.5),
      legend.key.height = unit(1.15, "cm"),
      plot.margin = margin(18, 24, 18, 18)
    )
}

ggsave(
  file.path(reg_image_dir, "regression_heatmap.png"),
  plot = plot_regression_heatmap(),
  width = 11.2, height = 8.4, dpi = 220, bg = "white"
)

# Train dùng log_price_cap (winsorized) để outlier xe sang không inflate RMSE.
# Eval dùng log_price thật để metrics phản ánh thực tế.
model_regression <- lm(
  log_price_cap ~ car_age + mileage_k + engine_non_ev + fuel + is_auto + is_imported + seat_count + brand_grp,
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
  "(Intercept)"  = "Hằng số",
  "car_age"      = "Tuổi xe (năm)",
  "mileage_k"    = "Số km đã đi (nghìn km)",
  "engine_non_ev"= "Dung tích động cơ (L, xe xăng/dầu)",
  "fuelDầu"      = "Nhiên liệu: Dầu",
  "fuelHybrid"   = "Nhiên liệu: Hybrid",
  "fuelĐiện"     = "Nhiên liệu: Điện",
  "is_auto"      = "Hộp số tự động",
  "is_imported"  = "Nhập khẩu",
  "seat_count"   = "Số chỗ ngồi"
)

coef_df <- data.frame(
  term       = rownames(coef_raw),
  term_vn    = unname(term_map[rownames(coef_raw)]),
  estimate   = round(coef_raw[, 1], 6),
  std_error  = round(coef_raw[, 2], 6),
  t_value    = round(coef_raw[, 3], 4),
  p_value    = round(coef_raw[, 4], 6),
  significant= ifelse(coef_raw[, 4] < 0.05, "***", ""),
  row.names  = NULL,
  stringsAsFactors = FALSE
)

coef_df$term_vn[is.na(coef_df$term_vn)] <- coef_df$term[is.na(coef_df$term_vn)]
# Brand dummy coefficients: "brand_grpTOYOTA" → "Hãng: TOYOTA"
brand_rows <- grepl("^brand_grp", coef_df$term_vn)
coef_df$term_vn[brand_rows] <- sub("^brand_grp", "Hãng: ", coef_df$term_vn[brand_rows])

reg_test_result <- data.frame(
  actual_billion    = round(test_reg$price_billion, 3),
  predicted_billion = round(exp(pred_log) / 1e9, 3),
  residual          = round((test_reg$price_billion * 1e9 - exp(pred_log)) / 1e9, 3)
)
