# Create conda environment with quarto

```bash
conda create -n quarto r-base=4.6.1 r-biocmanager r-furrr bioconductor-mia r-tidyverse
# make sure the R library is isolated in the environment
conda activate quarto
echo -e ".libPaths('${CONDA_PREFIX}/lib/R/library/')" > ${CONDA_PREFIX}/lib/R/etc/Rprofile.site
```

# Prepare data

This includes `metadata`, `microbiome matrix`, and `taxonomy data` preparation.
It also removes samples with less than 20k counts assigned, which can be defined deep enough

```bash
quarto render 00-prepare-data.qmd
```

# Create a `Dirichlet Multinomial` community assignment for 1 to 20 communities

This needs to be run in the background, it takes really long

```bash
01-Dirichlet-clustering.qmd -P k_communties:20
```
