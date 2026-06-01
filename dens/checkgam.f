      

 
      SUBROUTINE CHECKGAM(ICORE,LISTW,LISTG,FACT)
      IMPLICIT DOUBLE PRECISION(A-H,O-Z)
      INTEGER DIRPRD,DISSYW
      DIMENSION ICORE(*)
      COMMON/MACHSP/IINTLN,IFLTLN,IINTFP,IALONE,IBITWD
      COMMON /SYMINF/NSTART,NIRREP,IRREPA(255,2),DIRPRD(8,8)
      COMMON/SYMPOP/IRPDPD(8,22),ISYTYP(2,500),NTOT(18)
      COMMON/ADD/SUM
C moio is the first array of the /lists/ common (acescore lists.com); a
C partial declaration suffices to query list existence here.
      COMMON /LISTS/ MOIO(10,500)
CSSS      RETURN
C CHECKGAM is a diagnostic (prints gamma checksums). Skip it when the gamma
C lists were not built -- e.g. the AOBASIS/single_store CCSD path does not
C create MO-basis list LISTW/LISTG -- which would otherwise trip @GETLST
C "list does not exist". The normal path is unchanged.
      IF (MOIO(1,LISTW).LT.1 .OR. MOIO(1,LISTG).LT.1) RETURN
      E=0.0D+0
      E1=0.0D+0
      E2=0.0D+0
      sum = 0.0D0
      DO 1000 IRREP=1,NIRREP
      NUMSYW=IRPDPD(IRREP,ISYTYP(2,LISTW))
      DISSYW=IRPDPD(IRREP,ISYTYP(1,LISTW))
      IOFFW=1
      IOFFW2=1+NUMSYW*DISSYW*IINTFP
      CALL GETLST(ICORE(IOFFW),1,NUMSYW,1,IRREP,LISTW)
      CALL GETLST(ICORE(IOFFW2),1,NUMSYW,2,IRREP,LISTG)
CSSS      call output(icore(ioffw2),1,dissyw,1,numsyw,dissyw,numsyw,1)
      E=E+SDOT(NUMSYW*DISSYW,ICORE(IOFFW),1,ICORE(IOFFW2),1)
      E1=E1+SDOT(NUMSYW*DISSYW,ICORE(IOFFW),1,ICORE(IOFFW),1)
      E2=E2+SDOT(NUMSYW*DISSYW,ICORE(IOFFW2),1,ICORE(IOFFW2),1)
1000  CONTINUE
      sum=sum+FACT*e
      write(6,500)Fact*e,e1,e2
      write(6,501)sum
      return
500   format(' Energy contribution : ',3(F13.10,1X))
501   format(' Cumulative energy   : ',F20.10)
      end
