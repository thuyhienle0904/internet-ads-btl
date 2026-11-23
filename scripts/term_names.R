# Original names of the 1,554 term indicators.
# The Kaggle CSV numbers these columns 4..1557; the UCI distribution lists
# their names, in the same column order, in data/reference/ad.names.
load_term_names <- function(root) {
  path <- file.path(root, "data", "reference", "ad.names")
  if (!file.exists(path)) stop("Missing ", path, "; copy ad.names from the UCI download.")
  lines <- readLines(path, encoding = "latin1", warn = FALSE)
  found <- sub(":.*$", "", grep("^[a-z]+\\*", lines, value = TRUE))
  if (length(found) != 1554L)
    stop("Expected 1,554 term names in ad.names, found ", length(found), ".")
  stats::setNames(found, sprintf("term_%04d", 4:1557))
}
