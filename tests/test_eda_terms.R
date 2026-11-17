# Integration check for the generated term EDA. Run after scripts/02_eda_descriptive.R.
data <- read.csv("data/processed/internet_ads_processed.csv", check.names = FALSE)
terms <- sprintf("term_%04d", 4:1557)
stopifnot(all(terms %in% names(data)))
x <- as.matrix(data[terms])
ad <- data$IsAds == "ad."
support <- colSums(x)
ad_support <- colSums(x[ad, , drop = FALSE])
nonad_support <- support - ad_support

table_dir <- "output/eda-r/tables"
all_terms <- read.csv(file.path(table_dir, "term_prevalence_all.csv"))
per_record <- read.csv(file.path(table_dir, "term_count_per_record.csv"))
overview <- read.csv(file.path(table_dir, "term_overview.csv"))
top <- read.csv(file.path(table_dir, "term_top_class_contrasts.csv"))

stopifnot(identical(all_terms$term, terms),
          identical(as.integer(all_terms$support), as.integer(support)),
          identical(as.integer(all_terms$ad_support), as.integer(ad_support)),
          identical(as.integer(all_terms$nonad_support), as.integer(nonad_support)),
          isTRUE(all.equal(all_terms$prevalence_ad,
                           unname(ad_support / sum(ad)))),
          isTRUE(all.equal(all_terms$prevalence_nonad,
                           unname(nonad_support / sum(!ad)))),
          identical(as.integer(per_record$active_terms),
                    as.integer(rowSums(x))))

eligible <- which(support >= 20)
differences <- ad_support / sum(ad) - nonad_support / sum(!ad)
ranked <- eligible[order(-abs(differences[eligible]),
                         -support[eligible], terms[eligible])]
stopifnot(identical(top$term, terms[head(ranked, 10)]),
          overview$terms_present_under_20 == sum(support < 20),
          overview$distinct_term_patterns ==
            sum(!duplicated(as.data.frame(t(x)))),
          overview$distinct_eligible_patterns ==
            sum(!duplicated(as.data.frame(t(x[, eligible, drop = FALSE])))))
message("Term EDA outputs match the processed data.")
