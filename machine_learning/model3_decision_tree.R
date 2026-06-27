suppressPackageStartupMessages({
  library(rpart)
  library(ggplot2)
  library(rpart.plot)
  library(scales)
})

df_tree <- df[complete.cases(df[, c("price_segment", "car_age", "mileage_k",
                                     "engine_size", "is_auto", "is_imported",
                                     "seat_count")]),
              c("price_segment", "car_age", "mileage_k", "engine_size",
                "is_auto", "is_imported", "seat_count")]
df_tree$price_segment <- factor(df_tree$price_segment,
  levels = c("Phổ thông", "Tầm trung", "Khá", "Cao cấp"))
df_tree <- df_tree[!is.na(df_tree$price_segment), ]

stratified_train_index <- function(y, p = 0.8) {
  idx_by_class <- split(seq_along(y), y)
  unlist(lapply(idx_by_class, function(idx) {
    n_train <- max(1, floor(length(idx) * p))
    if (n_train >= length(idx)) n_train <- max(1, length(idx) - 1)
    sample(idx, n_train)
  }), use.names = FALSE)
}

set.seed(42)
idx_tree <- stratified_train_index(df_tree$price_segment, p = 0.8)
train_tree <- df_tree[idx_tree, ]
test_tree <- df_tree[-idx_tree, ]

model_tree <- rpart(
  price_segment ~ .,
  data = train_tree,
  method = "class",
  control = rpart.control(minsplit = 30, minbucket = 10, maxdepth = 6, cp = 0.001)
)
best_cp <- model_tree$cptable[which.min(model_tree$cptable[, "xerror"]), "CP"]
model_tree <- prune(model_tree, cp = best_cp)

tree_pred <- predict(model_tree, newdata = test_tree, type = "class")
levels_all <- levels(df_tree$price_segment)
conf_mat <- table(
  Prediction = factor(tree_pred, levels = levels_all),
  Reference = factor(test_tree$price_segment, levels = levels_all)
)

total <- sum(conf_mat)
tree_accuracy <- round(sum(diag(conf_mat)) / total, 4)
expected_accuracy <- sum(rowSums(conf_mat) * colSums(conf_mat)) / (total ^ 2)
tree_kappa <- round((tree_accuracy - expected_accuracy) / (1 - expected_accuracy), 4)

conf_table <- as.data.frame(conf_mat)
names(conf_table) <- c("du_doan", "thuc_te", "so_lan")

importance <- model_tree$variable.importance
if (is.null(importance)) {
  importance <- setNames(rep(0, 6), c("car_age", "mileage_k", "engine_size", "is_auto", "is_imported", "seat_count"))
}

feat_imp <- data.frame(
  feature = names(importance),
  importance = as.numeric(importance)
)
feat_imp$importance_pct <- if (sum(feat_imp$importance) > 0) {
  round(feat_imp$importance / sum(feat_imp$importance) * 100, 1)
} else {
  0
}
feat_imp$feature_vn <- c(
  car_age = "Tuổi xe",
  mileage_k = "Số km đã đi",
  engine_size = "Dung tích động cơ",
  is_auto = "Hộp số tự động",
  is_imported = "Nhập khẩu",
  seat_count = "Số chỗ ngồi"
)[feat_imp$feature]
feat_imp <- feat_imp[order(-feat_imp$importance), ]

class_metrics <- do.call(rbind, lapply(levels_all, function(cls) {
  tp <- conf_mat[cls, cls]
  fn <- sum(conf_mat[, cls]) - tp
  fp <- sum(conf_mat[cls, ]) - tp
  tn <- total - tp - fn - fp
  sensitivity <- ifelse(tp + fn == 0, NA_real_, tp / (tp + fn))
  specificity <- ifelse(tn + fp == 0, NA_real_, tn / (tn + fp))
  data.frame(
    Sensitivity = round(sensitivity, 4),
    Specificity = round(specificity, 4),
    `Balanced Accuracy` = round(mean(c(sensitivity, specificity), na.rm = TRUE), 4),
    class = cls,
    check.names = FALSE
  )
}))

# visual
EGMENT_COLORS <- c(
  "Phổ thông" = "#5DCAA5",   # teal
  "Tầm trung" = "#378ADD",   # blue
  "Khá"       = "#EF9F27",   # amber
  "Cao cấp"   = "#D85A30"    # coral
)

plot_decision_tree <- function(model = model_tree,
                               accuracy = tree_accuracy,
                               kappa    = tree_kappa) {
  
  subtitle_text <- sprintf(
    "Accuracy: %.1f%%  |  Kappa: %.4f",
    accuracy * 100, kappa
  )
  
  node_palette <- list(
    "Phổ thông" = "#E1F5EE",
    "Tầm trung" = "#E6F1FB",
    "Khá"       = "#FAEEDA",
    "Cao cấp"   = "#FAECE7"
  )
  
  par(mar = c(2, 2, 4, 2)) 
  
  rpart.plot(
    model,
    type          = 2,
    extra         = 104,
    fallen.leaves = FALSE,
    branch        = 0.5,
    round         = 1,
    box.palette   = node_palette,
    shadow.col    = "gray85",
    col           = "gray30",
    border.col    = "gray60",
    split.cex     = 0.85,
    split.font    = 2,
    cex           = 0.75,
    tweak         = 1.1,
    compress      = FALSE,
    ycompress     = FALSE,
    main          = paste0(
      "Cây quyết định phân loại phân khúc giá xe cũ\n",
      subtitle_text
    )
  )
}

png("output_tree_plot.png", width = 2500, height = 1900, res = 140)
plot_decision_tree()
dev.off()

plot_feature_importance <- function(fi = feat_imp) {
  
  fi$feature_vn <- factor(fi$feature_vn,
                          levels = fi$feature_vn[order(fi$importance_pct)])
  
  ggplot(fi, aes(x = feature_vn, y = importance_pct)) +
    
    geom_col(aes(y = 100), fill = "gray92", width = 0.65) +
    
    geom_col(fill = "#1D9E75", alpha = 0.88, width = 0.65) +
    
    geom_text(
      aes(label = paste0(importance_pct, "%")),
      hjust = -0.18,
      size  = 3.6,
      color = "gray25",
      fontface = "bold"
    ) +
    
    coord_flip(clip = "off") +
    scale_y_continuous(
      limits = c(0, 115),
      breaks = c(0, 25, 50, 75, 100),
      labels = function(x) paste0(x, "%"),
      expand = expansion(mult = c(0, 0))
    ) +
    labs(
      title    = "Độ quan trọng của biến (Feature Importance)",
      subtitle = "Decision Tree – Phân loại phân khúc giá xe cũ",
      x        = NULL,
      y        = "Tầm quan trọng (%)"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title        = element_text(face = "bold", size = 14, color = "gray15"),
      plot.subtitle     = element_text(size = 11, color = "gray45", margin = margin(b = 10)),
      axis.text.y       = element_text(size = 12, color = "gray20"),
      axis.text.x       = element_text(size = 10, color = "gray50"),
      axis.title.x      = element_text(size = 10, color = "gray50", margin = margin(t = 6)),
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.grid.major.x = element_line(color = "gray90", linetype = "dashed"),
      plot.margin        = margin(12, 30, 12, 12)
    )
}

ggsave(
  "output_feature_importance.png",
  plot   = plot_feature_importance(),
  width  = 9, height = 5.5, dpi = 150
)

plot_confusion_matrix <- function(ct       = conf_table,
                                  accuracy = tree_accuracy,
                                  kappa    = tree_kappa,
                                  levels   = levels_all) {
  
  ct$du_doan <- factor(ct$du_doan, levels = rev(levels))
  ct$thuc_te <- factor(ct$thuc_te, levels = levels)
  
  col_totals <- tapply(ct$so_lan, ct$thuc_te, sum)
  ct$pct_col <- round(ct$so_lan / col_totals[as.character(ct$thuc_te)] * 100, 1)
  
  ct$label <- ifelse(
    ct$so_lan == 0, "0",
    paste0(ct$so_lan, "\n(", ct$pct_col, "%)")
  )
  
  ct$is_correct <- as.character(ct$du_doan) == as.character(ct$thuc_te)
  
  ggplot(ct, aes(x = thuc_te, y = du_doan, fill = so_lan)) +
    
    geom_tile(color = "white", linewidth = 1.2) +
    
    geom_tile(
      data = subset(ct, is_correct),
      aes(x = thuc_te, y = du_doan),
      fill  = NA,
      color = "#0F6E56",
      linewidth = 1.8
    ) +
    
    geom_text(
      aes(label = label,
          color = ifelse(so_lan > max(so_lan) * 0.55, "light", "dark")),
      size     = 3.6,
      fontface = "bold",
      lineheight = 1.2
    ) +
    scale_color_manual(
      values = c(light = "white", dark = "gray20"),
      guide  = "none"
    ) +
    
    scale_fill_gradient(
      low    = "#EAF3DE",
      high   = "#0F6E56",
      name   = "Số lượng",
      breaks = pretty_breaks(4)
    ) +
    
    scale_x_discrete(position = "bottom") +
    
    labs(
      title    = "Ma trận nhầm lẫn – Decision Tree",
      subtitle = sprintf(
        "Accuracy: %.1f%%  |  Kappa: %.4f  |  Số mẫu test: %d",
        accuracy * 100, kappa, sum(ct$so_lan)
      ),
      x = "Giá trị thực tế (Actual)",
      y = "Giá trị dự đoán (Predicted)"
    ) +
    
    theme_minimal(base_size = 13) +
    theme(
      plot.title        = element_text(face = "bold", size = 14, color = "gray15"),
      plot.subtitle     = element_text(size = 10.5, color = "gray45",
                                       margin = margin(b = 12)),
      axis.text         = element_text(size = 11, color = "gray20"),
      axis.text.x       = element_text(face = "bold"),
      axis.text.y       = element_text(face = "bold"),
      axis.title        = element_text(size = 11, color = "gray40"),
      panel.grid        = element_blank(),
      legend.position   = "right",
      legend.key.height = unit(1.2, "cm"),
      plot.margin       = margin(12, 12, 12, 12)
    )
}

ggsave(
  "output_confusion_matrix.png",
  plot   = plot_confusion_matrix(),
  width  = 8, height = 6.5, dpi = 150
)