#!/usr/bin/env bash
# run_region000.sh
# Runs the MCMICRO pipeline on OrionImagesProcessed/A/region_000/region_000.ome.tiff
#
# Prerequisites:
#   1. source mcmicro_env.sh
#   2. Run run_exemplar.sh successfully at least once (pulls all containers)
#
# Usage:
#   source mcmicro_env.sh
#   bash run_region000.sh

set -euo pipefail

MCMICRO_DIR="/sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro"

# Source OME-TIFF (do not move — we symlink below)
IMAGE_SRC="/sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImagesProcessed/A/region_000/region_000.ome.tiff"

# MCMICRO experiment directory — outputs land here alongside raw/
EXPERIMENT="/sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImagesProcessed/A/region_000_run"

# --- Verify source image exists ---
if [ ! -f "$IMAGE_SRC" ]; then
  echo "ERROR: Image not found at:"
  echo "  $IMAGE_SRC"
  exit 1
fi

# --- Create MCMICRO input structure ---
# MCMICRO expects: <experiment>/raw/<image.ome.tiff>
RAW_DIR="$EXPERIMENT/raw"
mkdir -p "$RAW_DIR"

IMAGE_LINK="$RAW_DIR/region_000.ome.tiff"
if [ ! -L "$IMAGE_LINK" ]; then
  ln -sv "$IMAGE_SRC" "$IMAGE_LINK"
  echo "==> Symlinked image into $RAW_DIR"
else
  echo "==> Symlink already exists: $IMAGE_LINK"
fi

echo ""
echo "==> Starting MCMICRO pipeline..."
echo "    Image      : $IMAGE_SRC"
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
