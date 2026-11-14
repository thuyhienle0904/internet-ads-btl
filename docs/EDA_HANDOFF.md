# Descriptive EDA Handoff

## Input audit

Tuong's handoff contains 100 rows and 10 fields in both the original and processed data. The processed header is `v1` through `v10`; the labels remain `ad.` (16) and `nonad.` (84). The dictionary does not identify the geometric variables. The 100-row input has no header, whereas the full Kaggle file does. Using the handoff script's `header = FALSE` on the full file would incorrectly import its header as an observation. Trimming whitespace alone does not remove the periods from the labels.

The handoff report lists 3,280 observations and describes the ratio as height/width. The verified Kaggle CSV has 3,279 data rows plus a header. Its ratio agrees with width/height within 0.001 on all 2,369 rows with all three geometric values and positive dimensions. The handoff files were left unchanged.

## Scope and schema

The report now uses the full [Kaggle dataset](https://www.kaggle.com/datasets/uciml/internet-advertisements-data-set/data) supplied by the user. The raw CSV has 1,560 columns: an index, 1,558 features, and a label. Preprocessing and EDA use the same 3,279 observations. The prior 100-row handoff was retained as a separate reference.

| Original header | EDA field | Handling |
|---|---|---|
| Empty | Excluded | Row index, 0 through 3278 |
| 0, 1, 2 | height, width, aspect_ratio | Pixels, pixels, width/height |
| 3 | local | Retain 0/1 and preserve missingness |
| 4 through 1557 | term_4 through term_1557 | Preserve all 1,554 binary indicators |
| 1558 | label | Map ad. to ad and nonad. to nonad |

No imputation or row removal was performed. There are 856 exact repeated rows beyond first occurrences after removing the index; they are counted, not removed. The full processed CSV has 1,559 columns and 2,729 missing cells. Class proportions use the total row count. Feature summaries use observed values separately for each feature and group. Sample SD uses n-1 and quartiles use linear interpolation equivalent to R type 7.

## Reproduction

From the repository root, use Python with Matplotlib to generate the tables and figures:

```bash
python3 scripts/eda_kaggle_snapshot.py
```

When `data/raw/add.csv` is absent, the script downloads the latest `add.csv` from Kaggle automatically. Use `--download` to refresh it. The script also accepts the original Kaggle ZIP. It validates the schema, writes the full processed CSV and dictionary under `data/processed/`, then reads that CSV to generate EDA. The source SHA-256 and audit counts are recorded in `output/eda/tables/preprocessing_audit.csv`. Rerunning replaces these generated outputs.

```bash
Rscript tests/test_eda.R
Rscript scripts/01_data_setup.R
Rscript scripts/02_eda_descriptive.R
```

The R workflow writes the same processed schema and generates descriptive output in `output/eda-r/`. The report uses the verified Python output in `output/eda/`; the R run has not been verified because Rscript is unavailable on this machine.

## Deliverables

- `report/sections/04_descriptive.tex`: English report text, tables, and figure captions. Upload the PNGs and adjust the figure paths when integrating into Prism.
- `output/eda/tables/`: class counts, missingness, numeric summaries, binary proportions, column inventory, and figure index.
- `output/eda/figures/`: class distribution, three geometric-feature panels, and Local prevalence.
- `METHODS_LOG.md`: analysis methods and calculation conventions.

Data and generated outputs are ignored by Git. Review the full processed file and mapping with Tuong before merging. If preprocessing changes, regenerate the outputs and revise the report together. Agree on the split with Tan before using EDA for feature selection, review exact repeats for possible cross-split leakage, and fit imputation rules on training data only.
