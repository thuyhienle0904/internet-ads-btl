# Chapter 5 and 6 changes (branch `tan/ch5-ch6-evaluation`)

Base commit: `ccbb06f` (main, 21/11/2026). Owner of this change: Tân.

This branch changes the inference code, its figures, Chapter 5 and Chapter 6.
It does not change Chapters 1–4, 7, 8, the cover, or the bibliography. Items that
other owners must do are listed at the end.

## Why

A review of the 22/11 PDF found four problems in Chapter 5:

1. **Two different baselines.** Comparison A (geometry shape) used
   `Ad ~ log2_Height + log2_Width + Local + missing_size`. Comparison B (terms)
   used the same formula plus `Aspect_Ratio`. The report showed two different
   "geometry-only" test results (AP 0.594 and 0.612) without explanation, and
   §5.3 said Aspect Ratio is left out while §5.5.2 put it in.
2. **No uncertainty on test results.** The test set has 77 ads. Precision and
   recall had no intervals, so a gain of 3 ads and a gain of 20 ads were reported
   with the same confidence.
3. **"Anonymous" terms.** The report said the term meaning "cannot be inferred".
   The UCI distribution of the dataset includes `ad.names`, which names every
   column in order. The six selected terms are `ancurl*com`, `url*ads`,
   `ancurl*click`, `alt*click`, `alt*here` and `alt*click+here`.
4. **No basic two-sample test** from the course syllabus.

`report/sections/06_discussion.tex` was empty on main. The Chapter 6 in the PDF
came from a version that was not pushed. This branch writes Chapter 6 in full.

## Code changes

| File | Change |
|---|---|
| `data/reference/ad.names` | **New.** Original column-name file from the UCI download (`internet+advertisements.zip`). Not raw data, so it is committed. |
| `scripts/term_names.R` | **New.** `load_term_names(root)` maps `term_0004`…`term_1557` to their original names and stops if the file does not give exactly 1,554 names. |
| `scripts/03_inference_model.R` | One shared `base_formula` for both comparisons (the term models reuse it, so the two baselines cannot drift apart again). New Welch t-test of training width, ad vs non-ad (`width_welch_test.csv`). Term output tables get a `name` column. |
| `scripts/inference_metrics.R` | New helpers: `wilson_interval()`, `exact_mcnemar()`, `paired_ap_difference()` (stratified paired bootstrap, 2,000 resamples). |
| `scripts/04_evaluation.R` | Adds 95% Wilson intervals for precision and recall to both evaluation CSVs. Stops if the term pipeline's baseline differs from the main-effects model. Writes `model_comparison_tests.csv` (exact McNemar for ads caught and non-ads flagged, bootstrap interval for the AP gain; seed 2026). |
| `scripts/05_inference_visuals.R` | One comparison of three models (main effects, format + interaction, main effects + six terms) instead of two pairs. One PR figure (training OOF and test panels) and one confusion-matrix figure with three panels and Wilson intervals. |
| `report/figures/inference/term_test_confusion_matrices.png` | **Removed.** Its content is now a panel of `test_confusion_matrices.png`. |
| `tests/test_inference_metrics.R`, `tests/test_term_inference.R` | Tests for the new helpers (hand-checked values), the term names and the shared baseline. |

## Report changes

- **Chapter 5** (`report/sections/05_inference.tex`), rewritten:
  - 5.2 (new): Welch two-sample t-test for width.
  - 5.5: term names, an explanation of the prefixes, and why the three `alt`
    terms have very wide intervals (of the 117 training records with any of
    them, 98 contain all three).
  - 5.6: one table for all three models with 95% Wilson intervals, one paired
    comparison table (exact McNemar and bootstrap AP interval), and three
    corrected conclusions:
    - the curved size effect ranks better (AP +0.090, CI [0.039, 0.145]) but its
      decisions at the threshold are not distinguishable (3 extra ads, p = 0.25);
    - the terms catch 23 more of 77 test ads (p < 0.001) at the cost of 20 more
      false alarms;
    - test precision is consistent with the 0.70 target for the two geometry
      models, but just below it for the term model ([0.51, 0.69]).
  - Repeated "does not establish causality" caveats are reduced to one place.
- **Chapter 6** (`report/sections/06_discussion.tex`), new: main findings, strengths
  of the methods, limitations and extensions, following the rubric.

### Numbers that changed

Only the term model changed, because its baseline lost `Aspect_Ratio`. All
geometry results, the missingness test and Table 5.2 are unchanged.

| Quantity | Before (PDF 22/11) | After |
|---|---|---|
| Term model, test AP | 0.804 | 0.795 (gain over main effects 0.201) |
| Term model, test precision / FP | 0.613 / 41 | 0.607 / 42 |
| Term model, test recall | 0.844 | 0.844 (unchanged) |
| Term model, train OOF AP | 0.847 | 0.843 |
| Likelihood-ratio test, deviance reduction (6 df) | 515.95 | 523.83 |
| `ancurl*com` / `url*ads` / `ancurl*click` OR | 56.1 / 120.9 / 39.5 | 50.6 / 116.9 / 39.1 |
| "No terms" baseline row | separate model (AP 0.612) | removed: identical to "Main effects" (AP 0.594) |

## Review round 1 (independent reviewer: Gemini 4 Neon)

The reviewer checked every number against the output CSVs. Accepted and fixed:

- AP gain of the term model is 0.2005, so it is reported as **0.201** (was 0.200).
- "Width is right-skewed" was wrong for ads (mean 325.6 < median 455); now
  stated per class.
- The `missing_size` odds ratio depends on the filled-in median width
  (113.5 px); the text no longer reads it as a property of missingness.
- The extra 20 false alarms of the term model come from its lower threshold
  (0.14 vs 0.40), not from the terms: at the same recall the term model has
  higher precision for every recall from 0.08 to 0.96 on test.
- Precision–recall figure: step curves that match the AP computation, no
  artificial (0, 1) start point, one legend below the panels.
- Every method now has explicit Objective / Method / Result / Comment /
  Conclusion parts (rubric), α = 0.05 is stated, the logistic equation and
  Wald hypotheses are shown, every table and figure is referenced, and
  precision, recall, AP, ROC-AUC, OOF prediction, BH, deviance and the Wilson
  interval are defined where first used.
- Thresholds (0.40 / 0.29 / 0.14) and the refit on all training records are
  stated; training-row intervals are marked descriptive.
- Chapter 6: elastic net instead of lasso; "no test data in fitting or
  tuning" with the EDA caveat; Local added to the findings.

Chapter 5 is now 10 pages and Chapter 6 is 4 pages. The whole report must stay
within the 30-page body limit; check this when all chapters are merged.

## Verification

- The unchanged main code, run on our `add.csv`, reproduces all eight rows of the
  old Tables 5.3 and 5.6 exactly. The comparison above is therefore like for like.
- The full pipeline (`Rscript scripts/run_all.R`) and all four test files pass on
  R 4.4.2 (Docker image `r-base:4.4.2`).
- `report/thesis.tex` compiles with PDFLaTeX. Chapters 5 and 6 have no overfull lines.

## How to run

```sh
Rscript --encoding=UTF-8 scripts/run_all.R
Rscript --encoding=UTF-8 tests/test_inference_metrics.R
Rscript --encoding=UTF-8 tests/test_term_inference.R
```

`data/reference/ad.names` must exist (it is committed). `data/raw/add.csv` is
still required and is not committed.

## For the integrator and other owners

| Owner | Item |
|---|---|
| Phúc (Ch. 2) | Add short background for the new methods: Welch two-sample t-test, Wilson interval for a proportion, exact McNemar test, paired bootstrap interval. F2 is no longer reported in Chapter 5; remove it from Ch. 2 or keep it only if another chapter uses it. |
| Phúc (references) | `report/refs/references.bib` is empty on main. Chapter 5 §5.5 names the dataset by DOI inline (10.24432/C5V011). Replace this with `\cite{<dataset key>}` when the bibliography is restored. |
| Bách (Ch. 4) | Table 4.5, Figure 4.11 and §4.9 still say the terms are unnamed. Use `scripts/term_names.R` to label them. Two overfull lines remain in `04_descriptive.tex` (lines 121–124 and 286–296). |
| Tường (Ch. 1) | §1.2–1.3 call the indicators anonymous; the names come from `ad.names` in the UCI distribution. |
| Ch. 7 | The GitHub repository is **private**, so the code link will not open for the lecturer. Make it public or provide another link. |
| Cover | Title, names, student IDs, class, lecturer and date are still empty. |
