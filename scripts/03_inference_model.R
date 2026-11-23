root <- dirname(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))))
out <- file.path(root, "output", "inference")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source(file.path(root, "scripts", "term_names.R"))
term_label <- load_term_names(root)

read <- function(path) {
  d <- read.csv(path, check.names = FALSE, stringsAsFactors = FALSE, na.strings = c("NA", "?", ""))
  stopifnot(all(c("row_id", "Height", "Width", "Aspect_Ratio", "Local", "IsAds", "missing_size") %in% names(d)))
  stopifnot(!anyDuplicated(d$row_id), all(d$IsAds %in% c("ad.", "nonad.")))
  d
}
source_path <- file.path(root, "data", "processed", "internet_ads_processed.csv")
data <- read(source_path)
feature_cols <- setdiff(names(data), c("row_id", "IsAds", "missing_size"))
key <- do.call(paste, c(data[feature_cols], sep = "\r"))
data$group_id <- sprintf("grp_%06d", match(key, unique(key)))
group_rows <- split(seq_len(nrow(data)), data$group_id)
group_ad <- vapply(group_rows, function(i) any(data$IsAds[i] == "ad."), logical(1))
set.seed(42)
test_groups <- unlist(lapply(c(TRUE, FALSE), function(is_ad) {
  candidates <- names(group_ad)[group_ad == is_ad]
  sample(candidates, size = round(.20 * length(candidates)))
}), use.names = FALSE)
data$split <- ifelse(data$group_id %in% test_groups, "test", "train")
train <- data[data$split == "train", ]
stopifnot(!length(intersect(unique(data$group_id[data$split == "train"]),
                            unique(data$group_id[data$split == "test"]))))
manifest <- data.frame(row_id = data$row_id, group_id = data$group_id,
                       split = data$split, IsAds = data$IsAds)
write.csv(manifest, file.path(out, "processed_group_split.csv"), row.names = FALSE)
write.csv(data.frame(source = "data/processed/internet_ads_processed.csv",
                     source_md5 = unname(tools::md5sum(source_path)),
                     seed = 42, train_n = nrow(train), test_n = sum(data$split == "test"),
                     train_ad = sum(train$IsAds == "ad."),
                     test_ad = sum(data$IsAds[data$split == "test"] == "ad."),
                     group_overlap = 0),
          file.path(out, "split_audit.csv"), row.names = FALSE)

tab <- table(Missing = factor(train$missing_size, levels = 0:1),
             Class = factor(train$IsAds, levels = c("ad.", "nonad.")))
stopifnot(all(tab > 0))
chi <- suppressWarnings(chisq.test(tab, correct = FALSE))
if (any(chi$expected < 5)) stop("Chi-square expected count below 5; use an exact test.")
write.csv(as.data.frame.matrix(tab), file.path(out, "missingness_contingency.csv"))
write.csv(data.frame(n = sum(tab), statistic = unname(chi$statistic), df = unname(chi$parameter),
                     p_value = chi$p.value, min_expected = min(chi$expected),
                     cramers_v = sqrt(unname(chi$statistic) / sum(tab)),
                     ad_rate_missing = tab["1", "ad."] / sum(tab["1", ]),
                     ad_rate_observed = tab["0", "ad."] / sum(tab["0", ])),
          file.path(out, "missingness_chisquare.csv"), row.names = FALSE)

# Two-sample comparison of observed widths on training data (Welch t-test).
# Width is right-skewed, but each class has hundreds of observed widths, so
# the sample means are close to normal.
width_ad <- train$Width[train$IsAds == "ad." & !is.na(train$Width)]
width_nonad <- train$Width[train$IsAds == "nonad." & !is.na(train$Width)]
welch <- t.test(width_ad, width_nonad, var.equal = FALSE)
write.csv(data.frame(n_ad = length(width_ad), n_nonad = length(width_nonad),
                     mean_ad = mean(width_ad), mean_nonad = mean(width_nonad),
                     sd_ad = sd(width_ad), sd_nonad = sd(width_nonad),
                     median_ad = median(width_ad), median_nonad = median(width_nonad),
                     difference = mean(width_ad) - mean(width_nonad),
                     lower_95 = welch$conf.int[1], upper_95 = welch$conf.int[2],
                     t = unname(welch$statistic), df = unname(welch$parameter),
                     p_value = welch$p.value),
          file.path(out, "width_welch_test.csv"), row.names = FALSE)

prepare <- function(d, medians) {
  d$Ad <- as.integer(d$IsAds == "ad.")
  for (nm in c("Height", "Width", "Aspect_Ratio")) {
    d[[paste0(nm, "_missing")]] <- as.integer(is.na(d[[nm]]))
    d[[nm]][is.na(d[[nm]])] <- medians[[nm]]
    d[[paste0("log2_", nm)]] <- log2(d[[nm]])
  }
  d$Local_missing <- as.integer(is.na(d$Local))
  d$Local[is.na(d$Local)] <- medians[["Local"]]
  d$Local <- as.numeric(d$Local)
  d$wide_banner <- as.integer(d$Aspect_Ratio >= 6)
  d
}
# The one reference model for both comparisons in Chapter 5:
# geometry shape (fit_pair) and term indicators (fit_term_models).
base_formula <- Ad ~ log2_Height + log2_Width + Local + missing_size
fit_pair <- function(d) {
  med <- vapply(c("Height", "Width", "Aspect_Ratio"), function(nm) median(d[[nm]], na.rm = TRUE), numeric(1))
  med <- c(med, Local = as.numeric(names(which.max(table(d$Local)))))
  x <- prepare(d, med)
  rich_formula <- Ad ~ splines::ns(log2_Height, df = 3) +
    splines::ns(log2_Width, df = 3) + wide_banner +
    log2_Height:log2_Width + Local + missing_size
  fits <- list(main = glm(base_formula, family = binomial(), data = x),
               format_interaction = glm(rich_formula, family = binomial(), data = x))
  if (any(vapply(fits, function(f) !f$converged || anyNA(coef(f)), logical(1))))
    stop("Logistic fit failed to converge or has aliased coefficients.")
  list(medians = med, fits = fits)
}
predict_pair <- function(pair, d) {
  x <- prepare(d, pair$medians)
  lapply(pair$fits, function(f) as.numeric(predict(f, newdata = x, type = "response")))
}

groups <- train[!duplicated(train$group_id), c("group_id", "IsAds")]
set.seed(42)
groups$fold <- NA_integer_
for (label in c("ad.", "nonad.")) {
  idx <- which(groups$IsAds == label)
  groups$fold[idx] <- sample(rep(1:5, length.out = length(idx)))
}
fold <- groups$fold[match(train$group_id, groups$group_id)]
stopifnot(!anyNA(fold))
oof <- data.frame(row_id = train$row_id, Ad = as.integer(train$IsAds == "ad."),
                  group_id = train$group_id, fold = fold, main = NA_real_,
                  format_interaction = NA_real_)
for (k in 1:5) {
  pair <- fit_pair(train[fold != k, ])
  pred <- predict_pair(pair, train[fold == k, ])
  for (nm in names(pred)) oof[fold == k, nm] <- pred[[nm]]
}
stopifnot(!anyNA(oof$main), !anyNA(oof$format_interaction))
write.csv(oof, file.path(out, "train_oof_predictions.csv"), row.names = FALSE)
final <- fit_pair(train)
saveRDS(final, file.path(out, "logistic_models.rds"))

s <- summary(final$fits$main)$coefficients
or <- data.frame(term = rownames(s), coefficient = s[, 1], std_error = s[, 2],
                 odds_ratio = exp(s[, 1]), lower_95 = exp(s[, 1] - qnorm(.975) * s[, 2]),
                 upper_95 = exp(s[, 1] + qnorm(.975) * s[, 2]), p_value = s[, 4],
                 row.names = NULL)
write.csv(or, file.path(out, "main_effect_odds_ratios.csv"), row.names = FALSE)
message("Inference complete: ", nrow(train), " train records from data/processed; test labels unused for fitting.")

# Term inference: select on training data and repeat selection inside each
# grouped fold. The existing split and folds above are shared by design.
term_names <- names(term_label)
if (!all(term_names %in% names(data))) stop("Term columns are missing.")
if (anyNA(data[term_names]) || any(!as.matrix(data[term_names]) %in% 0:1))
  stop("Term indicators must be complete binary values.")
select_terms <- function(d, n = 6L) {
  x <- as.matrix(d[term_names])
  ad <- d$IsAds == "ad."
  support <- colSums(x)
  ad_support <- colSums(x[ad, , drop = FALSE])
  difference <- ad_support / sum(ad) - (support - ad_support) / sum(!ad)
  eligible <- which(support >= 20)
  if (length(eligible) < n) stop("Too few supported terms.")
  term_names[head(eligible[order(-abs(difference[eligible]),
                                 -support[eligible], term_names[eligible])], n)]
}
selected_terms <- select_terms(train)
write.csv(data.frame(rank = seq_along(selected_terms), term = selected_terms,
                     name = term_label[selected_terms], row.names = NULL),
          file.path(out, "term_selected_train.csv"), row.names = FALSE)

term_matrix <- as.matrix(train[term_names])
term_ad <- train$IsAds == "ad."
term_support <- colSums(term_matrix)
term_ad_support <- colSums(term_matrix[term_ad, , drop = FALSE])
term_candidates <- which(term_support >= 20)
term_tests <- lapply(term_candidates, function(j) {
  counts <- matrix(c(term_ad_support[j], sum(term_ad) - term_ad_support[j],
                     term_support[j] - term_ad_support[j],
                     sum(!term_ad) - term_support[j] + term_ad_support[j]),
                   nrow = 2, byrow = TRUE)
  expected <- outer(rowSums(counts), colSums(counts)) / sum(counts)
  valid <- min(expected) >= 5
  result <- if (valid) suppressWarnings(chisq.test(counts, correct = FALSE)) else NULL
  data.frame(term = term_names[j], name = unname(term_label[j]), ad_present = counts[1, 1],
             nonad_present = counts[2, 1],
             ad_prevalence = counts[1, 1] / sum(term_ad),
             nonad_prevalence = counts[2, 1] / sum(!term_ad),
             min_expected = min(expected),
             chi_square = if (valid) unname(result$statistic) else NA_real_,
             p_value = if (valid) result$p.value else NA_real_)
})
term_chi <- do.call(rbind, term_tests)
term_chi$bh_p_value <- NA_real_
valid_term_tests <- !is.na(term_chi$p_value)
term_chi$bh_p_value[valid_term_tests] <-
  p.adjust(term_chi$p_value[valid_term_tests], method = "BH")
term_chi$selected <- term_chi$term %in% selected_terms
write.csv(term_chi, file.path(out, "term_chisquare_train.csv"), row.names = FALSE)

prepare_terms <- function(d, medians) {
  d <- prepare(d, medians)
  d
}
fit_term_models <- function(d, chosen) {
  med <- vapply(c("Height", "Width", "Aspect_Ratio"),
                function(nm) median(d[[nm]], na.rm = TRUE), numeric(1))
  med <- c(med, Local = as.numeric(names(which.max(table(d$Local)))))
  x <- prepare_terms(d, med)
  augmented <- reformulate(c(attr(stats::terms(base_formula), "term.labels"), chosen),
                           response = "Ad")
  fits <- list(baseline = glm(base_formula, family = binomial(), data = x),
               with_terms = glm(augmented, family = binomial(), data = x))
  if (any(vapply(fits, function(f) !f$converged || anyNA(coef(f)), logical(1))))
    stop("Term logistic fit did not converge or has aliased coefficients.")
  list(medians = med, fits = fits, selected = chosen)
}
predict_term_models <- function(model, d) {
  x <- prepare_terms(d, model$medians)
  lapply(model$fits, function(f) as.numeric(predict(f, x, type = "response")))
}
term_oof <- data.frame(row_id = train$row_id,
                       Ad = as.integer(train$IsAds == "ad."), fold = fold,
                       baseline = NA_real_, with_terms = NA_real_)
fold_terms <- lapply(1:5, function(k) {
  chosen <- select_terms(train[fold != k, , drop = FALSE])
  model <- fit_term_models(train[fold != k, , drop = FALSE], chosen)
  prediction <- predict_term_models(model, train[fold == k, , drop = FALSE])
  for (nm in names(prediction)) term_oof[fold == k, nm] <<- prediction[[nm]]
  data.frame(fold = k, rank = seq_along(chosen), term = chosen,
             name = unname(term_label[chosen]))
})
if (anyNA(term_oof)) stop("Incomplete term out-of-fold predictions.")
write.csv(do.call(rbind, fold_terms), file.path(out, "term_selected_by_fold.csv"), row.names = FALSE)
write.csv(term_oof, file.path(out, "term_ablation_oof.csv"), row.names = FALSE)
final_terms <- fit_term_models(train, selected_terms)
saveRDS(final_terms, file.path(out, "term_logistic_models.rds"))
joint_terms <- anova(final_terms$fits$baseline, final_terms$fits$with_terms,
                     test = "Chisq")
write.csv(data.frame(df = joint_terms$Df[2],
                     deviance_reduction = joint_terms$Deviance[2],
                     p_value = joint_terms$`Pr(>Chi)`[2]),
          file.path(out, "term_logistic_joint_test.csv"), row.names = FALSE)
term_coefficients <- summary(final_terms$fits$with_terms)$coefficients[
  selected_terms, , drop = FALSE]
write.csv(data.frame(term = selected_terms, name = unname(term_label[selected_terms]),
                     coefficient = term_coefficients[, 1],
                     odds_ratio = exp(term_coefficients[, 1]),
                     lower_95 = exp(term_coefficients[, 1] -
                                      qnorm(.975) * term_coefficients[, 2]),
                     upper_95 = exp(term_coefficients[, 1] +
                                      qnorm(.975) * term_coefficients[, 2]),
                     p_value = term_coefficients[, 4], row.names = NULL),
          file.path(out, "term_adjusted_odds_ratios.csv"), row.names = FALSE)
message("Term models complete: ", paste(selected_terms, collapse = ", "))
