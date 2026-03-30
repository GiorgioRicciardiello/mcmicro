#!/usr/bin/env bash
#===========================================================
# LSF DIRECTIVES
#===========================================================
#BSUB -J mcmicro_coloc_batch
#BSUB -P acc_vascbrain
#BSUB -q long
#BSUB -W 72:00
#BSUB -n 4
#BSUB -R "rusage[mem=16000] span[hosts=1]"
#BSUB -o logs/coloc_batch_%J.out
#BSUB -e logs/coloc_batch_%J.err

# run_all_colocalization.sh
# Runs MCMICRO colocalization analysis sequentially on all samples A-K.
# First runs the mcmicro pipeline through quantification on each sample,
# then computes colocalization metrics.
#
# Usage (from login node, submit as LSF job):
#   bsub < run_all_colocalization.sh
#
# Or run locally (without LSF submission):
#   source mcmicro_env.sh
#   bash run_all_colocalization.sh
#
# To run a subset via LSF:
#   bsub -v REGIONS="B C D" < run_all_colocalization.sh

set -uo pipefail

# Resolve paths
MCMICRO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MCMICRO_DIR/mcmicro_env.sh"

BASE_DIR="/sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImagesProcessed"
LOG_DIR="$MCMICRO_DIR/logs/batch"
COLOC_SCRIPT="$MCMICRO_DIR/colocalization_analysis.py"
PARAMS_YML="$MCMICRO_DIR/params.yml"
mkdir -p "$LOG_DIR"

FAILED=""

# Default: run all folders A-K. Override with: REGIONS="B C D" bash run_all_colocalization.sh
REGIONS="${REGIONS:-A B C D E F G H I J K}"

echo "============================================"
echo " MCMICRO colocalization batch"
echo " Samples : $REGIONS"
echo " Base dir: $BASE_DIR"
echo " Work dir: $NXF_WORK"
echo "============================================"
echo ""

for LETTER in $REGIONS; do
  SAMPLE_DIR="$BASE_DIR/$LETTER"

  echo "----------------------------------------------"
  echo " Sample: $LETTER"
  echo " Path  : $SAMPLE_DIR"
  echo "----------------------------------------------"

  # Verify sample directory exists
  if [ ! -d "$SAMPLE_DIR" ]; then
    echo "  [SKIP] Directory not found — skipping $LETTER"
    echo ""
    continue
  fi

  # Verify markers.csv exists
  if [ ! -f "$SAMPLE_DIR/markers.csv" ]; then
    echo "  [SKIP] markers.csv not found — skipping $LETTER"
    echo ""
    continue
  fi

  # Run colocalization pipeline — log per sample, continue on failure
  SAMPLE_LOG="$LOG_DIR/coloc_${LETTER}.log"
  echo "  ==> Starting mcmicro colocalization for $LETTER (log: $SAMPLE_LOG) ..."

  if bash "$MCMICRO_DIR/run_colocalization.sh" "$SAMPLE_DIR" 2>&1 | tee "$SAMPLE_LOG"; then
    echo "  ==> [OK] $LETTER complete. Results in $SAMPLE_DIR/colocalization/"
  else
    echo "  ==> [FAIL] $LETTER failed — check $SAMPLE_LOG"
    FAILED="$FAILED $LETTER"
  fi
  echo ""
done

echo "============================================"
echo " Batch colocalization complete."
if [ -n "$FAILED" ]; then
  echo " FAILED samples:$FAILED"
  echo " Re-run with: REGIONS=\"${FAILED# }\" bash run_all_colocalization.sh"
else
  echo " All samples succeeded."
fi
echo "============================================"
