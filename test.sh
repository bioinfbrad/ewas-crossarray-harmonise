#!/usr/bin/env bash
# Run the tool tests. Two wrappers carry test cases; ewas_harmonise has none
# because it needs raw IDATs and no fixture small enough to commit exercises it.
#
#   ./test.sh                  real planemo test, falling back to the
#                              serverless runner where no port can be bound
#   RUNNER=planemo ./test.sh   force planemo, fail if it cannot start Galaxy
#   RUNNER=serverless ./test.sh  force the serverless runner
#   DEPS=conda ./test.sh       resolve requirements instead of using the
#                              R packages already on PATH
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

TESTABLE=(ewas_dmr_ml.xml ewas_blocks_hsmm.xml)
RUNNER="${RUNNER:-auto}"
DEPS="${DEPS:-none}"

# planemo test boots a Galaxy and binds an HTTP port. Some sandboxes refuse
# every bind, loopback and ephemeral included, so probe before committing to it.
can_bind() {
    python3 - <<'EOF' >/dev/null 2>&1
import socket, sys
s = socket.socket()
try:
    s.bind(("127.0.0.1", 0))
except OSError:
    sys.exit(1)
finally:
    s.close()
EOF
}

if [ "$RUNNER" = auto ]; then
    if can_bind; then
        RUNNER=planemo
    else
        RUNNER=serverless
        echo "NOTE: cannot bind a local port, so planemo test cannot start Galaxy." >&2
        echo "      Falling back to the serverless runner, which is the weaker check:" >&2
        echo "      it renders and executes the command but verifies no datatype" >&2
        echo "      sniffing, metadata setting or format declaration. Run the real" >&2
        echo "      harness in CI before trusting a wrapper change." >&2
    fi
fi

case "$RUNNER" in
    planemo)
        if [ "$DEPS" = conda ]; then
            dep_args=(--conda_auto_install --conda_auto_init)
        else
            dep_args=(--no_dependency_resolution)
        fi
        exec planemo test "${dep_args[@]}" \
            --test_output planemo_report.html \
            --test_output_json planemo_report.json \
            "${TESTABLE[@]}"
        ;;
    serverless)
        exec python3 tests/run_galaxy_tool_tests.py "${TESTABLE[@]}"
        ;;
    *)
        echo "RUNNER must be 'auto' (default), 'planemo' or 'serverless', got '$RUNNER'" >&2
        exit 2
        ;;
esac
