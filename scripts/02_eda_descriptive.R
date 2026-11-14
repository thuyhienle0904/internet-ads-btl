# Owner: Bach. Run from the repository root with Rscript.
# Input: full processed CSV; no raw-data cleaning here.
source("scripts/eda_helpers.R")

eda_config <- list(
  input_file = "data/processed/internet_ads_processed.csv",
  label_col = "label",
  numeric_cols = c("height", "width", "aspect_ratio"),
  binary_cols = "local",
  plot_numeric_cols = c("height", "width", "aspect_ratio"),
  plot_binary_cols = "local",
  scope = "Full processed Kaggle dataset; descriptive only",
  output_dir = "output/eda-r",
  expected_labels = c("ad", "nonad")
)

run_eda(eda_config)

processed <- read.csv(eda_config$input_file, check.names = FALSE, na.strings = c("", "NA"))
write_geometry_relationships(processed, eda_config)
