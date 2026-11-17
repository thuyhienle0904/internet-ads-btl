# Owner: Bach. Run from the repository root with Rscript.
# Input: v2 full-feature processed CSV; no raw-data cleaning here.
source("scripts/eda_helpers.R")

eda_config <- list(
  input_file = "data/processed/internet_ads_processed.csv",
  label_col = "IsAds",
  numeric_cols = c("Height", "Width", "Aspect_Ratio"),
  binary_cols = c("Local", "missing_size"),
  plot_numeric_cols = c("Height", "Width", "Aspect_Ratio"),
  plot_binary_cols = c("Local", "missing_size"),
  scope = "V2 full-record deduplicated dataset; missing values retained",
  output_dir = "output/eda-r",
  expected_labels = c("ad.", "nonad.")
)

processed <- read.csv(eda_config$input_file, check.names = FALSE, na.strings = c("", "NA"))
stopifnot("missing_size" %in% names(processed))
run_eda(eda_config, processed)
write_geometry_relationships(processed, eda_config)

write_eda_png(file.path(eda_config$output_dir, "figures", "geometry_qq.png"), function() {
  par(mfrow = c(1, 2))
  for (variable in c("Height", "Width")) {
    observed <- na.omit(processed[[variable]])
    qqnorm(observed, main = paste(variable, "(n =", length(observed), ")"),
           pch = 16, cex = .4)
    qqline(observed, col = "#a76423")
  }
})

# Publish only the complete set of figures from this successful R run.
figure_files <- c("class_distribution.png", sprintf("numeric_%03d.png", 1:3),
                  sprintf("binary_%03d.png", seq_along(eda_config$plot_binary_cols)),
                  "geometry_correlations.png",
                  "geometry_scatterplots.png", "geometry_qq.png")
figure_sources <- file.path(eda_config$output_dir, "figures", figure_files)
if (!all(file.exists(figure_sources))) stop("Incomplete R figure set.")
report_figures <- "report/figures/eda"
dir.create(report_figures, recursive = TRUE, showWarnings = FALSE)
if (!all(file.copy(figure_sources, report_figures, overwrite = TRUE))) {
  stop("Could not publish all R figures to the report.")
}
figure_index <- data.frame(
  variable = c("IsAds", eda_config$numeric_cols, eda_config$plot_binary_cols,
               "geometry_correlation", "geometry_pairs", "geometry_qq"),
  file = figure_files
)
write.csv(figure_index,
          file.path(eda_config$output_dir, "tables", "figure_index.csv"),
          row.names = FALSE)
message("Published ", length(figure_files), " R figures to ", report_figures)
source("scripts/eda_terms.R")
