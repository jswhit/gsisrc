module stpwmod

!$$$ module documentation block
!           .      .    .                                       .
! module:   stpwmod    module for stpw and its tangent linear stpw_tl
!  prgmmr:
!
! abstract: module for stpw and its tangent linear stpw_tl
!
! program history log:
!   2005-05-20  Yanqiu zhu - wrap stpw and its tangent linear stpw_tl into one module
!   2005-11-16  Derber - remove interfaces
!   2008-12-01  Todling - remove stpw_tl; add interface back
!   2009-08-12  lueken - update documentation
!
! subroutines included:
!   sub stpw
!
! attributes:
!   langauge: f90
!   machine:
!
!$$$ end documentation block

implicit none

PRIVATE
PUBLIC stpw

contains

subroutine stpw(whead,ru,rv,su,sv,out,sges,nstep)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    stpw        calculate penalty and contribution to stepsize
!                            from winds, using nonlinear qc.
!   prgmmr: derber           org: np23                date: 1991-02-26
!
! abstract: calculate penalty and contribution to stepsize from winds,
!              using nonlinear qc.
!
! program history log:
!   1991-02-26  derber
!   1998-02-03  derber
!   1999-08-24  derber, j., treadon, r., yang, w., first frozen mpp version
!   2004-07-29  treadon - add only to module use, add intent in/out
!   2004-10-08  parrish - add nonlinear qc option
!   2005-04-11  treadon - merge stpw and stpw_qc into single routine
!   2005-08-02  derber  - modify for variational qc parameters for each ob
!   2005-09-28  derber  - consolidate location and weight arrays
!   2005-10-21  su      - modify for variational qc
!   2006-07-28  derber  - modify to use new inner loop obs data structure
!                       - unify NL qc
!   2007-03-19  tremolet - binning of observations
!   2006-07-28  derber  - modify output for b1 and b3
!   2007-02-15  rancic  - add foto
!   2007-06-04  derber  - use quad precision to get reproducability over number of processors
!   2008-06-02  safford - rm unused var and uses
!   2008-12-03  todling - changed handling of ptr%time
!
!   input argument list:
!     whead
!     ru       - search direction for u
!     rv       - search direction for v
!     su       - analysis increment for u
!     sv       - analysis increment for v
!     sges     - step size estimates  (nstep)
!     nstep    - number of step sizes ( if == 0 use outer iteration value)
!
!   output argument list  
!     out(1:nstep)   - current penalty using sges(1:nstep)
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,i_kind,r_quad
  use obsmod, only: w_ob_type
  use qcmod, only: nlnqc_iter,varqc_iter
  use constants, only: izero,ione,one,half,two,tiny_r_kind,cg_term,zero_quad,r3600
  use gridmod, only: latlon1n
  use jfunc, only: l_foto,xhat_dt,dhat_dt
  implicit none

! Declare passed variables
  type(w_ob_type),pointer                ,intent(in):: whead
  integer(i_kind)                        ,intent(in):: nstep
  real(r_quad),dimension(max(ione,nstep)),intent(inout):: out
  real(r_kind),dimension(latlon1n)       ,intent(in):: ru,rv,su,sv
  real(r_kind),dimension(max(ione,nstep)),intent(in):: sges

! Declare local variables
  integer(i_kind) j1,j2,j3,j4,j5,j6,j7,j8,kk
  real(r_kind) valu,facu,valv,facv,w1,w2,w3,w4,w5,w6,w7,w8,time_w
  real(r_kind) cg_w,wgross,wnotgross,w_pg
  real(r_kind) uu,vv
  real(r_kind),dimension(max(ione,nstep))::pen
  type(w_ob_type), pointer :: wptr

  out=zero_quad

  wptr => whead
  do while (associated(wptr))
     if(wptr%luse)then
        if(nstep > izero)then
           j1=wptr%ij(1)
           j2=wptr%ij(2)
           j3=wptr%ij(3)
           j4=wptr%ij(4)
           j5=wptr%ij(5)
           j6=wptr%ij(6)
           j7=wptr%ij(7)
           j8=wptr%ij(8)
           w1=wptr%wij(1)
           w2=wptr%wij(2)
           w3=wptr%wij(3)
           w4=wptr%wij(4)
           w5=wptr%wij(5)
           w6=wptr%wij(6)
           w7=wptr%wij(7)
           w8=wptr%wij(8)

           valu=w1* ru(j1)+w2* ru(j2)+w3* ru(j3)+w4* ru(j4) &
               +w5* ru(j5)+w6* ru(j6)+w7* ru(j7)+w8* ru(j8)  

           facu=w1* su(j1)+w2* su(j2)+w3* su(j3)+w4* su(j4) &
               +w5* su(j5)+w6* su(j6)+w7* su(j7)+w8* su(j8) - wptr%ures
 
           valv=w1* rv(j1)+w2* rv(j2)+w3* rv(j3)+w4* rv(j4) &
               +w5* rv(j5)+w6* rv(j6)+w7* rv(j7)+w8* rv(j8)  
 
           facv=w1* sv(j1)+w2* sv(j2)+w3* sv(j3)+w4* sv(j4) &
               +w5* sv(j5)+w6* sv(j6)+w7* sv(j7)+w8* sv(j8) - wptr%vres
           if(l_foto) then
              time_w=wptr%time*r3600
              valu=valu+(w1*dhat_dt%u(j1)+w2*dhat_dt%u(j2)+ &
                         w3*dhat_dt%u(j3)+w4*dhat_dt%u(j4)+ &
                         w5*dhat_dt%u(j5)+w6*dhat_dt%u(j6)+ &
                         w7*dhat_dt%u(j7)+w8*dhat_dt%u(j8))*time_w
              facu=facu+(w1*xhat_dt%u(j1)+w2*xhat_dt%u(j2)+ &
                         w3*xhat_dt%u(j3)+w4*xhat_dt%u(j4)+ &
                         w5*xhat_dt%u(j5)+w6*xhat_dt%u(j6)+ &
                         w7*xhat_dt%u(j7)+w8*xhat_dt%u(j8))*time_w 
              valv=valv+(w1*dhat_dt%v(j1)+w2*dhat_dt%v(j2)+ &
                         w3*dhat_dt%v(j3)+w4*dhat_dt%v(j4)+ &
                         w5*dhat_dt%v(j5)+w6*dhat_dt%v(j6)+ &
                         w7*dhat_dt%v(j7)+w8*dhat_dt%v(j8))*time_w
              facv=facv+(w1*xhat_dt%v(j1)+w2*xhat_dt%v(j2)+ &
                         w3*xhat_dt%v(j3)+w4*xhat_dt%v(j4)+ &
                         w5*xhat_dt%v(j5)+w6*xhat_dt%v(j6)+ &
                         w7*xhat_dt%v(j7)+w8*xhat_dt%v(j8))*time_w 
           end if
     
           do kk=1,nstep
              uu=facu+sges(kk)*valu
              vv=facv+sges(kk)*valv
              pen(kk)= (uu*uu+vv*vv)*wptr%err2
           end do
        else
           pen(1)= (wptr%ures*wptr%ures+wptr%vres*wptr%vres)*wptr%err2
        end if

!  Modify penalty term if nonlinear QC

        if (nlnqc_iter .and. wptr%pg > tiny_r_kind .and.  &
                             wptr%b  > tiny_r_kind) then
           w_pg=wptr%pg*varqc_iter
           cg_w=cg_term/wptr%b
           wnotgross= one-w_pg
           wgross =w_pg*cg_w/wnotgross
           do kk=1,max(ione,nstep)
              pen(kk)= -two*log((exp(-half*pen(kk))+wgross)/(one+wgross))
           end do
        endif

        out(1) = out(1)+pen(1)*wptr%raterr2
        do kk=2,nstep
           out(kk) = out(kk)+(pen(kk)-pen(1))*wptr%raterr2
        end do
     end if

     wptr => wptr%llpoint

  end do
  return
end subroutine stpw

end module stpwmod
