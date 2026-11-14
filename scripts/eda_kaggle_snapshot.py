"""Validate the Kaggle CSV, export full processed data, and reproduce EDA."""
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
FIELDS = ("height", "width", "aspect_ratio", "local", "label")
FULL_FIELDS = FIELDS[:4] + tuple(f"term_{i}" for i in range(4, 1558)) + ("label",)
LABELS = ("ad", "nonad")
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
        if values[3] not in (None, 0, 1):
            raise ValueError(f"Invalid Local value at observation {index + 1}.")
        label = {"ad.": "ad", "nonad.": "nonad"}.get(row[-1].strip())
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
    duplicates = len(rows) - len(set(rows))
    missing = Counter(i for row in rows for i, value in enumerate(row) if value is None)
    write_csv(processed, FULL_FIELDS, rows)
    write_csv(processed.with_name("data_dictionary.csv"),
              ("variable", "source_header", "type", "unit", "missing_count", "description"),
              [(name, str(i), "numeric" if i < 3 else "label" if i == 1558 else "binary",
                "px" if i < 2 else "", missing[i],
                {"height": "Image height", "width": "Image width",
                 "aspect_ratio": "Width divided by height", "local": "Original binary local indicator",
                 "label": "Advertisement class (ad or nonad)"}.get(name, "Original binary term indicator"))
               for i, name in enumerate(FULL_FIELDS)])
    write_csv(audit_dir / "preprocessing_audit.csv", ("metric", "value"),
              [("source_sha256", sha), ("raw_observations", len(rows)),
               ("raw_columns_including_index", 1560), ("processed_observations", len(rows)),
               ("processed_columns", len(FULL_FIELDS)), ("missing_cells", sum(missing.values())),
               ("duplicate_rows_beyond_first_excluding_index", duplicates),
               ("rows_removed", 0), ("imputed_values", 0)])
    return sha


def save(fig, path):
    fig.savefig(path, dpi=180)
    plt.close(fig)


def build(source, processed, output):
    sha = export_processed(source, processed, output / "tables")
    with processed.open(encoding="utf-8", newline="") as file:
        data = [
            (*[None if row[k] == "NA" else float(row[k]) for k in FIELDS[:4]], row["label"])
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
        binary.append(("local", label, len(rows), len(x), len(rows) - len(x),
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
        hist.set(xlabel=name, ylabel="Observed count", title=f"All observed values (n={len(x):,})")
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
    write_csv(tables / "figure_index.csv", ("variable", "file"),
              [(v, f"numeric_{i:03}.png") for i, v in enumerate(FIELDS[:3], 1)]
              + [("local", "binary_001.png")])
    (output / "run_metadata.txt").write_text(
        f"Source: Kaggle uciml/internet-advertisements-data-set / add.csv\n"
        f"Source SHA-256: {sha}\nProcessed input: {processed}\n"
        "Scope: full processed dataset; descriptive analysis only.\n"
        f"Rows: {len(data)}; selected: {', '.join(FIELDS)}\n"
        "No imputation, filtering, deduplication or model fitting.\n"
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
                        default=Path("data/processed/internet_ads_processed.csv"))
    parser.add_argument("--output", type=Path, default=Path("output/eda"))
    args = parser.parse_args()
    if args.download or not args.source.exists():
        if args.source.suffix.lower() != ".csv":
            parser.error("Automatic Kaggle download requires a .csv source path.")
        args.source = download_kaggle_source(args.source)
    build(args.source, args.processed, args.output)
