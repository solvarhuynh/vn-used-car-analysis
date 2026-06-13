# ==========================================
# Visualization for multi-source clean/master used-car data
# ==========================================
suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(readr)
  library(plotly)
})

source("web_scraping/script/utils.R")

PLOT_DIR <- "insights/visualization/plots"
MASTER_CSV <- "web_scraping/data/master_data.csv"
CLEAN_DIR <- "web_scraping/data/clean"
dir.create(PLOT_DIR, recursive = TRUE, showWarnings = FALSE)

load_visual_data <- function() {
  if (file.exists(MASTER_CSV)) return(read_clean_csv(MASTER_CSV))
  files <- list.files(CLEAN_DIR, pattern = "^data_.*_clean\\.csv$", full.names = TRUE)
  if (!length(files)) stop("No master_data.csv or clean CSV files found for visualization.")
  bind_rows(lapply(files, read_clean_csv))
}

normalize_transmission_vis <- function(x) {
  x <- clean_transmission(x)
  case_when(
    x %in% c("Tự động", "Số tự động") ~ "Automatic",
    x == "Số sàn" ~ "Manual",
    x == "CVT" ~ "CVT",
    TRUE ~ NA_character_
  )
}

data_clean <- load_visual_data() %>%
  mutate(
    price = suppressWarnings(as.numeric(price)),
    year = suppressWarnings(as.numeric(year)),
    mileage = suppressWarnings(as.numeric(mileage)),
    brand = trimws(brand),
    fuel_type = ifelse(is.na(fuel_type) | fuel_type == "", "Không rõ", fuel_type),
    body_type = ifelse(is.na(body_type) | body_type == "", "Không rõ", body_type),
    city = ifelse(is.na(city) | city == "", "Không rõ", city),
    transmission = normalize_transmission_vis(transmission)
  ) %>%
  filter(
    !is.na(price), price >= 5e7, price <= 1.5e10,
    !is.na(brand), brand != "",
    !is.na(year), year >= 1990, year <= as.numeric(format(Sys.Date(), "%Y"))
  )

cat("Visualization input rows:", nrow(data_clean), "\n")

top_50_combo <- data_clean %>%
  group_by(brand) %>%
  summarise(so_luong = n(), gia_trung_vi = median(price, na.rm = TRUE), .groups = "drop") %>%
  arrange(desc(so_luong)) %>%
  head(50) %>%
  mutate(brand = factor(brand, levels = brand))

max_vol <- max(top_50_combo$so_luong, na.rm = TRUE)
max_price <- max(top_50_combo$gia_trung_vi, na.rm = TRUE)
coeff <- ifelse(max_vol == 0, 1, max_price / max_vol)

p0 <- ggplot(top_50_combo, aes(x = brand)) +
  geom_col(aes(y = so_luong), fill = "#2878b5", alpha = 0.86) +
  geom_line(aes(y = gia_trung_vi / coeff, group = 1), color = "#c9473a", linewidth = 1.1) +
  geom_point(aes(y = gia_trung_vi / coeff), color = "#9f2d25", size = 2) +
  scale_y_continuous(
    name = "Số lượng xe rao bán",
    sec.axis = sec_axis(~ . * coeff, name = "Giá trung vị (VNĐ)", labels = scales::label_number())
  ) +
  labs(title = "[OVERVIEW] Volume và giá trung vị theo hãng", x = "Hãng xe") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 60, hjust = 1, size = 8), panel.grid.major.x = element_blank())
ggsave(file.path(PLOT_DIR, "00_OVERVIEW_Bar-Line_top50.png"), p0, width = 15, height = 7, dpi = 300)

brand_top <- data_clean %>%
  group_by(brand) %>%
  summarise(n = n(), med_price = median(price, na.rm = TRUE), .groups = "drop") %>%
  arrange(desc(med_price)) %>%
  mutate(brand_label = factor(paste0(row_number(), ". ", brand), levels = rev(paste0(row_number(), ". ", brand))))

p1 <- data_clean %>%
  inner_join(brand_top, by = "brand") %>%
  ggplot(aes(x = brand_label, y = price, fill = brand)) +
  geom_boxplot(alpha = 0.72, outlier.colour = "#c9473a", outlier.shape = 1, outlier.alpha = 0.35) +
  coord_flip() +
  scale_y_log10(labels = scales::label_number()) +
  labs(title = "[WHAT] Phân bổ giá theo hãng", x = "Hãng xe", y = "Giá bán (VNĐ)") +
  theme_minimal() +
  theme(legend.position = "none", axis.text.y = element_text(size = 8))
ggsave(file.path(PLOT_DIR, "01_WHAT_boxplot_gia_theo_hang.png"), p1, width = 10, height = max(10, n_distinct(brand_top$brand) * 0.18), dpi = 300)

year_summary <- data_clean %>%
  group_by(year) %>%
  summarise(med_price = median(price, na.rm = TRUE), .groups = "drop")

p2 <- ggplot(data_clean, aes(x = year, y = price)) +
  geom_jitter(alpha = 0.18, color = "#2c3e50", width = 0.25, size = 1.1) +
  geom_smooth(data = year_summary, aes(x = year, y = med_price), method = "loess", color = "#c9473a", fill = "#f0b0a9", alpha = 0.35, linewidth = 1.1) +
  scale_y_log10(labels = scales::label_number()) +
  scale_x_continuous(breaks = seq(min(data_clean$year, na.rm = TRUE), max(data_clean$year, na.rm = TRUE), by = 2)) +
  labs(title = "[WHEN] Xu hướng giá theo năm sản xuất", x = "Năm sản xuất", y = "Giá bán (VNĐ)") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(PLOT_DIR, "02_WHEN_scatter_trend_khau_hao_nam.png"), p2, width = 10, height = 7, dpi = 300)

data_plot3 <- data_clean %>%
  filter(!is.na(mileage), mileage > 0, mileage < 500000, transmission %in% c("Manual", "Automatic"))

p3 <- ggplot(data_plot3, aes(x = mileage, y = price, color = transmission)) +
  geom_jitter(alpha = 0.25, size = 1.2, width = 0.2) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 1.25) +
  scale_color_manual(values = c("Automatic" = "#c9473a", "Manual" = "#2878b5")) +
  scale_y_log10(labels = scales::label_number()) +
  scale_x_continuous(labels = scales::label_comma(suffix = " km")) +
  labs(title = "[WHY] Odo và hộp số tác động đến giá", x = "Số km đã đi", y = "Giá bán (VNĐ)", color = "Hộp số") +
  theme_minimal() +
  theme(legend.position = "bottom")
ggsave(file.path(PLOT_DIR, "03_WHY_scatter_odo_vs_price.png"), p3, width = 10, height = 7, dpi = 300)

save_bar_plot <- function(df, col, filename, title, fill = "#2878b5", top_n = 20) {
  p <- df %>%
    count(.data[[col]], sort = TRUE) %>%
    head(top_n) %>%
    mutate(label = factor(.data[[col]], levels = rev(.data[[col]]))) %>%
    ggplot(aes(x = label, y = n)) +
    geom_col(fill = fill, alpha = 0.88) +
    coord_flip() +
    labs(title = title, x = NULL, y = "Số lượng") +
    theme_minimal()
  ggsave(file.path(PLOT_DIR, filename), p, width = 9, height = 6, dpi = 300)
  p
}

p4 <- save_bar_plot(data_clean, "fuel_type", "04_DIST_fuel_type.png", "[DISTRIBUTION] Nhiên liệu", "#3b8f63", 12)
p5 <- save_bar_plot(data_clean %>% filter(!is.na(transmission)), "transmission", "05_DIST_transmission.png", "[DISTRIBUTION] Hộp số", "#8a63a8", 8)
p6 <- save_bar_plot(data_clean, "body_type", "06_DIST_body_type.png", "[DISTRIBUTION] Kiểu dáng", "#c48b2c", 15)
p7 <- save_bar_plot(data_clean, "city", "07_DIST_city.png", "[DISTRIBUTION] Thành phố", "#4c7899", 20)

saveRDS(ggplotly(p0), file.path(PLOT_DIR, "p0_overview_interactive.rds"))
saveRDS(ggplotly(p1), file.path(PLOT_DIR, "p1_what_interactive.rds"))
saveRDS(ggplotly(p2), file.path(PLOT_DIR, "p2_when_interactive.rds"))
saveRDS(ggplotly(p3), file.path(PLOT_DIR, "p3_why_interactive.rds"))

cat("Visualization plots saved to", PLOT_DIR, "\n")
