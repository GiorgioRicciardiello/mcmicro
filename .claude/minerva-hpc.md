---
type: "reference"
slug: "minerva-hpc"
resource_type: "HPC"
scheduler: "LSF"
institution: "Icahn School of Medicine at Mount Sinai"
created: "2026-03-03"
updated: "2026-03-19"
---

# Minerva -- HPC Operations Center

Parent: [[mount-sinai]]

This is the single source of truth for all HPC-related workflows. Read this before any HPC project interaction.

We are part of two different HPC clusters:
- vascbrain
- sleeplab/ActigraphyUKBB

---

## Dual-Location Workflow

Projects with HPC compute exist in two places. **Which location is authoritative depends on the artifact class:**

| Artifact                                   | Source of Truth | Location                                         | Sync Mechanism                                           |
|--------------------------------------------| --------------- |--------------------------------------------------| -------------------------------------------------------- |
| **Code** (src, configs, tests)             | Local           | `~/projects/Elahi_Lab/<project>/`                | `git push` local -> `git pull` on Minerva                |
| **DataVascbrain** (input files, splits)    | Minerva         | `/sc/arion/projects/vascbrain/giocrm/<project>/` | Never leaves HPC (too large)                             |
| **DataSleepLab** (input files, splits)     | Minerva         | `/sc/arion/projects/sleeplab/ActigraphyUKBB/Data` | Never leaves HPC (too large)                             |
| **Results** (models, metrics, logs, plots) | Minerva         | same as data                                     | `rsync` to local only when needed for review/publication |
| **Environments** (venv, conda)             | Minerva         | `/sc/arion/work/riccig01/` or project-local      | Defined by lockfile in code; rebuilt on HPC              |

### Decision rule

Before running any command, ask: **"Is this a code operation or a data/results operation?"**

- **Code** (edit, test, commit, lint): run **locally** against `the current working directory project`. Always confirm if we are in the current working directory.
- **Data/results** (inspect, submit jobs, check output, monitor): run on **Minerva** via `wsl ssh minerva11 "<cmd>"`
- **Deploy code to HPC**: `git push` locally, then `wsl ssh minerva11 "cd <project> && git pull"`

### Common error patterns

| Mistake                             | Symptom                          | Fix                                            |
| ----------------------------------- | -------------------------------- |------------------------------------------------|
| Read local results assuming current | Stale metrics, missing runs      | Always read results via `ssh minerva11`         |
| Edit code on Minerva directly       | Diverged repos, lost changes     | Edit locally, push, pull on HPC                |
| Run tests on Minerva                | Slow, missing dev deps           | Run tests locally; HPC has production env only |
| Forget `git pull` on HPC after push | Old code runs, confusing results | Always push+pull as atomic deploy step         |

---

## Project Registry

### vascbrain — OrionCadasil (MCMICRO imaging pipeline)

| Item | Value |
|------|-------|
| Local working dir | `C:\Users\riccig01\Documents\vascbrain\OrionImages\mcmicro` |
| Minerva project root | `/sc/arion/projects/vascbrain/giocrm/OrionCadasil/` |
| Minerva code dir | `/sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro` |
| Minerva image data | `/sc/arion/projects/vascbrain/giocrm/OrionCadasil/OrionImagesProcessed/` |
| Allocation | `acc_vascbrain` |
| Scheduler | LSF (`premium` queue for pipeline jobs) |
| Container runtime | Apptainer (successor to Singularity) |
| Apptainer cache | `/sc/arion/scratch/giocrm/.apptainer_cache` |
| Nextflow work dir | `/sc/arion/scratch/giocrm/nf-work` |
| Nextflow home | `/sc/arion/scratch/giocrm/.nextflow` |

**Git remotes (local Windows repo):**

| Remote | URL | Purpose |
|--------|-----|---------|
| `origin` | `https://github.com/labsyspharm/mcmicro.git` | Upstream — never push here |
| `myfork` | `https://github.com/GiorgioRicciardiello/mcmicro` | Your fork — push all changes here |

**Git remotes (Minerva clone):**

| Remote | URL | Purpose |
|--------|-----|---------|
| `origin` | `https://github.com/GiorgioRicciardiello/mcmicro` | Your fork — pull from here |
| `upstream` | `https://github.com/labsyspharm/mcmicro.git` | labsyspharm — fetch updates only |

**Deploy cycle:**
```bash
# Windows: edit → commit → push
git push myfork master

# Minerva: pull (via WSL tunnel)
wsl ssh minerva11 "cd /sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro && git pull origin master"
```

**Image inventory (OrionCadasil):**

| Sample | Path on Minerva | Format | Run script |
|--------|-----------------|--------|------------|
| A / region_000 | `OrionImagesProcessed/A/region_000/region_000.ome.tiff` | OME-TIFF | `run_region000.sh` |
| FNEL03 | `OrionImages/FNEL03_CAD001_001/.../FNEL03_CAD001_001_FNEL03_2026_V1_001703.ome.tiff` | OME-TIFF | `run_FNEL03.sh` |

---

### vascbrain — default allocation

Default HPC project root: `/sc/arion/projects/vascbrain/giocrm/`
Default allocation: `acc_vascbrain`

### sleeplab

Default HPC project root: `/sc/arion/projects/sleeplab/ActigraphyUKBB/`
Default allocation: `acc_sleeplab`

---

## SSH Tunnel (Claude Code Access)

**Runtime: WSL2 Ubuntu** — ControlMaster is managed from WSL, not Git Bash.

> **Why not Git Bash?** OpenSSH on Windows/MINGW64 creates the socket but session
> multiplexing fails at runtime (`mux_client_request_session: read from master failed:
> Connection reset by peer`). ControlMaster works correctly on Linux — use WSL2 Ubuntu.

### One-time WSL SSH config setup

Inside WSL (`wsl` from any terminal):

```bash
# Create SSH config in WSL
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat > ~/.ssh/config << 'EOF'
Host minerva11
    HostName          minerva11.hpc.mssm.edu
    User              riccig01
    ControlMaster     auto
    ControlPath       ~/.ssh/cm_%C
    ControlPersist    4h
    ServerAliveInterval 60
    ServerAliveCountMax 5
    ForwardAgent      no

Host minerva
    HostName          minerva11.hpc.mssm.edu
    User              riccig01
    ControlMaster     auto
    ControlPath       ~/.ssh/cm_%C
    ControlPersist    4h
    ServerAliveInterval 60
    ServerAliveCountMax 5
    ForwardAgent      no
EOF
chmod 600 ~/.ssh/config
```

### Session startup protocol

1. Open a terminal and enter WSL: `wsl`
2. Run `ssh minerva11` — enter Sinai password + Microsoft Authenticator code **once**
   → master connection and socket created at `~/.ssh/cm_<hash>`
3. Leave that WSL terminal open (master process runs here)
4. Verify tunnel: `ssh -O check minerva11` → should print `Master running (pid=...)`
5. All subsequent `ssh minerva11 "<cmd>"` reuse the socket — no MFA prompt

Tunnel persists 4h after the last client disconnects.

### Check tunnel from Claude Code (Git Bash)

Claude Code runs in Git Bash but can invoke WSL commands:

```bash
wsl ssh -O check minerva11        # check master is alive
wsl ssh minerva11 "hostname"      # run a command through the tunnel
wsl ssh minerva11 "bjobs"         # check LSF jobs
```

If tunnel is down: `wsl ssh minerva11` in a separate terminal to re-authenticate.

### Windows SSH config (Git Bash — reference only)

`C:\Users\riccig01\.ssh\config` also has ControlMaster entries for `minerva11`/`minerva`
but these are **not used for tunneling** — only for direct Git Bash SSH if needed.
All tunneled HPC commands go through `wsl ssh minerva11 "<cmd>"`.

---

## Access

- Host: `minerva11.hpc.mssm.edu`
- User: `riccig01`
- Auth: SSH with MFA (Microsoft Authenticator)
- Login nodes: standard login nodes at `minerva11.hpc.mssm.edu`
- Support: HPC help desk (see Minerva docs)
- Docs: https://labs.icahn.mssm.edu/minervalab/documentation/

## Filesystem

| Path                                                 | Quota               | Backup | Purge     | Use                              |
|------------------------------------------------------| ------------------- | ------ | --------- | -------------------------------- |
| `/hpc/users/riccig01/`                               | standard home quota | yes    | no        | home directory                   |
| `/sc/arion/work/riccig01/`                           | work quota          | no     | no        | singularity cache, workflow dirs |
| `/sc/arion/scratch/riccig01/`                        | large               | no     | yes (90d) | temporary job files              |
| `/sc/arion/scratch/giocrm/`                          | large               | no     | yes (90d) | mcmicro NXF_WORK + Apptainer cache |
| `/sc/arion/projects/vascbrain/giocrm/`               | project quota       | yes    | no        | project data (default)           |
| `/sc/arion/projects/sleeplab/ActigraphyUKBB/giocrm/` | project quota       | yes    | no        | project data (default)           |

- Check quota: `myquota` or `lfs quota -u riccig01 /sc/arion/`
- Archival: contact hpchelp for archive requests
- Transfer: `rsync` or `scp` to/from login nodes; Globus for large transfers

## LSF Scheduler

### Commands

| Command | Purpose |
|---------|---------|
| `bsub` | Submit a job |
| `bjobs` | List running/pending jobs |
| `bkill <jobid>` | Kill a job |
| `bhist` | Job history |
| `bqueues` | List available queues |
| `lsload` | View node load |
| `bpeek <jobid>` | Preview stdout of running job |

### Queues

| Queue | Max Walltime | Notes |
|-------|-------------|-------|
| express | 12h | Short jobs, fast turnaround |
| premium | 144h (6d) | Standard long-running jobs — default for MCMICRO |
| long | 336h (14d) | Extended runs |
| interactive | varies | Interactive sessions |
| gpu | varies | GPU jobs (H100, L40S, A100, V100) |
| gpuexpress | 30min | Quick GPU testing |

- Default memory: 4GB per slot (always specify `-R "rusage[mem=X000]"` -- unit is MB, not GB)
- Walltime format: `HH:MM` (e.g., `-W 12:00`)
- Required flags: `-P <account>` for all jobs
- Default allocation: `acc_vascbrain`

## Nextflow / MCMICRO Operations

### One-time setup on Minerva

```bash
cd /sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode
git clone https://github.com/GiorgioRicciardiello/mcmicro mcmicro
cd mcmicro
git remote add upstream https://github.com/labsyspharm/mcmicro.git
```

### Every-session setup

```bash
cd /sc/arion/projects/vascbrain/giocrm/OrionCadasil/ProjectCode/mcmicro
source mcmicro_env.sh   # loads nextflow + apptainer, sets NXF_WORK / cache dirs
```

### Run scripts

| Script | Image | Profile |
|--------|-------|---------|
| `bash run_exemplar.sh` | exemplar-001 (test dataset) | `minerva,WSI` |
| `bash run_region000.sh` | A/region_000.ome.tiff | `minerva,WSI` |
| `bash run_FNEL03.sh` | FNEL03_CAD001_001.ome.tiff | `minerva,WSI` |

Always `source mcmicro_env.sh` before any run script.

### Monitoring Nextflow jobs

```bash
bjobs                        # list LSF jobs submitted by Nextflow
tail -f .nextflow.log        # live pipeline log
bjobs -p                     # see why jobs are PENDING
bacct | head -5              # confirm allocation name
```

### Profiles reference

| Profile | Purpose |
|---------|---------|
| `minerva` | LSF + Apptainer, standard resource limits |
| `minerva,WSI` | LSF + Apptainer + WSI memory overrides (230G for seg/s3seg) |
| `minervaWSI` | Shortcut for `minerva,WSI` |

Full details: see `USAGE.md` in the mcmicro repo root.

## Job Templates

### Interactive session

```bash
bsub -P acc_vascbrain \
     -q interactive \
     -n 2 \
     -R "rusage[mem=8000]" \
     -W 04:00 \
     -Is bash
```

### Batch script

```bash
#!/bin/bash
#BSUB -P acc_vascbrain
#BSUB -q premium
#BSUB -n 4
#BSUB -R "rusage[mem=16000]"
#BSUB -W 24:00
#BSUB -J job_name
#BSUB -o logs/%J_stdout.log
#BSUB -e logs/%J_stderr.log

module load anaconda3
conda activate myenv

python script.py
```

### GPU job (single GPU)

```bash
#!/bin/bash
#BSUB -P acc_vascbrain
#BSUB -q gpu
#BSUB -n 4
#BSUB -R "rusage[mem=32000]"
#BSUB -gpu "num=1:mode=exclusive_process"
#BSUB -W 24:00
#BSUB -J gpu_job
#BSUB -o logs/%J_stdout.log
#BSUB -e logs/%J_stderr.log

module load cuda
singularity exec --nv /path/to/container.sif python train.py
```

## Environment Management

**Module system**: Lmod (`module avail`, `module load <name>`)

```bash
module load nextflow        # also loads java/21 — required for MCMICRO
module load apptainer       # container runtime for MCMICRO
module load anaconda3       # load conda for Python projects
module load R/4.x.x         # load R module
```

**Conda best practices:**
- Install envs to `/sc/arion/work/riccig01/` to avoid home quota issues
- Use `conda env create -f environment.yml` for reproducible envs
- Pin versions in `environment.yml` for HPC runs

**Apptainer (Singularity successor):**
- Cache dir for mcmicro: `/sc/arion/scratch/giocrm/.apptainer_cache`
- Set via `mcmicro_env.sh` (sets both `APPTAINER_CACHEDIR` and `SINGULARITY_CACHEDIR`)
- Pull from Docker Hub: `apptainer pull docker://image:tag`
- Bind mounts: `-B /sc/arion/projects/vascbrain/giocrm/:/data`

## Resource Inventory

GPU fleet available on Minerva:

| GPU | Count | Notes |
|-----|-------|-------|
| H100 | 236 | Highest priority via `gpu` queue |
| L40S | 32 | Good for inference workloads |
| A100 | 40 | Multi-GPU training |
| V100 | 48 | Legacy GPU nodes |

CPU nodes: standard compute nodes accessible via `express`, `premium`, `long` queues.

## Best Practices

- Always specify `-P <account>` -- jobs without an account will be rejected. Default: `acc_vascbrain`
- Specify memory explicitly; default 4GB is insufficient for most bioinformatics tasks
- Use scratch for intermediate files; clean up after jobs complete (90-day purge policy)
- Store large datasets and results in `/sc/arion/projects/vascbrain/giocrm/`
- Use `apptainer`/`singularity` containers for reproducibility -- avoid per-node software installs
- Test with a short `express` job before submitting long `premium`/`long` jobs
- Log job IDs and parameters; use `bhist` to retrieve completed job metadata
- For MCMICRO: always `source mcmicro_env.sh` before any `nextflow run` or run script
- For R jobs: load the appropriate R module or use a conda/singularity environment with pinned packages
- For Python jobs: prefer conda environments with `environment.yml` committed to the repo