#!/usr/bin/env bash
# mcmicro_env.sh
# Source this file before running any MCMICRO command on Minerva.
# Usage: source mcmicro_env.sh
#
# To load automatically on every login, add to ~/.bashrc:
#   source /sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro/mcmicro_env.sh

module purge
module load nextflow    # also loads java/21
module load apptainer/1.2.5

# Raise process/thread limit so mksquashfs (used by apptainer) can create threads.
# Login nodes default to ulimit -u 256 (soft); hard limit is 512.
ulimit -u 512 2>/dev/null || true

# Container image cache — scratch is fine (90-day purge; re-pull if evicted)
# Use /sc/arion/scratch/riccig01/ — user-owned, large quota
export APPTAINER_CACHEDIR=/sc/arion/scratch/riccig01/.apptainer_cache
export SINGULARITY_CACHEDIR=/sc/arion/scratch/riccig01/.apptainer_cache

# Nextflow intermediate work files — scratch (temp, large, safe to lose)
export NXF_WORK=/sc/arion/scratch/riccig01/nf-work
export NXF_HOME=/sc/arion/scratch/riccig01/.nextflow

mkdir -p "$APPTAINER_CACHEDIR" "$NXF_WORK" "$NXF_HOME"

echo "MCMICRO environment loaded:"
echo "  java      : $(java -version 2>&1 | head -1)"
echo "  nextflow  : $(nextflow -version 2>&1 | grep version | xargs)"
echo "  apptainer : $(apptainer --version)"
echo "  NXF_WORK  : $NXF_WORK"
echo "  CACHE     : $APPTAINER_CACHEDIR"
