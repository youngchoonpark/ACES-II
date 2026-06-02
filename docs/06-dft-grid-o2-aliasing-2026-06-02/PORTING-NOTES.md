# DFT grid gfortran -O2 core-array aliasing miscompile — 2026-06-02

## Summary

Follow-up to docs/05 (the KSPRINT/NREALATM record-length fixes that de-crashed the eight
KS/DFT tests). After those, the DFT numerical grid still **integrated the electron
density to ~0** at the normal optimization level (`-O2`): C₂H₆ gave `0.0156` electrons
instead of `18`. Consequently the KS exchange-correlation was ~0, the KS-SCF energy was
~0.09–0.3 hartree off, and the KS forces were wrong.

Root cause: a **gfortran `-O2` core-array aliasing miscompile**. Fixed at the source with
`volatile kscore` in the four grid-driver routines. The DFT subsystem now produces
physically correct densities, KS-SCF energies matching the reference to 10 digits, and
greatly improved forces. **xintgrt group: 3/8 → 4/8 PASS** (`104.ks`, `105.ks`, `106.ks`
join `146.hfdft.ccsd`); suite **117 → 118 PASS / 182**.

## The bug

Each grid driver loops:

```fortran
      call oct(... kscore(pradgrid), ... kscore(pgrdangpts))   ! per center: REWRITES these
      do iradpt = 1, int_numradpts
         grid = kscore(pradgrid+iradpt-1)
         do iangpt = 1, kscore(pgrdangpts+grid-1)              ! <-- trip count
            call symoct(...) ; call integint(...)              ! accumulate density/XC/forces
         end do
      end do
```

`oct()` fills `kscore(pradgrid)` and `kscore(pgrdangpts)` for the current center. gfortran
`-O1+` **hoists/caches the inner trip-count load `kscore(pgrdangpts+grid-1)` across the
`oct()` call and across the iterations**, not seeing that `oct()` (which receives the
array under a different formal name) rewrites that very element, nor that `grid` —
itself loaded from `kscore(pradgrid+iradpt-1)` — changes each iteration. The cached value
was the stale `1`, so every inner loop ran a single angular point: the grid collapsed and
the integral was ~0.

Diagnosis path (all on `test/zmat.104.ks`, C₂H₆):
1. `intgrt` at `-O0` gave the correct density `17.998`; at `-O2`, `0.0156`. So it is a
   gfortran optimization bug, not a logic/port error (note `-finit-local-zero` is already
   on, so it is not uninitialized memory).
2. Binary search over the 75 `intgrt` objects (compile the suspect subset at `-O0`, rest
   `-O2`) → **`numintint.f`** for the density.
3. Flag isolation: `-O0` fixes it but `-O1`, `-O2 -fno-tree-vectorize`, no-`march=native`,
   no-`funroll` all stay broken → a basic `-O1` transform (load hoist), not vectorization.
4. Per-center debug prints showed `int_numradpts=50` correct but the inner angular count
   read as `1` (→ 50 integint calls for center 1, **0** for centers 2/3). Inserting a
   `write(*) kscore(pgrdangpts+grid-1)` (an I/O barrier) restored the correct `194` and
   the full call counts — confirming a hoisted/aliased load.
5. A separate bisection on the **SCF energy** signal located the SCF-time driver
   **`setnumint.f`**, and the residual wrong **forces** located the gradient driver
   **`numintAG.f`**.

## Changed files (all: add `volatile kscore`)

| file | mod time | role | recovers |
|---|---|---|---|
| `intgrt/numintint.F` | 2026-06-02 17:41:47 | post-SCF density integration (xintgrt) | density `0.0156 → 17.998` |
| `intgrt/setnumint.F` | 2026-06-02 18:27:09 | SCF-time XC grid setup (xvscf, via integxc/setinteg) | KS-SCF energy now matches reference to 10 digits (104.ks `-78.2952443996` vs `-78.2952443995`) |
| `vksdint/numintAG.F` | 2026-06-02 18:30:12 | analytic KS gradient grid (xvksdint) | KS forces RMS `0.085 → ≤1e-3`; 106.ks geometry optimization converges (RMS `8e-6`) |
| `intgrt/numinteff.F` | 2026-06-02 17:45:06 | alternate "efficient" XC path | identical loop/bug; fixed defensively (not exercised by these tests) |

`volatile kscore` forces every read of the integer core array in that routine to be
re-issued from memory, so the post-`oct()` value is seen. The grid drivers are not the
inner compute hot spot (that is `integint`/`setinteg`, still `-O2`), so the cost is
negligible; the fix keeps the whole tree at the normal optimization (no per-file `-O0`).

## Verification

```
# rebuild + install/relink everything that links the grid library
(cd intgrt  && gmake) && cp -p intgrt/libintgrt.a lib/ && cp -p intgrt/xintgrt bin/
(cd vscf    && gmake) && cp -p vscf/xvscf       bin/
(cd vksdint && gmake) && cp -p vksdint/xvksdint bin/

# DFT group (test/): 104.ks 105.ks 106.ks 146.hfdft.ccsd  -> PASSED
#   104.ks E(SCF) -78.2952443996  (ref -78.2952443995), density 17.998
# non-DFT regression (all still PASS): 001a 002a 011 022 042 057 035.ccsd
```

## Remaining work (142–145): residual KS-gradient error

With the grid fixed, `142/143/144.hfdft` (open-shell `UHF`/`HFDFT`, `OPT_MAXCYC=1`
single-gradient checks) and `145.ksgrad` still carry a small residual force (RMS ~1e-2 …
1e-3, down from 0.085) that leaves the gradient/optimizer just short of the reference.
A further, smaller defect in the (open-shell?) KS-gradient assembly remains; these are
classified NONCONVERGE. `145` was a **false pass** before this work (the broken grid made
it HF-like, coincidentally within tolerance); it is now an honest failure.

Suite total after these fixes: **118 PASS / 182** (was 117). See `changes.patch`.
