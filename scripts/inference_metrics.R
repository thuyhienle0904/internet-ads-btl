# One point per distinct score: tied observations enter together at a threshold.
precision_recall_points <- function(y, score) {
  if (length(y) != length(score) || !length(y) ||
      anyNA(y) || anyNA(score) || any(!is.finite(score)) ||
      any(!y %in% 0:1) || sum(y) == 0)
    stop("PR metrics require finite scores and binary labels with at least one Ad.")
  ord <- order(score, decreasing = TRUE)
  sorted <- score[ord]
  ends <- cumsum(rle(sorted)$lengths)
  tp <- cumsum(y[ord])[ends]
  data.frame(threshold = sorted[ends], recall = tp / sum(y),
             precision = tp / ends)
}

average_precision <- function(y, score) {
  curve <- precision_recall_points(y, score)
  sum(diff(c(0, curve$recall)) * curve$precision)
}

precision_constrained_threshold <- function(y, score, floor) {
  curve <- precision_recall_points(y, score)
  eligible <- which(curve$precision >= floor)
  if (!length(eligible)) return(1)
  curve$threshold[eligible[which.max(curve$recall[eligible])]]
}
