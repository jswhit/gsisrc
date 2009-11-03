module stpcalcmod

!$$$ module documentation block
!           .      .    .                                       .
! module:   stpcalcmod    module for stpcalc and its tangent linear stpcalc_tl
!  prgmmr:
!
! abstract: module for stpcalc and its tangent linear stpcalc_tl
!
! program history log:
!   2005-05-21  Yanqiu zhu - wrap stpcalc and its tangent linear stpcalc_tl into one module
!   2005-11-21  Derber - remove interfaces and clean up code
!   2008-12-02  Todling - remove stpcalc_tl
!   2009-08-12  lueken  - updated documentation
!
! subroutines included:
!   sub stpcalc
!
! attributes:
!   language: f90
!   machine:
!
!$$$ end documentation block

implicit none

PRIVATE
PUBLIC stpcalc

contains

subroutine stpcalc(stpinout,sval,sbias,xhat,dirx,dval,dbias, &
                   diry,penalty,pjcost,end_iter)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    stpcalc     calculate penalty and stepsize
!   prgmmr: derber           org: np23                date: 2003-12-18
!
! abstract: calculate current penalty and estimate stepsize
!               (nonlinear qc version)
!
!    A description of nonlinear qc follows:
!
!    The observation penalty Jo is defined as
!
!          Jo =  - (sum over obs) 2*log(Po)
!
!      where,
!
!          Po = Wnotgross*exp(-.5*(Hn(x+xb) - yo)**2 ) + Wgross
!            with
!                Hn = the forward model (possibly non-linear) normalized by 
!                     observation error
!                x  = the current estimate of the analysis increment
!                xb = the background state
!                yo = the observation normalized by observation error
!
!            Note:  The factor 2 in definition of Jo is present because the 
!                   penalty Jo as used in this code is 2*(usual definition 
!                   of penalty)
!
!          Wgross = Pgross*cg
!
!          Wnotgross = 1 - Wgross
!
!          Pgross = probability of gross error for observation (assumed
!                   here to have uniform distribution over the possible
!                   range of values)
!
!          cg = sqrt(2*pi)/2b
!
!          b = possible range of variable for gross errors, normalized by 
!              observation error
!
!    The values for the above parameters that Bill Collins used in the
!    eta 3dvar are:
!
!          cg = cg_term/b, where cg_term = sqrt(2*pi)/2 
!
!          b = 10.        ! range for gross errors, normalized by obs error
!
!          pg_q=.002      ! probability of gross error for specific humidity
!          pg_pw=.002     ! probability of gross error for precipitable water
!          pg_p=.002      ! probability of gross error for pressure
!          pg_w=.005      ! probability of gross error for wind
!          pg_t=.007      ! probability of gross error for temperature
!          pg_rad=.002    ! probability of gross error for radiances
!
!
!    Given the above Jo, the gradient of Jo is as follows:
!
!                                             T
!        gradx(Jo) = - (sum over observations) 2*H (Hn(x+xb)-yo)*(Po - Wgross)/Po
!
!      where, 
!
!          H = tangent linear model of Hn about x+xb
!
! 
!    Note that if Pgross = 0.0, then Wnotgross=1.0 and Wgross=0.0.  That is,
!    the code runs as though nonlinear quality control were not present
!    (which is indeed the case since the gross error probability is 0).  
!
!    As a result the same stp* routines may be used for use with or without
!    nonlinear quality control.
!    
!    Please note, however, that using the nonlinear qc routines makes the
!    stp* and int* operators nonlinear.  Hence, the need to evaluate the
!    step size operators twice for each observation type, give the current
!    step size algorithm coded below. 
!
!
! program history log:
!   2003-12-18  derber,j.
!   2004-07-23  derber  - modify to include conventional sst
!   2004-07-28  treadon - add only to module use, add intent in/out
!   2004-10-06  parrish - add nonlinear qc option
!   2004-10-06  kleist  - separate control vector for u,v, get search
!                         direction for u,v from dir for st,vp
!   2004-11-30  treadon - add brightness temperatures to nonlinear
!                         quality control
!   2005-01-20  okamoto - add u,v to stprad_qc
!   2005-01-26  cucurull- implement local GPS RO linear operator
!   2005-02-10  treadon - add u,v to stprad_qc (okamoto change not present)
!   2005-02-23  wu      - add call to normal_rh_to_q to convert normalized 
!                         RH to q
!   2005-04-11  treadon - rename stpcalc_qc as stpcalc
!   2005-05-21  yanqiu zhu - add 'use stp*mod', and modify call interfaces for using these modules
!   2005-05-27  derber - remove linear stepsize estimate
!   2005-06-03  parrish - add horizontal derivatives
!   2005-07-10  kleist  - add dynamic constraint term (linear)
!   2005-09-29  kleist  - expand Jc term, include time derivatives vector
!   2005-11-21  kleist  - separate tendencies from Jc term, add call to calctends tlm
!   2005-12-01  cucurull - add code for GPS local bending angle, add use obsmod for ref_obs
!   2005-12-20  parrish - add arguments to call to stpt to enable boundary layer forward
!                         model option.
!   2006-04-18  derber - add explicit iteration over stepsize (rather than 
!                        repeated calls) - clean up and simplify
!   2006-04-24  kleist - include both Jc formulations
!   2006-05-26  derber - modify to improve convergence checking
!   2007-03-19  tremolet - binning of observations
!   2007-04-13  tremolet - split Jo and 3dvar components into stpjo and stp3dvar
!   2006-07-26  parrish - correct inconsistency in computation of space and time derivatives of q
!                          currently, if derivatives computed, for q it is normalized q, but
!                          should be mixing ratio.
!   2006-08-04  parrish - add strong constraint initialization option
!   2006-09-18  derber - modify output from nonlinear operators to make same as linear operators
!   2006-09-20  derber - add sensible temperatures for conventional obs.
!   2006-10-12  treadon - replace virtual temperature with sensible in stppcp
!   2007-02-15  rancic  - add foto
!   2007-04-16  kleist  - modified calls to tendency and constraint routines
!   2007-06-04  derber  - use quad precision to get reproduceability over number of processors
!   2007-07-26  cucurull - update gps code to generalized vertical coordinate;
!                          get current solution for 3d pressure (xhat_3dp);
!                          move getprs_tl out of calctends_tl; add dirx3dp
!                          and remove ps in calctends_tl argument list;
!                          use getprs_tl 
!   2007-08-08  derber - optimize, ensure that only necessary time derivatives are calculated
!   2007-10-01  todling - add timers
!   2008-11-28  todling - revisited Tremolet's split in light of changes from May08 version
!   2009-06-02  derber - modify the calculation of the b term for the background to increase accuracy
!
!   input argument list:
!     stpinout - guess stepsize
!     sval     - current solution
!     xhat     - current solution
!     dirx     - search direction for x
!     diry     - search direction for y (B-1 dirx)
!     end_iter - end iteration flag
!     dval
!     sbias,dbias
!
!   output argument list:
!     xhat
!     stpinout - final estimate of stepsize
!     penalty  - penalty
!     end_iter - end iteration flag false if stepsize successful
!     pjcost
!
! remarks:
!     The part of xhat and dirx containing temps and psfc are values before strong initialization,
!     xhatt, xhatp and dirxt, dirxp contain temps and psfc after strong initialization.
!     If strong initialization is turned off, then xhatt, etc are equal to the corresponding 
!     fields in xhat, dirx.
!     xhatuv, xhat_y, xhat_t and dirxuv, dirx_t are all after
!     strong initialization if it is turned on.
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,i_kind,r_quad
  use mpimod, only: mype
  use constants, only:  zero,one_tenth,half,one,zero_quad
  use gsi_4dvar, only: nobs_bins, ltlint
  use jfunc, only: iout_iter,nclen,xhatsave,yhatsave,&
       l_foto,xhat_dt,dhat_dt,nvals_len
  use jcmod, only: ljcpdry
  use obsmod, only: yobs,nobs_type
  use stplimqmod, only: stplimq
  use stpjcpdrymod, only: stpjcpdry
  use bias_predictors
  use control_vectors
  use state_vectors
  use mpl_allreducemod, only: mpl_allreduce
  use timermod, only: timer_ini,timer_fnl
  implicit none

! Declare passed variables
  real(r_kind),intent(inout):: stpinout
  logical,     intent(inout):: end_iter
  real(r_kind),intent(out)  :: penalty
  real(r_kind),intent(out)  :: pjcost(4)

  type(control_vector),intent(inout)::xhat
  type(control_vector),intent(in)::dirx,diry
  type(state_vector),  intent(in)::sval(nobs_bins)
  type(state_vector),  intent(in)::dval(nobs_bins)
  type(predictors),    intent(in)::sbias,dbias


! Declare local parameters
  integer(i_kind),parameter:: ipen = 5+nobs_type
  integer(i_kind),parameter:: istp_iter = 5
  integer(i_kind),parameter:: ipenlin = 3
  integer(i_kind),parameter:: ioutpen = istp_iter*4

! Declare local variables
  integer(i_kind) i,j,mm1,ii,ibin
  integer(i_kind) istp_use
  real(r_quad),dimension(6,ipen):: pbc
  real(r_quad),dimension(ipen):: bpen,cpen   
  real(r_quad),dimension(3,ipenlin):: pstart 
  real(r_quad) bx,cx
  real(r_kind),dimension(ipen):: stpx   
  real(r_kind) dels,delpen
  real(r_kind) outpensave,stprat
  real(r_kind),dimension(4)::sges
  real(r_kind),dimension(0:istp_iter):: stp   
  real(r_kind),dimension(ioutpen):: outpen,outstp

!************************************************************************************  
! Initialize timer
  call timer_ini('stpcalc')

! Initialize variable
  mm1=mype+1
  stp(0)=stpinout
  outpen = zero

!   Begin calculating contributions to penalty and stepsize for various terms
!
!   stepsize = sum(b)/sum(c)
!
!    pbc(1,*) - stepsize sges(1) penalty (sges(1) == 0. first call)
!    pbc(2,*) - stepsize sges(2) penalty
!    pbc(3,*) - stepsize sges(3) penalty
!    pbc(4,*) - stepsize sges(4) penalty
!    pbc(5,*) - contribution to numerator b
!    pbc(6,*) - contribution to denomonator c
!
!    linear terms -> pbc(*,1:ipenlin=3)
!    pbc(*,1)  contribution from background, sat rad bias, and precip bias
!    pbc(*,2)  placeholder for future linear linear term
!    pbc(*,3)  contribution from dry pressure constraint term (Jc)
!
!    nonlinear terms -> pbc(*,4:ipen)
!    pbc(*,4)  contribution from negative moisture constraint term (Jl/Jq)
!    pbc(*,5)  contribution from excess moisture term (Jl/Jq)
!    pbc(*,6)  contribution from ps observation  term (Jo)
!    pbc(*,7)  contribution from t observation  term (Jo)
!    pbc(*,8)  contribution from w observation  term (Jo)
!    pbc(*,9)  contribution from q observation  term (Jo)
!    pbc(*,10) contribution from spd observation  term (Jo)
!    pbc(*,11) contribution from srw observation  term (Jo)
!    pbc(*,12) contribution from rw observation  term (Jo)
!    pbc(*,13) contribution from dw observation  term (Jo)
!    pbc(*,14) contribution from sst observation  term (Jo)
!    pbc(*,15) contribution from pw observation  term (Jo)
!    pbc(*,16) contribution from pcp observation  term (Jo)
!    pbc(*,17) contribution from oz observation  term (Jo)
!    pbc(*,18) contribution from o3l observation  term (Jo)(not used)
!    pbc(*,19) contribution from gps observation  term (Jo)
!    pbc(*,20) contribution from rad observation  term (Jo)
!    pbc(*,21) contribution from tcp observation  term (Jo)
!


  pstart=zero_quad
  pbc=zero_quad

! penalty, b and c for background terms

  pstart(1,1) = qdot_prod_sub(xhatsave,yhatsave)
!  two terms in next line should be the same, but roundoff makes average more accurate.
  pstart(2,1) =-0.5_r_quad*(qdot_prod_sub(dirx,yhatsave)+qdot_prod_sub(diry,xhatsave))
  pstart(3,1) = qdot_prod_sub(dirx,diry)

! Contraint and 3dvar terms
  if(l_foto )then
    call allocate_state(dhat_dt)
    call assign_scalar2state(dhat_dt,zero)
    call stp3dvar(dval(1),dhat_dt)

  end if


! Penalty, b, c for dry pressure
  if (ljcpdry) call stpjcpdry(dval(1)%q,dval(1)%cw,dval(1)%p,sval(1)%q,sval(1)%cw,sval(1)%p,mype, &
                 pstart(1,3),pstart(2,3),pstart(3,3))

! iterate over number of stepsize iterations (istp_iter - currently set to 2)
  stepsize: do ii=1,istp_iter

    dels=one_tenth ** ii
!   Do nonlinear terms
  
    sges(2)=(one-dels)*stp(ii-1)
    sges(3)= stp(ii-1)
    sges(4)=(one+dels)*stp(ii-1)
    if(ii == 1)then
      sges(1)=zero
    else
      sges(1)=half*sges(2)
    end if

    do i=1,ipenlin
      do j=1,4
        pbc(j,i)=pstart(1,i)-2.0_r_quad*pstart(2,i)*sges(j)+ &
                                        pstart(3,i)*sges(j)*sges(j)
      end do
      pbc(5,i)=pstart(2,i)
      pbc(6,i)=pstart(3,i)
    end do

!   penalty, b, and c for moisture constraint
    if(.not.ltlint) call stplimq(dval(1)%q,sval(1)%q,sges,pbc(1,4),pbc(1,5))

!   stepsize and background for Jo
    do ibin=1,nobs_bins
      call stpjo(yobs(ibin),dval(ibin),dbias,sval(ibin),sbias,sges,pbc(1,6))
    enddo

!   Gather J contributions
    call mpl_allreduce(6,ipen,pbc)

!   penalty and sum b and sum c
    bpen=zero_quad
    cpen=zero_quad
    do i=1,ipen
      bpen(i)=bpen(i)+pbc(5,i)
      cpen(i)=cpen(i)+pbc(6,i)
    end do
    do i=1,4
     do j=1,ipen
      outpen((ii-1)*4+i) = outpen((ii-1)*4+i)+pbc(i,j)
     end do
     outstp((ii-1)*4+i) = sges(i)
    end do
    bx=zero_quad
    cx=zero_quad
    stpx=zero
    do i=1,ipen
      bx=bx+bpen(i)
      cx=cx+cpen(i)
      if(cpen(i) > 1.e-20_r_kind)stpx(i)=bpen(i)/cpen(i)
    end do

!   estimate of stepsize

    stp(ii)=stp(ii-1)
    if(cx > 1.e-20_r_kind) stp(ii)=bx/cx         ! step size estimate
!   stp(ii)=min(stp(ii),one)

    delpen = stp(ii)*(bx - 0.5_r_quad*stp(ii)*cx ) 

    if(ii == 1)then
      pjcost(1) = pbc(1,1)            ! Jb
      pjcost(3) = pbc(1,2) + pbc(1,3) ! Jc
      pjcost(4) = pbc(1,5) + pbc(1,4) ! Jl
      pjcost(2) = zero
      do i=1,nobs_type
        pjcost(2) = pjcost(2)+pbc(1,5+i) ! Jo
      end do
      penalty=pjcost(1)+pjcost(2)+pjcost(3)+pjcost(4)
    end if

    stpinout=stp(ii)
    if(abs(delpen/penalty) < 1.e-17_r_kind) then
      if(mype == 0)then
        if(ii == 1)write(iout_iter,100) (pbc(1,i),i=1,ipen)
        write(iout_iter,140) ii,delpen,bx,cx,stp(ii)
        write(iout_iter,101) (stpx(i),i=1,ipen)
        write(iout_iter,105) (bpen(i),i=1,ipen)
        write(iout_iter,110) (cpen(i),i=1,ipen)
      end if
      end_iter = .true.
!     Finalize timer
      call timer_fnl('stpcalc')
      return
    end if

! Check for negative stepsize or cx <= 0. (probable error or large nonlinearity)
    if(cx < 1.e-20_r_kind .or. stpinout < zero) then
      stpinout=outstp(1)
      outpensave=outpen(1)
      do i=2,ii*4
        if(outpen(i) < outpensave)then
          stpinout=outstp(i)
          stp(ii)=stpinout
          outpensave=outpen(i)
        end if
      end do
!  Try different (better?) stepsize
      if(stpinout <= zero .and. ii /= istp_iter)then
        stp(ii)=outstp(2)
        do i=3,ii*4
          stp(ii)=min(outstp(i),stp(ii))
        end do
        stp(ii)=one_tenth*stp(ii)
      end if
    end if

! Write out detailed results to iout_iter
    if(ii == 1 .and. mype == 0) then
      write(iout_iter,100) (pbc(1,i),i=1,ipen)
      write(iout_iter,101) (stpx(i),i=1,ipen)
      write(iout_iter,105) (bpen(i),i=1,ipen)
      write(iout_iter,110) (cpen(i),i=1,ipen)
    endif
100 format(' J=',3e25.18/,(3x,3e25.18))
101 format(' S=',3e25.18/,(3x,3e25.18))
105 format(' b=',3e25.18/,(3x,3e25.18))
110 format(' c=',3e25.18/,(3x,3e25.18))
130 format('***WARNING***  negative or small cx inner', &
           ' iteration terminated - probable error',i2,3e25.18)
140 format('***WARNING***  expected penalty reduction small ',/,  &
           ' inner iteration terminated - probable convergence',i2,4e25.18)

!  Check for convergence in stepsize estimation
    istp_use=ii
    stprat=zero
    if(stp(ii) > zero)then
      stprat=abs((stp(ii)-stp(ii-1))/stp(ii))
    end if
    if(mype == 0)write(6,*)' stprat ',stprat
    if(stprat < 1.e-4_r_kind) exit stepsize

  end do stepsize

!  Check for final stepsize negative (probable error)
  stpinout=stp(istp_use)
  if(stpinout < zero)then
    if(mype == 0)then
      write(iout_iter,130) ii,bx,cx,stp(ii)
      write(iout_iter,101) (stpx(i),i=1,ipen)
      write(iout_iter,105) (bpen(i),i=1,ipen)
      write(iout_iter,110) (cpen(i),i=1,ipen)
    end if
    end_iter = .true.
  end if
  if(mype == 0)then
    write(iout_iter,200) (stp(i),i=0,istp_use)
    write(iout_iter,201) (outstp(i),i=1,istp_use*4)
    write(iout_iter,202) (outpen(i)-outpen(1),i=1,istp_use*4)
  end if
200 format(' stepsize estimates = ',6(e24.18,1x))
201 format(' stepsize guesses = ',(8(e12.6,1x)))
202 format(' penalties        = ',(8(e12.6,1x)))

!  If convergence or failure of stepsize calculation return
  if (end_iter) then
    call timer_fnl('stpcalc')
    return
  endif

! Update solution
  do i=1,nclen
     xhat%values(i)=xhat%values(i)+stpinout*dirx%values(i)
     xhatsave%values(i)=xhatsave%values(i)+stpinout*dirx%values(i)
     yhatsave%values(i)=yhatsave%values(i)+stpinout*diry%values(i)
  end do

! Update time derivative of solution if required
  if(l_foto) then
     do i=1,nvals_len
       xhat_dt%values(i)=xhat_dt%values(i)+stpinout*dhat_dt%values(i)
     end do
     call tv_to_tsen(xhat_dt%t,xhat_dt%q,xhat_dt%tsen)
     call deallocate_state(dhat_dt)
  end if

! Finalize timer
  call timer_fnl('stpcalc')

  return
end subroutine stpcalc

end module stpcalcmod
