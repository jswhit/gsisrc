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
!   2009-08-26  li      - add variables to handle nst guess files
!   2010-04-20  jing    - set hrdifsig_all and hrdifsfc_all for non-ESMF cases.
!   2010-12-06  hcHuang - make use of nemsio_module to check whether atm and sfc files
!                         are in NEMSIO format and get header informaion 'lpl'
!   2010-12-16  li      - (1) set nfldnst, ntguesnst, ifilenst, hrdifnst, hrdifnst_all for nst files. 
!                         (2) add zero initialization of nfldsfc
!
!   input argument list:
!     mype     - mpi task id
!
!   output argument list:
!
!   comments:
!     The difference of time Info between operational GFS IO (gfshead%, sfc_head%),
!      analysis time (iadate), and NEMSIO (idate=)
!
!       gfshead & sfc_head            NEMSIO Header           Analysis time (obsmod)
!       ===================   ============================  ==========================
!         %idate(1)  Hour     idate(1)  Year                iadate(1)  Year
!         %idate(2)  Month    idate(2)  Month               iadate(2)  Month
!         %idate(3)  Day      idate(3)  Day                 iadate(3)  Day
!         %idate(4)  Year     idate(4)  Hour                iadate(4)  Hour
!                             idate(5)  Minute              iadate(5)  Minute
!                             idate(6)  Scaled seconds
!                             idate(7)  Seconds multiplier
!
!     The difference of header forecasting hour Info bewteen operational GFS IO
!      (gfshead%, sfc_head%) and NEMSIO
!
!           gfshead & sfc_head                NEMSIO Header
!       ==========================     ============================
!       %fhour  FCST Hour (r_kind)     nfhour     FCST Hour (i_kind)
!                                      nfminute   FCST Mins (i_kind)
!                                      nfsecondn  FCST Secs (i_kind) numerator
!                                      nfsecondd  FCST Secs (i_kind) denominator
!
!       %fhour = float(nfhour) + float(nfminute)/r60 + float(nfsecondn)/float(nfsecondd)/r3600

! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,r_single,i_kind
  use mpimod, only: mpi_rtype,mpi_comm_world,ierror,npe,mpi_itype
  use guess_grids, only: nfldsig,nfldsfc,nfldnst,ntguessig,ntguessfc,ntguesnst,&
       ifilesig,ifilesfc,ifilenst,hrdifsig,hrdifsfc,hrdifnst,create_gesfinfo
  use guess_grids, only: hrdifsig_all,hrdifsfc_all,hrdifnst_all
  use gsi_4dvar, only: l4dvar, iwinbgn, winlen, nhr_assimilation
  use gridmod, only: ncep_sigio,nlat_sfc,nlon_sfc,lpl_gfs,dx_gfs, use_gfs_nemsio
  use constants, only: zero,r60inv,r60,r3600
  use obsmod, only: iadate
  use radinfo, only: nst_gsi
  use sfcio_module, only: sfcio_head,sfcio_sropen,&
       sfcio_sclose,sfcio_srhead
  use nstio_module, only: nstio_head,nstio_sropen,&
       nstio_srclose,nstio_srhead
  use sigio_module, only: sigio_head,sigio_sropen,&
       sigio_sclose,sigio_srhead
  use gfsio_module, only: gfsio_gfile,gfsio_open,&
       gfsio_getfilehead,gfsio_close
  use nemsio_module, only:  nemsio_init,nemsio_open,nemsio_close
  use nemsio_module, only:  nemsio_gfile,nemsio_getfilehead,nemsio_getheadvar
  
  implicit none

! Declare passed variables
  integer(i_kind),intent(in   ) :: mype

! Declare local parameters
  integer(i_kind),parameter:: lunsfc=11
  integer(i_kind),parameter:: lunatm=12
  integer(i_kind),parameter:: lunnst=13
  integer(i_kind),parameter:: num_lpl=2000
  real(r_kind),parameter:: r0_001=0.001_r_kind

! Declare local variables
  logical(4) fexist
  character(6) filename
  integer(i_kind) i,j,iwan,npem1,iret
  integer(i_kind) nhr_half
  integer(i_kind) iamana(3)
  integer(i_kind) nminanl,nmings,nming2,ndiff
  integer(i_kind),dimension(4):: idateg
  integer(i_kind),dimension(2):: i_ges
  integer(i_kind),dimension(5):: idate5
  integer(i_kind),dimension(num_lpl):: lpl_dum
  integer(i_kind),dimension(7):: idate
  integer(i_kind) :: nfhour, nfminute, nfsecondn, nfsecondd
  real(r_single) hourg4
  real(r_kind) hourg,t4dv
  real(r_kind),allocatable,dimension(:,:):: time_atm
  real(r_kind),allocatable,dimension(:,:):: time_sfc
  real(r_kind),allocatable,dimension(:,:):: time_nst

  type(sfcio_head):: sfc_head
  type(sigio_head):: sigatm_head
  type(nstio_head):: nst_head
  type(gfsio_gfile) :: gfile
  type(nemsio_gfile) :: gfile_atm,gfile_sfc,gfile_nst


!-----------------------------------------------------------------------------
! Initialize variables
  nhr_half=nhr_assimilation/2
  if(nhr_half*2 < nhr_assimilation) nhr_half=nhr_half+1
  npem1=npe-1

  fexist=.true.
  nfldsig=0
  nfldsfc=0
  nfldnst=0
  do i=0,99
     write(filename,'(a,i2.2)')'sigf',i
     inquire(file=filename,exist=fexist)
     if(fexist) nfldsig=nfldsig+1
     write(filename,'(a,i2.2)')'sfcf',i
     inquire(file=filename,exist=fexist)
     if(fexist) nfldsfc=nfldsfc+1
     write(filename,'(a,i2.2)')'nstf',i
     inquire(file=filename,exist=fexist)
     if(fexist) nfldnst=nfldnst+1
  enddo
  if(nfldsig==0) then
     write(6,*)'0 atm fields; aborting'
     call stop2(169)
  end if
  if(nfldsfc==0) then
     write(6,*)'0 sfc fields; aborting'
     call stop2(170)
  end if
  if(nfldnst==0 .and. nst_gsi > 0) then
    write(6,*)'0 nst fields; aborting'
    call stop2(170)
  end if
  allocate(time_atm(nfldsig,2),time_sfc(nfldsfc,2),time_nst(nfldnst,2))

! Let a single task query the guess files.
  if(mype==npem1) then

!    Convert analysis time to minutes relative to fixed date
     call w3fs21(iadate,nminanl)
     write(6,*)'READ_FILES:  analysis date,minutes ',iadate,nminanl

!    Check for consistency of times from atmospheric guess files.
     iwan=0
     do i=0,99
        write(filename,100)i
100     format('sigf',i2.2)
        inquire(file=filename,exist=fexist)
        if(fexist)then
           if ( .not. use_gfs_nemsio ) then
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
           else
              call nemsio_init(iret=iret)
              call nemsio_open(gfile_atm,filename,'READ',iret=iret)
              call nemsio_getfilehead(gfile_atm, nfhour=nfhour, nfminute=nfminute, &
                 nfsecondn=nfsecondn, nfsecondd=nfsecondd, idate=idate, iret=iret)
              call nemsio_close(gfile_atm,iret=iret)
              hourg4 = float(nfhour) + float(nfminute)/r60 + float(nfsecondn)/float(nfsecondd)/r3600
              idateg(1) = idate(4)  !hour
              idateg(2) = idate(2)  !month
              idateg(3) = idate(3)  !day
              idateg(4) = idate(1)  !year
           endif

           hourg = hourg4
           idate5(1)=idateg(4); idate5(2)=idateg(2)
           idate5(3)=idateg(3); idate5(4)=idateg(1); idate5(5)=0
           call w3fs21(idate5,nmings)
           nming2=nmings+60*hourg
           write(6,*)'READ_FILES:  atm guess file, nming2 ',hourg,idateg,nming2
           t4dv=real((nming2-iwinbgn),r_kind)*r60inv
           if (l4dvar) then
              if (t4dv<zero .OR. t4dv>winlen) cycle
           else
              ndiff=nming2-nminanl
              if(abs(ndiff) > 60*nhr_half ) cycle
           endif
           iwan=iwan+1
           if(nminanl==nming2) iamana(1)=iwan
           time_atm(iwan,1) = t4dv
           time_atm(iwan,2) = i+r0_001
        end if
     end do

!    Check for consistency of times from surface guess files.
     iwan=0
     do i=0,99
        write(filename,200)i
200     format('sfcf',i2.2)
        inquire(file=filename,exist=fexist)
        if(fexist)then
           if ( .not. use_gfs_nemsio ) then
              call sfcio_sropen(lunsfc,filename,iret)
              call sfcio_srhead(lunsfc,sfc_head,iret)
              hourg4=sfc_head%fhour
              idateg=sfc_head%idate
              i_ges(1)=sfc_head%lonb
              i_ges(2)=sfc_head%latb+2
              if(sfc_head%latb/2>num_lpl)then
                 write(6,*)'READ_FILES: increase dimension of variable lpl_dum'
                 call stop2(80)
              endif
              lpl_dum=0
              lpl_dum(1:sfc_head%latb/2)=sfc_head%lpl
              call sfcio_sclose(lunsfc,iret)
              write(6,*)' READ_FILES: in sfcio sfc_head%lpl = ', sfc_head%lpl
           else
              call nemsio_init(iret=iret)
              call nemsio_open(gfile_sfc,filename,'READ',iret=iret)
              call nemsio_getfilehead(gfile_sfc, nfhour=nfhour, nfminute=nfminute,  &
                 nfsecondn=nfsecondn, nfsecondd=nfsecondd, idate=idate, &
                 dimx=sfc_head%lonb, dimy=sfc_head%latb, iret=iret)
              hourg4   = float(nfhour) + float(nfminute)/r60 + float(nfsecondn)/float(nfsecondd)/r3600
              idateg(1) = idate(4)  !hour
              idateg(2) = idate(2)  !month
              idateg(3) = idate(3)  !day
              idateg(4) = idate(1)  !year
              i_ges(1)=sfc_head%lonb
              i_ges(2)=sfc_head%latb+2
              if((sfc_head%latb+1)/2>num_lpl)then
                 write(6,*)'READ_FILES: increase dimension of variable lpl_dum'
                 call stop2(80)
              endif
              if ( (sfc_head%latb+1)/2 /= sfc_head%latb/2 ) then
                 write(6,*) 'READ_FILES: ****WARNING**** (sfc_head%latb+1)/2 = ', &
                    (sfc_head%latb+1)/2, 'sfc_head%latb/2 = ', sfc_head%latb/2
              end if
              if (allocated(sfc_head%lpl)) deallocate(sfc_head%lpl)
              allocate(sfc_head%lpl((sfc_head%latb+1)/2))
              call nemsio_getheadvar(gfile_sfc,'lpl',sfc_head%lpl,iret=iret)
              if ( iret /= 0 ) then
                write(6,*)' READ_FILES: ****ERROR**** reading sfc_head%lpl, iret = ', iret
                call nemsio_close(gfile_sfc,iret=iret)
                call stop2(80)
              end if
              call nemsio_close(gfile_sfc,iret=iret)
              lpl_dum=0
              lpl_dum(1:sfc_head%latb/2)=sfc_head%lpl
              deallocate(sfc_head%lpl)
           endif
           hourg = hourg4
           idate5(1)=idateg(4); idate5(2)=idateg(2)
           idate5(3)=idateg(3); idate5(4)=idateg(1); idate5(5)=0
           call w3fs21(idate5,nmings)
           nming2=nmings+60*hourg
           write(6,*)'READ_FILES:  sfc guess file, nming2 ',hourg,idateg,nming2
           t4dv=real((nming2-iwinbgn),r_kind)*r60inv
           if (l4dvar) then
              if (t4dv<zero .OR. t4dv>winlen) cycle
           else
              ndiff=nming2-nminanl
              if(abs(ndiff) > 60*nhr_half ) cycle
           endif
           iwan=iwan+1
           if(nminanl==nming2) iamana(2)=iwan
           time_sfc(iwan,1) = t4dv
           time_sfc(iwan,2) = i+r0_001
        end if
     end do

!    Check for consistency of times from nst guess files.
     if ( nst_gsi > 0 ) then
     iwan=0
     do i=0,99
        write(filename,300)i
300     format('nstf',i2.2)
        inquire(file=filename,exist=fexist)
        if(fexist)then
           if ( .not. use_gfs_nemsio ) then
              call nstio_sropen(lunnst,filename,iret)
              call nstio_srhead(lunnst,nst_head,iret)
              hourg4=nst_head%fhour
              idateg=nst_head%idate
              i_ges(1)=nst_head%lonb
              i_ges(2)=nst_head%latb+2
              if(nst_head%latb/2>num_lpl)then
                 write(6,*)'READ_FILES: increase dimension of variable lpl_dum'
                 call stop2(80)
              endif
              lpl_dum=0
              lpl_dum(1:nst_head%latb/2)=nst_head%lpl
              call nstio_srclose(lunnst,iret)
              write(6,*)' READ_FILES: in nstio nst_head%lpl = ', nst_head%lpl
           else
              call nemsio_init(iret=iret)
              call nemsio_open(gfile_nst,filename,'READ',iret=iret)
              call nemsio_getfilehead(gfile_nst, nfhour=nfhour, nfminute=nfminute,  &
                 nfsecondn=nfsecondn, nfsecondd=nfsecondd, idate=idate, &
                 dimx=nst_head%lonb, dimy=nst_head%latb, iret=iret)
              hourg4   = float(nfhour) + float(nfminute)/r60 + float(nfsecondn)/float(nfsecondd)/r3600
              idateg(1) = idate(4)  !hour
              idateg(2) = idate(2)  !month
              idateg(3) = idate(3)  !day
              idateg(4) = idate(1)  !year
              i_ges(1)=nst_head%lonb
              i_ges(2)=nst_head%latb+2
              if((nst_head%latb+1)/2>num_lpl)then
                 write(6,*)'READ_FILES: increase dimension of variable lpl_dum'
                 call stop2(80)
              endif
              if ( (nst_head%latb+1)/2 /= nst_head%latb/2 ) then
                 write(6,*) 'READ_FILES: ****WARNING**** (nst_head%latb+1)/2 = ', &
                    (nst_head%latb+1)/2, 'nst_head%latb/2 = ', nst_head%latb/2
              end if
              if (allocated(nst_head%lpl)) deallocate(nst_head%lpl)
              allocate(nst_head%lpl((nst_head%latb+1)/2))
              call nemsio_getheadvar(gfile_nst,'lpl',nst_head%lpl,iret=iret)
              if ( iret /= 0 ) then
                write(6,*)' READ_FILES: ****ERROR**** reading nst_head%lpl, iret = ', iret
                call nemsio_close(gfile_nst,iret=iret)
                call stop2(80)
              end if
              call nemsio_close(gfile_nst,iret=iret)
              lpl_dum=0
              lpl_dum(1:nst_head%latb/2)=nst_head%lpl
              deallocate(nst_head%lpl)
           endif
           hourg = hourg4
           idate5(1)=idateg(4); idate5(2)=idateg(2)
           idate5(3)=idateg(3); idate5(4)=idateg(1); idate5(5)=0
           call w3fs21(idate5,nmings)
           nming2=nmings+60*hourg
           write(6,*)'READ_FILES:  nst guess file, nming2 ',hourg,idateg,nming2
           t4dv=real((nming2-iwinbgn),r_kind)*r60inv
           if (l4dvar) then
              if (t4dv<zero .OR. t4dv>winlen) cycle
           else
              ndiff=nming2-nminanl
              if(abs(ndiff) > 60*nhr_half ) cycle
           endif
           iwan=iwan+1
           if(nminanl==nming2) iamana(3)=iwan
           time_nst(iwan,1) = t4dv
           time_nst(iwan,2) = i+r0_001
        end if
     end do
     endif                          ! if ( nst_gsi > 0 ) then
  end if


! Broadcast guess file information to all tasks
  call mpi_bcast(time_atm,2*nfldsig,mpi_rtype,npem1,mpi_comm_world,ierror)
  call mpi_bcast(time_sfc,2*nfldsfc,mpi_rtype,npem1,mpi_comm_world,ierror)
  call mpi_bcast(time_nst,2*nfldnst,mpi_rtype,npem1,mpi_comm_world,ierror)
  call mpi_bcast(iamana,3,mpi_rtype,npem1,mpi_comm_world,ierror)
  call mpi_bcast(i_ges,2,mpi_itype,npem1,mpi_comm_world,ierror)
  nlon_sfc=i_ges(1)
  nlat_sfc=i_ges(2)
  call mpi_bcast(lpl_dum,num_lpl,mpi_itype,npem1,mpi_comm_world,ierror)
  allocate(lpl_gfs(nlat_sfc/2))
  allocate(dx_gfs(nlat_sfc/2))
  lpl_gfs(1)=1  ! singularity at pole
  dx_gfs(1) = 360._r_kind / lpl_gfs(1)
  do j=2,nlat_sfc/2
     lpl_gfs(j)=lpl_dum(j-1)
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
  if(mype == 0) write(6,*)'READ_FILES:  atm fcst files used in analysis  :  ',&
       (ifilesig(i),i=1,nfldsig),(hrdifsig(i),i=1,nfldsig),ntguessig
  

! Load time information for surface guess field info into output arrays
  ntguessfc = iamana(2)
  do i=1,nfldsfc
     hrdifsfc(i) = time_sfc(i,1)
     ifilesfc(i) = nint(time_sfc(i,2))
     hrdifsfc_all(i) = hrdifsfc(i)
  end do
  if(mype == 0) write(6,*)'READ_FILES:  sfc fcst files used in analysis:  ',&
       (ifilesfc(i),i=1,nfldsfc),(hrdifsfc(i),i=1,nfldsfc),ntguessfc
  
! Load time information for nst guess field info into output arrays
  ntguesnst = iamana(3)
  if ( nst_gsi > 0 ) then
    do i=1,nfldnst
       hrdifnst(i) = time_nst(i,1)
       ifilenst(i) = nint(time_nst(i,2))
       hrdifnst_all(i) = hrdifnst(i)
    end do
    if(mype == 0) write(6,*)'READ_FILES:  nst fcst files used in analysis:  ',&
         (ifilenst(i),i=1,nfldnst),(hrdifnst(i),i=1,nfldnst),ntguesnst
  endif

  if ( nst_gsi > 0 ) then
    deallocate(time_atm,time_sfc,time_nst)
  else
    deallocate(time_atm,time_sfc)
  endif

! End of routine
  return
end subroutine read_files
