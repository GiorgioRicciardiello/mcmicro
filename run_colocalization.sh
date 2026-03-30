#!/usr/bin/env bash
#===========================================================
# LSF DIRECTIVES
#===========================================================
#BSUB -J mcmicro_coloc
#BSUB -P acc_vascbrain
#BSUB -q long
#BSUB -W 24:00
#BSUB -n 4
#BSUB -R "rusage[mem=16000] span[hosts=1]"
#BSUB -o logs/coloc_%J.out
#BSUB -e logs/coloc_%J.err

# run_colocalization.sh
# Runs the MCMICRO pipeline through quantification on a single sample
# directory, then executes colocalization_analysis.py to compute pairwise
# Pearson / Manders / Spearman metrics across all 20 Orion channels.
#
# Usage (interactive, after sourcing environment):
#   source mcmicro_env.sh
#   bash run_colocalization.sh /path/to/experiment_dir
#
# Usage (LSF batch — pass SAMPLE_DIR via env variable):
#   SAMPLE_DIR=/path/to/experiment_dir bsub < run_colocalization.sh
#
# The script expects the experiment directory to already contain:
#   <SAMPLE_DIR>/raw/<image.ome.tiff>
#   <SAMPLE_DIR>/markers.csv
#
# After a successful pipeline run, quantification CSVs will appear at:
#   <SAMPLE_DIR>/quantification/<sample_name>*.csv
#
# Colocalization outputs are written to:
#   <SAMPLE_DIR>/colocalization/

set -uo pipefail

#-----------------------------------------------------------
# Resolve paths
#-----------------------------------------------------------
MCMICRO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$MCMICRO_DIR/logs"
PARAMS_YML="$MCMICRO_DIR/params.yml"
COLOC_SCRIPT="$MCMICRO_DIR/colocalization_analysis.py"

mkdir -p "$LOG_DIR"

# Accept sample directory as first positional argument or via env variable
SAMPLE_DIR="${1:-${SAMPLE_DIR:-}}"

if [ -z "$SAMPLE_DIR" ]; then
  echo "ERROR: No sample directory specified."
  echo "Usage: bash run_colocalization.sh /path/to/experiment_dir"
  echo "       or set SAMPLE_DIR=/path/to/experiment_dir before bsub submission"
  exit 1
fi

if [ ! -d "$SAMPLE_DIR" ]; then
  echo "ERROR: Sample directory not found: $SAMPLE_DIR"
  exit 1
fi

if [ ! -f "$SAMPLE_DIR/markers.csv" ]; then
  echo "ERROR: markers.csv not found in $SAMPLE_DIR"
  echo "  Expected: $SAMPLE_DIR/markers.csv"
  exit 1
fi

# Source MCMICRO environment (loads nextflow, apptainer, sets NXF_WORK etc.)
source "$MCMICRO_DIR/mcmicro_env.sh"

echo "============================================"
echo " MCMICRO colocalization run"
echo " Sample dir : $SAMPLE_DIR"
echo " Params     : $PARAMS_YML"
echo " Profile    : minerva,WSI"
echo " Work dir   : $NXF_WORK"
echo "============================================"
echo ""

#-----------------------------------------------------------
# Step 1: Run MCMICRO pipeline through quantification
#-----------------------------------------------------------
echo "==> [1/2] Running MCMICRO pipeline (registration -> quantification)..."

if ! nextflow run "$MCMICRO_DIR" \
    --in "$SAMPLE_DIR" \
    --params "$PARAMS_YML" \
    -profile minerva,WSI \
    -w "$NXF_WORK" \
    -resume; then
  echo "ERROR: MCMICRO pipeline failed for $SAMPLE_DIR"
  echo "  Check Nextflow logs in $NXF_WORK and the LSF error log."
  exit 1
fi

echo "==> MCMICRO pipeline complete."
echo ""

#-----------------------------------------------------------
# Step 2: Locate the quantification CSV produced by mcquant
#-----------------------------------------------------------
QUANT_DIR="$SAMPLE_DIR/quantification"

if [ ! -d "$QUANT_DIR" ]; then
  echo "ERROR: Quantification output directory not found: $QUANT_DIR"
  echo "  The pipeline may not have reached the quantification step."
  exit 1
fi

# mcquant writes one CSV per mask type; select the cell-level CSV
# (matched by cell*.csv — produced from cell*.tif mask)
QUANT_CSV=$(ls "$QUANT_DIR"/cell*.csv 2>/dev/null | head -1)

if [ -z "$QUANT_CSV" ]; then
  # Fallback: take any CSV in the quantification directory
  QUANT_CSV=$(ls "$QUANT_DIR"/*.csv 2>/dev/null | head -1)
fi

if [ -z "$QUANT_CSV" ]; then
  echo "ERROR: No quantification CSV found in $QUANT_DIR"
  echo "  Expected pattern: $QUANT_DIR/cell*.csv"
  exit 1
fi

echo "==> Quantification CSV: $QUANT_CSV"

#-----------------------------------------------------------
# Step 3: Run colocalization analysis
#-----------------------------------------------------------
COLOC_OUT_DIR="$SAMPLE_DIR/colocalization"
mkdir -p "$COLOC_OUT_DIR"

echo "==> [2/2] Running colocalization analysis..."
echo "    Input CSV  : $QUANT_CSV"
echo "    Output dir : $COLOC_OUT_DIR"
echo ""

if ! python3 "$COLOC_SCRIPT" \
    --input "$QUANT_CSV" \
    --output-dir "$COLOC_OUT_DIR" \
    --markers-csv "$SAMPLE_DIR/markers.csv"; then
  echo "ERROR: Colocalization analysis failed."
  echo "  Check Python output above for details."
  exit 1
fi

echo ""
echo "============================================"
echo " Colocalization analysis complete."
echo " Results in: $COLOC_OUT_DIR"
echo "   pearson_matrix.csv"
echo "   spearman_matrix.csv"
echo "   manders_m1_matrix.csv"
echo "   manders_m2_matrix.csv"
echo "   colocalization_heatmaps.png"
echo "============================================"
