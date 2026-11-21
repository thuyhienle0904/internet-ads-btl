# scripts/01_data_setup.R | Thieu Tuong - 2550364 | MT2013, HK261
# V2: deduplicate original features + label BEFORE missing-value processing.
# Keep ALL features, observed values, original ratios, and missing values.
# Base R only: Rscript scripts/01_data_setup.R

find_project_root <- function() {
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(arg)) {
    return(dirname(dirname(normalizePath(sub("^--file=", "", arg[1]),
                                        mustWork = TRUE))))
  }
  for (p in c(getwd(), dirname(getwd()))) {
    if (file.exists(file.path(p, "data/raw/add.csv"))) return(p)
  }
  stop("Open project root, then source('scripts/01_data_setup.R').")
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
  save_csv <- function(x, filename) {
    write.csv(x, file.path("data/processed", filename), row.names = FALSE,
              na = "NA", fileEncoding = "UTF-8")
  }
  save_duplicate_group_figure <- function(group_size_summary, label_summary) {
    figure_dir <- "output/preprocessing/figures"
    dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
    figure_file <- file.path(figure_dir, "duplicate_group_audit.png")
    png(figure_file, width = 1800, height = 900, res = 180)
    on.exit(dev.off(), add = TRUE)
    old_par <- par(no.readonly = TRUE)
    on.exit(par(old_par), add = TRUE)
    par(mfrow = c(1, 2), mar = c(5, 5, 4.5, 1))

    group_labels <- as.character(group_size_summary$Group_Size)
    barplot(group_size_summary$Group_Count, names.arg = group_labels,
      col = "#4C78A8", border = NA, las = 2,
      xlab = "Records in an exact duplicate group",
      ylab = "Number of duplicate groups",
      main = "A. Size of duplicate groups")
    mtext(sprintf("%d groups; %d raw records involved",
                  sum(group_size_summary$Group_Count),
                  sum(group_size_summary$Records_In_Groups)),
          side = 3, line = 0.4, cex = 0.8)

    barplot(label_summary$Rows_Removed, names.arg = label_summary$Label,
      col = c("#E45756", "#54A24B"), border = NA,
      ylab = "Redundant rows removed",
      main = "B. Removed rows by class")
    text(seq_along(label_summary$Rows_Removed), label_summary$Rows_Removed,
         labels = label_summary$Rows_Removed, pos = 3, cex = 0.9)
    mtext(sprintf("%d redundant rows removed", sum(label_summary$Rows_Removed)),
          side = 3, line = 0.4, cex = 0.8)
  }
  cat("INTERNET ADVERTISEMENTS - V2: KEEP FEATURES AND MISSINGNESS\n")
  cat("Runtime:", R.version.string, "\n\n")

  # 1. Read original CSV, including header and export index; never rewrite raw.
  raw_path <- "data/raw/add.csv"
  raw_md5 <- unname(tools::md5sum(raw_path))
  raw <- read.csv(raw_path, header = TRUE, check.names = FALSE,
    colClasses = "character", stringsAsFactors = FALSE,
    na.strings = NULL, strip.white = FALSE)
  stopifnot(identical(names(raw), c("", as.character(0:1558))),
    identical(dim(raw), c(3279L, 1560L)),
    identical(raw[[1]], as.character(seq_len(nrow(raw)) - 1L)))
  raw_index <- as.integer(raw[[1]])
  # This is only whitespace normalization, not filling or reducing features.
  original <- as.data.frame(lapply(raw[-1], trimws), stringsAsFactors = FALSE)
  names(original) <- as.character(0:1558)
  stopifnot(all(original[["1558"]] %in% c("ad.", "nonad.")))
  raw_missing <- as.matrix(original[seq_len(1558)]) == "?"

  # 2. Deduplicate ALL 1558 ORIGINAL FEATURES + LABEL, before NA handling.
  # The unique export index is not an image feature and must not be in the key.
  duplicate <- duplicated(original)
  keep <- !duplicate
  retained <- original[keep, , drop = FALSE]
  # Row audit records source indices and decisions, without changing values.
  row_audit <- data.frame(Raw_Index = raw_index,
    Label = original[["1558"]],
    Missing_Any_Original_Feature = as.integer(rowSums(raw_missing) > 0),
    Missing_Three_Size_Features = as.integer(rowSums(raw_missing[, 1:3]) > 0),
    Status = ifelse(duplicate, "removed_duplicate_full_record", "kept"))
  save_csv(row_audit, "row_audit.csv")

  # Audit the exact duplicate groups themselves. The separator cannot occur in
  # this numeric/binary source data, so each key represents all features + label.
  stopifnot(!any(grepl("\r", unlist(original, use.names = FALSE), fixed = TRUE)))
  full_record_key <- do.call(paste, c(original, sep = "\r"))
  key_counts <- table(full_record_key)
  duplicate_keys <- names(key_counts)[key_counts > 1L]
  first_positions <- match(duplicate_keys, full_record_key)
  group_sizes <- as.integer(key_counts[duplicate_keys])
  duplicate_groups <- data.frame(
    Group_ID = sprintf("DG%03d", seq_along(duplicate_keys)),
    Label = original[["1558"]][first_positions],
    Group_Size = group_sizes,
    Rows_Removed = group_sizes - 1L,
    Retained_Raw_Index = raw_index[first_positions],
    Member_Raw_Indices = vapply(duplicate_keys, function(key) {
      paste(raw_index[full_record_key == key], collapse = ";")
    }, character(1)),
    stringsAsFactors = FALSE)
  duplicate_groups <- duplicate_groups[order(-duplicate_groups$Group_Size,
                                               duplicate_groups$Label,
                                               duplicate_groups$Retained_Raw_Index), ]
  rownames(duplicate_groups) <- NULL
  duplicate_groups$Group_ID <- sprintf("DG%03d", seq_len(nrow(duplicate_groups)))
  save_csv(duplicate_groups, "duplicate_group_audit.csv")
  group_size_summary <- as.data.frame(table(Group_Size = duplicate_groups$Group_Size),
                                      stringsAsFactors = FALSE)
  group_size_summary$Group_Size <- as.integer(as.character(group_size_summary$Group_Size))
  group_size_summary <- group_size_summary[order(group_size_summary$Group_Size), ]
  names(group_size_summary)[2] <- "Group_Count"
  group_size_summary$Records_In_Groups <- with(group_size_summary,
    Group_Size * Group_Count)
  group_size_summary$Rows_Removed <- with(group_size_summary,
    (Group_Size - 1L) * Group_Count)
  save_csv(group_size_summary, "duplicate_group_size_summary.csv")
  label_summary <- data.frame(Label = c("ad.", "nonad."),
    Duplicate_Groups = vapply(c("ad.", "nonad."), function(label) {
      sum(duplicate_groups$Label == label)
    }, integer(1)),
    Records_In_Groups = vapply(c("ad.", "nonad."), function(label) {
      sum(duplicate_groups$Group_Size[duplicate_groups$Label == label])
    }, integer(1)),
    Rows_Removed = vapply(c("ad.", "nonad."), function(label) {
      sum(duplicate_groups$Rows_Removed[duplicate_groups$Label == label])
    }, integer(1)))
  save_csv(label_summary, "duplicate_group_label_summary.csv")
  stopifnot(nrow(duplicate_groups) == 277L, sum(duplicate_groups$Rows_Removed) == 856L,
            sum(duplicate_groups$Group_Size) == 1133L,
            identical(sum(duplicate_groups$Rows_Removed), sum(duplicate)))
  save_duplicate_group_figure(group_size_summary, label_summary)
  report_figure_dir <- "report/figures/preprocessing"
  dir.create(report_figure_dir, recursive = TRUE, showWarnings = FALSE)
  if (!file.copy("output/preprocessing/figures/duplicate_group_audit.png",
                 report_figure_dir, overwrite = TRUE)) {
    stop("Could not publish duplicate-group figure to the report.")
  }

  # 3. Convert '?' to R NA, and parse numbers WITHOUT imputing any value.
  parse_number <- function(text) {
    text[text %in% c("?", "")] <- NA_character_
    number <- suppressWarnings(as.numeric(text))
    if (any(!is.na(text) & is.na(number))) stop("Non-numeric feature value.")
    if (any(!is.finite(number[!is.na(number)]))) stop("Non-finite feature.")
    number
  }
  parsed <- as.data.frame(lapply(retained[seq_len(1558)], parse_number),
                          stringsAsFactors = FALSE)
  feature_names <- c("Height", "Width", "Aspect_Ratio", "Local",
                     sprintf("term_%04d", 4:1557))
  names(parsed) <- feature_names
  stopifnot(all(vapply(parsed[4:1558], function(v) {
    all(is.na(v) | v %in% c(0, 1))
  }, logical(1))))
  stopifnot(all(vapply(parsed[1:3], function(v) {
    all(is.na(v) | v > 0)
  }, logical(1))))
  # Keep original observed Aspect_Ratio; DO NOT recalculate Width/Height.
  processed <- data.frame(row_id = raw_index[keep], parsed,
    IsAds = factor(retained[["1558"]], levels = c("ad.", "nonad.")),
    check.names = FALSE)
  # User requested a flag for ANY missing original feature (including Local).
  # This differs from a flag restricted to the first three size features.
  processed$missing_size <- as.integer(rowSums(is.na(parsed)) > 0)
  rownames(processed) <- NULL
  stopifnot(nrow(processed) == 2423L, ncol(processed) == 1561L,
    sum(duplicate) == 856L, sum(processed$IsAds == "ad.") == 386L,
    sum(processed$IsAds == "nonad.") == 2037L,
    !anyDuplicated(processed[c(feature_names, "IsAds")]),
    sum(is.na(processed)) == 1473L, sum(processed$missing_size) == 499L,
    identical(processed$missing_size, as.integer(rowSums(is.na(parsed)) > 0)))
  save_csv(processed, "internet_ads_processed.csv")

  # 4. Export metadata for EVERY output column, not just size features.
  before <- c(0L, as.integer(colSums(raw_missing)), 0L, 0L)
  after <- as.integer(colSums(is.na(processed)))
  roles <- c("identifier", rep("feature", 1558), "target", "derived_flag")
  descriptions <- c("Chỉ mục dòng gốc; giữ để truy vết, không dùng làm biến dự báo",
    "Chiều cao ảnh", "Chiều rộng ảnh", "Tỷ lệ Width/Height gốc, giữ nguyên",
    "Chỉ báo nhị phân Local; giữ giá trị và NA gốc",
    paste0("Đặc trưng nhị phân gốc cột ", 4:1557,
           "; CSV không kèm tên/ngữ nghĩa từ khóa chi tiết"),
    "Nhãn: ad. là quảng cáo; nonad. là không quảng cáo",
    "1 nếu bất kỳ đặc trưng gốc nào thiếu, kể cả Local; 0 nếu đủ toàn bộ")
  types <- c("integer", rep("numeric", 1558), "factor", "integer_binary")
  dictionary <- data.frame(Variable_Name = names(processed),
    Raw_Column_Name = c("(blank)", as.character(0:1558), "(derived)"),
    CSV_Column_Position = c(seq_len(1560), NA_integer_), Role = roles,
    Data_Type = types, Unit = c("none", "pixel", "pixel", "dimensionless",
                              rep("none", 1557)),
    Missing_Before = before, Missing_After = after,
    Description = descriptions,
    Processing = c("Giữ chỉ mục; loại khỏi khóa xét trùng",
      rep("Giữ giá trị quan sát; chuyển ? thành NA; không điền khuyết", 1558),
      "Giữ ad./nonad.; quy ước số nếu cần: ad.=1, nonad.=0",
      "Tạo sau loại trùng từ is.na() của toàn bộ 1558 đặc trưng"))
  save_csv(dictionary, "data_dictionary.csv")
  missing_summary <- data.frame(Variable = names(processed),
    Missing_Before = before, Rate_Before = 100 * before / nrow(raw),
    Missing_After = after, Rate_After = 100 * after / nrow(processed))
  save_csv(missing_summary, "missing_summary.csv")
  class_rows <- function(labels, stage) {
    counts <- table(factor(labels, levels = c("ad.", "nonad.")))
    data.frame(Stage = stage, Label = names(counts), Count = as.integer(counts),
               Percent = 100 * as.numeric(counts) / length(labels))
  }
  classes <- rbind(class_rows(original[["1558"]], "raw"),
                    class_rows(processed$IsAds, "processed"))
  save_csv(classes, "class_distribution.csv")
  flag_rows <- function(labels, flag, stage) {
    tab <- as.data.frame(table(missing_size = factor(as.integer(flag), levels = c(0,1)),
                              Label = factor(labels, levels = c("ad.","nonad."))))
    names(tab)[3] <- "Count"
    tab$Stage <- stage
    totals <- ave(tab$Count, tab$missing_size, FUN = sum)
    tab$Percent_Within_Flag <- 100 * tab$Count / totals
    tab[c("Stage", "missing_size", "Label", "Count", "Percent_Within_Flag")]
  }
  flag_table <- rbind(flag_rows(original[["1558"]], rowSums(raw_missing)>0, "raw"),
    flag_rows(processed$IsAds, processed$missing_size, "processed"))
  save_csv(flag_table, "missing_size_distribution.csv")
  describe <- function(v) c(Observed = sum(!is.na(v)), Missing = sum(is.na(v)),
    Mean_Observed = mean(v, na.rm=TRUE), SD_Observed = sd(v, na.rm=TRUE),
    Min = min(v, na.rm=TRUE), Q1 = unname(quantile(v,.25,na.rm=TRUE)),
    Median = median(v,na.rm=TRUE), Q3 = unname(quantile(v,.75,na.rm=TRUE)),
    Max = max(v,na.rm=TRUE))
  stats <- sapply(processed[c("Height","Width","Aspect_Ratio")], describe)
  save_csv(data.frame(Statistic=rownames(stats),stats,row.names=NULL),
           "descriptive_statistics.csv")
  audit <- data.frame(Step = c("raw_csv", "deduplicate_full_record",
    "parse_NA_keep_all_features", "add_missing_size"),
    Rows = c(3279L, nrow(retained), nrow(parsed), nrow(processed)),
    Columns = c(1560L,1560L,1560L,ncol(processed)),
    Rows_Removed = c(0L,sum(duplicate),0L,0L),
    Missing_Cells = c(sum(raw_missing),sum(raw_missing[keep,]),
                       sum(is.na(parsed)),sum(is.na(processed))))
  save_csv(audit, "audit_log.csv")
  conflict_groups <- nrow(unique(original)) - nrow(unique(original[1:1558]))
  size_only_missing <- sum(rowSums(is.na(parsed[1:3])) > 0)
  summary <- data.frame(Metric=c("raw_rows","raw_csv_columns","original_features",
    "duplicate_rows_removed","processed_rows","output_columns","processed_ad",
    "processed_nonad","missing_cells_after","missing_size_rows",
    "missing_three_size_features","conflicting_label_groups"),
    Actual=c(nrow(raw),ncol(raw),1558,sum(duplicate),nrow(processed),ncol(processed),
      sum(processed$IsAds=="ad."),sum(processed$IsAds=="nonad."),
      sum(is.na(processed)),sum(processed$missing_size),size_only_missing,conflict_groups))
  save_csv(summary, "preprocessing_summary.csv")
  metadata <- data.frame(Key=c("version","dataset","source_url","raw_filename",
    "download_date_declared","date_note","run_timestamp","observation_unit",
    "raw_md5","raw_bytes","deduplication_scope","missing_size_definition",
    "missing_policy","label_mapping","R_version"),
    Value=c("v2 - preserve features and missingness","Internet Advertisements",
      "https://www.kaggle.com/datasets/uciml/internet-advertisements-data-set/data",
      "add.csv","2026-11-08","Ngày tải theo hồ sơ sinh viên; chưa xác minh độc lập",
      format(Sys.time(),tz="Asia/Bangkok",format="%Y-%m-%d %H:%M:%S %Z"),
      "Một bản ghi mô tả ảnh trên trang web",raw_md5,as.character(file.info(raw_path)$size),
      "Toàn bộ 1558 đặc trưng + nhãn gốc; không gồm chỉ mục xuất CSV; trước xử lý NA",
      "1 nếu bất kỳ đặc trưng gốc nào thiếu (bao gồm Local); 0 nếu đủ toàn bộ",
      "Giữ NA; không mean/median; không tính lại ratio; không loại thiếu Local",
      "ad.=1; nonad.=0 nếu cần biến số; file giữ nhãn chữ",R.version.string))
  save_csv(metadata,"source_metadata.csv")

  # 5. Report macros, raw integrity, and exported-file checks.
  macros <- c(NRaw=nrow(raw),NFileColumns=ncol(raw),NDuplicatesRemoved=sum(duplicate),
    NDuplicateGroups=nrow(duplicate_groups),
    NRecordsInDuplicateGroups=sum(duplicate_groups$Group_Size),
    NProcessed=nrow(processed),NOutputColumns=ncol(processed),
    NAdsRaw=sum(original[["1558"]]=="ad."),
    NNonadsRaw=sum(original[["1558"]]=="nonad."),
    NAdsProcessed=sum(processed$IsAds=="ad."),
    NNonadsProcessed=sum(processed$IsAds=="nonad."),NMissingFlag=sum(processed$missing_size),
    NSizeMissing=size_only_missing)
  writeLines(c("% Generated from R results; do not edit numeric values.",
    paste0("\\newcommand{\\",names(macros),"}{",sprintf("%.0f",macros),"}")),
    "output/preprocessing/results_generated.tex")
  stopifnot(identical(raw_md5,unname(tools::md5sum(raw_path))))
  exported <- read.csv("data/processed/internet_ads_processed.csv",check.names=FALSE,
                       na.strings="NA",stringsAsFactors=FALSE)
  stopifnot(identical(dim(exported),dim(processed)),
    identical(names(exported),names(processed)),sum(is.na(exported))==1473L,
    identical(exported$row_id,processed$row_id),
    all(vapply(feature_names,function(v) isTRUE(all.equal(exported[[v]],processed[[v]],
      check.attributes=FALSE,tolerance=0.000000000001)),logical(1))))
  cat("Processing stages:\n"); print(audit,row.names=FALSE)
  cat("\nClass distribution:\n"); print(classes,row.names=FALSE)
  cat("\nMissing flag distribution:\n"); print(flag_table,row.names=FALSE)
  cat("\nMissing features:\n"); print(missing_summary[missing_summary$Missing_Before>0,],row.names=FALSE)
  cat("\nSummary:\n"); print(summary,row.names=FALSE)
  cat("\nRaw MD5 unchanged:",raw_md5,"\n")
  cat("SUCCESS: retained all features, NA, original ratios; no imputation.\n\n")
  print(sessionInfo())
  invisible(processed)
}

main()
