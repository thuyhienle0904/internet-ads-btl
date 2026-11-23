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

# Wilson interval for 65 of 77 test ads, as quoted in Chapter 5.
stopifnot(isTRUE(all.equal(round(wilson_interval(65, 77), 3), c(.747, .909))),
          all(is.na(wilson_interval(0, 0))))
# Exact McNemar uses only the disagreements: 1 vs 2 gives a two-sided p of 1.
m <- exact_mcnemar(c(TRUE, TRUE, FALSE, FALSE), c(TRUE, FALSE, TRUE, TRUE))
stopifnot(m$only_first == 1, m$only_second == 2, isTRUE(all.equal(m$p_value, 1)),
          exact_mcnemar(c(TRUE, FALSE), c(TRUE, FALSE))$p_value == 1)
# Identical scores give an AP difference of exactly zero in every replicate.
set.seed(1)
stopifnot(all(paired_ap_difference(y, p, p, reps = 50) == 0))
message("Interval and paired-comparison helpers passed.")
