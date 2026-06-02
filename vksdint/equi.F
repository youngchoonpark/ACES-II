       subroutine equi(comp,ncount,comppov,e)

       implicit none
#include <aces.h>
#include <iuhf.com>
#include <mol.com>
#include <grid.com>
#include <kscore.com>

c        M_REAL
c     &  CA(totprim,naobasfn)

         integer ref, k,i,j,comp(natoms),comppov(natoms)

       integer ncount, e(natoms,natoms)
c The caller passes comp, comppov and e as three DIFFERENT sections of the
c same kscore core array (equi(kscore(pcompmemb),..,kscore(pcomppopv),
c kscore(equ))). gfortran -O1+ assumes the dummy arrays do not alias each
c other or the global kscore, so it cached/reordered the e(ref,..) stores
c against the comp/comppov/kscore reads -- the symmetry-equivalence map
c came out wrong, leaving a small residual KS-gradient force that stalled
c the geometry optimization. Mark them volatile so every access is a real
c memory reference. (Same -O2 aliasing class as numintint.F.)
       volatile kscore, comp, comppov, e

       i=1
       do j=1,ncount 
          ref=kscore(polist+j-1)
CSSS          write(*,*) 'ref=',ref
         do k=0,comppov(j)-1
          e(ref,ref+k)=comp(i)
          i=i+1
         end do
       end do
   
      return
      end
 
