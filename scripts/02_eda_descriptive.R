# Owner: Bach. Run from the repository root with Rscript.
# Input: reference-aligned five-variable processed CSV; no raw-data cleaning here.
source("scripts/eda_helpers.R")

eda_config <- list(
  input_file = "data/processed/internet_ads_processed.csv",
  label_col = "IsAds",
  numeric_cols = c("Height", "Width", "Aspect_Ratio"),
  binary_cols = "Local",
  plot_numeric_cols = c("Height", "Width", "Aspect_Ratio"),
  plot_binary_cols = "Local",
  scope = "Reference-aligned mean-imputed and deduplicated dataset; 1050 rows",
  output_dir = "output/eda-r",
  expected_labels = c("ad.", "nonad.")
)

run_eda(eda_config)

processed <- read.csv(eda_config$input_file, check.names = FALSE, na.strings = c("", "NA"))
write_geometry_relationships(processed, eda_config)

write_eda_png(file.path(eda_config$output_dir, "figures", "geometry_qq.png"), function() {
  par(mfrow = c(1, 2))
  for (variable in c("Height", "Width")) {
    qqnorm(processed[[variable]], main = variable, pch = 16, cex = .4)
    qqline(processed[[variable]], col = "#a76423")
  }
})
