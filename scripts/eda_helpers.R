# Base-R EDA functions. Source this file without running a data pipeline.
validate_eda <- function(data, config) {
  required <- c("label_col", "numeric_cols", "binary_cols", "plot_numeric_cols",
                "plot_binary_cols", "expected_labels", "scope", "output_dir")
  if (!all(required %in% names(config))) stop("Incomplete EDA configuration.")
  if (!is.data.frame(data) || nrow(data) == 0L) stop("Expected a non-empty data frame.")
  if (anyDuplicated(names(data))) stop("Duplicate column names.")
  if (length(config$label_col) != 1L || !nzchar(config$label_col)) stop("Set label_col.")
  if (length(config$scope) != 1L || !nzchar(config$scope)) stop("Set the agreed data scope.")
  features <- c(config$numeric_cols, config$binary_cols)
  if (anyDuplicated(features) || config$label_col %in% features) {
    stop("Feature lists must be disjoint and must not contain the label.")
  }
  columns <- c(config$label_col, features)
  if (!all(columns %in% names(data))) {
    stop("Missing columns: ", paste(setdiff(columns, names(data)), collapse = ", "))
  }
  labels <- as.character(data[[config$label_col]])
  if (anyNA(labels) || any(!labels %in% config$expected_labels)) {
    stop("Missing/unexpected labels. Agree label encoding with Tuong; do not silently recode.")
  }
  if (length(config$expected_labels) != 2L || anyNA(config$expected_labels) ||
      anyDuplicated(config$expected_labels)) stop("Expected two distinct labels.")
  for (name in features) {
    x <- data[[name]]
    if (!(is.numeric(x) || is.logical(x))) stop("Non-numeric feature: ", name)
    if (any(!is.finite(x[!is.na(x)]))) stop("Infinite values in: ", name)
  }
  for (name in config$binary_cols) {
    x <- data[[name]]
    if (any(!is.na(x) & !(x %in% c(0, 1)))) stop("Not binary 0/1/NA: ", name)
  }
  if (!all(config$plot_numeric_cols %in% config$numeric_cols) ||
      !all(config$plot_binary_cols %in% config$binary_cols)) {
    stop("Plot columns must belong to the corresponding feature lists.")
  }
  invisible(TRUE)
}

summarize_labels <- function(data, label_col, labels = c("ad", "nonad")) {
  counts <- as.integer(table(factor(data[[label_col]], levels = labels)))
  data.frame(class = labels, n = counts, proportion = counts / nrow(data))
}

numeric_summary_one <- function(x, variable, group) {
  valid <- x[!is.na(x)]
  n <- length(valid)
  quartiles <- if (n) as.numeric(quantile(valid, c(.25, .5, .75), type = 7)) else rep(NA_real_, 3)
  data.frame(variable = variable, group = group, n_total = length(x), n_valid = n,
             n_missing = sum(is.na(x)), mean = if (n) mean(valid) else NA_real_,
             sd = if (n > 1L) sd(valid) else NA_real_,
             min = if (n) min(valid) else NA_real_, q1 = quartiles[1],
             median = quartiles[2], q3 = quartiles[3],
             max = if (n) max(valid) else NA_real_, iqr = quartiles[3] - quartiles[1])
}

summarize_numeric <- function(data, columns, label_col = NULL, labels = c("ad", "nonad")) {
  rows <- list()
  for (name in columns) {
    rows[[length(rows) + 1L]] <- numeric_summary_one(data[[name]], name, "all")
    if (!is.null(label_col)) for (label in labels) {
      rows[[length(rows) + 1L]] <- numeric_summary_one(
        data[[name]][as.character(data[[label_col]]) == label], name, label)
    }
  }
  if (!length(rows)) return(numeric_summary_one(numeric(), "", "")[FALSE, ])
  do.call(rbind, rows)
}

summarize_binary <- function(data, columns, label_col, labels = c("ad", "nonad")) {
  rows <- list()
  for (name in columns) for (group in c("all", labels)) {
    x <- if (group == "all") data[[name]] else data[[name]][as.character(data[[label_col]]) == group]
    n_valid <- sum(!is.na(x))
    rows[[length(rows) + 1L]] <- data.frame(
      variable = name, group = group, n_total = length(x), n_valid = n_valid,
      n_missing = sum(is.na(x)), n_one = sum(x == 1, na.rm = TRUE),
      proportion_one = if (n_valid) sum(x == 1, na.rm = TRUE) / n_valid else NA_real_)
  }
  if (!length(rows)) return(data.frame(variable = character(), group = character(),
    n_total = integer(), n_valid = integer(), n_missing = integer(), n_one = integer(),
    proportion_one = numeric()))
  do.call(rbind, rows)
}

write_eda_png <- function(path, draw) {
  png(path, width = 1400, height = 900, res = 150)
  on.exit(dev.off(), add = TRUE)
  par(mar = c(6, 5, 4, 2))
  draw()
}

plot_eda_numeric <- function(data, variable, label_col, labels, path) {
  write_eda_png(path, function() {
    par(mfrow = c(1, 2))
    x <- as.numeric(data[[variable]])
    valid <- x[!is.na(x)]
    if (!length(valid)) {
      plot.new(); text(.5, .5, "No observed values")
      plot.new(); text(.5, .5, "No observed values")
    } else {
      hist(valid, main = "Observed distribution", xlab = variable,
           col = "#b7dcd6", border = "white")
      boxplot(lapply(labels, function(label) x[as.character(data[[label_col]]) == label]),
              names = labels, main = "By class (missing omitted)", ylab = variable,
              col = c("#b7dcd6", "#efd4a7"))
    }
  })
}

run_eda <- function(config, data = NULL) {
  if (is.null(data)) {
    if (!file.exists(config$input_file)) stop("Processed input file not found: ", config$input_file)
    data <- read.csv(config$input_file, check.names = FALSE, stringsAsFactors = FALSE,
                     na.strings = c("", "NA"))
  }
  validate_eda(data, config)
  tables <- file.path(config$output_dir, "tables")
  figures <- file.path(config$output_dir, "figures")
  dir.create(tables, recursive = TRUE, showWarnings = FALSE)
  dir.create(figures, recursive = TRUE, showWarnings = FALSE)
  labels <- summarize_labels(data, config$label_col, config$expected_labels)
  numeric <- summarize_numeric(data, config$numeric_cols, config$label_col, config$expected_labels)
  binary <- summarize_binary(data, config$binary_cols, config$label_col, config$expected_labels)
  features <- c(config$numeric_cols, config$binary_cols)
  inventory <- data.frame(variable = names(data),
    role = ifelse(names(data) == config$label_col, "label",
      ifelse(names(data) %in% config$numeric_cols, "numeric",
        ifelse(names(data) %in% config$binary_cols, "binary", "not_selected"))),
    n_missing = vapply(data, function(x) sum(is.na(x)), integer(1)))
  outputs <- list(class_counts = labels, numeric_summary = numeric,
                  binary_summary = binary, column_inventory = inventory)
  for (name in names(outputs)) {
    write.csv(outputs[[name]], file.path(tables, paste0(name, ".csv")),
              row.names = FALSE, na = "NA", fileEncoding = "UTF-8")
  }
  write_eda_png(file.path(figures, "class_distribution.png"), function() {
    centers <- barplot(labels$n, names.arg = labels$class, col = c("#549e91", "#ce9650"),
      ylim = c(0, max(labels$n) * 1.2), ylab = "Number of observations", main = "Class distribution")
    text(centers, labels$n, labels = sprintf("%d (%.1f%%)", labels$n, 100 * labels$proportion), pos = 3)
  })
  # Numeric IDs avoid unsafe file names from URL-derived feature names.
  plot_index <- data.frame(variable = character(), file = character())
  for (i in seq_along(config$plot_numeric_cols)) {
    variable <- config$plot_numeric_cols[i]
    filename <- sprintf("numeric_%03d.png", i)
    plot_eda_numeric(data, variable, config$label_col, config$expected_labels, file.path(figures, filename))
    plot_index <- rbind(plot_index, data.frame(variable = variable, file = filename))
  }
  for (i in seq_along(config$plot_binary_cols)) {
    variable <- config$plot_binary_cols[i]
    filename <- sprintf("binary_%03d.png", i)
    rows <- binary[binary$variable == variable & binary$group != "all", ]
    write_eda_png(file.path(figures, filename), function() {
      rates <- rows$proportion_one
      # Missing rates receive a zero-height placeholder explicitly marked NA.
      heights <- ifelse(is.na(rates), 0, rates)
      centers <- barplot(heights, names.arg = rows$group, ylim = c(0, 1.15),
                        col = c("#549e91", "#ce9650"),
                        ylab = "Proportion of 1 among observed values", main = variable)
      text(centers, heights, labels = ifelse(is.na(rates), "NA (no observations)",
        sprintf("%.1f%%; n=%d", 100 * rates, rows$n_valid)), pos = 3)
    })
    plot_index <- rbind(plot_index, data.frame(variable = variable, file = filename))
  }
  write.csv(plot_index, file.path(tables, "figure_index.csv"), row.names = FALSE, fileEncoding = "UTF-8")
  metadata <- c(paste("Scope:", config$scope), paste("Input:", config$input_file),
    paste("Run time (UTC):", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    paste("Input MD5:", if (file.exists(config$input_file)) unname(tools::md5sum(config$input_file)) else "in-memory data"),
    paste("Rows:", nrow(data)), paste("Columns:", ncol(data)),
    paste("Selected features:", length(features)),
    "Missing values are excluded per variable; denominators are recorded.",
    "SD uses n-1; quartiles use R quantile type 7. No imputation or feature selection is performed.",
    "Figure names are mapped to variables in tables/figure_index.csv.", capture.output(sessionInfo()))
  writeLines(metadata, file.path(config$output_dir, "run_metadata.txt"), useBytes = TRUE)
  message("EDA outputs written to ", config$output_dir)
  invisible(outputs)
}

# Descriptive geometry relationships use one common complete-case sample.
write_geometry_relationships <- function(data, config) {
  variables <- config$numeric_cols
  tables <- file.path(config$output_dir, "tables")
  figures <- file.path(config$output_dir, "figures")
  complete <- data[complete.cases(data[, variables, drop = FALSE]), , drop = FALSE]
  correlation <- cor(complete[, variables, drop = FALSE])
  pairs <- which(upper.tri(correlation, diag = TRUE), arr.ind = TRUE)
  result <- data.frame(feature_x = variables[pairs[, 1]],
                       feature_y = variables[pairs[, 2]],
                       n_complete = nrow(complete), pearson_r = correlation[pairs])
  write.csv(result, file.path(tables, "geometry_correlations.csv"), row.names = FALSE)
  write_eda_png(file.path(figures, "geometry_correlations.png"), function() {
    par(mar = c(7, 7, 3, 2))
    image(seq_along(variables), seq_along(variables), correlation,
          zlim = c(-1, 1), col = hcl.colors(101, "Blue-Red 3"), axes = FALSE,
          xlab = "", ylab = "", main = paste("Pearson r; complete n =", nrow(complete)))
    axis(1, seq_along(variables), variables, las = 2)
    axis(2, seq_along(variables), variables, las = 2)
    for (i in seq_along(variables)) for (j in seq_along(variables)) {
      text(i, j, sprintf("%.3f", correlation[i, j]))
    }
  })
  write_eda_png(file.path(figures, "geometry_scatterplots.png"), function() {
    colors <- c("#28786d", "#a76423")
    pairs(complete[, variables, drop = FALSE], pch = 16, cex = .4,
          col = adjustcolor(colors[match(complete[[config$label_col]], config$expected_labels)], .35),
          main = paste("Geometry pairs; complete n =", nrow(complete)))
    par(xpd = NA)
    legend("topright", legend = config$expected_labels, col = colors, pch = 16, cex = .7)
  })
  audit <- do.call(rbind, lapply(c(config$expected_labels, "all"), function(group) {
    rows <- if (group == "all") data else data[data[[config$label_col]] == group, , drop = FALSE]
    do.call(rbind, lapply(variables, function(variable) {
      x <- rows[[variable]]
      x <- x[!is.na(x)]
      q <- quantile(x, c(.25, .75), type = 7, names = FALSE)
      lower <- q[1] - 1.5 * diff(q)
      upper <- q[2] + 1.5 * diff(q)
      count <- sum(x < lower | x > upper)
      data.frame(variable = variable, group = group, n_valid = length(x),
                 lower_fence = lower, upper_fence = upper,
                 n_flagged = count, proportion_flagged = count / length(x))
    }))
  }))
  write.csv(audit, file.path(tables, "outlier_audit.csv"), row.names = FALSE)
}
