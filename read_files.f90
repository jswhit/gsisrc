subroutine read_files(mype)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    read_files       get info about atm & sfc guess files
!   prgmmr: derber           org: np23                date: 2002-11-14
!
! abstract:  This routine determines how many global atmospheric and
!            surface guess files are present.  The valid time for each
!            guess file is determine.  The time are then sorted in
!            ascending order.  This information is broadcast to all
!            mpi tasks.
!
! program history log:
!   2002-11-14  derber
!   2004-06-16  treadon - update documentation
!   2004-08-02  treadon - add only to module use, add intent in/out
!   2004-12-02  treadon - replace mpe_ibcast (IBM extension) with
!                         standard mpi_bcast
!   2005-01-27  treadon - make use of sfcio module
!   2005-02-18  todling - no need to read entire sfc file; only head needed
!   2005-03-30  treadon - clean up formatting of write statements
!   2006-01-09  treadon - use sigio to read gfs spectral coefficient file header
!   2007-05-08  treadon - add gfsio interface
!   2007-03-01  tremolet - measure time from beginning of assimilation window
!   2007-04-17  todling  - getting nhr_assimilation from gsi_4dvar
!   2008-05-27  safford - rm unused vars
!   2009-01-07  todling - considerable revamp (no pre-assigned dims)
!   2010-04-20  jing    - set hrdifsig_all and hrdifsfc_all for non-ESMF cases.
!
!   input argument list:
!     mype     - mpi task id
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,r_single,i_kind
  use mpimod, only: mpi_rtype,mpi_comm_world,ierror,npe,mpi_itype
  use guess_grids, only: nfldsig,nfldsfc,ntguessig,ntguessfc,&
       ifilesig,ifilesfc,hrdifsig,hrdifsfc,create_gesfinfo
  use guess_grids, only: hrdifsig_all,hrdifsfc_all
  use gsi_4dvar, only: l4dvar, iwinbgn, winlen, nhr_assimilation
  use gridmod, only: ncep_sigio,nlat_sfc,nlon_sfc,lpl_gfs,dx_gfs
  use constants, only: izero,ione,zero,r60inv
  use obsmod, only: iadate
  use sfcio_module, only: sfcio_head,sfcio_sropen,&
       sfcio_sclose,sfcio_srhead
  use sigio_module, only: sigio_head,sigio_sropen,&
       sigio_sclose,sigio_srhead
  use gfsio_module, only: gfsio_gfile,gfsio_open,&
       gfsio_getfilehead,gfsio_close
  
  implicit none

! Declare passed variables
  integer(i_kind),intent(in   ) :: mype

! Declare local parameters
  integer(i_kind),parameter:: lunsfc=11_i_kind
  integer(i_kind),parameter:: lunatm=12_i_kind
  integer(i_kind),parameter:: num_lpl=2000_i_kind
  real(r_kind),parameter:: r0_001=0.001_r_kind

! Declare local variables
  logical(4) fexist
  character(6) filename
  integer(i_kind) i,j,iwan,npem1,iret
  integer(i_kind) nhr_half
  integer(i_kind) iamana(2)
  integer(i_kind) nminanl,nmings,nming2,ndiff
  integer(i_kind),dimension(4):: idateg
  integer(i_kind),dimension(2):: i_ges
  integer(i_kind),dimension(5):: idate5
  integer(i_kind),dimension(num_lpl):: lpl_dum
  real(r_single) hourg4
  real(r_kind) hourg,t4dv
  real(r_kind),allocatable,dimension(:,:):: time_atm
  real(r_kind),allocatable,dimension(:,:):: time_sfc

  type(sfcio_head):: sfc_head
  type(sigio_head):: sigatm_head
  type(gfsio_gfile) :: gfile


!-----------------------------------------------------------------------------
! Initialize variables
  nhr_half=nhr_assimilation/2
  if(nhr_half*2 < nhr_assimilation) nhr_half=nhr_half+ione
  npem1=npe-ione

  fexist=.true.
  nfldsig=izero
  do i=0,99
     write(filename,'(a,i2.2)')'sigf',i
     inquire(file=filename,exist=fexist)
     if(fexist) nfldsig=nfldsig+ione
     write(filename,'(a,i2.2)')'sfcf',i
     inquire(file=filename,exist=fexist)
     if(fexist) nfldsfc=nfldsfc+ione
  enddo
  if(nfldsig==izero) then
     write(6,*)'0 atm fields; aborting'
     call stop2(169)
  end if
  if(nfldsfc==izero) then
     write(6,*)'0 sfc fields; aborting'
     call stop2(170)
  end if
  allocate(time_atm(nfldsig,2),time_sfc(nfldsfc,2))

! Let a single task query the guess files.
  if(mype==npem1) then

!    Convert analysis time to minutes relative to fixed date
     call w3fs21(iadate,nminanl)
     write(6,*)'READ_FILES:  analysis date,minutes ',iadate,nminanl

!    Check for consistency of times from atmospheric guess files.
     iwan=izero
     do i=0,99
        write(filename,100)i
100     format('sigf',i2.2)
        inquire(file=filename,exist=fexist)
        if(fexist)then
           if (ncep_sigio) then
              call sigio_sropen(lunatm,filename,iret)
              call sigio_srhead(lunatm,sigatm_head,iret)
              hourg4=sigatm_head%fhour
              idateg=sigatm_head%idate
              call sigio_sclose(lunatm,iret)
           else
              call gfsio_open(gfile,trim(filename),'read',iret)
              call gfsio_getfilehead(gfile,iret=iret,&
                   fhour=hourg4, &
                   idate=idateg)
              call gfsio_close(gfile,iret)
           endif

           hourg = hourg4
           idate5(1)=idateg(4); idate5(2)=idateg(2)
           idate5(3)=idateg(3); idate5(4)=idateg(1); idate5(5)=izero
           call w3fs21(idate5,nmings)
           nming2=nmings+60*hourg
           write(6,*)'READ_FILES:  atm guess file, nming2 ',hourg,idateg,nming2
           t4dv=real((nming2-iwinbgn),r_kind)*r60inv
           if (l4dvar) then
              if (t4dv<zero .OR. t4dv>winlen) go to 110
           else
              ndiff=nming2-nminanl
              if(abs(ndiff) > 60*nhr_half ) go to 110
           endif
           iwan=iwan+ione
           if(nminanl==nming2) iamana(1)=iwan
           time_atm(iwan,1) = t4dv
           time_atm(iwan,2) = i+r0_001
        end if
110     continue
     end do

!    Check for consistency of times from surface guess files.
     iwan=izero
     do i=0,99
        write(filename,200)i
200     format('sfcf',i2.2)
        inquire(file=filename,exist=fexist)
        if(fexist)then
           call sfcio_sropen(lunsfc,filename,iret)
           call sfcio_srhead(lunsfc,sfc_head,iret)
           hourg4=sfc_head%fhour
           idateg=sfc_head%idate
           i_ges(1)=sfc_head%lonb
           i_ges(2)=sfc_head%latb+2_i_kind
           if(sfc_head%latb/2>num_lpl)then
              write(6,*)'READ_FILES: increase dimension of variable lpl_dum'
              call stop2(80)
           endif
           lpl_dum=izero
           lpl_dum(1:sfc_head%latb/2)=sfc_head%lpl
           call sfcio_sclose(lunsfc,iret)
           hourg = hourg4
           idate5(1)=idateg(4); idate5(2)=idateg(2)
           idate5(3)=idateg(3); idate5(4)=idateg(1); idate5(5)=izero
           call w3fs21(idate5,nmings)
           nming2=nmings+60*hourg
           write(6,*)'READ_FILES:  sfc guess file, nming2 ',hourg,idateg,nming2
           t4dv=real((nming2-iwinbgn),r_kind)*r60inv
           if (l4dvar) then
              if (t4dv<zero .OR. t4dv>winlen) go to 210
           else
              ndiff=nming2-nminanl
              if(abs(ndiff) > 60*nhr_half ) go to 210
           endif
           iwan=iwan+ione
           if(nminanl==nming2) iamana(2)=iwan
           time_sfc(iwan,1) = t4dv
           time_sfc(iwan,2) = i+r0_001
        end if
210     continue
     end do

  end if


! Broadcast guess file information to all tasks
  call mpi_bcast(time_atm,2*nfldsig,mpi_rtype,npem1,mpi_comm_world,ierror)
  call mpi_bcast(time_sfc,2*nfldsfc,mpi_rtype,npem1,mpi_comm_world,ierror)
  call mpi_bcast(iamana,2_i_kind,mpi_rtype,npem1,mpi_comm_world,ierror)
  call mpi_bcast(i_ges,2_i_kind,mpi_itype,npem1,mpi_comm_world,ierror)
  nlon_sfc=i_ges(1)
  nlat_sfc=i_ges(2)
  call mpi_bcast(lpl_dum,num_lpl,mpi_itype,npem1,mpi_comm_world,ierror)
  allocate(lpl_gfs(nlat_sfc/2))
  allocate(dx_gfs(nlat_sfc/2))
  lpl_gfs(1)=ione  ! singularity at pole
  dx_gfs(1) = 360._r_kind / lpl_gfs(1)
  do j=2,nlat_sfc/2
     lpl_gfs(j)=lpl_dum(j-ione)
     dx_gfs(j) = 360._r_kind / lpl_gfs(j)
  enddo


! Allocate space for guess information files
  call create_gesfinfo

! Load time information for atm guess field sinfo into output arrays
  ntguessig = iamana(1)
  do i=1,nfldsig
     hrdifsig(i) = time_atm(i,1)
     ifilesig(i) = nint(time_atm(i,2))
     hrdifsig_all(i) = hrdifsig(i)
  end do
  if(mype == izero) write(6,*)'READ_FILES:  atm fcst files used in analysis  :  ',&
       (ifilesig(i),i=1,nfldsig),(hrdifsig(i),i=1,nfldsig),ntguessig
  

! Load time information for surface guess field info into output arrays
  ntguessfc = iamana(2)
  do i=1,nfldsfc
     hrdifsfc(i) = time_sfc(i,1)
     ifilesfc(i) = nint(time_sfc(i,2))
     hrdifsfc_all(i) = hrdifsfc(i)
  end do
  if(mype == izero) write(6,*)'READ_FILES:  sfc fcst files used in analysis:  ',&
       (ifilesfc(i),i=1,nfldsfc),(hrdifsfc(i),i=1,nfldsfc),ntguessfc
  
  deallocate(time_atm,time_sfc)

! End of routine
  return
end subroutine read_files
