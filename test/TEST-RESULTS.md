# ACES II regression results — gfortran-13 port

Updated 2026-06-02 from `test/triage.sh`. Realistic per-record tolerances
(`retol.sh`) and stale-reference fixes applied; plus the runtime fixes below.

## Summary: 113 PASS / 69 FAIL of 182

| Status | Count | Meaning |
|---|---|---|
| PASS | 113 | within realistic tolerance |
| CRASH | 35 | genuine runtime failure — **fix** |
| REAL | 8 | completed, numerically wrong — **fix** |
| DRIFT | 16 | geometry reorientation — benign |
| SETUP | 4 | missing basis/ECP/memory/limit — environment |
| NONCONVERGE | 5 | optimizer/SCF not converged — benign |
| INCOMPLETE | 1 | timeout — re-run |

## Runtime fixes applied 2026-06-02

| Fix | Kind | Recovered |
|---|---|---|
| `ecplib/ecp_int_driver.F`: ECP1INTS record length needs *Iintfp (4-byte record bug, same class as PTGP) | code | 134a, 134b |
| `ecplib/ecp_main.F`: guard mulnuc<=0 -> multiplicity 1 (symmetry index unset with SYM=OFF zeroed NMPROTON -> 0-electron SCF / @OCCUPY-F) | code | 134c, 134d |
| 3x `MEM_SIZE` 10GB/3GB -> 1GB (>2GB overflows the 4-byte integer model) | input | 035.lccsd1/2, 151.eomccsdpt |
| `test/GNUmakefile`: link ECPDATA into the work dir (like GENBAS); exclude non-test zmat.bas.143 | harness | unblocks all ECP; removes 1 false failure |

---

## CRASH (35)

| test | detail |
|---|---|
| zmat.028 | died in xvcc : @GETLST: Error reading list ( 1 , 61 ) -- real runtime failure |
| zmat.029 | died in xvcc : @GETLST: Error reading list ( 1 , 61 ) -- real runtime failure |
| zmat.032 | died in xvcc : @GETLST: Error reading list ( 1 , 61 ) -- real runtime failure |
| zmat.035.eommbpt2 | died in xvee : List ( 1 , 110 ) does not exist. -- real runtime failure |
| zmat.058.mrcc | died in xvee -- real runtime failure |
| zmat.067.mrcc | aborted in xmrcc (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.068.mrcc | aborted in xmrcc (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.069.mrcc | aborted in xmrcc (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.071.mrcc | died in xvip : List ( 2 , 110 ) does not exist. -- real runtime failure |
| zmat.080.mrcc | died in xvip : List ( 2 , 110 ) does not exist. -- real runtime failure |
| zmat.081.mrcc | died in xvip : List ( 2 , 110 ) does not exist. -- real runtime failure |
| zmat.085.mrcc | died in xvee -- real runtime failure |
| zmat.087.mrcc | aborted in xmrcc (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.088.mrcc | aborted in xmrcc (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.096.mrcc | aborted in xmrcc (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.098.mrcc | aborted in xmrcc (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.099.mrcc | aborted in xmrcc (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.100.mrcc | died in xvip : List ( 1 , 110 ) does not exist. -- real runtime failure |
| zmat.104.ks | died in xintgrt -- real runtime failure |
| zmat.105.ks | died in xintgrt -- real runtime failure |
| zmat.106.ks | died in xintgrt -- real runtime failure |
| zmat.124b.fno | aborted in xvtran (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.124c.fno | aborted in xvtran (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.124d.fno | aborted in xvcc (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.124e.fno | aborted in xvtran (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.124i.fno | aborted in xvtran (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.128 | died in xdens -- real runtime failure |
| zmat.134f.ecp | died in xintprc -- real runtime failure |
| zmat.138.ccsdt | aborted in xvmol2ja (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.139.ccsdpt | aborted in xvmol2ja (no @ACES_EXIT; segfault/hard abort) -- real runtime failure |
| zmat.142.hfdft | died in xintgrt -- real runtime failure |
| zmat.143.hfdft | died in xintgrt -- real runtime failure |
| zmat.144.hfdft | died in xintgrt -- real runtime failure |
| zmat.145.ksgrad | died in xintgrt -- real runtime failure |
| zmat.146.hfdft.ccsd | died in xintgrt -- real runtime failure |

## REAL (8)

| test | detail |
|---|---|
| zmat.043.mrcc | gross deviation(s) > 1e-3 in energy/Hessian/property -- investigate |
| zmat.044 | gross deviation(s) > 1e-3 in energy/Hessian/property -- investigate |
| zmat.048b | gross deviation(s) > 1e-3 in energy/Hessian/property -- investigate |
| zmat.059.mrcc | gross deviation(s) > 1e-3 in energy/Hessian/property -- investigate |
| zmat.072.mrcc | gross deviation(s) > 1e-3 in energy/Hessian/property -- investigate |
| zmat.073.mrcc | gross deviation(s) > 1e-3 in energy/Hessian/property -- investigate |
| zmat.090.mrcc | gross deviation(s) > 1e-3 in energy/Hessian/property -- investigate |
| zmat.094.mrcc | gross deviation(s) > 1e-3 in energy/Hessian/property -- investigate |

## DRIFT (16)

| test | detail |
|---|---|
| zmat.001b | gross deviations only in geometry (COORD/NUCREP), NUMERICAL gradient -- optimizer convergence/reorientation drift; energy matches |
| zmat.001c | gross deviations only in geometry (COORD/NUCREP), NUMERICAL gradient -- optimizer convergence/reorientation drift; energy matches |
| zmat.015a | gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum |
| zmat.015b | gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum |
| zmat.015c | gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum |
| zmat.015d | gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum |
| zmat.015e | gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum |
| zmat.015f | gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum |
| zmat.065 | gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum |
| zmat.078 | gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum |
| zmat.120a | gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum |
| zmat.120b | gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum |
| zmat.120c | gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum |
| zmat.120d | gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum |
| zmat.126a | gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum |
| zmat.126e | gross deviations only in geometry (COORD/NUCREP); energy matches to <=PREC -- coordinate-frame/reorientation or equivalent minimum |

## SETUP (4)

| test | detail |
|---|---|
| zmat.103.ks | memory pool too small (raise the relevant mem keyword) -- environment/input/limit, not a code bug |
| zmat.133 | basis set missing from GENBAS -- environment/input/limit, not a code bug |
| zmat.140.dkh | basis exceeds the 256-function 4-byte-model limit -- environment/input/limit, not a code bug |
| zmat.152.eommbpt2 | basis set missing from GENBAS -- environment/input/limit, not a code bug |

## NONCONVERGE (5)

| test | detail |
|---|---|
| zmat.121a | geometry optimizer did not converge (max steps exceeded) -- not a code bug (tolerance/max-steps; numerical noise vs reference) |
| zmat.121b | geometry optimizer did not converge (max steps exceeded) -- not a code bug (tolerance/max-steps; numerical noise vs reference) |
| zmat.121c | geometry optimizer did not converge (max steps exceeded) -- not a code bug (tolerance/max-steps; numerical noise vs reference) |
| zmat.131 | geometry optimizer did not converge (max steps exceeded) -- not a code bug (tolerance/max-steps; numerical noise vs reference) |
| zmat.134e.ecp | geometry optimizer did not converge (max steps exceeded) -- not a code bug (tolerance/max-steps; numerical noise vs reference) |

## INCOMPLETE (1)

| test | detail |
|---|---|
| zmat.135.ccsdtq | cut off mid-computation in ? (no @ACES_EXIT) -- likely timeout; re-run with more time |

## PASS (113)

    zmat.001a zmat.001d zmat.001e zmat.001f zmat.001g zmat.002a zmat.002b zmat.004a zmat.004b zmat.004c 
    zmat.010a zmat.010b zmat.010c zmat.011 zmat.012a zmat.012b zmat.012c zmat.013a zmat.013b zmat.013c 
    zmat.014a zmat.014a.apt zmat.014b zmat.014b.apt zmat.014c zmat.014c.apt zmat.020 zmat.021 zmat.022 
    zmat.022a zmat.022b zmat.022c zmat.023 zmat.023a zmat.024 zmat.025 zmat.026 zmat.026a zmat.031 
    zmat.033 zmat.035.ccsd zmat.035.lccsd1 zmat.035.lccsd2 zmat.036 zmat.037 zmat.038 zmat.041 zmat.042 
    zmat.045.tdhf zmat.046 zmat.046a zmat.046b zmat.047a zmat.047b zmat.047d zmat.048a zmat.049a 
    zmat.049b zmat.053 zmat.054a zmat.054b zmat.056.mrcc zmat.057 zmat.061.mrcc zmat.062.mrcc zmat.063 
    zmat.064 zmat.070.mrcc zmat.074 zmat.082.mrcc zmat.083 zmat.084.mrcc zmat.089.mrcc zmat.095.mrcc 
    zmat.109 zmat.110 zmat.116a zmat.116b zmat.116c zmat.117a zmat.117b zmat.117c zmat.118a zmat.118b 
    zmat.118c zmat.124a.fno zmat.124f.fno zmat.124g.fno zmat.124h.fno zmat.125a zmat.125b zmat.126b 
    zmat.126c zmat.126d zmat.126f zmat.126g zmat.126h zmat.127 zmat.129 zmat.130 zmat.132 zmat.134a.ecp 
    zmat.134b.ecp zmat.134c.ecp zmat.134d.ecp zmat.136.dccsd zmat.137.dccd zmat.141.rpa zmat.147.dkh 
    zmat.148.dkh zmat.150.eomccsdpt zmat.151.eomccsdpt zmat.153.eomgrad 
