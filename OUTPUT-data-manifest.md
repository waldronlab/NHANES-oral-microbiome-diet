# Output data manifest

This manifest describes every result file the analyses write: which notebook
builds it, with which key parameters, and what it contains. The data the
analyses read are described in [`INPUT-data-manifest.md`](INPUT-data-manifest.md).

**No results are tracked in git.** They are written to `Analyses/results/` and
live in the shared OneDrive folder only. Each notebook writes to the folder set
by its `outdir` parameter; all paths below are relative to `Analyses/`. Full
documentation of each notebook and its options is in
[`Analyses/README.md`](Analyses/README.md).

Checksums (SHA-256), sizes, and dates were recorded on 2026-11-11 from the files
then in OneDrive. See [Verify the outputs](#verify-the-outputs).

## Overview

| Notebook | Output folder | Files | Built on | Key parameters of the current files |
|----------|---------------|------:|----------|-------------------------------------|
| `01-prepare-data.qmd` | repository root | 1 | 2026-11-11 | none |
| `02-Dirichlet-clustering.qmd` | `results/DirichletMultinomial/` | 16 | 2026-10-30 | `k_communities: 15` |
| `03-diet-vs-alpha.qmd` | `results/alpha_diversity/` | 2 | 2026-11-11 | survey-weighted and unweighted models |
| `04-diet-vs-beta.qmd` | `results/beta_diversity/perm999_covperm999/<distance>/` | 4 × 7 | 2026-10-29 to 30 | `n_permutations: 999`, `n_permutations_covariates: 999`, 4 distances |
| `05-beta-summary.qmd` | `results/beta_diversity/perm999_covperm999/` | 1 | 2026-10-30 | `n_permutations: 999`, `n_permutations_covariates: 999` |

Notebooks 02, 04, and 05 ran on the analysis object from before 2026-11-11,
when alpha diversity was switched from the RSV to the RB feature table. They do
not use alpha diversity, and the rest of the object is unchanged, so their
results are still current.

All analyses use the three diet indices `HEI2020_ALL` (HEI-2020), `nova4_propcal`
(UPF, % calories), and `nova4_propg` (UPF, % grams), and the same covariates: age,
sex, race/ethnicity, education, income to poverty ratio, smoking, alcohol, BMI,
energy intake, number of natural teeth, and NHANES cycle.

**Participant-level files** contain `SEQN`s and must be handled like the input
data: `CST_assignments_for_k*.xlsx`, `PCoA.xlsx`, `dbRDA.xlsx`, and `betadisper.xlsx`.

## `01-prepare-data.qmd`: analysis object

Builds `NHANES_oral_microbiome.se.rda` (repository root) from the raw inputs:
genus counts, taxonomy, alpha diversity, diet indices, and oral health data, for
the 9,348 samples with more than 10,000 reads. Its contents and checksum are in
[`INPUT-data-manifest.md`](INPUT-data-manifest.md#analysis-object-nhanes_oral_microbiomeserda),
since every other notebook reads it.

## `02-Dirichlet-clustering.qmd`: community types

Fits Dirichlet Multinomial Mixture models with 1 to `k_communities` communities
on the genus counts of all 9,348 samples, and assigns each sample to a community
type (CST).

| Setting | Value |
|---------|-------|
| `k_communities` | 15 (models with 1 to 15 communities) |
| Genus filter | at least 10 counts in at least 50 samples |
| Random seed | 1234 |
| Ambiguous assignments | best and second-best probabilities differ by less than 0.2: `CST.Other` |

`n_workers` (parallel workers) does not change the results.

| File | Content |
|------|---------|
| `CST_assignments_for_k<k>.xlsx`, k = 1-15 | sheet `Mixture`: `SEQN`, assigned `CST`, and the probability of each CST (`CST.<i>_assign_prob`), one row per sample (9,348); sheet `MixtureWeights`: mixture weight (`pi`) and precision (`theta`) of each CST |
| `BestFitPlot.svg` | AIC, BIC, and Laplace by number of communities, to choose k |

## `03-diet-vs-alpha.qmd`: diet indices vs alpha diversity

Linear models `alpha ~ diet index + covariates` for each alpha diversity metric
(Observed, Shannon, Faith; RB feature table) and diet index. Diet indices are
standardized, so estimates are per 1 SD. Complete cases per model: 5,240-5,244
participants.

| Setting | Value |
|---------|-------|
| Primary models | survey-weighted (day-1 dietary weight `WTDRD1 / 2`, strata and PSUs, design on all NHANES 2009-2012 participants) |
| Sensitivity models | unweighted |
| Multiple testing | Benjamini-Hochberg FDR within each metric and method |

| File | Content |
|------|---------|
| `alpha_vs_diet_indices.xlsx` | one sheet per metric (`Observed richness`, `Shannon diversity`, `Faith's phylogenetic diversity`), 120 rows each: every model term (diet index and covariates) for both methods, with `n`, `estimate`, `std.error`, 95% CI, `statistic`, `p.value`, and `p.adj` (FDR) |
| `alpha_vs_diet_forest_plot.svg` | diet index estimates with 95% CI, by metric and method |

## `04-diet-vs-beta.qmd`: diet indices vs beta diversity

One render per distance, through `run-beta-distance.sh <distance>`. Models are
unweighted, with permutations restricted within NHANES strata (`SDMVSTRA`), on a
single analytic sample of 5,240 participants (complete cases for all diet
indices and covariates).

| Setting | Value |
|---------|-------|
| `distance` | `Bray-Curtis`, `Canberra` (computed from genus relative abundances, same genus filter as 02), `unweighted_UniFrac`, `weighted_UniFrac` (NHANES RB matrices) |
| `n_permutations` | 999, for the diet index PERMANOVA and betadisper |
| `n_permutations_covariates` | 999, for the covariate PERMANOVA |
| Random seed | 1234, reset before each test |

`n_cores` (cores for permutations) does not change the results.

Files in `results/beta_diversity/perm999_covperm999/<distance>/`, for each of the
four distances:

| File | Content |
|------|---------|
| `PERMANOVA.xlsx` | sheet `diet_indices`: `R2`, `F`, `p.value` of each diet index after adjusting for the covariates (3 rows); sheet `covariates`: marginal test of each covariate (`adonis2(by = "margin")`) |
| `betadisper.xlsx` | sheet `test`: dispersion across quartiles of each diet index (`F`, `p.value`); sheet `distance_to_median`: `SEQN`, quartile, and distance to the quartile median, per diet index |
| `betadisper_boxplots.svg` | distance to median by quartile, per diet index |
| `PCoA.xlsx` | sheet `coordinates`: `SEQN`, `PCo1`, `PCo2`; sheet `eigenvalues`: all axes |
| `PCoA_by_diet_index.png` | first two PCoA axes colored by each diet index |
| `dbRDA.xlsx` | sheet `inertia`: total, covariate, and diet index inertia, and the proportion explained by the index; sheet `site_scores`: `SEQN`, `CAP1`, `MDS1`, per diet index |
| `dbRDA_by_diet_index.png` | ordination constrained to each diet index, covariates partialled out |

The p-values of the diet indices are not FDR-corrected here; `05-beta-summary.qmd`
does it across distances.

## `05-beta-summary.qmd`: beta diversity summary

Combines the four distances of one run of `04-diet-vs-beta.qmd`, selected by the
same `n_permutations` and `n_permutations_covariates` (999 and 999).

| File | Content |
|------|---------|
| `perm999_covperm999/beta_vs_diet_summary_perm999_covperm999.xlsx` | sheets `PERMANOVA` and `betadisper`: diet index tests with Benjamini-Hochberg FDR across all distances and diet indices (12 tests each); `PERMANOVA_covariates`: covariate tests, FDR within distance; `dbRDA`: inertia of each distance and diet index |

## Files not described here

- **`results/beta_diversity/<distance>/`** (Bray-Curtis, Canberra,
  unweighted_UniFrac, weighted_UniFrac, without a `perm<n>_covperm<n>` level):
  results of an earlier version of `04-diet-vs-beta.qmd` (2026-10-29 21:57),
  with a different `PERMANOVA.xlsx` layout (one full `adonis2` table per diet
  index). The current notebooks neither write nor read them; they can be deleted.
- **HTML reports** (`Analyses/<notebook>.html` and `<notebook>_files/`): rendered
  next to each notebook; they document a run but are not results.
- `.DS_Store` and Office lock files (`~$*`).

## Verify the outputs

From `Analyses/`, `shasum -a 256 -c` checks the result files against this
manifest. A mismatch means a notebook was re-rendered; update this manifest
with the new checksums when that was intended.

```bash
cd Analyses
shasum -a 256 -c <<'EOF'
550a2ea1c6cc3669babbeec9f1f976f2b8b4dfa90633a3703d5dca65a08ef6b2  results/alpha_diversity/alpha_vs_diet_forest_plot.svg
a41897a82fbd116c80b5caf324df92da8d8a8771788c30b97552ec4003c8ee78  results/alpha_diversity/alpha_vs_diet_indices.xlsx
0d39e686af5e3919150df2bf41e1152e0db22bc9c4fba65e1f57abf9af7a2c9d  results/beta_diversity/perm999_covperm999/beta_vs_diet_summary_perm999_covperm999.xlsx
34a099e607e58e1d7adc81279a5275df067461259f80a359425df2da1a19e909  results/beta_diversity/perm999_covperm999/Bray-Curtis/betadisper_boxplots.svg
fd7dacb00c33cc44b66af56686829ae8d3e45d8667e72c1fb3c3bac146f67746  results/beta_diversity/perm999_covperm999/Bray-Curtis/betadisper.xlsx
afcd0eae9d293fad497d582fefa36c25247471ae012c32fe104e14ed121fe278  results/beta_diversity/perm999_covperm999/Bray-Curtis/dbRDA_by_diet_index.png
7f0e9ba97d3246050a737956fa88f401d11ffab461ddcfe9a4388fd120533cd2  results/beta_diversity/perm999_covperm999/Bray-Curtis/dbRDA.xlsx
11352d08e0ff0023c81fcf1b032d7bfae00c9414149247e387c0321569f98622  results/beta_diversity/perm999_covperm999/Bray-Curtis/PCoA_by_diet_index.png
00eb0c9fb61ebd7f86202602640bdbe652535066bcbcb57da56147a363665f2a  results/beta_diversity/perm999_covperm999/Bray-Curtis/PCoA.xlsx
a2cb36053e16ca04ae9626b66b8a55d135c4e9ea72a0b390847e0846adb6bb05  results/beta_diversity/perm999_covperm999/Bray-Curtis/PERMANOVA.xlsx
31df050975a0b245cef946f4a3f99232d378c36bf2b8bf44adedf631c6bf9ab1  results/beta_diversity/perm999_covperm999/Canberra/betadisper_boxplots.svg
783a643df0d33c05b674b1df9c2ed47a349669b62742e08b288328aaf294a77c  results/beta_diversity/perm999_covperm999/Canberra/betadisper.xlsx
761f409ae5a1b0c00cdfe44c6a705275afb07f550bd0a4f07e3405e591b2e995  results/beta_diversity/perm999_covperm999/Canberra/dbRDA_by_diet_index.png
55e86f70bce95c28ec8480c9be4248071911c6aa0fa7aa4bb6bdd4b83a49dd17  results/beta_diversity/perm999_covperm999/Canberra/dbRDA.xlsx
b07515fd3cbb31618fdfb80f19fbda8bbeed84e2f9c4afea1a637f911daa76e2  results/beta_diversity/perm999_covperm999/Canberra/PCoA_by_diet_index.png
2223cd5fa57b391aaca9f3d4ffc25f190a0c4c4fdb936257660bcd20ee1451a3  results/beta_diversity/perm999_covperm999/Canberra/PCoA.xlsx
9c4c673b1873b4c87999e483dd96a72f4d1b95fac68f8917b6a4b58aeb2685cf  results/beta_diversity/perm999_covperm999/Canberra/PERMANOVA.xlsx
b976371ab18203324980bd073e34f202995abc511e2608fed0cd34740e866c3a  results/beta_diversity/perm999_covperm999/unweighted_UniFrac/betadisper_boxplots.svg
33407c01abc1ebe10f7f4a498bdd1b6be8aa1e00ad5b1329caf949d343399beb  results/beta_diversity/perm999_covperm999/unweighted_UniFrac/betadisper.xlsx
a3f98bd19ef4d74477c5666106cce1f468527eba93e365f1a2dc91f2a5091d4a  results/beta_diversity/perm999_covperm999/unweighted_UniFrac/dbRDA_by_diet_index.png
9dab45396e3e56287121f3a491d1cc514f6750892a584b0a595759816d632397  results/beta_diversity/perm999_covperm999/unweighted_UniFrac/dbRDA.xlsx
f6ee2cac53c940efb7bf4d76bc42867549bc0654c301b075119a8250f9bb124f  results/beta_diversity/perm999_covperm999/unweighted_UniFrac/PCoA_by_diet_index.png
3c5c82e24a81f995c7aea91ddf2695cd93e81815c13cfb77968124ee7e0b1c7c  results/beta_diversity/perm999_covperm999/unweighted_UniFrac/PCoA.xlsx
ad471be8ecb4ce6d1a1099ec115b11e8324005788ca4f1cbe3c2fd283a723e77  results/beta_diversity/perm999_covperm999/unweighted_UniFrac/PERMANOVA.xlsx
6f52336b73296571f6e291fb1681722caa5e0ee98f100cba0947d55872ba6bb0  results/beta_diversity/perm999_covperm999/weighted_UniFrac/betadisper_boxplots.svg
723eaa87cb59610772b395a379a1fa4495bd98f15f3706786d73fed13679045b  results/beta_diversity/perm999_covperm999/weighted_UniFrac/betadisper.xlsx
804a48f1f16d9e10b0b439518e2078247b6fbaac7519b532252ca017f0aeb48f  results/beta_diversity/perm999_covperm999/weighted_UniFrac/dbRDA_by_diet_index.png
16e105efd3a861a2c88c427495dd5e9b9157c74d2bd91c4f1ac319043a49f6b8  results/beta_diversity/perm999_covperm999/weighted_UniFrac/dbRDA.xlsx
32c894b09cd4d66f8df781f201f4f5d844a95f04f0b7387785b16c02dfd237d1  results/beta_diversity/perm999_covperm999/weighted_UniFrac/PCoA_by_diet_index.png
5dc6774d813f537bae4130dd3a700767573d7fb7232641a5498edf8820909de8  results/beta_diversity/perm999_covperm999/weighted_UniFrac/PCoA.xlsx
e483b7beef631a93f4c7c6d9cbec5fe1de5c7a57239526e59aeff190c311eea4  results/beta_diversity/perm999_covperm999/weighted_UniFrac/PERMANOVA.xlsx
7fe6a34060bb1a27a856bf3379e375bd019d5773acf3aebe057f1423c372e4fe  results/DirichletMultinomial/BestFitPlot.svg
efb339f7f1e5f2751599c5dffbbd5a16b0a3529fa870bad8dd5fdcc8c98e9260  results/DirichletMultinomial/CST_assignments_for_k1.xlsx
798a4c882edd125a42fa4e3e3b3d49bf620a32b005025ad2f53b64dbf33fdfd4  results/DirichletMultinomial/CST_assignments_for_k10.xlsx
cb74d4996b0c74da2ff487fe65e07cb439a7a527f2c3aa9ae72adf526f66725c  results/DirichletMultinomial/CST_assignments_for_k11.xlsx
c6099dd83bea0d19ec95a5f8fe21cbf0f4719bcd0d2e562a4b5f9d123959ce52  results/DirichletMultinomial/CST_assignments_for_k12.xlsx
466812925189e56edb9862d7284730733753021b38248aacc28a862e138f0602  results/DirichletMultinomial/CST_assignments_for_k13.xlsx
f5f9adf197b274d1a6c21cd4c522bcc461544f8ff9dc71b06ee3faaa1b17c5ba  results/DirichletMultinomial/CST_assignments_for_k14.xlsx
87e5c2183edb4fa1e49df38433821832a9b77792a6a93a321f794152e83bbd46  results/DirichletMultinomial/CST_assignments_for_k15.xlsx
20d9fcb223608dc4eedfc50c5ddda1959813d9d4640f3a70fad472e12c3fbbe0  results/DirichletMultinomial/CST_assignments_for_k2.xlsx
6279915f2c3fb420d8030ce4172fc43a93a4e53113724451f600b33f028be03c  results/DirichletMultinomial/CST_assignments_for_k3.xlsx
2d6461f334478a676c529cb1c51624363f04c68095f876e664e0cde187ee9b16  results/DirichletMultinomial/CST_assignments_for_k4.xlsx
afe62e9f96362660dc9b02836a2ace4b742275e7c921412a28c056961b8a7994  results/DirichletMultinomial/CST_assignments_for_k5.xlsx
a1b69ce6b92484656034cf1ce8a84ac7cd5eb1fc6009c8cb1f48bd6381e6fc05  results/DirichletMultinomial/CST_assignments_for_k6.xlsx
3ec448293e379306f02d02766ab02b4a7a19e205bfe952e493f897435331cdbd  results/DirichletMultinomial/CST_assignments_for_k7.xlsx
a7db62ab490a1a0efcdb44593f118cedb8befe71e19509d2cc7606d14f66686e  results/DirichletMultinomial/CST_assignments_for_k8.xlsx
cdad607153d252795939295ece38e8cc620789c28cbd3d48508b3ee38d0ba247  results/DirichletMultinomial/CST_assignments_for_k9.xlsx
EOF
```
