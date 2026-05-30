# ACES II — gfortran 13 Port, Category 2 (blockdave, pccd, and cascade)

- **Date**: 2026-05-31
- **Scope**: continue the gfortran 13 port into the "Category 2" directories that
  failed to build whole-directory, starting with `blockdave`, then `pccd`, and the
  programs they unblock by linkage.
- **Build environment**: Ubuntu 24.04 / WSL2, gfortran 13.3.0, GNU Make 4.3, host `CCSDT-1`
  (case-sensitive ext4 clone — see [the case-sensitivity caveat](../gfortran-port-2026-05-30/PORTING-NOTES.md)).
- **Result**: working executables **72 → 79** (`bin/x*`). The pCCD / block-Davidson EOM
  programs and their dependents now build: `xpccd`, `xpccd_drpmo`, `xpsi4dbg`, `xvee`,
  `xrunpccd`, plus `xget_acesinfo`/`xget_acesmo`/`xpdens`/`xtdee`.

Follows the previous porting work in `docs/gfortran-port-2026-05-30/`.
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

## 5. Remaining work (still failing)

| Directory | Failing .o | Notes |
|---|---|---|
| `alice_nwchem` | 8 | NWChem interface — optional; only needed when interfacing with NWChem. |
| `mopac` | 1 | Undefined reference to `date_` — a legacy `DATE()` intrinsic gfortran does not provide. Needs a small wrapper (e.g. via `date_and_time`) or replacement. `mopac` is a standalone semi-empirical driver. |

---

## 6. Build & commit notes

- Built and verified on the case-sensitive ext4 build tree; libraries install to `lib/`,
  executables to `bin/`.
- Authored in a clean commit clone; `git status` shows exactly the 23 files in
  `changes.patch`. The build-system fix in §1 benefits every free-form source across the
  whole tree, so expect it to help future Category-2 directories too.
