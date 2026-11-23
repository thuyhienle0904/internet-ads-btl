# Descriptive analysis of the 1,554 binary term indicators.
# Run standalone: Rscript scripts/eda_terms.R
arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
if (!length(arg)) stop("Run this script with Rscript.")
root <- normalizePath(".")
if (!file.exists(file.path(root, "data", "processed", "internet_ads_processed.csv")))
  stop("Run from the repository root.")
source(file.path(root, "scripts", "term_names.R"))
original_names <- load_term_names(root)
input <- file.path(root, "data", "processed", "internet_ads_processed.csv")
out <- file.path(root, "output", "eda-r")
table_dir <- file.path(out, "tables")
figure_dir <- file.path(out, "figures")
report_dir <- file.path(root, "report", "figures", "eda")
for (path in c(table_dir, figure_dir, report_dir))
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
data <- read.csv(input, check.names = FALSE, stringsAsFactors = FALSE,
                 na.strings = c("", "NA"))
terms <- grep("^term_[0-9]{4}$", names(data), value = TRUE)
if (length(terms) != 1554L) stop("Expected exactly 1,554 term indicators.")
x <- as.matrix(data[terms])
storage.mode(x) <- "integer"
if (anyNA(x) || any(!x %in% 0:1)) stop("Terms must be complete binary 0/1 values.")
y <- data$IsAds == "ad."
if (anyNA(y) || !all(data$IsAds %in% c("ad.", "nonad."))) stop("Invalid labels.")

support <- colSums(x)
ad_support <- colSums(x[y, , drop = FALSE])
nonad_support <- support - ad_support
n_ad <- sum(y); n_nonad <- sum(!y)
# Identical columns describe the same observed 0/1 pattern, although their
# original feature IDs remain separate in the exported prevalence table.
distinct_patterns <- sum(!duplicated(as.data.frame(t(x))))
eligible_patterns <- sum(!duplicated(as.data.frame(t(x[, support >= 20,
                                                    drop = FALSE]))))
term_table <- data.frame(
  term = terms, name = unname(original_names[terms]), support = support, ad_support = ad_support,
  nonad_support = nonad_support,
  prevalence_all = support / nrow(x),
  prevalence_ad = ad_support / n_ad,
  prevalence_nonad = nonad_support / n_nonad,
  prevalence_difference = ad_support / n_ad - nonad_support / n_nonad,
  ad_rate_when_present = ifelse(support > 0, ad_support / pmax(support, 1), NA_real_),
  row.names = NULL)
write.csv(term_table, file.path(table_dir, "term_prevalence_all.csv"), row.names = FALSE)
write.csv(term_table[c("term", "name")],
          file.path(root, "data", "processed", "term_names.csv"), row.names = FALSE)

row_count <- rowSums(x)
row_table <- data.frame(row_id = data$row_id, IsAds = data$IsAds,
                        active_terms = row_count)
write.csv(row_table, file.path(table_dir, "term_count_per_record.csv"), row.names = FALSE)
overview <- data.frame(
  records = nrow(x), term_columns = ncol(x), active_cells = sum(x),
  density = mean(x), terms_never_present = sum(support == 0),
  terms_present_at_least_20 = sum(support >= 20),
  terms_present_under_20 = sum(support < 20),
  distinct_term_patterns = distinct_patterns,
  distinct_eligible_patterns = eligible_patterns,
  ad_mean_active_terms = mean(row_count[y]),
  nonad_mean_active_terms = mean(row_count[!y]),
  ad_median_active_terms = median(row_count[y]),
  nonad_median_active_terms = median(row_count[!y]))
write.csv(overview, file.path(table_dir, "term_overview.csv"), row.names = FALSE)

# Minimum support avoids ranking terms that appear in only a few records.
eligible <- term_table[term_table$support >= 20, ]
top <- head(eligible[order(-abs(eligible$prevalence_difference),
                           -eligible$support, eligible$term), ], 10)
write.csv(top, file.path(table_dir, "term_top_class_contrasts.csv"), row.names = FALSE)
top_plot <- head(top, 6)

png(file.path(figure_dir, "term_count_by_class.png"),
    width = 1200, height = 750, res = 150)
par(mar = c(5, 5, 4, 2))
boxplot(row_count[y], row_count[!y], names = c("Ad", "Non-Ad"),
        col = c("#D55E00", "#0072B2"), outline = FALSE,
        ylab = "Active terms per record",
        main = "Number of active term indicators by class")
stripchart(list(row_count[y], row_count[!y]), method = "jitter",
           vertical = TRUE, add = TRUE, pch = 16, cex = .28,
           col = adjustcolor("#333333", alpha.f = .18))
dev.off()

png(file.path(figure_dir, "term_class_prevalence.png"),
    width = 1600, height = 1050, res = 160)
par(mar = c(5, 13, 3, 2))
values <- rbind(Ad = 100 * top_plot$prevalence_ad,
                Nonad = 100 * top_plot$prevalence_nonad)
labels <- sprintf("%s (%s)", top_plot$term, top_plot$name)
barplot(values[, nrow(top_plot):1, drop = FALSE], beside = TRUE, horiz = TRUE,
        names.arg = rev(labels), las = 1, cex.names = .85,
        col = c("#D55E00", "#0072B2"), border = NA,
        xlab = "Within-class prevalence (%)",
        main = "Largest term prevalence differences")
legend("bottomright", c("Ad", "Non-Ad"),
       fill = c("#D55E00", "#0072B2"), bty = "n")
dev.off()

files <- c("term_count_by_class.png", "term_class_prevalence.png")
if (!all(file.copy(file.path(figure_dir, files), report_dir, overwrite = TRUE)))
  stop("Could not publish term figures to the report.")
index_path <- file.path(table_dir, "figure_index.csv")
index <- if (file.exists(index_path)) read.csv(index_path, stringsAsFactors = FALSE) else
  data.frame(variable = character(), file = character())
index <- index[!index$file %in% files, c("variable", "file")]
index <- rbind(index, data.frame(variable = c("active_term_count", "term_class_prevalence"),
                                 file = files))
write.csv(index, index_path, row.names = FALSE)
message("Term EDA complete: ", ncol(x), " indicators across ", nrow(x),
        " processed records; 2 report figures published.")
