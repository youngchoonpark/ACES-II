# ACES II — Runtime Port: first calculation runs under gfortran 13

- **Date**: 2026-06-01
- **Scope**: take the gfortran-13 build from *compiles & links* (docs/01, docs/02) to
  *actually runs a real calculation*. Diagnose and fix the runtime failures that stopped
  even the simplest SCF job, and get the first regression test to pass.
- **Build environment**: Ubuntu 24.04 / WSL2, gfortran 13.3.0, GNU Make 4.3, host
  auto-detected `gnu / X86_64 / linux` (case-sensitive ext4 clone — see
  [docs/01](../01-gfortran-port-2026-05-30/PORTING-NOTES.md)).
- **Result**:
  - Clean build: **107 libraries, 81 executables, no errors** (after the build-system
    fixes below).
  - **`test/zmat.001a` (H₂O geometry optimization, SCF/3-21G\*) PASSES** —
    `@TEST: All test records pass` (TOTENERG, COORD, NUCREP, SCFENEG within 1e-8 of the
    reference). `test/zmat.002a` also passes.
  - This is the first time the gfortran-13 port has run a complete ACES calculation; docs/01
    explicitly deferred runtime validation ("Building only confirms compilation and linking").

All work was done in a throwaway `git worktree` so the products never touched the main
checkout; only the source/build fixes recorded here were brought back. Full diff:
`changes.patch` (123 files: 5 real source/build fixes + 114 symlink repairs + 4 exec-bit
restores; apply with `git apply`).

---

## 0. How a clean checkout was found to be non-buildable

Two defects in the committed tree stopped a fresh clone from building at all (so docs/01's
"108 libs / 81 exes, no errors" only held on a tree whose makefile symlinks had already been
repaired locally — that repair was never committed):

1. **114 broken makefile symlinks.** 57 directories committed their `GNUmakefile` and
   `GNUmakefile.src` as **absolute symlinks to the original developer's path**
   `/home/perera/Develop/ACESII/Makefiles/...`, which does not exist. The top-level
   `makefile` only creates a symlink when none is present (`[ ! -h $@/GNUmakefile ]`), so it
   skipped these and the build used the dangling links → `GNUmakefile: No such file` for every
   affected directory. **Fix:** replaced all 114 with relative links
   (`ln -sr Makefiles/GNUmakefile{,.src}`), matching the 104 already-relative committed links.
2. **`docs/` built as a target.** The top-level makefile auto-discovers every subdirectory as
   a build target; the new `docs/` tree (added in docs/01–02) was picked up and `ar` failed on
   `libdocs.a` (`ar: *.o: No such file`). **Fix:** added `docs` to `tl_skip` in `makefile`.

Also restored the execute bit on `xprep xskip xunskip xpromote` (lost in a prior
non-ext4 checkout; required to run `./xprep -f`).

---

## 1. Root cause of the runtime failures: the integer/memory model

docs/01 added `-fdefault-integer-8` (8-byte default INTEGER) to make legacy code compile.
That choice is **incompatible with ACES II's runtime memory model**, which assumes the
canonical configuration **4-byte INTEGER + 8-byte DOUBLE (iintfp = 2) with 8-byte addresses
(`F_ADR = integer*8`)** — the model under which the reference regression outputs were
generated. With 8-byte integers `iintfp = 1`, and the VMOL integral package's hand-rolled
memory partitioning produces wrong sizes and dies in `@LARM: NOT ENOUGH MEMORY` before any
SCF iteration.

The fix is to build with **4-byte default integers** and keep addresses 8-byte. This was
verified by clearing the resulting blockers one at a time until `zmat.001a` ran to
completion. Confirmation that the model is now correct: VMOL's reported integral memory
(`a1 = 8903380`, `a2 = 18410` words) now matches the reference outputs exactly (it was
exactly half — `4451690` — under the 8-byte build).

---

## 2. Fixes (5 files)

| File | Modified | Cause → fix |
|---|---|---|
| `Makefiles/GNUmakefile` | 2026-06-01 19:53 | **(a)** gnu/X86_64 `FFLAGS`/`F9XFLAGS`: removed `-fdefault-integer-8` → 4-byte default INTEGER (`iintfp = 2`), so VMOL's memory math matches the reference. **(b)** Added `-fno-pie` (compile) and `-no-pie` (`LDFLAGS`, link): see §3. `-DF_ADR=integer*8` retained (addresses stay 8-byte; matches the `f_types.h` "F_INT is INT\*4 and F_ADR is INT\*8" model). |
| `Makefiles/GNUmakefile.src` | 2026-06-01 19:53 | `64BIT = 1` → `64BIT = 0`, so `-DF_64BIT` is **not** defined → the C side's `f_int` is a 4-byte `int` (`aces_com_machsp.c`: `iintln = sizeof(f_int)`), consistent with the 4-byte Fortran integer. (Leaving it on would make C report `iintfp = 1` while Fortran uses 4-byte integers — a C/Fortran ABI mismatch.) |
| `makefile` | 2026-06-01 19:53 | Added `docs` to `tl_skip` (§0). |
| `vmol/molecu.F` | 2026-06-01 19:53 | **gfortran -O2 mis-optimization.** The store `ICORE(I000-1+20)=ITMP-20` (sets `I2(20)`, the a2 work-area limit) was being dropped/reordered, so `I2(20)` read 0 and `@CONLOR` tripped `@LARM`. The original author had already left a commented `WRITE(6,*)` here noting it "is needed to get vmol to work with gfortran … most likely an optimization issue" — **uncommented it**; the I/O side effect acts as an optimization barrier and `I2(20)` is now written correctly. |
| `acescore/aces_cache_init.F` | 2026-06-01 19:53 | **kind mismatch exposed by 4-byte integers.** `iand(zTmp, ifltln-1)` etc. mix `zTmp` (`F_ADR` = integer\*8) with the default 4-byte integers `ifltln`/`iintln`; gfortran 13 rejects `iand` with different kinds. Wrapped the second operand in `int(..., kind(zTmp))` at the 4 active call sites. (Was silently fine when everything was 8-byte.) |

---

## 3. Why non-PIE is required

ACES allocates its core memory with `sbrk` (`-D_USE_SBRK`) and stores the heap as an integer
**offset** from a static anchor array (`aces_malloc.c`). For that offset (and the anchor
address itself, stored in the default-integer `lCore`) to fit in a 4-byte integer, the heap
must sit at a low address near the static data. Modern Ubuntu builds executables as **PIE**,
so they load at a high randomized address (~`0x5f61...`); `sbrk` then returns a high address,
`lCore` overflows (`@ACES_MALLOC: WARNING - the lCore address was overflowed`,
`lCore = 0xffffffffd207c000`), and the core cannot be addressed. Building **non-PIE**
(`-no-pie` / `-fno-pie`) puts the data segment and `sbrk` heap at low fixed addresses that fit
in 4 bytes. (The reference build predates default-PIE, so it never hit this.)

---

## 4. Build & run procedure (verified)

```sh
# in a case-sensitive ext4 checkout
chmod +x xprep xskip xunskip xpromote   # if exec bits were lost
./xprep -f
gmake -k          # 107 libs, 81 bins. (A 2nd `gmake` resolves cross-directory
                  #  link ordering, e.g. xpccd needing libdens; harmless on a clean tree.)

# run a regression test
cd test
cp KEEP/GENBAS KEEP/ECPDATA .            # the harness expects them in ./ 
PATH=$PWD/../bin:$PATH gmake zmat.001a   # -> "zmat.001a: PASSED"
```

---

## 5. Status & remaining work

**Done:** clean build; the integer/PIE/optimization model is now correct; `zmat.001a` and
`zmat.002a` pass.

**Not done — full runtime validation is an ongoing, multi-bug effort.** A 12-test smoke
sample passed only **2/12**; the other 10 fail in *different* places (e.g. `zmat.004a`
completes several SCF cycles, then dies in a later module; some numerical-gradient/large
tests may also be hitting the 120 s smoke-test timeout). Each is likely its own latent
4-byte/64-bit issue, to be diagnosed the same way (run → first error → fix → repeat).
Recommended next step: drive the test suite (`test/`, 207 inputs / 195 reference outputs)
case by case, starting from the cheapest SCF/MP2/CCSD jobs.

**Update (2026-06-01) — most of those "failures" are not code bugs.** Triaging the same
cheap smoke batch with `test/triage.sh` (see `TEST-TRIAGE.md`) shows the harness's flat
1e-8 tolerance was hiding the real picture: of the 9 non-passing cheap cases, **5 are
cross-compiler rounding (≤1e-6), 2 are numerical-gradient geometry drift (energy matches
to ~1e-7), and 2 are stale reference data** (`zmat.004a`/`004b` store an MP2-magnitude
`TOTENERG` in a plain-RHF test, contradicting their own `SCFENEG`, which our build
reproduces to 10 digits) — **0 genuine bugs in this batch**. Triage every failure
(`./triage.sh`) and chase only the `CRASH` and `REAL` buckets; that is where the
remaining 4-byte/non-PIE runtime defects actually are.

**Carried-over cleanups (still open, from docs/01–02):** the ~20 case-only `.f`/`.F` pairs;
the committed Intel-ifort artifacts `blockdave/eig__genmod.{f90,mod}`. Separately, the
per-directory `GNUmakefile`/`GNUmakefile.src` symlinks are build-tree artifacts the top-level
makefile can regenerate — long-term they could be removed from version control and
`.gitignore`d rather than committed.
