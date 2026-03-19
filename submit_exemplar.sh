#!/usr/bin/env bash
# submit_exemplar.sh
# Submits the exemplar run as an LSF job so Nextflow (and container pulls)
# execute on a compute node rather than the login node.
#
# Usage (from the mcmicro repo directory):
#   source mcmicro_env.sh
#   bash submit_exemplar.sh

MCMICRO_DIR="/sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro"
LOG_DIR="$MCMICRO_DIR/logs"
mkdir -p "$LOG_DIR"

bsub \
  -P acc_vascbrain \
  -q premium \
  -n 4 \
  -R "rusage[mem=16000]" \
  -W 04:00 \
  -J mcmicro_exemplar \
  -o "$LOG_DIR/exemplar_%J.stdout" \
  -e "$LOG_DIR/exemplar_%J.stderr" \
  "cd $MCMICRO_DIR && source mcmicro_env.sh && bash run_exemplar.sh"

echo "==> Exemplar job submitted. Monitor with:"
echo "    wsl ssh minerva11 \"bjobs\""
echo "    wsl ssh minerva11 \"tail -f $LOG_DIR/exemplar_<JOBID>.stdout\""
