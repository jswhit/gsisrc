module sfcobsqc
!$$$  module documentation block
!                .      .    .                                       .
! module:    sfcobsqc
!
! abstract: contains subroutines for the qc of surface obs based
!           on (i) the provider uselist for mesonet winds, (ii) 
!           station uselist for mesonet winds, and (iii) rejectlists 
!           for any ob type (u and v-wind, wind speed, temperatature, 
!           moisture, surface pressure). the code inquires for the 
!           existence of thsese lists in the gsi working directorty 
!           and applies them if present.
!           
!
! program history log:
!   2007-10-19  pondeca
!
! Uses:
  use kinds, only: i_kind,r_kind

  private

  implicit none

  character(16),allocatable,dimension(:)::cprovider
  character(5),allocatable,dimension(:)::csta_winduse
  character(80),allocatable,dimension(:)::w_rjlist,t_rjlist,p_rjlist,q_rjlist

  integer(i_kind) nprov,nwrjs,ntrjs,nprjs,nqrjs,nsta_mesowind_use

  logical listexist
  logical wlistexist
  logical tlistexist
  logical plistexist
  logical qlistexist
  logical listexist2

  public init_rjlists
  public get_usagerj
  public destroy_rjlists

contains

subroutine init_rjlists

!$$$  module documentation block
! abstract: initialize qc lists 

  implicit none

! Declare passed variables
! integer(i_kind),intent(in):: mype

! Declare local variables
  integer(i_kind) meso_unit,ncount,m
  character(80) cstring

  integer(i_kind), parameter::nmax=10000

  data meso_unit / 20 /
!**************************************************************************
  allocate(cprovider(200))
  allocate(w_rjlist(nmax))
  allocate(t_rjlist(nmax))
  allocate(p_rjlist(nmax))
  allocate(q_rjlist(nmax))
  allocate(csta_winduse(nmax))

!==> Read mesonet provider names from the uselist if it exists.
 inquire(file='mesonetuselist',exist=listexist)
 if(listexist) then
     open (meso_unit,file='mesonetuselist',form='formatted')
     ncount=0
     do m=1,3
      read(meso_unit,*,end=131) cstring
     enddo
130  continue
     ncount=ncount+1
     read(meso_unit,*,end=131) cprovider(ncount)
     goto 130
131  continue
     nprov=ncount-1
     print*,'mesonetuselist: nprov=',nprov
 endif
 close(meso_unit)
!
!==> Read in station names from the reject list for wind if it exists
 inquire(file='w_rejectlist',exist=wlistexist)
 if(wlistexist) then
     open (meso_unit,file='w_rejectlist',form='formatted')
     ncount=0
     do m=1,3
      read(meso_unit,*,end=141) cstring
     enddo
140  continue
     ncount=ncount+1
     read(meso_unit,*,end=141) w_rjlist(ncount)
     goto 140
141  continue
     nwrjs=ncount-1
     print*,'w_rejectlist: nwrjs=',nwrjs
   endif
 close(meso_unit)
!
!==> Read in station names from the reject list for temperature if it exists
 inquire(file='t_rejectlist',exist=tlistexist)
 if(tlistexist) then
     open (meso_unit,file='t_rejectlist',form='formatted')
     ncount=0
     do m=1,3
      read(meso_unit,*,end=151) cstring
     enddo
150  continue
     ncount=ncount+1
     read(meso_unit,*,end=151) t_rjlist(ncount)
     goto 150
151  continue
     ntrjs=ncount-1
     print*,'t_rejectlist: ntrjs=',ntrjs
   endif
 close(meso_unit)
!
!==> Read in station names from the reject list for surface pressure if it exists
 inquire(file='p_rejectlist',exist=plistexist)
 if(plistexist) then
     open (meso_unit,file='p_rejectlist',form='formatted')
     ncount=0
     do m=1,3
      read(meso_unit,*,end=161) cstring
     enddo
160  continue
     ncount=ncount+1
     read(meso_unit,*,end=161) p_rjlist(ncount)
     goto 160
161  continue
     nprjs=ncount-1
     print*,'p_rejectlist: nprjs=',nprjs
   endif
 close(meso_unit)
!
!==> Read in station names from the reject list for specific humidity if it exists
 inquire(file='q_rejectlist',exist=qlistexist)
 if(qlistexist) then
     open (meso_unit,file='q_rejectlist',form='formatted')
     ncount=0
     do m=1,3
      read(meso_unit,*,end=171) cstring
     enddo
170  continue
     ncount=ncount+1
     read(meso_unit,*,end=171) q_rjlist(ncount)
     goto 170
171  continue
     nqrjs=ncount-1
     print*,'q_rejectlist: nqrjs=',nqrjs
   endif
 close(meso_unit)
!
!==> Read in 'good' mesonet station names from the station uselist if it exists.
 inquire(file='mesonet_stnuselist',exist=listexist2)
 if(listexist2) then
     open (meso_unit,file='mesonet_stnuselist',form='formatted')
     ncount=0
180  continue
     ncount=ncount+1
     read(meso_unit,'(a5,a80)',end=181) csta_winduse(ncount),cstring
     goto 180
181  continue
     nsta_mesowind_use=ncount-1
     print*,'mesonet_stnuselist: nsta_mesowind_use=',nsta_mesowind_use
 endif
 close(meso_unit)
!
end subroutine init_rjlists

subroutine get_usagerj(kx,obstype,c_station_id,c_prvstg,c_sprvstg,usage_rj)

!$$$  module documentation block
! abstract: determine the usage value of read_prepbufr for surface obs. the following
!           is done: (i) if incoming usage value is >=100. then do nothing, since
!           read_prepbufr has already flagged this ob and assigned a specific usage 
!           value to it. (ii) use usage=500. for temperature, moisture, or surface pressure
!           obs which are found in the rejectlist. (iii) 


  implicit none

  integer(i_kind),intent(in):: kx
  character(10),intent(in):: obstype
  character(8),intent(in)::  c_station_id
  character(8),intent(in)::  c_prvstg,c_sprvstg
  real(r_kind),intent(inout):: usage_rj

! Declare local variables
  integer(i_kind) m,nlen
  character(8)  ch8
  real(r_kind) usage_rj0

! Declare local parameters
  real(r_kind),parameter:: r6    = 6.0_r_kind
  real(r_kind),parameter:: r5000 = 5000._r_kind
  real(r_kind),parameter:: r6000 = 6000._r_kind
  real(r_kind),parameter:: r6100 = 6100._r_kind
  real(r_kind),parameter:: r6200 = 6200._r_kind

     if (usage_rj >= r6) return

     usage_rj0=usage_rj

     if (kx.lt.190) then  !<==mass obs

        if(obstype=='t' .and. tlistexist ) then
               do m=1,ntrjs
                  ch8(1:8)=t_rjlist(m)(1:8)
                  nlen=len_trim(ch8)
                  if ((trim(c_station_id) == trim(ch8)) .or. &
                      (kx==188 .and. c_station_id(1:nlen)==ch8(1:nlen))) then !handle wfo's mesonets which never end with
                     usage_rj=r5000                                           !an "a" or "x" in the eight position following blanks
                     exit
                  endif
               enddo
           elseif(obstype=='q' .and. qlistexist ) then
               do m=1,nqrjs
                  ch8(1:8)=q_rjlist(m)(1:8)
                  nlen=len_trim(ch8)
                  if ((trim(c_station_id) == trim(ch8)) .or. &
                      (kx==188 .and. c_station_id(1:nlen)==ch8(1:nlen))) then
                     usage_rj=r5000
                     exit
                  endif
               enddo
           elseif(obstype=='ps' .and. plistexist ) then
               do m=1,nprjs
                  ch8(1:8)=p_rjlist(m)(1:8)
                  nlen=len_trim(ch8)
                  if ((trim(c_station_id) == trim(ch8)) .or. &
                      (kx==188 .and. c_station_id(1:nlen)==ch8(1:nlen))) then
                     usage_rj=r5000
                     exit
                  endif
               enddo
        end if

       elseif (kx.ge.190) then !<==wind obs

        if (kx.eq.288 .and. (listexist.or.listexist2)) then  !note that uselist must precede rejectlist
           usage_rj=r6000
           if (listexist) then
              do m=1,nprov
!                if (trim(c_prvstg//c_sprvstg) == trim(cprovider(m))) then
                 if (c_prvstg(1:8) == cprovider(m)(1:8) .and. (c_sprvstg(1:8) == cprovider(m)(9:16)  &
                                                               .or. cprovider(m)(9:16) == 'allsprvs') ) then
                    usage_rj=usage_rj0
                    exit
                  endif
              enddo
           endif
           if (listexist2) then
              do m=1,nsta_mesowind_use
                 if (c_station_id(1:5) == csta_winduse(m)(1:5)) then
                    usage_rj=usage_rj0
                    exit
                  endif
              enddo
           endif
        endif

        if(obstype=='uv' .and. wlistexist ) then
               do m=1,nwrjs
                  ch8(1:8)=w_rjlist(m)(1:8)
                  nlen=len_trim(ch8)
                  if ((trim(c_station_id) == trim(ch8)) .or. &
                      (kx==288 .and. c_station_id(1:nlen)==ch8(1:nlen))) then
                      if (kx.ne.288) then
                           usage_rj=r5000
                         else
                          if (usage_rj.eq.usage_rj0)    usage_rj=r6100 !ob is in at least one of the above two uselists
                          if (usage_rj.eq.r6000)        usage_rj=r6200 !ob is in none of the above two uselists
                      endif
                      exit
                  endif
               enddo
         endif

     end if
end subroutine get_usagerj

subroutine destroy_rjlists
  implicit none

  deallocate(cprovider)
  deallocate(w_rjlist)
  deallocate(t_rjlist)
  deallocate(p_rjlist)
  deallocate(q_rjlist)
  deallocate(csta_winduse)
end subroutine destroy_rjlists

end module sfcobsqc
