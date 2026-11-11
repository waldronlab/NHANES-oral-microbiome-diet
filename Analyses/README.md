# Analyses

This folder contains the Quarto notebooks that reproduce the analyses. This
readme describes how to render them and every option that can be tuned in each.
For the environment and the data layout, see the [main README](../README.md).

## How to render

All notebooks are rendered **from this folder**, with the `quarto` conda
environment described in the [main README](../README.md#quarto-environment):

```bash
cd Analyses
conda activate quarto
quarto render 01-prepare-data.qmd
```

or, without activating the environment:

```bash
conda run --no-capture-output -n quarto quarto render 01-prepare-data.qmd
```

Each render produces an HTML report next to the notebook (e.g. `01-prepare-data.html`)
and writes results to `results/<analysis>/`.

### Order of execution

```
01-prepare-data
 ├── 02-Dirichlet-clustering
 ├── 03-diet-vs-alpha
 └── 04-diet-vs-beta, one render per distance (4) ──> 05-beta-summary
```

  1. `01-prepare-data.qmd`: builds the data object used by all other notebooks
  2. `02-Dirichlet-clustering.qmd`: community types
  3. `03-diet-vs-alpha.qmd`: diet indices vs alpha diversity
  4. `04-diet-vs-beta.qmd`: diet indices vs beta diversity, one distance per render
  5. `05-beta-summary.qmd`: combines the distances of step 4, with FDR across them

### Running jobs in parallel

Wherever possible, run steps as separate jobs at the same time:

  - after step 1, steps 2, 3, and the four distances of step 4 are independent:
    up to 6 jobs at once
  - step 5 runs after all four distances of step 4 have finished

Each distance of step 4 is rendered with `run-beta-distance.sh`, which renders
its own copy of the notebook (`04-diet-vs-beta_<distance>_perm<n>_covperm<n>.qmd`),
so that several distances, or the same distance with different numbers of
permutations, can run in this folder at the same time without overwriting each
other's intermediate files. Do not run several plain
`quarto render 04-diet-vs-beta.qmd` at once in the same folder.

The copy and its `.rmarkdown` intermediate are deleted when the render succeeds,
and kept for debugging when it fails. Once the renders have finished, run
`./clean-beta-copies.sh` to delete any copies left behind (failed renders, or
files restored by OneDrive sync); it keeps the HTML reports and skips copies
whose render is still running.

**On one machine**, in the background with a log file per job:

```bash
conda activate quarto
mkdir -p logs
for distance in Bray-Curtis Canberra unweighted_UniFrac weighted_UniFrac; do
    nohup ./run-beta-distance.sh ${distance} > logs/04-diet-vs-beta_${distance}.log 2>&1 &
done
nohup quarto render 02-Dirichlet-clustering.qmd -P k_communities:15 \
    > logs/02-Dirichlet-clustering.log 2>&1 &

# when all distances have finished
./clean-beta-copies.sh
quarto render 05-beta-summary.qmd
```

Cores add up across jobs: the four distances with `n_cores:4` use 16 to 20
cores (4 permutation workers plus the main R process each), and step 2 uses
`n_workers` more. On a smaller machine, lower `n_cores` or run fewer jobs at
once. With a multithreaded BLAS (e.g. Apple Accelerate or OpenBLAS), limit its
threads per process (`VECLIB_MAXIMUM_THREADS=1` on macOS,
`OPENBLAS_NUM_THREADS=1` on Linux) so that workers do not compete for cores.

**On a cluster**, the repository must sit in the same folder layout as here
(data in `../../` relative to `Analyses/`, see the [main README](../README.md#data))
on a filesystem shared by all nodes, with the `quarto` environment installed.
Example with SLURM, one array task per distance:

```bash
#!/bin/bash
#SBATCH --job-name=diet-vs-beta
#SBATCH --array=0-3
#SBATCH --cpus-per-task=5
#SBATCH --mem=8G
#SBATCH --output=logs/04-diet-vs-beta_%a.log

distances=(Bray-Curtis Canberra unweighted_UniFrac weighted_UniFrac)
conda activate quarto
export OPENBLAS_NUM_THREADS=1
./run-beta-distance.sh ${distances[$SLURM_ARRAY_TASK_ID]} -P n_cores:4
```

Submit it from `Analyses/` with `sbatch`, then submit the summary to run after
all array tasks succeed:

```bash
sbatch --dependency=afterok:<array job id> --wrap "conda activate quarto && ./clean-beta-copies.sh && quarto render 05-beta-summary.qmd"

# for a run with other numbers of permutations, pass the same values to both:
#   ./run-beta-distance.sh ... -P n_permutations:9999
#   quarto render 05-beta-summary.qmd -P n_permutations:9999
```

Request `--cpus-per-task` = `n_cores` + 1. Memory measured on the full data is
about 0.75 GB per permutation worker; reading an NHANES UniFrac matrix needs a
few GB more, so 8 GB per distance with `n_cores:4` leaves some margin.

### Tuning options

Options come in two kinds:

  - **Parameters** (`params` in the YAML header of each notebook): computational
    settings and output folders. Change them from the command line with
    `-P name:value`, without editing the notebook. Several `-P` can be given,
    e.g. `quarto render 04-diet-vs-beta.qmd -P n_permutations:99 -P n_cores:8`.
  - **Analysis settings**: the variables, covariates, and thresholds defining the
    analysis. They are set in the chunk named below in each notebook, and changed
    by editing the notebook, so that the analysis choices are recorded in the code.

## `01-prepare-data.qmd`: prepare data

```bash
quarto render 01-prepare-data.qmd
```

Builds a `SummarizedExperiment` and saves it as `../NHANES_oral_microbiome.se.rda`:

- **assay**: genus counts (DADA2 RB)
- **rowData**: SILVA v123 taxonomy, with missing levels filled with the genus name
- **colData**:
  - alpha diversities (Observed, Faith, Shannon) from NHANES (DADA2 RB, the same feature table as the counts)
  - diet indices from Mukta: HEI-2020 total and components, NOVA groups 1-4, and covariates
  - NOVA subgroups from the raw NOVA files
  - oral health: number of natural teeth, implants, and missing teeth; exhaled nitric oxide

Runtime: a few minutes.

**Parameters**: none.

**Analysis settings**:

| Setting | Value | Where |
|---------|-------|-------|
| Alpha diversity | median of the 10 rarefactions at 10,000 reads | "Alpha diversities" section |
| Diet indices file | `analytic_cleanHEI_NOVA_Mukta_2026_08_19.xlsx` | "Diet scores" section |
| NOVA subgroups | mean over reliable recall days (`day1_ok`, `day2_ok` from Mukta's file) | "NOVA subgroups" section |
| Minimum sequencing depth | more than 10,000 reads per sample | last chunk of "Merge into Summarized Experiment" |

## `02-Dirichlet-clustering.qmd`: community types

```bash
quarto render 02-Dirichlet-clustering.qmd -P k_communities:20
```

Fits Dirichlet Multinomial Mixtures with 1 to `k_communities` communities, and
assigns each sample to a community type (CST).

Runtime: hours for `k_communities:20`. Each model runs on one core, and models
run in parallel, largest first, so the run takes about as long as the model with
the most communities.

**Parameters**:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `k_communities` | 10 | fit models with 1 to `k_communities` communities |
| `n_workers` | 10 | parallel workers (cores), one model each |
| `outdir` | `results/DirichletMultinomial` | output folder |

**Analysis settings**:

| Setting | Value | Where |
|---------|-------|-------|
| Random seed | `1234`, passed to every model | `setup` chunk |
| Genus prevalence filter | at least 10 counts in at least 50 samples | `filter by prevalence and detection` chunk |
| Ambiguous assignments | samples whose best and second-best CST probabilities differ by less than 0.2 are assigned to `CST.Other` | chunk creating `assignments_CST.df` |

**Outputs** in `outdir`:

- `CST_assignments_for_k<k>.xlsx`: assignments and probabilities (`Mixture`), mixture weights (`MixtureWeights`)
- `BestFitPlot.svg`: AIC, BIC, and Laplace by number of communities

## `03-diet-vs-alpha.qmd`: diet indices vs alpha diversity

```bash
quarto render 03-diet-vs-alpha.qmd
```

Linear models of each alpha diversity metric on each diet index, adjusted for
covariates: `alpha ~ diet index + covariates`. Diet indices are standardized
(mean 0, SD 1), so estimates are per 1 SD of the index. Primary models are
survey-weighted; unweighted models are a sensitivity analysis. The rationale is
in the notebook's "Survey weighting" section.

Runtime: ~ 1 min.

**Parameters**:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `outdir` | `results/alpha_diversity` | output folder |

**Analysis settings**, in the `variables` chunk:

| Setting | Default | Meaning |
|---------|---------|---------|
| `alpha_indices` | Observed, Shannon, Faith | outcomes; names are the labels used in tables and plots |
| `diet_indices` | `HEI2020_ALL`, `nova4_propcal`, `nova4_propg` | exposures; add MaPiDS here when available |
| `covariates` | age, sex, race/ethnicity, education, income to poverty ratio, smoking, alcohol, BMI, energy intake, number of natural teeth, NHANES cycle | adjustment set; delete a line to drop a covariate |
| `reference_levels` | e.g. `sex = "Female"`, `raceth = "Non_Hispanic_White"` | reference level of each categorical covariate |
| `use_survey_weights` | `TRUE` | `FALSE` fits unweighted models only |

Fixed choices: dietary day-1 weight (`WTDRD1 / 2`, for 2 combined cycles), design
built on all NHANES 2009-2012 participants and restricted to each model's
complete cases, Benjamini-Hochberg FDR within each alpha diversity metric and
method, across all diet index models and terms (`survey design` and `fit models` chunks).

**Outputs** in `outdir`:

- `alpha_vs_diet_indices.xlsx`: one sheet per alpha diversity metric, with all model terms (diet index and covariates): estimates, 95% CI, p-values, and Benjamini-Hochberg FDR within each metric and method
- `alpha_vs_diet_forest_plot.svg`

## `04-diet-vs-beta.qmd`: diet indices vs beta diversity

```bash
./run-beta-distance.sh Bray-Curtis                      # one distance, 999 permutations
./run-beta-distance.sh Canberra -P n_permutations:9999  # sensitivity analysis with 9,999
```

`quarto render 04-diet-vs-beta.qmd -P distance:Canberra` also works, but only
one such render at a time in this folder (see [Running jobs in parallel](#running-jobs-in-parallel)).

For one distance (`distance` parameter) and each diet index:

- **PERMANOVA**, in two parts:
  - diet index: `distance ~ diet index + Condition(covariates)` (`dbrda` + `anova`),
    only the index is tested, after adjusting for all covariates; same R2 and
    pseudo-F as the index row of `adonis2(by = "margin")`
  - covariates: one `adonis2(distance ~ covariates, by = "margin")`, each
    covariate tested after adjusting for the others (descriptive)
- **Betadisper**: dispersion across quartiles of the diet index
- **PCoA**: first two axes, colored by diet index
- **dbRDA**: ordination constrained to the diet index, with covariates partialled out

Models are unweighted; permutations are restricted within NHANES strata (`SDMVSTRA`).
p-values are not FDR-corrected here for the diet indices: `05-beta-summary.qmd`
does it across all distances.

Runtime: hours per distance with 999 permutations, and about 10 times longer with 9,999. Memory: each NHANES UniFrac
matrix is about 1 GB on disk, and is reduced to the analytic sample after reading.

**Parameters**:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `distance` | `Bray-Curtis` | distance to analyze: `Bray-Curtis`, `Canberra`, `unweighted_UniFrac`, or `weighted_UniFrac` |
| `n_permutations` | 999 | permutations for the diet index PERMANOVA and betadisper; the smallest possible p-value is 1 / (n_permutations + 1), and the Monte Carlo error at p = 0.05 is about ± 0.007 (± 0.002 with 9,999). Use e.g. 99 for a quick test, 9999 as a sensitivity analysis |
| `n_permutations_covariates` | 999 | permutations for the covariate PERMANOVA (descriptive, minimum p-value 0.001) |
| `n_cores` | 4 | cores used for permutations |
| `outdir` | `results/beta_diversity` | output folder; results go to `perm<n_permutations>_covperm<n_permutations_covariates>/<distance>/` |

**Analysis settings**, in the `variables` chunk:

| Setting | Default | Meaning |
|---------|---------|---------|
| `diet_indices` | `HEI2020_ALL`, `nova4_propcal`, `nova4_propg` | exposures |
| `covariates` | same as `03-diet-vs-alpha.qmd` | adjustment set; delete a line to drop a covariate |
| `reference_levels` | same as `03-diet-vs-alpha.qmd` | reference level of each categorical covariate |
| `nhanes_distance_files` | unweighted and weighted UniFrac (DADA2 RB) | pre-calculated NHANES distance matrices; add a file to add a distance |
| `computed_distances` | Bray-Curtis, Canberra | distances computed from the genus table with `vegan::vegdist`; add a method to add a distance |

A new distance must also be added to `distances` in `05-beta-summary.qmd`.

Other settings:

| Setting | Value | Where |
|---------|-------|-------|
| Random seed | `1234`, reset before each test | `setup` chunk |
| Bray-Curtis and Canberra | genus relative abundances, same prevalence filter as `02-Dirichlet-clustering.qmd` (at least 10 counts in at least 50 samples) | `distance` chunk |
| Analytic sample | complete cases for all diet indices and covariates, the same for all distances | `analytic sample` chunk |
| Betadisper groups | quartiles of the diet index, distance to group median | `betadisper` chunk |

**Outputs** in `outdir/perm<n_permutations>_covperm<n_permutations_covariates>/<distance>/`,
e.g. `results/beta_diversity/perm999_covperm999/Bray-Curtis/`. Each number of
permutations has its own folder, so runs for sensitivity analyses do not
overwrite each other:

- `PERMANOVA.xlsx`: diet index tests (`diet_indices`) and the full marginal covariate table (`covariates`)
- `betadisper.xlsx`, `betadisper_boxplots.svg`
- `PCoA.xlsx`, `PCoA_by_diet_index.png`
- `dbRDA.xlsx`, `dbRDA_by_diet_index.png`

The HTML report is `04-diet-vs-beta_<distance>_perm<n>_covperm<n>.html` with `run-beta-distance.sh`.

## `05-beta-summary.qmd`: beta diversity summary across distances

```bash
quarto render 05-beta-summary.qmd
```

Reads the results of every distance for one number of permutations and computes the
Benjamini-Hochberg FDR across all distances and diet indices (12 tests),
separately for PERMANOVA and betadisper. Distances without results are left out
with a warning, so render it again once all distances have finished.

Runtime: seconds.

**Parameters**:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `outdir` | `results/beta_diversity` | folder with the results of `04-diet-vs-beta.qmd` |
| `n_permutations` | 999 | selects the run of `04-diet-vs-beta.qmd` to summarize; use the same value as there |
| `n_permutations_covariates` | 999 | as above |

**Outputs** in `outdir/perm<n_permutations>_covperm<n_permutations_covariates>/`:

- `beta_vs_diet_summary_perm<n>_covperm<n>.xlsx`: diet index PERMANOVA and betadisper with FDR across distances, covariate PERMANOVA (FDR within distance), and dbRDA inertia
