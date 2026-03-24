#!/usr/bin/env bash
# run_all_regions.sh
# Runs the MCMICRO pipeline sequentially on all region_000 images in
# OrionImagesProcessed/ (folders A through K).
#
# Each folder must contain: <LETTER>/region_000/region_000.ome.tiff
# Outputs land in:          <LETTER>/region_000_run/
#
# Usage:
#   source mcmicro_env.sh
#   bash run_all_regions.sh
#
# To run a subset (e.g. B through D only):
#   REGIONS="B C D" bash run_all_regions.sh

set -euo pipefail

MCMICRO_DIR="/sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro"
BASE_DIR="/sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImagesProcessed"
MARKERS="$MCMICRO_DIR/config/markers/orion_20ch_panel.csv"

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

  # Run pipeline
  echo "  ==> Starting nextflow for $LETTER ..."
  nextflow run "$MCMICRO_DIR" \
    --in "$EXPERIMENT" \
    -profile minerva,WSI \
    -w "$NXF_WORK" \
    -resume

  echo "  ==> $LETTER complete. Outputs in $EXPERIMENT/"
  echo ""
done

echo "============================================"
echo " All samples done."
echo "============================================"
