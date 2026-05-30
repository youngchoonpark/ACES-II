# ACES II — Build-System Modernization & gfortran 13 Port

- **Dates**: 2026-05-30 to 2026-05-31
- **Scope**: improve build-system (makefile) portability + port legacy Fortran so it
  compiles with gfortran 13
- **Build environment**: Ubuntu 24.04 / WSL2, gfortran 13.3.0, GNU Make 4.3, host `CCSDT-1`
- **Result**: working executables **49 → 71** (the full CC/EOM suite was revived), 99 libraries

This document lets a collaborator review every change at once. The complete diff is in
`changes.patch` in this directory (apply with `git apply`).

---

## 0. Most important caveat — filesystem case sensitivity

The ACES II repository contains **20 pairs of files that differ only in case** (`foo.F` and
`foo.f` coexist as separate entries in the git index):

```
Test/dip/pre_dip_process.{F,f}      dens/Keep/pdcc_checkgam.{F,f}
Test/io_timer/end_time.{F,f}        dens/Keep/pdcc_into1.{F,f}
Test/io_timer/load1.{F,f}           dens/Keep/pdcc_intv1.{F,f}
Test/io_timer/main.{F,f}            dens/Keep/pdcc_io1aa.{F,f}
Test/io_timer/start_time.{F,f}      dens/Keep/pdcc_io1ab.{F,f}
Test/io_timer/triiii.{F,f}          dens/Keep/pdcc_iv1aa.{F,f}
Test/mt/main.{F,f}                  dens/Keep/pdcc_iv1ab.{F,f}
joda/save/built_bgmtrx.{F,f}        dens/Keep/pdcc_spinad1.{F,f}
libr2/old/pdcc_h4inx2_1.{F,f}       vksdint/old/func_exch_becke.{F,f}
libr2/old/pdcc_h4inx2_2.{F,f}
libr2/old/pdcc_h4inx2_3.{F,f}
```

**Conclusion: always clone and build on a case-sensitive filesystem (e.g. ext4).**
- Windows drives (`/mnt/c`, NTFS/DrvFS) and the default macOS filesystem are case-insensitive,
  so each of the 20 pairs collapses into a single file — correct checkout and build become
  **impossible**.
- In addition, the ACES build converts `.F` (source) → `cpp` → `.f` (compilation unit). On a
  case-insensitive filesystem `.F` and `.f` are the same file, so the preprocessing rule
  (`rm $@; cpp $< $@`) **destroys the source**.

> These 20 pairs look like leftovers from past development. Long-term, consider cleaning up the
> duplicate `.f` files under the `*.skip` / `old` / `Keep` / `save` directories (or `.gitignore`
> them). They are intentionally **not** part of this commit.

---

## 1. Recommended build procedure (verified workflow)

```sh
# 1) Clone onto a case-sensitive filesystem (ext4)
git clone <repo> ~/program/aces2/ACES-II
cd ~/program/aces2/ACES-II

# 2) Prepare the build environment (creates lib/ bin/, links the top-level makefile)
chmod +x xprep xskip xunskip xpromote     # exec bits may be lost when cloning via /mnt/c
./xprep -f

# 3) Build (host is auto-detected — no MACHSTATS entry needed)
gmake          # or `gmake -k` to collect all errors
```

Build products: `bin/x*` (executables), `lib/*.a` (libraries).

---

## 2. Build-system changes (5 files)

Previously the build looked up the `uname -n` hostname in a hard-coded `MACHSTATS` table to
choose the compiler / OS / architecture; an unlisted host aborted with
`$(error compiler undefined)`. The per-directory makefile symlinks were also committed with the
original developer's absolute paths (`/home/perera/...`), which are not portable. Changes:

| File | Modified | Change |
|---|---|---|
| `Makefiles/GNUmakefile` | 2026-05-30 21:45 | ① When the host is not in `MACHSTATS`, **auto-detect ARCH·OPSYS·CMPLR** from `uname -s` / `command -v gfortran\|ifort\|pgf90` / `uname -m` (replacing the `$(error)`). ② gnu/X86_64: `-march=amdfam10` → overridable `-march=${MARCH}` (default `native`). ③ Added `-fallow-argument-mismatch -std=legacy` for gfortran 10+. ④ Fixed typos: `$(forearch …)`→`$(foreach …)`, `vibavg:…:ibr2:`→`libr2`. |
| `makefile` | 2026-05-30 21:40 | Sub-directory makefile symlinks now use a **relative `ln -sr`** instead of an absolute `ln -s` (portability). |
| `Makefiles/GNUmakefile.tl` | 2026-05-30 21:40 | Same `ln -sr` change. |
| `Makefiles/GNUmakefile.src` | 2026-05-30 21:40 | Replaced the original developer's (QTP) absolute paths (`/home/perera/...`, MKL paths) with a **portable local configuration** (relative `-L./lib -L../lib` with `-llinpack -leispack -llb`). Functional defines (`-D_ASSERT -D_DOUG_KROLL …`) are preserved. |
| `Makefiles/GNUmakefile.src.example` (new) | 2026-05-30 21:40 | Preserves the original QTP `.src` configuration as a **reference template**. |

> Note: host `CCSDT-1` is absent from `MACHSTATS`, but auto-detection selects
> `gnu / X86_64 / linux`, so `gmake` works with no arguments. Auto-detected values can always be
> overridden, e.g. `gmake CMPLR=intel`.

---

## 3. Legacy Fortran → gfortran 13 source fixes (14 files)

gfortran 10+ rejects, as **errors**, several non-standard constructs that older compilers
tolerated. Every fix below preserves behavior (types matched to actual use; dead stores / dead
code left intact; output formatting unchanged) and was verified by compiling the file.

| File | Modified | gfortran error | Cause / fix |
|---|---|---|---|
| `vcc/checkintms.F` | 05-30 22:31 | Operand of `.NOT.` is INTEGER(8) | `Implicit Integer(A-Z)` made `Ao_lad` an integer. It is a logical flag, so declared `Logical UHF, Ao_lad`. |
| `vee/form_genrlizd_tdens.F` | 05-30 22:35 | `.or.` on LOGICAL/INTEGER | A stray `LOGICAL` keyword in the middle of the declaration (`…DRCCD,LOGICAL LCCD,…`) dropped `LCCD` (fixed-form blank insignificance). Removed the duplicate keyword; now matches `COMMON/REFTYPE/`. |
| `scrnc/scrnc_form_rcc_hbar.F` | 05-30 22:42 | `.or.` on LOGICAL/INTEGER | Declaration typo `EOM_SFDRCC` (missing trailing D) → corrected to the used name `EOM_SFDRCCD`. |
| `scrnc/scrnc_lrspn_cc_main.F` | 05-30 23:46 | Nonnegative width required | Format `"(3a,1x,5I,2I)"`; `5I,2I` is illegal → `I5,I2` for the two integers (`Iao_pair,Irrepx`). |
| `scrnc/scrnc_prep_culomb_ints.F` | 05-30 23:49 | Nonnegative width required | `"(a,a,i5,i)"`; the trailing `i` has no width → `i5`. |
| `aux/job_control.F` | 05-30 23:13 | Cannot convert LOGICAL to REAL | `Fcr = .False.` but `Fcr` was implicitly REAL. It is a write-only dead variable; declared `Logical … Fcr`. |
| `vdint/readin.F` | 05-30 23:17 | DATA has more variables than values (×2) | `MXQN=8` (L≤7) but labels were short: added angular-momentum letter `'k'` to `ISPD(8)`; `KWO(120)` uses implied-DO `(KWO(I),I=1,84)` to initialize only the existing 84 (no k-function labels, identical to the original). |
| `vcceh/factor.F` | 05-30 23:19 | DATA has more variables than values | `ANAME(100)` had only 45 values → implied-DO `(ANAME(I),I=1,45)`. |
| `vcceh/factor_is.F` | 05-30 23:44 | DATA has more variables than values (×4) | `GTAB_R/GTAB_S/ANAME_R/ANAME_S` (all dim 100) had 50/63/45/55 values → exact partial initialization via implied-DO for each. |
| `libint/built_symtran.F` | 05-30 23:20 | Array subscript is REAL | `Implicit Double Precision(A-H,O-Z)` made the argument `Dmaxcor` REAL. It is a work-array size, so added `Integer Dmaxcor`. |
| `tdcc2/tdcc_driver.F` | 05-30 23:30 | WRITE syntax error + LOGICAL→REAL | Missing comma between two strings in `Write(…,"(a,a)")` → added; declared `Sing` LOGICAL (`Sing = .False.`). |
| `oprots/oprots_driver.F` | 05-30 23:35 | WRITE syntax error (×3) | Missing commas between output string items + a comma lost past column 72 → relocated the comma onto the continuation line (output unchanged). |
| `vibavg/form_2dprop_deriv_eq.F` | 05-30 23:46 | WRITE syntax error | Missing comma between two strings in `Write(…,"(2a)")` → added. |
| `psi4dbg/psi4dbg_rdriver.F` | 05-30 23:50 | IF clause requires a scalar LOGICAL | `INTL1 = .FALSE.` then `IF(INTL1)`, but `INTL1` was implicitly INTEGER → declared `Logical … INTL1` (always `.FALSE.`, so the THEN block is dead code). |

### Common patterns (for collaborators)
1. **LOGICAL/INTEGER/REAL mixing** — an `Implicit` rule makes a logical flag an integer/real →
   fix with an explicit `Logical` declaration.
2. **DATA has more variables than values** — the array dimension grew (e.g. `MXQN` was bumped)
   but the DATA value list did not → use implied-DO `(A(I),I=1,N)` to initialize only the values
   provided (preserves original behavior).
3. **Missing comma between WRITE output items** / **fixed-form column-72 overflow** —
   add/relocate the comma.
4. **Missing width in a format edit descriptor** (`5I` → `I5`) — supply the width.

---

## 4. Build results

- Working executables: **71** (`bin/x*`) — including the main driver `xaces2` and CC/EOM core:
  `xjoda xvscf xvmol xvtran xvcc xlambda xdens xhbar xvcceh xvdint xlibint xvcc5q …`.
- Libraries: 99 (`lib/*.a`).
- Build logs: `build*.log` in the working directory (not part of the commit).

---

## 5. Remaining work (out of scope here — "Category 2")

The following are larger, per-directory ports where many files fail. Fixing `blockdave` and
`pccd` will also resolve the **link cascade** for `vee`, `mopac`, `psi4dbg`, `pccd_drpmo`, and
`runpccd` (their own sources already compile).

| Directory | Failing .o | Notes |
|---|---|---|
| `nddo` | 82 | semi-empirical module (may need F90) |
| `blockdave` | 43 | block Davidson — blocks `vee`/`mopac` etc. |
| `pccd` | 13 | pCCD — blocks `psi4dbg`/`pccd_drpmo`/`runpccd` |
| `alice_nwchem` | 10 | NWChem interface (optional) |
| `get_acesinfo` / `get_acesmo` | 6 / 5 | utility / interface |
| `liboo` | 5 | orbital-optimization library |

---

## 6. Commit guidance

- These changes were authored in a **clean clone on a case-sensitive filesystem**. `git status`
  shows only the 19 files below (the 20 case-collision pairs from §0 check out correctly and do
  not appear as modified).
- Total change: 19 files, +168 / −54 lines. Full diff: `changes.patch`.
