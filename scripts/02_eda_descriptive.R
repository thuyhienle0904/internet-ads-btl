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

# Publish only the complete set of figures from this successful R run.
figure_files <- c("class_distribution.png", sprintf("numeric_%03d.png", 1:3),
                  "binary_001.png", "geometry_correlations.png",
                  "geometry_scatterplots.png", "geometry_qq.png")
figure_sources <- file.path(eda_config$output_dir, "figures", figure_files)
if (!all(file.exists(figure_sources))) stop("Incomplete R figure set.")
report_figures <- "report/figures/eda"
dir.create(report_figures, recursive = TRUE, showWarnings = FALSE)
if (!all(file.copy(figure_sources, report_figures, overwrite = TRUE))) {
  stop("Could not publish all R figures to the report.")
}
figure_index <- data.frame(
  variable = c("IsAds", eda_config$numeric_cols, "Local",
               "geometry_correlation", "geometry_pairs", "geometry_qq"),
  file = figure_files
)
write.csv(figure_index,
          file.path(eda_config$output_dir, "tables", "figure_index.csv"),
          row.names = FALSE)
message("Published eight R figures to ", report_figures)
