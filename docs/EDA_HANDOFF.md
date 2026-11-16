# Reference-aligned preprocessing and descriptive analysis

## Current input and scope

The active EDA input is Tuong's revised five-variable preprocessing output, reproduced from the full Kaggle `add.csv`. The raw file has 3,279 observations and 1,560 columns including an exported index. The processed schema is `Height`, `Width`, `Aspect_Ratio`, `Local`, `IsAds`, with labels `ad.` and `nonad.`.

The pipeline selects five source columns, calculates Height/Width means from all observed raw values, imputes missing dimensions, recomputes every Width/Height ratio, removes 15 rows missing Local, and removes 2,214 repeats on all five selected columns. The final sample has 1,050 rows, 93 advertisements, 957 non-advertisements and no missing cells.

This supersedes the earlier 3,279-row EDA and its lowercase field names. The current figures and Chapter 4 describe the reduced sample. Full-record repeats (856) and five-column repeats after imputation (2,214) are different quantities. Removing repeats on five variables can merge distinct images; the class share changes from 14.00% to 8.86%.

## Reproduction

Place the original Kaggle `add.csv` in `data/raw/`. From the repository root, the Python route is

```bash
python3 scripts/eda_kaggle_snapshot.py
```

When `data/raw/add.csv` is absent, the script downloads the latest `add.csv` from Kaggle automatically. Use `--download` to refresh it. The script also accepts the original Kaggle ZIP. It validates the schema, writes the full processed CSV and dictionary under `data/processed/`, then reads that CSV to generate EDA. The source SHA-256 and audit counts are recorded in `output/eda/tables/preprocessing_audit.csv`. Rerunning replaces these generated outputs.
```sh
python3 -m venv .venv
.venv/bin/python -m pip install matplotlib
.venv/bin/python scripts/eda_kaggle_snapshot.py data/raw/add.csv
```

The script validates the full raw schema and index, exports the reference-aligned processed CSV, dictionary and row audit, then reads the CSV for EDA. The audit records source SHA-256 and processing counts. Running it replaces the generated CSV and Python comparison figures in `output/eda/` with the 1,050-row version. It does not publish report figures. It also accepts the original Kaggle ZIP.

The R route is

```sh
Rscript scripts/01_data_setup.R
Rscript scripts/02_eda_descriptive.R
```

The preprocessing script preserves the revised Tuong handoff algorithm. Its generated execution log and LaTeX macros are directed to `output/preprocessing/` for integration into this repository. The EDA entry point uses the exact delivered schema and labels. R output is written to `output/eda-r/`; after all eight R figures are generated successfully, the R entry point copies them into `report/figures/eda/` for the report. These files have the same bytes as that R run. The full figure index lists all eight outputs.

The supplied handoff records R 4.5.0 execution. On 14 November 2026 the integrated scripts were executed with the official R 4.6.2 macOS ARM64 runtime extracted into a temporary directory. An isolated project copy preserved the working input and report figures. Synthetic checks passed; preprocessing and EDA generated all eight PNGs. All 1,050 processed rows and 3,279 row decisions matched the Python workflow. Numerical summaries, binary proportions, class counts, correlations and outlier audits matched at relative/absolute tolerance 1e-12. Graphics used Quartz because the temporary Cairo runtime lacked X11 dependencies. Logs and comparison results are under `output/validation-r/`; R outputs are under `output/eda-r/`. The temporary runtime is not a system R installation. Numerical descriptive calculations use sample SD (n-1) and type 7 quartiles.

## Report and figures

Chapters 1, 3, 4 and 7 share the same scope. Chapter 4 includes overall and grouped statistics, class frequencies, histograms/boxplots, Pearson correlations, class-colored scatterplots, normal Q-Q plots, IQR flags, and Local prevalence. Code excerpts and interpretation are in English.

Eight R-generated PNG figures in `report/figures/eda/` are tracked for shared LaTeX compilation. Raw/processed CSVs, generated tables, logs and local environments are excluded from Git. Hypothesis tests and modeling are coordinated in the inference section. The reference's later median-imputed modeling branch is separate from this mean-imputed descriptive branch. Any predictive evaluation requires a separate train/test and training-only imputation design.
