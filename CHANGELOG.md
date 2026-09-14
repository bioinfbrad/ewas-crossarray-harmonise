# Changelog

Tool versions follow `@TOOL_VERSION@` in `macros.xml`; this file records
changes to the packaging. The methods themselves are developed upstream at
[kkamieniecka/ewas-crossarray-harmonise](https://github.com/kkamieniecka/ewas-crossarray-harmonise),
whose changelog carries the numerical history.

## [Unreleased]

### Added

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
