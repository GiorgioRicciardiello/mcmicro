#!/usr/bin/env python3
"""
colocalization_analysis.py
==========================
Reads the per-cell channel intensity CSV produced by mcquant (MCMICRO's
quantification module) and computes pairwise colocalization metrics across
all marker channels:

  - Pearson correlation coefficient
  - Spearman rank correlation coefficient
  - Manders overlap coefficients M1 and M2

Outputs
-------
  <output_dir>/pearson_matrix.csv        — NxN Pearson r matrix
  <output_dir>/spearman_matrix.csv       — NxN Spearman r matrix
  <output_dir>/manders_m1_matrix.csv     — NxN Manders M1 matrix
  <output_dir>/manders_m2_matrix.csv     — NxN Manders M2 matrix
  <output_dir>/colocalization_heatmaps.png — 4-panel heatmap figure

Usage
-----
  python3 colocalization_analysis.py \\
      --input  /path/to/quantification/cell.csv \\
      --output-dir /path/to/colocalization/ \\
      --markers-csv /path/to/markers.csv

  Optional flags:
      --intensity-metric  mean_intensity | median_intensity  (default: mean_intensity)
      --min-cells         minimum number of cells required to run (default: 50)

Dependencies
------------
  numpy, pandas, scipy, matplotlib, seaborn  (all standard scientific stack)
"""

import argparse
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")  # non-interactive backend for HPC nodes

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from scipy import stats


# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Pairwise colocalization metrics from mcquant per-cell CSV."
    )
    parser.add_argument(
        "--input", required=True,
        help="Path to mcquant per-cell quantification CSV (e.g. cell.csv)."
    )
    parser.add_argument(
        "--output-dir", required=True,
        help="Directory where output CSVs and heatmap PNG will be written."
    )
    parser.add_argument(
        "--markers-csv", required=True,
        help="Path to markers.csv used in the MCMICRO run."
    )
    parser.add_argument(
        "--intensity-metric", default="mean_intensity",
        choices=["mean_intensity", "median_intensity"],
        help="Which per-channel intensity metric to use (default: mean_intensity)."
    )
    parser.add_argument(
        "--min-cells", type=int, default=50,
        help="Minimum cell count required to proceed (default: 50)."
    )
    return parser.parse_args()


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

def load_markers(markers_csv_path: Path) -> list[str]:
    """Return ordered list of marker names from markers.csv."""
    df = pd.read_csv(markers_csv_path)
    required_col = "marker_name"
    if required_col not in df.columns:
        raise ValueError(
            f"markers.csv must contain a '{required_col}' column. "
            f"Found columns: {list(df.columns)}"
        )
    markers = df[required_col].dropna().str.strip().tolist()
    if not markers:
        raise ValueError("markers.csv contains no marker names.")
    return markers


def load_quantification(quant_csv_path: Path) -> pd.DataFrame:
    """Load the mcquant per-cell CSV into a DataFrame."""
    df = pd.read_csv(quant_csv_path)
    if df.empty:
        raise ValueError(f"Quantification CSV is empty: {quant_csv_path}")
    return df


def extract_intensity_columns(
    df: pd.DataFrame,
    markers: list[str],
    metric: str,
) -> pd.DataFrame:
    """
    Select the intensity columns for each marker from the mcquant CSV.

    mcquant names intensity columns as:
        <MarkerName>_<metric>    e.g.  Ki67_mean_intensity
    or, for some versions, just:
        <MarkerName>             (when only mean intensity is computed)

    This function tries the suffixed form first, then falls back to bare
    marker names, so it works across mcquant versions.

    Returns a DataFrame with one column per marker (columns named by marker).
    """
    selected = {}
    missing = []

    for marker in markers:
        suffixed = f"{marker}_{metric}"
        if suffixed in df.columns:
            selected[marker] = df[suffixed].values
        elif marker in df.columns:
            selected[marker] = df[marker].values
        else:
            missing.append(marker)

    if missing:
        # Emit a warning but continue with the markers that were found.
        # This handles autofluorescence channels (AF1, AF2, ArgoFluor*) that
        # some pipelines may exclude from quantification output.
        print(
            f"WARNING: The following markers were not found in the quantification "
            f"CSV (they will be excluded from analysis): {missing}",
            file=sys.stderr,
        )

    if not selected:
        raise ValueError(
            "No marker intensity columns could be matched in the quantification CSV.\n"
            f"Available columns: {list(df.columns)}\n"
            f"Markers searched: {markers}"
        )

    intensity_df = pd.DataFrame(selected)

    # Drop rows where ALL intensity values are NaN (segmentation artefacts)
    intensity_df = intensity_df.dropna(how="all")

    return intensity_df


# ---------------------------------------------------------------------------
# Colocalization metrics
# ---------------------------------------------------------------------------

def pearson_matrix(intensity_df: pd.DataFrame) -> pd.DataFrame:
    """
    Compute pairwise Pearson correlation coefficients.

    Uses scipy.stats.pearsonr for each pair to handle edge cases cleanly.
    Returns an NxN DataFrame (marker x marker).
    """
    markers = intensity_df.columns.tolist()
    n = len(markers)
    matrix = np.ones((n, n))

    for i in range(n):
        for j in range(i + 1, n):
            x = intensity_df.iloc[:, i].values.astype(float)
            y = intensity_df.iloc[:, j].values.astype(float)
            # Remove rows with NaN in either channel
            valid = np.isfinite(x) & np.isfinite(y)
            if valid.sum() < 3:
                r = np.nan
            else:
                r, _ = stats.pearsonr(x[valid], y[valid])
            matrix[i, j] = r
            matrix[j, i] = r

    return pd.DataFrame(matrix, index=markers, columns=markers)


def spearman_matrix(intensity_df: pd.DataFrame) -> pd.DataFrame:
    """
    Compute pairwise Spearman rank correlation coefficients.

    Returns an NxN DataFrame (marker x marker).
    """
    markers = intensity_df.columns.tolist()
    n = len(markers)
    matrix = np.ones((n, n))

    for i in range(n):
        for j in range(i + 1, n):
            x = intensity_df.iloc[:, i].values.astype(float)
            y = intensity_df.iloc[:, j].values.astype(float)
            valid = np.isfinite(x) & np.isfinite(y)
            if valid.sum() < 3:
                r = np.nan
            else:
                r, _ = stats.spearmanr(x[valid], y[valid])
            matrix[i, j] = r
            matrix[j, i] = r

    return pd.DataFrame(matrix, index=markers, columns=markers)


def manders_coefficients(
    x: np.ndarray,
    y: np.ndarray,
) -> tuple[float, float]:
    """
    Compute Manders overlap coefficients M1 and M2 for a single channel pair.

    M1 = sum(x_i  where y_i > 0) / sum(x_i)
    M2 = sum(y_i  where x_i > 0) / sum(y_i)

    Both x and y must be non-negative (raw intensity values).
    Returns (M1, M2).  Returns (nan, nan) if denominators are zero.
    """
    x = np.clip(x.astype(float), 0, None)
    y = np.clip(y.astype(float), 0, None)

    # Use positivity thresholds: a pixel/cell contributes if its intensity > 0
    y_positive = y > 0
    x_positive = x > 0

    sum_x = x.sum()
    sum_y = y.sum()

    m1 = x[y_positive].sum() / sum_x if sum_x > 0 else np.nan
    m2 = y[x_positive].sum() / sum_y if sum_y > 0 else np.nan

    return float(m1), float(m2)


def manders_matrices(
    intensity_df: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """
    Compute pairwise Manders M1 and M2 matrices.

    M1[i, j] = fraction of channel-i intensity co-occurring with channel-j signal.
    M2[i, j] = fraction of channel-j intensity co-occurring with channel-i signal.

    Note: M1[i,j] == M2[j,i] by definition, so the two matrices are transposes
    of each other (modulo NaN handling). Both are returned for explicitness.

    Returns (m1_df, m2_df), each NxN DataFrame (marker x marker).
    Diagonal is set to 1.0 (perfect self-overlap).
    """
    markers = intensity_df.columns.tolist()
    n = len(markers)
    m1_matrix = np.ones((n, n))
    m2_matrix = np.ones((n, n))

    for i in range(n):
        for j in range(i + 1, n):
            x = intensity_df.iloc[:, i].values.astype(float)
            y = intensity_df.iloc[:, j].values.astype(float)
            # Exclude NaN cells
            valid = np.isfinite(x) & np.isfinite(y)
            if valid.sum() < 3:
                m1 = m2 = np.nan
            else:
                m1, m2 = manders_coefficients(x[valid], y[valid])
            # M1[i,j]: fraction of i co-localizing with j
            m1_matrix[i, j] = m1
            m1_matrix[j, i] = m2   # M1[j,i] == M2[i,j]
            # M2[i,j]: fraction of j co-localizing with i
            m2_matrix[i, j] = m2
            m2_matrix[j, i] = m1   # M2[j,i] == M1[i,j]

    m1_df = pd.DataFrame(m1_matrix, index=markers, columns=markers)
    m2_df = pd.DataFrame(m2_matrix, index=markers, columns=markers)
    return m1_df, m2_df


# ---------------------------------------------------------------------------
# Output: CSV matrices
# ---------------------------------------------------------------------------

def save_matrix(df: pd.DataFrame, output_path: Path) -> None:
    """Write a square metric matrix to CSV with row and column headers."""
    df.to_csv(output_path, float_format="%.6f")
    print(f"  Saved: {output_path}")


# ---------------------------------------------------------------------------
# Output: Heatmap figure
# ---------------------------------------------------------------------------

def plot_heatmaps(
    pearson_df: pd.DataFrame,
    spearman_df: pd.DataFrame,
    manders_m1_df: pd.DataFrame,
    manders_m2_df: pd.DataFrame,
    output_path: Path,
    sample_label: str = "",
) -> None:
    """
    Generate a 2x2 figure with annotated heatmaps for all four metrics.

    Color scales:
      - Pearson / Spearman: diverging (-1 to +1), center at 0
      - Manders M1 / M2:    sequential (0 to 1)
    """
    fig, axes = plt.subplots(2, 2, figsize=(22, 20))
    fig.suptitle(
        f"Pairwise Channel Colocalization Metrics{' — ' + sample_label if sample_label else ''}",
        fontsize=14,
        fontweight="bold",
        y=0.98,
    )

    panels = [
        (axes[0, 0], pearson_df,    "Pearson r",           "coolwarm", -1, 1),
        (axes[0, 1], spearman_df,   "Spearman r",          "coolwarm", -1, 1),
        (axes[1, 0], manders_m1_df, "Manders M1\n(row co-localizes with col)", "YlOrRd", 0, 1),
        (axes[1, 1], manders_m2_df, "Manders M2\n(col co-localizes with row)", "YlOrRd", 0, 1),
    ]

    for ax, data, title, cmap, vmin, vmax in panels:
        mask = np.zeros_like(data.values, dtype=bool)
        # Mask upper triangle for Pearson/Spearman (symmetric); show full for Manders
        if "Manders" not in title:
            mask[np.triu_indices_from(mask, k=1)] = True

        sns.heatmap(
            data,
            ax=ax,
            cmap=cmap,
            vmin=vmin,
            vmax=vmax,
            mask=mask if "Manders" not in title else None,
            square=True,
            linewidths=0.3,
            linecolor="lightgray",
            annot=True,
            fmt=".2f",
            annot_kws={"size": 6},
            cbar_kws={"shrink": 0.75, "label": title.split("\n")[0]},
        )
        ax.set_title(title, fontsize=11, pad=10)
        ax.set_xlabel("")
        ax.set_ylabel("")
        ax.tick_params(axis="x", rotation=45, labelsize=7)
        ax.tick_params(axis="y", rotation=0,  labelsize=7)

    plt.tight_layout(rect=[0, 0, 1, 0.97])
    plt.savefig(output_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved: {output_path}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    args = parse_args()

    input_path = Path(args.input).resolve()
    output_dir = Path(args.output_dir).resolve()
    markers_csv_path = Path(args.markers_csv).resolve()

    # Validate inputs
    if not input_path.is_file():
        print(f"ERROR: Quantification CSV not found: {input_path}", file=sys.stderr)
        sys.exit(1)
    if not markers_csv_path.is_file():
        print(f"ERROR: markers.csv not found: {markers_csv_path}", file=sys.stderr)
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading markers from: {markers_csv_path}")
    markers = load_markers(markers_csv_path)
    print(f"  Found {len(markers)} markers: {markers}")

    print(f"\nLoading quantification data from: {input_path}")
    quant_df = load_quantification(input_path)
    print(f"  Total cells (rows) in CSV: {len(quant_df):,}")
    print(f"  Total columns: {len(quant_df.columns)}")

    if len(quant_df) < args.min_cells:
        print(
            f"ERROR: Only {len(quant_df)} cells found; minimum required is "
            f"{args.min_cells}. Aborting.",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"\nExtracting '{args.intensity_metric}' columns for each marker...")
    intensity_df = extract_intensity_columns(quant_df, markers, args.intensity_metric)
    n_markers = intensity_df.shape[1]
    n_cells = intensity_df.shape[0]
    print(f"  Markers matched: {n_markers} / {len(markers)}")
    print(f"  Cells used (non-empty rows): {n_cells:,}")

    if n_markers < 2:
        print(
            "ERROR: Fewer than 2 marker columns matched — cannot compute pairwise metrics.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Infer a short sample label from the input filename
    sample_label = input_path.stem

    print(f"\nComputing colocalization metrics for {n_markers} channels "
          f"({n_markers * (n_markers - 1) // 2} pairs)...")

    print("  Computing Pearson correlation matrix...")
    pearson_df = pearson_matrix(intensity_df)

    print("  Computing Spearman correlation matrix...")
    spearman_df = spearman_matrix(intensity_df)

    print("  Computing Manders overlap coefficients (M1, M2)...")
    manders_m1_df, manders_m2_df = manders_matrices(intensity_df)

    print("\nSaving output files...")
    save_matrix(pearson_df,    output_dir / "pearson_matrix.csv")
    save_matrix(spearman_df,   output_dir / "spearman_matrix.csv")
    save_matrix(manders_m1_df, output_dir / "manders_m1_matrix.csv")
    save_matrix(manders_m2_df, output_dir / "manders_m2_matrix.csv")

    print("  Generating heatmap figure...")
    plot_heatmaps(
        pearson_df,
        spearman_df,
        manders_m1_df,
        manders_m2_df,
        output_path=output_dir / "colocalization_heatmaps.png",
        sample_label=sample_label,
    )

    print(f"\nDone. All outputs written to: {output_dir}")


if __name__ == "__main__":
    main()
