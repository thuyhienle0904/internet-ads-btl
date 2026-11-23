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

# Q3: one reference model and two extensions of it. The term pipeline's
# baseline equals the main-effects model (checked in 04_evaluation.R), so it
# appears once here.
models <- c(main = "Main effects", format_interaction = "Format + interaction",
            with_terms = "Main effects + six terms")
colors <- c(main = "#0072B2", format_interaction = "#D55E00", with_terms = "#009E73")
comparison <- rbind(evaluation[evaluation$model %in% c("main", "format_interaction"), ],
                    term_evaluation[term_evaluation$model == "with_terms", ])
comparison$label <- models[comparison$model]
write.csv(comparison, file.path(table_dir, "model_comparison.csv"), row.names = FALSE)

scores_for <- function(sample) {
  d <- if (sample == "test") test else train
  terms <- if (sample == "test") term_test else term_train
  terms <- terms[match(d$row_id, terms$row_id), ]
  list(y = d$Ad, main = d$main, format_interaction = d$format_interaction,
       with_terms = terms$with_terms)
}
pr <- do.call(rbind, lapply(c("train_oof", "test"), function(sample) {
  s <- scores_for(sample)
  do.call(rbind, lapply(names(models), function(model) {
    cbind(sample = sample, model = model, precision_recall_points(s$y, s[[model]]))
  }))
}))
write.csv(pr, file.path(table_dir, "precision_recall_points.csv"), row.names = FALSE)
draw_png("precision_recall_curves.png", 1600, 800, function() {
  par(mfrow = c(1, 2), mar = c(4.5, 4.5, 3, 1.5), cex.main = 1.25, cex.lab = 1.15, cex.axis = 1.05)
  for (sample in c("train_oof", "test")) {
    n_ads <- sum(scores_for(sample)$y)
    plot(c(0, 1), c(0, 1), type = "n", xlab = "Ad recall", ylab = "Ad precision",
         main = sprintf("%s (%d ads)", if (sample == "test") "Held-out test"
                        else "Training, out-of-fold", n_ads))
    abline(h = unique(comparison$min_precision), lty = 3, col = "#666666")
    for (model in names(models)) {
      d <- pr[pr$sample == sample & pr$model == model, ]
      lines(c(0, d$recall), c(1, d$precision), col = colors[model], lwd = 2)
    }
    ap <- comparison$average_precision[match(paste(names(models), sample),
                                             paste(comparison$model, comparison$sample))]
    legend("bottomleft", sprintf("%s (AP %.3f)", models, ap), col = colors, lwd = 2,
           bty = "o", bg = "white", box.col = "white", cex = .95)
  }
})

# The 2 x 2 confusion matrices expose class imbalance better than accuracy.
test_metrics <- comparison[comparison$sample == "test", ]
confusion <- do.call(rbind, lapply(seq_len(nrow(test_metrics)), function(i) {
  r <- test_metrics[i, ]
  data.frame(model = r$model, actual = c("Ad", "Ad", "Non-Ad", "Non-Ad"),
             predicted = c("Ad", "Non-Ad", "Ad", "Non-Ad"),
             count = c(r$tp, r$fn, r$fp, r$tn))
}))
write.csv(confusion, file.path(table_dir, "test_confusion_counts.csv"), row.names = FALSE)
draw_png("test_confusion_matrices.png", 2100, 800, function() {
  par(mfrow = c(1, 3), mar = c(10, 5.5, 4, 2), cex.main = 1.6, cex.lab = 1.4, cex.axis = 1.3)
  for (model in names(models)) {
    r <- test_metrics[test_metrics$model == model, ]
    z <- matrix(c(r$tp, r$fn, r$fp, r$tn), 2, 2, byrow = TRUE)
    plot(c(.5, 2.5), c(.5, 2.5), type = "n", axes = FALSE, xlab = "",
         ylab = "Actual", main = models[model])
    for (row in 1:2) for (col in 1:2) {
      rect(col - .48, 2 - row + .52, col + .48, 2 - row + 1.48,
           col = if (row == col) "#C7E9C0" else "#FDD0A2", border = "white")
      text(col, 3 - row, z[row, col], cex = 2.4)
    }
    axis(1, 1:2, c("Ad", "Non-Ad"))
    axis(2, 2:1, c("Ad", "Non-Ad"), las = 1)
    mtext("Predicted class", side = 1, line = 3, cex = 1.1)
    mtext(sprintf("Precision %.2f [%.2f, %.2f]", r$precision, r$precision_lower,
                  r$precision_upper), side = 1, line = 5.4, cex = 1.15)
    mtext(sprintf("Recall %.2f [%.2f, %.2f]", r$recall, r$recall_lower, r$recall_upper),
          side = 1, line = 7.2, cex = 1.15)
  }
})

figure_files <- c("missingness_ad_rates.png", "adjusted_odds_ratios.png",
                  "precision_recall_curves.png", "test_confusion_matrices.png")
report_dir <- file.path(root, "report", "figures", "inference")
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
if (!all(file.copy(file.path(figure_dir, figure_files), report_dir,
                   overwrite = TRUE))) stop("Could not publish inference figures.")
message("Created and published ", length(figure_files), " inference figures; wrote 5 CSV tables.")
