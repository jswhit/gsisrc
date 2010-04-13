subroutine control2state(xhat,sval,bval)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    control2state
!   prgmmr: tremolet
!
! abstract:  Converts control variable to physical space
!
! program history log:
!   2007-04-13  tremolet - initial code
!   2008-11-28  todling  - add calc of 3dp; upd rh_to_q (Cucurull 2007-07-26)
!   2009-04-21  derber   - modify call to getuv to getuv(*,0)
!   2009-06-16  parrish  - for l_hyb_ens=.true., add calls to ensemble_forward_model and strong_bk
!   2009-08-14  lueken   - update documentation
!   2009-11-27  parrish  - for uv_hyb_ens=.true., then ensemble perturbations contain u,v instead of st,vp
!                            so introduce extra code to handle this case.
!   2010-02-21  parrish  - introduce changes to allow dual resolution, with ensemble computation on
!                            lower resolution grid compared to analysis grid.
!                            new parameter dual_res=.true. if ensemble grid is different from analysis grid.
!   2010-03-23  zhu      - use cstate for generalizing control variable
!
!   input argument list:
!     xhat - Control variable
!     sval - State variable
!     bval - Bias predictors
!
!   output argument list:
!     sval - State variable
!     bval - Bias predictors
!
!$$$ end documentation block
use kinds, only: r_kind,i_kind
use constants, only: izero,ione
use control_vectors
use state_vectors
use bias_predictors
use gsi_4dvar, only: nsubwin, nobs_bins, l4dvar, lsqrtb
use gridmod, only: latlon1n,latlon11
use jfunc, only: nsclen,npclen,nrclen
use hybrid_ensemble_parameters, only: l_hyb_ens,uv_hyb_ens,dual_res
use balmod, only: strong_bk
use hybrid_ensemble_isotropic_regional, only: ensemble_forward_model,ensemble_forward_model_dual_res
implicit none
  
! Declare passed variables  
type(control_vector), intent(in   ) :: xhat
type(state_vector)  , intent(inout) :: sval(nsubwin)
type(predictors)    , intent(inout) :: bval

! Declare local variables  	
integer(i_kind) :: ii,jj
real(r_kind),dimension(latlon1n):: u,v
type(control_state):: cstate

!******************************************************************************

if (lsqrtb) then
   write(6,*)'control2state: not for sqrt(B)'
   call stop2(106)
end if
if (nsubwin/=ione .and. .not.l4dvar) then
   write(6,*)'control2state: error 3dvar',nsubwin,l4dvar
   call stop2(107)
end if

! Loop over control steps
do jj=1,nsubwin

! If this is hybrid ensemble run, then call strong constraint here:
!    first need to transfer variables, since xhat is input only.
   call allocate_cs(cstate)
   cstate%values(:)=xhat%step(jj)%values(:)

! If this is ensemble run, then add ensemble contribution sum(a_en(k)*xe(k)),  where a_en(k) are the ensemble
!   control variables and xe(k), k=1,n_ens are the ensemble perturbations.
   if(l_hyb_ens) then
      if(uv_hyb_ens) then
!        Convert streamfunction and velocity potential to u,v
         call getuv(u,v,cstate%st,cstate%vp,izero)
         cstate%st(:)=u(:)
         cstate%vp(:)=v(:)
      end if
      if(dual_res) then
         call ensemble_forward_model_dual_res(cstate,xhat%step(jj)%a_en)
      else
         call ensemble_forward_model(cstate,xhat%step(jj)%a_en)
      end if
!     Apply strong constraint to sum of static background and ensemble background combinations to
!     reduce imbalances introduced by ensemble localization in addition to known imbalances from
!     static background
      call strong_bk(cstate%st,cstate%vp,cstate%p,cstate%t)
   end if

!  Get 3d pressure
   call getprs_tl(cstate%p,cstate%t,sval(jj)%p3d)

!  Convert input normalized RH to q
   call normal_rh_to_q(cstate%rh,cstate%t,sval(jj)%p3d,sval(jj)%q)

!  Calculate sensible temperature
   call tv_to_tsen(cstate%t,sval(jj)%q,sval(jj)%tsen)

!  Convert streamfunction and velocity potential to u,v
   if(l_hyb_ens.and.uv_hyb_ens) then
      sval(jj)%u(:)=cstate%st(:)
      sval(jj)%v(:)=cstate%vp(:)
   else
      call getuv(sval(jj)%u,sval(jj)%v,cstate%st,cstate%vp,izero)
   end if

!  Copy other variables
   do ii=1,latlon1n
      sval(jj)%t (ii)=cstate%t(ii)
      if (nrf3_oz>izero) sval(jj)%oz(ii)=cstate%oz(ii)
      if (nrf3_cw>izero) sval(jj)%cw(ii)=cstate%cw(ii)
   enddo

   do ii=1,latlon11
      sval(jj)%p(ii)=cstate%p(ii)
      if (nrf2_sst>izero) sval(jj)%sst(ii)=cstate%sst(ii)
   enddo

   call deallocate_cs(cstate)
end do

! Biases
do ii=1,nsclen
   bval%predr(ii)=xhat%predr(ii)
enddo

do ii=1,npclen
   bval%predp(ii)=xhat%predp(ii)
enddo

return
end subroutine control2state
