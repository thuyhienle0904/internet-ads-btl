# Owner: Tường
# Input:  data/raw/
# Output: data/processed/ and any validation tables in output/tables/
# Run from the repository root. EDA reads the same output schema as the Python workflow.
local({
  raw <- read.csv("data/raw/add.csv", header = TRUE, check.names = FALSE,
                  colClasses = "character", na.strings = NULL)
  expected <- c("", as.character(0:1558))
  if (!identical(names(raw), expected) || nrow(raw) != 3279L ||
      !identical(trimws(raw[[1]]), as.character(0:3278))) {
    stop("Expected the full Kaggle add.csv with its original header and index.")
  }
  data <- raw[-1L]
  names(data) <- c("height", "width", "aspect_ratio", "local",
                   paste0("term_", 4:1557), "label")
  for (i in seq_len(1558L)) {
    x <- trimws(data[[i]])
    x[x %in% c("?", "", "NA")] <- NA_character_
    numeric_x <- suppressWarnings(as.numeric(x))
    if (any(!is.na(x) & !is.finite(numeric_x))) stop("Invalid value in ", names(data)[i])
    if (i >= 4L && any(!is.na(numeric_x) & !(numeric_x %in% c(0, 1)))) {
      stop("Invalid binary value in ", names(data)[i])
    }
    if (i >= 5L && anyNA(numeric_x)) stop("Missing value in ", names(data)[i])
    data[[i]] <- numeric_x
  }
  labels <- trimws(data$label)
  if (anyNA(labels) || !setequal(unique(labels), c("ad.", "nonad."))) {
    stop("Expected labels ad. and nonad.")
  }
  data$label <- ifelse(labels == "ad.", "ad", "nonad")
  dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
  write.csv(data, "data/processed/internet_ads_processed.csv", row.names = FALSE)
  dictionary <- data.frame(
    variable = names(data), source_header = 0:1558,
    type = c(rep("numeric", 3), rep("binary", 1555), "label"),
    unit = c("px", "px", rep("", 1557)),
    missing_count = colSums(is.na(data)),
    description = c("Image height", "Image width", "Width divided by height",
                    "Original binary local indicator", rep("Original binary term indicator", 1554),
                    "Advertisement class (ad or nonad)")
  )
  write.csv(dictionary, "data/processed/data_dictionary.csv", row.names = FALSE)
  message(nrow(data), " observations, ", ncol(data), " columns; ",
          sum(duplicated(data)), " repeated feature/label rows retained.")
})
