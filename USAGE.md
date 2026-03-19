# MCMICRO — Minerva HPC Usage Guide

How to run the MCMICRO pipeline on Mount Sinai Minerva (IBM LSF + Apptainer).

---

## Table of Contents

1. [Repository layout](#repository-layout)
2. [Git workflow — fork strategy](#git-workflow--fork-strategy)
3. [One-time setup on Minerva](#one-time-setup-on-minerva)
4. [Every-session setup](#every-session-setup)
5. [Step 1: Test run (exemplar-001)](#step-1-test-run-exemplar-001)
6. [Step 2a: Production run — A/region_000 (SVS)](#step-2a-production-run--aregion_000-svs)
7. [Step 2b: Production run — FNEL03 (OME-TIFF)](#step-2b-production-run--fnel03-ome-tiff)
8. [Monitoring jobs](#monitoring-jobs)
9. [Expected output structure](#expected-output-structure)
10. [Profiles reference](#profiles-reference)
11. [Resource tuning](#resource-tuning)
12. [Troubleshooting](#troubleshooting)

---

## Repository layout

```
mcmicro/
├── config/nf/
│   ├── minerva.config        # LSF executor + per-process resource limits
│   ├── minerva_wsi.config    # minerva.config + wsi.config (convenience)
│   ├── singularity.config    # Apptainer/Singularity settings
│   └── wsi.config            # Whole-slide image resource overrides
├── nextflow.config           # All profile definitions (minerva, minervaWSI, ...)
├── mcmicro_env.sh            # Source this to load modules + set env vars
├── run_exemplar.sh           # Download and run the test dataset
└── run_FNEL03.sh             # Production run for FNEL03 image
```

---

## Git workflow — fork strategy

This repo is a fork of the upstream labsyspharm pipeline. Custom Minerva configs and
run scripts live on **your fork only** — never pushed to upstream.

### Remote layout

```
origin  → https://github.com/labsyspharm/mcmicro.git   (upstream — never push here)
myfork  → https://github.com/GiorgioRicciardiello/mcmicro  (your fork — push here)
```

On Minerva after cloning your fork, `origin` points to your fork. Add upstream once:

```bash
# On Minerva (one time only)
git remote add upstream https://github.com/labsyspharm/mcmicro.git
```

### Typical edit cycle

```
Windows (edit configs/scripts)
  → git push myfork master
      → Minerva: git pull origin master
```

**On Windows — after editing:**
```bash
git add config/nf/minerva.config config/nf/minerva_wsi.config config/nf/wsi.config \
        nextflow.config mcmicro_env.sh run_exemplar.sh run_FNEL03.sh run_region000.sh USAGE.md
git commit -m "feat: describe your change"
git push myfork master
```

**On Minerva — pull the latest:**
```bash
cd /sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro
git pull origin master
```

### Absorbing upstream updates from labsyspharm

When the upstream pipeline releases a fix or new feature you want:

```bash
# On Windows
git fetch origin               # get upstream changes
git merge origin/master        # merge into your local master
# resolve any conflicts, then:
git push myfork master         # publish merged result to your fork
# On Minerva
git pull origin master
```

### Branch strategy

For config/run script changes use `master` directly — no extra branches needed.
Create a branch only when experimenting with pipeline logic changes you are not
sure you want to keep:

```bash
git checkout -b feature/my-experiment
# ... edit, test ...
git checkout master
git merge feature/my-experiment
git push myfork master
```

---

## One-time setup on Minerva

Run these commands once after cloning the repository on Minerva.

```bash
# SSH to Minerva
ssh riccig01@minerva.hpc.mssm.edu

# Clone from your fork (origin = your fork on Minerva)
cd /sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode
git clone https://github.com/GiorgioRicciardiello/mcmicro mcmicro
cd mcmicro

# Register labsyspharm as upstream so you can pull their updates later
git remote add upstream https://github.com/labsyspharm/mcmicro.git
git remote -v   # should show both origin (your fork) and upstream (labsyspharm)

# Create Apptainer cache and work dirs under projects (persistent, backed up)
mkdir -p /sc/arion/scratch/riccig01/.apptainer_cache
mkdir -p /sc/arion/scratch/riccig01/nf-work
mkdir -p /sc/arion/projects/vascbrain/giocrm/.nextflow

# Confirm your allocation name (update minerva.config if different from acc_vascbrain)
bacct | head -5
```

If `bacct` shows a different allocation name, edit `config/nf/minerva.config` line:
```groovy
clusterOptions = '-P acc_vascbrain'   // <- change to your allocation
```

---

## Every-session setup

Source this at the start of every Minerva session before running anything.

```bash
cd /sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro
source mcmicro_env.sh
```

Expected output:
```
MCMICRO environment loaded:
  java      : openjdk version "21.0.x" ...
  nextflow  : version 25.x.x
  apptainer : apptainer version 1.3.6
  NXF_WORK  : /sc/arion/scratch/riccig01/nf-work
  CACHE     : /sc/arion/scratch/riccig01/.apptainer_cache
```

---

## Step 1: Test run (exemplar-001)

**Run once** to verify containers pull and the pipeline executes end-to-end before
touching real data.

```bash
source mcmicro_env.sh
bash run_exemplar.sh

```

- Downloads exemplar-001 (~600 MB) to `/sc/arion/projects/vascbrain/giocrm/OrionCadasil/test/`
- Runs full MCMICRO pipeline with `-profile minerva,WSI`
- Expected time: 15–30 min
- All containers are cached to `/sc/arion/scratch/riccig01/.apptainer_cache` (reused in future runs)

Check result:
```bash
ls /sc/arion/projects/vascbrain/giocrm/OrionCadasil/test/exemplar-001/
# Should contain: raw/ registration/ segmentation/ quantification/ qc/
```

---

## Step 2a: Production run — A/region_000 (OME-TIFF)

The image is `region_000.ome.tiff` — OME-TIFF is the native format for MCMICRO, no
conversion needed. **Do not move the file**; the script symlinks it into the MCMICRO
input structure so the original data stays untouched.

Actual file layout on Minerva:
```
OrionImagesProcessed/A/region_000/
├── region_000.ome.tiff        ← pipeline input (symlinked, not copied)
├── region_000.h5
├── region_000_coordinates.json
└── region_000_thumbnail.png
```

```bash
source mcmicro_env.sh
bash run_region000.sh
```

The script:
1. Verifies `region_000.ome.tiff` exists at the source path
2. Creates `region_000_run/raw/` and symlinks the image — no copy, no move
3. Runs with `-profile minerva,WSI -resume`

Source image:
```
/sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImagesProcessed/A/region_000/region_000.ome.tiff
```

Outputs land in:
```
/sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImagesProcessed/A/region_000_run/
```

---

## Step 2b: Production run — FNEL03 (OME-TIFF)

```bash
source mcmicro_env.sh
bash run_FNEL03.sh
```

The script:
1. Verifies the source image exists at the expected path
2. Creates the MCMICRO input structure (`FNEL03_CAD001_001/raw/`) with a symlink to the image — no copy
3. Runs `nextflow run` with `-profile minerva,WSI -resume`

Image path used:
```
/sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImages/FNEL03_CAD001_001/
  FNEL03_CAD001_001/FNEL03_CAD001_001_FNEL03_2026_V1_001703.ome.tiff
```

Outputs land in:
```
/sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImages/FNEL03_CAD001_001/
```

---

## Monitoring jobs

MCMICRO submits each pipeline step as a separate LSF job. Monitor with:

```bash
# List all your running/pending jobs
bjobs

# Detailed status of a specific job
bjobs -l JOBID

# Live Nextflow log (run from the directory where you launched nextflow)
tail -f .nextflow.log

# Job stdout/stderr (Nextflow writes these to the work directory)
find /sc/arion/scratch/riccig01/nf-work -name ".command.log" | xargs tail -f

# Cancel all your jobs
bkill 0

# Cancel a specific job
bkill JOBID
```

---

## Expected output structure

After a successful run:

```
FNEL03_CAD001_001/
├── raw/
│   └── FNEL03_CAD001_001_FNEL03_2026_V1_001703.ome.tiff  (symlink)
├── registration/
│   └── FNEL03_CAD001_001_FNEL03_2026_V1_001703.ome.tiff  (stitched/registered)
├── segmentation/
│   ├── cell-states/
│   └── unmicst-*/
│       ├── nucleiRingMask.tif
│       ├── cytoplasmMask.tif
│       └── cellMask.tif
├── quantification/
│   └── FNEL03_CAD001_001_FNEL03_2026_V1_001703.csv       (per-cell intensities)
└── qc/
    └── s3seg/                                              (segmentation thumbnails)
```

---


## Profiles reference

Profiles are combined with commas: `-profile <platform>,<resource>`.

| Profile | Purpose |
|---------|---------|
| `minerva` | LSF executor, Apptainer containers, Minerva resource defaults |
| `minervaWSI` | Same as `minerva,WSI` — convenience shortcut |
| `WSI` | Whole-slide image resource overrides (more RAM for large files) |
| `TMA` | Tissue microarray resource overrides |
| `GPU` | Enable GPU for segmentation |

**For the FNEL03 image (87 GB whole-slide):**
```bash
-profile minerva,WSI
```

---

## Resource tuning

Edit `config/nf/minerva.config` to adjust per-process limits:

```groovy
process {
  executor       = 'lsf'
  queue          = 'premium'
  clusterOptions = '-P acc_vascbrain'   // allocation — verify with: bacct

  // Defaults applied to any process not listed below
  cpus   = 4
  time   = '12h'
  memory = '64G'

  withName: 'segmentation:worker' { cpus = 8; time = '24h'; memory = '128G' }
  withName: s3seg                 { cpus = 6; time = '12h'; memory = '128G' }
  withName: mcquant               {           time = '12h'; memory =  '64G' }
  withName: ashlar                {           time = '6h';  memory =  '64G' }
}
```

**Queues available on Minerva:**
| Queue | Max walltime | Use for |
|-------|-------------|---------|
| `premium` | 144h | Interactive / priority jobs |
| `long` | 168h | Long batch jobs |
| `gpu` | 72h | GPU segmentation |

---

## Troubleshooting

### "java.lang.UnsupportedClassVersionError" or Java 8 errors

```bash
module purge
module load nextflow    # this auto-loads Java 21
java -version           # confirm: openjdk 21
```

### Containers fail to pull — "FATAL ERROR: Failed to create thread"

Root cause: login nodes have `ulimit -u 256` (soft). `mksquashfs` (used by Apptainer
to build SIF files) creates multiple threads and hits this limit.

Fix: `mcmicro_env.sh` raises the soft limit to 512 (hard limit) automatically.
If you sourced it and still see the error, check:

```bash
ulimit -u        # should be 512 after sourcing mcmicro_env.sh
ulimit -Hu       # hard limit — if < 512, contact HPC support
```

If the limit is already at the hard cap, pre-pull containers manually:

```bash
# Pre-pull all containers (run once, takes ~20 min)
source mcmicro_env.sh
bash prepull_containers.sh
```

`prepull_containers.sh` pulls all images to `$APPTAINER_CACHEDIR` using the
exact filename format Nextflow expects (`labsyspharm-name-tag.img`).

**Do NOT run nextflow via `bsub`** — compute nodes have no internet access and
cannot pull containers. Always run `nextflow run` from the login node; it
submits individual pipeline steps to LSF automatically.

### "PENDING" jobs that never start

```bash
bjobs -p               # shows pending reason
bqueues                # check queue availability
# Common cause: allocation name wrong in clusterOptions
bacct | head -5        # get correct allocation name
```

### Pipeline stalls or a step fails

```bash
# Check Nextflow log
tail -100 .nextflow.log | grep -i "error\|fail\|exception"

# Find the failed process work directory
grep "FAILED" .nextflow.log | tail -5
# Navigate to that hash directory and inspect:
cat /sc/arion/scratch/riccig01/nf-work/xx/yyyyyyyy/.command.err
```

### Out of memory for a specific step

Increase memory in `config/nf/minerva.config` for the failing process name (shown in Nextflow log), push, pull, and re-run with `-resume`.

### Resume not working

```bash
# -resume requires the same work directory
# Confirm NXF_WORK is set
echo $NXF_WORK   # must be /sc/arion/scratch/riccig01/nf-work
source mcmicro_env.sh
bash run_FNEL03.sh
```

---

**Last Updated**: 2026-03-19
**Platform**: Mount Sinai Minerva (LSF + Apptainer 1.2.5)
**Pipeline**: MCMICRO (Nextflow 25.x)
