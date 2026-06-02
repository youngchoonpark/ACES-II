# ACES II — Contributor Notes & Working Guidelines

Read this when you start non-trivial work on the repository. It is **not** auto-loaded;
consult it as needed (this is a shared, multi-contributor project).

## Documenting work (please follow)

For every change set, create or update a documentation folder before considering the
task done:

- **Path:** `docs/<NN>-<topic>-<YYYY-MM-DD>/` — prefix a **two-digit sequence number**
  `NN` (`01`, `02`, …, next after the highest existing one) so the folders read in order,
  and **include the date, day included** (e.g. `docs/01-gfortran-port-2026-05-30/`).
- **Contents:**
  - A notes file (`PORTING-NOTES.md` or similar), written in **English**, containing:
    - a summary and the environment context;
    - for every changed file: its **location**, a **description of the change
      (cause → fix)**, and the file's **modification timestamp** (`stat -c '%y' <file>`);
    - build/run results and any remaining work;
    - organized so collaborators can review all changes at once.
  - `changes.patch` — the full `git diff`, so collaborators can review/apply it.
- **Reference example:** `docs/01-gfortran-port-2026-05-30/`.

## Build environment (critical)

ACES II must be cloned and built on a **case-sensitive filesystem** (e.g. ext4).
The repository contains ~20 file pairs that differ only in case (`foo.F` / `foo.f`),
and the `.F → cpp → .f` build step collapses/destroys sources on a case-insensitive
filesystem (Windows `/mnt/*`, default macOS).

The host is auto-detected by the makefiles, so no `MACHSTATS` entry is needed
(`gmake` works with no arguments; override with e.g. `gmake CMPLR=intel`).
**See `docs/BUILD.md` for the step-by-step build guide**, and
`docs/01-gfortran-port-2026-05-30/PORTING-NOTES.md` for the porting history.

## Open items (TODO)

- gfortran 13 port (compile): **COMPLETE — every directory compiles, 81 executables in
  `bin/x*`.** See `docs/01-gfortran-port-2026-05-30/` and
  `docs/02-category2-port-2026-05-31/` (build-system fixes + per-file source fixes, incl. the
  `extiface` — formerly `alice_nwchem` — d-function rewrite and rename).
- gfortran 13 port (runtime): **IN PROGRESS — full regression suite now at 119 PASS / 182**
  (`test/TEST-RESULTS.md`, run via `test/triage.sh`). The build runs and the 4-byte-integer /
  non-PIE model is in place (`docs/03-runtime-port-2026-06-01/`); subsequent fixes:
  - **docs/04** — ECP: symmetric `NMPROTON` via JOBARC `COMPPOPV` (`@OCCUPY-F`), `C2DIIS` for
    a hard Cu₂O₂²⁺ SCF. (+2 → 114)
  - **docs/05** — DFT/KS: `KSPRINT` logical & `NREALATM` integer read/written as `iintfp`
    words (should be length 1) — de-crashed all 8 xintgrt tests. (+3 → 117)
  - **docs/06** — DFT grid **gfortran `-O2` core-array aliasing miscompile**: the inner
    angular-loop bound `kscore(pgrdangpts+grid-1)` was cached across the `oct()` call that
    rewrites it, collapsing the grid (density → ~0). Fixed with `volatile kscore` in 4 grid
    drivers (`numintint`/`setnumint`/`numinteff`/`numintAG`). (+3 → 118)
  - **docs/07** — same `-O2` aliasing class via dummy-argument aliasing in `vksdint/equi.F`
    (the KS-gradient symmetry map); `volatile kscore,comp,comppov,e`. (+1 → 119)
  - **Remaining real defects (~38):** see `test/TEST-RESULTS.md`. Largest groups: **MRCC**
    (14, `xmrcc`/`xvip`/`xvee`), **FNO** (5, `xvtran`), `xvcc @GETLST(1,61)` (3), high-order
    CC `138/139` (`xvmol2ja`), `028/029/032`, `128` (`xdens`); **REAL** (8: `044`, `048b`,
    6× mrcc); **open-shell HF-DFT gradient** `142–144` (logic defect, not `-O2`) and
    `134e.ecp` (garbage ECP gradient). Plus 3 MRCC **HANGs** (`070/082/095`, numerically
    correct but a non-terminating `xvip` loop) and benign DRIFT/SETUP/NONCONVERGE.
- Two defects found while making a fresh clone buildable were also fixed in docs/03: 114
  committed makefile symlinks pointing to a dead `/home/perera/...` path, and `docs/` being
  auto-built. (A clean checkout did **not** build before these.)
- Consider cleaning up the ~20 case-only-differing `.f`/`.F` pairs
  (see `docs/01-gfortran-port-2026-05-30/PORTING-NOTES.md` §0).
- Consider removing the committed Intel-ifort artifact `blockdave/eig__genmod.{f90,mod}`.
- Consider un-committing the per-directory `GNUmakefile`/`GNUmakefile.src` symlinks (the
  top-level makefile regenerates them) and `.gitignore`ing them.
