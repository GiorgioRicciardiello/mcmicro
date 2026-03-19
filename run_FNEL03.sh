#!/usr/bin/env bash
# run_FNEL03.sh
# Runs the MCMICRO pipeline on the FNEL03 Orion whole-slide image.
#
# Prerequisites:
#   1. source mcmicro_env.sh
#   2. Run run_exemplar.sh successfully at least once
#
# Usage:
#   source mcmicro_env.sh
#   bash run_FNEL03.sh

set -euo pipefail

MCMICRO_DIR="/sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro"

# Input experiment folder — must contain raw/ subfolder with the image
EXPERIMENT="/sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImages/FNEL03_CAD001_001"

# The raw image (already on Minerva)
IMAGE_SRC="/sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImages/FNEL03_CAD001_001/FNEL03_CAD001_001/FNEL03_CAD001_001_FNEL03_2026_V1_001703.ome.tiff"

# --- Verify source image exists ---
if [ ! -f "$IMAGE_SRC" ]; then
  echo "ERROR: Image not found at:"
  echo "  $IMAGE_SRC"
  echo "Check the path and try again."
  exit 1
fi

# --- Create MCMICRO input structure ---
# MCMICRO expects: <experiment>/raw/<image.ome.tiff>
RAW_DIR="$EXPERIMENT/raw"
mkdir -p "$RAW_DIR"

# Symlink image into raw/ if not already there
IMAGE_LINK="$RAW_DIR/FNEL03_CAD001_001_FNEL03_2026_V1_001703.ome.tiff"
if [ ! -L "$IMAGE_LINK" ]; then
  ln -sv "$IMAGE_SRC" "$IMAGE_LINK"
  echo "==> Symlinked image into $RAW_DIR"
else
  echo "==> Symlink already exists: $IMAGE_LINK"
fi

echo "==> Starting MCMICRO pipeline..."
echo "    Experiment : $EXPERIMENT"
echo "    Work dir   : $NXF_WORK"
echo "    Profile    : minerva,WSI"
echo ""

nextflow run "$MCMICRO_DIR" \
  --in "$EXPERIMENT" \
  -profile minerva,WSI \
  -w "$NXF_WORK" \
  -resume

echo ""
echo "==> Pipeline finished. Outputs are in:"
echo "    $EXPERIMENT/"
