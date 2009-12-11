subroutine read_wrf_mass_files(mype)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    read_wrf_mass_files   same as read_files, but for wrfmass
!   prgmmr: parrish          org: np22                date: 2004-06-22
!
! abstract: figure out available time levels of background fields for 
!             later input. This is patterned after read_wrf_nmm_files.
!
! program history log:
!   2004-06-22  parrish, document
!   2004-08-02  treadon - add only to module use, add intent in/out
!   2004-12-03  treadon - replace mpe_ibcast (IBM extension) with
!                         standard mpi_bcast
!   2005-03-30  treadon - reformat code (cosmetic changes only)
!   
!   input argument list:
!     mype     - pe number
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$ end documentation block

  use kinds, only: r_kind,r_single,i_kind
  use mpimod, only: mpi_comm_world,ierror,mpi_rtype,npe
  use guess_grids, only: nfldsig,nfldsfc,ntguessig,ntguessfc,&
       ifilesig,ifilesfc,hrdifsig,hrdifsfc,create_gesfinfo
  use gsi_4dvar, only: nhr_assimilation
  use gridmod, only: regional_time,regional_fhr
  use constants, only: izero,ione,zero,one,zero_single,r60inv
  use obsmod, only: iadate
  implicit none

! Declare passed variables
  integer(i_kind),intent(in):: mype

! Declare local parameters
  real(r_kind),parameter:: r0_001=0.001_r_kind

! Declare local variables
  logical(4) fexist
  character(6) filename
  integer(i_kind) i,j,iwan,npem1
  integer(i_kind) nhr_half
  integer(i_kind) nminanl,nmings,nming2,ndiff
  integer(i_kind),dimension(4):: idateg
  integer(i_kind),dimension(5):: idate5
  real(r_single) hourg4
  real(r_kind) hourg,temp
  real(r_kind),dimension(202,2):: time_ges


!-----------------------------------------------------------------------------
! Start read_wrf_mass_files here.
  nhr_half=nhr_assimilation/2
  if(nhr_half*2 < nhr_assimilation) nhr_half=nhr_half+ione
  npem1=npe-ione

  do i=1,202
     time_ges(i,1) = 999_r_kind
     time_ges(i,2) = 999_r_kind
  end do


! Let a single task query the guess files.
  if(mype==npem1) then

!    Convert analysis time to minutes relative to fixed date
     call w3fs21(iadate,nminanl)
     write(6,*)'READ_wrf_mass_FILES:  analysis date,minutes ',iadate,nminanl

!    Check for consistency of times from sigma guess files.
     iwan=izero
     do i=0,99
        write(filename,100)i
100     format('sigf',i2.2)
        inquire(file=filename,exist=fexist)
        if(fexist)then
           idateg(1)=regional_time(4)  !  hour
           idateg(2)=regional_time(2)  !  month
           idateg(3)=regional_time(3)  !  day
           idateg(4)=regional_time(1)  !  year
           hourg4= regional_fhr        !  fcst hour
           hourg = hourg4
           idate5(1)=idateg(4); idate5(2)=idateg(2)
           idate5(3)=idateg(3); idate5(4)=idateg(1); idate5(5)=izero
           call w3fs21(idate5,nmings)
           nming2=nmings+60*hourg
           write(6,*)'READ_wrf_mass_FILES:  sigma guess file, nming2 ',hourg,idateg,nming2
           ndiff=nming2-nminanl
           if(abs(ndiff) > 60*nhr_half ) go to 110
           iwan=iwan+ione
           time_ges(iwan,1) = (nming2-nminanl)*r60inv
           time_ges(iwan+100,1)=i+r0_001
        end if
110     continue
     end do
     time_ges(201,1)=one
     time_ges(202,1)=one
     if(iwan > ione)then
        do i=1,iwan
           do j=i+ione,iwan 
              if(time_ges(j,1) < time_ges(i,1))then
                 temp=time_ges(i+100_i_kind,1)
                 time_ges(i+100_i_kind,1)=time_ges(j+100_i_kind,1)
                 time_ges(j+100_i_kind,1)=temp
                 temp=time_ges(i,1)
                 time_ges(i,1)=time_ges(j,1)
                 time_ges(j,1)=temp
              end if
           end do
           if(time_ges(i,1) < r0_001)time_ges(202,1) = i
        end do
     end if
     time_ges(201,1) = iwan+r0_001

!?????????????????????????????????????????????????????????????????????????
!??????rewrite/remove code related to surface file, because in wrf mode???
!?????????there is no surface file (see comment and temporary fix below)??
!?????????????????????????????????????????????????????????????????????????

!    Check for consistency of times from surface guess files.
     iwan=izero
     do i=0,99
        write(filename,200)i
200     format('sfcf',i2.2)
        inquire(file=filename,exist=fexist)
        if(fexist)then
           hourg4=zero_single !???????need to think about how wrf restart files define time.
                              !   ???? there appears to be no initial hour/forecast hour, only 
                              !   ???? the valid time of the file.
           idateg(4)=iadate(1); idateg(2)=iadate(2)
           idateg(3)=iadate(3); idateg(1)=iadate(4)
           hourg = hourg4
           idate5(1)=idateg(4); idate5(2)=idateg(2)
           idate5(3)=idateg(3); idate5(4)=idateg(1); idate5(5)=izero
           call w3fs21(idate5,nmings)
           nming2=nmings+60*hourg
           write(6,*)'READ_wrf_mass_FILES:  surface guess file, nming2 ',hourg,idateg,nming2
           ndiff=nming2-nminanl
           if(abs(ndiff) > 60*nhr_half ) go to 210
           iwan=iwan+ione
           time_ges(iwan,2) = (nming2-nminanl)*r60inv
           time_ges(iwan+100_i_kind,2)=i+r0_001
        end if
210     continue
        if(iwan==ione) exit
     end do
     time_ges(201,2)=one
     time_ges(202,2)=one
     if(iwan > ione)then
        do i=1,iwan
           do j=i+ione,iwan 
              if(time_ges(j,2) < time_ges(i,2))then
                 temp=time_ges(i+100_i_kind,2)
                 time_ges(i+100_i_kind,2)=time_ges(j+100_i_kind,2)
                 time_ges(j+100_i_kind,2)=temp
                 temp=time_ges(i,2)
                 time_ges(i,2)=time_ges(j,2)
                 time_ges(j,2)=temp
              end if
           end do
           if(time_ges(i,2) < r0_001)time_ges(202,2) = i
        end do
     end if
     time_ges(201,2) = iwan+r0_001
  end if

! Broadcast guess file information to all tasks
  call mpi_bcast(time_ges,404_i_kind,mpi_rtype,npem1,mpi_comm_world,ierror)

  nfldsig   = nint(time_ges(201,1))
!!nfldsfc   = nint(time_ges(201,2))
  nfldsfc   = ione

! Allocate space for guess information files
  call create_gesfinfo

  do i=1,nfldsig
     ifilesig(i) = -100_i_kind
     hrdifsig(i) = zero
  end do

  do i=1,nfldsfc
     ifilesfc(i) = -100_i_kind
     hrdifsfc(i) = zero
  end do

! Load time information for sigma guess field sinfo into output arrays
  ntguessig = nint(time_ges(202,1))
  do i=1,nfldsig
     hrdifsig(i) = time_ges(i,1)
     ifilesig(i) = nint(time_ges(i+100_i_kind,1))
  end do
  if(mype == izero) write(6,*)'READ_wrf_mass_FILES:  sigma fcst files used in analysis  :  ',&
       (ifilesig(i),i=1,nfldsig),(hrdifsig(i),i=1,nfldsig),ntguessig
  
  
! Load time information for surface guess field info into output arrays
  ntguessfc = nint(time_ges(202,2))
  do i=1,nfldsfc
     hrdifsfc(i) = time_ges(i,2)
     ifilesfc(i) = nint(time_ges(i+100_i_kind,2))
  end do

! Below is a temporary fix. The wrf_mass regional mode does not have a surface
! file.  Instead the surface fields are passed through the atmospheric guess
! file.  Without a separate surface file the code above sets ntguessig and 
! nfldsig to zero.  This causes problems later in the code when arrays for
! the surface fields are allocated --> one of the array dimensions is nfldsfc
! and it will be zero.  This portion of the code should be rewritten, but until
! it is, the fix below gets around the above mentioned problem.

  ntguessfc = ntguessig
!!nfldsfc   = ione
  do i=1,nfldsfc
     hrdifsfc(i) = hrdifsig(ntguessig)
     ifilesfc(i) = ifilesig(ntguessig)
  end do
  if(mype == izero) write(6,*)'READ_wrf_mass_FILES:  surface fcst files used in analysis:  ',&
       (ifilesfc(i),i=1,nfldsfc),(hrdifsfc(i),i=1,nfldsfc),ntguessfc
  

! End of routine
  return
end subroutine read_wrf_mass_files
