subroutine setupq(lunin,mype,bwork,awork,nele,nobs,is,conv_diagsave)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    setupq      compute rhs of oi for moisture observations
!   prgmmr: parrish          org: np22                date: 1990-10-06
!
! abstract:  For moisture observations, this routine
!              a) reads obs assigned to given mpi task (geographic region),
!              b) simulates obs from guess,
!              c) apply some quality control to obs,
!              d) load weight and innovation arrays used in minimization
!              e) collects statistics for runtime diagnostic output
!              f) writes additional diagnostic information to output file
!
! program history log:
!   1990-10-06  parrish
!   1998-04-10  weiyu yang
!   1999-03-01  wu - ozone processing moved into setuprhs from setupoz
!   1999-08-24  derber, j., treadon, r., yang, w., first frozen mpp version
!   2004-06-17  treadon - update documentation
!   2004-08-02  treadon - add only to module use, add intent in/out
!   2004-10-06  parrish - increase size of qwork array for nonlinear qc
!   2004-11-22  derber - remove weight, add logical for boundary point
!   2004-12-22  treadon - move logical conv_diagsave from obsmod to argument list
!   2005-03-02  dee - remove garbage from diagnostic file
!   2005-03-09  parrish - nonlinear qc change to account for inflated obs error
!   2005-05-27  derber - level output change
!   2005-07-27  derber  - add print of monitoring and reject data
!   2005-09-28  derber  - combine with prep,spr,remove tran and clean up
!   2005-10-06  treadon - lower huge_error to prevent overflow 
!   2005-10-14  derber  - input grid location and fix regional lat/lon
!   2005-10-21  su  - modify variational qc and diagonose output
!   2005-11-03  treadon - correct error in ilone,ilate data array indices
!   2005-11-21  kleist - change to call to genqsat
!   2005-11-21  derber - correct error in use of qsges
!   2005-11-22  wu     - add option to perturb conventional obs
!   2005-11-29  derber - remove psfcg and use ges_lnps instead
!   2006-01-31  todling - storing wgt/wgtlim in diag file instead of wgt only
!   2006-02-02  treadon - rename lnprsl as ges_lnprsl
!   2006-02-03  derber  - fix bug in counting rlow and rhgh
!   2006-02-24  derber  - modify to take advantage of convinfo module
!   2006-03-21  treadon - modify optional perturbation to observation
!   2006-04-03  derber  - eliminate unused arrays
!   2006-05-30  su,derber,treadon - modify diagnostic output
!   2006-06-06  su - move to wgtlim to constants module
!   2006-07-28  derber  - modify to use new inner loop obs data structure
!                       - modify handling of multiple data at same location
!   2006-07-31  kleist - use ges_ps instead of ln(ps)
!   2006-08-28      su - fix a bug in variational qc
!   2007-03-09      su - modify obs perturbation
!   2007-03-19  tremolet - binning of observations
!   2007-06-05  tremolet - add observation diagnostics structure
!   2007-08-28      su - modify gross check error  
!   2008-03-24      wu - oberror tuning and perturb obs
!   2008-05-23  safford - rm unused vars and uses
!   2008-12-03  todling - changed handle of tail%time
!   2009-02-06  pondeca - for each observation site, add the following to the
!                         diagnostic file: local terrain height, dominate surface
!                         type, station provider name, and station subprovider name
!   2009-08-19  guo     - changed for multi-pass setup with dtime_check().
!   2011-05-06  Su      - modify the observation gross check error
!   2011-08-09  pondeca - correct bug in qcgross use
!
!   input argument list:
!     lunin    - unit from which to read observations
!     mype     - mpi task id
!     nele     - number of data elements per observation
!     nobs     - number of observations
!
!   output argument list:
!     bwork    - array containing information about obs-ges statistics
!     awork    - array containing information for data counts and gross checks
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use mpeu_util, only: die,perr
  use kinds, only: r_kind,r_single,r_double,i_kind

  use obsmod, only: qtail,qhead,rmiss_single,perturb_obs,oberror_tune,&
       i_q_ob_type,obsdiags,lobsdiagsave,nobskeep,lobsdiag_allocated,&
       time_offset
  use obsmod, only: q_ob_type
  use obsmod, only: obs_diag
  use gsi_4dvar, only: nobs_bins,hr_obsbin
  use oneobmod, only: oneobtest,maginnov,magoberr
  use guess_grids, only: ges_lnprsl,ges_q,hrdifsig,nfldsig,ges_ps,ges_tsen,ges_prsl
  use gridmod, only: lat2,lon2,nsig,get_ijk,twodvar_regional
  use constants, only: zero,one,r1000,r10,r100
  use constants, only: huge_single,wgtlim,three
  use constants, only: tiny_r_kind,five,half,two,huge_r_kind,cg_term,r0_01
  use qcmod, only: npres_print,ptopq,pbotq,dfact,dfact1
  use jfunc, only: jiter,last,jiterstart,miter
  use convinfo, only: nconvtype,cermin,cermax,cgross,cvar_b,cvar_pg,ictype
  use convinfo, only: icsubtype
  use converr, only: ptabl 
  use m_dtime, only: dtime_setup, dtime_check, dtime_show
  implicit none

! Declare passed variables
  logical                                          ,intent(in   ) :: conv_diagsave
  integer(i_kind)                                  ,intent(in   ) :: lunin,mype,nele,nobs
  real(r_kind),dimension(100+7*nsig)               ,intent(inout) :: awork
  real(r_kind),dimension(npres_print,nconvtype,5,3),intent(inout) :: bwork
  integer(i_kind)                                  ,intent(in   ) :: is	! ndat index

! Declare local parameters
  real(r_kind),parameter:: small1=0.0001_r_kind
  real(r_kind),parameter:: small2=0.0002_r_kind
  real(r_kind),parameter:: r0_7=0.7_r_kind
  real(r_kind),parameter:: r8=8.0_r_kind
  real(r_kind),parameter:: r0_001 = 0.001_r_kind
  real(r_kind),parameter:: r1e16=1.e16_r_kind
  character(len=*),parameter:: myname='setupq'

! Declare external calls for code analysis
  external:: tintrp2a
  external:: tintrp3
  external:: grdcrd
  external:: genqsat
  external:: stop2

! Declare local variables  
  
  real(r_double) rstation_id
  real(r_kind) qob,qges,qsges
  real(r_kind) ratio_errors,dlat,dlon,dtime,dpres,rmaxerr,error
  real(r_kind) rsig,dprpx,rlow,rhgh,presq,tfact
  real(r_kind) psges,sfcchk,ddiff,errorx
  real(r_kind) cg_q,wgross,wnotgross,wgt,arg,exp_arg,term,rat_err2,qcgross
  real(r_kind) grsmlt,ratio,val2,obserror
  real(r_kind) obserrlm,residual,ressw2,scale,ress,huge_error
  real(r_kind) val,valqc,rwgt
  real(r_kind) errinv_input,errinv_adjst,errinv_final
  real(r_kind) err_input,err_adjst,err_final
  real(r_kind),dimension(nele,nobs):: data
  real(r_kind),dimension(nobs):: dup
  real(r_kind),dimension(lat2,lon2,nsig,nfldsig):: qg
  real(r_kind),dimension(nsig):: prsltmp
  real(r_single),allocatable,dimension(:,:)::rdiagbuf

  integer(i_kind) i,nchar,nreal,j,ii,l,jj,mm1,itemp
  integer(i_kind) jsig,itype,k,nn,ikxx,iptrb,ibin,ioff
  integer(i_kind) ier,ilon,ilat,ipres,iqob,id,itime,ikx,iqmax,iqc
  integer(i_kind) ier2,iuse,ilate,ilone,istnelv,iobshgt,istat,izz,iprvd,isprvd
  integer(i_kind) idomsfc,iskint,isfcr,iff10,iderivative

  character(8) station_id
  character(8),allocatable,dimension(:):: cdiagbuf
  character(8),allocatable,dimension(:):: cprvstg,csprvstg
  character(8) c_prvstg,c_sprvstg
  real(r_double) r_prvstg,r_sprvstg

  logical ice
  logical,dimension(nobs):: luse,muse

  logical:: in_curbin, in_anybin
  integer(i_kind),dimension(nobs_bins) :: n_alloc
  integer(i_kind),dimension(nobs_bins) :: m_alloc
  type(q_ob_type),pointer:: my_head
  type(obs_diag),pointer:: my_diag

  equivalence(rstation_id,station_id)
  equivalence(r_prvstg,c_prvstg)
  equivalence(r_sprvstg,c_sprvstg)

  n_alloc(:)=0
  m_alloc(:)=0
!*******************************************************************************
! Read and reformat observations in work arrays.
  read(lunin)data,luse

  ier=1       ! index of obs error
  ilon=2      ! index of grid relative obs location (x)
  ilat=3      ! index of grid relative obs location (y)
  ipres=4     ! index of pressure
  iqob=5      ! index of q observation
  id=6        ! index of station id
  itime=7     ! index of observation time in data array
  ikxx=8      ! index of ob type
  iqmax=9     ! index of max error
  itemp=10    ! index of dry temperature
  iqc=11      ! index of quality mark
  ier2=12     ! index of original-original obs error ratio
  iuse=13     ! index of use parameter
  idomsfc=14  ! index of dominant surface type
  iskint=15   ! index of surface skin temperature
  iff10=16    ! index of 10 meter wind factor
  isfcr=17    ! index of surface roughness
  ilone=18    ! index of longitude (degrees)
  ilate=19    ! index of latitude (degrees)
  istnelv=20  ! index of station elevation (m)
  iobshgt=21  ! index of observation height (m)
  izz=22      ! index of surface height
  iprvd=23    ! index of observation provider
  isprvd=24   ! index of observation subprovider
  iptrb=25    ! index of q perturbation

  do i=1,nobs
     muse(i)=nint(data(iuse,i)) <= jiter
  end do

  dup=one
  do k=1,nobs
     do l=k+1,nobs
        if(data(ilat,k) == data(ilat,l) .and.  &
           data(ilon,k) == data(ilon,l) .and.  &
           data(ipres,k) == data(ipres,l) .and. &
           data(ier,k) < r1000 .and. data(ier,l) < r1000 .and. &
           muse(k) .and. muse(l))then
           tfact=min(one,abs(data(itime,k)-data(itime,l))/dfact1)
           dup(k)=dup(k)+one-tfact*tfact*(one-dfact)
           dup(l)=dup(l)+one-tfact*tfact*(one-dfact)
        end if
     end do
  end do


! If requested, save select data for output to diagnostic file
  if(conv_diagsave)then
     ii=0
     nchar=1
     nreal=20
     if (lobsdiagsave) nreal=nreal+4*miter+1
     if (twodvar_regional) then; nreal=nreal+2; allocate(cprvstg(nobs),csprvstg(nobs)); endif
     allocate(cdiagbuf(nobs),rdiagbuf(nreal,nobs))
  end if
  rsig=nsig

  mm1=mype+1
  grsmlt=five  ! multiplier factor for gross error check
  huge_error = huge_r_kind/r1e16
  scale=one

  ice=.false.   ! get larger (in rh) q obs error for mixed and ice phases

! new code
! ice=.true.  ! get same (in rh) q obs error for mixed and ice phases

  iderivative=0
  do jj=1,nfldsig
     call genqsat(qg(1,1,1,jj),ges_tsen(1,1,1,jj),ges_prsl(1,1,1,jj),lat2,lon2,nsig,ice,iderivative)
  end do


! Prepare specific humidity data
  call dtime_setup()
  do i=1,nobs
     dtime=data(itime,i)
     call dtime_check(dtime, in_curbin, in_anybin)
     if(.not.in_anybin) cycle

     if(in_curbin) then
!       Convert obs lats and lons to grid coordinates
        dlat=data(ilat,i)
        dlon=data(ilon,i)
        dpres=data(ipres,i)

        rmaxerr=data(iqmax,i)
        ikx=nint(data(ikxx,i))
        error=data(ier2,i)
     endif ! (in_curbin)

!    Link observation to appropriate observation bin
     if (nobs_bins>1) then
        ibin = NINT( dtime/hr_obsbin ) + 1
     else
        ibin = 1
     endif
     IF (ibin<1.OR.ibin>nobs_bins) write(6,*)mype,'Error nobs_bins,ibin= ',nobs_bins,ibin

!    Link obs to diagnostics structure
     if (.not.lobsdiag_allocated) then
        if (.not.associated(obsdiags(i_q_ob_type,ibin)%head)) then
           allocate(obsdiags(i_q_ob_type,ibin)%head,stat=istat)
           if (istat/=0) then
              write(6,*)'setupq: failure to allocate obsdiags',istat
              call stop2(272)
           end if
           obsdiags(i_q_ob_type,ibin)%tail => obsdiags(i_q_ob_type,ibin)%head
        else
           allocate(obsdiags(i_q_ob_type,ibin)%tail%next,stat=istat)
           if (istat/=0) then
              write(6,*)'setupq: failure to allocate obsdiags',istat
              call stop2(273)
           end if
           obsdiags(i_q_ob_type,ibin)%tail => obsdiags(i_q_ob_type,ibin)%tail%next
        end if
        allocate(obsdiags(i_q_ob_type,ibin)%tail%muse(miter+1))
        allocate(obsdiags(i_q_ob_type,ibin)%tail%nldepart(miter+1))
        allocate(obsdiags(i_q_ob_type,ibin)%tail%tldepart(miter))
        allocate(obsdiags(i_q_ob_type,ibin)%tail%obssen(miter))
        obsdiags(i_q_ob_type,ibin)%tail%indxglb=i
        obsdiags(i_q_ob_type,ibin)%tail%nchnperobs=-99999
        obsdiags(i_q_ob_type,ibin)%tail%luse=.false.
        obsdiags(i_q_ob_type,ibin)%tail%muse(:)=.false.
        obsdiags(i_q_ob_type,ibin)%tail%nldepart(:)=-huge(zero)
        obsdiags(i_q_ob_type,ibin)%tail%tldepart(:)=zero
        obsdiags(i_q_ob_type,ibin)%tail%wgtjo=-huge(zero)
        obsdiags(i_q_ob_type,ibin)%tail%obssen(:)=zero

        n_alloc(ibin) = n_alloc(ibin) +1
        my_diag => obsdiags(i_q_ob_type,ibin)%tail
        my_diag%idv = is
        my_diag%iob = i
        my_diag%ich = 1
     else
        if (.not.associated(obsdiags(i_q_ob_type,ibin)%tail)) then
           obsdiags(i_q_ob_type,ibin)%tail => obsdiags(i_q_ob_type,ibin)%head
        else
           obsdiags(i_q_ob_type,ibin)%tail => obsdiags(i_q_ob_type,ibin)%tail%next
        end if
        if (obsdiags(i_q_ob_type,ibin)%tail%indxglb/=i) then
           write(6,*)'setupq: index error'
           call stop2(274)
        end if
     endif

     if(.not.in_curbin) cycle

! Interpolate log(ps) & log(pres) at mid-layers to obs locations/times
     call tintrp2a(ges_ps,psges,dlat,dlon,dtime,hrdifsig,&
          1,1,mype,nfldsig)
     call tintrp2a(ges_lnprsl,prsltmp,dlat,dlon,dtime,hrdifsig,&
          1,nsig,mype,nfldsig)

     presq=r10*exp(dpres)
     itype=ictype(ikx)
     dprpx=zero
     if(itype > 179 .and. itype < 190 .and. .not.twodvar_regional)then
        dprpx=abs(one-exp(dpres-log(psges)))*r10
!       dprpx=abs(presq-r10*psges)*0.0025_r_kind
     end if

!    Put obs pressure in correct units to get grid coord. number
     call grdcrd(dpres,1,prsltmp(1),nsig,-1)

!    Get approximate k value of surface by using surface pressure
     sfcchk=log(psges)
     call grdcrd(sfcchk,1,prsltmp(1),nsig,-1)

!    Check to see if observations is above the top of the model (regional mode)
     if( dpres>=nsig+1)dprpx=1.e6_r_kind
     if(itype > 179 .and. itype < 186) dpres=one

!    Scale errors by guess saturation q
 
     call tintrp3(qg,qsges,dlat,dlon,dpres,dtime,hrdifsig,&
          1,mype,nfldsig)

!    Load obs error and value into local variables
     obserror = max(cermin(ikx)*r0_01,min(cermax(ikx)*r0_01,data(ier,i)))
     qob = data(iqob,i) 

     rmaxerr=rmaxerr*qsges
     rmaxerr=max(small2,rmaxerr)
     errorx =(data(ier,i)+dprpx)*qsges
     errorx =max(small1,errorx)
    

!    Adjust observation error to reflect the size of the residual.
!    If extrapolation occurred, then further adjust error according to
!    amount of extrapolation.

     rlow=max(sfcchk-dpres,zero)
     rhgh=max(dpres-r0_001-rsig,zero)
     
     if(luse(i))then
        awork(1) = awork(1) + one
        if(rlow/=zero) awork(2) = awork(2) + one
        if(rhgh/=zero) awork(3) = awork(3) + one
     end if

     ratio_errors=error*qsges/(errorx+1.0e6_r_kind*rhgh+r8*rlow)

!    Check to see if observations is above the top of the model (regional mode)
     if (dpres > rsig) ratio_errors=zero
     error=one/(error*qsges)


! Interpolate guess moisture to observation location and time
     call tintrp3(ges_q,qges,dlat,dlon,dpres,dtime, &
        hrdifsig,1,mype,nfldsig)

! Compute innovations

     ddiff=qob-qges

!    If requested, setup for single obs test.
     if (oneobtest) then
        ddiff=maginnov*1.e-3_r_kind
        error=one/(magoberr*1.e-3_r_kind)
        ratio_errors=one
     end if

!    Gross error checks

     if(abs(ddiff) > grsmlt*data(iqmax,i)) then
        error=zero
        ratio_errors=zero


        if(luse(i))awork(5)=awork(5)+one
     end if
     obserror=min(one/max(ratio_errors*error,tiny_r_kind),huge_error)
     obserror=obserror*r100/qsges
     obserrlm=max(cermin(ikx),min(cermax(ikx),obserror))
     residual=abs(ddiff*r100/qsges)
     ratio=residual/obserrlm

! modify gross check limit for quality mark=3
     if(data(iqc,i) == three ) then
        qcgross=r0_7*cgross(ikx)
     else
        qcgross=cgross(ikx)
     endif

     if(ratio > qcgross .or. ratio_errors < tiny_r_kind) then
        if(luse(i))awork(4)=awork(4)+one
        error=zero
        ratio_errors=zero

     else
        ratio_errors=ratio_errors/sqrt(dup(i))
     end if

     if (ratio_errors*error <=tiny_r_kind) muse(i)=.false.
     if (nobskeep>0) muse(i)=obsdiags(i_q_ob_type,ibin)%tail%muse(nobskeep)

!   Oberror Tuning and Perturb Obs
     if(muse(i)) then
        if(oberror_tune )then
           if( jiter > jiterstart ) then
              ddiff=ddiff+data(iptrb,i)/error/ratio_errors
           endif
        else if(perturb_obs )then
           ddiff=ddiff+data(iptrb,i)/error/ratio_errors  
        endif
     endif


!    Compute penalty terms
     val      = error*ddiff
     if(luse(i))then

        val2     = val*val
        exp_arg  = -half*val2
        rat_err2 = ratio_errors**2
        if (cvar_pg(ikx) > tiny_r_kind .and. error >tiny_r_kind) then
           arg  = exp(exp_arg)
           wnotgross= one-cvar_pg(ikx)
           cg_q=cvar_b(ikx)
           wgross = cg_term*cvar_pg(ikx)/(cg_q*wnotgross)
           term =log((arg+wgross)/(one+wgross))
           wgt  = one-wgross/(arg+wgross)
           rwgt = wgt/wgtlim
        else
           term = exp_arg
           wgt  = wgtlim
           rwgt = wgt/wgtlim
        endif
        valqc = -two*rat_err2*term
        
!       Accumulate statistics for obs belonging to this task
        if(muse(i))then
           if(rwgt < one) awork(21) = awork(21)+one
           jsig = dpres
           jsig=max(1,min(jsig,nsig))
           awork(jsig+5*nsig+100)=awork(jsig+5*nsig+100)+val2*rat_err2
           awork(jsig+6*nsig+100)=awork(jsig+6*nsig+100)+one
           awork(jsig+3*nsig+100)=awork(jsig+3*nsig+100)+valqc
        end if
! Loop over pressure level groupings and obs to accumulate statistics
! as a function of observation type.
        ress  = scale*r100*ddiff/qsges
        ressw2= ress*ress
        nn=1
        if (.not. muse(i)) then
           nn=2
           if(ratio_errors*error >=tiny_r_kind)nn=3
        end if
        do k = 1,npres_print
           if(presq >= ptopq(k) .and. presq <= pbotq(k))then
 
              bwork(k,ikx,1,nn)  = bwork(k,ikx,1,nn)+one             ! count
              bwork(k,ikx,2,nn)  = bwork(k,ikx,2,nn)+ress            ! (o-g)
              bwork(k,ikx,3,nn)  = bwork(k,ikx,3,nn)+ressw2          ! (o-g)**2
              bwork(k,ikx,4,nn)  = bwork(k,ikx,4,nn)+val2*rat_err2   ! penalty
              bwork(k,ikx,5,nn)  = bwork(k,ikx,5,nn)+valqc           ! nonlin qc penalty
           end if
        end do
     end if

     obsdiags(i_q_ob_type,ibin)%tail%luse=luse(i)
     obsdiags(i_q_ob_type,ibin)%tail%muse(jiter)=muse(i)
     obsdiags(i_q_ob_type,ibin)%tail%nldepart(jiter)=ddiff
     obsdiags(i_q_ob_type,ibin)%tail%wgtjo= (error*ratio_errors)**2

!    If obs is "acceptable", load array with obs info for use
!    in inner loop minimization (int* and stp* routines)
     if (.not. last .and. muse(i)) then

        if(.not. associated(qhead(ibin)%head))then
           allocate(qhead(ibin)%head,stat=istat)
           if(istat /= 0)write(6,*)' failure to write qhead '
           qtail(ibin)%head => qhead(ibin)%head
        else
           allocate(qtail(ibin)%head%llpoint,stat=istat)
           if(istat /= 0)write(6,*)' failure to write qtail%llpoint '
           qtail(ibin)%head => qtail(ibin)%head%llpoint
        end if

        m_alloc(ibin) = m_alloc(ibin) +1
        my_head => qtail(ibin)%head
        my_head%idv = is
        my_head%iob = i

!       Set (i,j,k) indices of guess gridpoint that bound obs location
        call get_ijk(mm1,dlat,dlon,dpres,qtail(ibin)%head%ij(1),qtail(ibin)%head%wij(1))
        
        qtail(ibin)%head%res    = ddiff
        qtail(ibin)%head%err2   = error**2
        qtail(ibin)%head%raterr2= ratio_errors**2   
        qtail(ibin)%head%time   = dtime
        qtail(ibin)%head%b      = cvar_b(ikx)
        qtail(ibin)%head%pg     = cvar_pg(ikx)
        qtail(ibin)%head%luse   = luse(i)

        if(oberror_tune) then
           qtail(ibin)%head%qpertb=data(iptrb,i)/error/ratio_errors
           qtail(ibin)%head%kx=ikx
           if(presq > ptabl(2))then
              qtail(ibin)%head%k1=1
           else if( presq <= ptabl(33)) then
              qtail(ibin)%head%k1=33
           else
              k_loop: do k=2,32
                 if(presq > ptabl(k+1) .and. presq <= ptabl(k)) then
                    qtail(ibin)%head%k1=k
                    exit k_loop
                 endif
              enddo k_loop
           endif
        endif

        qtail(ibin)%head%diags => obsdiags(i_q_ob_type,ibin)%tail

        my_head => qtail(ibin)%head
        my_diag => qtail(ibin)%head%diags
        if(my_head%idv /= my_diag%idv .or. &
           my_head%iob /= my_diag%iob ) then
           call perr(myname,'mismatching %[head,diags]%(idv,iob,ibin) =', &
                 (/is,i,ibin/))
           call perr(myname,'my_head%(idv,iob) =',(/my_head%idv,my_head%iob/))
           call perr(myname,'my_diag%(idv,iob) =',(/my_diag%idv,my_diag%iob/))
           call die(myname)
	endif
        
     endif

! Save select output for diagnostic file
     if(conv_diagsave .and. luse(i))then
        ii=ii+1
        rstation_id     = data(id,i)
        cdiagbuf(ii)    = station_id         ! station id

        rdiagbuf(1,ii)  = ictype(ikx)        ! observation type
        rdiagbuf(2,ii)  = icsubtype(ikx)     ! observation subtype
    
        rdiagbuf(3,ii)  = data(ilate,i)      ! observation latitude (degrees)
        rdiagbuf(4,ii)  = data(ilone,i)      ! observation longitude (degrees)
        rdiagbuf(5,ii)  = data(istnelv,i)    ! station elevation (meters)
        rdiagbuf(6,ii)  = presq              ! observation pressure (hPa)
        rdiagbuf(7,ii)  = data(iobshgt,i)    ! observation height (meters)
        rdiagbuf(8,ii)  = dtime-time_offset  ! obs time (hours relative to analysis time)

        rdiagbuf(9,ii)  = data(iqc,i)        ! input prepbufr qc or event mark
        rdiagbuf(10,ii) = rmiss_single       ! setup qc or event mark 
        rdiagbuf(11,ii) = data(iuse,i)       ! read_prepbufr data usage flag
        if(muse(i)) then
           rdiagbuf(12,ii) = one             ! analysis usage flag (1=use, -1=not used)
        else
           rdiagbuf(12,ii) = -one                    
        endif

        err_input = data(ier2,i)*qsges            ! convert rh to q
        err_adjst = data(ier,i)*qsges             ! convert rh to q
        if (ratio_errors*error>tiny_r_kind) then
           err_final = one/(ratio_errors*error)
        else
           err_final = huge_single
        endif

        errinv_input = huge_single
        errinv_adjst = huge_single
        errinv_final = huge_single
        if (err_input>tiny_r_kind) errinv_input = one/err_input
        if (err_adjst>tiny_r_kind) errinv_adjst = one/err_adjst
        if (err_final>tiny_r_kind) errinv_final = one/err_final

        rdiagbuf(13,ii) = rwgt               ! nonlinear qc relative weight
        rdiagbuf(14,ii) = errinv_input       ! prepbufr inverse observation error
        rdiagbuf(15,ii) = errinv_adjst       ! read_prepbufr inverse obs error
        rdiagbuf(16,ii) = errinv_final       ! final inverse observation error

        rdiagbuf(17,ii) = data(iqob,i)       ! observation
        rdiagbuf(18,ii) = ddiff              ! obs-ges used in analysis
        rdiagbuf(19,ii) = qob-qges           ! obs-ges w/o bias correction (future slot)

        rdiagbuf(20,ii) = qsges              ! guess saturation specific humidity

        ioff=20
        if (lobsdiagsave) then
           do jj=1,miter 
              ioff=ioff+1 
              if (obsdiags(i_q_ob_type,ibin)%tail%muse(jj)) then
                 rdiagbuf(ioff,ii) = one
              else
                 rdiagbuf(ioff,ii) = -one
              endif
           enddo
           do jj=1,miter+1
              ioff=ioff+1
              rdiagbuf(ioff,ii) = obsdiags(i_q_ob_type,ibin)%tail%nldepart(jj)
           enddo
           do jj=1,miter
              ioff=ioff+1
              rdiagbuf(ioff,ii) = obsdiags(i_q_ob_type,ibin)%tail%tldepart(jj)
           enddo
           do jj=1,miter
              ioff=ioff+1
              rdiagbuf(ioff,ii) = obsdiags(i_q_ob_type,ibin)%tail%obssen(jj)
           enddo
        endif
        
        if (twodvar_regional) then
           rdiagbuf(ioff+1,ii) = data(idomsfc,i) ! dominate surface type
           rdiagbuf(ioff+2,ii) = data(izz,i)     ! model terrain at ob location
           r_prvstg            = data(iprvd,i)
           cprvstg(ii)         = c_prvstg        ! provider name
           r_sprvstg           = data(isprvd,i)
           csprvstg(ii)        = c_sprvstg       ! subprovider name
        endif

     end if

! End of loop over observations
  end do
  

! Write information to diagnostic file
  if(conv_diagsave)then
     call dtime_show(myname,'diagsave:q',i_q_ob_type)
     write(7)'  q',nchar,nreal,ii,mype
     write(7)cdiagbuf(1:ii),rdiagbuf(:,1:ii)
     deallocate(cdiagbuf,rdiagbuf)

     if (twodvar_regional) then
        write(7)cprvstg(1:ii),csprvstg(1:ii)
        deallocate(cprvstg,csprvstg)
     endif
  end if

! End of routine
end subroutine setupq

