#!/usr/bin/env bash
# Refresh this tool repository from a checkout of the upstream pipeline,
# https://github.com/kkamieniecka/ewas-crossarray-harmonise, which is where the
# wrappers and drivers are developed.
#
#   ./sync-from-pipeline.sh /path/to/ewas-crossarray-harmonise
#
# The one rewrite applied here: upstream wrappers reach the drivers through
# $__tool_directory__/../bin/, which points outside a published tool
# repository. Here the drivers sit in scripts/ inside the tool directory, so
# the prefix becomes $__tool_directory__/scripts/. Nothing else is edited --
# review the diff before committing, and record the upstream commit this
# printed in the commit message.
set -euo pipefail

up=${1:?usage: sync-from-pipeline.sh /path/to/pipeline/checkout}
here=$(cd "$(dirname "$0")" && pwd)

for f in macros.xml ewas_harmonise.xml ewas_dmr_ml.xml ewas_blocks_hsmm.xml; do
    sed 's|\$__tool_directory__/\.\./bin/|$__tool_directory__/scripts/|g' \
        "$up/galaxy/$f" > "$here/$f"
done

for f in 01_harmonise.R 04_dmr_ml.R 05_blocks_hsmm.R ewasml.R; do
    cp "$up/bin/$f" "$here/scripts/$f"
done

cp "$up"/galaxy/test-data/* "$here/test-data/"
cp "$up/tests/run_galaxy_tool_tests.py" "$here/tests/run_galaxy_tool_tests.py"

echo "synced from $up at commit $(git -C "$up" rev-parse HEAD 2>/dev/null || echo unknown)"
echo "review: git -C $here diff"
