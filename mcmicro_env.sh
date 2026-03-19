#!/usr/bin/env bash
# mcmicro_env.sh
# Source this file before running any MCMICRO command on Minerva.
# Usage: source mcmicro_env.sh
#
# To load automatically on every login, add to ~/.bashrc:
#   source /sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro/mcmicro_env.sh

module purge
module load nextflow    # also loads java/21
module load apptainer

# Container image cache — use scratch to avoid filling home quota
export APPTAINER_CACHEDIR=/sc/arion/scratch/giocrm/.apptainer_cache
export SINGULARITY_CACHEDIR=/sc/arion/scratch/giocrm/.apptainer_cache

# Nextflow work and home directories on scratch
export NXF_WORK=/sc/arion/scratch/giocrm/nf-work
export NXF_HOME=/sc/arion/scratch/giocrm/.nextflow

mkdir -p "$APPTAINER_CACHEDIR" "$NXF_WORK" "$NXF_HOME"

echo "MCMICRO environment loaded:"
echo "  java      : $(java -version 2>&1 | head -1)"
echo "  nextflow  : $(nextflow -version 2>&1 | grep version | xargs)"
echo "  apptainer : $(apptainer --version)"
echo "  NXF_WORK  : $NXF_WORK"
echo "  CACHE     : $APPTAINER_CACHEDIR"
