# ==============================================================================
# Script: run_all.R
# Purpose: Train all ML models from repository master data
# Output: machine_learning/output_models.RData
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
})

source("web_scraping/script/utils.R")

CURRENT_YEAR <- as.integer(format(Sys.Date(), "%Y"))
OUTPUT_FILE <- "machine_learning/output_models.RData"

source("machine_learning/prepare_features.R", local = TRUE)
source("machine_learning/model1_regression.R", local = TRUE)
source("machine_learning/model2_clustering.R", local = TRUE)
source("machine_learning/model3_decision_tree.R", local = TRUE)

df_final <- df %>%
  select(
    brand, model, trim, year, car_age,
    body_type, body_type_clean, fuel_type, transmission,
    engine_size, engine_non_ev, seat_count, drivetrain,
    price, price_billion, price_segment,
    mileage, mileage_k, origin, color, city, posted_date, source, url,
    is_auto, is_imported, cluster_id, cluster_name
  )

summary_stats <- list(
  total_listings = nrow(df_final),
  n_sources = n_distinct(df_final$source),
  n_brands = n_distinct(df_final$brand),
  n_cities = n_distinct(df_final$city),
  price_mean = round(mean(df_final$price_billion, na.rm = TRUE), 3),
  price_median = round(median(df_final$price_billion, na.rm = TRUE), 3),
  price_min = round(min(df_final$price_billion, na.rm = TRUE), 3),
  price_max = round(max(df_final$price_billion, na.rm = TRUE), 3),
  year_range = c(min(df_final$year), max(df_final$year)),
  pct_auto = round(mean(df_final$is_auto, na.rm = TRUE) * 100, 1),
  pct_imported = round(mean(df_final$is_imported, na.rm = TRUE) * 100, 1)
)

source_summary <- df_final %>%
  group_by(source) %>%
  summarise(n_xe = n(), gia_median = round(median(price_billion, na.rm = TRUE), 3), .groups = "drop") %>%
  arrange(desc(n_xe))

brand_summary <- df_final %>%
  group_by(brand) %>%
  summarise(
    n_xe = n(),
    gia_trung_binh = round(mean(price_billion, na.rm = TRUE), 3),
    gia_median = round(median(price_billion, na.rm = TRUE), 3),
    km_tb = round(mean(mileage_k, na.rm = TRUE), 1),
    tuoi_tb = round(mean(car_age, na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  arrange(desc(n_xe))

body_summary <- df_final %>%
  group_by(body_type_clean) %>%
  summarise(
    n_xe = n(),
    gia_trung_binh = round(mean(price_billion, na.rm = TRUE), 3),
    gia_median = round(median(price_billion, na.rm = TRUE), 3),
    .groups = "drop"
  ) %>%
  arrange(desc(n_xe))

segment_summary <- df_final %>%
  group_by(price_segment) %>%
  summarise(n_xe = n(), pct = round(n() / nrow(df_final) * 100, 1), .groups = "drop")

city_summary <- df_final %>%
  group_by(city) %>%
  summarise(n_xe = n(), gia_trung_binh = round(mean(price_billion, na.rm = TRUE), 3), .groups = "drop") %>%
  arrange(desc(n_xe)) %>%
  slice_head(n = 15)

save(
  df_final, summary_stats, source_summary, brand_summary, body_summary,
  segment_summary, city_summary,
  model_regression, reg_metrics, coef_df, reg_test_result,
  model_kmeans, cluster_profiles_raw, cluster_centers_real,
  cluster_name_map, elbow_df, avg_silhouette, OPTIMAL_K,
  model_tree, tree_accuracy, tree_kappa,
  conf_table, feat_imp, class_metrics,
  file = OUTPUT_FILE
)

cat("Done. ML artifacts saved to:", OUTPUT_FILE, "\n")