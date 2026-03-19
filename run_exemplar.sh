#!/usr/bin/env bash
# run_exemplar.sh
# Downloads and runs the MCMICRO test exemplar on Minerva.
# Run ONCE to verify the pipeline and container pulls work before
# processing real data.
#
# Usage (from the mcmicro repo directory):
#   source mcmicro_env.sh
#   bash run_exemplar.sh

set -euo pipefail

MCMICRO_DIR="/sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro"
TEST_DIR="/sc/arion/projects/vascbrain/giocrm/OrionCadasil/test"

mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "==> Downloading exemplar-001..."
nextflow run "$MCMICRO_DIR/exemplar.nf" \
  --name exemplar-001 \
  --path "$TEST_DIR" \
  -w "$NXF_WORK"

echo "==> Running MCMICRO pipeline on exemplar-001..."
nextflow run "$MCMICRO_DIR" \
  --in "$TEST_DIR/exemplar-001" \
  -profile minerva,WSI \
  -w "$NXF_WORK" \
  -resume

echo "==> Exemplar run complete. Check $TEST_DIR/exemplar-001 for outputs."
