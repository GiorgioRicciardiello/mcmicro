[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) ![Build Status](https://github.com/labsyspharm/mcmicro/actions/workflows/ci.yml/badge.svg)

# MCMICRO: Multiple-choice microscopy pipeline

MCMICRO is an end-to-end processing pipeline for multiplexed whole slide imaging and tissue microarrays developed at the [HMS Laboratory of Systems Pharmacology](https://hits.harvard.edu/the-program/laboratory-of-systems-pharmacology/about/). It comprises stitching and registration, segmentation, and single-cell feature extraction. Each step of the pipeline is containerized to enable portable deployment across an array of compute environments.

The pipeline is described in [Nature Methods](https://www.nature.com/articles/s41592-021-01308-y). Please see [mcmicro.org](https://mcmicro.org/) for documentation, tutorials, benchmark datasets and more.

## Orion Colocalization Quantification (Minerva HPC)

### Data Structure Required

```
/sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImagesProcessed/
├── A/region_000_run/
│   ├── raw/region_000.ome.tiff          (30-channel WSI)
│   ├── markers.csv                       (channel metadata)
├── B/region_000_run/
│   ├── raw/region_000.ome.tiff
│   ├── markers.csv
... (samples C through K)
```

### Execution Order

#### 1. Single Sample Run
```bash
cd /sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro
bash run_colocalization.sh /sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImagesProcessed/A/region_000_run
```

**Files checked:**
- `$SAMPLE_DIR/markers.csv` — REQUIRED
- `$SAMPLE_DIR/raw/*.tiff` — REQUIRED (mcmicro reads)

**Script:** `run_colocalization.sh`
- Line 49-61: Validates `SAMPLE_DIR` argument and markers.csv exist
- Line 86-95: Runs mcmicro pipeline (registration → quantification)
- Line 113-124: Locates `quantification/cell*.csv` output
- Line 139-146: Calls `colocalization_analysis.py`

**Outputs:**
```
$SAMPLE_DIR/colocalization/
├── pearson_matrix.csv
├── spearman_matrix.csv
├── manders_m1_matrix.csv
├── manders_m2_matrix.csv
└── colocalization_heatmaps.png
```

#### 2. Batch Run (All Samples A-K)
```bash
cd /sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro
bsub < run_all_colocalization.sh
```

**Script:** `run_all_colocalization.sh`
- Line 44: Reads `REGIONS` env var (default: A B C D E F G H I J K)
- Line 55: Sets `SAMPLE_DIR="$BASE_DIR/$LETTER/region_000_run"` for each sample
- Line 63: Verifies `$SAMPLE_DIR` exists
- Line 70-74: Verifies `$SAMPLE_DIR/markers.csv` exists
- Line 80: Calls `run_colocalization.sh "$SAMPLE_DIR"` for each sample

**LSF directives (lines 5-12):**
- Account: `acc_vascbrain`
- Queue: `long` (72-hour timeout)
- Memory: 16 GB per task
- Logs: `/sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro/logs/coloc_batch_*.out|err`

**Run subset:**
```bash
REGIONS="B C D" bsub < run_all_colocalization.sh
```

### Configuration

**`params.yml`** (mcmicro config)
- `start-at: registration` — begins at registration stage
- `stop-at: quantification` — ends after quantification
- `segmentation-channel: 1` — Hoechst (channel 1)
- `mcquant` options: `--masks cell*.tif nucleiMask.tif --intensity_props median_intensity`

### Python Post-Processing

**`colocalization_analysis.py`**

Input:
- `--input <CSV>` — mcquant output `quantification/cell*.csv`
- `--output-dir <DIR>` — write to `colocalization/`
- `--markers-csv <CSV>` — sample markers.csv

Output metrics (per channel pair):
- Pearson correlation coefficient
- Spearman rank correlation
- Manders M1 overlap (intensity of ch-i in ch-j > 0 regions)
- Manders M2 overlap (intensity of ch-j in ch-i > 0 regions)
- Heatmap visualization (2×2 panel PNG)

### Troubleshooting

**"markers.csv not found" → Script skips sample**
- Verify: `ls /sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImagesProcessed/A/region_000_run/markers.csv`
- If missing: Copy from `config/markers/orion_20ch_panel.csv`

**"quantification/cell*.csv not found" → Pipeline stage failure**
- Check log: `tail -f logs/batch/coloc_A.log`
- Check nextflow work dir: `ls /sc/arion/scratch/riccig01/nf-work/`

**"Directory not found" → Path mismatch**
- Verify structure: `ls -la /sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImagesProcessed/A/`
- Expected: `region_000_run/` subdirectory present

### Quick Start

1. Verify environment: `source mcmicro_env.sh`
2. Test single sample: `bash run_colocalization.sh /sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImagesProcessed/A/region_000_run`
3. Launch batch (LSF): `bsub < run_all_colocalization.sh`
4. Monitor: `bjobs` then `tail -f logs/batch/coloc_A.log`
5. Collect results: `find OrionImagesProcessed -name "*colocalization_heatmaps.png"`

---

## Original MCMICRO Docs

### Quick start

1. [Install](https://mcmicro.org/tutorial/installation.html) nextflow and Docker. Verify installation with `nextflow run hello` and `docker run hello-world`
1. [Download](http://mcmicro.org/datasets/) exemplar data: `nextflow run labsyspharm/mcmicro/exemplar.nf --name exemplar-001`
1. [Run](https://mcmicro.org/tutorial/tutorial.html) mcmicro on the exemplar: `nextflow run labsyspharm/mcmicro --in exemplar-001`

## Funding

This work is supported by the following:

* NCI grants U54-CA22508U2C-CA233262 and U2C-CA233280
* *NIH grant 1U54CA225088: Systems Pharmacology of Therapeutic and Adverse Responses to Immune Checkpoint and Small Molecule Drugs* 
* Ludwig Center at Harvard Medical School and the Ludwig Cancer Research Foundation
* Denis Schapiro was supported by the University of Zurich BioEntrepreneur-Fellowship (BIOEF-17-001) and a Swiss National Science Foundation Early Postdoc Mobility fellowship (P2ZHP3_181475). He is currently a [Damon Runyon Quantitative Biology Fellow](https://www.damonrunyon.org/news/entries/5551/Damon%20Runyon%20Cancer%20Research%20Foundation%20awards%20new%20Quantitative%20Biology%20Fellowships)
* NCI grant [1U24CA274494-01](https://reporter.nih.gov/project-details/10525124): Multi-Consortia Coordinating Center (MC2 Center) for Cancer Biology: Building Interdisciplinary Scientific Communities, Coordinating Impactful Resource Sharing, and Advancing Cancer Research

[Contributors](https://mcmicro.org/community/)
