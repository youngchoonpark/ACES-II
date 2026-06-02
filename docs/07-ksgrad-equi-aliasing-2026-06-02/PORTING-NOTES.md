# KS-gradient symmetry-map aliasing fix (`equi.F`) + open-shell gradient finding — 2026-06-02

## Summary

Continuation of docs/06 (the four `volatile kscore` grid fixes that took the KS/DFT group
to 4/8). The remaining residual KS-gradient error was split into two distinct causes:

- **Closed-shell (`145.ksgrad`): a fifth `-O2` aliasing miscompile, in `vksdint/equi.F`.**
  Fixed → **145.ksgrad PASS**, group now **5/8**, suite **118 → 119 PASS / 182**.
- **Open-shell (`142/143/144.hfdft`): NOT an `-O2` bug** — a genuine open-shell
  KS-gradient logic/port defect. Characterized and left open.

## `vksdint/equi.F` — dummy-argument aliasing miscompile (the closed-shell residual)

- **File / time:** `vksdint/equi.F` — `2026-06-02 19:12:06 +0900`.
- **How found:** with docs/06 applied, `145.ksgrad` (closed-shell `RHF`/`SCF_TYPE=KS`,
  MG3) stalled at RMS force `0.00116`. Building `vksdint` at `-O0` converged it
  (RMS `2.2e-5`), so a `vksdint` file mis-compiled at `-O2`. A binary search over the 57
  `vksdint` objects isolated **`equi.f`**.
- **Cause:** `equi` builds the symmetry-equivalence map `e(ref,ref+k)=comp(i)`. The caller
  passes three sections of the **same `kscore` core array** as its dummy arguments:
  ```fortran
  call equi(kscore(pcompmemb), ncount, kscore(pcomppopv), kscore(equ))
  c          ^comp                      ^comppov           ^e
  ```
  gfortran `-O1+` assumes the distinct dummy arrays `comp`, `comppov`, `e` (and the global
  `kscore`) do not alias, so it reordered/cached the `e(ref,..)` stores against the
  `comp`/`comppov`/`kscore(polist+..)` reads. The equivalence map came out wrong, the
  KS-gradient symmetrization left a small residual force, and the optimizer stalled.
- **Fix:** `volatile kscore, comp, comppov, e`. Marking only `volatile kscore` was **not**
  enough — the aliasing is through the dummy arguments, which are separate symbols from the
  global `kscore`, so they must be named too. With all four volatile, `145.ksgrad` PASSes
  at the normal `-O2`.

This is the same defect *class* as the docs/06 grid fixes (gfortran `-O1+` aliasing of the
4-byte integer core array), but a distinct *mechanism* (dummy-argument aliasing rather than
a load hoisted across `oct()`).

## Open-shell `142/143/144.hfdft` — logic defect, not `-O2` (left open)

These are open-shell (`REF=UHF`, `MULTI=2`) HF-DFT single-gradient checks
(`kspot=hf`, `func=becke,lyp`, `OPT_MAXCYC=1`, empty TEST.DAT → the run must converge in
one optimization step, i.e. the analytic gradient at the input geometry must be ~0).

- The gradient **computes and is translationally invariant** (e.g. unique-center z-forces
  `H +0.111, H +0.050, Cl −0.161`, sum ≈ 0) but is non-zero (RMS ~0.017), so the single
  optimization step never converges and `xaces2` exits with "max steps exceeded".
- **Unchanged at `-O0`** for both `intgrt` and `vksdint` → it is **not** a compiler
  miscompile but a real open-shell KS-gradient logic/port bug (or a missing term in the
  UHF HF-DFT gradient). Closed-shell KS gradients (`145.ksgrad`, and the energy/geometry of
  `104/105/106.ks`) are now correct, so the defect is specific to the open-shell path.
- Next step: compare the analytic open-shell gradient against a finite-difference gradient
  of the same energy to localize the missing/incorrect term (alpha/beta XC contribution).

## Verification

```
(cd vksdint && gmake) && cp -p vksdint/xvksdint bin/      # equi fix, -O2
# DFT group (test/): 104.ks 105.ks 106.ks 145.ksgrad 146.hfdft.ccsd -> PASSED (5/8)
#   142/143/144.hfdft -> open-shell gradient residual (still fail)
# non-DFT regression (all PASS): 001a 002a 011 022 042 057 035.ccsd
```

Suite total after this fix: **119 PASS / 182** (was 118). See `changes.patch`.
