[Link to repo on OneDrive, which includes data](https://cuny907-my.sharepoint.com/:f:/r/personal/levi_waldron56_login_cuny_edu/Documents/data/NHANES-microbiome/NHANES-oral-microbiome-diet?d=w5e4e7eae95d94983adedfe3359e7cf25&csf=1&web=1&e=1NYPy1)

# Diet quality, ultra-processed foods, and the oral microbiome in NHANES 2009-2012

Analyses of the oral microbiome using NHANES 2009-2010 and 2011-2012.

**Overall hypothesis**: the oral microbiome modifies the health outcomes of diet.
For each diet index (HEI-2020, ultra-processed foods by calories and by grams,
and MaPiDS once available), we test:

  1. alpha diversity ~ diet index + covariates
  2. beta diversity ~ diet index + covariates (PERMANOVA, betadisper, PCoA, dbRDA)
  3. whether oral community types (Dirichlet Multinomial Mixtures) modify the
     association between diet and health outcomes

This repository contains the code to reproduce the analyses. The analyses are
Quarto notebooks in `Analyses/`, described in [`Analyses/README.md`](Analyses/README.md).
This readme gives a broader view of the repository, with a focus on setting up
the environment and the data needed to reproduce the analyses.

## Environment setup

All analyses run on a local workstation (tested on macOS with 14 cores and 36 GB
of memory). To aid reproducibility, all analyses are run from the command line.

We use `conda` for environment management due to its ease of setup, its
cross-platform compatibility, and the portability of environment specifics.
To install conda, visit the [conda website](https://docs.conda.io/projects/conda/en/latest/user-guide/install/index.html).

Once installed, make sure all necessary channels are available

```bash
conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge

conda config --set channel_priority strict
```

### `quarto` environment

```bash
conda create -n quarto \
    -c conda-forge \
    -c bioconda \
    quarto \
    r-base=4.6.1 \
    r-biocmanager \
    r-knitr \
    r-rmarkdown \
    r-tidyverse \
    r-haven \
    r-openxlsx2 \
    r-data.table \
    r-broom \
    r-furrr \
    r-survey \
    r-vegan \
    r-patchwork \
    r-svglite \
    bioconductor-summarizedexperiment \
    bioconductor-mia \
    bioconductor-dirichletmultinomial

# r-haven: read NHANES .xpt files (01-prepare-data, 03-diet-vs-alpha)
# r-furrr, bioconductor-dirichletmultinomial: Dirichlet Multinomial Mixtures (02-Dirichlet-clustering)
# r-survey: survey-weighted models (03-diet-vs-alpha)
# r-vegan, r-data.table: beta diversity and NHANES distance matrices (04-diet-vs-beta)

conda activate quarto

# specify an environment-bound library for package management and loading in R
echo -e ".libPaths('${CONDA_PREFIX}/lib/R/library')" >> ${CONDA_PREFIX}/lib/R/etc/Rprofile.site
```

Without conda, the notebooks also render with the `quarto` bundled in RStudio
(`/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto` on macOS),
provided the R packages above are installed.

## Data

The data are not part of this repository. They live in the parent folder of the
repository (the shared OneDrive folder `NHANES-microbiome`), and the notebooks
read them with relative paths (`../../`), so the layout must be
(every file, its checksum, and the contents of the analysis object are described
in [`DATA_MANIFEST.md`](DATA_MANIFEST.md)):

```
NHANES-microbiome/
├── NHANES-oral-microbiome-diet/        # this repository
├── microbiome-data/                    # NHANES oral microbiome files (dada2rb-* used)
├── 2009-2010/                          # NHANES 2009-2010 .xpt files (DEMO, DR1TOT, OHXDEN, ENX, ...)
├── 2011-2012/                          # NHANES 2011-2012 .xpt files
├── diet-indices-from-Mukta/            # HEI-2020 and NOVA groups, plus covariates
│   └── analytic_cleanHEI_NOVA_Mukta_2026_08_19.xlsx
├── NOVA food processing files/         # NOVA groups and subgroups per recall day
│   └── nh0910.day[12].nova.v20250131.csv, nh1112.day[12].nova.v20250131.csv
└── MAPiDs/                             # MaPiDS specification (score not yet computed)
```

  - **Oral microbiome**: NHANES 2009-2012 oral rinse 16S rRNA data, as released by
    CDC (see `OralMicrobiomeDataDocumentation-508.pdf`). We use genus counts from the
    DADA2 RB pipeline, alpha diversities, and the pre-calculated UniFrac distance
    matrices (the public release has no phylogenetic tree). The distance matrices
    are about 1 GB each.
  - **NHANES questionnaire, examination, and dietary files**: downloaded from the
    CDC NHANES website into the `2009-2010/` and `2011-2012/` folders.
  - **Diet indices**: HEI-2020 (total and components) and NOVA groups 1-4 were
    computed by Mukta, with the analytic covariates (demographics, smoking,
    alcohol, BMI, energy intake, survey design variables and weights).

## Run analyses (in Analyses)

Each notebook is rendered from the `Analyses/` folder with the `quarto`
environment. [`Analyses/README.md`](Analyses/README.md) documents each notebook,
its runtime, and its tuning options.

```bash
cd Analyses
conda activate quarto
quarto render 01-prepare-data.qmd
quarto render 02-Dirichlet-clustering.qmd -P k_communities:20
quarto render 03-diet-vs-alpha.qmd
for distance in Bray-Curtis Canberra unweighted_UniFrac weighted_UniFrac; do
    ./run-beta-distance.sh ${distance}
done
./clean-beta-copies.sh   # delete any per-distance notebook copies left behind
quarto render 05-beta-summary.qmd
```

Steps 2, 3, and each distance of step 4 can run as separate jobs at the same
time, on one machine or on a cluster: see
[Running jobs in parallel](Analyses/README.md#running-jobs-in-parallel).

### How it works

- `01-prepare-data.qmd` builds a `SummarizedExperiment` with genus counts
  (assay), taxonomy (rowData), and all metadata (colData), and saves it as
  `NHANES_oral_microbiome.se.rda` at the root of the repository. All other notebooks
  load this object.
- Each notebook writes its results to its own folder in `Analyses/results/`,
  set by the `outdir` parameter.
- Analysis choices are set in a "Variables" chunk at the top of each analysis
  notebook (outcomes, diet indices, covariates, reference levels): to drop a
  covariate, delete its line. Notebook parameters (`params` in the YAML header)
  set computational choices, and can be changed from the command line with
  `-P name:value`.
- Alpha diversity models are survey-weighted, with unweighted models as a
  sensitivity analysis. Beta diversity and community type analyses are
  unweighted, with permutations restricted within NHANES strata. The rationale
  is written in the "Survey weighting" section of `03-diet-vs-alpha.qmd`.

### Order of execution

Later steps read the results of earlier ones, so run them in this order:

  1. Prepare data (`01-prepare-data.qmd`)
  2. Dirichlet Multinomial Mixtures community types (`02-Dirichlet-clustering.qmd`)
  3. Diet indices vs alpha diversity (`03-diet-vs-alpha.qmd`)
  4. Diet indices vs beta diversity (`04-diet-vs-beta.qmd`), one render per distance
  5. Beta diversity summary across distances (`05-beta-summary.qmd`)

Steps 2-4 only depend on step 1, and can run in parallel. Step 5 needs all
distances of step 4.

### Steps that need extra time or resources

- `02-Dirichlet-clustering.qmd` fits one model per number of communities and
  takes hours for `k_communities:20`. Models run in parallel, one per worker
  (`-P n_workers:10` by default), and the slowest single model sets the run time.
- `04-diet-vs-beta.qmd` analyzes one distance per render. It reads the NHANES
  UniFrac matrices (about 1 GB each) and runs 999 permutations per diet index
  test and for the covariate table (9,999 as a sensitivity analysis) on about 5,000 samples; permutations use
  `-P n_cores:4` cores by default, so each distance can take hours.

Run them as background or cluster jobs with a log file (see
[`Analyses/README.md`](Analyses/README.md#running-jobs-in-parallel)), keeping
the total cores of the jobs running at once within the machine's cores.

### Not yet implemented

- MaPiDS diet index (specification in `MAPiDs/`, score not yet computed)
- Health outcomes and community types as modifiers of the diet-outcome
  association (requires the NCHS Linked Mortality Files, not yet downloaded)
