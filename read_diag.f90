!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    read_raddiag                       read rad diag file
!   prgmmr: tahara           org: np20                date: 2003-01-01
!
! abstract:  This module contains code to process radiance
!            diagnostic files.  The module defines structures
!            to contain information from the radiance
!            diagnostic files and then provides two routines
!            to access contents of the file.
!
! program history log:
!   2005-07-22 treadon - add this doc block
!   2010-10-05 treadon - refactor code to GSI standard
!   2010-10-08 zhu     - use data_tmp to handle various npred values
!
! contains
!   read_radiag_header - read radiance diagnostic file header
!   read_radiag_data   - read radiance diagnostic file data
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

module read_diag

  use kinds, only:  i_kind,r_single
  implicit none

! Declare public and private
  private

  public :: diag_header_fix_list
  public :: diag_header_chan_list
  public :: diag_data_name_list
  public :: diag_data_fix_list
  public :: diag_data_chan_list
  public :: diag_data_extra_list
  public :: read_radiag_header
  public :: read_radiag_data
  public :: iversion_radiag
  public :: ireal_radiag
  public :: ipchan_radiag



  integer(i_kind),parameter :: ireal_radiag  = 26   ! number of real entries per spot in radiance diagnostic file
  integer(i_kind),parameter :: ipchan_radiag = 7    ! number of entries per channel per spot in radiance diagnostic file

! Declare structures for radiance diagnostic file information
  type diag_header_fix_list
     character(len=20) :: isis           ! sat and sensor type
     character(len=10) :: id             ! sat type
     character(len=10) :: obstype        ! observation type
     integer(i_kind) :: jiter            ! outer loop counter
     integer(i_kind) :: nchan            ! number of channels in the sensor
     integer(i_kind) :: npred            ! number of updating bias correction predictors
     integer(i_kind) :: idate            ! time (yyyymmddhh)
     integer(i_kind) :: ireal            ! # of real elements in the fix part of a data record
     integer(i_kind) :: ipchan           ! # of elements for each channel except for bias correction terms
     integer(i_kind) :: iextra           ! # of extra elements for each channel
     integer(i_kind) :: jextra           ! # of extra elements
     integer(i_kind) :: idiag            ! first dimension of diag_data_chan
     integer(i_kind) :: angord           ! order of polynomial for adp_anglebc option
     integer(i_kind) :: iversion         ! radiance diagnostic file version number
  end type diag_header_fix_list

  type diag_data_name_list
     character(len=10),dimension(ireal_radiag) :: fix
     character(len=10),dimension(:),allocatable :: chn
  end type diag_data_name_list
  
  type diag_header_chan_list
     real(r_single) :: freq              ! frequency (Hz)
     real(r_single) :: polar             ! polarization
     real(r_single) :: wave              ! wave number (cm^-1)
     real(r_single) :: varch             ! error variance (or SD error?)
     real(r_single) :: tlapmean          ! mean lapse rate
     integer(i_kind):: iuse              ! use flag
     integer(i_kind):: nuchan            ! sensor relative channel number
     integer(i_kind):: iochan            ! satinfo relative channel number
  end type diag_header_chan_list

  type diag_data_fix_list
     real(r_single) :: lat               ! latitude (deg)
     real(r_single) :: lon               ! longitude (deg)
     real(r_single) :: zsges             ! guess elevation at obs location (m)
     real(r_single) :: obstime           ! observation time relative to analysis
     real(r_single) :: senscn_pos        ! sensor scan position (integer(i_kind))
     real(r_single) :: satzen_ang        ! satellite zenith angle (deg)
     real(r_single) :: satazm_ang        ! satellite azimuth angle (deg)
     real(r_single) :: solzen_ang        ! solar zenith angle (deg)
     real(r_single) :: solazm_ang        ! solar azimumth angle (deg)
     real(r_single) :: sungln_ang        ! sun glint angle (deg)
     real(r_single) :: water_frac        ! fractional coverage by water
     real(r_single) :: land_frac         ! fractional coverage by land
     real(r_single) :: ice_frac          ! fractional coverage by ice
     real(r_single) :: snow_frac         ! fractional coverage by snow
     real(r_single) :: water_temp        ! surface temperature over water (K)
     real(r_single) :: land_temp         ! surface temperature over land (K)
     real(r_single) :: ice_temp          ! surface temperature over ice (K)
     real(r_single) :: snow_temp         ! surface temperature over snow (K)
     real(r_single) :: soil_temp         ! soil temperature (K)
     real(r_single) :: soil_mois         ! soil moisture 
     real(r_single) :: land_type         ! land type (integer(i_kind))
     real(r_single) :: veg_frac          ! vegetation fraction
     real(r_single) :: snow_depth        ! snow depth
     real(r_single) :: sfc_wndspd        ! surface wind speed
     real(r_single) :: qcdiag1           ! ir=cloud fraction, mw=cloud liquid water
     real(r_single) :: qcdiag2           ! ir=cloud top pressure, mw=total column water
  end type diag_data_fix_list

  type diag_data_chan_list
     real(r_single) :: tbobs              ! Tb (obs) (K)
     real(r_single) :: omgbc              ! Tb_(obs) - Tb_(simulated w/ bc)  (K)
     real(r_single) :: omgnbc             ! Tb_(obs) - Tb_(simulated_w/o bc) (K)
     real(r_single) :: errinv             ! inverse error (K**(-1))
     real(r_single) :: qcmark             ! quality control mark
     real(r_single) :: emiss              ! surface emissivity
     real(r_single) :: tlap               ! temperature lapse rate
     real(r_single) :: bicons             ! constant bias correction term
     real(r_single) :: biang              ! scan angle bias correction term
     real(r_single) :: biclw              ! CLW bias correction term
     real(r_single) :: bilap2             ! square lapse rate bias correction term
     real(r_single) :: bilap              ! lapse rate bias correction term
     real(r_single),dimension(:),allocatable :: bifix          ! angle dependent bias
     real(r_single) :: bisst              ! SST bias correction term
  end type diag_data_chan_list

  type diag_data_extra_list
     real(r_single) :: extra              ! extra information
  end type diag_data_extra_list

  integer(i_kind),parameter:: iversion_radiag = 11104
  real(r_single),parameter::  rmiss_radiag    = -9.9e11_r_single

contains

subroutine read_radiag_header(ftin,npred_radiag,retrieval,header_fix,header_chan,data_name,iflag)
!                .      .    .                                       .
! subprogram:    read_diag_header                 read rad diag header
!   prgmmr: tahara           org: np20                date: 2003-01-01
!
! abstract:  This routine reads the header record from a radiance
!            diagnostic file
!
! program history log:
!   2010-10-05 treadon - add this doc block
!
! input argument list:
!   ftin          - unit number connected to diagnostic file 
!   npred_radiag  - number of bias correction terms
!   retrieval     - .true. if sst retrieval
!
! output argument list:
!   header_fix    - header information structure
!   header_chan   - channel information structure
!   data_name     - diag file data names
!   iflag         - error code
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

! Declare passed arguments
  integer(i_kind),intent(in)             :: ftin
  integer(i_kind),intent(in)             :: npred_radiag
  logical,intent(in)                     :: retrieval
  type(diag_header_fix_list ),intent(out):: header_fix
  type(diag_header_chan_list),pointer    :: header_chan(:)
  type(diag_data_name_list)              :: data_name
  integer(i_kind),intent(out)            :: iflag
    

!  Declare local variables
  character(len=2):: string
  character(len=10):: satid,sentype
  character(len=20):: sensat
  integer(i_kind),save :: nchan_last = -1
  integer(i_kind) :: i,ich
  integer(i_kind):: jiter,nchanl,npred,ianldate,ireal,ipchan,iextra,jextra


! Read header (fixed_part).
  read(ftin,IOSTAT=iflag) header_fix
  if (iflag/=0) then
     rewind(ftin)
     read(ftin,IOSTAT=iflag) sensat,satid,sentype,jiter,nchanl,npred,ianldate,&
          ireal,ipchan,iextra,jextra
     if (iflag/=0) then
        write(6,*)'READ_RADIAG_HEADER:  ***ERROR*** Unknown file format.  Cannot read'
        return
     endif
     header_fix%isis    = sensat
     header_fix%id      = satid
     header_fix%obstype = sentype
     header_fix%jiter   = jiter
     header_fix%nchan   = nchanl
     header_fix%npred   = npred
     header_fix%idate   = ianldate
     header_fix%ireal   = ireal
     header_fix%ipchan  = ipchan
     header_fix%iextra  = iextra
     header_fix%jextra  = jextra
     header_fix%idiag   = ipchan+npred+1
     header_fix%angord  = 0
     header_fix%iversion= iversion_radiag-1
  endif
  write(6,*)'READ_RADIAG_HEADER:  isis=',header_fix%isis,&
       ' nchan=',header_fix%nchan,&
       ' npred=',header_fix%npred,&
       ' angord=',header_fix%angord,&
       ' idiag=',header_fix%idiag,&
       ' iversion=',header_fix%iversion

  if (header_fix%npred  /= npred_radiag) &
       write(6,*) 'READ_RADIAG_HEADER:  **WARNING** header_fix%npred,npred=',&
       header_fix%npred,npred_radiag
  
  if (header_fix%iextra /= 0) &
       write(6,*)'READ_RADIAG_HEADER:  extra diagnostic information available, ',&
       'iextra=',header_fix%iextra
  
! Allocate and initialize as needed
  if (header_fix%nchan /= nchan_last)then
     if (nchan_last > 0) then
        deallocate(header_chan)
        deallocate(data_name%chn)
     endif
     nchan_last = header_fix%nchan

     allocate(header_chan( header_fix%nchan))

     allocate(data_name%chn(header_fix%idiag))
     data_name%fix(1) ='lat       '
     data_name%fix(2) ='lon       '
     data_name%fix(3) ='zsges     '
     data_name%fix(4) ='obstim    '
     data_name%fix(5) ='scanpos   '
     data_name%fix(6) ='satzen    '
     data_name%fix(7) ='satazm    '
     data_name%fix(8) ='solzen    '
     data_name%fix(9) ='solazm    '
     data_name%fix(10)='sungln    '
     data_name%fix(11)='fwater    '
     data_name%fix(12)='fland     '
     data_name%fix(13)='fice      '
     data_name%fix(14)='fsnow     '
     data_name%fix(15)='twater    '
     data_name%fix(16)='tland     '
     data_name%fix(17)='tice      '
     data_name%fix(18)='tsnow     '
     data_name%fix(19)='tsoil     '
     data_name%fix(20)='soilmoi   '
     data_name%fix(21)='landtyp   '
     data_name%fix(22)='vegfrac   '
     data_name%fix(23)='snowdep   '
     data_name%fix(24)='wndspd    '
     data_name%fix(25)='qc1       '
     data_name%fix(26)='qc2       '

     data_name%chn(1)='obs       '
     data_name%chn(2)='omgbc     '
     data_name%chn(3)='omgnbc    '
     data_name%chn(4)='errinv    '
     data_name%chn(5)='qcmark    '
     data_name%chn(6)='emiss     '
     data_name%chn(7)='tlap      '

     if (header_fix%iversion<iversion_radiag) then
        data_name%chn( 8)= 'bifix     '
        data_name%chn( 9)= 'bilap     '
        data_name%chn(10)= 'bilap2    '
        data_name%chn(11)= 'bicons    '
        data_name%chn(12)= 'biang     '
        data_name%chn(13)= 'biclw     '
        if (retrieval) data_name%chn(13)= 'bisst     '
     else
        data_name%chn( 8)= 'bicons    '
        data_name%chn( 9)= 'biang     '
        data_name%chn(10)= 'biclw     '
        data_name%chn(11)= 'bilap2    '
        data_name%chn(12)= 'bilap     '
        do i=1,header_fix%angord
           write(string,'(i2.2)') header_fix%angord-i+1
           data_name%chn(12+i)= 'bifix' // string
        end do
        data_name%chn(12+header_fix%angord+1)= 'bifix     '
        data_name%chn(12+header_fix%angord+2)= 'bisst     '
     endif
  endif

! Read header (channel part)
  do ich=1, header_fix%nchan
     read(ftin,IOSTAT=iflag) header_chan(ich)
     if (iflag/=0) return
  end do

! Construct array containing menonics for data record entries
  
     
end subroutine read_radiag_header

subroutine read_radiag_data(ftin,header_fix,retrieval,data_fix,data_chan,data_extra,iflag )
!                .      .    .                                       .
! subprogram:    read_radiag_dat                    read rad diag data
!   prgmmr: tahara           org: np20                date: 2003-01-01
!
! abstract:  This routine reads the data record from a radiance
!            diagnostic file
!
! program history log:
!   2010-10-05 treadon - add this doc block
!
! input argument list:
!   ftin - unit number connected to diagnostic file
!   header_fix - header information structure
!
! output argument list:
!   data_fix   - spot header information structure
!   data_chan  - spot channel information structure
!   data_extra - spot extra information
!   iflag      - error code
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$


! Declare passed arguments
  integer(i_kind),intent(in)             :: ftin
  type(diag_header_fix_list ),intent(in) :: header_fix
  logical,intent(in)                     :: retrieval
  type(diag_data_fix_list)   ,intent(out):: data_fix
  type(diag_data_chan_list)  ,pointer    :: data_chan(:)
  type(diag_data_extra_list) ,pointer    :: data_extra(:,:)
  integer(i_kind),intent(out)            :: iflag
    
! Declare local variables
  integer(i_kind),save :: nchan_last = -1
  integer(i_kind),save :: iextra_last = -1
  integer(i_kind) :: ich,iang,ndiag
  real(r_single),dimension(:,:),allocatable :: data_tmp

! Allocate arrays as needed
  if (header_fix%nchan /= nchan_last) then
     if (nchan_last > 0) then
        do ich=1,nchan_last
           deallocate(data_chan(ich)%bifix)
        end do
        deallocate(data_chan)
     endif
     allocate(data_chan(header_fix%nchan))
     do ich=1,header_fix%nchan
        allocate(data_chan(ich)%bifix(header_fix%angord+1))
     end do
     nchan_last = header_fix%nchan
  endif

  if (header_fix%iextra /= iextra_last) then
     if (iextra_last > 0) deallocate(data_extra)
     allocate(data_extra(header_fix%iextra,header_fix%jextra))
     iextra_last = header_fix%iextra
  endif

! Allocate array to hold data record
  allocate(data_tmp(header_fix%idiag,header_fix%nchan))

! Read data record
  if (header_fix%iextra == 0) then
     read(ftin,IOSTAT=iflag) data_fix, data_tmp
  else
     read(ftin,IOSTAT=iflag) data_fix, data_tmp, data_extra
  endif

! Transfer data record to output structure
  do ich=1,header_fix%nchan
     data_chan(ich)%tbobs =data_tmp(1,ich)
     data_chan(ich)%omgbc =data_tmp(2,ich)
     data_chan(ich)%omgnbc=data_tmp(3,ich)
     data_chan(ich)%errinv=data_tmp(4,ich)
     data_chan(ich)%qcmark=data_tmp(5,ich)
     data_chan(ich)%emiss =data_tmp(6,ich)
     data_chan(ich)%tlap  =data_tmp(7,ich)
  end do
  if (header_fix%iversion<iversion_radiag) then
     do ich=1,header_fix%nchan
        data_chan(ich)%bifix(1)=data_tmp(8,ich)
        data_chan(ich)%bilap   =data_tmp(9,ich)
        data_chan(ich)%bilap2  =data_tmp(10,ich)
        data_chan(ich)%bicons  =data_tmp(11,ich)
        data_chan(ich)%biang   =data_tmp(12,ich)
        data_chan(ich)%biclw   =data_tmp(13,ich)
        data_chan(ich)%bisst   = rmiss_radiag
        if (retrieval) then
           data_chan(ich)%biclw   =rmiss_radiag
           data_chan(ich)%bisst   =data_tmp(13,ich) 
        endif
     end do
  else
     do ich=1,header_fix%nchan
        data_chan(ich)%bicons=data_tmp(8,ich)
        data_chan(ich)%biang =data_tmp(9,ich)
        data_chan(ich)%biclw =data_tmp(10,ich)
        data_chan(ich)%bilap2=data_tmp(11,ich)
        data_chan(ich)%bilap =data_tmp(12,ich)
     end do
     do ich=1,header_fix%nchan
        do iang=1,header_fix%angord+1
           data_chan(ich)%bifix(iang)=data_tmp(12+iang,ich)
        end do
     end do
     data_chan(ich)%bisst = data_tmp(12+header_fix%angord+2,ich)  
  endif
  deallocate(data_tmp)
    
end subroutine read_radiag_data

end module read_diag

