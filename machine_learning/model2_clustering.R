suppressPackageStartupMessages(library(cluster))
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(gridExtra))

dir.create("machine_learning/images", recursive = TRUE, showWarnings = FALSE)

clust_cols <- c("price_billion", "car_age", "mileage_k", "engine_size")
df_clust <- df[complete.cases(df[, clust_cols]), clust_cols]
df_clust <- df_clust[apply(df_clust, 1, function(x) all(is.finite(x))), , drop = FALSE]

safe_scale <- function(x) {
  x <- as.matrix(x)
  sds <- apply(x, 2, sd)
  keep <- is.finite(sds) & sds > 0
  if (!all(keep)) x <- x[, keep, drop = FALSE]
  if (ncol(x) == 0) stop("Loi: Khong co phuong sai")
  return(scale(x))
}

df_scaled <- safe_scale(df_clust)
if (nrow(df_scaled) < 2) stop("Data it qua khong chay duoc")

set.seed(42)
elbow_df <- data.frame(
  k   = 2:8,
  wss = sapply(2:8, function(k) {
    if (nrow(df_scaled) <= k) return(NA_real_)
    kmeans(df_scaled, centers = k, nstart = 20, iter.max = 100)$tot.withinss
  })
)

png("machine_learning/images/elbow_method.png", width = 800, height = 600, res = 120)
plot(elbow_df$k, elbow_df$wss, 
     type = "b", pch = 19, frame = FALSE, col = "blue", lwd = 2,
     xlab = "So cum (k)", ylab = "WSS",
     main = "Elbow Method")
abline(v = 4, col = "red", lty = 2, lwd = 2)
dev.off()

OPTIMAL_K <- 4
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

profile_df <- data.frame(
  cluster = 1:OPTIMAL_K,
  gia_trung_binh = tapply(df_clust$price_billion, model_kmeans$cluster, mean),
  km_tb = tapply(df_clust$mileage_k, model_kmeans$cluster, mean)
)
profile_df <- profile_df[order(profile_df$gia_trung_binh), ]

price_rank <- rank(profile_df$gia_trung_binh)
km_rank    <- rank(profile_df$km_tb)

profile_df$ten_cum <- ifelse(
  price_rank == 1, "Xe pho thong / Dich vu",
  ifelse(price_rank == max(price_rank), "Xe cao cap / Hang sang",
         ifelse(km_rank == max(km_rank[price_rank > 1 & price_rank < max(price_rank)]),
                "Xe gia dinh chay nhieu", "Xe gia dinh do thi"))
)

cluster_name_map <- setNames(profile_df$ten_cum, profile_df$cluster)
clust_idx <- which(complete.cases(df[, c("price_billion", "car_age", "mileage_k", "engine_size")]))
df$cluster_id[clust_idx]   <- model_kmeans$cluster
df$cluster_name[clust_idx] <- cluster_name_map[as.character(model_kmeans$cluster)]

# Visual
pca_res <- prcomp(df_scaled, center = FALSE, scale. = FALSE)
df_plot <- data.frame(
  x1 = pca_res$x[, 1],
  x2 = pca_res$x[, 2],
  Cluster = as.factor(cluster_name_map[as.character(model_kmeans$cluster)])
)

plot_before <- ggplot(df_plot, aes(x = x1, y = x2)) +
  geom_point(color = "blue", alpha = 0.7, size = 1.5) +
  theme_bw() +
  labs(title = "Original unclustered data", x = "x1", y = "x2")

plot_after <- ggplot(df_plot, aes(x = x1, y = x2, color = Cluster)) +
  geom_point(alpha = 0.7, size = 1.5) +
  theme_bw() +
  labs(title = "Clustered data", x = "x1", y = "x2") +
  theme(legend.position = "bottom", legend.title = element_blank())

png("machine_learning/images/cluster_comparison.png", width = 1000, height = 500, res = 120)
grid.arrange(plot_before, plot_after, ncol = 2)
dev.off()