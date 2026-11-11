# Data manifest

This manifest describes every data file the analyses read or write: where it
lives, where it comes from, what it contains, and whether it is tracked in git.

**No data are tracked in git.** The repository tracks code and documentation
only (see `.gitignore`). All data live in the shared OneDrive folder
`NHANES-microbiome/`, the parent folder of this repository, and the notebooks
read them with paths relative to `Analyses/`.

Checksums (SHA-256), sizes, and the object summary below were recorded on
2026-11-11 from the files then in OneDrive. See [Verify the inputs](#verify-the-inputs)
to check that your copies match.

## Overview

| Data | Location (from the repository root) | Tracked | Made by |
|------|-------------------------------------|---------|---------|
| Analysis object `NHANES_oral_microbiome.se.rda` | `./` | no | `01-prepare-data.qmd` |
| NHANES oral microbiome release | `../microbiome-data/` | no | CDC/NCHS |
| NHANES questionnaire, exam, and dietary files | `../2009-2010/`, `../2011-2012/` | no | CDC/NCHS |
| HEI-2020, NOVA groups, and covariates | `../diet-indices-from-Mukta/` | no | Mukta |
| NOVA groups and subgroups per recall day | `../NOVA food processing files/` | no | NOVA classification of NHANES recalls |
| MaPiDS specification (documents, not data) | `../MAPiDs/` | no | study team |
| Results | `Analyses/results/` | no | notebooks 02-05 |

## Analysis object: `NHANES_oral_microbiome.se.rda`

The source data of every analysis notebook (02-05). It is built by
`Analyses/01-prepare-data.qmd` from the inputs below and saved at the root of
the repository. It is **not tracked in git and was purged from the git history**.
It lives only in OneDrive. To rebuild it, render `01-prepare-data.qmd`.

| Property | Value |
|----------|-------|
| Path | `NHANES_oral_microbiome.se.rda` (repository root) |
| Size | 10,440,140 bytes |
| SHA-256 | `7e9f7e8140895ac0627a81dffeff58ed74153c58448c9e723a162338cd19b96f` |
| Format | R data file with one object, `NHANES_oral_microbiome.se`; load with `load()` |
| Class | `SummarizedExperiment` (SummarizedExperiment 1.42.0, R 4.6.2) |
| Dimensions | 1,348 genera × 9,348 samples |
| `metadata()` | empty |

```r
library(SummarizedExperiment)
load("NHANES_oral_microbiome.se.rda")   # creates NHANES_oral_microbiome.se
```

### Assay

| Assay | Content |
|-------|---------|
| `counts` | Genus read counts (numeric matrix), DADA2 RB pipeline (`dada2rb-genus-count.txt`), not rarefied. Rows are genera (`RB_genus1` ... `RB_genus1348`), columns are participants (`SEQN`). |

- Samples: kept with more than 10,000 reads; library sizes range from 10,034 to
  675,498 (median 79,823).
- Sparsity: 94.8% of entries are zero; 89 genera have zero counts in all kept samples.

### Row data (taxonomy)

`Domain`, `Phylum`, `Class`, `Order`, `Family`, `Genus`, from SILVA v123
(`dada2rb-taxonomy-annotate.txt`). All rows are Bacteria. Where a rank is not
resolved (`"NA"` in the source file), the genus ID is used instead (e.g.
`Genus = "RB_genus12"`); this is the case for the `Genus` of 383 genera.

### Column data (samples): 346 columns

Rows are named by `SEQN`, the NHANES participant ID (character). The columns are
the full join of four tables, restricted to the samples with microbiome data:

| Group | Columns | Source | Non-missing |
|-------|---------|--------|-------------|
| ID | `SEQN` | all | 9,348 |
| Alpha diversity | `alpha_Observed`, `alpha_Faith`, `alpha_Shannon` | `dada2rb-alpha.txt`, median of the 10 rarefactions at 10,000 reads | 9,348 |
| Survey design | `cycle`, `SDMVPSU`, `SDMVSTRA`, `WTINT2YR`, `WTMEC2YR`, `WTDRD1`, `WTDR2D`, `wt_diet1`, `wt_diet2` | Mukta's file; `wt_diet1`/`wt_diet2` = `WTDRD1`/`WTDR2D` ÷ 2 (4-year weights for the two combined cycles) | 7,108 (6,326 for the day-2 weights) |
| Demographics | `age` (20-69), `sex`, `raceth`, `edu`, `marital`, `pir` | Mukta's file | 6,552-7,108 |
| Health and lifestyle | `bmi`, `waist`, `smoke_status`, `alcohol_cat`, `prev_cvd`, `prev_cancer`, `prev_diabetes`, `prev_htn`, `prev_any`, `pregnant`, `lactating` | Mukta's file | varies |
| Diet (nutrients) | `kcal`, `sfat_g`, `fiber_g`, `sodium_mg`, `sat_pct_kcal` | Mukta's file | 7,108 |
| Recall quality | `day1_ok`, `day2_ok`, `n_reliable_recalls`, `hei_source` | Mukta's file | 7,108 |
| HEI-2020 | `HEI2020_ALL` (total, 0-100) and 13 components `HEI2020_TOTALFRT` ... `HEI2020_SATFAT` | Mukta's file | 7,107 |
| NOVA groups | `nova[1-4]_kcal`, `nova[1-4]_g`, `nova[1-4]_propcal`, `nova[1-4]_propg`; ultra-processed food indices are `nova4_propcal` and `nova4_propg` | Mukta's file | 7,101 |
| NOVA subgroups | `novasg<N>_kcal`, `novasg<N>_g`, `novasg<N>_propcal`, `novasg<N>_propg` for 40 subgroups (list in `01-prepare-data.qmd`) | NOVA files, averaged over the reliable recall days | 7,108 |
| Oral health (derived) | `OH_n_natural_teeth`, `OH_n_implants`, `OH_n_no_teeth_nor_implants`, from the tooth counts `OHX01TC`-`OHX32TC` | `OHXDEN_F`, `OHXDEN_G` | 8,218 |
| Oral health (raw NHANES) | `NHANES_year`, `OHDEXSTS`, `OHDDESTS`, `OHX[01-32]TC`, `OHXIMP`, `OHXDECAY`, `OHXREST`, `OHXSEAL`, `OHX<tooth>CTC`, `OHX<tooth>CSC`, `OHX<tooth>SE` (NHANES codes, see the CDC codebooks) | `OHXDEN_F`, `OHXDEN_G` | varies |
| Nitric oxide | `OH_nitric_oxide_exhalation`, mean of `ENXTR1Q`-`ENXTR4Q` | `ENX_F`, `ENX_G` | 8,063 |

Samples by cycle (`NHANES_year`): 4,818 in 2009-2010, 4,528 in 2011-2012, and 2
without oral health data.

### Things to know when using the object

- **2,240 samples have no diet or covariate data.** They have microbiome data
  but are not in Mukta's analytic file (for example, participants outside ages 20-69),
  so all columns from that file are `NA`. The analytic sample is the 7,108
  participants with `cycle` not missing (7,107 with `HEI2020_ALL`).
- **All microbiome data come from the RB feature table** (`dada2rb-*`): counts,
  alpha diversity, and the NHANES UniFrac distances. Before 2026-11-11, alpha
  diversity was read from the RSV table (`dada2rsv-alpha.txt`) by mistake.
- `cycle` (Mukta's file) and `NHANES_year` (oral health files) agree wherever both
  are present.
- `pregnant` and `lactating` are 0 or `NA`, and the `novasg43_*` columns
  (instant formula) are all 0.
- NOVA group 4 subgroups are filled in for 9 participants whose `nova4_kcal` is
  `NA` in Mukta's file (open question in `01-prepare-data.qmd`).

## External inputs

Read by the notebooks, never modified. Paths are relative to the `NHANES-microbiome/`
folder.

### NHANES oral microbiome (`microbiome-data/`)

NHANES 2009-2012 oral rinse 16S rRNA (V4) data, as released by CDC/NCHS
(documentation: `OralMicrobiomeDataDocumentation-508.pdf` in `NHANES-microbiome/`).
The folder holds the full release (counts and relative abundances at each rank,
alpha and beta diversity, for two feature tables); only the files below are used.

The two feature tables (section 4 of the documentation) both remove SV1032, a
non-bacterial ASV that split the samples into two clusters in beta diversity:

| Prefix | CDC label | Removed from the DADA2 ASV table |
|--------|-----------|----------------------------------|
| `dada2rb-*` | "DADA2 Remove unassigned" | all 2,750 ASVs without a phylum ("Bacteria; NA; NA; NA; NA; NA"), SV1032 included |
| `dada2rsv-*` | "DADA2 Remove SV1032" | SV1032 only |

Both use SILVA v123 taxonomy. These analyses use RB, the stricter filter.

| File | Size (bytes) | SHA-256 | Used by | Content |
|------|-------------:|---------|---------|---------|
| `dada2rb-genus-count.txt` | 27,645,047 | `77a982e4f4d7dbb9d0ba0c0fbb22592277dc6d53ecb9990bce10b9d2a0e2d0b0` | 01 | genus counts, one row per `SEQN` |
| `dada2rb-taxonomy-annotate.txt` | 181,030 | `08fb334b707f45389bf603b881d3bc6fcee40602248cd0cd731b32733e8f37e5` | 01 | SILVA v123 taxonomy of each genus |
| `dada2rb-alpha.txt` | 15,171,455 | `a967562c5e603a952516813a91bd9045fdc711aca84eeb8111a142e42470425d` | 01 | alpha diversity, 10 rarefactions per depth |
| `dada2rb-unwunifrac-beta.txt` | 1,038,946,832 | `b70f651ed454432174c22cfff9de8fc8075e7456493e1fde8adc48ed0e78d9c8` | 04 | unweighted UniFrac distance matrix |
| `dada2rb-wunifrac-beta.txt` | 1,038,941,312 | `bb96b7bcf4c420cf972ab0e4bf2938c961a2899c2de0020957a1eec509964bcd` | 04 | weighted UniFrac distance matrix |

Bray-Curtis and Canberra distances are computed from the `counts` assay in
`04-diet-vs-beta.qmd`, not read from the release.

### NHANES files (`2009-2010/`, `2011-2012/`)

SAS transport files downloaded from the CDC NHANES website (cycles F and G),
with their `.htm` codebooks. The folders hold many more files than are used.

| File | Size (bytes) | SHA-256 | Used by | Content |
|------|-------------:|---------|---------|---------|
| `2009-2010/OHXDEN_F.xpt` | 2,561,280 | `f1f6c600338beacaa99d058c5f4ecba50cd9d698bd0a5a9a44345f3f739aef2b` | 01 | oral health, dentition |
| `2011-2012/OHXDEN_G_exam.xpt` | 6,966,080 | `6ac1182f7ed897b84300a6bf83c5f3108a63a2f7fe25827ee669f38a384d54bd` | 01 | oral health, dentition |
| `2009-2010/ENX_F_exam.xpt` | 1,446,160 | `53d089b29b3635f562566e4d74123d9e916fc82a6c310adc76f32bf7da534b59` | 01 | exhaled nitric oxide |
| `2011-2012/ENX_G_exam.xpt` | 1,322,960 | `e8fda9beb9dfd88ea1732a826edd6e01f6dbec64344632f718e210ca3f1600d8` | 01 | exhaled nitric oxide |
| `2009-2010/DEMO_F.xpt` | 3,631,600 | `78c4d4a6e5eafa9da3bbb24a90d140fef5d8c0cda932a7ff8ee609288d4fae07` | 03 | demographics and survey design |
| `2011-2012/DEMO_G_demo.xpt` | 3,753,760 | `eaf0525d1952626885af3e935415a1f66ad62c18698080e7354789c125af252d` | 03 | demographics and survey design |
| `2009-2010/DR1TOT_F_diet.xpt` | 13,640,000 | `7ff258b1cb2020509d0d0ad3afb49797ca5196d085bac3e45cc6df149d93091c` | 03 | day-1 dietary weight `WTDRD1` |
| `2011-2012/DR1TOT_G_diet.xpt` | 12,424,880 | `d5589de4cd987eef86dd13b3b2bc3db9186ab80a87c96a3968421ddef9235c57` | 03 | day-1 dietary weight `WTDRD1` |

`03-diet-vs-alpha.qmd` reads `DEMO` and `DR1TOT` to define the survey design on
all NHANES participants, not only those in the analysis object.

### Diet indices (`diet-indices-from-Mukta/`)

| File | Size (bytes) | SHA-256 | Used by | Content |
|------|-------------:|---------|---------|---------|
| `analytic_cleanHEI_NOVA_Mukta_2026_08_19.xlsx` | 6,444,356 | `14cb5612c7974557939164435ad3ae36ccb6a5b6db777438df7144dc61388865` | 01 | HEI-2020 (total and components), NOVA groups 1-4, survey design variables and weights, covariates, recall quality flags |

Computed by Mukta. Its columns are listed under [Column data](#column-data-samples-346-columns).

### NOVA per recall day (`NOVA food processing files/`)

| File | Size (bytes) | SHA-256 | Used by |
|------|-------------:|---------|---------|
| `nh0910.day1.nova.v20250131.csv` | 10,752,300 | `cf8b8d27f8268dd004f65c8aa1a59112207a623fb0a7085f851ecee05a03ec0d` | 01 |
| `nh0910.day2.nova.v20250131.csv` | 9,363,696 | `64ca8538d053382022854b7d6b21ff93e07407833586ad56abcb872006a68e6e` | 01 |
| `nh1112.day1.nova.v20250131.csv` | 9,398,512 | `4efe47a5c099aa124ebaae7a3086a4cb40ded46839f9754710ee9d401d352769` | 01 |
| `nh1112.day2.nova.v20250131.csv` | 8,423,297 | `11041ddc802912b60460fa34c35c24c288b3fa0b14344851f87b92d98653a260` | 01 |

NOVA groups and subgroups (absolute kcal and grams, proportion of calories and
grams) per participant and recall day, version 2025-01-31. Only the subgroup
columns are used; the group columns come from Mukta's file.

### MaPiDS (`MAPiDs/`)

Specification and analysis plan documents (`.docx`, `.pdf`). Not read by any
notebook: the MaPiDS score is not yet computed.

## Outputs (`Analyses/results/`)

Written by the notebooks; not tracked in git. Each notebook writes to the folder
set by its `outdir` parameter.

| Notebook | Folder | Files |
|----------|--------|-------|
| `01-prepare-data.qmd` | repository root | `NHANES_oral_microbiome.se.rda` (above) |
| `02-Dirichlet-clustering.qmd` | `results/DirichletMultinomial/` | `CST_assignments_for_k<k>.xlsx` (community type of each participant, one file per number of communities), `BestFitPlot.svg` |
| `03-diet-vs-alpha.qmd` | `results/alpha_diversity/` | `alpha_vs_diet_indices.xlsx`, `alpha_vs_diet_forest_plot.svg` |
| `04-diet-vs-beta.qmd` | `results/beta_diversity/perm<n>_covperm<n>/<distance>/` | `PERMANOVA.xlsx`, `betadisper.xlsx`, `PCoA.xlsx`, `dbRDA.xlsx`, `betadisper_boxplots.svg`, `PCoA_by_diet_index.png`, `dbRDA_by_diet_index.png` |
| `05-beta-summary.qmd` | `results/beta_diversity/perm<n>_covperm<n>/` | `beta_vs_diet_summary_perm<n>_covperm<n>.xlsx` |

`results/beta_diversity/<distance>/` folders without a `perm<n>_covperm<n>`
level come from runs before the permutation numbers were added to the path; the
current notebooks do not write there.

Participant-level outputs contain `SEQN`s and should be handled like the input
data: `CST_assignments_for_k*.xlsx`, `PCoA.xlsx` (coordinates), `dbRDA.xlsx`
(site scores), and `betadisper.xlsx` (distances to the median).

## Verify the inputs

From the `NHANES-microbiome/` folder, `shasum -a 256 -c` checks your copies
against this manifest (the two UniFrac matrices take a few seconds each):

```bash
cd "NHANES-microbiome"
shasum -a 256 -c <<'EOF'
7e9f7e8140895ac0627a81dffeff58ed74153c58448c9e723a162338cd19b96f  NHANES-oral-microbiome-diet/NHANES_oral_microbiome.se.rda
77a982e4f4d7dbb9d0ba0c0fbb22592277dc6d53ecb9990bce10b9d2a0e2d0b0  microbiome-data/dada2rb-genus-count.txt
08fb334b707f45389bf603b881d3bc6fcee40602248cd0cd731b32733e8f37e5  microbiome-data/dada2rb-taxonomy-annotate.txt
a967562c5e603a952516813a91bd9045fdc711aca84eeb8111a142e42470425d  microbiome-data/dada2rb-alpha.txt
b70f651ed454432174c22cfff9de8fc8075e7456493e1fde8adc48ed0e78d9c8  microbiome-data/dada2rb-unwunifrac-beta.txt
bb96b7bcf4c420cf972ab0e4bf2938c961a2899c2de0020957a1eec509964bcd  microbiome-data/dada2rb-wunifrac-beta.txt
14cb5612c7974557939164435ad3ae36ccb6a5b6db777438df7144dc61388865  diet-indices-from-Mukta/analytic_cleanHEI_NOVA_Mukta_2026_08_19.xlsx
cf8b8d27f8268dd004f65c8aa1a59112207a623fb0a7085f851ecee05a03ec0d  NOVA food processing files/nh0910.day1.nova.v20250131.csv
64ca8538d053382022854b7d6b21ff93e07407833586ad56abcb872006a68e6e  NOVA food processing files/nh0910.day2.nova.v20250131.csv
4efe47a5c099aa124ebaae7a3086a4cb40ded46839f9754710ee9d401d352769  NOVA food processing files/nh1112.day1.nova.v20250131.csv
11041ddc802912b60460fa34c35c24c288b3fa0b14344851f87b92d98653a260  NOVA food processing files/nh1112.day2.nova.v20250131.csv
f1f6c600338beacaa99d058c5f4ecba50cd9d698bd0a5a9a44345f3f739aef2b  2009-2010/OHXDEN_F.xpt
53d089b29b3635f562566e4d74123d9e916fc82a6c310adc76f32bf7da534b59  2009-2010/ENX_F_exam.xpt
78c4d4a6e5eafa9da3bbb24a90d140fef5d8c0cda932a7ff8ee609288d4fae07  2009-2010/DEMO_F.xpt
7ff258b1cb2020509d0d0ad3afb49797ca5196d085bac3e45cc6df149d93091c  2009-2010/DR1TOT_F_diet.xpt
6ac1182f7ed897b84300a6bf83c5f3108a63a2f7fe25827ee669f38a384d54bd  2011-2012/OHXDEN_G_exam.xpt
e8fda9beb9dfd88ea1732a826edd6e01f6dbec64344632f718e210ca3f1600d8  2011-2012/ENX_G_exam.xpt
eaf0525d1952626885af3e935415a1f66ad62c18698080e7354789c125af252d  2011-2012/DEMO_G_demo.xpt
d5589de4cd987eef86dd13b3b2bc3db9186ab80a87c96a3968421ddef9235c57  2011-2012/DR1TOT_G_diet.xpt
EOF
```

A mismatch on `NHANES_oral_microbiome.se.rda` alone is expected after
re-rendering `01-prepare-data.qmd` (the file can differ byte-wise even when the
object is the same); update its checksum here when the object is rebuilt on purpose.
A mismatch on an input means the source data changed.
