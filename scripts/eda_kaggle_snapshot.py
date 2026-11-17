"""Validate the Kaggle CSV, export reference-aligned processed data, and reproduce EDA."""
import argparse
import csv
import hashlib
import io
import math
import statistics as stats
import zipfile
from collections import Counter
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

DATASET_HANDLE = "uciml/internet-advertisements-data-set"
DATASET_FILE_PATH = "add.csv"
FIELDS = ("Height", "Width", "Aspect_Ratio", "Local", "IsAds")
LABELS = ("ad.", "nonad.")
COLORS = ("#28786d", "#a76423")
NAMES = ("Height (px)", "Width (px)", "Aspect ratio (width / height)")


def download_kaggle_source(destination):
    """Download the latest Kaggle CSV and cache it locally for reproducible EDA."""
    try:
        import kagglehub
        from kagglehub import KaggleDatasetAdapter
    except ImportError as error:
        raise RuntimeError(
            "Install dependencies first: python -m pip install -r requirements.txt"
        ) from error

    print(f"Downloading {DATASET_HANDLE}/{DATASET_FILE_PATH} from Kaggle...")
    df = kagglehub.dataset_load(
        KaggleDatasetAdapter.PANDAS,
        DATASET_HANDLE,
        DATASET_FILE_PATH,
        pandas_kwargs={"dtype": str, "keep_default_na": False},
    )
    if df.shape[1] != 1560:
        raise ValueError("Kaggle returned an unexpected number of columns.")

    # KaggleHub/Pandas names the blank index header 'Unnamed: 0'. Restore the
    # original Kaggle header expected by the validation step below.
    df.columns = [""] + [str(i) for i in range(1559)]
    destination.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(destination, index=False)
    return destination


def load_processed_rows(source):
    content = source.read_bytes()
    if source.suffix.lower() == ".zip":
        with zipfile.ZipFile(io.BytesIO(content)) as archive:
            content = archive.read("add.csv")
    reader = csv.reader(io.StringIO(content.decode("utf-8-sig"), newline=""))
    expected = [""] + [str(i) for i in range(1559)]
    if next(reader, None) != expected:
        raise ValueError("Expected full Kaggle add.csv with its original header.")
    data = []
    for index, row in enumerate(reader):
        if len(row) != len(expected) or row[0].strip() != str(index):
            raise ValueError(f"Unexpected width or index at observation {index + 1}.")
        values = [None if x.strip() in ("?", "", "NA") else float(x)
                  for x in row[1:5]]
        if any(x is not None and not math.isfinite(x) for x in values):
            raise ValueError(f"Nonfinite feature at observation {index + 1}.")
        if any(v is not None and v <= 0 for v in values[:2]):
            raise ValueError(f"Nonpositive geometry at observation {index + 1}.")
        if values[3] not in (None, 0, 1):
            raise ValueError(f"Invalid Local value at observation {index + 1}.")
        label = {"ad.": "ad.", "nonad.": "nonad."}.get(row[-1].strip())
        if label is None:
            raise ValueError(f"Unknown label at observation {index + 1}.")
        terms = [v.strip() for v in row[5:-1]]
        if any(v not in ("0", "1") for v in terms):
            raise ValueError(f"Invalid binary term at observation {index + 1}.")
        data.append((*values, *terms, label))
    if len(data) != 3279 or any(not any(r[-1] == k for r in data) for k in LABELS):
        raise ValueError("Expected all 3,279 observations and both classes.")
    return data, hashlib.sha256(content).hexdigest()


def write_csv(path, header, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(header)
        writer.writerows(["NA" if v is None else v for v in row] for row in rows)


def observed(rows, column):
    return [r[column] for r in rows if r[column] is not None]


def export_processed(source, processed, audit_dir):
    rows, sha = load_processed_rows(source)
    raw_duplicates = len(rows) - len(set(rows))
    means = [stats.mean(observed(rows, i)) for i in range(2)]
    selected = []
    seen = set()
    audit = []
    for index, row in enumerate(rows):
        height = row[0] if row[0] is not None else means[0]
        width = row[1] if row[1] is not None else means[1]
        record = (height, width, width / height, row[3], row[-1])
        if row[3] is None:
            status = "removed_missing_local"
        elif record in seen:
            status = "removed_duplicate_five_columns"
        else:
            status = "kept"
            seen.add(record)
            selected.append(record)
        audit.append((index, row[0] is None, row[1] is None, row[3] is None, status))
    if len(selected) != 1050 or Counter(r[-1] for r in selected) != Counter({"ad.": 93, "nonad.": 957}):
        raise ValueError("Reference preprocessing counts do not match the validated dataset.")
    write_csv(processed, FIELDS, selected)
    write_csv(processed.with_name("row_audit.csv"),
              ("Raw_Index", "Height_Imputed", "Width_Imputed", "Local_Missing", "Status"), audit)
    write_csv(processed.with_name("data_dictionary.csv"),
              ("Variable_Name", "Raw_Column_Name", "Data_Type", "Unit", "Missing_Before", "Missing_After", "Processing"),
              [(name, source_header, kind, unit, sum(r[i] is None for r in rows) if i < 4 else 0, 0, treatment)
               for i, (name, source_header, kind, unit, treatment) in enumerate(zip(
                   FIELDS, ("0", "1", "2", "3", "1558"),
                   ("numeric", "numeric", "numeric", "binary", "label"),
                   ("pixel", "pixel", "dimensionless", "none", "none"),
                   ("Mean imputation", "Mean imputation", "Recomputed Width/Height",
                    "Missing rows excluded", "Retain ad./nonad.")))])
    write_csv(audit_dir / "preprocessing_audit.csv", ("metric", "value"),
              [("source_sha256", sha), ("raw_observations", len(rows)),
               ("raw_columns_including_index", 1560), ("processed_observations", len(selected)),
               ("processed_columns", 5), ("missing_cells_before", sum(v is None for r in rows for v in r)),
               ("missing_cells_after", 0), ("full_record_duplicate_excess", raw_duplicates),
               ("removed_missing_local", 15), ("removed_duplicate_five_columns", 2214),
               ("height_imputation_mean", means[0]), ("width_imputation_mean", means[1])])
    return sha


def save(fig, path):
    fig.savefig(path, dpi=180)
    plt.close(fig)


def describe_relationships(data, tables, figures):
    complete = [r for r in data if all(v is not None for v in r[:3])]
    matrix = [[stats.correlation([r[i] for r in complete], [r[j] for r in complete])
               for j in range(3)] for i in range(3)]
    write_csv(tables / "geometry_correlations.csv", ("feature_x", "feature_y", "n_complete", "pearson_r"),
              [(FIELDS[i], FIELDS[j], len(complete), matrix[i][j])
               for i in range(3) for j in range(i, 3)])
    fig, ax = plt.subplots(figsize=(6, 4), layout="constrained")
    heat = ax.imshow(matrix, vmin=-1, vmax=1, cmap="BrBG")
    ax.set_xticks(range(3), FIELDS[:3])
    ax.set_yticks(range(3), FIELDS[:3])
    ax.set_title(f"Pearson correlation; complete geometry n={len(complete):,}")
    for i in range(3):
        for j in range(3):
            ax.text(j, i, f"{matrix[i][j]:.3f}", ha="center", va="center",
                    color="white" if abs(matrix[i][j]) > .65 else "black")
    fig.colorbar(heat, ax=ax, label="Pearson r")
    save(fig, figures / "geometry_correlations.png")
    fig, axes = plt.subplots(1, 3, figsize=(11, 3.5), layout="constrained")
    for ax, (i, j) in zip(axes, ((0, 1), (0, 2), (1, 2))):
        for label, color in reversed(list(zip(LABELS, COLORS))):
            rows = [r for r in complete if r[-1] == label]
            ax.scatter([r[i] for r in rows], [r[j] for r in rows],
                       s=9, alpha=.35, color=color, label=f"{label} (n={len(rows)})")
        ax.set(xlabel=NAMES[i], ylabel=NAMES[j])
        ax.grid(alpha=.15)
    axes[0].legend(fontsize=8)
    fig.suptitle("Processed geometry pairs by class; reference-aligned sample")
    save(fig, figures / "geometry_scatterplots.png")
    audit = []
    for label in (*LABELS, "all"):
        rows = data if label == "all" else [r for r in data if r[-1] == label]
        for i, feature in enumerate(FIELDS[:3]):
            values = observed(rows, i)
            q1, _, q3 = stats.quantiles(values, n=4, method="inclusive")
            lower, upper = q1 - 1.5 * (q3 - q1), q3 + 1.5 * (q3 - q1)
            flagged = sum(v < lower or v > upper for v in values)
            audit.append((feature, label, len(values), lower, upper, flagged, flagged / len(values)))
    write_csv(tables / "outlier_audit.csv",
              ("variable", "group", "n_valid", "lower_fence", "upper_fence", "n_flagged", "proportion_flagged"), audit)


def build(source, processed, output):
    sha = export_processed(source, processed, output / "tables")
    with processed.open(encoding="utf-8", newline="") as file:
        data = [
            (*[None if row[k] == "NA" else float(row[k]) for k in FIELDS[:4]], row["IsAds"])
            for row in csv.DictReader(file)
        ]
    groups = {k: [r for r in data if r[-1] == k] for k in LABELS}
    groups["all"] = data
    tables, figures = output / "tables", output / "figures"
    figures.mkdir(parents=True, exist_ok=True)
    write_csv(tables / "class_counts.csv", ("class", "n", "proportion"),
              [(k, len(groups[k]), len(groups[k]) / len(data)) for k in LABELS])
    summary = []
    binary = []
    missing = []
    for label, rows in groups.items():
        missing.append((label, len(rows), sum(any(x is None for x in r[:3]) for r in rows)))
        for i, variable in enumerate(FIELDS[:3]):
            x = observed(rows, i)
            q1, median, q3 = stats.quantiles(x, n=4, method="inclusive")
            summary.append((variable, label, len(rows), len(x), len(rows) - len(x),
                            stats.mean(x), stats.stdev(x), min(x), q1, median, q3,
                            max(x), q3 - q1))
        x = observed(rows, 3)
        binary.append(("Local", label, len(rows), len(x), len(rows) - len(x),
                       x.count(1), x.count(1) / len(x)))
    write_csv(tables / "numeric_summary.csv",
              ("variable", "group", "n_total", "n_valid", "n_missing", "mean", "sd",
               "min", "q1", "median", "q3", "max", "iqr"), summary)
    write_csv(tables / "binary_summary.csv",
              ("variable", "group", "n_total", "n_valid", "n_missing", "n_one",
               "proportion_one"), binary)
    write_csv(tables / "geometry_missing.csv", ("group", "n_total", "n_any_missing"), missing)
    write_csv(tables / "column_inventory.csv", ("variable", "role", "n_missing"),
              [(name, role, sum(r[i] is None for r in data))
               for i, (name, role) in enumerate(zip(FIELDS, ("numeric",) * 3 + ("binary", "label")))])
    plt.rcParams.update({"axes.spines.top": False, "axes.spines.right": False,
                         "font.size": 11, "axes.axisbelow": True})
    fig, ax = plt.subplots(figsize=(6.4, 3.1), layout="constrained")
    counts = [len(groups[k]) for k in LABELS]
    bars = ax.bar(LABELS, counts, color=COLORS, width=.58)
    ax.bar_label(bars, labels=[f"{n:,} ({n / len(data):.2%})" for n in counts], padding=4)
    ax.set(ylim=(0, max(counts) * 1.18), ylabel="Observations")
    ax.grid(axis="y", alpha=.2)
    save(fig, figures / "class_distribution.png")
    for i, name in enumerate(NAMES):
        fig, (hist, box) = plt.subplots(1, 2, figsize=(8.5, 3.15), layout="constrained")
        x = observed(data, i)
        hist.hist(x, bins=28, color="#28786d", edgecolor="white", linewidth=.5)
        hist.set(xlabel=name, ylabel="Count", title=f"Processed values (n={len(x):,})")
        xs = [observed(groups[k], i) for k in LABELS]
        bp = box.boxplot(xs, patch_artist=True,
                         flierprops={"markersize": 2, "alpha": .35},
                         medianprops={"color": "#161616"})
        for patch, color in zip(bp["boxes"], COLORS):
            patch.set_facecolor(color)
        box.set_xticks([1, 2], [f"{k}\nn={len(x):,}" for k, x in zip(LABELS, xs)])
        box.set(ylabel=name, title="By class")
        for ax in (hist, box):
            ax.grid(axis="y", alpha=.2)
        save(fig, figures / f"numeric_{i + 1:03}.png")
    fig, ax = plt.subplots(figsize=(6.4, 3.0), layout="constrained")
    bars = ax.bar(LABELS, [r[-1] * 100 for r in binary[:2]], color=COLORS, width=.58)
    ax.bar_label(bars, labels=[f"{r[-1]:.2%} (n={r[3]:,})" for r in binary[:2]], padding=4)
    ax.set(ylim=(0, 100), ylabel="Local = 1 (% of observed values)")
    ax.grid(axis="y", alpha=.2)
    save(fig, figures / "binary_001.png")
    describe_relationships(data, tables, figures)
    fig, axes = plt.subplots(1, 2, figsize=(8.5, 3.3), layout="constrained")
    for i, ax in enumerate(axes):
        values = sorted(observed(data, i))
        theoretical = [stats.NormalDist().inv_cdf((j + .5) / len(values))
                       for j in range(len(values))]
        q1, _, q3 = stats.quantiles(values, n=4, method="inclusive")
        slope = (q3 - q1) / (stats.NormalDist().inv_cdf(.75) - stats.NormalDist().inv_cdf(.25))
        intercept = q1 - slope * stats.NormalDist().inv_cdf(.25)
        ax.scatter(theoretical, values, s=9, alpha=.4, color=COLORS[0])
        ax.plot([theoretical[0], theoretical[-1]],
                [intercept + slope * theoretical[0], intercept + slope * theoretical[-1]],
                color=COLORS[1])
        ax.set(xlabel="Theoretical normal quantile", ylabel=NAMES[i], title=FIELDS[i])
        ax.grid(alpha=.15)
    save(fig, figures / "geometry_qq.png")
    write_csv(tables / "figure_index.csv", ("variable", "file"),
              [(v, f"numeric_{i:03}.png") for i, v in enumerate(FIELDS[:3], 1)]
              + [("Local", "binary_001.png"), ("geometry_correlation", "geometry_correlations.png"),
                 ("geometry_pairs", "geometry_scatterplots.png"), ("geometry_qq", "geometry_qq.png")])
    (output / "run_metadata.txt").write_text(
        f"Source: Kaggle uciml/internet-advertisements-data-set / add.csv\n"
        f"Source SHA-256: {sha}\nProcessed input: {processed}\n"
        "Scope: reference-aligned 1050-row processed dataset; descriptive analysis only.\n"
        f"Rows: {len(data)}; selected: {', '.join(FIELDS)}\n"
        "Preprocessing: mean-impute Height/Width, recompute ratio, drop missing Local, deduplicate five columns. No model fitting.\n"
        "Quartiles: inclusive linear interpolation (R type 7); sample SD: n-1.\n"
        f"Figures: Matplotlib {matplotlib.__version__}\n", encoding="utf-8")
    print(f"EDA snapshot: {len(data)} rows, {len(summary)} numeric summaries; {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", type=Path, default=Path("data/raw/add.csv"),
                        help="Original Kaggle add.csv or ZIP (default: data/raw/add.csv)")
    parser.add_argument("--download", action="store_true",
                        help="Download the latest Kaggle add.csv before running the analysis")
    parser.add_argument("--processed", type=Path,
                        default=Path("output/eda-legacy/data/internet_ads_processed.csv"))
    parser.add_argument("--output", type=Path, default=Path("output/eda-legacy"))
    args = parser.parse_args()
    if args.download or not args.source.exists():
        if args.source.suffix.lower() != ".csv":
            parser.error("Automatic Kaggle download requires a .csv source path.")
        args.source = download_kaggle_source(args.source)
    build(args.source, args.processed, args.output)
