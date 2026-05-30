# ACES II — Contributor Notes & Working Guidelines

Read this when you start non-trivial work on the repository. It is **not** auto-loaded;
consult it as needed (this is a shared, multi-contributor project).

## Documenting work (please follow)

For every change set, create or update a documentation folder before considering the
task done:

- **Path:** `docs/<topic>-<YYYY-MM-DD>/` — the directory name **must include the date,
  day included** (e.g. `docs/gfortran-port-2026-05-30/`).
- **Contents:**
  - A notes file (`PORTING-NOTES.md` or similar), written in **English**, containing:
    - a summary and the environment context;
    - for every changed file: its **location**, a **description of the change
      (cause → fix)**, and the file's **modification timestamp** (`stat -c '%y' <file>`);
    - build/run results and any remaining work;
    - organized so collaborators can review all changes at once.
  - `changes.patch` — the full `git diff`, so collaborators can review/apply it.
- **Reference example:** `docs/gfortran-port-2026-05-30/`.

## Build environment (critical)

ACES II must be cloned and built on a **case-sensitive filesystem** (e.g. ext4).
The repository contains ~20 file pairs that differ only in case (`foo.F` / `foo.f`),
and the `.F → cpp → .f` build step collapses/destroys sources on a case-insensitive
filesystem (Windows `/mnt/*`, default macOS).

The host is auto-detected by the makefiles, so no `MACHSTATS` entry is needed
(`gmake` works with no arguments; override with e.g. `gmake CMPLR=intel`).
See `docs/gfortran-port-2026-05-30/PORTING-NOTES.md` for the full build procedure and history.

## Open items (TODO)

- Port the remaining "Category 2" directories that still fail to compile with gfortran 13:
  `nddo` (82), `blockdave` (43), `pccd` (13), `alice_nwchem` (10), `get_acesinfo` (6),
  `get_acesmo` (5), `liboo` (5). Fixing `blockdave` and `pccd` also unblocks the link
  cascade for `vee`, `mopac`, `psi4dbg`, `pccd_drpmo`, `runpccd`.
- Consider cleaning up the ~20 case-only-differing `.f`/`.F` pairs (see PORTING-NOTES §0).
