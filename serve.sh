#!/usr/bin/env bash
# Boot a local Galaxy with the three EWAS cross-array tools loaded, so the
# wrappers can be driven through the UI.
#
#   ./serve.sh                 forms only, jobs will fail for want of R packages
#   DEPS=conda ./serve.sh      resolve requirements so jobs actually run
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
        # environments by a wide margin.
        dep_args=(--conda_auto_install --conda_auto_init)
        ;;
    *)
        echo "DEPS must be 'none' (default) or 'conda', got '$DEPS'" >&2
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
