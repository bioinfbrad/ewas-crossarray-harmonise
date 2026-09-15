# Changelog

Tool versions follow `@TOOL_VERSION@` in `macros.xml`; this file records
changes to the packaging. The methods themselves are developed upstream at
[kkamieniecka/ewas-crossarray-harmonise](https://github.com/kkamieniecka/ewas-crossarray-harmonise),
whose changelog carries the numerical history.

## [Unreleased]

### Changed

- Synced from upstream `3c5dbab`. `requirements_r_ml` (`ewas_dmr_ml`,
  `ewas_blocks_hsmm`) moves from R 4.4 with `bioconductor-limma` 3.62.0 to R
  4.5 with 3.66.0, with Matrix, optparse and jsonlite pinned to match. That
  set was solved and installed on `osx-arm64`, so those two tools resolve
  through conda on Apple silicon; 3.62.0 has no build there.
- The drivers `04_dmr_ml.R` and `05_blocks_hsmm.R` load the upstream
  `crossarrayEWAS` R package when it is installed and fall back to
  `scripts/ewasml.R` when it is not, recording which in the stage's run
  record. Here it is always the fallback: the wrappers deliberately do not
  require the package while it is unpublished, since a requirement that
  resolves in no channel breaks dependency resolution. README records the two
  edits that retire the vendored core once it is published.
- `docs/local-galaxy.md`: the Apple-silicon note is now specific.
  `bioconductor-minfi` is `noarch` and not itself the obstacle — it needs
  `bioconductor-illuminaio`, which has no `osx-arm64` build at any version,
  and that is where the solve fails.

### Added

- `docs/local-galaxy.md`: step-by-step routes to a local Galaxy carrying these
  tools - planemo serve, a release checkout with the tools installed from the
  Test Tool Shed, and the amd64 Docker image. Records why `ewas_harmonise`
  cannot resolve through conda on Apple silicon.
- `DEPS=hostR` in `serve.sh` runs jobs against an existing R library
  (`R_LIBS_USER`) instead of resolving requirements, and warns which of
  minfi, limma, Matrix, optparse and jsonlite are missing from it.

- `serve.sh` boots a local Galaxy with all three tools loaded (`DEPS=conda`
  resolves requirements so jobs run; `PORT=` moves it off 9090), and `test.sh`
  runs the tool tests. `test.sh` probes for a bindable local port first and
  falls back to `tests/run_galaxy_tool_tests.py` where planemo's Galaxy cannot
  start, printing what that fallback does not cover.

- Published to the Test Tool Shed as three repositories owned by
  `kkamieniecka` — `ewas_harmonise` (`fbb7663c2818`), `ewas_dmr_ml`
  (`24ca6c21e06a`) and `ewas_blocks_hsmm` (`63349e961d40`), each revision 0,
  tool version 0.1.0. The shed parsed all three as valid tools with no invalid
  tools, which confirms `macros.xml` resolves in each per-tool repository:
  `@TOOL_VERSION@` expanded and the macro's requirement set came back in the
  install info. `owner:` is the shed account, which is not the GitHub account
  this repository sits under.

- Initial extraction of the Galaxy tool suite from upstream commit
  `e4c54cf334b995599bb6a21320ac99f85bc72dc7`: `ewas_harmonise`,
  `ewas_dmr_ml` and `ewas_blocks_hsmm` (tool version 0.1.0, profile 23.0),
  `macros.xml`, the four R drivers they call, the synthetic test fixtures, and
  `tests/run_galaxy_tool_tests.py`.
- `.shed.yml` with `auto_tool_repositories`, so the suite publishes as one
  repository per tool, and `planemo shed_lint --tools --ensure_metadata` in CI.
- CI runs `planemo lint --fail_level error` on all three wrappers and
  `planemo test --no_dependency_resolution` on the two that carry `<tests>`,
  against a micromamba environment holding the R requirements. A failing
  planemo run echoes its tail as a check annotation, since the raw step log is
  download-only.
- `sync-from-pipeline.sh`, which refreshes the wrappers, drivers, fixtures and
  runner from an upstream checkout and applies the one rewrite this repository
  needs.

### Changed

- The wrappers call the drivers through `$__tool_directory__/scripts/` instead
  of upstream's `$__tool_directory__/../bin/`, so a published tool repository
  references nothing outside itself.
