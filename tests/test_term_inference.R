# Run after scripts/03_inference_model.R and 04_evaluation.R.
root <- normalizePath(".")
source(file.path(root, "scripts", "inference_metrics.R"))
out <- file.path(root, "output", "inference")
manifest <- read.csv(file.path(out, "processed_group_split.csv"))
oof <- read.csv(file.path(out, "term_ablation_oof.csv"))
test <- read.csv(file.path(out, "term_ablation_test_predictions.csv"))
selected <- read.csv(file.path(out, "term_selected_train.csv"))
fold_selected <- read.csv(file.path(out, "term_selected_by_fold.csv"))
chi <- read.csv(file.path(out, "term_chisquare_train.csv"))
evaluation <- read.csv(file.path(out, "term_ablation_evaluation.csv"))
stopifnot(nrow(oof) == sum(manifest$split == "train"),
          nrow(test) == sum(manifest$split == "test"),
          setequal(oof$row_id, manifest$row_id[manifest$split == "train"]),
          setequal(test$row_id, manifest$row_id[manifest$split == "test"]),
          !length(intersect(oof$row_id, test$row_id)),
          all(is.finite(oof$baseline)), all(is.finite(oof$with_terms)),
          all(is.finite(test$baseline)), all(is.finite(test$with_terms)),
          nrow(selected) == 6, !anyDuplicated(selected$term),
          all(table(fold_selected$fold) == 6),
          setequal(selected$term, chi$term[chi$selected]),
          all(chi$min_expected[chi$selected] >= 5),
          all(is.na(chi$p_value[chi$min_expected < 5])))
for (model in c("baseline", "with_terms")) {
  train_result <- evaluation[evaluation$model == model &
                               evaluation$sample == "train_oof", ]
  test_result <- evaluation[evaluation$model == model &
                              evaluation$sample == "test", ]
  threshold <- precision_constrained_threshold(oof$Ad, oof[[model]], .70)
  stopifnot(nrow(train_result) == 1, nrow(test_result) == 1,
            isTRUE(all.equal(train_result$threshold, threshold)),
            isTRUE(all.equal(test_result$threshold, threshold)),
            isTRUE(all.equal(test_result$average_precision,
                             average_precision(test$Ad, test[[model]]))),
            test_result$tp == sum(test[[model]] >= threshold & test$Ad == 1),
            test_result$fp == sum(test[[model]] >= threshold & test$Ad == 0))
}
message("Term inference split and metrics checks passed.")

# Term names come from data/reference/ad.names in original column order.
source(file.path(root, "scripts", "term_names.R"))
term_label <- load_term_names(root)
stopifnot(length(term_label) == 1554L,
          term_label[["term_0004"]] == "url*images+buttons",
          term_label[["term_1243"]] == "ancurl*com",
          identical(unname(term_label[selected$term]), selected$name))
# One baseline: the term pipeline's model without terms is the main-effects model.
main_test <- read.csv(file.path(out, "test_predictions.csv"))
stopifnot(isTRUE(all.equal(test$baseline, main_test$main[match(test$row_id, main_test$row_id)])))
comparisons <- read.csv(file.path(out, "model_comparison_tests.csv"))
stopifnot(nrow(comparisons) == 2L,
          all(comparisons$ap_difference_lower <= comparisons$ap_difference),
          all(comparisons$ap_difference <= comparisons$ap_difference_upper))
message("Term names and shared-baseline checks passed.")
