# Running these tools in a local Galaxy

Three routes, in increasing order of how much they resemble a production
install. Route A is the fastest way to see the forms; route B is the one that
tests what was actually published; route C is the one where every dependency
resolves on Apple silicon. Written against planemo 0.75.47.

## A. planemo serve (start here)

1. **Prerequisites.** Command-line git (`xcode-select --install`), Python
   3.11 or 3.12, and about 6 GB free disk. Galaxy's own virtualenv and a
   mirror of its repository both land under `~/.planemo`.
2. **Install planemo** in its own environment, not into system Python:

   ```sh
   python3 -m venv ~/venvs/planemo
   source ~/venvs/planemo/bin/activate
   pip install planemo
   ```
3. **Clone this repository** and start it:

   ```sh
   git clone https://github.com/bioinfbrad/ewas-crossarray-harmonise
   cd ewas-crossarray-harmonise
   ./serve.sh
   ```
4. **Wait out the first boot.** planemo mirrors `galaxyproject/galaxy`
   (~950 MB), checks out a working tree, builds a virtualenv and runs the
   database migrations. Ten to twenty minutes on a first run; about a minute
   on later ones, since the mirror is cached.
5. **Open <http://127.0.0.1:9090>.** No login is required — planemo serves
   with an admin user it configures itself (`--galaxy_email` overrides the
   address). The three tools appear in the tool panel.
6. **Upload the fixtures.** `serve.sh` prints the list on startup; they are
   the same five files the tool tests use, from `test-data/`: `test_mval.f64`,
   `test_mval_dims.json`, `test_pheno.csv`, `test_anno.csv`,
   `test_probe_map.csv`. Feed them to *EWAS DMR (ML region finder)* or
   *EWAS blocks (distance-aware HSMM)*.
7. **Make jobs actually run.** The default is `--no_dependency_resolution`:
   forms, parameter trees and conditionals are all live, but a submitted job
   fails for want of R packages. Two ways out:

   ```sh
   DEPS=conda ./serve.sh                            # resolve through bioconda
   R_LIBS_USER=/path/to/lib DEPS=hostR ./serve.sh   # use an R library you have
   ```

   On Apple silicon `DEPS=conda` resolves `ewas_dmr_ml` and
   `ewas_blocks_hsmm` but **not** `ewas_harmonise`. Both halves of that are
   now measured rather than assumed. The first: the pin set those two tools
   ask for — R 4.5, `bioconductor-limma` 3.66.0, Matrix, optparse, jsonlite —
   solves and installs on `osx-arm64` here, which is why the macro pins that
   exact set and not the R 4.4 pairing it used to (limma 3.62.0 has no
   `osx-arm64` build). The second: `bioconductor-minfi` is `noarch`, so it is
   not itself the obstacle — it requires `bioconductor-illuminaio`, which has
   no `osx-arm64` build at any version, and the solve fails there. One arm64
   build of that recipe, with whatever it cascades into, is what would unblock
   the tool. `DEPS=hostR` is the way around it — point it at a library where
   you installed minfi yourself (`BiocManager::install`, which builds from
   source for arm64) and Galaxy inherits that environment. The script checks
   the library for minfi, limma, Matrix, optparse and jsonlite and names
   whatever is absent before booting.
8. **Stop with Ctrl-C.** Each `serve.sh` run is a fresh Galaxy with a fresh
   history; pass `--file_path` and `--database_connection` through to planemo
   if you want state to survive a restart.

## B. A real Galaxy, tools installed from the Tool Shed

This is the route that tests the published artifact rather than the working
copy — a shed install resolves `macros.xml` from inside each per-tool
repository, which a local checkout never exercises.

1. Clone a release branch and boot it once so it builds its virtualenv
   (`git branch -r --list 'origin/release_*'` lists what is current; 26.1 at
   the time of writing):

   ```sh
   git clone -b release_26.1 https://github.com/galaxyproject/galaxy
   cd galaxy && sh run.sh
   ```
2. Stop it, set `admin_users` in `config/galaxy.yml` to the address you will
   register, restart, and register that account in the web UI.
3. Add the Test Tool Shed to `config/tool_sheds_conf.xml` (copy the `.sample`
   and add an entry whose URL is `https://testtoolshed.g2.bx.psu.edu`), then
   restart again.
4. **Admin → Tool Management → Install new tools**, search owner
   `kkamieniecka` for `ewas_harmonise`, `ewas_dmr_ml` and
   `ewas_blocks_hsmm`, and install each with its dependencies. The
   `osx-arm64` limitation above applies to the conda environments Galaxy
   builds during that install too.

## C. Docker, if you want minfi resolved rather than compiled

The `bgruening/galaxy-stable` images are `linux/amd64`, so on Apple silicon
they run under emulation — slower, but conda then resolves `linux-64`, where
`bioconductor-minfi` has prebuilt packages. Mount the checkout into the
container's tool tree:

```sh
docker run -d -p 8080:80 \
  -v "$PWD:/galaxy-central/tools/ewas:ro" \
  quay.io/bgruening/galaxy-stable
```

then either add the three XML files to a section of the container's
`tool_conf.xml`, or install from the shed as in route B from inside the
container.

## Which route answers which question

| question | route |
|---|---|
| does the form behave, are the conditionals right | A |
| do the tool tests pass | `./test.sh`, or CI |
| does the published shed revision install cleanly | B |
| does `ewas_harmonise` run end to end on this laptop | A with `DEPS=hostR`, or C |
