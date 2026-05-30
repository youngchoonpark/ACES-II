# ACES II — gfortran 13 Port, Category 2 (blockdave, pccd, and cascade)

- **Date**: 2026-05-31
- **Scope**: continue the gfortran 13 port into the "Category 2" directories that
  failed to build whole-directory, starting with `blockdave`, then `pccd`, and the
  programs they unblock by linkage.
- **Build environment**: Ubuntu 24.04 / WSL2, gfortran 13.3.0, GNU Make 4.3, host `CCSDT-1`
  (case-sensitive ext4 clone — see [the case-sensitivity caveat](../01-gfortran-port-2026-05-30/PORTING-NOTES.md)).
- **Result**: working executables **72 → 81** (`bin/x*`), and **every directory now
  compiles with gfortran 13 — no failing directories remain.** Newly building:
  `xpccd`, `xpccd_drpmo`, `xpsi4dbg`, `xvee`, `xrunpccd`, `xmopac`, the NWChem interface
  `alice_nwchem`, plus `xget_acesinfo`/`xget_acesmo`/`xpdens`/`xtdee`.

Follows the previous porting work in `docs/01-gfortran-port-2026-05-30/`.
Full diff: `changes.patch` (23 files, +41 / −25; apply with `git apply`).

---

## 1. Build-system change (1 file) — fixes ALL free-form `.f90`/`.f95` sources

The biggest win was a build-system fix, not source edits: it resolved the bulk of the
Category 2 failures at once (e.g. `nddo` ~82, `blockdave` ~37, `liboo` ~5 were almost
entirely this).

| File | Modified | Change |
|---|---|---|
| `Makefiles/GNUmakefile` | 2026-05-31 00:47 | In the gnu branch: ① `MODDIRS_PREFIX = -I` — gfortran searches module/include dirs with `-I`, not the default `-M` (which it rejects as `unrecognized command-line option '-M../include'` when compiling `.f90`/`.f95`). ② Added `F9XFLAGS` mirroring `FFLAGS` (`-fno-second-underscore -finit-local-zero -fno-range-check -fdefault-integer-8 -fallow-argument-mismatch -std=legacy`). Free-form sources are compiled with `F9XFLAGS`, which was previously empty, so `.f90` files were built with 4-byte integers (ABI-inconsistent with the 8-byte `.F`/`.f` objects) and without the loose-interface tolerance. |

> Root cause of the inflated failure counts in the build log: when `gmake` stops at the
> first error in a directory, every later file shows "not built", so a directory with a
> couple of real issues can appear to have dozens of failures. Surveying with per-file
> compiles gives the true count.

---

## 2. blockdave (5 source files)

`block-Davidson` library. After the build-system fix above, only these real source
issues remained:

| File | Modified | gfortran error | Cause / fix |
|---|---|---|---|
| `blockdave/blockdavid_init.F` | 00:40 | Cannot convert LOGICAL to REAL | `CISfilterFlag = .True.` with `Implicit Double Precision`; declared it in the existing `Logical … , CISfilterFlag`. |
| `blockdave/nlsZero.F` | 00:40 | DATA CHARACTER→INTEGER | `DATA BLANK /" "/` with `IMPLICIT INTEGER`; declared `CHARACTER*1 BLANK`. |
| `blockdave/nlsZeroPartTwo.F` | 00:40 | DATA CHARACTER→INTEGER | same as nlsZero. |
| `blockdave/NLMOcorrect.f90` | 00:45 | EXIST tag must be LOGICAL | `INQUIRE(...,EXIST=NLS_EXIST/NBO_EXIST)`; declared both LOGICAL. |
| `blockdave/filterRoots.f90` | 00:45 | EXIST tag must be LOGICAL | same as NLMOcorrect. |

> Note: `blockdave/eig__genmod.{f90,mod}` are Intel-ifort COMPILER-GENERATED interface
> stubs (dated 2021) committed by mistake; they are orphaned (nothing `USE`s them) and
> compile harmlessly under gfortran. Candidate for cleanup (not touched here).

---

## 3. pccd (16 source fixes across 12 files)

`pCCD` library/program. All failures were LOGICAL/INTEGER/REAL typing or a syntax slip:

| File | Modified | Issue → fix |
|---|---|---|
| `pccd/pccd_checkintms.F` | 00:53 | `.NOT. Ao_lad` (INTEGER) → declare `Ao_lad` LOGICAL. |
| `pccd/pccd_dens.F` | 00:53 | `If (Nonhf_ref)` → declare `Nonhf_ref` LOGICAL. |
| `pccd/pccd_e4s.F` | 00:53 | `IF(NONHF)` → declare `NONHF` LOGICAL. |
| `pccd/pccd_genint.F` | 00:53 | `IF(NONHF)` → declare `NONHF` LOGICAL. |
| `pccd/pccd_rotate.F` | 00:53 | `IF (DIIS)` → declare `DIIS` LOGICAL. |
| `pccd/pccd_urdriver.F` | 00:53 | `IF (LINCC)` → declare `LINCC` LOGICAL. |
| `pccd/pccd_g3all.F` | 00:53 | `DIMENSION T1(DISSYT,…)` with REAL `DISSYT` → declare `INTEGER DISSYT,NUMSYT`. |
| `pccd/pccd_quad2.F` | 00:53 | `CALL INSMEM("PCC_QUAD2",,MAXCOR)` — empty 2nd argument → supply `I004` (the needed-memory size, per the `IF(I004.LT.MAXCOR)…ELSE` pattern). |
| `pccd/pccd_uldriver.F` | 00:57 | `TERM1..TERM6 = .TRUE./.FALSE.` → declare `TERM1..TERM6` LOGICAL (only TERM1 was declared). |
| `pccd/pccd_form_dropmo_urotgrads.F` | 00:57 | `Bredundant`, `QCID`, `M4DSQ` assigned `.TRUE./.FALSE.` but undeclared → declare LOGICAL. (`M4DSQ` is a misspelling of the declared `M4SDQ`; declared as-is to preserve behavior rather than rename.) |
| `pccd/pccd_form_urotgrads.F` | 00:57 | same as form_dropmo_urotgrads. |
| `pccd/pccd_gfock_debug.F` | 00:57 | same as form_dropmo_urotgrads. |

---

## 4. Cascade unblocked (vee, runpccd, get_acesinfo)

With `blockdave` and `pccd` built, the dependent programs linked — after these last
source fixes:

| File | Modified | Issue → fix |
|---|---|---|
| `vee/form_genrlizd_tdens.F` | 01:03 | Undefined symbol `check_tdens_lists_` at link. The two calls are inside `#ifdef _DEBUG_LVL0` (which this build defines) but the routine is **not defined anywhere in the tree** — incomplete debug instrumentation. Commented out the two diagnostic calls (no effect on results). |
| `runpccd/do_natural_orbs.F` | 01:02 | `(geom_opt.or.vib_specs).and.analytical_gradient` with `implicit integer` → declare the three LOGICAL. |
| `runpccd/run_opt.F` | 01:07 | `szGExtrap = 'xa2proc grad_extrp'` assigned to an implicit REAL (dead variable) → declare `character*80 szGExtrap`. |
| `runpccd/job_control.F` | 01:10 | (a) `If (Drop .Gt. 0)` — `Drop` was wrongly in a `Logical` list → removed so it is INTEGER. (b) `pCCDTS`/`pCCDTSD` (set from `Pccd_calc==56/58`, used widely) were undeclared → declared LOGICAL. (c) declaration typo `Act_amps_exsit` → `Act_amps_exist` (the spelling actually used by the `INQUIRE(...,EXIST=)`). |
| `get_acesinfo/get_moinfo.f90` | 01:02 | `yesno==.false.` (LOGICAL compared with `==`) → `.not.yesno`. |

---

## 4b. mopac (1 new file) and alice_nwchem (2 source fixes)

| File | Modified | Issue → fix |
|---|---|---|
| `mopac/date_gfortran.f` (new) | 01:19 | `CALL DATE(IDATE)` (legacy Unix date routine, `IDATE` is `CHARACTER*24`) was an undefined reference `date_` — gfortran has no `DATE` intrinsic. Added a `SUBROUTINE DATE(STR)` wrapper that calls the `FDATE` intrinsic (returns a 24-char date string). `xmopac` now builds. |
| `alice_nwchem/civec.f90` | 01:30 | Format `'(/,a,i)'` (no width on `i`) → `'(/,a,i5)'` (4 occurrences). |
| `alice_nwchem/civec2.f90` | 01:30 | same as civec.f90 (7 occurrences). |

## 4c. extiface (formerly alice_nwchem) — d-function transform rewrite + module order

This directory (the external-program interface; renamed from `alice_nwchem` — see §7) was
the last failing directory. Two parts:

**(a) `alice_nwchem/function.f90` — rewrote the d-function cart↔sph transform.**
It declared `double precision mat_d(36)` but initialised it via `DATA` with fraction
**strings** (`'1/2'`, `'1/3'`, `'-1/6'`, …) and used them numerically
(`mat(i,j)=mat_d(ind)`) — so it never compiled. The matrices were transcribed from the
file's own comments (a standard unnormalized real solid-harmonic convention) into proper
numeric Fortran:
  - `cart2sph` (all integers): `d0 = 2zz−xx−yy`, `d-2 = xy`, `d+1 = xz`, `d+2 = xx−yy`,
    `d-1 = yz`, and the 6th row the `r² = xx+yy+zz` s-contaminant.
  - `sph2cart` (its inverse with the s-contaminant set to zero, i.e. pure 5d):
    `xx = −d0/6 + d+2/2`, `yy = −d0/6 − d+2/2`, `zz = d0/3`, `xy = d-2`, `xz = d+1`,
    `yz = d-1`. Verified by inverting the cart2sph matrix.
  - Both use F90 array constructors; the fractions are `double precision, parameter`
    values (`o2=1d0/2d0, o3=1d0/3d0, o6=1d0/6d0`) evaluated exactly at compile time
    (no precision loss, unlike a decimal `DATA`).

**(b) Module build order — `Makefiles/GNUmakefile.src`.**
The directory uses Fortran 90 modules
(`mod_fun`/`mod_print` → `mod_get_aces2`/`mod_civec`/`mod_info`/`mod_movec` → `mod_aovec`
→ `mod_job` → `extiface`). FAST mode does not compute module deps, so an
`ifeq (${CURR},extiface)` block sets the topological compile order via `OBJ`
(mirroring the existing `asv` block):
`OBJ := function.o print.o get_aces2.o civec.o nwchem_info.o movec.o aovec.o civec2.o job.o extiface.o`.

Also `civec.f90`/`civec2.f90` had the `'(/,a,i)'` width-less format fixed to `'(/,a,i5)'`.

## 5. Status — full build

**Every directory now compiles with gfortran 13; no failing directories remain.**
81 executables in `bin/x*`, libraries in `lib/`.

Optional follow-ups (not required for the build):
- Clean up the ~20 case-only-differing `.f`/`.F` pairs (see `../01-gfortran-port-2026-05-30/PORTING-NOTES.md` §0).
- Remove the committed Intel-ifort artifact `blockdave/eig__genmod.{f90,mod}`.

---

## 7. Directory rename: `alice_nwchem` → `extiface`

The directory held only an NWChem reader but is intended to grow into the home for
interfaces to several external QC programs (NWChem, GAMESS, …), so it was renamed to the
program-neutral `extiface` (ACES already has a separate `gamess` directory, so a
program-specific name would be misleading). `git mv` preserves history. Changes:

- `git mv alice_nwchem extiface`.
- `git mv extiface/alice_nwchem.f90 extiface/extiface.f90` — the main program file must
  match the directory name, since the binary is `x<dir>` and the main object is `<dir>.o`.
  Updated `program alice_nwchem` / `end program alice_nwchem` → `… extiface`.
- `Makefiles/GNUmakefile.src`: the module-order block now keys on
  `ifeq (${CURR},extiface)` and lists `extiface.o` (was `alice_nwchem.o`).
- Removed build artifacts that had been committed by mistake under the directory:
  `*.mod` (compiled Fortran modules) and a stray `.print.f90.swp` (vim swap file).
- Result: builds and installs as `bin/xextiface`; the rest of the tree is unaffected
  (the directory is auto-discovered by the top-level makefile and is not referenced by
  name anywhere else).

Internal Fortran module names (`mod_fun`, `mod_job`, …) were left unchanged — they are not
tied to the directory name.

---

## 6. Build & commit notes

- Built and verified on the case-sensitive ext4 build tree; libraries install to `lib/`,
  executables to `bin/`. Full diff: `changes.patch` (source/build fixes plus the
  `alice_nwchem` → `extiface` rename, §7).
- The build-system fixes (§1 `MODDIRS_PREFIX`/`F9XFLAGS`, §4c module order) benefit every
  free-form source across the whole tree, not just these directories.
