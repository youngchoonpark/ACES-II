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

- gfortran 13 port: **COMPLETE — every directory compiles, 81 executables in `bin/x*`.**
  See `docs/01-gfortran-port-2026-05-30/` and `docs/02-category2-port-2026-05-31/` for the full
  record (build-system fixes + per-file source fixes, including the `extiface` —
  formerly `alice_nwchem` — d-function transform rewrite and the directory rename).
- Consider cleaning up the ~20 case-only-differing `.f`/`.F` pairs
  (see `docs/01-gfortran-port-2026-05-30/PORTING-NOTES.md` §0).
- Consider removing the committed Intel-ifort artifact `blockdave/eig__genmod.{f90,mod}`.
