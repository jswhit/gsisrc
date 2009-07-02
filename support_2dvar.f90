subroutine convert_binary_2d
!$$$  subprogram documentation block
!
! Adapted from convert_binary_mass
!   prgmmr: pondeca           org: np20                date: 2004-12-13
!
! abstract:
! Read in from restart file of 2dvar-only surface analysis and write 
! the result to temporary binary file expected by read_2d_guess. 
!
! program history log:
!   2004-12-13  pondeca
!   2006-04-06  middlecoff - change in_unit from 15 to 11 (big endian)
!                            and out_unit 55 to lendian_out
!   2006-09-15  treadon - use nhr_assimilation to build local guess filename
!   2007-03-13  derber - remove unused qsinv2 from jfunc use list
!   2008-04-03  safford - remove unused vars
!
! input argument list:
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$

  use kinds, only: r_single,i_kind
  use gsi_4dvar, only: nhr_assimilation
  use gsi_io, only: lendian_out
  implicit none

! Declare local parameters
  real(r_single),parameter:: one_single = 1.0_r_single
  real(r_single),parameter:: r45 = 45.0_r_single

  character(6) filename
  character(9) wrfges
  
  integer(i_kind) in_unit,status_hdr
  integer(i_kind) hdrbuf(512)

  integer(i_kind) iyear,imonth,iday,ihour,iminute,isecond
  integer(i_kind) nlon_regional,nlat_regional,nsig_regional
  real(r_single),allocatable::field2(:,:),field2b(:,:)
  real(r_single),allocatable::field2c(:,:)
  integer(i_kind),allocatable::ifield2(:,:)
  real(r_single) rad2deg_single
  
  data in_unit / 11 /

  wrfges = 'wrf_inout'
  open(in_unit,file=wrfges,form='unformatted')
  write(filename,100) nhr_assimilation
100 format('sigf',i2.2)
  open(lendian_out,file=filename,form='unformatted')


  write(6,*)' convert_binary_2d: in_unit,lendian_out=',in_unit,lendian_out
  rewind lendian_out


! Check for valid input file
  read(in_unit,iostat=status_hdr)hdrbuf
  if(status_hdr /= 0) then
     write(6,*)'CONVERT_BINARY_2D:  problem with wrfges = ',&
          trim(wrfges),', Status = ',status_hdr
     call stop2(74)
  endif


  read(in_unit) iyear,imonth,iday,ihour,iminute,isecond, &
                nlon_regional,nlat_regional,nsig_regional
  write(6,*)' convert_binary_2d: iy,m,d,h,m,s=',&
              iyear,imonth,iday,ihour,iminute,isecond
  write(6,*)' convert_binary_2d: nlon,lat,sig_regional=',&
              nlon_regional,nlat_regional,nsig_regional
  write(lendian_out) iyear,imonth,iday,ihour,iminute,isecond, &
              nlon_regional,nlat_regional,nsig_regional


  allocate(field2(nlon_regional,nlat_regional))
  allocate(field2b(nlon_regional,nlat_regional))
  allocate(field2c(nlon_regional,nlat_regional))
  allocate(ifield2(nlon_regional,nlat_regional))

  read(in_unit) field2b,field2c !DX_MC,DY_MC

!                  XLAT
   rad2deg_single=r45/atan(one_single)
   read(in_unit)field2
   write(6,*)' convert_binary_2d: max,min XLAT(:,1)=',&
               maxval(field2(:,1)),minval(field2(:,1))
   write(6,*)' convert_binary_2d: max,min XLAT(1,:)=',&
               maxval(field2(1,:)),minval(field2(1,:))
   write(6,*)' convert_binary_2d: xlat(1,1),xlat(nlon,1)=',&
               field2(1,1),field2(nlon_regional,1)
   write(6,*)' convert_binary_2d: xlat(1,nlat),xlat(nlon,nlat)=', &
               field2(1,nlat_regional),field2(nlon_regional,nlat_regional)
   field2=field2/rad2deg_single
   write(lendian_out)field2,field2b    !XLAT,DX_MC    


!                  XLONG
  read(in_unit)field2
  write(6,*)' convert_binary_2d: max,min XLONG(:,1)=',&
              maxval(field2(:,1)),minval(field2(:,1))
  write(6,*)' convert_binary_2d: max,min XLONG(1,:)=',&
              maxval(field2(1,:)),minval(field2(1,:))
  write(6,*)' convert_binary_2d: xlong(1,1),xlong(nlon,1)=',&
              field2(1,1),field2(nlon_regional,1)
  write(6,*)' convert_binary_2d: xlong(1,nlat),xlong(nlon,nlat)=', &
              field2(1,nlat_regional),field2(nlon_regional,nlat_regional)
  field2=field2/rad2deg_single
  write(lendian_out)field2,field2c   !  XLONG,DY_MC         


  read(in_unit)field2             !  psfc0
  write(6,*)' convert_binary_2d: max,min psfc0=',maxval(field2),minval(field2)
  write(6,*)' convert_binary_2d: mid psfc0=', & 
              field2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)field2           
   

  read(in_unit)field2             !  PHB (zsfc*g)
  write(6,*)' convert_binary_2d: max,min,mid PHB=', &
              maxval(field2),minval(field2), &
              field2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)field2    


  read(in_unit)field2             !  T  ! POT TEMP (sensible??)
  write(6,*)' convert_binary_2d: max,min,mid T=',&
              maxval(field2),minval(field2), &
              field2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)field2    
  

  read(in_unit)field2             !  Q
  write(6,*)' convert_binary_2d: max,min,mid Q=',&
              maxval(field2),minval(field2), &
              field2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)field2    


  read(in_unit)field2             !  U
  write(6,*)' convert_binary_2d: max,min,mid U=',&
              maxval(field2),minval(field2), &
              field2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)field2    


  read(in_unit)field2             !  V
  write(6,*)' convert_binary_2d: max,min,mid V=',&
              maxval(field2),minval(field2), &
              field2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)field2    


  read(in_unit)field2             !  LANDMASK  (1=land, 0=water)
  write(6,*)' convert_binary_2d: max,min landmask=', & 
              maxval(field2),minval(field2)
  write(6,*)' convert_binary_2d: mid landmask=', & 
              field2(nlon_regional/2,nlat_regional/2)
  write(6,*)' convert_binary_2d: landmask(1,1),landmask(nlon,1)=', &
              field2(1,1),field2(nlon_regional,1)
  write(6,*)' convert_binary_2d: landmask(1,nlat),landmask(nlon,nlat)=', &
              field2(1,nlat_regional),field2(nlon_regional,nlat_regional)
  write(lendian_out)field2    


  read(in_unit)field2             !  XICE
  write(6,*)' convert_binary_2d: max,min XICE=',maxval(field2),minval(field2)
  write(6,*)' convert_binary_2d: mid XICE=', & 
              field2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)field2    


  read(in_unit)field2             !  SST
  write(6,*)' convert_binary_2d: max,min SST=',&
              maxval(field2),minval(field2)
  write(6,*)' convert_binary_2d: mid SST=', & 
              field2(nlon_regional/2,nlat_regional/2)
  write(6,*)' convert_binary_2d: sst(1,1),sst(nlon,1)=',&
              field2(1,1),field2(nlon_regional,1)
  write(6,*)' convert_binary_2d: sst(1,nlat),sst(nlon,nlat)=', &
              field2(1,nlat_regional),field2(nlon_regional,nlat_regional)
  write(lendian_out)field2    


  read(in_unit)ifield2            !  IVGTYP
  write(6,*)' convert_binary_2d: max,min IVGTYP=', & 
              maxval(ifield2),minval(ifield2)
  write(6,*)' convert_binary_2d: mid IVGTYP=', & 
              ifield2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)ifield2    


  read(in_unit)ifield2            !  ISLTYP
  write(6,*)' convert_binary_2d: max,min ISLTYP=', & 
              maxval(ifield2),minval(ifield2)
  write(6,*)' convert_binary_2d: mid ISLTYP=', & 
              ifield2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)ifield2    


  read(in_unit)field2             !  VEGFRA
  write(6,*)' convert_binary_2d: max,min VEGFRA=',maxval(field2),minval(field2)
  write(6,*)' convert_binary_2d: mid VEGFRA=', & 
              field2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)field2    


  read(in_unit)field2             !  SNOW
  write(6,*)' convert_binary_2d: max,min SNO=',maxval(field2),minval(field2)
  write(6,*)' convert_binary_2d: mid SNO=',field2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)field2    


  read(in_unit)field2             !  U10
  write(6,*)' convert_binary_2d: max,min U10=',maxval(field2),minval(field2)
  write(6,*)' convert_binary_2d: mid U10=',field2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)field2    


  read(in_unit)field2             !  V10
  write(6,*)' convert_binary_2d: max,min V10=',maxval(field2),minval(field2)
  write(6,*)' convert_binary_2d: mid V10=',field2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)field2    


  read(in_unit)field2             !  SMOIS
  write(6,*)' convert_binary_2d: max,min SMOIS=',maxval(field2),minval(field2)
  write(6,*)' convert_binary_2d: mid SMOIS=',field2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)field2    


  read(in_unit)field2             !  TSLB
  write(6,*)' convert_binary_2d: max,min TSLB=',maxval(field2),minval(field2)
  write(6,*)' convert_binary_2d: mid TSLB=',field2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)field2    


  read(in_unit)field2             !  TSK
  write(6,*)' convert_binary_2d: max,min TSK=',maxval(field2),minval(field2)
  write(6,*)' convert_binary_2d: mid TSK=',field2(nlon_regional/2,nlat_regional/2)
  write(lendian_out)field2    

  close(in_unit)
  close(lendian_out)

  deallocate(field2,field2b,field2c)
  deallocate(ifield2)
end subroutine convert_binary_2d

!----------------------------------------------------------------------------------
subroutine read_2d_files(mype)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    read_2d_files   same as read_files, but for files used in 2dvar
!   Adapted from read_wrf_nmm_files
!   prgmmr: pondeca           org: np20                date: 2004-12-27
!
! abstract: figure out available time levels of background fields for
!             later input.
!
! program history log:
!   2004-12-27  pondeca
!   2006-04-06  middlecoff - remove mpi_request_null since not used
!   2008-04-03  safford    - remove uses mpi_status_size, zero_single (not used)
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
!$$$

  use kinds, only: r_kind,i_kind,r_single
  use mpimod, only: mpi_comm_world,ierror,mpi_rtype,npe
  use guess_grids, only: nfldsig,nfldsfc,ntguessig,ntguessfc,&
       ifilesig,ifilesfc,hrdifsig,hrdifsfc,create_gesfinfo
  use gsi_4dvar, only: nhr_assimilation
  use gridmod, only: regional_time,regional_fhr
  use constants, only: izero,zero,one,r60inv
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
  real(r_kind),dimension(202):: time_ges

!-----------------------------------------------------------------------------
! Start read_2d_files here.

  nhr_half=nhr_assimilation/2
  if(nhr_half*2.lt.nhr_assimilation) nhr_half=nhr_half+1
  npem1=npe-1

  do i=1,202
     time_ges(i) = 999
  end do

! Let a single task query the guess files.
  if(mype==npem1) then

!    Convert analysis time to minutes relative to fixed date
     call w3fs21(iadate,nminanl)
     write(6,*)'READ_2d_ FILES:  analysis date,minutes ',iadate,nminanl

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
           write(6,*)' READ_2d_FILES:  sigma guess file, nming2 ',hourg,idateg,nming2
           ndiff=nming2-nminanl
           if(abs(ndiff) > 60*nhr_half ) go to 110
           iwan=iwan+1
           time_ges(iwan) = (nming2-nminanl)*r60inv
           time_ges(iwan+100)=i+r0_001
        end if
110     continue
     end do
     time_ges(201)=one
     time_ges(202)=one
     if(iwan > 1)then
        do i=1,iwan
           do j=i+1,iwan 
              if(time_ges(j) < time_ges(i))then
                 temp=time_ges(i+100)
                 time_ges(i+100)=time_ges(j+100)
                 time_ges(j+100)=temp
                 temp=time_ges(i)
                 time_ges(i)=time_ges(j)
                 time_ges(j)=temp
              end if
           end do
           if(time_ges(i) < r0_001)time_ges(202) = i
        end do
     end if
     time_ges(201) = iwan+r0_001
  end if

! Broadcast guess file information to all tasks
  call mpi_bcast(time_ges,202,mpi_rtype,npem1,mpi_comm_world,ierror)

  nfldsig   = nint(time_ges(201))
  nfldsfc   = nfldsig

! Allocate space for guess information files
  call create_gesfinfo

  do i=1,nfldsig
     ifilesig(i) = -100
     hrdifsig(i) = zero
  end do

  do i=1,nfldsfc
     ifilesfc(i) = -100
     hrdifsfc(i) = zero
  end do

! Load time information for sigma guess field sinfo into output arrays
  ntguessig = nint(time_ges(202))
  do i=1,nfldsig
     hrdifsig(i) = time_ges(i)
     ifilesig(i) = nint(time_ges(i+100))
  end do
  if(mype == 0) write(6,*)' READ_2d_FILES:  sigma fcst files used in analysis  :  ',&
       (ifilesig(i),i=1,nfldsig),(hrdifsig(i),i=1,nfldsig),ntguessig
  
  
! Think of guess sfcf files as coinciding with guess sigf files
  ntguessfc = ntguessig
  do i=1,nfldsig
     ntguessfc = ntguessig
     hrdifsfc(i) = hrdifsig(i)
     ifilesfc(i) = ifilesig(i)
  end do
  if(mype == 0) write(6,*)' READ_2d_FILES:  surface fcst files used in analysis:  ',&
       (ifilesfc(i),i=1,nfldsfc),(hrdifsfc(i),i=1,nfldsfc),ntguessfc
  
!
! End of routine
  return
  end subroutine read_2d_files

!----------------------------------------------------------------------------------
subroutine read_2d_guess(mype)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    read_2d_guess      read 2d interface file
!
!   Adapted from read_wrf_mass_guess
!   prgmmr: pondeca           org: np20                date: 2005-01-06
!
! abstract:   read guess from a binary file created in a previous step
!             that interfaces with the restart file which may be
!             written in a different format. The a-grid is assumed.
!             The guess is read in by complete horizontal fields, one field
!             per processor, in parallel.  
!
! program history log:
!   2005-01-06  pondeca
!   2005-11-29  derber - remove external iteration dependent calculations
!   2006-02-02  treadon - remove unused quanities from use guess_grids
!   2006-04-06  middlecoff - changed nfcst from 11 to 15 so nfcst could be used as little endian
!   2006-07-30  kleist - make change to ges_ps from ln(ps)
!   2006-07-28  derber  - include sensible temperature
!   2008-04-02  safford - rm unused vars and uses     
!
!   input argument list:
!     mype     - pe number
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,i_kind,r_single
  use mpimod, only: mpi_sum,mpi_integer,mpi_real4,mpi_comm_world,npe,ierror
  use jfunc, only: qsatg,jiter,jiterstart,qgues,dqdrh
  use guess_grids, only: ges_z,ges_ps,ges_tv,ges_q,ges_cwmr,ges_vor,&
       ges_div,ges_u,ges_v,ges_tvlat,ges_tvlon,ges_qlat,ges_qlon,&
       fact10,soil_type,veg_frac,veg_type,sfct,sno,soil_temp,soil_moi,&
       isli,ntguessig,nfldsig,ifilesig,ges_tsen
  use gridmod, only: lat2,lon2,lon1,lat1,nlat_regional,nlon_regional,&
       nsig,ijn_s,displs_s,eta1_ll,pt_ll,itotsub
  use constants, only: zero,one,grav,fv,zero_single,rd,cp_mass
  implicit none

! Declare passed variables
  integer(i_kind),intent(in):: mype

! Declare local parameters
  real(r_kind),parameter:: r0_01=0.01_r_kind
  real(r_kind),parameter:: r0_1=0.1_r_kind

! Declare local variables
  integer(i_kind) kt,kq,ku,kv

! 2D variable names stuck in here
  integer(i_kind) nfcst

! other internal variables
  real(r_single) tempa(itotsub)
  real(r_single),allocatable::temp1(:,:),temp1u(:,:),temp1v(:,:)
  real(r_single),allocatable::all_loc(:,:,:)
  integer(i_kind),allocatable::itemp1(:,:)
  integer(i_kind),allocatable::igtype(:),jsig_skip(:)
  character(60),allocatable::identity(:)
  character(6) filename 
  integer(i_kind) irc_s_reg(npe),ird_s_reg(npe)
  integer(i_kind) ifld,im,jm,lm,num_2d_fields
  integer(i_kind) num_all_fields,num_loc_groups,num_all_pad
  integer(i_kind) i,icount,icount_prev,it,j,k
  integer(i_kind) i_0,i_psfc,i_fis,i_t,i_q,i_u,i_v,i_sno,i_u10,i_v10,i_smois,i_tslb
  integer(i_kind) i_sm,i_xice,i_sst,i_tsk,i_ivgtyp,i_isltyp,i_vegfrac
  integer(i_kind) isli_this
  real(r_kind) psfc_this,sm_this,xice_this
  integer(i_kind) num_doubtful_sfct,num_doubtful_sfct_all


!  RESTART FILE input grid dimensions in module gridmod
!      These are the following:
!          im -- number of x-points on C-grid
!          jm -- number of y-points on C-grid
!          lm -- number of vertical levels ( = nsig for now)


  num_doubtful_sfct=0
  if(mype==0) write(6,*)' at 0 in read_2d_guess'


! Big section of operations done only on first outer iteration

     if(mype==0) write(6,*)' at 0.1 in read_2d_guess'

     im=nlon_regional
     jm=nlat_regional
     lm=nsig

!    Following is for convenient 2D input
     num_2d_fields=18! Adjust once exact content of RTMA restart file is known
     num_all_fields=num_2d_fields*nfldsig
     num_loc_groups=num_all_fields/npe
     if(mype==0) write(6,'(" at 1 in read_2d_guess, lm            =",i6)')lm
     if(mype==0) write(6,'(" at 1 in read_2d_guess, num_2d_fields=",i6)')num_2d_fields
     if(mype==0) write(6,'(" at 1 in read_2d_guess, nfldsig       =",i6)')nfldsig
     if(mype==0) write(6,'(" at 1 in read_2d_guess, num_all_fields=",i6)')num_all_fields
     if(mype==0) write(6,'(" at 1 in read_2d_guess, npe           =",i6)')npe
     if(mype==0) write(6,'(" at 1 in read_2d_guess, num_loc_groups=",i6)')num_loc_groups
     do 
        num_all_pad=num_loc_groups*npe
        if(num_all_pad >= num_all_fields) exit
        num_loc_groups=num_loc_groups+1
     end do
     if(mype==0) write(6,'(" at 1 in read_2d_guess, num_all_pad   =",i6)')num_all_pad
     if(mype==0) write(6,'(" at 1 in read_2d_guess, num_loc_groups=",i6)')num_loc_groups

     allocate(all_loc(lat1+2,lon1+2,num_all_pad))
     allocate(jsig_skip(num_2d_fields))
     allocate(igtype(num_2d_fields))
     allocate(identity(num_2d_fields))

!    igtype is a flag indicating whether each input field is h-, u-, or v-grid
!    and whether integer or real
!     abs(igtype)=1 for h-grid
!                =2 for u-grid
!                =3 for v-grid
!     igtype < 0 for integer field

     i=0
     i=i+1 ; i_psfc=i                                                ! psfc
     write(identity(i),'("record ",i3,"--psfc")')i
     jsig_skip(i)=3     ! number of files to skip before getting to psfc
     igtype(i)=1
     i=i+1 ; i_fis=i                                               ! sfc geopotential
     write(identity(i),'("record ",i3,"--fis")')i
     jsig_skip(i)=0 
     igtype(i)=1
     i_t=i+1
     do k=1,lm
        i=i+1                                                       ! t(k)  (sensible temp)
        write(identity(i),'("record ",i3,"--t(",i2,")")')i,k
        jsig_skip(i)=0
        igtype(i)=1
     end do
     i_q=i+1
     do k=1,lm
        i=i+1                                                       ! q(k)
        write(identity(i),'("record ",i3,"--q(",i2,")")')i,k
        jsig_skip(i)=0 ; igtype(i)=1
     end do
     i_u=i+1
     do k=1,lm
        i=i+1                                                       ! u(k)
        write(identity(i),'("record ",i3,"--u(",i2,")")')i,k
        jsig_skip(i)=0 ; igtype(i)=2
     end do
     i_v=i+1
     do k=1,lm
        i=i+1                                                       ! v(k)
        write(identity(i),'("record ",i3,"--v(",i2,")")')i,k
        jsig_skip(i)=0 ; igtype(i)=3
     end do
     i=i+1   ; i_sm=i                                              ! landmask
     write(identity(i),'("record ",i3,"--sm")')i
     jsig_skip(i)=0 ; igtype(i)=1
     i=i+1 ; i_xice=i                                              ! xice
     write(identity(i),'("record ",i3,"--xice")')i
     jsig_skip(i)=0 ; igtype(i)=1
     i=i+1 ; i_sst=i                                               ! sst
     write(identity(i),'("record ",i3,"--sst")')i
     jsig_skip(i)=0 ; igtype(i)=1
     i=i+1 ; i_ivgtyp=i                                            ! ivgtyp
     write(identity(i),'("record ",i3,"--ivgtyp")')i
     jsig_skip(i)=0 ; igtype(i)=-1
     i=i+1 ; i_isltyp=i                                            ! isltyp
     write(identity(i),'("record ",i3,"--isltyp")')i
     jsig_skip(i)=0 ; igtype(i)=-1
     i=i+1 ; i_vegfrac=i                                           ! vegfrac
     write(identity(i),'("record ",i3,"--vegfrac")')i
     jsig_skip(i)=0 ; igtype(i)=1
     i=i+1 ; i_sno=i                                               ! sno
     write(identity(i),'("record ",i3,"--sno")')i
     jsig_skip(i)=0 ; igtype(i)=1
     i=i+1 ; i_u10=i                                               ! u10
     write(identity(i),'("record ",i3,"--u10")')i
     jsig_skip(i)=0 ; igtype(i)=1
     i=i+1 ; i_v10=i                                               ! v10
     write(identity(i),'("record ",i3,"--v10")')i
     jsig_skip(i)=0 ; igtype(i)=1
     i=i+1 ; i_smois=i                                             ! smois
     write(identity(i),'("record ",i3,"--smois(",i2,")")')i,k
     jsig_skip(i)=0 ; igtype(i)=1
     i=i+1 ; i_tslb=i                                              ! tslb
     write(identity(i),'("record ",i3,"--tslb(",i2,")")')i,k
     jsig_skip(i)=0 ; igtype(i)=1
     i=i+1 ; i_tsk=i                                               ! tsk
     write(identity(i),'("record ",i3,"--sst")')i
     jsig_skip(i)=0 ; igtype(i)=1

!    End of stuff from 2D restart file

     allocate(temp1(im,jm),itemp1(im,jm),temp1u(im+1,jm),temp1v(im,jm+1))
     
     do i=1,npe
        irc_s_reg(i)=ijn_s(mype+1)
     end do
     ird_s_reg(1)=0
     do i=1,npe
        if(i /= 1) ird_s_reg(i)=ird_s_reg(i-1)+irc_s_reg(i-1)
     end do
     
!    Read fixed format input file created from external interface
!    This is done by reading in parallel from every pe, and redistributing
!    to local domains once for every npe fields read in, using 
!    mpi_all_to_allv

     nfcst=15
     icount=0
     icount_prev=1
     do it=1,nfldsig
        write(filename,'("sigf",i2.2)')ifilesig(it)
        open(nfcst,file=filename,form='unformatted') ; rewind nfcst
        write(6,*)'READ_2d_GUESS:  open nfcst=',nfcst,' to file=',filename

!       Read, interpolate, and distribute 2D restart fields
        do ifld=1,num_2d_fields
           icount=icount+1
           if(jsig_skip(ifld) > 0) then
              do i=1,jsig_skip(ifld)
                 read(nfcst)
              end do
           end if
           if(mype==mod(icount-1,npe)) then
              if(igtype(ifld)==1 .or. igtype(ifld)==2 .or. igtype(ifld)==3) then
                 read(nfcst)((temp1(i,j),i=1,im),j=1,jm)
                 write(6,'(" ifld, temp1(im/2,jm/2)=",i6,e15.5)')ifld,temp1(im/2,jm/2)
                 call fill_mass_grid2t(temp1,im,jm,tempa,1)
              end if
              if(igtype(ifld) < 0) then
                 read(nfcst)((itemp1(i,j),i=1,im),j=1,jm)
                 do j=1,jm
                    do i=1,im
                       temp1(i,j)=itemp1(i,j)
                    end do
                 end do
                 write(6,'(" ifld, temp1(im/2,jm/2)=",i6,e15.5)')ifld,temp1(im/2,jm/2)
                 call fill_mass_grid2t(temp1,im,jm,tempa,1)
              end if
           else
              read(nfcst)
           end if

!          Distribute to local domains everytime we have npe fields
           if(mod(icount,npe) == 0.or.icount==num_all_fields) then
              call mpi_alltoallv(tempa,ijn_s,displs_s,mpi_real4, &
                   all_loc(1,1,icount_prev),irc_s_reg,ird_s_reg,mpi_real4,mpi_comm_world,ierror)
              icount_prev=icount+1
           end if
        end do
        close(nfcst)
     end do
!   do kv=i_v,i_v+nsig-1
!    if(mype==0) write(6,*)' at 1.15, kv,mype,j,i,v=', &
!         kv,mype,2,1,all_loc(2,1,kv)
!   end do


!    Next do conversion of units as necessary and
!    reorganize into WeiYu's format--

     do it=1,nfldsig
        i_0=(it-1)*num_2d_fields
        kt=i_0+i_t-1
        kq=i_0+i_q-1
        ku=i_0+i_u-1
        kv=i_0+i_v-1

        do k=1,nsig
           kt=kt+1
           kq=kq+1
           ku=ku+1
           kv=kv+1
           do i=1,lon1+2
              do j=1,lat1+2
                 ges_u(j,i,k,it) = all_loc(j,i,ku)
                 ges_v(j,i,k,it) = all_loc(j,i,kv)
                 ges_vor(j,i,k,it) = zero
                 ges_q(j,i,k,it)   = all_loc(j,i,kq)
                 ges_tsen(j,i,k,it)  = all_loc(j,i,kt) 
              end do
           end do
        end do
        do i=1,lon1+2
           do j=1,lat1+2
              ges_z(j,i,it)    = all_loc(j,i,i_0+i_fis)/grav ! surface elevation multiplied by g

!             convert input psfc to psfc in mb, and then to log(psfc) in cb
              
              psfc_this=r0_01*all_loc(j,i,i_0+i_psfc)
              ges_ps(j,i,it)=r0_1*psfc_this   ! convert from mb to cb
              sno(j,i,it)=all_loc(j,i,i_0+i_sno)
              soil_moi(j,i,it)=all_loc(j,i,i_0+i_smois)
              soil_temp(j,i,it)=all_loc(j,i,i_0+i_tslb)
           end do
        end do
        
        if(mype==10) write(6,*)' in read_2d_guess, min,max(soil_moi)=', &
             minval(soil_moi),maxval(soil_moi)
        if(mype==10) write(6,*)' in read_2d_guess, min,max(soil_temp)=', &
             minval(soil_temp),maxval(soil_temp)


!       Convert sensible temp to virtual temp  
        do k=1,nsig
           do i=1,lon1+2
              do j=1,lat1+2
                 ges_tv(j,i,k,it) = ges_tsen(j,i,k,it) * (one+fv*ges_q(j,i,k,it))
              end do
           end do
        end do
     end do

     
!    Zero out fields not used
     ges_div=zero
     ges_cwmr=zero
     ges_tvlat=zero
     ges_tvlon=zero
     ges_qlat=zero
     ges_qlon=zero

     
!    Transfer surface fields
     do it=1,nfldsig
        i_0=(it-1)*num_2d_fields
        do i=1,lon1+2
           do j=1,lat1+2
              fact10(j,i,it)=one    !  later fix this by using correct w10/w(1)
              veg_type(j,i,it)=all_loc(j,i,i_0+i_ivgtyp)
              veg_frac(j,i,it)=r0_01*all_loc(j,i,i_0+i_vegfrac)
              soil_type(j,i,it)=all_loc(j,i,i_0+i_isltyp)
              sm_this=zero
              if(all_loc(j,i,i_0+i_sm) /= zero_single) sm_this=one
              xice_this=zero
              if(all_loc(j,i,i_0+i_xice) /= zero_single) xice_this=one
              
              isli_this=0
              if(xice_this==one) isli_this=2
              if(xice_this==zero.and.sm_this==one) isli_this=1
              isli(j,i,it)=isli_this
              
              sfct(j,i,it)=all_loc(j,i,i_0+i_sst)
              if(isli(j,i,it) /= 0) sfct(j,i,it)=all_loc(j,i,i_0+i_tsk)
              if(sfct(j,i,it) < one) then

!             For now, replace missing skin temps with 1st sigma level temp
                 sfct(j,i,it)=all_loc(j,i,i_0+i_t) 
!                write(6,*)' doubtful skint replaced with 1st sigma level t, j,i,mype,sfct=',&
!                     j,i,mype,sfct(j,i,it)
                 num_doubtful_sfct=num_doubtful_sfct+1
              end if
           end do
        end do
     end do
     
     call mpi_reduce(num_doubtful_sfct,num_doubtful_sfct_all,1,mpi_integer,mpi_sum,&
          0,mpi_comm_world,ierror)
     if(mype==0) write(6,*)' in read_2d_guess, num_doubtful_sfct_all = ',num_doubtful_sfct_all
     if(mype==10) write(6,*)' in read_2d_guess, min,max(sfct)=', &
          minval(sfct),maxval(sfct)
     if(mype==10) write(6,*)' in read_2d_guess, min,max(veg_type)=', &
          minval(veg_type),maxval(veg_type)
     if(mype==10) write(6,*)' in read_2d_guess, min,max(veg_frac)=', &
          minval(veg_frac),maxval(veg_frac)
     if(mype==10) write(6,*)' in read_2d_guess, min,max(soil_type)=', &
          minval(soil_type),maxval(soil_type)
     if(mype==10) write(6,*)' in read_2d_guess, min,max(isli)=', &
          minval(isli),maxval(isli)
     
     deallocate(all_loc,jsig_skip,igtype,identity)
     deallocate(temp1,itemp1,temp1u,temp1v)


     return
end subroutine read_2d_guess

!----------------------------------------------------------------------------------
subroutine wr2d_binary(mype)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    wr2d_binary              write out 2D restart file
! Adpated from wrwrfmassa.
!   prgmmr: pondeca           org: np20                date: 2005-2-7
!
!   abstract: read 2D guess restart interface file, add analysis
!             increment, and write out 2D analysis restart
!             interface file.
!
! program history log:
!   2005-02-07  pondeca
!   2006-04-06  middlecoff - Changed iog from 11 to 15 so iog could be little endian
!                          Changed ioan from 51 to 66 so ioan could be little endian
!   2006-07-28 derber - include sensible temperature
!   2006-07-31  kleist - make change to ges_ps instead of ln(ps)
!   2008-04-03  safford - rm unused vars and uses
!
!   input argument list:
!     mype     - pe number
!
!   output argument list:
!     no output arguments
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,r_single,i_kind
  use guess_grids, only: ntguessfc,ntguessig,ifilesig,sfct,ges_ps,&
       ges_tv,ges_q,ges_u,ges_v,ges_tsen
  use mpimod, only: mpi_comm_world,ierror,mpi_real4,strip_single
  use gridmod, only: pt_ll,eta1_ll,lat2,iglobal,itotsub,update_regsfc,displs_s,&
       ijn_s,lon2,nsig,lon1,lat1,nlon_regional,nlat_regional,ijn,displs_g
  use constants, only: one,fv,zero_single
  use jfunc, only: qsatg
  implicit none

! Declare passed variables
  integer(i_kind),intent(in):: mype

! Declare local parameters
  real(r_kind),parameter:: r10=10.0_r_kind
  real(r_kind),parameter:: r100=100.0_r_kind
  real(r_kind),parameter:: r225=225.0_r_kind

! Declare local variables
  integer(i_kind) im,jm,lm
  real(r_single),allocatable::temp1(:),temp1u(:),temp1v(:),tempa(:),tempb(:)
  real(r_single),allocatable::all_loc(:,:,:)
  real(r_single),allocatable::strp(:)
  character(6) filename
  integer(i_kind) iog,ioan,i,j,k,kt,kq,ku,kv,it,i_psfc,i_t,i_q,i_u,i_v
  integer(i_kind) i_sst,i_skt
  integer(i_kind) num_2d_fields,num_all_fields,num_all_pad
  integer(i_kind) regional_time0(6),nlon_regional0,nlat_regional0,nsig0
  real(r_kind) psfc_this
  real(r_single) glon0(nlon_regional,nlat_regional),glat0(nlon_regional,nlat_regional)
  real(r_single) dx_mc0(nlon_regional,nlat_regional),dy_mc0(nlon_regional,nlat_regional)
  real(r_single),allocatable::all_loc_ps(:,:),temp1_ps(:)
  real(r_single),allocatable::all_loc_qsatg(:,:,:),all_loc_prh(:,:,:),temp1_prh(:)

  im=nlon_regional
  jm=nlat_regional
  lm=nsig

  num_2d_fields=3+4*lm
  num_all_fields=num_2d_fields
  num_all_pad=num_all_fields
  allocate(all_loc(lat1+2,lon1+2,num_all_pad))
  allocate(strp(lat1*lon1))
  allocate(all_loc_ps(lat1+2,lon1+2))
  allocate(all_loc_qsatg(lat1+2,lon1+2,nsig),all_loc_prh(lat1+2,lon1+2,nsig))

  i_psfc=1
  i_t=2
  i_q=i_t+lm
  i_u=i_q+lm
  i_v=i_u+lm
  i_sst=i_v+lm
  i_skt=i_sst+1
  
  allocate(temp1(im*jm),temp1u((im+1)*jm),temp1v(im*(jm+1)))
  allocate(temp1_ps(im*jm))
  allocate(temp1_prh(im*jm))

  if(mype == 0) write(6,*)' at 2 in wr2d_binary'

  iog=15
  ioan=66
  if(mype == 0) then
     write(filename,'("sigf",i2.2)')ifilesig(ntguessig)
     open (iog,file=filename,form='unformatted')
     open (ioan,file='siganl',form='unformatted')
     rewind iog ; rewind ioan
  end if

! Convert analysis variables to 2D variables
  it=ntguessig
  
! Create all_loc from ges_*
  if(mype == 0) write(6,*)' at 3 in wr2d_binary'
  all_loc=zero_single
  kt=i_t-1
  kq=i_q-1
  ku=i_u-1
  kv=i_v-1
  do k=1,nsig
     kt=kt+1
     kq=kq+1
     ku=ku+1
     kv=kv+1
     do i=1,lon2
        do j=1,lat2
           all_loc(j,i,ku)=ges_u(j,i,k,it)
           all_loc(j,i,kv)=ges_v(j,i,k,it)
           all_loc(j,i,kq)=ges_q(j,i,k,it)
           all_loc(j,i,kt)=ges_tsen(j,i,k,it)   ! sensible temperature
           all_loc_qsatg(j,i,k)=qsatg(j,i,k)
           all_loc_prh(j,i,k)=ges_q(j,i,k,it)/qsatg(j,i,k)
        end do
     end do
  end do
  do i=1,lon2
     do j=1,lat2
        psfc_this=r10*ges_ps(j,i,it)   ! convert from cb to mb
        all_loc(j,i,i_psfc)=r100*psfc_this
        all_loc_ps(j,i)=ges_ps(j,i,it)
     end do
  end do
  
  if(mype == 0) then
     read(iog) regional_time0,nlon_regional0,nlat_regional0,nsig0
     write(ioan) regional_time0,nlon_regional0,nlat_regional0,nsig0
     read(iog) glat0,dx_mc0
     write(ioan) glat0,dx_mc0
     read(iog) glon0,dy_mc0
     write(ioan) glon0,dy_mc0
  end if
  
! Update psfc
  if(mype == 0) write(6,*)' at 6 in wr2d_binary'

  allocate(tempa(itotsub),tempb(itotsub))
  if(mype == 0) then
   read(iog)temp1
   temp1_ps=log(temp1/r100/r10)
  endif
   call strip_single(all_loc(1,1,i_psfc),strp,1)
  call mpi_gatherv(strp,ijn(mype+1),mpi_real4, &
       tempa,ijn,displs_g,mpi_real4,0,mpi_comm_world,ierror)
  if(mype == 0) then
     call fill_mass_grid2t(temp1,im,jm,tempb,2)
     do i=1,iglobal
        tempa(i)=tempa(i)-tempb(i)
     end do
     call unfill_mass_grid2t(tempa,im,jm,temp1)
     write(ioan)temp1
  end if

  call strip_single(all_loc_ps,strp,1)
  call mpi_gatherv(strp,ijn(mype+1),mpi_real4, &
       tempa,ijn,displs_g,mpi_real4,0,mpi_comm_world,ierror)
  if(mype == 0) then
     call fill_mass_grid2t(temp1_ps,im,jm,tempb,2)
     do i=1,iglobal
        tempa(i)=tempa(i)-tempb(i)
     end do
     temp1_ps=zero_single
     call unfill_mass_grid2t(tempa,im,jm,temp1_ps)
  end if

!  FIS read/write
  if(mype == 0) then
     read(iog)temp1
     write(ioan)temp1
  end if

! Update t
  kt=i_t-1
  do k=1,nsig
     kt=kt+1
     if(mype == 0) read(iog)temp1
     call strip_single(all_loc(1,1,kt),strp,1)
     call mpi_gatherv(strp,ijn(mype+1),mpi_real4, &
          tempa,ijn,displs_g,mpi_real4,0,mpi_comm_world,ierror)
     if(mype == 0) then
        call fill_mass_grid2t(temp1,im,jm,tempb,2)
        do i=1,iglobal
           tempa(i)=tempa(i)-tempb(i)
        end do
        call unfill_mass_grid2t(tempa,im,jm,temp1)
        write(ioan)temp1
     end if
  end do

! Update q
  kq=i_q-1
  do k=1,nsig
     kq=kq+1 
     if(mype == 0) then
       read(iog)temp1
       temp1_prh=temp1
     endif
     call strip_single(all_loc(1,1,kq),strp,1)
     call mpi_gatherv(strp,ijn(mype+1),mpi_real4, &
          tempa,ijn,displs_g,mpi_real4,0,mpi_comm_world,ierror)
     if(mype == 0) then
        call fill_mass_grid2t(temp1,im,jm,tempb,2)
        do i=1,iglobal
           tempa(i)=tempa(i)-tempb(i)
        end do
        call unfill_mass_grid2t(tempa,im,jm,temp1)
        write(ioan)temp1
     end if

     call strip_single(all_loc_qsatg(1,1,k),strp,1)
     call mpi_gatherv(strp,ijn(mype+1),mpi_real4, &
          tempa,ijn,displs_g,mpi_real4,0,mpi_comm_world,ierror)
     if(mype == 0) then
        call fill_mass_grid2t(temp1_prh,im,jm,tempb,2)
        do i=1,iglobal
           tempb(i)=tempb(i)/tempa(i)
         end do
     end if
     call strip_single(all_loc_prh(1,1,k),strp,1)
     call mpi_gatherv(strp,ijn(mype+1),mpi_real4, &
          tempa,ijn,displs_g,mpi_real4,0,mpi_comm_world,ierror)
     if(mype == 0) then
        do i=1,iglobal
           tempa(i)=tempa(i)-tempb(i)
        end do
        temp1_prh=zero_single
        call unfill_mass_grid2t(tempa,im,jm,temp1_prh)
     end if
  end do

! Update u
  ku=i_u-1
  do k=1,nsig
     ku=ku+1   
     if(mype == 0) read(iog)temp1
     call strip_single(all_loc(1,1,ku),strp,1)
     call mpi_gatherv(strp,ijn(mype+1),mpi_real4, &
          tempa,ijn,displs_g,mpi_real4,0,mpi_comm_world,ierror)
     if(mype == 0) then
        call fill_mass_grid2t(temp1,im,jm,tempb,2)
      do i=1,iglobal
        tempa(i)=tempa(i)-tempb(i)
      end do
      call unfill_mass_grid2t(tempa,im,jm,temp1)
      write(ioan)temp1
    end if
  end do

! Update v
  kv=i_v-1
  do k=1,nsig
     kv=kv+1
     if(mype == 0) read(iog)temp1
     call strip_single(all_loc(1,1,kv),strp,1)
     call mpi_gatherv(strp,ijn(mype+1),mpi_real4, &
          tempa,ijn,displs_g,mpi_real4,0,mpi_comm_world,ierror)
     if(mype == 0) then
        call fill_mass_grid2t(temp1,im,jm,tempb,2)
        do i=1,iglobal
           tempa(i)=tempa(i)-tempb(i)
        end do
        call unfill_mass_grid2t(tempa,im,jm,temp1)
        write(ioan)temp1
     end if
  end do

  if (mype==0) then
     write(ioan)temp1_ps !increment of ps
     write(ioan)temp1_prh  !increment of pseudo RH
  endif
  
! Load updated skin temperature array if writing out to analysis file
  if (update_regsfc) then ! set to .false.
     do i=1,lon1+2
        do j=1,lat1+2
           all_loc(j,i,i_sst)=sfct(j,i,ntguessfc)
           all_loc(j,i,i_skt)=sfct(j,i,ntguessfc)
        end do
     end do
  end if

  if(mype == 0) then
! SM
     read(iog)temp1
     write(ioan)temp1
! SICE
     read(iog)temp1
     write(ioan)temp1
  end if

! SST
  if(update_regsfc) then
     if(mype == 0) read(iog)temp1
     if (mype==0)write(6,*)' at 9.1 in wr2d_binary,max,min(temp1)=',maxval(temp1),minval(temp1)
     call strip_single(all_loc(1,1,i_sst),strp,1)
     call mpi_gatherv(strp,ijn(mype+1),mpi_real4, &
          tempa,ijn,displs_g,mpi_real4,0,mpi_comm_world,ierror)
     if(mype == 0) then
        if(mype == 0) write(6,*)' at 9.2 in wr2d_binary,max,min(tempa)=',maxval(tempa),minval(tempa)
        call fill_mass_grid2t(temp1,im,jm,tempb,2)
        do i=1,iglobal
           if(tempb(i) < (r225)) then
              tempa(i)=zero_single
           else
              tempa(i)=tempa(i)-tempb(i)
           end if
        end do
        if(mype == 0) write(6,*)' at 9.4 in wr2d_binary,max,min(tempa)=',maxval(tempa),minval(tempa)
        call unfill_mass_grid2t(tempa,im,jm,temp1)
        write(6,*)' at 9.6 in wr2d_binary,max,min(temp1)=',maxval(temp1),minval(temp1)
        write(ioan)temp1
     end if     !endif mype==0
  else
     if(mype==0) then
        read(iog)temp1
        write(ioan)temp1
     end if
  end if   !end if check updatesfc
  
! REST OF FIELDS
  if (mype == 0) then
     do k=4,11
        read(iog)temp1
        write(ioan)temp1
     end do
  end if
  
! Update SKIN TEMP
  if(update_regsfc) then
     if(mype == 0) read(iog)temp1
     if (mype==0)write(6,*)' at 10.0 in wr2d_binary,max,min(temp1)=',maxval(temp1),minval(temp1)
     call strip_single(all_loc(1,1,i_skt),strp,1)
     call mpi_gatherv(strp,ijn(mype+1),mpi_real4, &
          tempa,ijn,displs_g,mpi_real4,0,mpi_comm_world,ierror)
     if(mype == 0) then
        call fill_mass_grid2t(temp1,im,jm,tempb,2)
        do i=1,iglobal
           if(tempb(i) < (r225)) then
              tempa(i)=zero_single
           else 
              tempa(i)=tempa(i)-tempb(i)
           end if
        end do
        call unfill_mass_grid2t(tempa,im,jm,temp1)
        write(ioan)temp1
     end if
  else
     if (mype == 0) then
        read(iog)temp1
        write(ioan)temp1
     end if
  end if

  if (mype==0) then
     close(iog)
     close(ioan)
  endif

! Write out qsatg for gsi-2dvar post-processing purposes
  do k=1,nsig
     call strip_single(all_loc_qsatg(1,1,k),strp,1)
     call mpi_gatherv(strp,ijn(mype+1),mpi_real4, &
          tempa,ijn,displs_g,mpi_real4,0,mpi_comm_world,ierror)
     if(mype == 0) then
      temp1=zero_single
      call unfill_mass_grid2t(tempa,im,jm,temp1)
      open (94,file='bckg_qsat.dat',form='unformatted')
      write(94) temp1
      close(94)
    end if
  end do

  deallocate(all_loc)
  deallocate(all_loc_ps)
  deallocate(temp1_ps)
  deallocate(temp1)
  deallocate(tempa)
  deallocate(tempb)
  deallocate(temp1u)
  deallocate(temp1v)
  deallocate(temp1_prh)
  deallocate(all_loc_qsatg)
  deallocate(all_loc_prh)
  deallocate(strp)
  
end subroutine wr2d_binary
!----------------------------------------------------------------------------------
