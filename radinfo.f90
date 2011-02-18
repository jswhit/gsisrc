module radinfo 
!$$$   module documentation block
!                .      .    .                                       .
! module:    radinfo   
!
! abstract:  This module contains variables and routines related
!            to information for the use of satellite radiance data.
!
! program history log:
!   1995-07-06  derber
!   2004-05-13  kleist, documentation
!   2004-06-22  treadon - update documentation
!   2004-07-15  todling - protex-compliant prologue
!   2004-11-23  treadon - change 110 format statement
!   2004-11-30  xu li   - add array fbias for AVHRR bias correction
!   2004-12-08  xu li   - add logical flag retrieval to module
!   2004-12-22  treadon - rename logical "idiag_rad" as "diag_rad"
!   2005-02-03  xu li   - add SST analysis read and move sub intgrid2 from sst_retrieval to this module
!   2005-03-25  xu li   - modify sub rdgrbsst and remove intgrid2
!   2005-04-18  treadon - make rdgrbsst a separate subroutine
!   2005-09-28  derber  - change radinfo input file add ermax_rad,b_rad and pg_rad
!   2006-02-03  derber  - modify for new obs control and obs count
!   2006-04-27  derber  - remove jppf
!   2008-04-23  safford - add standard documentation block
!   2010-04-29  zhu     - add analysis varaince info for radiance bias correction coefficients
!   2010-05-06  zhu     - add option adp_anglebc for variational radiance angle bias correction 
!   2010-05-12  zhu     - add option passive_bc for radiance bias correction for monitored channels
!   2010-07-12  zhu     - add inew_rad
!   2010-10-05  treadon - remove npred1 (not used)
!   2010-10-12  zhu     - combine scaninfo and edgeinfo into one file scaninfo
!   2011-01-04  zhu     - add tlapmean update for new/existing channels when adp_anglebc is turned on
!
! subroutines included:
!   sub init_rad            - set satellite related variables to defaults
!   sub init_rad_vars       - initialize satellite related variables
!   sub radinfo_read        - read in sat info and biases, including read 
!                             sst_an and avhrr bias correction
!   sub radinfo_write       - write out satellite biases
!
! functions included:
!   fun newchn
!
! variable definitions:
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP; SGI Origin 2000; Compaq/HP
!
!$$$ end documentation block


! !USES:

  use kinds, only: r_kind,i_kind,r_quad
  implicit none

! set default to private
  private
! set subroutines to public
  public :: init_rad
  public :: init_rad_vars
  public :: radinfo_read
  public :: radinfo_write
  public :: angle_cbias
  public :: find_edges
! set passed variables to public
  public :: jpch_rad,npred,b_rad,pg_rad,diag_rad,iuse_rad,nusis,inew_rad
  public :: crtm_coeffs_path,retrieval,predx,ang_rad,newchn,cbias
  public :: air_rad,nuchan,numt,varch,fbias,ermax_rad,tlapmean
  public :: ifactq,mype_rad
  public :: ostats,rstats,varA
  public :: adp_anglebc,angord,use_edges
  public :: passive_bc
  public :: radstart,radstep

  integer(i_kind),parameter:: numt = 33   ! size of AVHRR bias correction file
  integer(i_kind),parameter:: ntlapthresh = 100 ! threshhold value of cycles if tlapmean update is needed

  logical diag_rad    ! logical to turn off or on the diagnostic radiance file (true=on)
  logical retrieval   ! logical to turn off or on the SST retrieval with AVHRR data
  logical adp_anglebc ! logical to turn off or on the variational radiance angle bias correction
  logical passive_bc  ! logical to turn off or on radiance bias correction for monitored channels
  logical use_edges   ! logical to use data on scan edges (.true.=to use)

  integer(i_kind) jpch_rad      ! number of channels*sat
  integer(i_kind) npred         ! number of radiance biases predictors
  integer(i_kind) mype_rad      ! task id for writing out radiance diagnostics
  integer(i_kind) angord        ! order of polynomial for angle bias correction

  real(r_kind),allocatable,dimension(:):: varch       ! variance for each satellite channel
  real(r_kind),allocatable,dimension(:):: ermax_rad   ! error maximum (qc)
  real(r_kind),allocatable,dimension(:):: b_rad       ! variational b value
  real(r_kind),allocatable,dimension(:):: pg_rad      ! variational pg value
  real(r_kind),allocatable,dimension(:):: tlapmean    ! mean lapse rate (fixed from input file)
  real(r_kind),allocatable,dimension(:):: tsum_tlapmean  ! err sum of mean lapse rate 
  real(r_kind),allocatable,dimension(:):: ang_rad     ! 0 or 1 depending on iuse_rad (1 - use angle bias correction)
  real(r_kind),allocatable,dimension(:):: air_rad     ! 0 or 1 depending on iuse_rad (1 - use air mass bias correction)          
  real(r_kind),allocatable,dimension(:,:):: fbias     ! bias for AVHRR siumulated radiance
  real(r_kind),allocatable,dimension(:,:):: cbias     ! angle dependent bias for satellite channels
  real(r_kind),allocatable,dimension(:,:):: predx     ! coefficients for predictor part of bias correction

  real(r_kind),allocatable,dimension(:,:):: varA
  real(r_kind),allocatable,dimension(:):: ostats
  real(r_quad),allocatable,dimension(:,:):: rstats

  real(r_kind),allocatable,dimension(:):: radstart    ! starting scan angle
  real(r_kind),allocatable,dimension(:):: radstep     ! step of scan angle
  real(r_kind),allocatable,dimension(:):: radnstep    ! nstep of scan angle

  integer(i_kind),allocatable,dimension(:):: radedge1    ! cut-off of edge removal
  integer(i_kind),allocatable,dimension(:):: radedge2    ! cut-off of edge removal

  integer(i_kind),allocatable,dimension(:):: count_tlapmean ! the count of tlapmean update 

  integer(i_kind),allocatable,dimension(:):: nuchan    ! satellite channel
  integer(i_kind),allocatable,dimension(:):: iuse_rad  ! use to turn off satellite radiance data
!                                                    = -2 do not use
!                                                    = -1 monitor if diagnostics produced
!                                                    =  0 monitor and use in QC only
!                                                    =  1 use data with complete quality control
!                                                    =  2 use data with no airmass bias correction
!                                                    =  3 use data with no angle dependent bias correction
!                                                    =  4 use data with no bias correction


  logical,allocatable,dimension(:):: inew_rad  ! indicator if it needs initialized for satellite radiance data
  logical,allocatable,dimension(:):: update_tlapmean ! indicator if tlapmean update is needed

  integer(i_kind),allocatable,dimension(:):: ifactq    ! scaling parameter for d(Tb)/dq sensitivity

  character(len=20),allocatable,dimension(:):: nusis   ! sensor/instrument/satellite indicator
  character(len=256),save:: crtm_coeffs_path = "./" ! path of CRTM_Coeffs files


contains


  subroutine init_rad
!$$$  subprogram documentation block
!                .      .    .
! subprogram:    int_rad
!
!   prgrmmr:     derber      org: np23                date: 1995-07-06
!
! abstract:  This routine sets default values for variables used in
!            the radiance processing routines.
!
! program history log:
!   1995-07-06  derber
!   2004-06-22  treadon - update documentation
!   2004-07-15  todling - protex-compliant prologue
!   2008-04-23  safford -- add standard subprogram doc block
!   2010-05-06  zhu     - add adp_anglebc and angord
!   2010-05-12  zhu     - add passive_bc
!   2010-09-02  zhu     - add use_edges
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp; SGI Origin 2000; Compaq/HP
!
!$$$ end documentation block

    implicit none

    jpch_rad = 0          ! total number of channels over all instruments & satellites
    retrieval = .false.   ! .true. = apply physical SST retrieval with AVHRR data
    diag_rad = .true.     ! .true.=generate radiance diagnostic file
    mype_rad = 0          ! mpi task to collect and print radiance use information on/from
    npred=5               ! number of bias correction predictors

    passive_bc = .false.  ! .true.=turn on bias correction for monitored channels
    adp_anglebc = .false. ! .true.=turn on angle bias correction
    angord = 0            ! order of polynomial for angle bias correction
    use_edges = .true.    ! .true.=to use data on scan edges
  end subroutine init_rad


  subroutine init_rad_vars
!$$$  subprogram documentation block
!                .      .    .
! subprogram:    init_rad_vars
!
!   prgrmmr:     derber      org: np23                date: 1995-07-06
!
! abstract:  This routine sets parameters used in the radiance 
!            assimilation.  The parameters below depend on values
!            which may be altered by the SETUP namelist.
!
! program history log:
!   1995-07-06  derber
!   2004-06-22  treadon - update documentation
!   2004-07-15  todling - protex-compliant prologue
!   2008-04-23  safford -- add standard subprogram doc block
!   2010-05-06  zhu     - add option adp_anglebc
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp; SGI Origin 2000; Compaq/HP
!
!$$$ end documentation block

    implicit none

!   safeguard angord value for option adp_anglebc
    if (adp_anglebc) then 
       if (angord==0) then 
          write(6,*)'INIT_RAD_VARS:  ***ERROR*** error value for angord, reset angord to be 4' 
          angord=4
       end if
    else
       if (angord/=0) angord=0
    end if

    if (adp_anglebc) npred=npred+angord
    
    return
  end subroutine init_rad_vars


  subroutine radinfo_read(newpc4pred)
!$$$  subprogram documentation block
!                .      .    .
! subprogram:    radinfo_read
!
!   prgrmmr:     yang        org: np20                date: 1998-05-15
!
! abstract:  This routine reads the satinfo, satbias\_angle, and
!            satbias files.  
!
!            The satinfo file contains information about the channels,
!            sensors, and satellites.  It specifies observation error
!            for the channels, how to use the channels (assimilate,
!            monitor, etc), the type of channel (ir or microwave),
!            and other useful information.  
!
!            The satbias\_angle file contains the angle dependent part
!            of the brightness temperature bias for each channel/
!            instrument/satellite.  Also included in this file is 
!            the mean temperature lapse rate for each channels 
!            weighted by the weighting function for the given channel/
!            instrument.
!
!            The satbias\_in file contains the coefficients for the
!            predictive part of the bias correction.
!
!
! program history log:
!   1998-05-15  yang, weiyu
!   1999-08-24  derber, j., treadon, r., yang, w., first frozen mpp version
!   2004-06-22  treadon - update documentation
!   2004-07-15  todling - protex-compliant prologue
!   2004-11-30  xu li- read SST dependent bias for AVHRR radiance (NOAA-16 & NOAA-17) 
!                      and SST analysis when retrieval = .true.
!   2005-02-08  xu li- read SST analysis when retrieval = .true.
!   2005-10-11  treadon - change satinfo read to free format
!   2005-11-30  li - fix a bug in the format to read avhrr SST dependent BC
!   2007-03-13  derber  - modify to allow input bias correction files of different lengths and orders
!   2007-06-29  treadon - determine/build n_sensors and sensorlist from satinfo file
!   2008-04-23  safford - add standard doc block, rm unused vars and uses
!   2010-04-29  zhu     - add analysis varaince info for radiance bias correction coefficients
!   2010-05-06  zhu     - add option adp_anglebc for variational angle bias correction
!   2011-01-04  zhu     - add tlapmean update for new channels when adp_anglebc is turned on
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp; SGI Origin 2000; Compaq/HP
!
!$$$ end documentation block

! !USES:

    use obsmod, only: iout_rad
    use constants, only: zero,one,zero_quad
    use mpimod, only: mype
    implicit none

! !INPUT PARAMETERS:


    integer(i_kind) i,j,k,ich,lunin,lunout,nlines
    integer(i_kind) ip,istat,n,ichan,mch,ij,nstep,edge1,edge2,ntlapupdate
    real(r_kind),dimension(npred):: predr
    real(r_kind) tlapm
    real(r_kind) tsum
    real(r_kind) ostatsx
    real(r_kind) start,step
    real(r_kind),dimension(90)::cbiasx
    real(r_kind),dimension(npred)::varx
    character(len=1):: cflg
    character(len=120) crecord
    character(len=20) :: isis 
    character(len=20) :: satscan_sis
    character(len=20),allocatable,dimension(:):: satsenlist
    real(r_kind),dimension(numt):: fbiasx     ! contains SST dependent bias  for SST retrieval
    logical,allocatable,dimension(:):: nfound
    logical cfound
    logical newpc4pred,pcexist

    data lunin / 49 /
    data lunout / 51 /

!============================================================================

!   Determine number of entries in satellite information file
    open(lunin,file='satinfo',form='formatted')
    j=0
    nlines=0
    read1:  do
       read(lunin,100,iostat=istat) cflg,crecord
       if (istat /= 0) exit
       nlines=nlines+1
       if (cflg == '!') cycle
       j=j+1
    end do read1
    if (istat>0) then
       close(lunin)
       write(6,*)'RADINFO_READ:  ***ERROR*** error reading radinfo, istat=',istat
       write(6,*)'RADINFO_READ:  stop program execution'
       call stop2(79)
    endif
    jpch_rad = j


!   Allocate arrays to hold radiance information
!     nuchan    - channel number
!     nusis     - sensor/instrument/satellite
!     iuse_rad  - use parameter
!     ifactq    - scaling parameter for d(Tb)/dq sensitivity
!     varch     - variance for each channel

    allocate(nuchan(jpch_rad),nusis(jpch_rad),&
         iuse_rad(0:jpch_rad),ifactq(jpch_rad),varch(jpch_rad),&
         ermax_rad(jpch_rad),b_rad(jpch_rad),pg_rad(jpch_rad), &
         ang_rad(jpch_rad),air_rad(jpch_rad),inew_rad(jpch_rad))
    allocate(satsenlist(jpch_rad),nfound(jpch_rad))
    iuse_rad(0)=-999
    inew_rad=.true.
    ifactq=0
    air_rad=one
    ang_rad=one


!   All mpi tasks open and read radiance information file.
!   Task mype_rad writes information to radiance runtime file

    if (mype==mype_rad) then
       open(iout_rad)
       write(iout_rad,*)'RADINFO_READ:  jpch_rad=',jpch_rad
    endif
    rewind(lunin)
    j=0
    do k=1,nlines
       read(lunin,100) cflg,crecord
       if (cflg == '!') cycle
       j=j+1
       read(crecord,*) nusis(j),nuchan(j),iuse_rad(j),&
            varch(j),ermax_rad(j),b_rad(j),pg_rad(j)
       if(iuse_rad(j) == 4 .or. iuse_rad(j) == 2)air_rad(j)=zero
       if(iuse_rad(j) == 4 .or. iuse_rad(j) == 3)ang_rad(j)=zero
       if (mype==mype_rad) write(iout_rad,110) j,nusis(j), &
            nuchan(j),varch(j),iuse_rad(j),ermax_rad(j), &
            b_rad(j),pg_rad(j)
    end do
    close(lunin)
100 format(a1,a120)
110 format(i4,1x,a20,' chan= ',i4,  &
          ' var= ',f7.3,' use= ',i2,' ermax= ',F7.3, &
          ' b_rad= ',F7.2,' pg_rad=',F7.2)


!   Allocate arrays for additional preconditioning info
!   Read in information for data number and preconditioning

    if (newpc4pred) then
       allocate(ostats(jpch_rad), rstats(npred,jpch_rad),varA(npred,jpch_rad))
       varA = zero
       ostats = zero
       rstats = zero_quad

       inquire(file='satbias_pc',exist=pcexist)
       if (pcexist) then
          open(lunin,file='satbias_pc',form='formatted')
          nfound = .false.
          read3: do
             read(lunin,'(I5,1x,A20,1x,I5,e15.7/2(4x,10e15.7/))',iostat=istat) &
                  ich,isis,ichan,ostatsx,(varx(ip),ip=1,npred)
             if (istat/=0) exit
             cfound = .false.
             do j =1,jpch_rad
                if(trim(isis) == trim(nusis(j)) .and. ichan == nuchan(j))then
                   cfound = .true.
                   nfound(j) = .true.
                   do i=1,npred
                      varA(i,j)=varx(i)
                   end do
                   ostats(j)=ostatsx
                   if (any(varx/=zero) .and. iuse_rad(j)>-2) inew_rad(j)=.false.
                end if
             end do
             if(.not. cfound .and. mype == 0) &
                  write(6,*) '***WARNING instrument/channel ',isis,ichan, &
                  'found in satbias_pc file but not found in satinfo'
          end do read3
          close(lunin)
          if (istat>0) then
             write(6,*)'RADINFO_READ:  ***ERROR*** error reading satbias_pc, istat=',istat
          endif

          if (mype==mype_rad) then
             write(iout_rad,*)'RADINFO_READ:  read satbias_pc file'
             do j=1,jpch_rad
                if(.not. nfound(j))write(iout_rad,*) 'RADINFO_READ: ***WARNING instrument/channel ',&
                     nusis(j),nuchan(j),' not found in satbias_pc file - set to zero '
             end do
          end if
       else
          if (mype==mype_rad) then
             write(iout_rad,*)'RADINFO_READ:  satbias_pc file doesnot exist - set to zero'
          end if
       end if
    end if   ! end newpc4pred


!   Read in start,step information and cutoff values for scan edges
    allocate(radstart(jpch_rad),radstep(jpch_rad),radnstep(jpch_rad))
    allocate(radedge1(jpch_rad),radedge2(jpch_rad))
    radstart=zero
    radstep =one
    radnstep=90
    radedge1=-1
    radedge2=-1

    inquire(file='scaninfo',exist=pcexist)
    if (pcexist) then
       open(lunin,file='scaninfo',form='formatted')
       do
          read(lunin,1000,IOSTAT=istat) cflg,satscan_sis,start,step,nstep,edge1,edge2
          if (istat /= 0) exit
          if (cflg == '!') cycle

          do j =1,jpch_rad
             if(trim(satscan_sis) == trim(nusis(j)))then
                radstart(j)=start
                radstep(j)=step
                radnstep(j)=nstep
                radedge1(j)=edge1
                radedge2(j)=edge2
             end if
          end do
       end do
1000   format(a1,a20,2f11.3,i10,2i6)
       close(lunin)
    else
       if(mype == 0) write(6,*) '***WARNING file scaninfo not found, use default'

       do j =1,jpch_rad
          call satstep(nusis(j),start,step,nstep,edge1,edge2)
          radstart(j)=start
          radstep(j)=step
          radnstep(j)=nstep
          radedge1(j)=edge1
          radedge2(j)=edge2
       end do
    end if  ! if pcexist


!   Allocate arrays to receive angle dependent bias information.
!   Open file to bias file (satang=satbias_angle).  Read data.

    allocate(cbias(90,jpch_rad),tlapmean(jpch_rad))
    cbias=zero
    tlapmean=zero
    if (adp_anglebc) then 
       allocate(count_tlapmean(jpch_rad),update_tlapmean(jpch_rad),tsum_tlapmean(jpch_rad))
       count_tlapmean=0
       tsum_tlapmean=zero
       update_tlapmean=.true.
    end if

    if (.not. adp_anglebc) then
       open(lunin,file='satbias_angle',form='formatted')
       nfound = .false.
       read2: do
          read(lunin,'(I5,1x,A20,2x,I4,e15.6/9(4x,10f7.3/))',iostat=istat) &
               ich,isis,ichan,tlapm,(cbiasx(ip),ip=1,90)
          if (istat /= 0) exit
          cfound = .false.
          do j =1,jpch_rad
             if(trim(isis) == trim(nusis(j)) .and. ichan == nuchan(j))then
                cfound = .true.
                nfound(j) = .true.
                do i=1,90
                   cbias(i,j)=cbiasx(i)
                end do
                tlapmean(j)=tlapm
             end if
          end do
          if(.not. cfound .and. mype == 0) &
               write(6,*) '***WARNING instrument/channel ',isis,ichan, &
               'found in satbias_angle file but not found in satinfo'
       end do read2
       close(lunin)
       if (istat>0) then
          write(6,*)'RADINFO_READ:  ***ERROR*** error reading satbias_angle, istat=',istat
          write(6,*)'RADINFO_READ:  stop program execution'
          call stop2(79)
       endif

       if (mype==mype_rad) then
          write(iout_rad,*)'RADINFO_READ:  read satbias_angle file'
          do j=1,jpch_rad
             if(.not. nfound(j))write(iout_rad,*) 'RADINFO_READ: ***WARNING instrument/channel ',&
                  nusis(j),nuchan(j),' not found in satbias_angle file - set to zero '
          end do
       end if
    end if ! end of .not.adp_anglebc


    if ( .not. retrieval ) then

!   Allocate array to hold coefficients for predictive (air mass) part of 
!   bias correction.  Open unit to input file.  Read data.
       allocate(predx(npred,jpch_rad))
       do j=1,jpch_rad
          do i=1,npred
             predx(i,j)=zero
          end do
       end do

       open(lunin,file='satbias_in' ,form='formatted')
       nfound = .false.
       read4: do
          if (.not. adp_anglebc) then
             read(lunin,'(I5,1x,A20,1x,I5,10f12.6)',iostat=istat) ich,isis,&
                  ichan,(predr(ip),ip=1,npred)
          else
             read(lunin,'(I5,1x,A20,1x,I5,2e15.6,1x,I5/2(4x,10f12.6/))',iostat=istat) ich,isis,&
                  ichan,tlapm,tsum,ntlapupdate,(predr(ip),ip=1,npred)
          end if
          if (istat /= 0) exit
          cfound = .false.
          do j =1,jpch_rad
             if(trim(isis) == trim(nusis(j)) .and. ichan == nuchan(j))then
                cfound = .true.
                nfound(j) = .true.
                do i=1,npred
                   predx(i,j)=predr(i)
                end do
                if (adp_anglebc) then 
                   tlapmean(j)=tlapm
                   tsum_tlapmean(j)=tsum
                   count_tlapmean(j)=ntlapupdate
                   if (ntlapupdate > ntlapthresh) update_tlapmean(j)=.false.
                end if
                if (any(predr/=zero)) inew_rad(j)=.false.
             end if
          end do
          if(mype == 0 .and. .not. cfound) &
             write(6,*) '***WARNING instrument/channel ',isis,ichan, &
             'found in satbias_in file but not found in satinfo'
       end do read4
       close(lunin)
       if (istat>0) then
          write(6,*)'RADINFO_READ:  ***ERROR*** error reading satbias_in, istat=',istat
          write(6,*)'RADINFO_READ:  stop program execution'
          call stop2(79)
       endif

       if (mype==mype_rad) then
          write(iout_rad,*)'RADINFO_READ:  guess air mass bias correction coefficients below'
          do j=1,jpch_rad
             if (nfound(j)) then
                write(iout_rad,140) j,trim(nusis(j)),(predx(n,j),n=1,npred)
             else
                write(iout_rad,*) '***WARNING instrument/channel ',&
                nusis(j),nuchan(j),' not found in satbias_in file - set to zero '
             endif
          end do
140       format(i4,1x,a20,10f12.6)
       endif


!      Initialize predx if inew_rad and compute angle bias correction and tlapmean
       if (adp_anglebc) then
          call init_predx(newpc4pred)
          do j=1,jpch_rad
             call angle_cbias(trim(nusis(j)),j,cbias(1,j))
          end do

!         check inew_rad again
          do j =1,jpch_rad
             if (inew_rad(j) .and. iuse_rad(j)>=0 .and. all(predx(:,j)==zero)) then
                iuse_rad(j)=-1
             end if
          end do

          if (mype==mype_rad) then
             open(lunout,file='satbias_ang.out',form='formatted')
             do j=1,jpch_rad
                write(lunout,'(I5,1x,A20,2x,I4,e15.6/9(4x,10f7.3/))') &
                     j,nusis(j),nuchan(j),tlapmean(j),(cbias(i,j),i=1,90)
             end do
             close(lunout)
          end if
       end if

    endif

! Read SST dependent radiance bias correction lookup table
    if (retrieval) then
      
       allocate(fbias(numt,jpch_rad))
       fbias=zero
       
       if(mype==mype_rad) write(iout_rad,*) &
            'RADINFO_READ:  read SST & D/N dependent bias correction from ',lunin
       open(lunin,file='satbias_sst',form='formatted')
       rewind (lunin)

!      Loop over satellites sensors & channels
       read5: do
          read(lunin,'(I5,1x,a20,1x,I5/3(4x,11f10.3/) )',iostat=istat) ich,isis,ichan,(fbiasx(i),i=1,numt)
          if (istat /= 0) exit
          cfound = .false.
          do j=1,jpch_rad
             if(trim(isis) == trim(nusis(j)) .and. ichan == nuchan(j))then
                cfound = .true.
                do i=1,numt
                   fbias(i,j)=fbiasx(i)
                end do
                tlapmean(j)=tlapm
             end if
          end do
          if(.not. cfound)write(6,*) ' WARNING instrument/channel ',isis,ichan, &
             'found in satbias_sst file and not found in satinfo'
       end do read5
       close(lunin)
    endif           ! endif for if (retrieval) then


!   Close unit for runtime output.  Return to calling routine
    if(mype==mype_rad)close(iout_rad)
    return

  end subroutine radinfo_read


  subroutine radinfo_write(newpc4pred)
!$$$  subprogram documentation block
!                .      .    .
! subprogram:    radinfo_write
!
!   prgrmmr:     yang        org: np20                date: 1998-05-15
!
! abstract:  This routine writes an updated version of the predictive
!            part of the bias correction.
!
! program history log:
!   1998-05-15  yang, weiyu
!   1999-08-24  derber, j., treadon, r., yang, w., first frozen mpp version
!   2004-06-22  treadon - update documentation
!   2004-07-15  todling - protex-compliant prologue
!   2008-04-23  safford - add standard subprogram doc block
!   2010-04-29  zhu     - add analysis varaince info for radiance bias correction coefficients
!   2010-05-06  zhu     - add option adp_anglebc
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp; SGI Origin 2000; Compaq/HP
!
!$$$ end documentation block

! !USES:

    implicit none

    integer(i_kind) lunout,jch,ip,i
    real(r_kind),dimension(npred):: varx
    logical newpc4pred
    data lunout / 51 /

!   Open unit to output file.  Write analysis varaince info.  Close unit.
    if (newpc4pred) then
       open(lunout,file='satbias_pc.out',form='formatted')
       rewind lunout
       do jch=1,jpch_rad
          do i=1,npred
             varx(i)=varA(i,jch)
          end do
          write(lunout,'(I5,1x,A20,1x,I5,e15.7/2(4x,10e15.7/))') jch,nusis(jch),&
               nuchan(jch),ostats(jch),(varx(ip),ip=1,npred)
       end do
       close(lunout)
    end if

!   Open unit to output file.  Write updated coefficients.  Close unit.
    open(lunout,file='satbias_out',form='formatted')
    rewind lunout
    if (.not. adp_anglebc) then
       do jch=1,jpch_rad
          write(lunout,'(I5,1x,a20,1x,i5,10f12.6)') jch,nusis(jch),nuchan(jch),&
               (predx(ip,jch),ip=1,npred)
       end do
    else
       do jch=1,jpch_rad
          write(lunout,'(I5,1x,a20,1x,i5,2e15.6,1x,I5/2(4x,10f12.6/))') jch,nusis(jch),nuchan(jch),&
               tlapmean(jch),tsum_tlapmean(jch),count_tlapmean(jch),(predx(ip,jch),ip=1,npred)
       end do
    end if
    close(lunout)

!   Deallocate data arrays for bias correction and those which hold
!   information from satinfo file.
    deallocate (predx,cbias,tlapmean,nuchan,nusis,iuse_rad,air_rad,ang_rad, &
         ifactq,varch,inew_rad)
    if (adp_anglebc) deallocate(count_tlapmean,update_tlapmean,tsum_tlapmean)
    if (newpc4pred) deallocate(ostats,rstats,varA)
    deallocate (radstart,radstep,radnstep,radedge1,radedge2)
    return
  end subroutine radinfo_write



  integer(i_kind) function newchn(sis,ichan)   ! "satinfo-relative" index of 
                                               ! (sis,ichan) combination
!$$$  subprogram documentation block
!                .      .    .
! subprogram:    function newchn
!
!   prgrmmr:     derber      org: np23                date: 1997-08-13
!
! abstract:  For a given satellite and channel produce a combined 
!            channel number based on input from the satinfo file.
!            If the requested channel/satellite combination is
!            not found, the function returns a zero value.
!
! program history log:
!   1997-08-13  derber
!   2004-06-22  treadon - update documentation
!   2004-07-15  todling - protex-compliant prologue
!   2008-04-23  safford - add standard subprogram doc block, rm unused uses
!
!   input argument list:
!     sis     - satellite to search for
!     ichan   - channel number to search for
!
!   return:
!             - combined channel number
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp; SGI Origin 2000; Compaq/HP
!
!$$$ end documentation block

! !USES:

    implicit none

! !INPUT PARAMETERS:

    character(len=20), intent(in   ) :: sis   ! satellite to search for
    integer(i_kind)  , intent(in   ) :: ichan ! channel number to search for

    integer(i_kind) j

    do j=1,jpch_rad
       if ( nuchan(j)==ichan .and. nusis(j)==sis) then
          newchn=j
          return
       end if
    end do
    write(6,*) 'NEWCHN:  channel=',ichan,' sensor/instrument/satellite=',sis, &
         ' not present in satinfo file'
    newchn=0
    return
  end function newchn
  
   real(r_kind) function rnad_pos(isis,iscan,jch)
!$$$  subprogram documentation block
!                .      .    .
! subprogram:    function rnad_pos
!
!   prgrmmr:     zhu      org: np23                date: 2010-05-06
!
! abstract:  For a given satellite/sensor produce the scan angle
!
! program history log:
!   2010-05-06  zhu
!
!   return:
!             - scan angle
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp; SGI Origin 2000; Compaq/HP
!
!$$$ end documentation block

! !USES:
   implicit none
   character(len=20),intent(in):: isis
   integer(i_kind),intent(in):: iscan,jch

   integer(i_kind) ifov
   real(r_kind) piece

   if (index(isis,'iasi')/=0) then

      piece=-0.625_r_kind
      if (mod(iscan,2) == 1) piece = 0.625_r_kind
      rnad_pos=radstart(jch)+radstep(jch)*float((iscan-1)/2)+piece

   else

      if (index(isis,'hirs')/=0 .and. (index(isis,'n16')/=0 .or. &
                                       index(isis,'n17')/=0)) then
         ifov=iscan+1
      else
         ifov=iscan
      end if
      rnad_pos=radstart(jch)+radstep(jch)*float(ifov-1)

   end if

   return
   end function rnad_pos

   subroutine angle_cbias(isis,j,cbiasj)
!$$$  subprogram documentation block
!                .      .    .
! subprogram:    angle_cbias
!
!   prgrmmr:     zhu      org: np23                date: 2010-05-06
!
! abstract:  For a given satellite/sensor produce angle bias correction
!
! program history log:
!   2010-05-06  zhu
!   2010-12-16  treadon - recode cbiasj to be consistent with setuprad
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp; SGI Origin 2000; Compaq/HP
!
!$$$ end documentation block

! !USES:

     use constants, only: zero,deg2rad
     implicit none
     
     character(len=20),intent(in):: isis
     integer(i_kind),intent(in):: j
     real(r_kind),dimension(90),intent(inout):: cbiasj
     
     integer(i_kind) i,k
     real(r_kind),dimension(npred):: pred
     
     pred=zero
     do i=1,radnstep(j)
        pred(npred)=rnad_pos(isis,i,j)*deg2rad
        do k=2,angord
           pred(npred-k+1)=pred(npred)**k
        end do
        cbiasj(i)=zero
        do k=1,angord
           cbiasj(i) = cbiasj(i)+ predx(npred-k+1,j)*pred(npred-k+1)
        end do
        
     end do
     return
   end subroutine angle_cbias

   subroutine satstep(isis,start,step,nstep,edge1,edge2)
!$$$  subprogram documentation block
!                .      .    .
! subprogram:    satstep
!
!   prgrmmr:     zhu      org: np23                date: 2010-05-06
!
! abstract:  This routine sets step, start, and nstart
!
! program history log:
!   2010-05-06  zhu
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp; SGI Origin 2000; Compaq/HP
!
!$$$ end documentation block

   use constants, only: zero,one,three
   implicit none

   character(len=20),intent(in) :: isis
   integer(i_kind),intent(out)  :: nstep,edge1,edge2
   real(r_kind),intent(out)     :: start,step

   start=zero
   step =one
   nstep=90
   edge1=-1
   edge2=-1

   if (index(isis,'hirs')/=0) then
      step  = 1.80_r_kind
      start = -49.5_r_kind
      nstep = 56
      edge1 = 7
      edge2 = 50
   else if (index(isis,'msu')/=0) then
      if (index(isis,'amsua')/=0) then
         step  = three + one/three
         start = -48._r_kind - one/three
         nstep = 30
         edge1 = 4
         edge2 = 27
      else if (index(isis,'amsub')/=0) then
         step  = 1.1_r_kind
         start = -48.95_r_kind
         nstep = 90
         edge1 = 10
         edge2 = 81
      else
         step  = 9.474_r_kind
         start = -47.37_r_kind
         nstep = 90
         edge1 = 2
         edge2 = 10
      end if
   else if (index(isis,'mhs')/=0) then
      step  = 10.0_r_kind/9.0_r_kind
      start = -445.0_r_kind/9.0_r_kind
      nstep = 90
      edge1 = 10
      edge2 = 81
   else if (index(isis,'ssu')/=0) then
      step  = 10.0_r_kind
      start = -35.00_r_kind
      nstep = 90
      edge1 = 2
      edge2 = 7
   else if (index(isis,'airs')/=0) then
      step  = 1.1_r_kind
      start = -48.9_r_kind
      nstep = 90
      edge1 = 10
      edge2 = 81
   else if (index(isis,'hsb')/=0) then
      step  = 1.1_r_kind
      start = -48.95_r_kind
      nstep = 90
      edge1 = 10
      edge2 = 81
   else if (index(isis,'iasi')/=0) then
      step  = 3.334_r_kind
      start = -48.33_r_kind
      nstep = 60
      edge1 = 5
      edge2 = 56
   end if

   return
   end subroutine satstep


   subroutine init_predx(newpc4pred)
!$$$  subprogram documentation block
!                .      .    .
! subprogram:    init_predx
!
!   prgrmmr:     zhu      org: np23                date: 2010-07-13
!
! abstract:  For a given satellite/sensor produce predictor coeficients for angle bias correction
!
! program history log:
!   2010-07-13  zhu  - modified from global_angupdate
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp; SGI Origin 2000; Compaq/HP
!
!$$$ end documentation block

! !USES:

   use obsmod, only: ndat,dplat,dfile,dtype,dsis
   use mpimod, only:  npe,mype,mpi_comm_world,ierror
   use read_diag, only: read_radiag_header,read_radiag_data,diag_header_fix_list,&
        diag_header_chan_list,diag_data_fix_list,diag_data_chan_list,&
        diag_data_extra_list,diag_data_name_list
   use constants, only: zero,one,deg2rad
   implicit none

!  Declare local parameters
   integer(i_kind),parameter:: lndiag = 21
   integer(i_kind),parameter:: lntemp = 51

   integer(i_kind),parameter:: nthreshold = 200
   integer(i_kind),parameter:: maxchn = 3000
   integer(i_kind),parameter:: maxdat = 100

   real(r_kind),parameter:: dtmax = 6.0


!  Declare local variables
   logical lexist
   logical data_on_edges
   logical update
   logical newpc4pred

   character(10):: obstype,platid
   character(20):: satsens,satsens_id
   character(50):: fdiag_rad,dname,fname

   integer(i_kind):: ix,ii,iii,iich,ndatppe
   integer(i_kind):: i,j,jj,n_chan,k
   integer(i_kind):: ierror_code
   integer(i_kind):: istatus,ispot,iuseqc
   integer(i_kind):: np,new_chan,nc
   integer(i_kind):: counttmp
   integer(i_kind),dimension(maxchn):: ich
   integer(i_kind),dimension(maxchn):: io_chan
   integer(i_kind),dimension(maxdat):: ipoint
 
   real(r_kind):: bias,scan,errinv,rnad
   real(r_kind):: tlaptmp,tsumtmp,ratio,wgtlap
   real(r_kind),allocatable,dimension(:):: tsum0,tsum,tlap0,tlap1,tlap2,tcnt
   real(r_kind),allocatable,dimension(:,:):: AA
   real(r_kind),allocatable,dimension(:):: be
   real(r_kind),allocatable,dimension(:):: iobs
   real(r_kind),allocatable,dimension(:,:,:):: A
   real(r_kind),allocatable,dimension(:,:):: b
   real(r_kind),allocatable,dimension(:):: pred
   real(r_kind),allocatable,dimension(:):: predr

!  Declare types used for reading satellite data
   type(diag_header_fix_list )         :: header_fix
   type(diag_header_chan_list),pointer :: header_chan(:)
   type(diag_data_name_list)           :: data_name
   type(diag_data_fix_list   )         :: data_fix
   type(diag_data_chan_list  ),pointer :: data_chan(:)
   type(diag_data_extra_list ),pointer :: data_extra(:,:)

!************************************************************************
!  Return if no new channels AND update_tlapmean=.false.
   if (.not. (any(inew_rad) .or. any(update_tlapmean))) return
   if (mype==0) write(6,*) 'INIT_PREDX:  enter routine'

   np=angord+1

!  Allocate and initialize data arrays
   if (any(update_tlapmean)) then
      allocate(tsum0(jpch_rad),tsum(jpch_rad),tlap0(jpch_rad), &
               tlap1(jpch_rad),tlap2(jpch_rad),tcnt(jpch_rad))
      do j=1,jpch_rad
         tsum(j)=zero
         tsum0(j)=tsum_tlapmean(j)
         tcnt(j)=zero
         tlap1(j)=zero
         tlap2(j)=zero
         tlap0(j)=tlapmean(j)
         if (.not. newpc4pred) tlap0(j)=100.0_r_kind*tlap0(j)  ! convert tlap to its original unit
      end do
   end if

!  Assign each satellite/sensor to a mpi task
   ndatppe=0
   ix=0
   ipoint=0
   do i=1,ndat
      if(ix >= npe )ix=ix-npe
      if(ix == mype)then
         ndatppe=ndatppe+1
         ipoint(ndatppe)=i
      end if
      ix=ix+1
   end do

!  Loop over mpi tasks.  Each task processes a given set of satellite/sensors
   loopf:  do ii=1,ndatppe
      iii=ipoint(ii)
      obstype=dtype(iii)
      platid=dplat(iii)
      satsens_id=dsis(iii)

!     Create diagnostic filename
      fdiag_rad = 'diag_' // trim(dtype(iii)) // '_' // trim(dplat(iii))

!     See if diagnostic file exists
      inquire(file=fdiag_rad,exist=lexist)
      if (.not.lexist) cycle loopf

!     Open file and read header
      open(lndiag,file=fdiag_rad,form='unformatted',status='old',iostat=istatus)
      if (istatus/=0) then
         write(6,*)'INIT_PREDX:  Task ',mype,' problem opening file ',trim(fdiag_rad),' iostat=',istatus
         close(lndiag)
         cycle loopf
      endif

      call read_radiag_header(lndiag,npred,retrieval,header_fix,header_chan,data_name,istatus)
      if (istatus/=0) then
         write(6,*)'INIT_PREDX:  Task ',mype,' problem reading file ',trim(fdiag_rad),' header, iostat=',istatus
         close(lndiag)
         cycle loopf
      endif

!     Process file
      write(6,*)'INIT_PREDX:  Task ',mype,' processing ',trim(fdiag_rad)
      satsens = header_fix%isis
      n_chan = header_fix%nchan

!     Check for consistency between specified and retrieved satellite id
      if (satsens /= satsens_id) then
         write(6,*)'INIT_PREDX:  ***ERROR*** inconsistent satellite ids ',&
              ' fdiag_rad= ',trim(fdiag_rad),' satsens,satsens_id=',satsens,satsens_id
         ierror_code=99
         call mpi_abort(mpi_comm_world,ierror_code,ierror)
         stop 98
      endif

!     Extract satinfo relative index and get new_chan
      new_chan=0
      update=.false.
      do j=1,n_chan
         io_chan(j) = real( header_chan(j)%iochan, 4 )
         if (inew_rad(io_chan(j))) then
            new_chan=new_chan+1
            ich(new_chan) = io_chan(j)
         end if
         if (update_tlapmean(io_chan(j))) update=.true.
      end do
      if (.not. update .and. new_chan==0) then 
         close(lndiag)
         cycle loopf
      end if

!     Allocate arrays and initialize
      if (new_chan/=0) then
         allocate(A(np,np,new_chan),b(np,new_chan))
         allocate(iobs(new_chan),pred(np))
         do j=1,new_chan
            iobs(j)=zero
            do i=1,np
               b(i,j)=zero
               do k=1,np
                  A(i,k,j)=zero
               end do
            end do
         end do
      end if


!     Loop to read diagnostic file
      istatus = 0
      loopd:  do while (istatus == 0)
 
!        Read a record.  If read flag, istatus does not equal zero, exit loopd
         call read_radiag_data( lndiag,header_fix,retrieval,data_fix,data_chan,data_extra,istatus )
         if( istatus /= 0 ) exit loopd

!        Extract scan angle, lat, lon
         scan   = data_fix%senscn_pos
         ispot  = nint(scan)

!        Exclude data on edges
         if (.not. use_edges) then
            call find_edges(satsens_id,ispot,data_on_edges)
            if (data_on_edges) cycle loopd
         end if

!        Channel loop
         nc=0
         loopc:  do j = 1, n_chan
            jj=io_chan(j)
            if (inew_rad(jj)) nc = nc+1
            

            if ((.not. inew_rad(jj)) .and.  &
                (.not. update_tlapmean(jj))) cycle loopc

!           Check for reasonable obs-ges and observed Tb.
!           If the o-g difference is too large (> 200 K, very genereous!)
!           of the observation is too cold (<50 K) or too warm (>500 K),
!           do not use this observation in computing the update to the
!           angle dependent bias.
            if( ( abs(data_chan(j)%omgnbc) > 200. .or. &
                 data_chan(j)%tbobs < 50. .or. &
                 data_chan(j)%tbobs > 500. ) ) then
               cycle loopc
            end if
 
!           if errinv= (1 /(obs error)) is small (small = less than 1.e-6)
!           the observation did not pass quality control.  In this
!           case, do not use this observation in computing the update
!           to the angle dependent bias
            if (iuse_rad(jj)>0 .and. data_chan(j)%errinv<1.e-6) cycle loopc

!           If iuseqc flag is <=0 (i.e., 0 or -1), ensure (o-g)<dtmax.
!           If the user says to ingore the qc flag, check the the o-g
!           difference falls within the user specify maximum allowable
!           difference.  If the o-g lies outside this bound, do not use
!           this observation in computing the update to the angle
!           dependent bias.
            if ( iuse_rad(jj)<=0 .and. abs(data_chan(j)%omgnbc)>dtmax ) then
               cycle loopc
            end if

            errinv=data_chan(j)%errinv
            if (iuse_rad(jj)<=0) errinv=one

            if (update_tlapmean(jj)) then
               tlaptmp=data_chan(j)%tlap
               if (header_fix%inewpc==0) tlaptmp=100.0_r_kind*tlaptmp
               tlap1(jj)=tlap1(jj)+(tlaptmp-tlap0(jj))*errinv
               tsum(jj) =tsum(jj)+errinv
               tcnt(jj) =tcnt(jj)+one
            end if

            if (inew_rad(jj)) then

!              Define predictor
               pred=zero
               pred(1) = one
               rnad = rnad_pos(satsens,ispot,io_chan(j))*deg2rad
               do i=1,angord
                  pred(i+1) = rnad**i
               end do

!              Add values to running sums.
               iobs(nc) = iobs(nc)+one
               bias = data_chan(j)%omgnbc
               do i=1,np
                  b(i,nc) = b(i,nc)+bias*pred(i)*errinv**2
               end do
               do k=1,np
                  do i=1,np
                     A(i,k,nc) = A(i,k,nc)+pred(i)*pred(k)*errinv**2
                  end do
               end do
            end if
        
         enddo loopc ! channel loop

!     End of loop over diagnostic file
      enddo loopd

      close(lndiag)

!     Compute tlapmean
      if (update) then
         do j = 1,n_chan
            jj=io_chan(j)
!           wgtlap=one
            if (update_tlapmean(jj)) then
               if(tcnt(jj) >= nthreshold)  then
                  tsum(jj)=tsum(jj)+tsum0(jj)
!                 tlap2(jj) = tlap0(jj) + wgtlap*tlap1(jj)/tsum(jj)
                  tlap2(jj) = tlap0(jj) + tlap1(jj)/tsum(jj)
                  count_tlapmean(jj)=count_tlapmean(jj)+one
               elseif (tcnt(jj)>0) then
                  ratio = max(zero,min(tcnt(jj)/float(nthreshold),one))
                  tsum(jj)=ratio*tsum(jj)+tsum0(jj)
!                 tlap2(jj) = tlap0(jj) + ratio*wgtlap*tlap1(jj)/tsum(jj)
                  tlap2(jj) = tlap0(jj) + ratio*tlap1(jj)/tsum(jj)
                  count_tlapmean(jj)=count_tlapmean(jj)+one
               else
                  tsum(jj)=tsum0(jj)
                  tlap2(jj) = tlap0(jj)
                  count_tlapmean(jj)=count_tlapmean(jj)
               endif
               tsum_tlapmean(jj)=tsum(jj)
               tlapmean(jj)=tlap2(jj)
               if (.not. newpc4pred) tlapmean(jj)=0.01_r_kind*tlapmean(jj)
            end if
         end do

!        Write updated tlapmean and sample size to scratch files
         dname = 'update_' // trim(obstype) // '_' // trim(platid)
         open(lntemp,file=dname,form='formatted')
         do j=1,n_chan
            jj=io_chan(j)
            write(lntemp,220) jj,tlapmean(jj),tsum_tlapmean(jj),count_tlapmean(jj)
220         format(I5,1x,2e15.6,1x,I5)
         end do
         close(lntemp)
      end if


      if (new_chan/=0) then
         if (all(iobs<nthreshold)) then
            deallocate(A,b,iobs,pred)
            cycle loopf
         endif

!        Solve linear system
         allocate(AA(np,np),be(np))
         do i=1,new_chan
            if (iobs(i)<nthreshold) cycle
            AA(:,:)=A(:,:,i)
            be(:)  =b(:,i)
            call linmm(AA,be,np,1,np,np)

            predx(1,ich(i))=be(1)
            do j=1,angord
               predx(npred-j+1,ich(i))=be(j+1)
            end do
         end do ! end of new_chan
         deallocate(AA,be)

!        write initialized predx to scratch files
         dname = 'init_' // trim(obstype) // '_' // trim(platid)
         open(lntemp,file=dname,form='formatted')
         do i=1,new_chan
            if (iobs(i)<nthreshold) cycle
            write(lntemp,210) ich(i),predx(1,ich(i)),(predx(npred-k+1,ich(i)),k=1,angord)
 210        format(I5,1x,5e13.6)
         end do
         close(lntemp)

         deallocate(A,b)
         deallocate(iobs,pred)
      end if

!  End of loop over satellite/sensor types
   end do loopf


!  Wait for all mpi tasks to finish processing the
!  satellite/sensors assigned to them.
!  write(6,*)'INIT_PREDX:  Wait after satellite/sensor loop'
   call mpi_barrier(mpi_comm_world,ierror)


!  Combine the satellite/sensor specific predx together
   if (any(inew_rad)) then
      allocate(predr(np))
      do i=1,ndat
         fname = 'init_' // trim(dtype(i)) // '_' // trim(dplat(i))
         inquire(file=fname,exist=lexist)

!        Process the scratch file
         if (lexist) then
!           Read data from scratch file
            write(6,*) 'INIT_PREDX:  processing update file i=',i,' with fname=',trim(fname)
            open(lntemp,file=fname,form='formatted')
            do
               read(lntemp,210,end=160) iich,(predr(k),k=1,np)
               predx(1,iich)=predr(1)
               do j=1,angord
                  predx(npred-j+1,iich)=predr(j+1)
               end do
            end do
160         continue
            close(lntemp)
         end if  ! end of lexist
      end do ! end of ndat
      deallocate(predr)
   end if

   if (any(update_tlapmean)) then 
      do i=1,ndat
         fname = 'update_' // trim(dtype(i)) // '_' // trim(dplat(i))
         inquire(file=fname,exist=lexist)

!        Process the scratch file
         if (lexist) then
!           Read data from scratch file
            write(6,*) 'INIT_PREDX:  processing update file i=',i,' with fname=',trim(fname)
            open(lntemp,file=fname,form='formatted')
            do 
               read(lntemp,220,end=260) jj,tlaptmp,tsumtmp,counttmp
               tlapmean(jj)=tlaptmp
               tsum_tlapmean(jj)=tsumtmp
               count_tlapmean(jj)=counttmp
            end do
260         continue
            close(lntemp)
         end if  ! end of lexist
      end do ! end of ndat

      deallocate(tsum0,tsum,tlap0,tlap1,tlap2,tcnt)
   end if

!  End of program
   return
   end subroutine init_predx

   subroutine find_edges(sis,ispot,data_on_edges)
!$$$  subprogram documentation block
!                .      .    .
! subprogram:    find_edges
!
!   prgrmmr:     zhu      org: np23                date: 2010-09-02
!
! abstract:  For a given satellite/sensor produce data_on_edges
!
! program history log:
!   2010-09-02  zhu
!
! attributes:
!   language: f90
!   machine:  ibm rs/6000 sp; SGI Origin 2000; Compaq/HP
!
!$$$ end documentation block

   implicit none

   character(len=*),intent(in) :: sis
   integer(i_kind),intent(in ) :: ispot
   logical,intent(out) :: data_on_edges

   integer(i_kind):: i
   logical hirs,msu,amsua,amsub,mhs,hirs4,hirs3,hirs2,ssu,airs,hsb,iasi
 
   data_on_edges=.false.

   do i=1,jpch_rad
      if (radedge1(i)==-1 .or. radedge2(i)==-1) cycle
      if (trim(sis)==trim(nusis(i)) .and. (ispot<radedge1(i) .or. ispot>radedge2(i))) then
         data_on_edges=.true.
         exit
      end if
   end do

   return
   end subroutine find_edges
 
end module radinfo
