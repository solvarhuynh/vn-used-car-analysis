suppressPackageStartupMessages(library(cluster))

clust_cols <- c("price_billion", "car_age", "mileage_k", "engine_size")
df_clust <- df[complete.cases(df[, clust_cols]), clust_cols]
df_clust <- df_clust[apply(df_clust, 1, function(x) all(is.finite(x))), , drop = FALSE]

safe_scale <- function(x) {
  x <- as.matrix(x)
  sds <- apply(x, 2, sd)
  keep <- is.finite(sds) & sds > 0
  if (!all(keep)) {
    x <- x[, keep, drop = FALSE]
  }
  if (ncol(x) == 0) stop("No numeric variance available for clustering.")
  scaled <- scale(x)
  scaled
}

df_scaled <- safe_scale(df_clust)

if (nrow(df_scaled) < 2) {
  stop("Not enough rows for clustering.")
}

set.seed(42)
elbow_df <- data.frame(
  k   = 2:8,
  wss = sapply(2:8, function(k) {
    if (nrow(df_scaled) <= k) return(NA_real_)
    kmeans(df_scaled, centers = k, nstart = 20, iter.max = 100)$tot.withinss
  })
)

OPTIMAL_K <- 4
if (nrow(df_scaled) <= OPTIMAL_K) {
  stop(sprintf("Not enough rows for kmeans with k=%d.", OPTIMAL_K))
}
set.seed(42)
model_kmeans <- kmeans(df_scaled, centers = OPTIMAL_K, nstart = 25, iter.max = 100)

sil_idx <- seq_len(nrow(df_scaled))
if (length(sil_idx) > 5000) {
  set.seed(42)
  sil_idx <- sample(sil_idx, 5000)
}
if (length(unique(model_kmeans$cluster)) > 1 && length(sil_idx) > 1) {
  sil <- silhouette(model_kmeans$cluster[sil_idx], dist(df_scaled[sil_idx, , drop = FALSE]))
  avg_silhouette <- round(mean(sil[, 3]), 4)
} else {
  avg_silhouette <- NA_real_
}

cluster_profiles_raw <- aggregate(
  df_clust,
  by  = list(cluster = model_kmeans$cluster),
  FUN = function(x) c(mean = round(mean(x), 3), median = round(median(x), 3))
)

profile_df <- data.frame(
  cluster        = 1:OPTIMAL_K,
  n_xe           = as.integer(table(model_kmeans$cluster)),
  pct            = round(as.numeric(table(model_kmeans$cluster)) / nrow(df_clust) * 100, 1),
  gia_trung_binh = round(tapply(df_clust$price_billion, model_kmeans$cluster, mean), 3),
  gia_median     = round(tapply(df_clust$price_billion, model_kmeans$cluster, median), 3),
  tuoi_xe_tb     = round(tapply(df_clust$car_age,       model_kmeans$cluster, mean), 1),
  km_tb          = round(tapply(df_clust$mileage_k,     model_kmeans$cluster, mean), 1),
  dong_co_tb     = round(tapply(df_clust$engine_size,   model_kmeans$cluster, mean), 2)
)
profile_df <- profile_df[order(profile_df$gia_trung_binh), ]

price_rank <- rank(profile_df$gia_trung_binh)
km_rank    <- rank(profile_df$km_tb)
profile_df$ten_cum <- ifelse(
  price_rank == 1, "Xe phổ thông / Dịch vụ",
  ifelse(price_rank == max(price_rank), "Xe cao cấp / Hạng sang",
         ifelse(km_rank == max(km_rank[price_rank > 1 & price_rank < max(price_rank)]),
                "Xe gia đình chạy nhiều",
                "Xe gia đình đô thị"))
)

cluster_profiles_raw <- profile_df

cluster_name_map <- setNames(profile_df$ten_cum, profile_df$cluster)

cluster_centers_real <- as.data.frame(
  t(t(model_kmeans$centers) * attr(df_scaled, "scaled:scale") +
      attr(df_scaled, "scaled:center"))
)
cluster_centers_real$cluster <- 1:OPTIMAL_K
cluster_centers_real$ten_cum <- cluster_name_map[as.character(1:OPTIMAL_K)]

clust_idx <- which(complete.cases(df[, c("price_billion", "car_age",
                                          "mileage_k", "engine_size")]))
df$cluster_id[clust_idx]   <- model_kmeans$cluster
df$cluster_name[clust_idx] <- cluster_name_map[as.character(model_kmeans$cluster)]
