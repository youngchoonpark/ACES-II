      Subroutine Built_symtran(Iwork,Dwork,Dmaxcor,Imaxcor,Nunique,
     &                   Nsymgen,Kka)

      Implicit Double Precision(A-H,O-Z)

C Dmaxcor is a work-array size; the implicit D-rule would make it REAL, so
C declare it INTEGER explicitly (like Imaxcor, which is implicitly integer).
      Integer Dmaxcor

      Dimension Dwork(Dmaxcor)
      Dimension Iwork(Imaxcor) 
      Character*1 Kka(8,3)
      Character*1 Blank

      Data Blank /" "/

      Nirrep = 2**Nsymgen
#ifdef _NOSKIP  
      Do J = 1, Nsymgen
         Do I = 1, 3
            If (Kka(J,I) .Eq. Blank) 
         Enddo
      Enddo
#endif

      Return
      End
