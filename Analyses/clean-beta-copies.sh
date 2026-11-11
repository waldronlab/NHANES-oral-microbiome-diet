#!/usr/bin/env bash
# Delete the per-distance copies of 04-diet-vs-beta.qmd made by
# run-beta-distance.sh (04-diet-vs-beta_<distance>_perm<n>_covperm<n>.qmd) and
# their Quarto intermediates (.rmarkdown). Reports (.html, _files/) are kept.
# Copies whose render is still running are skipped.
#
# Usage: ./clean-beta-copies.sh

set -euo pipefail

cd "$(dirname "$0")"

shopt -s nullglob
for notebook_copy in 04-diet-vs-beta_*.qmd; do
    if pgrep -f "quarto.*render.*${notebook_copy}" > /dev/null; then
        echo "Skipped (render running): ${notebook_copy}"
        continue
    fi
    rm -f "${notebook_copy}" "${notebook_copy%.qmd}.rmarkdown"
    echo "Deleted: ${notebook_copy}"
done
