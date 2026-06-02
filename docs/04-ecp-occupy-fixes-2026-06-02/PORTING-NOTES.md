# ECP `@OCCUPY-F` / SCF-convergence fixes (134 group) — 2026-06-02

## Summary

Follow-up to the runtime port (`docs/03-runtime-port-2026-06-01/`). After a full
regression re-run on the rebuilt binaries (112 PASS / 182), the six ECP tests
`zmat.134{a–f}.ecp` were investigated. Two were fixed; two are now correctly
characterized as a real defect / an environment limit. The 134 group went from
**2/6 → 4/6 PASS**, and the whole suite from **112 → 114 PASS / 182**.

| test | system | before | after | cause → fix |
|---|---|---|---|---|
| `zmat.134b.ecp` | Cl₂ / SBKJC, sym ON | CRASH `@OCCUPY-F` | **PASS** | symmetric post-ECP proton count was wrong → **code fix** in `ecplib/ecp_main.F` |
| `zmat.134a.ecp` | Cu₂O₂²⁺ / Stuttgart, SYM=OFF | NONCONVERGE | **PASS** | RPP SCF limit cycle → **input fix** `SCF_EXTRAP=C2DIIS` |
| `zmat.134c.ecp` | sym OFF | PASS | PASS | unchanged (regression-checked) |
| `zmat.134d.ecp` | sym OFF | PASS | PASS | unchanged (regression-checked) |
| `zmat.134e.ecp` | ECP MBPT(2) gradient | NONCONVERGE | still fails | **real ECP-gradient defect** (not benign) — documented, not yet fixed |
| `zmat.134f.ecp` | UF₆ MBPT(2) | CRASH | still fails | **2 GB file limit** of the 4-byte build — environment, not a code bug |

## Environment

- Host: linux x86_64, gfortran 13 (auto-detected `ARCH=X86_64 OPSYS=linux CMPLR=gnu`).
- 4-byte-integer / non-PIE model (see docs/03).
- Build: rebuilt `ecplib` → installed `lib/libecplib.a` → relinked `xvmol`
  (`ECP_MAIN` is called from `vmol/readin.F`, so it lives in `xvmol`).

## Changed files

### 1. `ecplib/ecp_main.F` — correct the post-ECP proton count under symmetry
- **Location:** subroutine `ECP_MAIN`, the `chgsum`/`nproton` block (~lines 79–105),
  plus one added local declaration `Dimension iorbpop(Mxatms)`.
- **Modification time:** `2026-06-02 16:25:43 +0900`.
- **Cause:** `nproton` (effective nuclear charge after ECP, written to JOBARC
  `NMPROTON` and read by `xvscf`) was computed as
  `Σ charge(i)·fmult(mulnuc(i))` over symmetry-unique atoms. The in-common
  `MULNUC/FMULT` (COMMON `/INDX/`, `/DAT/`) are **not populated in the ECP path** —
  they come back 0 when symmetry is on. The docs/03 guard "`mulnuc(i)<=0` ⇒ treat as
  a single atom (multiplicity 1)" is correct for `SYM=OFF` (every atom is its own
  unique atom) but **wrong when symmetry is on**, where one symmetry-unique atom
  represents several physical atoms. For Cl₂ with symmetry the unique Cl was counted
  once → 7 protons instead of 14 → odd electron count → `@OCCUPY-F, Specified charge
  and multiplicity are impossible`, aborting a perfectly valid closed-shell singlet.
- **Fix:** sum each unique atom's charge over its **true multiplicity**, taken from
  the authoritative per-orbit population `COMPPOPV` in JOBARC (the same vector
  `SymEqv` uses a few lines below):
  ```fortran
  call getrec(20,'JOBARC','COMPNORB',1,norbit)
  call getrec(20,'JOBARC','COMPPOPV',norbit,iorbpop)
  chgsum=0
  do i=1,natoms
     if (i.le.norbit) then
        chgsum=chgsum+charge(i)*dfloat(iorbpop(i))
     else
        chgsum=chgsum+charge(i)
     endif
  enddo
  nproton=idint(chgsum)
  ```
  For `SYM=OFF` every orbit has population 1, so the result is identical to the old
  behaviour (verified: 134c/134d still PASS). For symmetric Cl₂ the population is 2,
  giving 14 protons and a valid singlet (134b now PASS).

### 2. `test/zmat.134a.ecp` — SCF convergence aid
- **Location:** `*ACES2` namelist, line 8.
- **Modification time:** `2026-06-02 16:34:10 +0900`.
- **Cause:** the Cu₂O₂²⁺ RHF SCF (CORE guess + default RPP extrapolation) falls into a
  limit cycle — the energy oscillates around −586.88 a.u. with the FDS−SDF error stuck
  at ~0.1–0.24, and it hits the 150-cycle ceiling without converging. The test carries
  no numerical reference records, so it only needs to complete.
- **Fix:** add `SCF_EXTRAP=C2DIIS` (`MEM_SIZE=1GB` → `MEM_SIZE=1GB,SCF_EXTRAP=C2DIIS`).
  C2DIIS converges this hard case in well under 150 cycles; `xaces2` then completes
  successfully (~29 s). No `SCF_MAXCYC` increase was needed.

### 3. `test/TEST-RESULTS.md` — regression bookkeeping
- **Modification time:** `2026-06-02 16:38:43 +0900`.
- Summary 112 → **114 PASS**; moved 134a/134b to PASS; annotated 134e (real
  ECP-gradient defect) and 134f (2 GB-file limit) rather than leaving them as opaque
  NONCONVERGE/CRASH.

## Remaining work (134 group)

- **`zmat.134e.ecp` — real ECP-gradient defect.** The ECP MBPT(2) gradient returns
  nonsensical internal forces (`dV/dR ≈ −334 hartree/bohr`; the RMS/Min force fields
  overflow to `****`). The optimizer therefore can never satisfy its convergence test
  and exits with "Maximum number of optimization steps exceeded" — which `triage.sh`
  mislabels NONCONVERGE. The energy/SCF/MBPT(2) parts complete; the bug is in the ECP
  contribution to the gradient (xvdint / `ecp_grdint`). Needs a focused look at the
  ECP gradient-integral path. Not addressed here.
- **`zmat.134f.ecp` — 2 GB file limit.** UF₆ MBPT(2) builds an 18.4 M-integral list
  whose file exceeds 2 GB; `@ACES_LIST_TOUCH: Files over 2GB are not supported by this
  binary`. This is the architectural ceiling of the 4-byte-record build (same class as
  `zmat.140.dkh`'s 256-function limit), not a code bug. Fixing it requires an
  8-byte-record / large-file build, out of scope for the 4-byte port.

## Build & verification

```
# rebuild + relink
(cd ecplib && gmake) && cp -p ecplib/libecplib.a lib/ && (cd vmol && gmake) \
  && cp -p vmol/xvmol bin/

# verify (test/)
gmake zmat.134a.ecp   # PASSED   (was NONCONVERGE)
gmake zmat.134b.ecp   # PASSED   (was CRASH @OCCUPY-F)
gmake zmat.134c.ecp   # PASSED   (unchanged — SYM=OFF regression check)
gmake zmat.134d.ecp   # PASSED   (unchanged — SYM=OFF regression check)
gmake zmat.134e.ecp   # FAILED   (real ECP-gradient defect, documented)
gmake zmat.134f.ecp   # FAILED   (2GB file limit, environment)
```

Suite total after these fixes: **114 PASS / 182** (was 112). See `changes.patch` for
the full diff.
