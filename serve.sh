#!/usr/bin/env bash
# Boot a local Galaxy with the three EWAS cross-array tools loaded, so the
# wrappers can be driven through the UI.
#
#   ./serve.sh                 forms only, jobs will fail for want of R packages
#   DEPS=conda ./serve.sh      resolve requirements through conda
#   DEPS=hostR ./serve.sh      run jobs against the R library on this machine
#                              (needs Rscript on PATH and R_LIBS_USER set)
#   PORT=9191 ./serve.sh       serve somewhere other than 9090
#
# First boot clones a galaxy-dev tree into ~/.planemo and takes several
# minutes; later boots reuse it.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

PORT="${PORT:-9090}"
DEPS="${DEPS:-none}"
TOOLS=(ewas_harmonise.xml ewas_dmr_ml.xml ewas_blocks_hsmm.xml)

case "$DEPS" in
    none)
        # Fast: the tool forms, parameter tree and conditional logic are all
        # live, but no requirement is installed, so submitted jobs fail.
        dep_args=(--no_dependency_resolution)
        ;;
    conda)
        # Slow on first run. ewas_harmonise pulls bioconductor-minfi and the
        # Illumina annotation packages, which is the heaviest of the three
        # environments by a wide margin. Note that bioconda ships no
        # osx-arm64 bioconductor-* builds, so on Apple silicon this resolves
        # for ewas_dmr_ml and ewas_blocks_hsmm but not for ewas_harmonise.
        dep_args=(--conda_auto_install --conda_auto_init)
        ;;
    hostR)
        # Run jobs against an R library that already exists on this machine,
        # which is how ewas_harmonise gets to run on Apple silicon. Galaxy
        # inherits this environment, so Rscript must be on PATH and
        # R_LIBS_USER must point at the library holding minfi and limma.
        command -v Rscript >/dev/null || {
            echo "DEPS=hostR needs Rscript on PATH" >&2
            exit 127
        }
        : "${R_LIBS_USER:?DEPS=hostR needs R_LIBS_USER set to the library holding minfi/limma}"
        [ -d "$R_LIBS_USER" ] || {
            echo "R_LIBS_USER=$R_LIBS_USER is not a directory" >&2
            exit 2
        }
        missing="$(Rscript -e 'p <- c("minfi","limma","Matrix","optparse","jsonlite"); cat(paste(p[!p %in% rownames(installed.packages())], collapse=" "))' 2>/dev/null)"
        if [ -n "$missing" ]; then
            echo "WARNING: not in R_LIBS_USER: $missing" >&2
            echo "         tools needing those packages will fail at job time." >&2
        fi
        export R_LIBS_USER
        dep_args=(--no_dependency_resolution)
        ;;
    *)
        echo "DEPS must be 'none' (default), 'conda' or 'hostR', got '$DEPS'" >&2
        exit 2
        ;;
esac

command -v planemo >/dev/null || {
    echo "planemo not on PATH; pip install planemo (or activate the env that has it)" >&2
    exit 127
}

cat <<MSG
Serving ${#TOOLS[@]} tools on http://127.0.0.1:${PORT} (dependencies: ${DEPS})

Fixtures to upload, from test-data/ — these are what the tool tests use:
  test_mval.f64        M-value matrix, float64, probes x samples
  test_mval_dims.json  its dimensions and probe/sample order
  test_pheno.csv       phenotype table
  test_anno.csv        probe annotation
  test_probe_map.csv   cross-array probe map

Ctrl-C to stop.
MSG

exec planemo serve --host 127.0.0.1 --port "$PORT" "${dep_args[@]}" "${TOOLS[@]}"
