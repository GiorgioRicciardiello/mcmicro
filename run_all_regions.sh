#!/usr/bin/env bash
#===========================================================
# LSF DIRECTIVES
#===========================================================
#BSUB -J mcmicro_batch_regions
#BSUB -P acc_vascbrain
#BSUB -q long
#BSUB -W 72:00
#BSUB -n 4
#BSUB -R "rusage[mem=8000] span[hosts=1]"
#BSUB -o /sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro/logs/batch_mcmicro_%J.out
#BSUB -e /sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro/logs/batch_mcmicro_%J.err

# run_all_regions.sh
# Runs the MCMICRO pipeline sequentially on all region_000 images in
# OrionImagesProcessed/ (folders A through K).
#
# Usage (from login node):
#   bsub < run_all_regions.sh
#
# Or run locally (without LSF submission):
#   source mcmicro_env.sh
#   bash run_all_regions.sh
#
# To run a subset via LSF:
#   bsub -v REGIONS="B C D" < run_all_regions.sh

set -uo pipefail

# Source environment (CRITICAL for bsub jobs)
MCMICRO_DIR="/sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro"
source "$MCMICRO_DIR/mcmicro_env.sh"
BASE_DIR="/sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImagesProcessed"
MARKERS="$MCMICRO_DIR/config/markers/orion_20ch_panel.csv"
LOG_DIR="$MCMICRO_DIR/logs/batch"
mkdir -p "$LOG_DIR"

FAILED=""

# Default: run all folders A-K. Override with: REGIONS="B C D" bash run_all_regions.sh
REGIONS="${REGIONS:-A B C D E F G H I J K}"

echo "============================================"
echo " MCMICRO batch run — OrionImagesProcessed"
echo " Samples : $REGIONS"
echo " Profile : minerva,WSI"
echo " Work dir: $NXF_WORK"
echo "============================================"
echo ""

for LETTER in $REGIONS; do
  IMAGE_SRC="$BASE_DIR/$LETTER/region_000/region_000.ome.tiff"
  EXPERIMENT="$BASE_DIR/$LETTER/region_000_run"

  echo "----------------------------------------------"
  echo " Sample: $LETTER"
  echo " Image : $IMAGE_SRC"
  echo " Output: $EXPERIMENT"
  echo "----------------------------------------------"

  # Verify image exists
  if [ ! -f "$IMAGE_SRC" ]; then
    echo "  [SKIP] Image not found — skipping $LETTER"
    echo ""
    continue
  fi

  # Ensure parent dir is writable
  chmod u+w "$BASE_DIR/$LETTER" 2>/dev/null || true

  # Create MCMICRO input structure
  mkdir -p "$EXPERIMENT/raw"

  # Symlink image
  IMAGE_LINK="$EXPERIMENT/raw/region_000.ome.tiff"
  if [ ! -L "$IMAGE_LINK" ]; then
    ln -sv "$IMAGE_SRC" "$IMAGE_LINK"
  fi

  # Deploy markers.csv
  cp -n "$MARKERS" "$EXPERIMENT/markers.csv" 2>/dev/null || true

  # Run pipeline — log per sample, continue on failure
  SAMPLE_LOG="$LOG_DIR/sample_${LETTER}.log"
  echo "  ==> Starting nextflow for $LETTER (log: $SAMPLE_LOG) ..."
  if nextflow run "$MCMICRO_DIR" \
      --in "$EXPERIMENT" \
      -profile minerva,WSI \
      -w "$NXF_WORK" \
      -resume 2>&1 | tee "$SAMPLE_LOG"; then
    echo "  ==> [OK] $LETTER complete. Outputs in $EXPERIMENT/"
  else
    echo "  ==> [FAIL] $LETTER failed — check $SAMPLE_LOG"
    FAILED="$FAILED $LETTER"
  fi
  echo ""
done

echo "============================================"
echo " Batch complete."
if [ -n "$FAILED" ]; then
  echo " FAILED samples:$FAILED"
  echo " Re-run with: REGIONS=\"${FAILED# }\" bash run_all_regions.sh"
else
  echo " All samples succeeded."
fi
echo "============================================"