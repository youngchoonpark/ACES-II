# retol.awk -- rewrite the per-record tolerance column (col 3) of a test's
# TEST.DAT section to realistic, cross-compiler values, leaving the reference
# VALUE column untouched. See docs/03-runtime-port-2026-06-01/TEST-TRIAGE.md.
#
# The stock tolerance is 0.1E-08 (= 1e-9) for every record -- far tighter than a
# gfortran build can reproduce against the Intel reference. This sets, by record
# type (bands chosen to PASS every observed cross-compiler-rounding case yet still
# FAIL every observed real deviation):
#
#   energy records   -> 1e-7   (0.1E-06)   precision <=9e-9 ; real >=1.4e-5
#   Hessian/force    -> 1e-5   (0.1E-04)   finite-difference; precision <=8e-7
#   everything else  -> 1e-6   (0.1E-05)   precision <=6e-7 ; real >=3.5e-6
#
# Only the tolerance token (the last field of each value line, between TEST.DAT
# and end of file) is changed. Idempotent. Input section is never touched.

function tolfor(rec,   r) {
   r = toupper(rec)
   if (r=="TOTENERG"||r=="SCFENEG"||r=="TOTENER2"||r=="PARENERG"|| \
       r=="E_AVG"||r=="E_OPEN"||r=="KSTOTELE"||r=="KSSCFENG")  return "0.1E-06"  # 1e-7
   if (r=="INTR_HES"||r=="FORCECON")                          return "0.1E-04"  # 1e-5
   return "0.1E-05"                                                             # 1e-6
}
BEGIN { intest=0 }
/TEST\.DAT/         { intest=1; print; next }
!intest             { print; next }                 # input section: verbatim
$1=="d"             { rec=$2; print; next }          # record declaration
/^[ \t]*[-+]?[.0-9]/ && NF>=2 {                      # a value line: value  tol
   line=$0
   sub(/[ \t]+[^ \t]+[ \t]*$/, "   " tolfor(rec), line)   # swap only the tol token
   print line; next
}
{ print }
