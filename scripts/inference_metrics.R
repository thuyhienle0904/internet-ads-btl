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

# 95% Wilson score interval for a proportion k / n.
wilson_interval <- function(k, n, level = .95) {
  if (n == 0) return(c(NA_real_, NA_real_))
  as.numeric(prop.test(k, n, conf.level = level, correct = FALSE)$conf.int)
}

# Exact McNemar test for two classifiers judged on the same records:
# only the records where exactly one of the two flags is TRUE carry evidence.
exact_mcnemar <- function(first, second) {
  if (length(first) != length(second) || anyNA(first) || anyNA(second))
    stop("McNemar needs two complete logical vectors of equal length.")
  only_first <- sum(first & !second)
  only_second <- sum(!first & second)
  p <- if (only_first + only_second > 0)
    binom.test(only_first, only_first + only_second)$p.value else 1
  data.frame(only_first = only_first, only_second = only_second, p_value = p)
}

# Percentile interval for AP(second) - AP(first) on the same records.
# Ads and non-ads are resampled separately so every replicate keeps the
# observed class counts and always contains positives.
paired_ap_difference <- function(y, first, second, reps = 2000L, level = .95) {
  pos <- which(y == 1); neg <- which(y == 0)
  draws <- replicate(reps, {
    i <- c(sample(pos, replace = TRUE), sample(neg, replace = TRUE))
    average_precision(y[i], second[i]) - average_precision(y[i], first[i])
  })
  alpha <- (1 - level) / 2
  c(estimate = average_precision(y, second) - average_precision(y, first),
    lower = unname(quantile(draws, alpha)), upper = unname(quantile(draws, 1 - alpha)))
}
