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

  1. `01-prepare-data.qmd`: builds the data object used by all other notebooks
  2. `02-Dirichlet-clustering.qmd`: community types
  3. `03-diet-vs-alpha.qmd`: diet indices vs alpha diversity
  4. `04-diet-vs-beta.qmd`: diet indices vs beta diversity

Steps 2-4 only depend on step 1. Steps 2 and 4 are long and use many cores
(see below): run them one at a time, in the background, with a log file:

```bash
mkdir -p logs
nohup conda run --no-capture-output -n quarto \
    quarto render 02-Dirichlet-clustering.qmd -P k_communities:20 \
    > logs/02-Dirichlet-clustering.log 2>&1 &
```

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

Builds a `SummarizedExperiment` and saves it as `../NHANES_oral_microbiome.se`:

- **assay**: genus counts (DADA2 RB)
- **rowData**: SILVA v123 taxonomy, with missing levels filled with the genus name
- **colData**:
  - alpha diversities (Observed, Faith, Shannon) from NHANES (DADA2 RSV)
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

Runtime: a few minutes.

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
quarto render 04-diet-vs-beta.qmd
```

For each distance and each diet index:

- **PERMANOVA**: `distance ~ covariates + diet index`, terms tested sequentially,
  so the index is tested after adjusting for covariates
- **Betadisper**: dispersion across quartiles of the diet index
- **PCoA**: first two axes, colored by diet index
- **dbRDA**: ordination constrained to the diet index, with covariates partialled out

Models are unweighted; permutations are restricted within NHANES strata (`SDMVSTRA`).

Runtime: hours with 999 permutations. Memory: each NHANES UniFrac matrix is about
1 GB on disk, and is reduced to the analytic sample after reading.

**Parameters**:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `n_permutations` | 999 | permutations for PERMANOVA and betadisper; use e.g. 99 for a quick test |
| `n_cores` | 4 | cores used for permutations |
| `outdir` | `results/beta_diversity` | output folder |

**Analysis settings**, in the `variables` chunk:

| Setting | Default | Meaning |
|---------|---------|---------|
| `diet_indices` | `HEI2020_ALL`, `nova4_propcal`, `nova4_propg` | exposures |
| `covariates` | same as `03-diet-vs-alpha.qmd` | adjustment set; delete a line to drop a covariate |
| `reference_levels` | same as `03-diet-vs-alpha.qmd` | reference level of each categorical covariate |
| `nhanes_distance_files` | unweighted and weighted UniFrac (DADA2 RB) | pre-calculated NHANES distance matrices; add a file to add a distance |

Other settings:

| Setting | Value | Where |
|---------|-------|-------|
| Random seed | `1234`, reset before each test | `setup` chunk |
| Bray-Curtis and Canberra | genus relative abundances, same prevalence filter as `02-Dirichlet-clustering.qmd` (at least 10 counts in at least 50 samples) | `distances` chunk |
| Analytic sample | complete cases for all diet indices and covariates, shared by all distances | `analytic sample` chunk |
| Betadisper groups | quartiles of the diet index, distance to group median | `betadisper` chunk |

**Outputs** in `outdir`:

- `beta_vs_diet_summary.xlsx`: PERMANOVA, betadisper, and dbRDA results across distances
- one subfolder per distance (`Bray-Curtis/`, `Canberra/`, `unweighted_UniFrac/`, `weighted_UniFrac/`) with:
  - `PERMANOVA.xlsx`: full PERMANOVA tables, one sheet per diet index
  - `betadisper.xlsx`, `betadisper_boxplots.svg`
  - `PCoA.xlsx`, `PCoA_by_diet_index.png`
  - `dbRDA.xlsx`, `dbRDA_by_diet_index.png`
