# scripts/01_data_setup.R | Thieu Tuong - 2550364 | MT2013, HK261
# Reproduce Section 3 (printed pp. 11-18) of the previous group's report.
# Base R only. Run: Rscript scripts/01_data_setup.R
# Deduplication uses FIVE selected columns, not all original features.
# See docs/EDA_HANDOFF.md for the scope and limitations.

find_project_root <- function() {
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(arg)) {
    script <- normalizePath(sub("^--file=", "", arg[1]), mustWork = TRUE)
    return(dirname(dirname(script)))
  }
  for (p in c(getwd(), dirname(getwd()))) {
    if (file.exists(file.path(p, "data/raw/add.csv"))) return(p)
  }
  stop("Open the project root, then source('scripts/01_data_setup.R').")
}

main <- function() {
  project_root <- find_project_root()
  old_wd <- getwd()
  old_options <- options(digits = 12, scipen = 999)
  on.exit({setwd(old_wd); options(old_options)}, add = TRUE)
  setwd(project_root)
  for (p in c("data/processed", "output/preprocessing")) {
    dir.create(p, recursive = TRUE, showWarnings = FALSE)
  }
  sink("output/preprocessing/execution_log.txt", split = TRUE)
  on.exit(sink(), add = TRUE)
  cat("INTERNET ADVERTISEMENTS - REFERENCE PREPROCESSING\n")
  cat("R runtime:", R.version.string, "\n\n")
  save_csv <- function(x, name) {
    write.csv(x, file.path("data/processed", name), row.names = FALSE,
              na = "", fileEncoding = "UTF-8")
  }

  # 1. Read full add.csv with HEADER; preserve its original bytes.
  raw_path <- "data/raw/add.csv"
  if (!file.exists(raw_path)) stop("Missing data/raw/add.csv")
  raw_md5 <- unname(tools::md5sum(raw_path))
  raw <- read.csv(raw_path, header = TRUE, check.names = FALSE,
    colClasses = "character", stringsAsFactors = FALSE,
    na.strings = NULL, strip.white = FALSE)
  if (!identical(names(raw), c("", as.character(0:1558)))) {
    stop("Expected blank index header, then column names 0..1558.")
  }
  if (nrow(raw) != 3279L || ncol(raw) != 1560L) {
    stop("Expected FULL add.csv: 3279 observations, 1560 CSV columns.")
  }
  stopifnot(identical(raw[[1]], as.character(seq_len(nrow(raw)) - 1L)))
  full <- as.data.frame(lapply(raw[-1], trimws), stringsAsFactors = FALSE)
  names(full) <- as.character(0:1558)
  if (!all(full[["1558"]] %in% c("ad.", "nonad."))) {
    stop("Target must contain ad. and nonad. only.")
  }
  binary_ok <- vapply(full[as.character(3:1557)], function(v) {
    all(v %in% c("0", "1", "?"))
  }, logical(1))
  stopifnot(all(binary_ok))
  stopifnot(!any(vapply(full[as.character(4:1557)], function(v) {
    any(v == "?")
  }, logical(1))))
  full_dup <- sum(duplicated(full))
  features <- full[seq_len(1558)]
  # Binary labels: this difference counts feature vectors with both labels.
  conflict_groups <- nrow(unique(full)) - nrow(unique(features))

  # 2. Select exactly the five columns used by the reference.
  selected <- full[c("0", "1", "2", "3", "1558")]
  names(selected) <- c("Height", "Width", "Aspect_Ratio", "Local", "IsAds")
  for (v in names(selected)[1:4]) {
    text <- selected[[v]]
    text[text %in% c("?", "")] <- NA_character_
    number <- suppressWarnings(as.numeric(text))
    if (any(!is.na(text) & is.na(number))) {
      stop(paste("Unexpected non-numeric value in", v))
    }
    stopifnot(all(is.finite(number[!is.na(number)])))
    selected[[v]] <- number
  }
  selected$IsAds <- factor(selected$IsAds, levels = c("ad.", "nonad."))
  stopifnot(all(na.omit(selected$Height) > 0),
            all(na.omit(selected$Width) > 0),
            all(na.omit(selected$Local) %in% c(0, 1)))
  missing_before <- colSums(is.na(selected))
  stopifnot(identical(as.integer(missing_before), c(903L,901L,910L,15L,0L)))
  cat("Raw:", nrow(raw), "rows;", ncol(raw), "CSV columns\n")
  cat("1558 features + target + export index\n")
  cat("Full-record duplicate excess (index excluded):", full_dup, "\n")
  cat("Conflicting-label feature groups:", conflict_groups, "\n\n")

  # 3. Means from ALL observed raw values BEFORE any row removal.
  mean_height <- mean(selected$Height, na.rm = TRUE)
  mean_width <- mean(selected$Width, na.rm = TRUE)
  data_mean <- selected
  data_mean$Height[is.na(data_mean$Height)] <- mean_height
  data_mean$Width[is.na(data_mean$Width)] <- mean_width
  # Recompute ALL ratios, even those originally observed.
  data_mean$Aspect_Ratio <- data_mean$Width / data_mean$Height

  # 4. Drop missing Local, then deduplicate EXACTLY five selected columns.
  row_audit <- data.frame(
    Raw_Index = as.integer(raw[[1]]),
    Height_Imputed = is.na(selected$Height),
    Width_Imputed = is.na(selected$Width),
    Local_Missing = is.na(selected$Local),
    Status = ifelse(is.na(selected$Local), "removed_missing_local", "kept"))
  keep_local <- !is.na(data_mean$Local)
  after_local <- data_mean[keep_local, , drop = FALSE]
  dup_five <- duplicated(after_local)
  row_audit$Status[which(keep_local)[dup_five]] <- "removed_duplicate_five_columns"
  processed <- after_local[!dup_five, , drop = FALSE]
  rownames(processed) <- NULL
  # Validate computed results; never replace data with expected numbers.
  stopifnot(nrow(after_local) == 3264L, sum(dup_five) == 2214L,
    nrow(processed) == 1050L, ncol(processed) == 5L,
    !anyNA(processed), !anyDuplicated(processed),
    sum(processed$IsAds == "ad.") == 93L,
    sum(processed$IsAds == "nonad.") == 957L,
    all(is.finite(processed$Aspect_Ratio)),
    isTRUE(all.equal(processed$Aspect_Ratio, processed$Width / processed$Height)))
  save_csv(processed, "internet_ads_processed.csv")
  save_csv(row_audit, "row_audit.csv")

  # 5. Export actual audit tables and a five-variable data dictionary.
  missing_summary <- data.frame(Variable = names(selected),
    Missing_Before = as.integer(missing_before),
    Missing_Rate_Before = as.numeric(100 * missing_before / nrow(selected)),
    Missing_After = as.integer(colSums(is.na(processed))))
  save_csv(missing_summary, "missing_summary.csv")
  imputation <- data.frame(Variable = c("Height", "Width"),
    Mean = c(mean_height, mean_width),
    Median = c(median(selected$Height, na.rm = TRUE),
               median(selected$Width, na.rm = TRUE)),
    Method_Used = "mean", Imputed_Count = as.integer(missing_before[1:2]))
  save_csv(imputation, "imputation_values.csv")
  class_rows <- function(df, stage) {
    counts <- table(factor(df$IsAds, levels = c("ad.", "nonad.")))
    data.frame(Stage = stage, Label = names(counts), Count = as.integer(counts),
      Percent = 100 * as.numeric(counts) / nrow(df))
  }
  classes <- rbind(class_rows(selected, "raw"),
    class_rows(after_local, "after_local_filter"), class_rows(processed, "processed"))
  save_csv(classes, "class_distribution.csv")
  describe <- function(v) c(Mean = mean(v), SD = sd(v), Min = min(v),
    Q1 = unname(quantile(v, 0.25)), Median = median(v),
    Q3 = unname(quantile(v, 0.75)), Max = max(v))
  stats <- sapply(processed[c("Height", "Width", "Aspect_Ratio")], describe)
  save_csv(data.frame(Statistic = rownames(stats), stats, row.names = NULL),
    "descriptive_statistics.csv")
  audit <- data.frame(
    Step = c("raw_csv", "select_five", "impute_and_recompute_ratio",
      "drop_missing_local", "deduplicate_five"),
    Rows = c(nrow(raw), nrow(selected), nrow(data_mean), nrow(after_local), nrow(processed)),
    Columns = c(ncol(raw), ncol(selected), ncol(data_mean), ncol(after_local), ncol(processed)),
    Rows_Removed = c(0L, 0L, 0L, sum(!keep_local), sum(dup_five)),
    Missing_Cells = c(sum(missing_before), sum(missing_before),
      sum(is.na(data_mean)), sum(is.na(after_local)), sum(is.na(processed))))
  save_csv(audit, "audit_log.csv")
  dictionary <- data.frame(
    Variable_Name = names(processed), Raw_Column_Name = c("0", "1", "2", "3", "1558"),
    CSV_Column_Position = c(2L, 3L, 4L, 5L, 1560L),
    Data_Type = c("numeric", "numeric", "numeric", "numeric_binary", "factor"),
    Unit = c("pixel", "pixel", "dimensionless", "none", "none"),
    Description = c("Chiều cao ảnh", "Chiều rộng ảnh",
      "Tỷ lệ chiều rộng/chiều cao: Width/Height",
      "Chỉ báo nhị phân Local, giữ theo báo cáo mẫu",
      "Nhãn ảnh: ad. là quảng cáo; nonad. là không quảng cáo"),
    Valid_Values = c("> 0", "> 0", "> 0", "0; 1", "ad.; nonad."),
    Missing_Before = as.integer(missing_before), Missing_After = 0L,
    Processing = c("Điền trung bình quan sát trước khi lọc dòng",
      "Điền trung bình quan sát trước khi lọc dòng",
      "Tính lại toàn bộ bằng Width/Height sau khi điền khuyết",
      "Loại dòng có Local thiếu", "Giữ nhãn chữ ad./nonad."),
    Numeric_Mapping = c("", "", "", "", "ad. = 1; nonad. = 0 (quy ước bàn giao)"))
  save_csv(dictionary, "data_dictionary.csv")
  summary <- data.frame(
    Metric = c("raw_rows", "csv_columns", "features", "selected_columns",
      "full_duplicate_excess", "conflicting_label_groups", "height_missing",
      "width_missing", "ratio_missing", "local_missing", "height_mean", "width_mean",
      "rows_after_local", "five_column_duplicates_removed", "processed_rows",
      "processed_ad", "processed_nonad", "missing_after"),
    Actual = c(nrow(raw), ncol(raw), 1558, ncol(selected), full_dup, conflict_groups,
      missing_before[1:4], mean_height, mean_width, nrow(after_local), sum(dup_five),
      nrow(processed), sum(processed$IsAds == "ad."), sum(processed$IsAds == "nonad."),
      sum(is.na(processed))),
    Reference = c(3279,1560,1558,5,NA,NA,903,901,910,15,
      64.02188552188552,155.3448275862069,3264,2214,1050,93,957,0))
  summary$Matches_Reference <- ifelse(is.na(summary$Reference), NA,
    abs(summary$Actual - summary$Reference) < 0.00000001)
  stopifnot(all(summary$Matches_Reference, na.rm = TRUE))
  save_csv(summary, "preprocessing_summary.csv")
  metadata <- data.frame(
    Key = c("dataset", "source_url", "raw_filename", "download_date_declared",
      "date_note", "run_timestamp", "observation_unit", "reference_scope", "raw_md5", "raw_bytes",
      "label_mapping", "deduplication_scope", "R_version"),
    Value = c("Internet Advertisements Data Set",
      "https://www.kaggle.com/datasets/uciml/internet-advertisements-data-set/data",
      "add.csv", "2026-11-08",
      "Ngày tải do tài liệu gốc của sinh viên ghi; không suy ra từ file ZIP",
      format(Sys.time(), tz = "Asia/Bangkok", format = "%Y-%m-%d %H:%M:%S %Z"),
      "Một bản ghi mô tả hình ảnh trên trang web",
      "Báo cáo khóa trước: phần 3, trang in 11-18; không gồm phần 5 dùng median",
      raw_md5, as.character(file.info(raw_path)$size), "ad. = 1; nonad. = 0",
      "Height, Width, Aspect_Ratio, Local, IsAds sau điền khuyết và lọc Local",
      R.version.string))
  save_csv(metadata, "source_metadata.csv")

  # 6. Generate report macros directly from computed results.
  macros <- c(NRaw = nrow(raw), NFileColumns = ncol(raw), NAfterLocal = nrow(after_local),
    NDuplicatesRemoved = sum(dup_five), NProcessed = nrow(processed),
    NAdsRaw = sum(selected$IsAds == "ad."), NNonadsRaw = sum(selected$IsAds == "nonad."),
    NAdsProcessed = sum(processed$IsAds == "ad."),
    NNonadsProcessed = sum(processed$IsAds == "nonad."),
    MeanHeight = mean_height, MeanWidth = mean_width)
  values <- vapply(seq_along(macros), function(i) {
    if (names(macros)[i] %in% c("MeanHeight", "MeanWidth")) {
      sprintf("%.8f", macros[i])
    } else sprintf("%.0f", macros[i])
  }, character(1))
  tex <- paste0("\\newcommand{\\", names(macros), "}{", values, "}")
  writeLines(c("% Generated by scripts/01_data_setup.R; do not edit numbers.", tex),
    "output/preprocessing/results_generated.tex", useBytes = TRUE)
  stopifnot(identical(raw_md5, unname(tools::md5sum(raw_path))))
  exported <- read.csv("data/processed/internet_ads_processed.csv", stringsAsFactors = FALSE)
  stopifnot(identical(dim(exported), c(1050L, 5L)), !anyNA(exported),
    identical(names(exported), names(processed)),
    isTRUE(all.equal(exported$Aspect_Ratio, exported$Width / exported$Height,
      tolerance = 0.000000000001)))
  cat("Missing values:\n"); print(missing_summary, row.names = FALSE)
  cat("\nImputation values:\n"); print(imputation, row.names = FALSE)
  cat("\nProcessing stages:\n"); print(audit, row.names = FALSE)
  cat("\nClass distribution:\n"); print(classes, row.names = FALSE)
  cat("\nReference checks:\n"); print(summary, row.names = FALSE)
  cat("\nFinal structure:\n"); str(processed)
  cat("\nRaw MD5 unchanged:", raw_md5, "\n")
  cat("\nSUCCESS: 1050 rows, 5 columns; 93 ad., 957 nonad.; no missing values.\n")
  cat("This reproduces preprocessing, not model performance.\n\n")
  print(sessionInfo())
  invisible(processed)
}

main()
