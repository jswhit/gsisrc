subroutine setuppw(lunin,mype,bwork,awork,nele,nobs,conv_diagsave)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    setuppw     compute rhs of oi for total column water
!   prgmmr: parrish          org: np22                date: 1990-10-06
!
! abstract:  For total column water, this routine
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
!   2003-12-23  kleist - modify to use delta(pressure) from guess fields
!   2004-06-17  treadon - update documentation
!   2004-08-02  treadon - add only to module use, add intent in/out
!   2004-10-06  parrish - increase size of pwwork array for nonlinear qc
!   2004-11-22  derber - remove weight, add logical for boundary point
!   2004-12-22  treadon - move logical conv_diagsave from obsmod to argument list
!   2005-02-10  treadon - move initialization of dp_pw into routine sprpw
!   2005-03-02  dee - remove garbage from diagnostic file
!   2005-03-09  parrish - nonlinear qc change to account for inflated obs error
!   2005-07-27  derber  - add print of monitoring and reject data
!   2005-09-28  derber  - combine with prep,spr,remove tran and clean up
!   2005-10-14  derber  - input grid location and fix regional lat/lon
!   2005-11-03  treadon - correct error in ilone,ilate data array indices
!   2005-11-14  pondeca - correct error in diagnostic array index
!   2006-01-31  todling/treadon - store wgt/wgtlim in rdiagbuf(6,ii)
!   2006-02-02  treadon - rename prsi as ges_prsi
!   2006-02-24  derber  - modify to take advantage of convinfo module
!   2006-05-30  su,derber,treadon - modify diagnostic output
!   2006-06-06  su - move to wgtlim to constants module
!   2006-07-28  derber  - modify to use new inner loop obs data structure
!                       - modify handling of multiple data at same location
!                       - unify NL qc
!   2006-08-28      su  - fix a bug in variational qc
!   2007-03-19  tremolet - binning of observations
!   2007-06-05  tremolet - add observation diagnostics structure
!   2007-08-28      su  - modify gross check error 
!   2008-12-03  todling - changed handle of tail%time
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
  use kinds, only: r_kind,r_single,r_double,i_kind
  use guess_grids, only: ges_q,ges_prsi,hrdifsig,nfldsig
  use gridmod, only: lat2,lon2,nsig,get_ij
  use obsmod, only: pwhead,pwtail,rmiss_single,i_pw_ob_type,obsdiags,&
                    lobsdiagsave,nobskeep,lobsdiag_allocated,time_offset
  use gsi_4dvar, only: nobs_bins,hr_obsbin
  use constants, only: zero,one,tpwcon,r1000, &
       tiny_r_kind,three,half,two,cg_term,huge_single,&
       wgtlim
  use jfunc, only: jiter,last,miter
  use qcmod, only: dfact,dfact1,npres_print
  use convinfo, only: nconvtype,cermin,cermax,cgross,cvar_b,cvar_pg,ictype
  use convinfo, only: icsubtype
  implicit none

! Declare local parameter
  real(r_kind),parameter:: r0_01 = 0.01_r_kind
  real(r_kind),parameter:: ten = 10.0_r_kind

! Declare passed variables
  logical,intent(in):: conv_diagsave
  integer(i_kind),intent(in):: lunin,mype,nele,nobs
  real(r_kind),dimension(100+7*nsig),intent(inout):: awork
  real(r_kind),dimension(npres_print,nconvtype,5,3),intent(inout):: bwork


! Declare local variables
  real(r_double) rstation_id
  real(r_kind):: pwges,grsmlt,dlat,dlon,dtime,obserror, &
       obserrlm,residual,ratio,dpw
  real(r_kind) error,ddiff
  real(r_kind) ressw2,ress,scale,val2,val,valqc
  real(r_kind) rat_err2,exp_arg,term,ratio_errors,rwgt
  real(r_kind) cg_pw,wgross,wnotgross,wgt,arg
  real(r_kind) errinv_input,errinv_adjst,errinv_final
  real(r_kind) err_input,err_adjst,err_final,tfact
  real(r_kind),dimension(nobs)::dup
  real(r_kind),dimension(nele,nobs):: data
  real(r_kind),dimension(lat2,lon2,nfldsig)::rp2
  real(r_kind),dimension(nsig+1):: prsitmp
  real(r_single),allocatable,dimension(:,:)::rdiagbuf

  integer(i_kind) ikxx,nn,istat,ibin,ioff
  integer(i_kind) i,nchar,nreal,k,j,jj,ii,l,mm1
  integer(i_kind) ier,ilon,ilat,ipw,id,itime,ikx,ipwmax,iqc
  integer(i_kind) ier2,iuse,ilate,ilone,istnelv,iobshgt,iobsprs
  integer(i_kind) idomsfc,iskint,iff10,isfcr

  logical,dimension(nobs):: luse,muse
  
  character(8) station_id
  character(8),allocatable,dimension(:):: cdiagbuf

  equivalence(rstation_id,station_id)


  grsmlt=three  ! multiplier factor for gross check
  mm1=mype+1
  scale=one

!******************************************************************************
! Read and reformat observations in work arrays.
! Simulate tpw from guess (forward model)
  rp2=zero
  do jj=1,nfldsig
     do k=1,nsig
        do j=1,lon2
           do i=1,lat2
              rp2(i,j,jj)=rp2(i,j,jj) + ges_q(i,j,k,jj) * &
                   tpwcon*ten*(ges_prsi(i,j,k,jj)-ges_prsi(i,j,k+1,jj))    ! integrate q
           end do
        end do
     end do
  end do

  read(lunin)data,luse

!        index information for data array (see reading routine)
  ier=1       ! index of obs error
  ilon=2      ! index of grid relative obs location (x)
  ilat=3      ! index of grid relative obs location (y)
  ipw = 4     ! index of pw observations
  id=5        ! index of station id
  itime=6     ! index of observation time in data array
  ikxx=7      ! index of ob type
  ipwmax=8    ! index of pw max error
  iqc=9       ! index of quality mark
  ier2=10     ! index of original-original obs error ratio
  iuse=11     ! index of use parameter
  idomsfc=12  ! index of dominant surface type
  iskint=13   ! index of surface skin temperature
  iff10=14    ! index of 10 meter wind factor
  isfcr=15    ! index of surface roughness
  ilone=16    ! index of longitude (degrees)
  ilate=17    ! index of latitude (degrees)
  istnelv=18  ! index of station elevation (m)
  iobsprs=19  ! index of observation pressure (hPa)
  iobshgt=20  ! index of observation height (m)

  do i=1,nobs
    muse(i)=nint(data(11,i)) <= jiter
  end do

  dup=one
  do k=1,nobs
    do l=k+1,nobs
      if(data(ilat,k) == data(ilat,l) .and.  &
         data(ilon,k) == data(ilon,l) .and. &
         data(ier,k) < r1000 .and. data(ier,l) < r1000 .and. &
         muse(k) .and. muse(l)) then
        tfact=min(one,abs(data(itime,k)-data(itime,l))/dfact1)
        dup(k)=dup(k)+one-tfact*tfact*(one-dfact)
        dup(l)=dup(l)+one-tfact*tfact*(one-dfact)
      end if
    end do
  end do

! If requested, save select data for output to diagnostic file
  if(conv_diagsave)then
     nchar=1
     nreal=19
     if (lobsdiagsave) nreal=nreal+4*miter+1
     allocate(cdiagbuf(nobs),rdiagbuf(nreal,nobs))
     ii=0
  end if


! Prepare total precipitable water data
  do i=1,nobs

     dlat=data(ilat,i)
     dlon=data(ilon,i)

     dtime=data(itime,i)
     dpw=data(ipw,i)
     ikx = nint(data(ikxx,i))
     error=data(ier2,i)

     ratio_errors=error/data(ier,i)
     error=one/error

!    Link observation to appropriate observation bin
     if (nobs_bins>1) then
       ibin = NINT( dtime/hr_obsbin ) + 1
     else
       ibin = 1
     endif
     IF (ibin<1.OR.ibin>nobs_bins) write(6,*)mype,'Error nobs_bins,ibin= ',nobs_bins,ibin
  
!    Link obs to diagnostics structure
     if (.not.lobsdiag_allocated) then
       if (.not.associated(obsdiags(i_pw_ob_type,ibin)%head)) then
         allocate(obsdiags(i_pw_ob_type,ibin)%head,stat=istat)
         if (istat/=0) then
           write(6,*)'setuppw: failure to allocate obsdiags',istat
           call stop2(269)
         end if
         obsdiags(i_pw_ob_type,ibin)%tail => obsdiags(i_pw_ob_type,ibin)%head
       else
         allocate(obsdiags(i_pw_ob_type,ibin)%tail%next,stat=istat)
         if (istat/=0) then
           write(6,*)'setuppw: failure to allocate obsdiags',istat
           call stop2(270)
         end if
         obsdiags(i_pw_ob_type,ibin)%tail => obsdiags(i_pw_ob_type,ibin)%tail%next
       end if
       allocate(obsdiags(i_pw_ob_type,ibin)%tail%muse(miter+1))
       allocate(obsdiags(i_pw_ob_type,ibin)%tail%nldepart(miter+1))
       allocate(obsdiags(i_pw_ob_type,ibin)%tail%tldepart(miter))
       allocate(obsdiags(i_pw_ob_type,ibin)%tail%obssen(miter))
       obsdiags(i_pw_ob_type,ibin)%tail%indxglb=i
       obsdiags(i_pw_ob_type,ibin)%tail%nchnperobs=-99999
       obsdiags(i_pw_ob_type,ibin)%tail%luse=.false.
       obsdiags(i_pw_ob_type,ibin)%tail%muse(:)=.false.
       obsdiags(i_pw_ob_type,ibin)%tail%nldepart(:)=-huge(zero)
       obsdiags(i_pw_ob_type,ibin)%tail%tldepart(:)=zero
       obsdiags(i_pw_ob_type,ibin)%tail%wgtjo=-huge(zero)
       obsdiags(i_pw_ob_type,ibin)%tail%obssen(:)=zero
     else
       if (.not.associated(obsdiags(i_pw_ob_type,ibin)%tail)) then
         obsdiags(i_pw_ob_type,ibin)%tail => obsdiags(i_pw_ob_type,ibin)%head
       else
         obsdiags(i_pw_ob_type,ibin)%tail => obsdiags(i_pw_ob_type,ibin)%tail%next
       end if
       if (obsdiags(i_pw_ob_type,ibin)%tail%indxglb/=i) then
         write(6,*)'setuppw: index error'
         call stop2(271)
       end if
     endif

 
     call tintrp2a(rp2,pwges,dlat,dlon,dtime, &
        hrdifsig,1,1,mype,nfldsig)

! Interpolate pressure at interface values to obs location
     call tintrp2a(ges_prsi,prsitmp,dlat,dlon,dtime, &
         hrdifsig,1,nsig+1,mype,nfldsig)

! Compute innovations
     ddiff=dpw-pwges

!    Gross checks using innovation

     residual = abs(ddiff)
     if (residual>grsmlt*data(ipwmax,i)) then
        error = zero
        ratio_errors=zero
        if (luse(i)) awork(7) = awork(7)+one
     end if
     obserror = one/max(ratio_errors*error,tiny_r_kind)
     obserrlm = max(cermin(ikx),min(cermax(ikx),obserror))
     ratio    = residual/obserrlm
     if (ratio> cgross(ikx) .or. ratio_errors < tiny_r_kind) then
        if (luse(i)) awork(6) = awork(6)+one
        error = zero
        ratio_errors=zero
     else
       ratio_errors=ratio_errors/sqrt(dup(i))
     end if
     if (ratio_errors*error <= tiny_r_kind) muse(i)=.false.
     if (nobskeep>0) muse(i)=obsdiags(i_pw_ob_type,ibin)%tail%muse(nobskeep)

     val      = error*ddiff

     if(luse(i))then
!    Compute penalty terms (linear & nonlinear qc).
        val2     = val*val
        exp_arg  = -half*val2
        rat_err2 = ratio_errors**2
        if (cvar_pg(ikx) > tiny_r_kind .and. error > tiny_r_kind) then
           arg  = exp(exp_arg)
           wnotgross= one-cvar_pg(ikx)
           cg_pw=cvar_b(ikx)
           wgross = cg_term*cvar_pg(ikx)/(cg_pw*wnotgross)
           term = log((arg+wgross)/(one+wgross))
           wgt  = one-wgross/(arg+wgross)
           rwgt = wgt/wgtlim
        else
           term = exp_arg
           wgt  = wgtlim
           rwgt = wgt/wgtlim
        endif
        valqc = -two*rat_err2*term

! Accumulate statistics as a function of observation type.
        ress  = ddiff*scale
        ressw2= ress*ress
        val2  = val*val
        rat_err2 = ratio_errors**2
!       Accumulate statistics for obs belonging to this task
        if (muse(i) ) then
          if(rwgt < one) awork(21) = awork(21)+one
          awork(5) = awork(5)+val2*rat_err2
          awork(4) = awork(4)+one
          awork(22)=awork(22)+valqc
          nn=1
        else
          nn=2
          if(ratio_errors*error >=tiny_r_kind)nn=3
        end if
        bwork(1,ikx,1,nn)  = bwork(1,ikx,1,nn)+one             ! count
        bwork(1,ikx,2,nn)  = bwork(1,ikx,2,nn)+ress            ! (o-g)
        bwork(1,ikx,3,nn)  = bwork(1,ikx,3,nn)+ressw2          ! (o-g)**2
        bwork(1,ikx,4,nn)  = bwork(1,ikx,4,nn)+val2*rat_err2   ! penalty
        bwork(1,ikx,5,nn)  = bwork(1,ikx,5,nn)+valqc           ! nonlin qc penalty
        
     end if

     obsdiags(i_pw_ob_type,ibin)%tail%luse=luse(i)
     obsdiags(i_pw_ob_type,ibin)%tail%muse(jiter)=muse(i)
     obsdiags(i_pw_ob_type,ibin)%tail%nldepart(jiter)=ddiff
     obsdiags(i_pw_ob_type,ibin)%tail%wgtjo= (error*ratio_errors)**2

!    If obs is "acceptable", load array with obs info for use
!    in inner loop minimization (int* and stp* routines)
     if ( .not. last .and. muse(i)) then

        if(.not. associated(pwhead(ibin)%head))then
            allocate(pwhead(ibin)%head,stat=istat)
            if(istat /= 0)write(6,*)' failure to write pwhead '
            pwtail(ibin)%head => pwhead(ibin)%head
        else
            allocate(pwtail(ibin)%head%llpoint,stat=istat)
            if(istat /= 0)write(6,*)' failure to write pwtail%llpoint '
            pwtail(ibin)%head => pwtail(ibin)%head%llpoint
        end if
        allocate(pwtail(ibin)%head%dp(nsig),stat=istat)
        if (istat/=0) write(6,*)'MAKECOBS:  allocate error for pwtail_dp, istat=',istat


!       Set (i,j) indices of guess gridpoint that bound obs location
        call get_ij(mm1,dlat,dlon,pwtail(ibin)%head%ij(1),pwtail(ibin)%head%wij(1))

        pwtail(ibin)%head%res    = ddiff
        pwtail(ibin)%head%err2   = error**2
        pwtail(ibin)%head%raterr2= ratio_errors**2  
        pwtail(ibin)%head%time   = dtime
        pwtail(ibin)%head%b      = cvar_b(ikx)
        pwtail(ibin)%head%pg     = cvar_pg(ikx)
        pwtail(ibin)%head%luse   = luse(i)

! Load the delta pressures at the obs location
        do k=1,nsig
           pwtail(ibin)%head%dp(k)=ten*(prsitmp(k)-prsitmp(k+1))
        end do
        pwtail(ibin)%head%diags => obsdiags(i_pw_ob_type,ibin)%tail

     endif


!    Save select output for diagnostic file
     if(conv_diagsave .and. luse(i))then
        ii=ii+1
        rstation_id     = data(id,i)
        cdiagbuf(ii)    = station_id         ! station id

        rdiagbuf(1,ii)  = ictype(ikx)        ! observation type
        rdiagbuf(2,ii)  = icsubtype(ikx)     ! observation subtype
    
        rdiagbuf(3,ii)  = data(ilate,i)      ! observation latitude (degrees)
        rdiagbuf(4,ii)  = data(ilone,i)      ! observation longitude (degrees)
        rdiagbuf(5,ii)  = data(istnelv,i)    ! station elevation (meters)
        rdiagbuf(6,ii)  = data(iobsprs,i)    ! observation pressure (hPa)
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

        err_input = data(ier2,i)
        err_adjst = data(ier,i)
        if (ratio_errors*error>tiny_r_kind) then
           err_final = one/(ratio_errors*error)
        else
           err_final = huge_single
        endif

        errinv_input = huge_single
        errinv_adjst = huge_single
        errinv_final = huge_single
        if (err_input>tiny_r_kind) errinv_input=one/err_input
        if (err_adjst>tiny_r_kind) errinv_adjst=one/err_adjst
        if (err_final>tiny_r_kind) errinv_final=one/err_final

        rdiagbuf(13,ii) = rwgt               ! nonlinear qc relative weight
        rdiagbuf(14,ii) = errinv_input       ! prepbufr inverse obs error
        rdiagbuf(15,ii) = errinv_adjst       ! read_prepbufr inverse obs error
        rdiagbuf(16,ii) = errinv_final       ! final inverse observation error

        rdiagbuf(17,ii) = dpw                ! total precipitable water obs (kg/m**2)
        rdiagbuf(18,ii) = ddiff              ! obs-ges used in analysis (kg/m**2)
        rdiagbuf(19,ii) = dpw-pwges          ! obs-ges w/o bias correction (kg/m**2) (future slot)

        if (lobsdiagsave) then
          ioff=19
          do jj=1,miter 
            ioff=ioff+1 
            if (obsdiags(i_pw_ob_type,ibin)%tail%muse(jj)) then
              rdiagbuf(ioff,ii) = one
            else
              rdiagbuf(ioff,ii) = -one
            endif
          enddo
          do jj=1,miter+1 
            ioff=ioff+1 
            rdiagbuf(ioff,ii) = obsdiags(i_pw_ob_type,ibin)%tail%nldepart(jj)
          enddo
          do jj=1,miter
            ioff=ioff+1
            rdiagbuf(ioff,ii) = obsdiags(i_pw_ob_type,ibin)%tail%tldepart(jj)
          enddo
          do jj=1,miter
            ioff=ioff+1
            rdiagbuf(ioff,ii) = obsdiags(i_pw_ob_type,ibin)%tail%obssen(jj)
          enddo
        endif

     end if


  end do


! Write information to diagnostic file
  if(conv_diagsave)then
     write(7)' pw',nchar,nreal,ii,mype
     write(7)cdiagbuf(1:ii),rdiagbuf(:,1:ii)
     deallocate(cdiagbuf,rdiagbuf)
  end if

! End of routine
end subroutine setuppw
