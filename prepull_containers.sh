#!/usr/bin/env bash
# prepull_containers.sh
# Pre-pulls all MCMICRO container images using the exact filename format
# that Nextflow expects: docker://<org>/<name>:<tag> -> <org>-<name>-<tag>.img
#
# Must be run from the login node (needs internet + ulimit 512).
# Requires: source mcmicro_env.sh first (sets APPTAINER_CACHEDIR, ulimit 512)
#
# Usage:
#   source mcmicro_env.sh
#   bash prepull_containers.sh

set -euo pipefail

CACHE_DIR="${APPTAINER_CACHEDIR:-/sc/arion/projects/vascbrain/giocrm/.apptainer_cache}"
mkdir -p "$CACHE_DIR"

# Convert docker://org/name:tag -> org-name-tag.img  (Nextflow cache naming)
nxf_img_name() {
  echo "$1" | sed 's|docker://||; s|/|-|g; s|:|-|g'
}

# All containers used by MCMICRO (from config/defaults.yml + nextflow.config)
IMAGES=(
  "docker://ghcr.io/labsyspharm/mcmicro:roadie-2023-10-25"
  "docker://labsyspharm/basic-illumination:1.4.0"
  "docker://labsyspharm/ashlar:1.19.0"
  "docker://labsyspharm/unetcoreograph:2.4.6"
  "docker://labsyspharm/unmicst:2.7.7"
  "docker://labsyspharm/s3segmenter:1.5.6"
  "docker://labsyspharm/quantification:1.6.0"
)

echo "==> Pulling ${#IMAGES[@]} containers to $CACHE_DIR"
echo "    ulimit -u: $(ulimit -u)"
echo ""

for img in "${IMAGES[@]}"; do
  img_file="$(nxf_img_name "$img").img"
  img_path="$CACHE_DIR/$img_file"

  if [ -f "$img_path" ]; then
    echo "  [SKIP] $img_file  (already cached)"
  else
    echo "  [PULL] $img -> $img_file ..."
    apptainer pull "$img_path" "$img"
    echo "  [DONE] $img_file"
  fi
  echo ""
done

echo "==> All containers ready in $CACHE_DIR"
ls -lh "$CACHE_DIR"/*.img 2>/dev/null || echo "(no .img files)"
