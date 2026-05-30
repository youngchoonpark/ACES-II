      SUBROUTINE DATE(STR)
C
C  Wrapper supplying the legacy Unix DATE(buf) routine, which older MOPAC
C  code calls as `CALL DATE(IDATE)` to obtain the current date/time string.
C  gfortran does not provide DATE as an intrinsic (link-time undefined
C  reference to date_), so route it through the FDATE intrinsic, which
C  returns a 24-character string such as 'Sat May 31 01:13:08 2026'.
C
      CHARACTER*(*) STR
      CALL FDATE(STR)
      RETURN
      END
