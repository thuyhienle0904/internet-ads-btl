# V2 preprocessing and descriptive analysis

The current workflow uses the 3,279-row Kaggle export in `data/raw/add.csv`.
Tường's R script retains all 1,558 original features and removes 856 exact
duplicates across those features and the label. It keeps `row_id` for
traceability and adds `missing_size` for any missing original feature.
The resulting 2,423 rows contain 386 advertisements and 2,037 non-advertisements.
The 1,554 term columns use `term_####`, with the suffix taken from the
original Kaggle column header.

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

## Finding for the discussion

Among the 1,554 binary indicators, `term_1243` had the largest absolute
difference in observed rates between classes. It occurred in 167 of 386 ads
(43.26%) and 12 of 2,037 nonads (0.59%). This makes it a candidate for further
evaluation, although it was absent in 219 of 386 ads. The full screening table
is written to `output/eda-r/tables/term_comparison.csv`. For model feature
selection, repeat the screening within training data and evaluate on held-out
data.
