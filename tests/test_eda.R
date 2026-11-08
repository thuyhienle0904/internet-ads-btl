# Synthetic data only. Run from repository root: Rscript tests/test_eda.R
source("scripts/eda_helpers.R")
toy <- data.frame(label = c("ad", "ad", "nonad", "nonad"),
                  height = c(1, 3, NA, 5), flag = c(1, NA, 0, 1),
                  empty = rep(NA_real_, 4), constant = rep(2, 4))
config <- list(input_file = "synthetic-only", label_col = "label",
  numeric_cols = c("height", "empty", "constant"), binary_cols = "flag",
  plot_numeric_cols = c("height", "empty", "constant"), plot_binary_cols = "flag",
  scope = "synthetic test, not report data", output_dir = tempfile("eda-test-"),
  expected_labels = c("ad", "nonad"))
stopifnot(isTRUE(validate_eda(toy, config)))
labels <- summarize_labels(toy, "label")
stopifnot(identical(labels$n, c(2L, 2L)), all(labels$proportion == .5))
numeric <- summarize_numeric(toy, config$numeric_cols, "label")
row <- numeric[numeric$variable == "height" & numeric$group == "all", ]
stopifnot(row$n_valid == 3, row$n_missing == 1, row$mean == 3, row$sd == 2,
          row$q1 == 2, row$median == 3, row$q3 == 4)
stopifnot(all(is.na(numeric$mean[numeric$variable == "empty"])))
binary <- summarize_binary(toy, "flag", "label")
stopifnot(binary$proportion_one[binary$group == "ad"] == 1,
          binary$proportion_one[binary$group == "nonad"] == .5,
          binary$n_valid[binary$group == "ad"] == 1)
bad <- toy; bad$flag[1] <- 2
stopifnot(inherits(try(validate_eda(bad, config), silent = TRUE), "try-error"))
bad <- toy; bad$label[1] <- NA
stopifnot(inherits(try(validate_eda(bad, config), silent = TRUE), "try-error"))
bad <- toy; bad$height[1] <- Inf
stopifnot(inherits(try(validate_eda(bad, config), silent = TRUE), "try-error"))
result <- run_eda(config, toy)
stopifnot(file.exists(file.path(config$output_dir, "tables", "numeric_summary.csv")),
          file.exists(file.path(config$output_dir, "figures", "class_distribution.png")),
          file.exists(file.path(config$output_dir, "run_metadata.txt")))
single_class <- toy[toy$label == "ad", ]
config$output_dir <- tempfile("eda-one-class-")
run_eda(config, single_class)
message("EDA synthetic checks passed. Temporary outputs are not real results.")
