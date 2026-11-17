# Run: Rscript tests/test_inference_metrics.R
arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", arg[1]))))
source(file.path(root, "scripts", "inference_metrics.R"))

# Both orders describe the same tied score group and must give the same AP.
stopifnot(identical(average_precision(c(1, 0), c(.5, .5)), .5))
stopifnot(identical(average_precision(c(0, 1), c(.5, .5)), .5))

y <- c(1, 0, 1, 0)
p <- c(.8, .8, .3, .1)
stopifnot(isTRUE(all.equal(average_precision(y, p), 7 / 12)))
stopifnot(identical(average_precision(y, p),
                    average_precision(y[c(2, 1, 3, 4)], p[c(2, 1, 3, 4)])))
curve <- precision_recall_points(y, p)
stopifnot(nrow(curve) == 3L, isTRUE(all.equal(curve$precision[1], .5)),
          isTRUE(all.equal(curve$recall[1], .5)))
message("Tie-aware AP and PR thresholds passed.")
