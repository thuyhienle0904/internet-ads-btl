# Tables and figures from the processed-data inference pipeline.
# Run after 03_inference_model.R and 04_evaluation.R:
# Rscript scripts/05_inference_visuals.R
file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
if (!length(file_arg)) stop("Run this script with Rscript.")
root <- dirname(dirname(normalizePath(sub("^--file=", "", file_arg[1]))))
source(file.path(root, "scripts", "inference_metrics.R"))
out <- file.path(root, "output", "inference")
figure_dir <- file.path(out, "figures")
table_dir <- file.path(out, "tables")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

read_result <- function(name) {
  path <- file.path(out, name)
  if (!file.exists(path)) stop("Missing ", path, "; run scripts 03 and 04 first.")
  read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
audit <- read_result("split_audit.csv")
source_path <- file.path(root, "data", "processed", "internet_ads_processed.csv")
if (!identical(unname(tools::md5sum(source_path)), audit$source_md5[1]))
  stop("Processed data changed; rerun scripts 03 and 04.")
chi <- read_result("missingness_chisquare.csv")
counts <- read_result("missingness_contingency.csv")
or <- read_result("main_effect_odds_ratios.csv")
evaluation <- read_result("logistic_evaluation.csv")
train <- read_result("train_oof_predictions.csv")
test <- read_result("test_predictions.csv")
term_evaluation <- read_result("term_ablation_evaluation.csv")
term_train <- read_result("term_ablation_oof.csv")
term_test <- read_result("term_ablation_test_predictions.csv")
stopifnot(nrow(train) == audit$train_n, nrow(test) == audit$test_n,
          nrow(term_train) == audit$train_n, nrow(term_test) == audit$test_n,
          setequal(term_train$row_id, train$row_id),
          setequal(term_test$row_id, test$row_id),
          all(c("main", "format_interaction", "Ad") %in% names(train)),
          all(c("main", "format_interaction", "Ad") %in% names(test)),
          all(evaluation$sample %in% c("train_oof", "test")))

draw_png <- function(name, width, height, plot_fn) {
  png(file.path(figure_dir, name), width = width, height = height, res = 150)
  tryCatch(plot_fn(), finally = dev.off())
}
colors <- c(main = "#0072B2", format_interaction = "#D55E00")
model_labels <- c(main = "Main effects", format_interaction = "Format + interaction")

# Q1: show conditional class rates with denominators alongside the test table.
missing_table <- data.frame(
  missingness = c("No missing original feature", "At least one missing feature"),
  ad = as.integer(counts[["ad."]]),
  nonad = as.integer(counts[["nonad."]]))
missing_table$total <- missing_table$ad + missing_table$nonad
missing_table$ad_rate <- missing_table$ad / missing_table$total
missing_table$chi_square <- chi$statistic[1]
missing_table$p_value <- chi$p_value[1]
write.csv(missing_table, file.path(table_dir, "missingness_ad_rates.csv"), row.names = FALSE)
draw_png("missingness_ad_rates.png", 1100, 750, function() {
  par(mar = c(6, 5, 4, 2))
  values <- 100 * missing_table$ad_rate
  at <- barplot(values, names.arg = c("Complete", "Any missing"),
                col = c("#0072B2", "#D55E00"), border = NA,
                ylim = c(0, max(values) * 1.35), ylab = "Ad rate (%)",
                main = "Missingness and advertisement status | train")
  text(at, values, sprintf("%.1f%%\n(n=%d)", values, missing_table$total),
       pos = 3, cex = 1)
  mtext(sprintf("Pearson chi-square p = %.4f; rates are associations, not causal effects",
                chi$p_value[1]), side = 1, line = 4, cex = .85)
})

# Q2: exclude the intercept; a log axis gives multiplicative ORs honest spacing.
or <- or[or$term != "(Intercept)", ]
or$label <- c(log2_Height = "Height doubled", log2_Width = "Width doubled",
              Local = "Local = 1", missing_size = "Any missing")[or$term]
if (anyNA(or$label)) stop("Unrecognized odds-ratio term.")
write.csv(or[c("term", "label", "odds_ratio", "lower_95", "upper_95", "p_value")],
          file.path(table_dir, "adjusted_odds_ratios.csv"), row.names = FALSE)
draw_png("adjusted_odds_ratios.png", 1200, 780, function() {
  par(mar = c(5, 12, 4, 3))
  y <- rev(seq_len(nrow(or)))
  plot(or$odds_ratio, y, log = "x", xlim = range(c(.7, or$lower_95, or$upper_95)) * c(.9, 1.1),
       ylim = c(.5, nrow(or) + .5), yaxt = "n", ylab = "", xlab = "Adjusted odds ratio (log scale)",
       pch = 19, cex = 1.35, col = "#0072B2", main = "Main-effects logistic model | train")
  segments(or$lower_95, y, or$upper_95, y, lwd = 2, col = "#0072B2")
  abline(v = 1, lty = 2, col = "#666666")
  axis(2, at = y, labels = or$label, las = 1)
})

# Q3: PR curves use the true labels, showing both train OOF and locked test.
pr <- do.call(rbind, lapply(c("train_oof", "test"), function(sample) {
  d <- if (sample == "test") test else train
  do.call(rbind, lapply(names(colors), function(model) {
    cbind(sample = sample, model = model,
          precision_recall_points(d$Ad, d[[model]]))
  }))
}))
write.csv(pr, file.path(table_dir, "precision_recall_points.csv"), row.names = FALSE)

# The 2 x 2 confusion matrices expose class imbalance better than accuracy.
test_metrics <- evaluation[evaluation$sample == "test", ]
confusion <- do.call(rbind, lapply(seq_len(nrow(test_metrics)), function(i) {
  r <- test_metrics[i, ]
  data.frame(model = r$model, actual = c("Ad", "Ad", "Non-Ad", "Non-Ad"),
             predicted = c("Ad", "Non-Ad", "Ad", "Non-Ad"),
             count = c(r$tp, r$fn, r$fp, r$tn))
}))
write.csv(confusion, file.path(table_dir, "test_confusion_counts.csv"), row.names = FALSE)
write.csv(evaluation, file.path(table_dir, "model_comparison.csv"), row.names = FALSE)
draw_png("test_confusion_matrices.png", 1400, 760, function() {
  par(mfrow = c(1, 2), mar = c(8, 5, 4, 3))
  for (model in names(colors)) {
    r <- test_metrics[test_metrics$model == model, ]
    z <- matrix(c(r$tp, r$fn, r$fp, r$tn), 2, 2, byrow = TRUE)
    plot(c(.5, 2.5), c(.5, 2.5), type = "n", axes = FALSE, xlab = "",
         ylab = "Actual", main = sprintf("%s | test", model_labels[model]))
    for (row in 1:2) for (col in 1:2) {
      rect(col - .48, 2 - row + .52, col + .48, 2 - row + 1.48,
           col = if (row == col) "#C7E9C0" else "#FDD0A2", border = "white")
      text(col, 3 - row, z[row, col], cex = 1.7)
    }
    axis(1, 1:2, c("Ad", "Non-Ad"))
    axis(2, 2:1, c("Ad", "Non-Ad"), las = 1)
    mtext("Predicted class", side = 1, line = 2.7)
    mtext(sprintf("Precision %.3f | Recall %.3f | F2 %.3f",
                  r$precision, r$recall, r$f2), side = 1, line = 5, cex = .85)
  }
})

# Term ablation: paired PR panels make ranking gains visible at each recall.
term_colors <- c(baseline = "#0072B2", with_terms = "#D55E00")
term_labels <- c(baseline = "No terms", with_terms = "With six terms")
term_pr <- do.call(rbind, lapply(c("train_oof", "test"), function(sample) {
  d <- if (sample == "test") term_test else term_train
  do.call(rbind, lapply(names(term_colors), function(model) {
    cbind(sample = sample, model = model,
          precision_recall_points(d$Ad, d[[model]]))
  }))
}))
write.csv(term_pr, file.path(table_dir, "term_precision_recall_points.csv"),
          row.names = FALSE)
draw_png("precision_recall_curves.png", 1500, 1400, function() {
  par(mfrow = c(2, 2), mar = c(4, 4, 3, 1.5), oma = c(0, 0, 1, 0))
  for (comparison in c("geometry", "terms")) {
    curve <- if (comparison == "geometry") pr else term_pr
    metric <- if (comparison == "geometry") evaluation else term_evaluation
    palette <- if (comparison == "geometry") colors else term_colors
    labels <- if (comparison == "geometry") model_labels else term_labels
    for (sample in c("train_oof", "test")) {
      plot(c(0, 1), c(0, 1), type = "n", xlab = "Ad recall",
           ylab = "Ad precision",
           main = sprintf("%s | %s",
                          if (comparison == "geometry") "Geometry models" else "Term ablation",
                          if (sample == "test") "held-out test" else "train OOF"))
      abline(h = unique(metric$min_precision), lty = 3, col = "#666666")
      for (model in names(palette)) {
        d <- curve[curve$sample == sample & curve$model == model, ]
        lines(c(0, d$recall), c(1, d$precision), col = palette[model], lwd = 2)
      }
      legend("topright", vapply(names(palette), function(model) {
        ap <- metric$average_precision[metric$sample == sample & metric$model == model]
        sprintf("%s (AP %.3f)", labels[model], ap)
      }, character(1)), col = palette, lty = 1, lwd = 2,
      bty = "o", bg = "white", box.col = "white", cex = .76)
    }
  }
})

term_test_metrics <- term_evaluation[term_evaluation$sample == "test", ]
draw_png("term_test_confusion_matrices.png", 1400, 760, function() {
  par(mfrow = c(1, 2), mar = c(8, 5, 4, 3))
  for (model in names(term_colors)) {
    r <- term_test_metrics[term_test_metrics$model == model, ]
    z <- matrix(c(r$tp, r$fn, r$fp, r$tn), 2, 2, byrow = TRUE)
    plot(c(.5, 2.5), c(.5, 2.5), type = "n", axes = FALSE, xlab = "",
         ylab = "Actual", main = sprintf("%s | held-out test", term_labels[model]))
    for (row in 1:2) for (col in 1:2) {
      rect(col - .48, 2 - row + .52, col + .48, 2 - row + 1.48,
           col = if (row == col) "#C7E9C0" else "#FDD0A2", border = "white")
      text(col, 3 - row, z[row, col], cex = 1.7)
    }
    axis(1, 1:2, c("Ad", "Non-Ad"))
    axis(2, 2:1, c("Ad", "Non-Ad"), las = 1)
    mtext("Predicted class", side = 1, line = 2.7)
    mtext(sprintf("Precision %.3f | Recall %.3f | F2 %.3f",
                  r$precision, r$recall, r$f2), side = 1, line = 5, cex = .85)
  }
})

figure_files <- c("missingness_ad_rates.png", "adjusted_odds_ratios.png",
                  "precision_recall_curves.png", "test_confusion_matrices.png",
                  "term_test_confusion_matrices.png")
report_dir <- file.path(root, "report", "figures", "inference")
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
if (!all(file.copy(file.path(figure_dir, figure_files), report_dir,
                   overwrite = TRUE))) stop("Could not publish inference figures.")
message("Created and published 5 inference figures; wrote 6 CSV tables.")
