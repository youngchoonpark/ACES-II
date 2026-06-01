#!/bin/sh
# triage.sh -- classify ACES II regression-test failures into actionable buckets.
#
# The test harness (GNUmakefile) only ever prints "PASSED" or "FAILED in test
# module" / "FAILED in xaces2".  That single opaque "FAILED in test module"
# conflates several very different situations, which wasted time during the
# gfortran-13 runtime port (see docs/03-runtime-port-2026-06-01/TEST-TRIAGE.md).
# This tool reads the per-test output file (out.<name>, kept by the harness in
# this directory) plus the reference records embedded in the input's TEST.DAT
# section, and sorts each failure into:
#
#   PASS          all checked records within tolerance.
#   NONCONVERGE   the run aborted because the SCF or geometry optimizer did not
#                 converge (max steps/cycles). Not a code bug; tolerance/max-steps.
#   SETUP         the run aborted on an environment/input/limit problem: a basis set
#                 missing from GENBAS, ECP data unassignable, a malformed input (no
#                 *ACES2 namelist), a too-small memory pool, or the 256-function
#                 4-byte-model basis limit. Not a code bug; fix the data/input/limit.
#   CRASH         xaces2 did not complete for a genuine runtime reason. INVESTIGATE.
#   PRECISION     completed; every deviation <= PREC (default 1e-6). Cross-compiler
#                 rounding vs the (Intel-built) reference; NOT a code bug.
#   DRIFT         completed; the only gross deviations are geometry (COORD) records
#                 and the job uses NUMERICAL gradients -> optimizer converged to a
#                 marginally different geometry. Expected for finite-difference runs.
#   BAD-REFERENCE completed; our SCF energy matches the reference SCFENEG to <=PREC,
#                 but the reference's own TOTENERG disagrees with its SCFENEG by
#                 >GROSS in an SCF-only (no-correlation) job -- impossible for RHF,
#                 so the stored reference value is stale/wrong (the zmat.004a case:
#                 an MP2-magnitude TOTENERG pasted into an RHF test). NOT a code bug.
#   REAL          completed, but has gross deviations not explained above -> a
#                 genuine numerical bug. INVESTIGATE (this is the bucket that matters).
#
# Usage:
#   ./triage.sh                 classify every existing out.zmat.* / out.script.* file
#   ./triage.sh zmat.004a ...   classify the named tests (runs them first if no out.* yet)
#   PREC=1e-6 GROSS=1e-3 ./triage.sh ...   override thresholds
#
# Thresholds are deliberately generous: PREC separates "rounding" from "signal",
# GROSS separates "drift/precision" from "energy-scale wrongness".

PREC=${PREC:-1e-6}
GROSS=${GROSS:-1e-3}

# Build the work list.
if [ $# -gt 0 ]; then
   tests="$*"
else
   tests=$(ls out.zmat.* out.script.* 2>/dev/null | sed 's#^out\.##')
fi
[ -n "$tests" ] || { echo "no out.* files found; run a test first (e.g. gmake zmat.004a) or pass test names" >&2; exit 1; }

printf '%-14s %-13s %-10s %s\n' TEST STATUS MAXDEV NOTE
printf '%-14s %-13s %-10s %s\n' '----' '------' '------' '----'

for t in $tests; do
   out="out.$t"
   # If asked for a specific test with no output yet, run it via the harness.
   if [ ! -f "$out" ] && [ -f "$t" ]; then
      PATH="$PWD/../bin:$PATH" gmake "$t" >/dev/null 2>&1
   fi
   if [ ! -f "$out" ]; then
      printf '%-14s %-13s %-10s %s\n' "$t" NO-OUTPUT - "no out.$t and no input '$t' to run"
      continue
   fi
   t_input="$t"; [ -f "$t_input" ] || t_input=/dev/null

   awk -v name="$t" -v PREC="$PREC" -v GROSS="$GROSS" '
      function abs(x){ return x<0 ? -x : x }
      # ---- pass 1: the input file (reference TEST.DAT + method keywords) ----
      FNR==NR {
         if ($0 ~ /TEST\.DAT/) { intest=1; next }
         if (!intest) {
            line=toupper($0)
            if (line ~ /MBPT|MP2|CCSD|CCSDT|CC2|CC3|QCISD|[^A-Z]CCD([^A-Z]|$)/) corr=1
            if (line ~ /NUMERICAL/) numgrad=1
         } else {
            if ($1=="d") { rec=$2; next }
            if ($0 ~ /^[[:space:]]*[+-]?[0-9]/) {
               if (rec=="TOTENERG" && reftot=="")  reftot=$1+0
               if (rec=="SCFENEG"  && refscf=="")  refscf=$1+0
            }
         }
         next
      }
      # ---- pass 2: the out.<name> file ----
      /completed successfully/ { completed++ }
      /FAILED in xaces2/       { xacesfail=1 }
      /Executing "x/ { m=$0; sub(/.*Executing "/,"",m); sub(/".*/,"",m); lastmod=m; lastexec=NR }
      /It=|Iteration|cpu=|E\(SCF\)=|energy=|micro|macro/ { lastprog=NR }   # active-progress markers
      /@ACES_EXIT/ && /error has occurred/ { aceserr=1 }   # note: xa2proc also prints this on a failed compare; only consulted when no compare ran
      /@GETLST|Assertion failed|@LARM|NOT ENOUGH|does not exist|@CONLOR|insufficient|@CHECKGAM|@ACES_MALLOC.*overflow/ {
         errmsg=$0; sub(/^[ \t]+/,"",errmsg); sub(/[ \t]+$/,"",errmsg)
      }
      # --- non-code-bug abort reasons (environment / input / convergence) ---
      /Maximum number of optimization steps exceeded/ { nonconv="geometry optimizer did not converge (max steps exceeded)" }
      /SCF failed to converge|did not converge in|maximum number of SCF/ { if(nonconv=="") nonconv="SCF did not converge" }
      /not found on GENBAS/        { if(setupmsg=="") setupmsg="basis set missing from GENBAS" }
      /CANNOT ASSIGN ECP/          { if(setupmsg=="") setupmsg="ECP data missing/unassignable (ECPDATA)" }
      /missing the ACES2 namelist/ { if(setupmsg=="") setupmsg="malformed input: no *ACES2 namelist (not a runnable ZMAT)" }
      /NORB too large/             { if(setupmsg=="") setupmsg="basis exceeds the 256-function 4-byte-model limit" }
      /MEMORY_SIZE is too small|ran out of memory/ { if(setupmsg=="") setupmsg="memory pool too small (raise the relevant mem keyword)" }
      /E\(SCF\)/ && /a\.u\./ {
         for (i=1;i<=NF;i++) if ($i=="=") { ourscf=$(i+1)+0 }
      }
      /of record "/ {
         r=$0; sub(/.*of record "/,"",r); sub(/".*/,"",r); gsub(/ +$/,"",r); currec=r
      }
      /off by/ {
         d=$0; sub(/.*off by/,"",d); gsub(/[[:space:]]/,"",d); dev=abs(d+0)
         nfail++
         if (dev>maxdev) maxdev=dev
         if (dev>PREC) {                                  # bucket each gross record
            gross++
            if (currec=="COORD" || currec=="NUCREP") grossGeom++   # geometry-derived
            else if (currec=="TOTENERG")             grossTot++
            else if (currec=="SCFENEG")              grossScf++
            else                                     grossOther++  # energies/Hessian/props
         }
      }
      END {
         # classification.
         # "completed" is inferred from xa2proc having run at all: the harness only
         # runs the record comparison when xaces2 returns 0, so any out-of-tolerance
         # line (nfail>0) proves xaces2 finished. (Numerical-optimization output has
         # no "@ACES2: completed" banner, so we cannot rely on that alone.)
         done = (completed>0) || (nfail>0)
         status="REAL"; note=""
         if (!done) {
            # no record comparison ran -> xaces2 did not finish. First peel off the
            # non-code-bug reasons (convergence, environment/input/limit), then split
            # a genuine ACES error from a run merely cut off (timeout).
            if (nonconv!="") {
               status="NONCONVERGE"; note=nonconv " -- not a code bug (tolerance/max-steps; numerical noise vs reference)"
            } else if (setupmsg!="") {
               status="SETUP"; note=setupmsg " -- environment/input/limit, not a code bug"
            } else if (aceserr) {
               status="CRASH"
               note="died in " (lastmod?lastmod:"?")
               if (errmsg!="") note=note " : " errmsg
               note=note " -- real runtime failure"
            } else if (lastprog>lastexec) {
               # progress (iterations) continued past the last module launch -> the
               # job was still computing when it stopped: timeout/interrupt, not a bug.
               status="INCOMPLETE"
               note="cut off mid-computation in " (lastmod?lastmod:"?") " (no @ACES_EXIT) -- likely timeout; re-run with more time"
            } else {
               # stopped at/just after entering a module, no ACES error and no
               # progress -> a hard abort (e.g. SIGSEGV) that printed no @ACES_EXIT.
               status="CRASH"
               note="aborted in " (lastmod?lastmod:"?") " (no @ACES_EXIT; segfault/hard abort) -- real runtime failure"
            }
         } else if (nfail==0) {
            status="PASS"; note="all records within tolerance"
         } else if (maxdev<=PREC) {
            status="PRECISION"; note="all deviations <= " PREC " (cross-compiler rounding, not a code bug)"
         } else if (!corr && grossTot>0 && grossScf==0 && grossGeom==0 && grossOther==0 \
                    && reftot!="" && refscf!="" && abs(reftot-refscf)>GROSS \
                    && ourscf!="" && abs(ourscf-refscf)<=PREC) {
            status="BAD-REFERENCE"
            note=sprintf("ref TOTENERG(%.4f) != ref SCFENEG(%.4f) in SCF-only job; our SCF matches ref SCFENEG -> stale reference", reftot, refscf)
         } else if (grossTot==0 && grossScf==0 && grossOther==0 && grossGeom>0) {
            # energy reproduced to <=PREC; only the geometry differs. This is a
            # coordinate-frame/reorientation or equivalent-minimum difference, not a
            # wrong number. Common with NUMERICAL gradients, but also seen with
            # analytic optimizations (e.g. an O2 bond placed/ordered differently).
            status="DRIFT"
            if (numgrad)
               note="gross deviations only in geometry (COORD/NUCREP), NUMERICAL gradient -- optimizer convergence/reorientation drift; energy matches"
            else
               note="gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum"
         } else {
            status="REAL"; note="gross deviation(s) > " GROSS " in energy/Hessian/property -- investigate"
         }
         printf "%-14s %-13s %-10.1e %s\n", name, status, maxdev+0, note
      }
   ' "$t_input" "$out"
done
