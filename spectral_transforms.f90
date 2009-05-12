subroutine g2s0(spectral_out,grid_in)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    g2s0        grid to spectral
!   prgmmr: kleist           org: np23                date: 2006-07-15
!
! abstract: transform scalar from gaussian grid to spherical harmonic coefficients.
!           This works for equally spaced grid also
!
! program history log:
!   2006-07-15  kleist
!
!   input argument list:
!     grid_in  - input grid field on gaussian grid
!
!   output argument list:
!     spectral_out - output spherical harmonic coefficients
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

  use specmod, only: nc,factsml
  use kinds, only: r_kind,i_kind
  use constants, only: zero
  use gridmod, only: nlat,nlon
  implicit none

  real(r_kind),intent(out)::spectral_out(nc)
  real(r_kind),intent(in)::grid_in(nlat,nlon)

  real(r_kind) work(nlon,nlat-2),spec_work(nc)
  integer(i_kind) i,j,jj

!  Transfer contents of input grid to local work array
!  Reverse ordering in j direction from n-->s to s-->n
  do j=2,nlat-1
    jj=nlat-j
    do i=1,nlon
      work(i,jj)=grid_in(j,i)
    end do
  end do
  call sptez_s(spec_work,work,-1)

  do i=1,nc
    spectral_out(i)=spec_work(i)
    if(factsml(i))spectral_out(i)=zero
  end do
 
  return
end subroutine g2s0

subroutine g2s0_ad(spectral_in,grid_out)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    g2s0_ad     adjoint of g2s0
!   prgmmr: kleist           org: np23                date: 2006-07-15
!
! abstract: adjoint of g2s0
!
! program history log:
!   2006-07-15  kleist
!   2007-05-15  errico  - Correct for proper use if grid includes equator 
!   2008-04-11  safford - rm unused var
!
!   input argument list:
!     spectral_in  - input spherical harmonic coefficients
!
!   output argument list:
!     grid_out - output grid field on gaussian grid
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

  use specmod, only: jcap,nc,factsml,wlat,jb,je
  use kinds, only: r_kind,i_kind
  use constants, only: zero,half,two
  use gridmod, only: nlat,nlon
  implicit none

  real(r_kind),intent(in)::spectral_in(nc)
  real(r_kind),intent(out)::grid_out(nlat,nlon)

  real(r_kind) work(nlon,nlat-2),spec_work(nc)
  integer(i_kind) i,j,jj

  do i=1,nc
    spec_work(i)=spectral_in(i)/float(nlon)
    if(factsml(i))spec_work(i)=zero
  end do
  do i=2*jcap+3,nc
    spec_work(i)=half*spec_work(i)
  end do
 
  call sptez_s(spec_work,work,1)

!
! If nlat odd, then j=je is the equator.  The factor of 2 is because, 
! je is referenced only once, not twice as in the spectral transform 
! routines where half of the equator is considered in each hemisphere,
! separately. 
  do j=jb,je-mod(nlat,2)
    do i=1,nlon
      work(i,j)=work(i,j)*wlat(j)
      work(i,nlat-1-j)=work(i,nlat-1-j)*wlat(j)
    end do
  end do
  
  if (mod(nlat,2) .ne. 0) then
    do i=1,nlon
      work(i,je)=work(i,je)*two*wlat(je)
    end do
  endif

!  Transfer contents of output grid to local work array
!  Reverse ordering in j direction from n-->s to s-->n
  do j=2,nlat-1
    jj=nlat-j
    do i=1,nlon
      grid_out(j,i)=work(i,jj)
    end do
  end do

!  Load zero into pole points
  do i=1,nlon
    grid_out(1,i)   =zero
    grid_out(nlat,i)=zero
  end do

  return
end subroutine g2s0_ad

subroutine s2g0(spectral_in,grid_out)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    s2g0        inverse of g2s0
!   prgmmr: kleist           org: np23                date: 2006-07-15
!
! abstract: inverse of g2s0
!
! program history log:
!   2006-07-15  kleist
!   2007-05-15  errico - add call to spectra_pole_scalar
!   2008-04-11  safford - rm unused uses
!
!   input argument list:
!     spectral_in  - input spherical harmonic coefficients
!
!   output argument list:
!     grid_out - output grid field on gaussian grid
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

  use specmod, only: nc,factsml
  use kinds, only: r_kind,i_kind
  use constants, only: zero
  use gridmod, only: nlat,nlon
  implicit none

  real(r_kind),intent(in)::spectral_in(nc)
  real(r_kind),intent(out)::grid_out(nlat,nlon)

  real(r_kind) work(nlon,nlat-2),spec_work(nc)
  integer(i_kind) i,j,jj

  do i=1,nc
    spec_work(i)=spectral_in(i)
    if(factsml(i))spec_work(i)=zero
  end do
 
  call sptez_s(spec_work,work,1)

!  Reverse ordering in j direction from n-->s to s-->n
!  And account for work array excluding pole points
  do j=2,nlat-1
    jj=nlat-j
    do i=1,nlon
      grid_out(j,i)=work(i,jj)
    end do
  end do

!  fill in pole points using spectral coefficients
!  (replace earlier algorithm that assumed zero gradient next to pole)
  call spectra_pole_scalar (grid_out,spec_work)

  return
end subroutine s2g0

subroutine s2g0_ad(spectral_out,grid_in)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    s2g0_ad     adjoint of s2g0
!   prgmmr: kleist           org: np23                date: 2006-07-15
!
! abstract: adjoint of s2g0
!
! program history log:
!   2006-07-15  kleist
!   2007-04-22  errico    correction for proper treatment of equator
!                         also add call to spectra_pole_scalar_ad 
!
!   input argument list:
!     grid_in  - input spherical harmonic coefficients
!
!   output argument list:
!     spectral_out - output grid field on gaussian grid
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

  use specmod, only: jcap,nc,factsml,wlat,jb,je
  use kinds, only: r_kind,i_kind
  use constants, only: zero,two
  use gridmod, only: nlat,nlon
  implicit none

  real(r_kind),intent(out)::spectral_out(nc)
  real(r_kind),intent(in)::grid_in(nlat,nlon)

  real(r_kind) work(nlon,nlat-2),spec_work(nc)
  integer(i_kind) i,j,jj


!  Reverse ordering in j direction from n-->s to s-->n
!  And account for work array excluding pole points
  do j=2,nlat-1
    jj=nlat-j
    do i=1,nlon
      work(i,jj)=grid_in(j,i)
    end do
  end do

  do j=jb,je-mod(nlat,2)
    do i=1,nlon
      work(i,j)=work(i,j)/wlat(j)
      work(i,nlat-1-j)=work(i,nlat-1-j)/wlat(j)
    end do
  end do

  if (mod(nlat,2) .ne. 0) then
    do i=1,nlon
      work(i,je)=work(i,je)/(two*wlat(je))
    end do
  endif

  call sptez_s(spec_work,work,-1)

  do i=1,nc
    spec_work(i)=spec_work(i)*float(nlon)
  end do
  do i=2*jcap+3,nc
    spec_work(i)=two*spec_work(i)
  end do

  call spectra_pole_scalar_ad (grid_in,spec_work)

  do i=1,nc
    spectral_out(i)=spec_work(i)
    if(factsml(i))spectral_out(i)=zero
  end do

  return
end subroutine s2g0_ad


subroutine uvg2zds(zsp,dsp,ugrd,vgrd)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    uvg2zds     grid u,v to spectral vort, div
!   prgmmr: kleist           org: np23                date: 2006-07-15
!
! abstract: transform vector u,v from gaussian grid to spherical harmonic
!           coefficients of vorticity and divergence.
!
! program history log:
!   2006-07-15  kleist
!
!   input argument list:
!     ugrd  - input u on gaussian grid
!     vgrd  - input v on gaussian grid
!
!   output argument list:
!     zsp   - output spherical harmonic coefficients of vorticity
!     dsp   - output spherical harmonic coefficients of divergence
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

  use specmod, only: nc,factvml
  use kinds, only: r_kind,i_kind
  use constants, only: zero
  use gridmod, only: nlat,nlon
  implicit none

! Passed variables
  real(r_kind),dimension(nlat,nlon),intent(in) :: ugrd,vgrd
  real(r_kind),dimension(nc),intent(out) :: zsp,dsp

! Local variables
  real(r_kind),dimension(nlon,nlat-2):: grdwrk1,grdwrk2 
  real(r_kind),dimension(nc):: spcwrk1,spcwrk2
  integer(i_kind) i,j,jj

! Transfer contents of input grid to local work array
! Reverse ordering in j direction from n-->s to s-->n
  do j=2,nlat-1
    jj=nlat-j
    do i=1,nlon
      grdwrk1(i,jj)=ugrd(j,i)
      grdwrk2(i,jj)=vgrd(j,i)
    end do
  end do

  call sptez_v(spcwrk1,spcwrk2,grdwrk1,grdwrk2,-1)

  do i=1,nc
    zsp(i)=spcwrk2(i)
    dsp(i)=spcwrk1(i)
    if(factvml(i))then
       zsp(i)=zero
       dsp(i)=zero
    end if
  end do

  return
end subroutine uvg2zds

subroutine uvg2zds_ad(zsp,dsp,ugrd,vgrd)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    uvg2zds_ad  adjoint of uvg2zds
!   prgmmr: kleist           org: np23                date: 2006-07-15
!
! abstract: adjoint of uvg2zds
!
! program history log:
!   2006-07-15  kleist
!   2007-04-22  errico  - correction for proper treatment of equator
!   2008-04-11  safford - rm unused uses
!
!   input argument list:
!     ugrd  - input u on gaussian grid
!     vgrd  - input v on gaussian grid
!     zsp   - input spherical harmonic coefficients of vorticity
!     dsp   - input spherical harmonic coefficients of divergence
!
!   output argument list:
!     ugrd  - output u on gaussian grid
!     vgrd  - output v on gaussian grid
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

  use specmod, only: nc,factvml,wlat,jb,je,jcap,ncd2,enn1
  use kinds, only: r_kind,i_kind
  use constants, only: zero,half,two
  use gridmod, only: nlat,nlon
  implicit none

! Passed variables
  real(r_kind),dimension(nlat,nlon),intent(inout) :: ugrd,vgrd
  real(r_kind),dimension(nc),intent(in) :: zsp,dsp

! Local variables
  real(r_kind),dimension(nlon,nlat-2):: grdwrk1,grdwrk2
  real(r_kind),dimension(nc):: spcwrk1,spcwrk2
  integer(i_kind) i,j,jj

  do i=1,nc
    spcwrk1(i)=dsp(i)/float(nlon)
    spcwrk2(i)=zsp(i)/float(nlon)
    if(factvml(i))then
      spcwrk1(i)=zero
      spcwrk2(i)=zero
    end if
  end do

  do i=2*jcap+3,nc
     spcwrk1(i)=half*spcwrk1(i)
     spcwrk2(i)=half*spcwrk2(i)
  end do

  do i=2,ncd2
     spcwrk1(2*i-1)=spcwrk1(2*i-1)*enn1(i)
     spcwrk1(2*i)=spcwrk1(2*i)*enn1(i)
     spcwrk2(2*i-1)=spcwrk2(2*i-1)*enn1(i)
     spcwrk2(2*i)=spcwrk2(2*i)*enn1(i)
  end do

  call sptez_v(spcwrk1,spcwrk2,grdwrk1,grdwrk2,1)

  do j=jb,je-mod(nlat,2)
    do i=1,nlon
      grdwrk1(i,j)=grdwrk1(i,j)*wlat(j)
      grdwrk1(i,nlat-1-j)=grdwrk1(i,nlat-1-j)*wlat(j)
      grdwrk2(i,j)=grdwrk2(i,j)*wlat(j)
      grdwrk2(i,nlat-1-j)=grdwrk2(i,nlat-1-j)*wlat(j)
    end do
  end do

  if (mod(nlat,2) .ne. 0) then
    do i=1,nlon
      grdwrk1(i,je)=grdwrk1(i,je)*two*wlat(je)
      grdwrk2(i,je)=grdwrk2(i,je)*two*wlat(je)
    end do
  endif 


! Transfer contents of input grid to local work array
! Reverse ordering in j direction from n-->s to s-->n
  do j=2,nlat-1
    jj=nlat-j
    do i=1,nlon
      ugrd(j,i)=grdwrk1(i,jj)
      vgrd(j,i)=grdwrk2(i,jj)
    end do
  end do

  do i=1,nlon
    ugrd(1,i)    = zero
    ugrd(nlat,i) = zero
    vgrd(1,i)    = zero
    vgrd(nlat,i) = zero
  end do

  return
end subroutine uvg2zds_ad

subroutine zds2pcg(zsp,dsp,pgrd,cgrd)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    zds2pcg     transform spec. vort,div to psi,chi on grid
!   prgmmr: kleist           org: np23                date: 2006-07-15
!
! abstract: transform spectral vorticity, divergence to psi and chi on grid
!
! program history log:
!   2006-07-15  kleist
!
!   input argument list:
!     zsp   - input spherical harmonic coefficients of vorticity
!     dsp   - input spherical harmonic coefficients of divergence
!
!   output argument list:
!     pgrd  - output psi on gaussian grid
!     cgrd  - output chi on gaussian grid
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

  use specmod, only: nc,factvml,ncd2,enn1
  use kinds, only: r_kind,i_kind
  use constants, only: zero
  use gridmod, only: nlat,nlon
  implicit none

! Passed variables
  real(r_kind),dimension(nc),intent(in):: zsp,dsp
  real(r_kind),dimension(nlat,nlon),intent(out) :: pgrd,cgrd

! Local variables
  real(r_kind),dimension(nc):: spc1,spc2
  integer(i_kind) i

! Inverse laplacian
  spc1(1)=zero
  spc1(2)=zero
  spc2(1)=zero
  spc2(2)=zero
  do i=2,ncd2
    spc1(2*i-1)=zsp(2*i-1)/(-enn1(i))
    spc1(2*i)=zsp(2*i)/(-enn1(i))
    spc2(2*i-1)=dsp(2*i-1)/(-enn1(i))
    spc2(2*i)=dsp(2*i)/(-enn1(i))
  end do
  call s2g0(spc1,pgrd)
  call s2g0(spc2,cgrd)

  return
end subroutine zds2pcg
subroutine zds2pcg_ad(zsp,dsp,pgrd,cgrd)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    zds2pcg     transform spec. vort,div to psi,chi on grid
!   prgmmr: kleist           org: np23                date: 2006-07-15
!
! abstract: transform spectral vorticity, divergence to psi and chi on grid
!
! program history log:
!   2006-07-15  kleist
!
!   input argument list:
!     zsp   - input spherical harmonic coefficients of vorticity
!     dsp   - input spherical harmonic coefficients of divergence
!
!   output argument list:
!     pgrd  - output psi on gaussian grid
!     cgrd  - output chi on gaussian grid
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

  use specmod, only: nc,factvml,ncd2,enn1
  use kinds, only: r_kind,i_kind
  use constants, only: zero
  use gridmod, only: nlat,nlon
  implicit none

! Passed variables
  real(r_kind),dimension(nc),intent(out):: zsp,dsp
  real(r_kind),dimension(nlat,nlon),intent(inout) :: pgrd,cgrd

! Local variables
  real(r_kind),dimension(nc):: spc1,spc2
  integer(i_kind) i

! Inverse laplacian
  call s2g0_ad(spc1,pgrd)
  call s2g0_ad(spc2,cgrd)
  pgrd=0
  cgrd=0
  spc1(1)=zero
  spc1(2)=zero
  spc2(1)=zero
  spc2(2)=zero
  do i=2,ncd2
    zsp(2*i-1)=spc1(2*i-1)/(-enn1(i))
    zsp(2*i)=spc1(2*i)/(-enn1(i))
    dsp(2*i-1)=spc2(2*i-1)/(-enn1(i))
    dsp(2*i)=spc2(2*i)/(-enn1(i))
  end do

  return
end subroutine zds2pcg_ad

subroutine zds2uvg(zsp,dsp,ugrd,vgrd)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    zds2uvg     inverse of uvg2zds
!   prgmmr: kleist           org: np23                date: 2006-07-15
!
! abstract: inverse of uvg2zds
!
! program history log:
!   2006-07-15  kleist
!   2007-05-15  errico  include proper specification of pole points
!
!   input argument list:
!     zsp   - input spherical harmonic coefficients of vorticity
!     dsp   - input spherical harmonic coefficients of divergence
!
!   output argument list:
!     ugrd  - output u on gaussian grid
!     vgrd  - output v on gaussian grid
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

  use specmod, only: nc,factvml
  use kinds, only: r_kind,i_kind
  use constants, only: zero
  use gridmod, only: nlat,nlon,sinlon,coslon
  implicit none

! Passed variables
  real(r_kind),dimension(nc),intent(in):: zsp,dsp
  real(r_kind),dimension(nlat,nlon),intent(out) :: ugrd,vgrd

! Local variables
  real(r_kind),dimension(nlon,nlat-2):: grdwrk1,grdwrk2
  real(r_kind),dimension(nc):: spcwrk1,spcwrk2
  integer(i_kind) i,j,jj

  do i=1,nc
    spcwrk1(i)=dsp(i)
    spcwrk2(i)=zsp(i)
    if(factvml(i))then
      spcwrk1(i)=zero
      spcwrk2(i)=zero
    end if
  end do

  call sptez_v(spcwrk1,spcwrk2,grdwrk1,grdwrk2,1)

! Reverse ordering in j direction from n-->s to s-->n
! and copy to array that includes pole points
  do j=2,nlat-1
    jj=nlat-j
    do i=1,nlon
      ugrd(j,i)=grdwrk1(i,jj)
      vgrd(j,i)=grdwrk2(i,jj)
    end do
  end do

!  fill in pole points
!  (replace earlier algorithm that assumed zero gradient next to pole)
  call  spectra_pole_wind (ugrd,vgrd,spcwrk2,spcwrk1)


  return
end subroutine zds2uvg

subroutine zds2uvg_ad(zsp,dsp,ugrd,vgrd)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    zds2uvg_ad  adjoint of zds2uvg
!   prgmmr: kleist           org: np23                date: 2006-07-15
!
! abstract: adjoint of zds2uvg
!
! program history log:
!   2006-07-15  kleist
!   2007-04-22  errico -  correction for proper treatment of equator
!                      -  also add call to spectra_pole_scalar_ad 
!   2008-04-11  safford - rm unused uses
!
!   input argument list:
!     zsp   - input spherical harmonic coefficients of vorticity
!     dsp   - input spherical harmonic coefficients of divergence
!     ugrd  - input u on gaussian grid
!     vgrd  - input v on gaussian grid
!
!   output argument list:
!     zsp   - output spherical harmonic coefficients of vorticity
!     dsp   - output spherical harmonic coefficients of divergence
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

  use specmod, only: nc,factvml,wlat,jb,je,jcap,ncd2,enn1
  use kinds, only: r_kind,i_kind
  use constants, only: zero,two
  use gridmod, only: nlat,nlon,sinlon,coslon
  implicit none

! Passed variables
  real(r_kind),dimension(nlat,nlon),intent(in) :: ugrd,vgrd
  real(r_kind),dimension(nc),intent(inout) :: zsp,dsp

! Local variables
  real(r_kind),dimension(nlon,nlat-2):: grdwrk1,grdwrk2
  real(r_kind),dimension(nc):: spcwrk1,spcwrk2
  integer(i_kind) i,j,jj

! Transfer contents of input grid to local work array
! Reverse ordering in j direction from n-->s to s-->n
  do j=2,nlat-1
    jj=nlat-j
    do i=1,nlon
      grdwrk1(i,jj)=ugrd(j,i)
      grdwrk2(i,jj)=vgrd(j,i)
    end do
  end do

  do j=jb,je-mod(nlat,2)
    do i=1,nlon
      grdwrk1(i,j)=grdwrk1(i,j)/wlat(j)
      grdwrk1(i,nlat-1-j)=grdwrk1(i,nlat-1-j)/wlat(j)
      grdwrk2(i,j)=grdwrk2(i,j)/wlat(j)
      grdwrk2(i,nlat-1-j)=grdwrk2(i,nlat-1-j)/wlat(j)
    end do
  end do

  if (mod(nlat,2) .ne. 0) then
    do i=1,nlon
      grdwrk1(i,je)=grdwrk1(i,je)/(two*wlat(je))
      grdwrk2(i,je)=grdwrk2(i,je)/(two*wlat(je))
    end do
  endif 

  call sptez_v(spcwrk1,spcwrk2,grdwrk1,grdwrk2,-1)

  do i=2,ncd2
     spcwrk1(2*i-1)=spcwrk1(2*i-1)/enn1(i)
     spcwrk1(2*i)=spcwrk1(2*i)/enn1(i)
     spcwrk2(2*i-1)=spcwrk2(2*i-1)/enn1(i)
     spcwrk2(2*i)=spcwrk2(2*i)/enn1(i)
  end do

  do i=1,nc
     spcwrk1(i)=spcwrk1(i)*float(nlon)
     spcwrk2(i)=spcwrk2(i)*float(nlon)
  end do

  do i=2*jcap+3,nc
     spcwrk1(i)=two*spcwrk1(i)
     spcwrk2(i)=two*spcwrk2(i)
  end do

!  adjoint of pole fill 
  call  spectra_pole_wind_ad (ugrd,vgrd,spcwrk2,spcwrk1)

  do i=1,nc
    zsp(i)=spcwrk2(i)
    dsp(i)=spcwrk1(i)
    if(factvml(i))then
      zsp(i)=zero
      dsp(i)=zero
    end if
  end do

  return
end subroutine zds2uvg_ad

subroutine spectra_pole_scalar (field,coefs)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    spectra_pole_scalar    
!   prgmmr: errico           org:                 date: 2007-05-15
!
! abstract: fill pole values for scalar field using spectral coefficients
!
! program history log:
!   2007-05-15  errico
!
!   input argument list:
!     coefs  - spherical harmonic coefficients of scalar field
!
!   output argument list:
!     field - scalar field (modified at poles only)
!
! attributes:
!   language: f90
!
!$$$
 use specmod, only: nc,jcap
 use kinds, only: r_kind,i_kind
 use constants, only: zero,one,three
 use gridmod, only: nlat,nlon
  
      implicit none      

      real(r_kind), intent(in)  :: coefs(nc)        ! all spectral coefs
      real(r_kind), intent(inout) :: field(nlat,nlon) ! field, including pole    
! 
!  Local variables

      integer(i_kind) :: n           ! order of assoc. legendre polynomial 
      integer(i_kind) :: n1          ! offset for real zonal wavenumber m=0 coefs
      integer(i_kind) :: j           ! longitude index      
      real(r_kind) :: alp0(0:jcap)   ! Assoc Legendre Poly for m=0 at the North Pole
      real(r_kind) :: epsi0(0:jcap)  ! epsilon factor for m=0
      real(r_kind) :: fnum, fden
      real(r_kind)  :: afac           ! alp for S. pole 
      real(r_kind) :: fpole_n, fpole_s    ! value of scalar field at n and s pole 
!
!  The spectral coefs are assumed to be ordered
!      alternating real, imaginary
!      all m=0 first, followed by m=1, etc.
!      ordered in ascending values of n-m
!      the first index is 1, correspond to the real part of the global mean.
!      triangular truncation assumed
!      These conditions determine the value of n1.
!
!  Compute epsilon for m=0.
      epsi0(0)=zero  
      do n=1,jcap
        fnum=real(n**2)
        fden=real(4*n**2-1)
        epsi0(n)=dsqrt(fnum/fden)
      enddo
!
!  Compute Legendre polynomials for m=0 at North Pole
       alp0(0)=one
       alp0(1)=dsqrt(three)
       do n=2,jcap
         alp0(n)=(alp0(n-1)-epsi0(n-1)*alp0(n-2))/epsi0(n)
       enddo
!
!  Compute projection of wavenumber 0 (only real values for this
       fpole_n=zero
       fpole_s=zero
       n1=1
       do n=0,jcap 
         if (mod(n,2).eq.1) then
            afac=-alp0(n)
          else 
            afac= alp0(n)
          endif  
          fpole_n=fpole_n+alp0(n)*coefs(2*n+n1)
          fpole_s=fpole_s+   afac*coefs(2*n+n1)
       enddo
!
! set field for all "longitudes" at the pole to the same value
       do j=1,nlon
         field(   1,j)=fpole_s  
         field(nlat,j)=fpole_n
       enddo

       end subroutine spectra_pole_scalar 
!
!  x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x
!
subroutine spectra_pole_scalar_ad (field,coefs)
 
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    spectra_pole_scalar_ad    
!   prgmmr: errico           org:                 date: 2007-05-15
!
! abstract: adjoint of spectra_pole_scalar
!
! program history log:
!   2007-05-15  errico
!
!   input argument list:
!     field -  adjoint (dual) of field (only poles used here)
!     coefs  - adjoint (dual) of spherical harmonic coefficients
!
!   output argument list:
!     coefs  - incremented adjoint (dual) of spherical harmonic coefficients
!
! attributes:
!   language: f90
!
!$$$
 use specmod, only: nc,jcap
 use kinds, only: r_kind,i_kind
 use constants, only: zero,one,three
 use gridmod, only: nlat,nlon
  
      implicit none      

      real(r_kind), intent(inout) :: coefs(nc)  ! adjoint of all spectral coefs
      real(r_kind), intent(in) :: field(nlat,nlon) ! adjoint field, including pole    
! 
!  Local variables

      integer(i_kind) :: n           ! order of assoc. legendre polynomial 
      integer(i_kind) :: n1          ! offset for real zonal wavenumber m=0 coefs
      integer(i_kind) :: j           ! longitude index      
      real(r_kind) :: alp0(0:jcap)   ! Assoc Legendre Poly for m=0 at the North Pole
      real(r_kind) :: epsi0(0:jcap)  ! epsilon factor for m=0
      real(r_kind) :: fnum, fden
      real(r_kind)  :: afac           ! alp for S. pole
      real(r_kind) :: fpole_n, fpole_s    ! value of scalar field at n and s pole 

  
!
!  The spectral coefs are assumed to be ordered
!      alternating real, imaginary
!      all m=0 first, followed by m=1, etc.
!      ordered in ascending values of n-m
!      the first index is 1
!      triangular truncation assumed
!      These conditions determine the value of n1.
!
!  Compute epsilon for m=0.
      epsi0(0)=zero  
      do n=1,jcap
        fnum=real(n**2, r_kind)
        fden=real(4*n**2-1, r_kind)
        epsi0(n)=dsqrt(fnum/fden)
      enddo
!
!  Compute Legendre polynomials for m=0 at North Pole
       alp0(0)=one
       alp0(1)=dsqrt(three)
       do n=2,jcap
         alp0(n)=(alp0(n-1)-epsi0(n-1)*alp0(n-2))/epsi0(n)
       enddo
!
!  Compute projection of wavenumber 0 (only real values for this)
       fpole_n=zero
       fpole_s=zero
       do j=1,nlon
         fpole_n=fpole_n+field(nlat,j)
         fpole_s=fpole_s+field(   1,j)
       enddo
       
       n1=1
       do n=0,jcap 
         if (mod(n,2).eq.1) then
            afac=-alp0(n)
          else 
            afac= alp0(n)
          endif
          coefs(2*n+n1)=coefs(2*n+n1)+afac*fpole_s+alp0(n)*fpole_n  
       enddo
!
       end subroutine spectra_pole_scalar_ad 
!
!  x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x
!
subroutine spectra_pole_wind (ufield,vfield,vort,divg)               
 
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:  spectra_pole_wind          grid to spectral
!   prgmmr: errico           org:                 date: 2007-05-15
!
! abstract: fill pole values for vector wind field using spectral coefficients
!
! program history log:
!   2007-05-15  errico
!
!   input argument list:
!     vort  - spherical harmonic coefficients of vorticity
!     divg  - spherical harmonic coefficients of divergence
!
!   output argument list:
!     ufield - u wind component field (set at poles only)
!     vfield - v wind component field (set at poles only)
!
! attributes:
!   language: f90
!
!$$$
 use specmod, only: nc,jcap
 use kinds, only: r_kind,i_kind
 use constants, only: zero,one,two,three,rearth,pi
 use gridmod, only: nlat,nlon
     
      implicit none  
  
      real(r_kind), intent(in)  :: vort(nc) ! spect. coefs for vorticity
      real(r_kind), intent(in)  :: divg(nc) ! spect. coefs for divergence
      real(r_kind), intent(inout) :: ufield(nlat,nlon) ! u field, including pole    
      real(r_kind), intent(inout) :: vfield(nlat,nlon) ! v field, including pole    
! 
!  Local variables

      integer(i_kind) :: n      ! order of assoc. Legendre polynomial
      integer(i_kind) :: n1     ! offset value for location of m=1 coefs
      integer(i_kind) :: j      ! longitude index 
      real(r_kind) :: alp1(1:jcap)  ! Assoc Legendre Poly for m=1 at the North Pole
      real(r_kind) :: epsi1(1:jcap) ! epsilon factor for zonal wavenumber m=1
      real(r_kind) :: fnum, fden, fac
      real(r_kind) :: coslon(nlon), sinlon(nlon) ! sines and cosines of longitudes
      real(r_kind) :: afac       ! alp for S. pole 
      real(r_kind) :: s_vort_R_n  ! sum of real part of P(n)*vort(n)/(n*n+n) for N.pole
      real(r_kind) :: s_vort_I_n  ! sum of imag part of P(n)*vort(n)/(n*n+n) for N.pole
      real(r_kind) :: s_divg_R_n  ! sum of real part of P(n)*divg(n)/(n*n+n) for N.pole
      real(r_kind) :: s_divg_I_n  ! sum of imag part of P(n)*divg(n)/(n*n+n) for N.pole
      real(r_kind) :: s_vort_R_s  ! sum of real part of P(n)*vort(n)/(n*n+n) for S.pole
      real(r_kind) :: s_vort_I_s  ! sum of imag part of P(n)*vort(n)/(n*n+n) for S.pole
      real(r_kind) :: s_divg_R_s  ! sum of real part of P(n)*divg(n)/(n*n+n) for S.pole
      real(r_kind) :: s_divg_I_s  ! sum of imag part of P(n)*divg(n)/(n*n+n) for S.pole
      real(r_kind) :: uR_n, vR_n ! twice real part of m=1 Fourier coef for u,v (N.pole) 
      real(r_kind) :: uI_n, vI_n ! twice imag part of m=1 Fourier coef for u,v (N.pole) 
      real(r_kind) :: uR_s, vR_s ! twice real part of m=1 Fourier coef for u,v (S.pole)  
      real(r_kind) :: uI_s, vI_s ! twice imag part of m=1 Fourier coef for u,v (S.pole)      
      real(r_kind) :: tworearth             
    
!  spectral components of u:
!  u(n)=a( -e(n)*vort(n-1)/n + e(n+1)*vort(n+1)/(n+1) -i*divg(n)/(n*n+n)
!  where a=earth's radius, vort and divg are spectral coefs, and e=epsi1 factor 
!  complex Fourier coef for wavenumber 1 of u at the pole is
!  u_coef= sum_(n=1 to n=jcap+1) p_(n,m=1)*u(n)
!  At rhe poles, the sum over vort contribution is simplified by noting that
!  sum (n=1 to n=jcap+1) p_(n,m=1)*( vort contrib to u(n)) =
!    -a*sum (n=1 to n=jcap)   p_(n,m=1)*vort(n)/(n*n+n)
!  for all vort(n), n=1,...,jcap
!  Therefore
!  u_coef= a* (-   sum (n=1 to n=jcap)   p_(n,m=1)*vort(n)/(n*n+n)
!              - i*sum (n=1 to n=jcap)   p_(n,m=1)*divg(n)/(n*n+n) ) 
!  v_coef=-i*u_coef
!  u(lon)=2.*modulus(u_coef) cos(u_phase + lon/twopi)
!  where the 2 is because m=-1 is implicitly considered, with the m=-1
!    Fourier coef equal to the complex conjugate of that for m=1
!  u_phase is atan(imag part of u_coef/ real part of u_coef) 
!
!  The spectral coefs are assumed to be ordered
!      alternating real, imaginary
!      all m=0 first, followed by m=1, etc.
!      ordered in ascending values of n-m
!      the first index is 1
!      triangular truncation assumed
!      These conditions determine the value of n1.
!  The phases of the spectra are assumed to be with respect
!  to the first longitude being 0.
!
      n1=2*(jcap+1)
!
!  Specify cosine and sines of longitudes assuming that 
!  the phases of spectral coefs are with repect to the 
!  origin being the first longitude.
      fac=two*pi/nlon
      do j=1,nlon
        coslon(j)=cos(fac*(j-1))
        sinlon(j)=sin(fac*(j-1))
      enddo

      do n=1,jcap
        fnum=real(n**2-1, r_kind)
        fden=real(4*n**2-1, r_kind)
        epsi1(n)=dsqrt(fnum/fden)
      enddo
!
!  Compute Legendre polynomials / cos for m=1 at North Pole
!  This is actually limit Pn,m / abs (cos) as pole is approached 
      alp1(1)=sqrt(three/two)
      alp1(2)=dsqrt(two+three)*alp1(1)
      do n=3,jcap
        alp1(n)=(alp1(n-1)-epsi1(n-1)*alp1(n-2))/epsi1(n)
      enddo
!
!  Replace Legendre polynomials by P/(n*n+n)
      do n=1,jcap
        alp1(n)=alp1(n)/(n*n+n)
      enddo
!
!  Compute sums of coefs weighted by P(n)/(n*n+n)
      s_vort_R_n=zero
      s_vort_I_n=zero
      s_divg_R_n=zero
      s_divg_I_n=zero
      s_vort_R_s=zero
      s_vort_I_s=zero
      s_divg_R_s=zero
      s_divg_I_s=zero
      
      do n=1,jcap 
        if (mod(n,2).eq.0) then
          afac=-alp1(n)
        else 
          afac= alp1(n)
        endif  
        s_vort_R_n = s_vort_R_n + alp1(n)*vort(2*n-1+n1)
        s_vort_I_n = s_vort_I_n + alp1(n)*vort(2*n  +n1)        
        s_divg_R_n = s_divg_R_n + alp1(n)*divg(2*n-1+n1)
        s_divg_I_n = s_divg_I_n + alp1(n)*divg(2*n  +n1) 
        s_vort_R_s = s_vort_R_s + afac*vort(2*n-1+n1)
        s_vort_I_s = s_vort_I_s + afac*vort(2*n  +n1)        
        s_divg_R_s = s_divg_R_s + afac*divg(2*n-1+n1)
        s_divg_I_s = s_divg_I_s + afac*divg(2*n  +n1) 
      enddo
      s_vort_R_s = -s_vort_R_s
      s_vort_I_s = -s_vort_I_s
!
!  Determine 2* real and imag parts for m=1 u wind at pole
!  The factor -1 if south is because as the south pole is approached, 
!  the limit of abs(cos)/cos = -1.  
      tworearth=two*rearth
      uR_n= tworearth * (s_divg_I_n - s_vort_R_n)
      uI_n=-tworearth * (s_divg_R_n + s_vort_I_n) 
      vR_n=-uI_n
      vI_n= uR_n
      uR_s= tworearth * (s_divg_I_s - s_vort_R_s)
      uI_s=-tworearth * (s_divg_R_s + s_vort_I_s) 
      vR_s= uI_s
      vI_s=-uR_s
!
!  Perform Fourier projection for m=1 at pole             
      do j=1,nlon
        ufield(nlat,j)=uR_n*coslon(j)-uI_n*sinlon(j)
        vfield(nlat,j)=vR_n*coslon(j)-vI_n*sinlon(j)
        ufield(   1,j)=uR_s*coslon(j)-uI_s*sinlon(j)
        vfield(   1,j)=vR_s*coslon(j)-vI_s*sinlon(j)
      enddo
!
      end subroutine spectra_pole_wind 
!
!  x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x
!
subroutine spectra_pole_wind_ad (ufield,vfield,vort,divg)


!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:  spectra_pole_wind_ad 
!   prgmmr: errico           org:                 date: 2007-05-15
!
! abstract: adjoint of routine spectra_pole_wind
!
! program history log:
!   2007-05-15  errico
!
!   input argument list:
!     ufield - adjoint (dual) of u wind component field (set at poles only)
!     vfield - adjoint (dual) of v wind component field (set at poles only)
!     vort  - adjoint (dual) of spherical harmonic coefficients of vorticity
!     divg  - adjoint (dual) of spherical harmonic coefficients of divergence
!
!   output argument list:
!     vort  - incremented adjoint (dual) of spherical harmonic coefficients of vorticity
!     divg  - incremented adjoint (dual) of spherical harmonic coefficients of divergence
!
! attributes:
!   language: f90
!
!$$$
 use specmod, only: nc,jcap
 use kinds, only: r_kind,i_kind
 use constants, only: zero,one,two,three,rearth,pi
 use gridmod, only: nlat,nlon
     
      implicit none  
  
      real(r_kind), intent(in) :: ufield(nlat,nlon) ! adjoint of u field, including pole    
      real(r_kind), intent(in) :: vfield(nlat,nlon) ! adjoint of v field, including pole    
      real(r_kind), intent(inout)  :: vort(nc) ! adjoint of spect. coefs for vorticity
      real(r_kind), intent(inout)  :: divg(nc) ! adjoint of spect. coefs for divergence
! 
!  Local variables

      integer(i_kind) :: n      ! order of assoc. Legendre polynomial
      integer(i_kind) :: n1     ! offset value for location of m=1 coefs
      integer(i_kind) :: j      ! longitude index 
      real(r_kind) :: alp1(1:jcap)  ! Assoc Legendre Poly for m=1 at the North Pole
      real(r_kind) :: epsi1(1:jcap) ! epsilon factor for zonal wavenumber m=1
      real(r_kind) :: fnum, fden, fac
      real(r_kind) :: coslon(nlon), sinlon(nlon) ! sines and cosines of longitudes
      real(r_kind) :: afac       ! alp for S. pole 
      real(r_kind) :: s_vort_R_n  ! sum of real part of P(n)*vort(n)/(n*n+n) for N.pole
      real(r_kind) :: s_vort_I_n  ! sum of imag part of P(n)*vort(n)/(n*n+n) for N.pole
      real(r_kind) :: s_divg_R_n  ! sum of real part of P(n)*divg(n)/(n*n+n) for N.pole
      real(r_kind) :: s_divg_I_n  ! sum of imag part of P(n)*divg(n)/(n*n+n) for N.pole
      real(r_kind) :: s_vort_R_s  ! sum of real part of P(n)*vort(n)/(n*n+n) for S.pole
      real(r_kind) :: s_vort_I_s  ! sum of imag part of P(n)*vort(n)/(n*n+n) for S.pole
      real(r_kind) :: s_divg_R_s  ! sum of real part of P(n)*divg(n)/(n*n+n) for S.pole
      real(r_kind) :: s_divg_I_s  ! sum of imag part of P(n)*divg(n)/(n*n+n) for S.pole
      real(r_kind) :: uR_n, vR_n ! twice real part of m=1 Fourier coef for u,v (N.pole) 
      real(r_kind) :: uI_n, vI_n ! twice imag part of m=1 Fourier coef for u,v (N.pole) 
      real(r_kind) :: uR_s, vR_s ! twice real part of m=1 Fourier coef for u,v (S.pole)  
      real(r_kind) :: uI_s, vI_s ! twice imag part of m=1 Fourier coef for u,v (S.pole)      
      real(r_kind) :: tworearth             
!  The phases of the spectra are assumed to be with respect
!  to the first longitude being 0.
!
      n1=2*(jcap+1)
!
!  Specify cosine and sines of longitudes assuming that 
!  the phases of spectral coefs are with repect to the 
!  origin being the first longitude.
      fac=two*pi/nlon
      do j=1,nlon
        coslon(j)=cos(fac*(j-1))
        sinlon(j)=sin(fac*(j-1))
      enddo

      do n=1,jcap
        fnum=real(n**2-1, r_kind)
        fden=real(4*n**2-1, r_kind)
        epsi1(n)=dsqrt(fnum/fden)
      enddo
!
!  Compute Legendre polynomials / cos for m=1 at North Pole
!  This is actually limit Pn,m / abs (cos) as pole is approached 
      alp1(1)=sqrt(three/two)
      alp1(2)=dsqrt(two+three)*alp1(1)
      do n=3,jcap
        alp1(n)=(alp1(n-1)-epsi1(n-1)*alp1(n-2))/epsi1(n)
      enddo
!
!  Replace Legendre polynomials by P/(n*n+n)
      do n=1,jcap
        alp1(n)=alp1(n)/(n*n+n)
      enddo
!
!  Perform adjoint of Fourier projection for m=1 at pole         
      uR_n=zero    
      uI_n=zero    
      vR_n=zero    
      vI_n=zero    
      uR_s=zero    
      uI_s=zero    
      vR_s=zero    
      vI_s=zero    
      do j=1,nlon
        uR_n=uR_n+coslon(j)*ufield(nlat,j)
        uI_n=uI_n-sinlon(j)*ufield(nlat,j)
        vR_n=vR_n+coslon(j)*vfield(nlat,j)
        vI_n=vI_n-sinlon(j)*vfield(nlat,j)
        uR_s=uR_s+coslon(j)*ufield(   1,j)
        uI_s=uI_s-sinlon(j)*ufield(   1,j)
        vR_s=vR_s+coslon(j)*vfield(   1,j)
        vI_s=vI_s-sinlon(j)*vfield(   1,j)
      enddo

!  the limit of abs(cos)/cos = -1.  
      uI_n=uI_n-vR_n
      uR_n=uR_n+vI_n
      uI_s=uI_s+vR_s
      uR_s=uR_s-vI_s
      tworearth=two*rearth
      s_vort_R_n=-tworearth*uR_n
      s_vort_I_n=-tworearth*uI_n
      s_divg_R_n=-tworearth*uI_n
      s_divg_I_n= tworearth*uR_n
      s_vort_R_s= tworearth*uR_s
      s_vort_I_s= tworearth*uI_s
      s_divg_R_s=-tworearth*uI_s
      s_divg_I_s= tworearth*uR_s
!
      do n=1,jcap 
        if (mod(n,2).eq.0) then
           afac=-alp1(n)
         else 
           afac= alp1(n)
         endif  
         vort(2*n-1+n1)=vort(2*n-1+n1)+alp1(n)*s_vort_R_n  &
                                      +   afac*s_vort_R_s
         vort(2*n  +n1)=vort(2*n  +n1)+alp1(n)*s_vort_I_n  &
                                      +   afac*s_vort_I_s
         divg(2*n-1+n1)=divg(2*n-1+n1)+alp1(n)*s_divg_R_n  &
                                      +   afac*s_divg_R_s
         divg(2*n  +n1)=divg(2*n  +n1)+alp1(n)*s_divg_I_n  &
                                      +   afac*s_divg_I_s
      enddo
!
      end subroutine spectra_pole_wind_ad 
!
!

subroutine test_inverses(mype)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram: test_inverses
!   prgmmr: kleist           org: np23                date: 2006-07-15
!
! abstract: test that corresponding invserse routines for spectral transforms
!           are indeed the inverses of each other (up to roundoff error) and 
!           that corresponding adjoints are indeed adjouts (up to roundoff 
!           error)           
!
! program history log:
!   2006-07-15  kleist
!   2007-04-22  errico - addition of some further tests, including for vector 
!                        transforms and adjoint testing 
!   2009-01-02  todling - remove unused vars
!
!   input argument list:
!     mype  - processor number
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
! Notes: 
!
!   The test of inverses requires either checking spectral coefs or checking
!   fields, but the latter only if the starting field has been spectrally truncated,
!   otherwise the starting field has components that can not be reconstituted 
!   by the spectra.
!
!   The jacobian test for adjoints uses the fact that the matrix operator for 
!   the adjoint is the transpose of the forward operator matrix. Each of these 
!   matrices have elements in common. Individual elements can be implicitly 
!   determined by inputing unit vectors (say element j) to the operator 
!   (transform) and then looking at particular single values (say i) of the ouput:
!   the result is element i,j of the matrix for the operator.
!
!   The norm test uses the fact that <x, My> = <M^T x, y>, where M^T is the adjoint
!   of M and x and y are arbitrary vectors in the appropriate subspaces. This is
!   the definition of the adjoint, defined for the norm <,>.  
!
!$$$

  use kinds, only: r_kind,i_kind,r_single
  use gridmod, only:  nlat,nlon
  use guess_grids, only: ges_u,ges_tv,ges_v,ntguessig
  use specmod, only: nc,jcap
  use constants, only: zero,one,two
  implicit none

  integer(i_kind),intent(in):: mype
  integer(i_kind) :: index (5)
  integer i,j,n,ig,ncstep
  real(r_kind),dimension(nlat,nlon):: u1,v1,u2,u3,v2,t1,t2
  real(r_kind),dimension(nc):: s1,s2,s3
  real(r_kind),dimension(nc):: d1,d2,d3
  real(r_kind):: diffmax, absmax
! smallfrac is expected size of lagest fractional roundoff error 
  real(r_kind),parameter:: smallfrac=1.e-9

  s1=zero ; s2=zero ; s3=zero
  t1=zero ; t2=zero ; v1=zero

! use the following field to create a test field t1
  call gather_stuff2(ges_tv(1,1,1,ntguessig),t1,1,mype,0)

! only perform the test on one processor.
  if (mype==0) then

! load S1 with something
    write(777,*) ' *********************************************************'
    write(777,*) ' *                   Test spectral routines              *'
    write(777,*) ' *   diff=difference of numbers that should be the same  *'
    write(777,*) ' *        except for roundoff effects                    *'
    write(777,*) ' *   fracdiff=fractional difference of numbers that      *'
    write(777,*) ' *        should be the same except for roundoff: only   *'
    write(777,*) ' *        printed if > parameter smallfrac               *'
    write(777,*) ' *********************************************************'
    write(777,*) ' smallfrac=',smallfrac
!
!
! *********************************************************
! TEST SCALAR TRANSFORM AND ITS INVERSE
    call g2s0(s1,t1)  ! compute spectral coefs s1
    call s2g0(s1,t2)  ! compute spectrally truncated field t2
    call g2s0(s3,t2)  ! recompute spectra from field  
!
! check all spectral coefficients
    write(777,*) ' '
    write(777,*) ' **** Test that s2g0 and g2s0 are inverses ****'
    absmax=zero
    diffmax=zero
    do i=1,nc
      if (s1(i).ne.0  .and. abs((s1(i)-s3(i))/s1(i)) .gt. smallfrac) then
        write(777,'(a,i6,1p3e18.10)') 'i,s1,s3,fracdiff = ' &
                                     ,i,s1(i),s3(i),(s1(i)-s3(i))/s1(i)
      end if
      if (abs(s1(i)) > absmax) absmax=abs(s1(i))
      if (abs(s3(i)) > absmax) absmax=abs(s3(i))
      if (abs(s1(i)-s3(i)) > diffmax) diffmax=abs(s1(i)-s3(i))
    end do
    write(777,*) ' max of absolute values tested =',absmax
    write(777,*) ' max of absolute diff obtained =',diffmax
!
!
! *****************************************************************
! TEST VECTOR TRANSFORM AND ITS INVERSE
! use same spectral coefs as for previous test
    u1=zero; u2=zero; v1=zero; v2=zero
    s2=zero; s3=zero
    d2=zero; d3=zero
    s1(1)=zero  ! this component is always zero
    d1=0.1*s1 
    call zds2uvg(s1,d1,u1,v1)  
    call uvg2zds(s2,d2,u1,v1) 
!
    write(777,*) ' '
    write(777,*) ' **** Test that zds2uvg and uvg2zds are inverses for vorticity ****'
    absmax=zero
    diffmax=zero
     do i=1,nc
        if (s1(i).ne.0  .and. abs((s1(i)-s2(i))/s1(i)) .gt. smallfrac) then
        write(777,'(a,i6,1p3e18.10)') 'i,s1,s2,fracdiff = ' &
                                     ,i,s1(i),s2(i),(s1(i)-s2(i))/s1(i)
      end if
      if (abs(s1(i)) > absmax) absmax=abs(s1(i))
      if (abs(s2(i)) > absmax) absmax=abs(s2(i))
      if (abs(s1(i)-s2(i)) > diffmax) diffmax=abs(s1(i)-s2(i))
    end do
    write(777,*) ' max of absolute values tested =',absmax
    write(777,*) ' max of absolute diff obtained =',diffmax
!
    write(777,*) ' '
    write(777,*) ' **** Test that zds2uvg and uvg2zds are inverses for divergence ****'
    absmax=zero
    diffmax=zero
     do i=1,nc
        if (d1(i).ne.0  .and. abs((d1(i)-d2(i))/d1(i)) .gt. smallfrac) then
        write(777,'(a,i6,1p3e18.10)') 'i,d1,d2,fracdiff = ' &
                                     ,i,d1(i),d2(i),(d1(i)-d2(i))/d1(i)
      end if
      if (abs(d1(i)) > absmax) absmax=abs(d1(i))
      if (abs(d2(i)) > absmax) absmax=abs(d2(i))
      if (abs(d1(i)-d2(i)) > diffmax) diffmax=abs(d1(i)-d2(i))
    end do
    write(777,*) ' max of absolute values tested =',absmax
    write(777,*) ' max of absolute diff obtained =',diffmax
!
!
! *********************************************************
! TEST THAT ADJOINT SCALAR ROUTINES ARE INVERSES OF EACH OTHER
    
    call s2g0_ad(s1,t1)  ! compute spectral adjoint coefs s1
    call g2s0_ad(s1,t2)  ! compute spectrally truncated adjoint field t2
    call s2g0_ad(s3,t2)  ! recompute spectra from field  
!
! check all spectra
    write(777,*) ' '
    write(777,*) ' **** Test that s2g0_ad and g2s0_ad are inverses ****'
    absmax=zero
    diffmax=zero
    do i=1,nc
        if (s1(i).ne.0  .and. abs((s1(i)-s3(i))/s1(i)) .gt. smallfrac) then
        write(777,'(a,i6,1p3e18.10)') 'i,s1,s3,fracdiff = ' &
                                     ,i,s1(i),s3(i),(s1(i)-s3(i))/s1(i)
      end if
      if (abs(s1(i)) > absmax) absmax=abs(s1(i))
      if (abs(s3(i)) > absmax) absmax=abs(s3(i))
      if (abs(s1(i)-s3(i)) > diffmax) diffmax=abs(s1(i)-s3(i))
    end do
    write(777,*) ' max of absolute values tested =',absmax
    write(777,*) ' max of absolute diff obtained =',diffmax!
!
!
!   ***********************************************************
!   TEST THAT ADJOINT VECTOR ROUTINES ARE INVERSES OF EACH OTHER     
    u1=zero; v1=zero
    s2=zero; d2=zero
    s1(1)=zero
    d1=0.1*s1 
    call uvg2zds_ad(s1,d1,u1,v1) 
    call zds2uvg_ad(s2,d2,u1,v1)
!
    write(777,*) ' '
    write(777,*) ' **** Test that zds2uvg_ad and uvg2zds_ad are' &
                 ,' inverses for vorticity ****'
    absmax=zero
    diffmax=zero
     do i=1,nc
        if (s1(i).ne.0  .and. abs((s1(i)-s2(i))/s1(i)) .gt. smallfrac) then
        write(777,'(a,i6,1p3e18.10)') 'i,s1,s2,fracdiff = ' &
                                     ,i,s1(i),s2(i),(s1(i)-s2(i))/s1(i)
      end if
      if (abs(s1(i)) > absmax) absmax=abs(s1(i))
      if (abs(s2(i)) > absmax) absmax=abs(s2(i))
      if (abs(s1(i)-s2(i)) > diffmax) diffmax=abs(s1(i)-s2(i))
    end do
    write(777,*) ' max of absolute values tested =',absmax
    write(777,*) ' max of absolute diff obtained =',diffmax
!
    write(777,*) ' '
    write(777,*) ' **** Test that zds2uvg_ad and uvg2zds_ad are' &
                ,' inverses for divergence ****'
    absmax=zero
    diffmax=zero
     do i=1,nc
        if (d1(i).ne.0  .and. abs((d1(i)-d2(i))/d1(i)) .gt. smallfrac) then
        write(777,'(a,i6,1p3e18.10)') 'i,d1,d2,fracdiff = ' &
                                     ,i,d1(i),d2(i),(d1(i)-d2(i))/d1(i)
      end if
      if (abs(d1(i)) > absmax) absmax=abs(d1(i))
      if (abs(d2(i)) > absmax) absmax=abs(d2(i))
      if (abs(d1(i)-d2(i)) > diffmax) diffmax=abs(d1(i)-d2(i))
    end do
    write(777,*) ' max of absolute values tested =',absmax
    write(777,*) ' max of absolute diff obtained =',diffmax
!
!
!   ***********************************************
!   TEST ADJOINT FOR SELECTED ELEMENTS OF JACOBIAN MATRIX
!   test that s2g0_ad is adjoint of s2g0_ad
!
    write(777,*) ' '
    write(777,*) ' **** Apply Jacobian test to selected elements' &
                ,' of s2g0_ad and s2g0 ***' 
!
    absmax=zero
    diffmax=zero
!
! So only 5 lats tested to cut down on computation
    index(1)=1            ! S. pole
    index(2)=2            ! 1st Lat next to S. pole
    index(3)=(nlat+1)/2   ! equator or ist N. of equator if no equator
    index(4)=nlat-1       ! 1st lat next to N. pole 
    index(5)=nlat         ! N. pole
!
! Only check a subset of spectral coefs to reduce computation
    ncstep=4*jcap/3
    if (mod(ncstep,2) == 0) ncstep=ncstep+1 ! then both real and imag parts tested
   
    do n=1,nc,ncstep
      if (mod(n,2) ==0 .and. n .le. 2*jcap+2 ) then
        d1(n)=zero   ! these are imag parts of coefs for zonal wave number 0
      else
        i=3   ! only one longitude tested 
!
        do ig=1,5     !loop over selected lats to test
          d1=zero; d2=zero
          u1=zero; u2=zero
          j = index(ig)
          d1(n)=one
          u2(j,i)=one
          call s2g0_ad(d2,u2)  
          call s2g0(d1,u1)
          d3(n)=u1(j,i)-d2(n)
          if (abs(d3(n)) .gt. smallfrac*(abs(d2(n))+abs(u1(j,i))) ) then 
            write(777,'(a,2i7,1p3e18.10)') ' latindex,spec-index,s,g,diff ' &
                                            ,j,n,d2(n),u1(j,i),d3(n)
          endif
          if (abs(d2(n))  > absmax) absmax=abs(d2(n))
          if (abs(u1(j,i)) > absmax) absmax=abs(u1(j,i))
          if (abs(d3(n))  > diffmax) diffmax=abs(d3(n))      
        enddo   ! loop over selected lats
      endif     ! test if imag part of zonal wave 0 coef
 
    enddo       ! loop over spec index n
 
    write(777,*) ' max of absolute values tested =',absmax
    write(777,*) ' max of absolute diff obtained =',diffmax
!
!
!   *******************************************
!   TEST ADJOINT USING NORM TEST
!   test that uvg2zds_ad is adjoint of uvg2zds      
!   s is vort spectral coefs here
    u1=zero; u2=zero; v1=zero; v2=zero
    s1=zero; s2=zero; d1=zero; d2=zero

! fill wind with random numbers, then spectrally truncate
    call random_number(u1)
    call random_number(v1)
    call uvg2zds(s1,d1,u1,v1)
    u1=zero
    v1=zero
    call zds2uvg(s1,d1,u1,v1)  
!
!  fill spectral adjoint variables with random numbers
!  but with magnitudes like we have in real cases   
    call random_number(d2)
    call random_number(s2)
    d2=d2*d1 ! this will set values that should be 0 to 0.
    s2=s2*s1 ! this will set values that should be 0 to 0.
!
!  call 2 routines to compare
    s1=zero
    d1=zero
    u2=zero
    v2=zero  
    call uvg2zds_ad(s2,d2,u2,v2)   
    call uvg2zds(s1,d1,u1,v1)  
!
!  d3(1) is the norm in terms of spectra 
    d3(1:3)=zero
    do i=1,nc
      d3(1)=d3(1) + s1(i)*s2(i) + d1(i)*d2(i)
    enddo
!
!  d3(2) is the norm in terms of grid values
    do i=1,nlat
      do j=1,nlon
        d3(2)=d3(2) + u1(i,j)*u2(i,j) + v1(i,j)*v2(i,j)
      enddo
    enddo
!
!  d3(3) is the difference in the norms
    d3(3)=d3(1)-d3(2)
! 
    write(777,*) ' '
    write(777,*) ' **** Apply norm test to uvg2zds and uvg2zds_ad ****'
    write(777,'(a,1p3e18.10)') ' zdnorm, uvnorm, diff ',d3(1:3)
!
!
!   ****************************************************
!   TEST VECTOR TRANSFORM ADJOINT ZDS2UVG USING NORM TEST
!   test that zds2uvg_ad is adjoint of zds2uvg      
!   s is vort spectral coefs here
    u1=zero; u2=zero; v1=zero; v2=zero
    s1=zero; s2=zero; d1=zero; d2=zero

! fill wind with random numbers, then spectrally truncate
    call random_number(u1)
    call random_number(v1)
    call uvg2zds(s1,d1,u1,v1)
    u1=zero
    v1=zero
    call zds2uvg(s1,d1,u1,v1)  
!
!  fill spectral adjoint variables with random numbers
!  but with magnitudes like we have in real cases   
    call random_number(d2)
    call random_number(s2)
    d2=d2*d1 ! this will set values that should be 0 to 0.
    s2=s2*s1 ! this will set values that should be 0 to 0.
!
!  call 2 routines to compare
    s1=zero
    d1=zero
    u2=zero
    v2=zero  
    call zds2uvg(s2,d2,u2,v2)  
    call zds2uvg_ad(s1,d1,u1,v1)  
!
!  d3(1) is the norm in terms of spectra 
    d3(1:3)=zero
    do i=1,nc
      d3(1)=d3(1) + s1(i)*s2(i) + d1(i)*d2(i)
    enddo
!
!  d3(2) is the norm in terms of grid values
    do i=1,nlat
      do j=1,nlon
        d3(2)=d3(2) + u1(i,j)*u2(i,j) + v1(i,j)*v2(i,j)
      enddo
    enddo
!
!  d3(3) is the difference in the norms
    d3(3)=d3(1)-d3(2)
! 
    write(777,*) ' '
    write(777,*) ' **** Apply norm test to zds2uvg and zds2uvg_ad ****'
    write(777,'(a,1p3e18.10)') ' zdnorm, uvnorm, diff ',d3(1:3)
!
!
!   **************************************************
!   TEST SCALAR TRANSFROM ADJOINT S2G USING NORM TEST
!   u is scalar field here

! fill adjoint field with random numbers, then compute adjoint spectra
    call random_number(u1)
    u3=u1
    s1=zero
    call s2g0_ad(s1,u3)   

!  fill spectral variables with random numbers
!  but with magnitudes like we have in real cases
    call random_number(s2)
    s2=s2*s1  ! this will set values that should be 0 to 0.
    s3=s2
    u2=zero
    call s2g0(s3,u2)
!
!  d3(1) is the norm in terms of spectra 
    d3(1:3)=zero
    do i=1,nc
      d3(1)=d3(1) + s1(i)*s2(i) 
    enddo
!
!  d3(2) is the norm in terms of grid values
    do i=1,nlat
      do j=1,nlon
        d3(2)=d3(2) + u1(i,j)*u2(i,j) 
      enddo
    enddo
!
!  d3(3) is the difference in the norms
    d3(3)=d3(1)-d3(2)
! 
    write(777,*) ' '
    write(777,*) ' **** Apply norm test to s2g0 and s2g0_ad ****'
    write(777,'(a,1p3e18.10)') ' snorm, gnorm, diff ',d3(1:3)
!
!
!   ****************************************************
!   TEST SCALAR TRANSFORM ADJOINT G2S USING NORM TEST
!   u is scalar field here

! fill field with random numbers, then spectrally truncate
    call random_number(u1)
    u3=u1
    s1=zero
    call g2s0(s1,u3)
!
!  fill spectral adjoint variables with random numbers
!  but with magnitudes like we have in real cases
    call random_number(s2)
    s2=s2*s1  ! this will set values that should be 0 to 0.
    s3=s2
    u2=zero
    call g2s0_ad(s3,u2)
!
!  d3(1) is the norm in terms of spectra 
    d3(1:3)=zero
    do i=1,nc
      d3(1)=d3(1) + s1(i)*s2(i) 
    enddo
!
!  d3(2) is the norm in terms of grid values
    do i=1,nlat
      do j=1,nlon
        d3(2)=d3(2) + u1(i,j)*u2(i,j) 
      enddo
    enddo
!
!  d3(3) is the difference in the norms
    d3(3)=d3(1)-d3(2)
! 
    write(777,*) ' '
    write(777,*) ' **** Apply norm test to g2s0 and g2s0_ad ****'
    write(777,'(a,1p3e18.10)') ' snorm, gnorm, diff ',d3(1:3)
!
!
   end if   ! end mype
!
!
end subroutine test_inverses



