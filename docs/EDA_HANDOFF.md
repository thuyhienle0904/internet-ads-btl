# V2 preprocessing and descriptive analysis

The current workflow uses the 3,279-row Kaggle export in `data/raw/add.csv`.
Tường's R script retains all 1,558 original features and removes 856 exact
duplicates across those features and the label. It keeps `row_id` for
traceability and adds `missing_size` for any missing original feature.
The resulting 2,423 rows contain 386 advertisements and 2,037 non-advertisements.

From the repository root:

```sh
Rscript scripts/01_data_setup.R
Rscript tests/test_eda.R
Rscript scripts/02_eda_descriptive.R
```

Preprocessing writes the CSV and audit tables to `data/processed/` and its log
to `output/preprocessing/`. EDA writes tables and figures to `output/eda-r/`
and copies the nine report figures to `report/figures/eda/`. Univariate
summaries use observed values per feature. Pearson correlations and
geometry scatterplots use 1,931 complete geometry records.

`scripts/eda_kaggle_snapshot.py` reproduces the historical 1,050-row workflow.
Its default outputs are isolated under `output/eda-legacy/`. Use the R
workflow above to regenerate the v2 report.
