# Methods Log

Record each method, formula, test, metric, or preprocessing rule added to the analysis code. Notify Phuc so the background section and references stay consistent.

| Method | Contributor | Script | Purpose | Definition or procedure | Reference | Integrated into background? |
|---|---|---|---|---|---|---|
| Class counts and proportions | Bách | scripts/eda_helpers.R | Describe class balance | Count observations by label and divide by the total row count; reject missing labels | R help: table | Pending |
| Mean, sample SD, median, quartiles, and IQR | Bách | scripts/eda_helpers.R | Summarize numeric features overall and by class | Exclude missing values per feature; report observed and missing counts; use n-1 for SD and type 7 quartiles | R help: mean, sd, quantile | Pending |
| Binary feature prevalence | Bách | scripts/eda_helpers.R | Compare classes descriptively | Divide the count of ones by the number of observed values; missing is not zero | R help: sum, is.na | Pending |
| Histograms and boxplots by class | Bách | scripts/eda_helpers.R | Explore distributions and outliers | Specify plotted features explicitly; retain outliers and make no inference from the plots alone | R help: hist, boxplot | Pending |
| Full Kaggle preprocessing and missingness audit | Tường / Bách | scripts/01_data_setup.R; scripts/eda_kaggle_snapshot.py | Provide a common input for preprocessing and EDA | Validate the header, index, and labels; drop only the index; retain all 3,279 observations and 1,558 features; audit missingness and repeated rows; generate EDA from the processed CSV | Kaggle add.csv; docs/EDA_HANDOFF.md | Pending |

| Pearson correlations and geometry scatterplots | Bách | scripts/eda_kaggle_snapshot.py; scripts/eda_helpers.R | Describe linear relationships and class overlap | Use the common 2,369 complete geometry rows; report n; preserve original scales and observations | R help: cor, pairs | Pending |
| Tukey 1.5-IQR flags | Bách | scripts/eda_kaggle_snapshot.py; scripts/eda_helpers.R | Describe extreme observations without deletion | Type 7 Q1/Q3; flag strictly outside Q1-1.5 IQR and Q3+1.5 IQR, pooled and by class; flagging does not imply error | R help: quantile, boxplot.stats (hinges can differ) | Pending |
