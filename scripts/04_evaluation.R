root <- dirname(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))))
out <- file.path(root, "output", "inference")
source(file.path(root, "scripts", "inference_metrics.R"))
arg <- grep("^--min-precision=", commandArgs(TRUE), value = TRUE)
min_precision <- if (length(arg)) as.numeric(sub("^--min-precision=", "", arg[1])) else .70
if (!is.finite(min_precision) || min_precision <= 0 || min_precision > 1) stop("Invalid min precision.")
oof <- read.csv(file.path(out, "train_oof_predictions.csv"))
pair <- readRDS(file.path(out, "logistic_models.rds"))
source_path <- file.path(root, "data", "processed", "internet_ads_processed.csv")
data <- read.csv(source_path,
                 check.names = FALSE, stringsAsFactors = FALSE, na.strings = c("NA", "?", ""))
audit <- read.csv(file.path(out, "split_audit.csv"), stringsAsFactors = FALSE)
if (!identical(unname(tools::md5sum(source_path)), audit$source_md5[1]))
  stop("Processed data changed since training; rerun 03_inference_model.R.")
manifest <- read.csv(file.path(out, "processed_group_split.csv"), stringsAsFactors = FALSE)
idx <- match(as.character(data$row_id), as.character(manifest$row_id))
stopifnot(!anyNA(idx), !anyDuplicated(manifest$row_id))
test <- data[manifest$split[idx] == "test", ]
stopifnot(!length(intersect(unique(oof$group_id), unique(manifest$group_id[idx][manifest$split[idx] == "test"]))))

prepare <- function(d, medians) {
  for (nm in c("Height", "Width", "Aspect_Ratio")) {
    d[[nm]][is.na(d[[nm]])] <- medians[[nm]]
    d[[paste0("log2_", nm)]] <- log2(d[[nm]])
  }
  d$Local[is.na(d$Local)] <- medians[["Local"]]
  d$Local <- as.numeric(d$Local)
  d$wide_banner <- as.integer(d$Aspect_Ratio >= 6)
  d
}
x <- prepare(test, pair$medians)
y <- as.integer(test$IsAds == "ad.")
scores <- lapply(pair$fits, function(f) as.numeric(predict(f, newdata = x, type = "response")))
auc_roc <- function(y, p) {
  (sum(rank(p, ties.method = "average")[y == 1]) - sum(y) * (sum(y) + 1) / 2) /
    (sum(y) * sum(y == 0))
}
metrics <- function(y, p, threshold) {
  pred <- p >= threshold
  tp <- sum(pred & y == 1); fp <- sum(pred & y == 0)
  fn <- sum(!pred & y == 1); tn <- sum(!pred & y == 0)
  precision <- if (tp + fp) tp / (tp + fp) else NA_real_
  recall <- tp / (tp + fn)
  data.frame(threshold = threshold, tp = tp, fp = fp, fn = fn, tn = tn,
             precision = precision, recall = recall,
             f2 = if (is.na(precision) || 4 * precision + recall == 0) NA_real_
                  else 5 * precision * recall / (4 * precision + recall),
             accuracy = (tp + tn) / length(y), average_precision = average_precision(y, p),
             roc_auc = auc_roc(y, p))
}
choose_threshold <- function(y, p, floor) {
  candidates <- sort(unique(p), decreasing = TRUE)
  tp <- cumsum(y[order(-p)]); n_pred <- seq_along(y)
  # Evaluate only ends of tied score blocks.
  ends <- match(candidates, p[order(-p)])
  ends <- c(ends[-1] - 1L, length(y))
  precision <- tp[ends] / ends
  recall <- tp[ends] / sum(y)
  eligible <- which(precision >= floor)
  if (!length(eligible)) return(1)
  candidates[eligible[which.max(recall[eligible])]]
}
chosen <- lapply(names(scores), function(nm) {
  threshold <- choose_threshold(oof$Ad, oof[[nm]], min_precision)
  cbind(model = nm, sample = "train_oof", min_precision = min_precision,
        metrics(oof$Ad, oof[[nm]], threshold))
})
chosen_test <- lapply(seq_along(scores), function(i) {
  nm <- names(scores)[i]
  cbind(model = nm, sample = "test", min_precision = min_precision,
        metrics(y, scores[[nm]], chosen[[i]]$threshold))
})
result <- do.call(rbind, c(chosen, chosen_test))
write.csv(result, file.path(out, "logistic_evaluation.csv"), row.names = FALSE)
write.csv(data.frame(row_id = test$row_id, Ad = y, main = scores$main,
                     format_interaction = scores$format_interaction),
          file.path(out, "test_predictions.csv"), row.names = FALSE)

term_oof <- read.csv(file.path(out, "term_ablation_oof.csv"), stringsAsFactors = FALSE)
term_pair <- readRDS(file.path(out, "term_logistic_models.rds"))
term_x <- prepare(test, term_pair$medians)
term_scores <- lapply(term_pair$fits, function(f) {
  as.numeric(predict(f, newdata = term_x, type = "response"))
})
names(term_scores) <- c("baseline", "with_terms")

term_chosen <- lapply(names(term_scores), function(nm) {
  threshold <- choose_threshold(term_oof$Ad, term_oof[[nm]], min_precision)
  cbind(model = nm, sample = "train_oof", min_precision = min_precision,
        metrics(term_oof$Ad, term_oof[[nm]], threshold))
})
term_chosen_test <- lapply(seq_along(term_scores), function(i) {
  nm <- names(term_scores)[i]
  cbind(model = nm, sample = "test", min_precision = min_precision,
        metrics(y, term_scores[[nm]], term_chosen[[i]]$threshold))
})
term_result <- do.call(rbind, c(term_chosen, term_chosen_test))
write.csv(term_result, file.path(out, "term_ablation_evaluation.csv"), row.names = FALSE)
write.csv(data.frame(row_id = test$row_id, Ad = y,
                     baseline = term_scores$baseline,
                     with_terms = term_scores$with_terms),
          file.path(out, "term_ablation_test_predictions.csv"), row.names = FALSE)
message("Held-out evaluation complete: ", length(y), " test records.")
