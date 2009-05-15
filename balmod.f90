module balmod
!$$$   module documentation block
!                .      .    .                                       .
! module:    balmod          contains balance related stuff
!   prgmmr: parrish          org: np22                date: 2005-01-22
!
! abstract: contains routines for loading and using balance parameters
!             which define "slow" part of control variable,
!             specifically the stream function dependent part of
!             temperature, surface pressure, and velocity potential.
!
! program history log:
!   2005-01-22  parrish
!   2005-05-24  pondeca - accommodate 2dvar only surface analysis option
!   2005-07-15  wu - include fstat, f1 and fix l2
!   2008-10-08  derber include routines strong_bk and strong_bk_ad
!
! subroutines included:
!   sub create_balance_vars      - create arrays for balance vars
!   sub destroy_balance_vars     - remove arrays for balance vars
!   sub create_balance_vars_reg  - create arrays for regional balance vars
!   sub destroy_balance_vars_reg - remove arrays for regional balance vars
!   sub prebal                   - load balance vars
!   sub prebal_reg               - load regional balance vars
!   sub balance                  - balance routine
!   sub tbalance                 - adjoint of balance
!   sub locatelat_reg            - get interp vars for lat var --> regional grid
!   sub strong_bk                - apply strong balance constraint in background error matrix
!   sub strong_bk_ad             - apply adjoint of strong balance constraint in background error matrix
!
! Variable Definitions:
!   def agvz      - projection of streamfunction onto balanced temperature
!   def wgvz      - projection of streamfunction onto balanced ln(ps)
!   def bvz       - projection of streamfunction onto velocity potential
!   def ke_vp     - index of level above which to not let stream function
!                    influence velocity potential
!   def rllat     - lat of each regional grid point in lat grid units
!   def rllat1    - same as rllat, but for subdomains
!   def f1        - sin(lat)/sin(mid lat) for subdomains
!   def llmin     - min lat index for lat dependent background error, balance vars
!   def llmax     - max lat index for lat dependent background error, balance vars
!   def fstat     - .true. to seperate f from bal projection in regional mode
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$ end documentation block

  use kinds, only: r_kind,i_kind
  implicit none

  real(r_kind),allocatable,dimension(:,:,:):: agvz
  real(r_kind),allocatable,dimension(:,:):: wgvz
  real(r_kind),allocatable,dimension(:,:):: bvz
  real(r_kind),allocatable   :: rllat(:,:),rllat1(:,:),f1(:,:)

  integer(i_kind) ke_vp
  integer(i_kind) llmin,llmax
  logical fstat

contains
  subroutine create_balance_vars
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    create_balance_vars    create arrays for balance vars
!   prgmmr: parrish          org: np22                date: 2005-01-22
!
! abstract: creates arrays for balance variables
!
! program history log:
!   2005-01-22  parrish
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    use gridmod, only: lat2,nsig
    implicit none
    
    allocate(agvz(lat2,nsig,nsig),wgvz(lat2,nsig),bvz(lat2,nsig))
    
    return
  end subroutine create_balance_vars
  
  subroutine destroy_balance_vars
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    destroy_balance_vars  deallocates balance var arrays
!   prgmmr: parrish          org: np22                date: 2005-01-22
!
! abstract: deallocates balance var arrays
!
! program history log:
!   2005-01-22  parrish
!   2005-03-03  treadon - add implicit none
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    implicit none
    deallocate(agvz,wgvz,bvz)
    return
  end subroutine destroy_balance_vars

  subroutine create_balance_vars_reg(mype)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    create_balance_vars_reg  create arrays for reg balance vars
!   prgmmr: parrish          org: np22                date: 2005-01-22
!
! abstract: create arrays for regional balance vars
!
! program history log:
!   2005-01-22  parrish
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    use gridmod, only: nlat,nlon,nsig,lat2,lon2
    implicit none

    integer(i_kind),intent(in):: mype

!         compute rllat, rllat1, llmin, llmax
    allocate(rllat(nlat,nlon))
    allocate(rllat1(lat2,lon2))
    allocate(f1(lat2,lon2))
    call locatelat_reg(mype)
    
    allocate(agvz(llmin:llmax,nsig,nsig), &
         wgvz(llmin:llmax,nsig), &
         bvz(llmin:llmax,nsig))
    
    return
  end subroutine create_balance_vars_reg

  subroutine destroy_balance_vars_reg
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    destroy_balance_vars_reg  deallocate reg balance var arrays
!   prgmmr: parrish          org: np22                date: 2005-01-22
!
! abstract: deallocate regional balance variable arrays
!
! program history log:
!   2005-01-22  parrish
!   2005-03-03  treadon - add implicit none
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    implicit none
    deallocate(rllat,rllat1,f1,agvz,wgvz,bvz)
    return
  end subroutine destroy_balance_vars_reg

  subroutine prebal(mlat)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    prebal
!   prgmmr: wu               org: np22                date: 2000-03-15
!
! abstract: load balance variables agvz, bvz, wgvz, and ke_vp
!
! program history log:
!   2000-03-15  wu           
!   2004-02-03  kleist, updated to load background stats according
!               to updated mpi distribution on horizontal slabs
!   2004-03-15  derber, kleist, incorporate variances into this routine
!               stats from single file, additional clean up
!   2004-05-17  kleist, documentation and clean up
!   2004-08-03  treadon - add only to module use, add intent in/out
!   2004-10-26  wu - include factors hzscl in the range of RF table
!   2004-11-02  treadon - add horizontal resolution error check on berror_stats
!   2004-11-16  treadon - add longitude dimension to variance array dssv
!   2004-11-20  derber - modify to make horizontal table more reproducable and  
!               move most of table calculations to berror 
!   2005-01-22  parrish - split off from old prewgt
!   2005-03-28  wu - replace mlath with mlat            
!   2005-04-14  treadon - add corq2 to global berror_stats read
!   2005-04-22  treadon - change berror file to 4-byte reals
!   2006-04-17  treadon - remove calculation of ke_vp
!   2007-05-30  h.liu   - add coroz
!   2008-07-10  jguo    - place read of bkgerr fields in m_berror_stats
!   2008-12-29  todling - get mlat from dims in m_berror_stats; mype from mpimod
!
!   input argument list:
!
!   output argument list:
!     mlat     - number of latitudes in stats
!
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    use kinds, only: r_kind,i_kind,r_single
    use mpimod, only: mype
    use gridmod, only: istart,lat2,nlat,nlon,nsig
    use constants, only: zero
    use m_berror_stats,only: berror_get_dims,berror_read_bal
    implicit none
    
!   Declare passed variables
    integer(i_kind),intent(out):: mlat

!   Declare local variables
    integer(i_kind) i,j,k,msig
    integer(i_kind) mm1
    integer(i_kind) jx
    
    real(r_single),dimension(nlat,nsig,nsig):: agvin
    real(r_single),dimension(nlat,nsig) :: wgvin,bvin
    
!   Initialize local variables
    mm1=mype+1

    call berror_read_bal(agvin,bvin,wgvin,mype)
    call berror_get_dims(msig,mlat)
    if(msig/=nsig) then
      write(6,*) 'prebal: levs in file inconsistent with GSI',msig,nsig
      call stop2(101)
    end if

!   Set ke_vp=nsig (note:  not used in global)
    ke_vp=nsig
    
!   load balance projections
    agvz=zero
    bvz=zero
    wgvz=zero
    do k=1,nsig
       do j=1,nsig
          do i=1,lat2
             jx=istart(mm1)+i-2
             jx=max(jx,2)
             jx=min(nlat-1,jx)
             agvz(i,j,k)=agvin(jx,j,k)
          end do
       end do
       do i=1,lat2
          jx=istart(mm1)+i-2
          jx=max(jx,2)
          jx=min(nlat-1,jx)
          wgvz(i,k)=wgvin(jx,k)
          bvz(i,k)=bvin(jx,k)
       end do
    enddo
    
    return
  end subroutine prebal
  
  subroutine prebal_reg(mlat)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    prebal_reg  setup balance vars
!   prgmmr: wu               org: np22                date: 2000-03-15
!
! abstract: load balance variables agvz, bvz, wgvz, and ke_vp
!
! program history log:
!   2000-03-15  wu
!   2004-08-03  treadon - add only to module use; add intent in/out;
!                         fix bug in which rdgstat_reg inadvertently
!                         recomputed sigl (s/b done in gridmod)
!   2004-10-26  wu - include factors hzscl in the range of RF table
!   2004-11-16  treadon - add longitude dimension to variance array dssv
!   2004-11-20  derber - modify to make horizontal table more reproducable and
!               move most of table calculations to berror
!   2005-01-23  parrish - split off from old prewgt_reg
!   2005-02-07  treadon - add deallocate(corz,corp,hwll,hwllp,vz,agvi,bvi,wgvi)
!   2005-03-28  wu - replace mlath with mlat and modify dim of corz, corp
!   2006-04-17  treadon - replace sigl with ges_prslavg/ges_psfcavg 
!
!   input argument list:
!
!   output argument list:
!     mlat     - number of latitude grid points
!
!   other important variables
!     nsig     - number of sigma levels
!   agv,wgv,bv - balance correlation matrix for t,p,div

! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!$$$
    use kinds, only: r_kind,i_kind
    use gridmod, only: nsig,twodvar_regional
    use guess_grids, only: ges_prslavg,ges_psfcavg
    use constants, only: zero
    implicit none

!   Declare passed variables
    integer(i_kind),intent(out):: mlat

!   Declare local parameters
    real(r_kind),parameter:: r08 = 0.8_r_kind

!   Declare local variables
    integer(i_kind) k,i
!   integer(i_kind) n,m
    integer(i_kind) j
    integer(i_kind) ke,inerr
    integer(i_kind) msig                   ! stats dimensions

    real(r_kind):: psfc08
    real(r_kind),dimension(nsig):: rlsig
    real(r_kind),allocatable,dimension(:):: corp, hwllp
    real(r_kind),allocatable,dimension(:,:):: wgvi ,bvi
    real(r_kind),allocatable,dimension(:,:,:):: corz, hwll, agvi ,vz
    


!   Read dimension of stats file
    inerr=22
    open(inerr,file='berror_stats',form='unformatted')
    rewind inerr
    read(inerr)msig,mlat
    
!   Allocate arrays in stats file
    allocate ( corz(1:mlat,1:nsig,1:4) )
    allocate ( corp(1:mlat) )
    allocate ( hwll(0:mlat+1,1:nsig,1:4),hwllp(0:mlat+1) )
    allocate ( vz(1:nsig,0:mlat+1,1:6) )
    allocate ( agvi(0:mlat+1,1:nsig,1:nsig) )
    allocate ( bvi(0:mlat+1,1:nsig),wgvi(0:mlat+1,1:nsig) )
    
!   Read in background error stats and interpolate in vertical to that specified in namelist
    call rdgstat_reg(msig,mlat,inerr,&
         hwll,hwllp,vz,agvi,bvi,wgvi,corz,corp,rlsig)
    close(inerr)
    
!   ke_vp used to project SF to balanced VP
!   below sigma level 0.8

    psfc08=r08*ges_psfcavg
    ke=nsig
    j_loop: do j=1,nsig
       if (ges_prslavg(j)<psfc08) then
          ke=j
          exit j_loop
       endif
    enddo j_loop
    
    ke_vp=ke-1
    if (twodvar_regional) ke_vp=ke
    do k=1,ke_vp
       do j=llmin,llmax
          bvz(j,k)=bvi(j,k)
       enddo
    enddo
    if (.not.twodvar_regional) then
       do k=ke_vp+1,nsig
          do j=llmin,llmax
             bvz(j,k)=zero
          enddo
       enddo
    endif
    
    do k=1,nsig
       do j=1,nsig
          do i=llmin,llmax
             agvz(i,j,k)=agvi(i,j,k)
          end do
       end do
       do i=llmin,llmax
          wgvz(i,k)=wgvi(i,k)
       end do
    enddo

!   Alternatively, zero out all balance correlation matrices
!   for univariate surface analysis
!    if (twodvar_regional) then
!       bvz(:,:)=zero
!       agvz(:,:,:)=zero
!       wgvz(:,:)=zero
!    endif
    
    deallocate ( corz,corp,hwll,hwllp,vz,agvi,bvi,wgvi)
    
    return
  end subroutine prebal_reg
  
  subroutine balance(t,p,st,vp,fpsproj)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    balance     apply balance equation
!
!   prgmmr: parrish          org: np22                date: 1990-10-06
!
! abstract: balance equation and conversion from streamfunction 
!           and velocity potential to uv
!
! program history log:
!   1990-10-06  parrish
!   1994-02-02  parrish
!   1997-12-03  weiyu yang
!   1999-06-28  yang w., second structure mpp version
!   1999-08-24  derber, j., treadon, r., yang, w., first frozen mpp version
!   1999-12-07  wu               grid version
!   2003-12-22  derber 
!   2004-02-03  kleist, new mpi strategy
!   2004-05-06  derber separate out balance equation from vertical correlation
!   2004-07-28  treadon - add only on use declarations; add intent in/out
!   2004-10-26  kleist - remove u,v - st,vp conversion outside of bkerror, modified
!               ps balance 
!   2005-02-23  wu - add variable conversion for normalized relative humidity        
!   2005-03-05  parrish - for qoption=2, leave q unchanged, so in/out is normalized rh
!   2005-06-06  wu - use f1 in balance projection (st->t) when fstat=.true.
!   2005-07-14  wu - add max bound to l2
!   2005-11-21  derber modify to make qoption =1 work same as =2
!   2006-01-11  kleist - add full nsig projection for surface pressure
!   2006-10-15  gu - add back vp projection onto surface pressure
!   2006-11-30  todling - add fpsproj to control diff projection contributions to ps  
!   2008-06-05  safford - rm unused vars
!   2008-12-29  todling - remove q from arg list
!
!   input argument list:
!     t        - t grid values 
!     p        - p surface grid values 
!     q        - q grid values 
!     st       - streamfunction grid values 
!     vp       - velocity potential grid values 
!
!   output argument list:
!     t        - t grid values 
!     p        - p surface grid values 
!     q        - q grid values 
!     st       - streamfunction grid values 
!     vp       - velocity potential grid values 
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    use kinds, only: r_kind,i_kind
    use constants, only: one,half
    use gridmod, only: regional,lat2,nsig,iglobal,itotsub,lon2
    implicit none
    
!   Declare passed variables
    real(r_kind),dimension(lat2,lon2),intent(inout):: p
    real(r_kind),dimension(lat2,lon2,nsig),intent(inout):: t,vp,st
    logical, intent(in) :: fpsproj

!   Declare local variables
    integer(i_kind) i,j,k,l,m,l2,isize,lm

    real(r_kind) dl1,dl2

!   Initialize variables
    isize=max(iglobal,itotsub)


!   REGIONAL BRANCH
    if (regional) then

!      Add contribution from streamfunction to unbalanced velocity potential.
       do k=1,ke_vp
          do j=1,lon2
             do i=1,lat2
                l=int(rllat1(i,j))
                l2=min0(l+1,llmax)
                dl2=rllat1(i,j)-float(l)
                dl1=one-dl2
                vp(i,j,k)=vp(i,j,k)+(dl1*bvz(l,k)+dl2*bvz(l2,k))*st(i,j,k)
             end do
          end do
       end do
       

      if (fstat) then
!      Add contribution from streamfunction to unbalanced temperature.
      lm=(llmax+llmin)*half
       do k=1,nsig
          do m=1,nsig
             do j=1,lon2
                do i=1,lat2
                   t(i,j,m)=t(i,j,m)+agvz(lm,m,k)*f1(i,j)*st(i,j,k)
                end do
             end do
          end do
       end do

      else ! not fstat

!      Add contribution from streamfunction to unbalanced temperature.
       do k=1,nsig
          do m=1,nsig
             do j=1,lon2
                do i=1,lat2
                   l=int(rllat1(i,j))
                l2=min0(l+1,llmax)
                   dl2=rllat1(i,j)-float(l)
                   dl1=one-dl2
                   t(i,j,m)=t(i,j,m)+(dl1*agvz(l,m,k)+dl2*agvz(l2,m,k))*st(i,j,k)
                end do
             end do
          end do
       end do
      endif ! fstat

!      Add contribution from streamfunction to surface pressure.
       do k=1,nsig
          do j=1,lon2
             do i=1,lat2
                l=int(rllat1(i,j))
                l2=min0(l+1,llmax)
                dl2=rllat1(i,j)-float(l)
                dl1=one-dl2
                p(i,j)=p(i,j)+(dl1*wgvz(l,k)+dl2*wgvz(l2,k))*st(i,j,k)
             end do
          end do
       end do
       
!   GLOBAL BRANCH
    else

!      Add contribution from streamfunction and unbalanced vp
!      to surface pressure.
       if ( fpsproj ) then
          do k=1,nsig
             do j=1,lon2
                do i=1,lat2
                   p(i,j)=p(i,j)+wgvz(i,k)*st(i,j,k)
                end do
             end do
          end do
       else
          do j=1,lon2
             do i=1,lat2
                do k=1,nsig-1
                   p(i,j)=p(i,j)+wgvz(i,k)*st(i,j,k)
                end do
                p(i,j)=p(i,j)+wgvz(i,nsig)*vp(i,j,1)
             end do
          end do
       endif

!      Add contribution from streamfunction to veloc. potential
       do k=1,nsig
          do j=1,lon2
             do i=1,lat2
                vp(i,j,k)=vp(i,j,k)+bvz(i,k)*st(i,j,k)
             end do
          end do
       end do

!      Add contribution from streamfunction to unbalanced temperature.
       do k=1,nsig
          do l=1,nsig
             do j=1,lon2
                do i=1,lat2
                   t(i,j,l)=t(i,j,l)+agvz(i,l,k)*st(i,j,k)
                end do
             end do
          end do
       end do

!   End of REGIONAL/GLOBAL if-then block
    endif

!   Strong balance constraint
    call strong_bk(st,vp,p,t)


    return
  end subroutine balance
  
  subroutine tbalance(t,p,st,vp,fpsproj)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    tbalance    adjoint of balance
!   prgmmr: parrish          org: np22                date: 1994-02-12
!
! abstract: adjoint of balance equation
!
! program history log:
!   1994-02-12  parrish
!   1998-01-22  weiyu yang
!   1999-06-28  yang w., second structure mpp version
!   1999-08-24  derber, j., treadon, r., yang, w., first frozen mpp version
!   1999-12-07  wu               grid version
!   2003-12-22  derber
!   2004-02-03  kleist, new mpi strategy
!   2004-05-06  derber separate out balance from vertical covariance
!   2004-07-09  treadon - use qsatg_fix instead of qsatg in normalization of q (bug fix)
!   2004-10-26  kleist - remove u,v -- st,vp conversion oustide of bkerror, modified ps
!               balance
!   2005-02-23  wu - add adjoint of variable conversion for normalized relative humidity        
!   2005-03-05  parrish - for qoption=2, leave q unchanged, so in/out is normalized rh
!   2005-07-15  wu - use f1 in adjoint of balance projection (st->t) when fstat=.true. Add max bound to l2
!   2005-11-21  derber modify to make qoption =1 work same as =2
!   2006-01-11  kleist - add full nsig projection for surface pressure
!   2006-10-15  gu - add back vp projection onto surface pressure
!   2006-11-30  todling - add fpsproj to control diff projection contributions to ps  
!   2008-06-05  safford - rm unused vars
!   2008-12-29  todling - remove q from arg list
!
!   input argument list:
!     t        - t grid values from int routines 
!     p        - p surface grid values from int routines 
!     st       - streamfunction grid values from int routines 
!     vp       - velocity potential grid values from int routines
!
!   output argument list:
!     q        - q grid values with adjoint of balance added
!     st       - streamfunction grid vals with adjoint of balance added
!     vp       - velocity potential grid values with adjoint of balance added
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    use kinds,       only: r_kind,i_kind
    use constants,   only: one,half
    use gridmod,     only: itotsub,regional,iglobal,lon2,lat2,nsig
    implicit none

!   Declare passed variables
    real(r_kind),dimension(lat2,lon2),intent(inout):: p
    real(r_kind),dimension(lat2,lon2,nsig),intent(inout):: t
    real(r_kind),dimension(lat2,lon2,nsig),intent(inout):: st,vp
    logical, intent(in) :: fpsproj

!   Declare local variables
    integer(i_kind) l,m,l2,i,j,k,igrid,isize,lm

    real(r_kind) dl1,dl2
  
!  Adjoint of strong balance constraint
    call strong_bk_ad(st,vp,p,t)

!   Initialize variables
    igrid=lat2*lon2
    isize=max(iglobal,itotsub)

!   REGIONAL BRANCH
    if (regional) then

      if(fstat) then
!      Adjoint of contribution to temperature from streamfunction.
      lm=(llmax+llmin)*half
       do m=1,nsig
          do k=1,nsig
             do j=1,lon2
                do i=1,lat2
                   st(i,j,m)=st(i,j,m)+agvz(lm,k,m)*f1(i,j)*t(i,j,k)
                end do
             end do
          end do
       end do

      else ! not fstat

!      Adjoint of contribution to temperature from streamfunction.
       do m=1,nsig
          do k=1,nsig
             do j=1,lon2
                do i=1,lat2
                   l=int(rllat1(i,j))
                l2=min0(l+1,llmax)
                   dl2=rllat1(i,j)-float(l)
                   dl1=one-dl2
                   st(i,j,m)=st(i,j,m)+(dl1*agvz(l,k,m)+dl2*agvz(l2,k,m))*t(i,j,k)
                end do
             end do
          end do
       end do
      endif ! fstat

!      Adjoint of streamfunction contribution to surface pressure.  
!      Add contributions from u and v to streamfunction and velocity potential
       do k=1,nsig
          do j=1,lon2
             do i=1,lat2
                l=int(rllat1(i,j))
                l2=min0(l+1,llmax)
                dl2=rllat1(i,j)-float(l)
                dl1=one-dl2
                st(i,j,k)=st(i,j,k)+(dl1*wgvz(l,k)+dl2*wgvz(l2,k))*p(i,j)
                
             end do
          end do
       end do

!      Adjoint of contribution to velocity potential from streamfunction.
       do k=1,ke_vp
          do j=1,lon2
             do i=1,lat2
                l=int(rllat1(i,j))
                l2=min0(l+1,llmax)
                dl2=rllat1(i,j)-float(l)
                dl1=one-dl2
                st(i,j,k)=st(i,j,k)+(dl1*bvz(l,k)+dl2*bvz(l2,k))*vp(i,j,k)
             end do
          end do
       end do
       
!   GLOBAL BRANCH
    else

!      Adjoint of contribution to temperature from streamfunction.
       do k=1,nsig
          do l=1,nsig
             do j=1,lon2
                do i=1,lat2
                   st(i,j,k)=st(i,j,k)+agvz(i,l,k)*t(i,j,l)
                end do
             end do
          end do
       end do
       
!      Adjoint of contribution to velocity potential from streamfunction.
       do k=1,nsig
          do j=1,lon2
             do i=1,lat2
                st(i,j,k)=st(i,j,k)+bvz(i,k)*vp(i,j,k)
             end do
          end do
       end do

!      Adjoint of streamfunction and unbalanced velocity potential
!      contribution to surface pressure.
       if ( fpsproj ) then
          do k=1,nsig
             do j=1,lon2
                do i=1,lat2
                   st(i,j,k)=st(i,j,k)+wgvz(i,k)*p(i,j)
                end do
             end do
          end do
       else
          do j=1,lon2
             do i=1,lat2
                do k=1,nsig-1
                   st(i,j,k)=st(i,j,k)+wgvz(i,k)*p(i,j)
                end do
                vp(i,j,1)=vp(i,j,1)+wgvz(i,nsig)*p(i,j)
             end do
          end do
       endif
!   End of REGIONAL/GLOBAL if-then block
    endif

    return
  end subroutine tbalance

  subroutine locatelat_reg(mype)      
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    locatelat_reg   calc interp coeffs for background stats
!   prgmmr: wu               org: np22                date: 2004-03-15
!
! abstract: calculates interpolation indexes and weights between 
!           the background error statistics and the analysis grids                        
!
! program history log:
!   2004-03-15  wu       
!   2004-06-14  wu, documentation and clean up       
!   2004-07-28  treadon - simplify subroutine call list
!   2005-03-28  wu - replace mlath with mlat
!   2005-04-22  treadon - change berror file to 4-byte reals
!   2005-06-06  wu - setup f1 for balance projection (st->t) when fstat=.true.
!
!   input argument list:
!     mype     - mpi task id
!
!   output argument list
!
! remarks: see modules used
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    use kinds, only: r_kind,i_kind,r_single
    use gridmod, only: nlon,nlat,lat2,lon2,istart,jstart,region_lat
    use constants, only: deg2rad,one
    implicit none
    
!   Declare passed variables
    integer(i_kind),intent(in):: mype

!   Declare local variables
    integer(i_kind) i,j,msig,mlat,lunin,m,m1,mm1,jl,il
    real(r_kind) fmid
    real(r_kind),allocatable,dimension(:):: clat_avn
    real(r_single),allocatable,dimension(:):: clat_avn4


!   Read in dim of stats file
    lunin=22
    open(lunin,file='berror_stats',form='unformatted')
    rewind lunin
    read(lunin)msig,mlat
    

!   Allocate and read in lat array in stats file
    allocate( clat_avn(mlat), clat_avn4(mlat) )
    read(lunin)clat_avn4
    close(lunin)
    do i=1,mlat
       clat_avn(i)=clat_avn4(i)*deg2rad
    end do
    deallocate(clat_avn4)
    

!   Decide and output rllat,rllat1,llmax,llmin (through module berror )
!   rllat: location of analysis grid in stats grid unit (whole domain)
!   llmax,llmin: max,min stats grid needed in analysis domain
!   rllat1: location of analysis grid in stats grid unit (MPP local domain)

    llmax=-999
    llmin=999
    do j=1,nlon 
       do i=1,nlat   
          if(region_lat(i,j).ge.clat_avn(mlat))then
             rllat(i,j)=float(mlat)
             llmax=max0(mlat,llmax)
             llmin=min0(mlat,llmin)
          else if(region_lat(i,j).lt.clat_avn(1))then
             rllat(i,j)=1.
             llmax=max0(1,llmax)
             llmin=min0(1,llmin)
          else
             do m=1,mlat-1
                m1=m+1
                if((region_lat(i,j).ge.clat_avn(m)).and.  &
                     (region_lat(i,j).lt.clat_avn(m1)))then
                   rllat(i,j)=float(m)
                   llmax=max0(m,llmax)
                   llmin=min0(m,llmin)
                   go to 1234
                end if
             end do
1234         continue
             rllat(i,j)=rllat(i,j)+(region_lat(i,j)-clat_avn(m))/(clat_avn(m1)-clat_avn(m))
          endif
       end do
    end do
    llmax=min0(mlat,llmax+1)
    llmin=max0(1,llmin-1)
    
    deallocate(clat_avn)
    
    mm1=mype+1
    do j=1,lon2            
       jl=j+jstart(mm1)-2
       jl=min0(max0(1,jl),nlon)
       do i=1,lat2            
          il=i+istart(mm1)-2
          il=min0(max0(1,il),nlat)
          rllat1(i,j)=rllat(il,jl)
       enddo
    enddo
 if(fstat)then
   fmid=one/sin(region_lat(nlat/2,nlon/2))
    do j=1,lon2
       jl=j+jstart(mm1)-2
       jl=min0(max0(1,jl),nlon)
       do i=1,lat2
          il=i+istart(mm1)-2
          il=min0(max0(1,il),nlat)
          f1(i,j)=sin(region_lat(il,jl))*fmid
       enddo
    enddo
 endif
    
    return
  end subroutine locatelat_reg
  
subroutine strong_bk(st,vp,p,t)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    strong_bk   apply strong balance constraint
!   prgmmr: derber           org: np23                date: 2003-12-18
!
! abstract: apply strong balance constraint
!
!
! program history log:
!   2008-09-19  derber,j.
!   2008-12-29  todling   - redefine interface
!   2009-04-21  derber - modify interface with calctends_no
!
!   input argument list:
!     st       - input control vector, stream function
!     vp       - input control vector, velocity potential
!     p        - input control vector, surface pressure
!     t        - input control vector, temperature
!
!   output argument list:
!     st       - output control vector, stream function
!     vp       - output control vector, velocity potential
!     p        - output control vector, surface pressure
!     t        - output control vector, temperature
!
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,i_kind
  use mpimod, only: mype
  use constants, only:  zero
  use gridmod, only: latlon1n,latlon11,nnnn1o
  use mod_vtrans,only: nvmodes_keep
  use mod_strong,only: nstrong
  implicit none

! Declare passed variables
  real(r_kind),dimension(latlon1n),intent(inout):: st,vp
  real(r_kind),dimension(latlon11),intent(inout):: p
  real(r_kind),dimension(latlon1n),intent(inout):: t

  logical:: fullfield
  integer(i_kind) istrong
  real(r_kind),dimension(latlon1n)::u_t,v_t,t_t
  real(r_kind),dimension(latlon11):: ps_t

!******************************************************************************  
  if(nvmodes_keep <= 0 .or. nstrong <= 0) return

! compute derivatives

  fullfield=.false.
  do istrong=1,nstrong
 
     call calctends_no_tl(st,vp,t,p,mype,u_t,v_t,t_t,ps_t)

     call strong_bal_correction(u_t,v_t,t_t, &
          ps_t,mype,st,vp,t,p,.false.,fullfield,.true.)

   end do

  return
end subroutine strong_bk

subroutine strong_bk_ad(st,vp,p,t)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    strong_bk_ad   apply adjoint of strong balance constraint
!   prgmmr: derber           org: np23                date: 2003-12-18
!
! abstract: apply adjoint of strong balance constraint
!
!
! program history log:
!   2008-09-19  derber,j.
!   2008-12-29  todling   - redefine interface
!   2009-04-21  derber - modify interface with calctends_no
!
!   input argument list:
!     st       - input control vector, stream function
!     vp       - input control vector, velocity potential
!     p        - input control vector, surface pressure
!     t        - input control vector, temperature
!
!   output argument list:
!     st       - output control vector, stream function
!     vp       - output control vector, velocity potential
!     p        - output control vector, surface pressure
!     t        - output control vector, temperature
!
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,i_kind
  use mpimod, only: mype
  use constants, only: zero
  use gridmod, only: latlon1n,latlon11,nnnn1o,latlon1n1
  use mod_vtrans,only: nvmodes_keep
  use mod_strong,only: nstrong
  implicit none
  
! Declare passed variables  
  real(r_kind),dimension(latlon1n),intent(inout):: st,vp
  real(r_kind),dimension(latlon11),intent(inout):: p
  real(r_kind),dimension(latlon1n),intent(inout):: t

! Declare local variables  	
  integer(i_kind) i,k
  real(r_kind),dimension(latlon1n):: u_t,v_t,t_t
  real(r_kind),dimension(latlon11):: ps_t
  integer(i_kind) istrong

!******************************************************************************

  if(nvmodes_keep <= 0 .or. nstrong <= 0) return
     
  do istrong=1,nstrong
! Zero gradient arrays
    do i=1,latlon1n
       u_t(i)=zero
       v_t(i)=zero
       t_t(i)=zero
    end do
    do i=1,latlon11
       ps_t(i)=zero
    end do

    call strong_bal_correction_ad(u_t,v_t,t_t,ps_t,mype,st,vp,t,p)

    call calctends_no_ad(st,vp,t,p,mype,u_t,v_t,t_t,ps_t)  
!
  end do

  return
  end subroutine strong_bk_ad
end module balmod
