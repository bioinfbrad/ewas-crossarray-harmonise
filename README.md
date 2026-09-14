# EWAS cross-array harmonisation — Galaxy tool suite

Three Galaxy tools for longitudinal epigenome-wide association studies that
combine Illumina HumanMethylation450 (450K) and MethylationEPIC arrays. They
extend the [EWASGalaxy](https://doi.org/10.1101/553784) suite: harmonisation
that keeps each array in its native probe space until QC is complete, and
design-aware replacements for the fixed-gap region finding and fixed-width
block finding of the minfi workflow.

This repository is the **packaged tool suite only** — the wrappers, the R
drivers they call, and their tests. The Nextflow pipeline, the legacy
bumphunter baseline, the method comparison and the documentation live upstream:
[kkamieniecka/ewas-crossarray-harmonise](https://github.com/kkamieniecka/ewas-crossarray-harmonise).

| tool id | what it does |
|---|---|
| `ewas_harmonise` | per-array QC in native probe space, then merge through `minfi::combineArrays()`; exports an M-value matrix, probe annotation, phenotypes and a QC audit |
| `ewas_dmr_ml` | differentially methylated regions from a within-subject model with a fused penalty, cross-validated by holding out whole subjects; replaces bump hunting |
| `ewas_blocks_hsmm` | megabase-scale blocks from a distance-aware hidden semi-Markov model over data-driven open-sea clusters; replaces the fixed 500 bp / 1500 bp collapse |

## Why a within-subject model

In a two-cohort 450K + EPIC study every Sentrix chip is nested inside one array
type, so array type is collinear with cohort and with chip and no design matrix
can separate them. What is estimable is the within-subject change over the
exposure: each subject sits entirely on one array, the subject intercept
absorbs array, cohort and chip exactly, and the exposure coefficient is
identified from repeated visits of the same person. Permutations are therefore
restricted to visits of the same subject, and cross-validation folds hold out
whole subjects.

## Install

The suite is published on the **[Test Tool Shed](https://testtoolshed.g2.bx.psu.edu)**
under owner `kkamieniecka`, as one repository per tool — `ewas_harmonise`,
`ewas_dmr_ml`, `ewas_blocks_hsmm` — each at revision 0, tool version 0.1.0.
Install from a Galaxy admin panel with the Test Tool Shed configured, or
search the shed for `ewas_`. The main Tool Shed carries nothing yet.

To publish a new revision from a checkout:

```sh
export SHED_KEY=...                   # shed User -> Preferences -> Manage API Key
planemo shed_lint --tools --skip version_bumped --fail_level error .
planemo shed_update --shed_target testtoolshed --shed_key_from_env SHED_KEY \
    -m "what changed" .
```

Notes from the first upload:

- `owner:` in `.shed.yml` must be the shed account that owns the API key, not
  the GitHub account — they need not be the same name.
- `planemo shed_lint` queries the shed to decide whether the version needs a
  bump, and always the *main* shed regardless of `--shed_target`; `--skip
  version_bumped` keeps it offline. Lint at `--fail_level error` so the
  `TestsMissing` warning on `ewas_harmonise` does not stop it.
- `shed_lint` and `shed_update` need the shed reachable and a key, so they are
  hand-run publication steps, not part of CI.
- `planemo shed_diff` fetches the shed-side archive over hgweb, which the Test
  Tool Shed does not serve to anonymous clients; where that is blocked, verify
  a revision through the API instead — `/api/repositories?owner=…` then
  `/api/repositories/{id}/metadata` shows the parsed tools and any invalid
  ones.

Or by hand: copy this directory into your Galaxy `tools/` tree and add the
three XML files to a section in `tool_conf.xml`. Requirements resolve through
conda (bioconda + conda-forge); `ewas_harmonise` needs `bioconductor-minfi`
and the Illumina annotation packages it pulls in, which is the heaviest of the
three environments.

## Layout

```
.shed.yml                     suite metadata for the Tool Shed
macros.xml                    versions, requirement sets, shared design inputs
ewas_harmonise.xml            tool wrappers
ewas_dmr_ml.xml
ewas_blocks_hsmm.xml
scripts/01_harmonise.R        the drivers the wrappers call
scripts/04_dmr_ml.R
scripts/05_blocks_hsmm.R
scripts/ewasml.R              numerical core sourced by 04 and 05
test-data/                    synthetic fixtures for the tool tests
tests/run_galaxy_tool_tests.py  serverless fallback runner
serve.sh                      boot a local Galaxy with the three tools
test.sh                       run the tool tests, real harness or fallback
sync-from-pipeline.sh         refresh this repo from an upstream checkout
```

The only difference from upstream is the path the wrappers use to reach the
drivers: upstream they sit in the pipeline's `bin/`, here they sit in
`scripts/` inside the tool directory, so nothing is referenced outside the
published repository. `sync-from-pipeline.sh` applies that rewrite.

## Running it locally

Two scripts wrap the flag lists:

```sh
./serve.sh                  # local Galaxy on 127.0.0.1:9090 with all three tools
DEPS=conda ./serve.sh       # ... with requirements resolved, so jobs run
PORT=9191 ./serve.sh

./test.sh                   # the tool tests
RUNNER=serverless ./test.sh # skip Galaxy, render and execute the commands only
```

`serve.sh` defaults to `--no_dependency_resolution`: the forms, parameter tree
and conditional logic are all live, but submitted jobs fail for want of R
packages. `DEPS=conda` fixes that at the cost of a long first run, and
`R_LIBS_USER=… DEPS=hostR` runs jobs against an R library already on the
machine — which is how `ewas_harmonise` runs on Apple silicon, where bioconda
has no `osx-arm64` `bioconductor-*` builds. The script prints the `test-data/`
fixtures to upload, which are the same inputs the tool tests use.

`docs/local-galaxy.md` is the step-by-step version, including installing from
the Test Tool Shed into a real Galaxy and the Docker route.

`test.sh` probes whether a local port can be bound before choosing a runner.
Where it can, it runs `planemo test` and writes `planemo_report.html` /
`.json`. Where it cannot — some sandboxes refuse every bind, loopback and
ephemeral included, and planemo's Galaxy then never starts — it falls back to
the serverless runner and says so on stderr. That fallback is the weaker
check: it renders and executes each test's command and verifies the declared
content assertions, but nothing downstream of the job — no datatype sniffing,
no metadata setting, no format declarations. A wrapper defect of exactly that
kind (a `csv` output declaration over a gzipped file) once passed the runner
and failed the real harness, so treat a green fallback as provisional until CI
agrees.

## Tests

```sh
planemo lint --fail_level error ewas_*.xml
planemo test --no_dependency_resolution ewas_dmr_ml.xml ewas_blocks_hsmm.xml
```

Both run in CI on every push. `ewas_harmonise` carries no `<tests>` — it reads
raw IDATs, and no synthetic fixture stands in for them — so `planemo lint`
reports a `TestsMissing` warning for it; CI lints at `--fail_level error` so
that warning stays visible without failing the build.

`planemo test` starts a Galaxy instance on a local port. Where that is not
possible (containers and sandboxes that forbid binding), run

```sh
python tests/run_galaxy_tool_tests.py ewas_dmr_ml.xml ewas_blocks_hsmm.xml
```

which renders the same `<command>` from the same `<test>` values plus the XML
defaults, runs it, and checks `expect_num_outputs` and `<assert_contents>`. It
is not a substitute for planemo: no datatype sniffing, no metadata, no format
declarations, no dependency resolution, no diff-style output comparison. A
datatype defect that real `planemo test` caught in `ewas_blocks_hsmm` was
invisible to it.

The fixtures under `test-data/` are synthetic and seeded — 4000 probes, 39
arrays, 12 subjects — generated upstream by
`tests/gen_equivalence_fixtures.py --stage-dir`. No study data is committed
here. The 4000-probe panel clusters into ~170 open-sea units, below the
production floor of 200, so the block tool's test lowers
`--min-fit-clusters` to 100; regenerate the fixtures rather than growing them.

## Provenance

Extracted from upstream commit `e4c54cf334b995599bb6a21320ac99f85bc72dc7`
(2026-09-10), where the wrappers and their tests pass `planemo lint` and
`planemo test` in CI.

## Citation

If you use these tools, cite the EWASGalaxy suite they extend
([10.1101/553784](https://doi.org/10.1101/553784)) and, for the harmonisation
step, minfi's `combineArrays`
([10.1093/bioinformatics/btu049](https://doi.org/10.1093/bioinformatics/btu049)).

## Licence

MIT, as upstream. See [LICENSE](LICENSE).
