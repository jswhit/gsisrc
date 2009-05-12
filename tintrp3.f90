subroutine tintrp3(f,g,dx,dy,dz,obstime,gridtime,n,mype,nflds)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    intrp3      linear interpolation in 4 dims
!   prgmmr: parrish          org: np22                date: 1990-10-11
!
! abstract: linear interpolate in 4 dimensions (x,y,z,time)
!
! program history log:
!   1990-10-11  parrish
!   1998-04-05  weiyu yang
!   1999-08-24  derber, j., treadon, r., yang, w., first frozen mpp version
!   2004-05-18  kleist, documentation
!   2005-02-02  treadon - use ione from constants
!   2008-04-03  safford - rm unused vars         
!   2009-01-23  todling - dim on gridtime is nflds
!
!   input argument list:
!     f        - input interpolator
!     dx,dy,dz - input x,y,z-coords of interpolation points (grid units)
!     obstime  - time to interpolate to
!     gridtime - grid guess times to interpolate from
!     n        - number of interpolatees
!     mype     - mpi task id
!     nflds    - number of guess times available to interpolate from
!
!   output argument list:
!     g        - output interpolatees
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$ 
  use kinds, only: r_kind,i_kind
  use gridmod, only: jstart,istart,lon1,nlon,lon2,lat2,nlat,nsig
  use constants, only: zero,one,ione
  implicit none

! Declare passed variables
  integer(i_kind),intent(in):: n,mype,nflds
  real(r_kind),dimension(lat2,lon2,nsig,nflds),intent(in):: f
  real(r_kind),dimension(n),intent(in):: dx,dy,dz,obstime
  real(r_kind),dimension(nflds),intent(in):: gridtime
  real(r_kind),dimension(n),intent(out):: g

! Declare local variables
  integer(i_kind) m1,i,ix1,iy1,ix,ixp,iyp
  integer(i_kind) iy,iz,izp,itime,itimep,j
  real(r_kind) delx,delyp,delxp,delt,deltp
  real(r_kind) dely,delz,delzp

  m1=mype+ione
  do i=ione,n
    ix1=int(dx(i))
    iy1=int(dy(i))
    iz=int(dz(i))
    ix1=max(ione,min(ix1,nlat)); iz=max(ione,min(iz,nsig))  
    delx=dx(i)-float(ix1)
    dely=dy(i)-float(iy1)
    delz=dz(i)-float(iz)
    delx=max(zero,min(delx,one)); delz=max(zero,min(delz,one))
    ix=ix1-istart(m1)+2
    iy=iy1-jstart(m1)+2
    if(iy<ione) then
      iy1=iy1+nlon
      iy=iy1-jstart(m1)+2
    end if
    if(iy>lon1+ione) then
      iy1=iy1-nlon
      iy=iy1-jstart(m1)+2
    end if
    ixp=ix+ione; iyp=iy+ione
    izp=min(iz+ione,nsig)
    if(ix1==nlat) then
      ixp=ix
    end if
    if(obstime(i) > gridtime(1) .and. obstime(i) < gridtime(nflds))then
      do j=1,nflds-1
        if(obstime(i) > gridtime(j) .and. obstime(i) <= gridtime(j+1))then
          itime=j
          itimep=j+1
          delt=((gridtime(j+1)-obstime(i))/(gridtime(j+1)-gridtime(j)))
        end if
      end do
    else if(obstime(i) <=gridtime(1))then
      itime=1
      itimep=1
      delt=one
    else
      itime=nflds
      itimep=nflds
      delt=one
    end if
    deltp=one-delt
    delxp=one-delx; delyp=one-dely
    delzp=one-delz
    g(i) =(f(ix ,iy ,iz ,itime )*delxp*delyp*delzp &
         + f(ixp,iy ,iz ,itime )*delx*delyp*delzp &
         + f(ix ,iyp,iz ,itime )*delxp*dely *delzp &
         + f(ixp,iyp,iz ,itime )*delx*dely *delzp &
         + f(ix ,iy ,izp,itime )*delxp*delyp*delz  &
         + f(ixp,iy ,izp,itime )*delx*delyp*delz &
         + f(ix ,iyp,izp,itime )*delxp*dely *delz &
         + f(ixp,iyp,izp,itime )*delx*dely *delz)*delt + &
          (f(ix ,iy ,iz ,itimep)*delxp*delyp*delzp &
         + f(ixp,iy ,iz ,itimep)*delx*delyp*delzp &
         + f(ix ,iyp,iz ,itimep)*delxp*dely *delzp &
         + f(ixp,iyp,iz ,itimep)*delx*dely *delzp &
         + f(ix ,iy ,izp,itimep)*delxp*delyp*delz &
         + f(ixp,iy ,izp,itimep)*delx*delyp*delz &
         + f(ix ,iyp,izp,itimep)*delxp*dely *delz &
         + f(ixp,iyp,izp,itimep)*delx*dely *delz)*deltp
  end do

  return
end subroutine tintrp3
