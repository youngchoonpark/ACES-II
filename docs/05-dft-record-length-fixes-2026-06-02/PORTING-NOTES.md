# DFT/KS record-length fixes (xintgrt group) — 2026-06-02

## Summary

Investigated the eight KS/DFT regression tests, all of which crashed identically
(`died in xintgrt`): `104/105/106.ks`, `142/143/144.hfdft`, `145.ksgrad`,
`146.hfdft.ccsd`. The crashes were **two record-length-mismatch bugs of the same class
as the ECP `iintfp` bugs** (docs/04): a scalar read or written as `iintfp` integer words
(= 2 in the 4-byte-integer model; it was 1 only in the old 8-byte build), overrunning the
target by 4 bytes and corrupting adjacent memory. Both are fixed in code.

Result: the xintgrt group went **0/8 → 3/8 PASS** (`106.ks`, `145.ksgrad`,
`146.hfdft.ccsd`), and the whole suite **114 → 117 PASS / 182**. The other five no longer
crash; they are now blocked by a separate, deeper grid `-O2` numerical defect (below).

| test | before | after | note |
|---|---|---|---|
| `zmat.106.ks` | CRASH (xintgrt) | **PASS** | KSPRINT fix |
| `zmat.145.ksgrad` | CRASH (xintgrt) | **PASS** | KSPRINT fix |
| `zmat.146.hfdft.ccsd` | CRASH (xintgrt) | **PASS** | KSPRINT fix |
| `zmat.104.ks` | CRASH (xintgrt) | REAL | de-crashed; KS energy wrong (grid -O2 defect) |
| `zmat.105.ks` | CRASH (xintgrt) | REAL | de-crashed; KS energy wrong (grid -O2 defect) |
| `zmat.142.hfdft` | CRASH (xintgrt) | NONCONVERGE | de-crashed by KSPRINT+NREALATM; KS forces wrong (grid -O2) |
| `zmat.143.hfdft` | CRASH (xintgrt) | NONCONVERGE | same |
| `zmat.144.hfdft` | CRASH (xintgrt) | NONCONVERGE | same |

## Environment

- linux x86_64, gfortran 13, 4-byte-integer / non-PIE model (`iintfp = 2`,
  `F_ADR = integer*8`). See docs/03.
- `ECP_MAIN`-style record I/O bug class; cf. docs/04 (`@OCCUPY-F`) and docs/03 (PTGP/
  ECP1INTS record lengths). The common root is "a scalar handled as `iintfp` words".

## Changed files

### 1. `KSPRINT` — logical read/written as `iintfp` words (crash: `@RELPTR`)
- **Files / times:**
  - `intgrt/numintint.F` — `2026-06-02 17:04:44 +0900`
  - `intgrt/numinteff.F` — `2026-06-02 17:05:28 +0900`
  - `vscf/vscf.F` — `2026-06-02 17:05:21 +0900`
- **Cause:** `KSPRINT` stores a single `LOGICAL` flag. It was written
  (`putrec(...,'KSPRINT',iintfp,scfks)` in vscf) and read
  (`getrec(...,'KSPRINT',iintfp,print_post_ks)` in numintint/numinteff) using **`iintfp`**
  as the element count. A default `LOGICAL` is 4 bytes here, but `iintfp = 2` words = 8
  bytes, so the read overran `print_post_ks` by 4 bytes and clobbered the adjacent local
  `pnull` (the integer-stack null pointer), zeroing it. The end-of-routine
  `relptr(1,F_INTEGER,pnull)` then saw `pnull = 0 < i0` and aborted with
  `@RELPTR: invalid pointer`. In the old 8-byte build `iintfp = 1` and a default logical
  was 8 bytes, so it happened to match.
- **Diagnosis:** traced by printing `pnull` — correct (`230429481`) right after `setptr`,
  then `0` immediately after the `KSPRINT` getrec, with `iintfp = 2`.
- **Fix:** use element count **`1`** in all three calls (a logical = one default-integer
  word, correct in both the 4-byte and 8-byte models).

### 2. `NREALATM` — integer read as `iintfp` words (crash: `@GETREC` mismatch)
- **File / time:** `vksdint/vhfksdint.F` — `2026-06-02 17:12:27 +0900`.
- **Cause:** `NREALATM` is a single integer, written with length 1 in
  `joda/fetchz.F` (`PUTREC(...,'NREALATM',IONE,NREAL)`), but read in `vhfksdint.F` as
  `getrec(...,'NREALATM',iintfp,natom)` — `iintfp = 2` words ≠ the stored 1, so
  xvksdint aborted with `@GETREC: "NREALATM" record length mismatch` (the crash for
  142/143/144).
- **Fix:** read length **`1`**.

## Remaining DFT blocker (left open): grid `-O2` mis-optimization

With the crashes fixed, the KS numerical grid still **integrates the density to ~0
electrons at `-O2`** (C₂H₆ should give 18; we get `0.0156`). Built at `-O0` the same
source gives `17.998`, so it is a gfortran `-O2` mis-optimization in the `intgrt` grid
code — the same family as the VMOL `-O2` store-drop fixed by an I/O barrier in docs/03.

Crucially, `-O0` is **not** a clean fix here:
- Building `intgrt` at `-O0` (and relinking `xvscf`/`xvksdint`, which link `libintgrt.a`)
  makes the single-point KS energies correct → `104.ks`/`105.ks` then PASS.
- **But** it regresses the geometry-optimization cases: `106.ks` and `145.ksgrad` (which
  PASS at `-O2` with only the record fixes) start grinding for dozens of cycles, because
  the KS **forces** are still wrong. So `-O0` trades 2 passes for 2 regressions — a wash.

Therefore `-O0` was not applied; the binaries ship at the normal optimization with only
the two record-length source fixes. The proper next step is to locate the specific grid
statement gfortran `-O2` mis-handles (as was done for VMOL) and add a targeted source
fix / optimization barrier, which should recover `104/105.ks` (energy) and let
`142–144.hfdft` (forces) converge.

## Build & verification

```
# rebuild + install (default optimization)
(cd intgrt  && gmake) && cp -p intgrt/libintgrt.a lib/ && cp -p intgrt/xintgrt bin/
(cd vscf    && gmake) && cp -p vscf/xvscf       bin/
(cd vksdint && gmake) && cp -p vksdint/xvksdint bin/

# DFT group (test/)
106.ks PASSED · 145.ksgrad PASSED · 146.hfdft.ccsd PASSED
104.ks/105.ks  -> complete (no crash), KS energy wrong  (REAL)
142/143/144    -> complete (no crash), optimizer non-converge (NONCONVERGE)

# regression spot-check (non-DFT, all still PASS): 001a 002a 011 022 042 057
```

Suite total after these fixes: **117 PASS / 182** (was 114). See `changes.patch`.
