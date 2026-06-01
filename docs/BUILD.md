# Building ACES II

Verified 2026-05-31 on Ubuntu 24.04 / WSL2 with gfortran 13.3.0 and GNU Make 4.3:
a clean build produces **108 libraries (`lib/*.a`) and 81 executables (`bin/x*`)** with
no compile or link errors.

---

## 1. Requirements

- **gfortran** (10+; tested with 13.3), **gcc/g++**, **cpp**, **GNU make** (`gmake`/`make`), `ar`.
  - Ubuntu/Debian: `sudo apt-get install gfortran gcc g++ make binutils`
- A **case-sensitive filesystem** — see the critical note below.

## 2. CRITICAL — use a case-sensitive filesystem (not a Windows drive)

The repository contains ~20 file pairs that differ only in case (`foo.F` / `foo.f`), and
the build converts `.F` (source) → `cpp` → `.f` (compilation unit). On a **case-insensitive**
filesystem (Windows drives mounted at `/mnt/*` under WSL, or the default macOS volume),
`.F` and `.f` collapse to the same file, so:

- the repo cannot even be checked out correctly, and
- the `.F → .f` step overwrites/destroys its own source.

**Always clone and build on a case-sensitive filesystem (e.g. native ext4 under WSL,
`~/...`).** If your repo currently lives on `/mnt/c`, clone it onto ext4 first:

```sh
git clone <repo-url-or-path> ~/program/aces2/ACES-II
cd ~/program/aces2/ACES-II
```

`git clone` (not `cp -r`) is required: it re-checks-out the files from git's object store,
so the case-distinct pairs materialise correctly.

## 3. Build steps

```sh
cd ~/program/aces2/ACES-II

# Scripts can lose their execute bit when a repo is cloned via a Windows mount:
chmod +x xprep xskip xunskip xpromote

# Prepare the build tree (creates lib/ bin/ bin/sio, links the top-level makefile):
./xprep -f

# Build everything (the host/compiler/OS are auto-detected — no MACHSTATS entry needed):
gmake
```

- Products: executables in `bin/x*`, libraries in `lib/*.a`.
- The host is auto-detected (`gnu` / `X86_64` / `linux` here), so `gmake` works with no
  arguments even though the machine is not in the makefile's `MACHSTATS` table.

## 4. Useful options

```sh
gmake -k all          # keep going after errors (build as much as possible, collect all)
gmake clean           # remove all generated objects/intermediates
gmake clean && gmake  # full rebuild from scratch (do NOT chain as `gmake clean all`)

gmake CMPLR=intel     # override the auto-detected compiler (gnu | intel | pg | ...)
gmake MARCH=x86-64    # override the CPU target (default: native to the build host)
```

Per-directory builds (from the top level), e.g. just the coupled-cluster program:

```sh
gmake vcc             # build one directory and install its products
```

Local, per-checkout build settings live in `Makefiles/GNUmakefile.src`
(`Makefiles/GNUmakefile.src.example` is the original QTP reference configuration).

## 5. Notes / known points

- gfortran 10+ rejects several constructs older compilers tolerated. The makefiles pass
  `-fallow-argument-mismatch -std=legacy -fdefault-integer-8` (and the matching `F9XFLAGS`
  / `MODDIRS_PREFIX=-I` for free-form `.f90`); see `docs/01-…` and `docs/02-…`.
- Building only confirms **compilation and linking**. Numerical/runtime validation
  (running actual ACES calculations) is a separate step.
- Optional repository cleanups (not required to build): the ~20 case-only-differing
  `.f`/`.F` pairs, and a stray committed Intel-ifort artifact `blockdave/eig__genmod.*`.

## 6. History

Full record of the gfortran 13 port and build-system modernization:
- `docs/01-gfortran-port-2026-05-30/` — build-system fixes + first port pass.
- `docs/02-category2-port-2026-05-31/` — blockdave, pccd, mopac, the `extiface`
  (formerly `alice_nwchem`) interface, and the cascade.
- `docs/03-runtime-port-2026-06-01/` — runtime port: switched to the 4-byte-integer /
  non-PIE model so calculations actually run (`test/zmat.001a` passes), and repaired two
  defects that stopped a fresh clone from building at all (114 dead `/home/perera/...`
  makefile symlinks; `docs/` auto-built). **Note:** the integer model changed here, so the
  flags described above (`-fdefault-integer-8`) are superseded — see docs/03.
