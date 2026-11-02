#!/usr/bin/env bash
# Render 04-diet-vs-beta.qmd for one distance.
#
# Each distance renders from its own copy of the notebook, so that several
# distances can render at the same time in this folder without overwriting each
# other's intermediate files, also for runs of the same distance with different
# numbers of permutations. The report is
# 04-diet-vs-beta_<distance>_perm<n_permutations>_covperm<n_permutations_covariates>.html.
#
# Usage: ./run-beta-distance.sh <distance> [more quarto render arguments]
#   distance: Bray-Curtis, Canberra, unweighted_UniFrac, or weighted_UniFrac
# Example: ./run-beta-distance.sh Canberra -P n_cores:8

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <distance> [more quarto render arguments]" >&2
    exit 1
fi

distance="$1"
shift

cd "$(dirname "$0")"

# numbers of permutations, from the arguments or else the notebook defaults
notebook_default() { awk -v p="$1:" '$1 == p {print $2; exit}' 04-diet-vs-beta.qmd; }
n_permutations=$(notebook_default n_permutations)
n_permutations_covariates=$(notebook_default n_permutations_covariates)
for arg in "$@"; do
    case "${arg}" in
        n_permutations:*) n_permutations="${arg#*:}" ;;
        n_permutations_covariates:*) n_permutations_covariates="${arg#*:}" ;;
    esac
done

notebook_copy="04-diet-vs-beta_${distance}_perm${n_permutations}_covperm${n_permutations_covariates}.qmd"
cp 04-diet-vs-beta.qmd "${notebook_copy}"
trap 'rm -f "${notebook_copy}"' EXIT

quarto render "${notebook_copy}" -P distance:"${distance}" "$@"
