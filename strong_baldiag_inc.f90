subroutine strong_baldiag_inc(sval)

!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    strong_baldiag_inc    get balance diagnostics
!   prgmmr: parrish          org: np23                date: 2006-08-12
!
! abstract: get balance diagnostic statistics of increment
!
! program history log:
!   2006-08-12  parrish
!   2007-04-16  kleist   - modified to be used for diagnostics only
!   2007-07-26 cucurull  - call getprs; add xhat3dp and remove ps in calctends_tl argument list
!   2007-08-08  derber - only calculate dynamics time derivatives
!   2008-04-09  safford  - rm unused vars and uses
!   2009-01-17  todling  - per early changes from Tremolet (revisited)
!   2010-05-13  todling  - udpate to use gsi_bundle
!                          BUG FIX: was missing deallocate_state call
!
!   input argument list:
!     sval    - current solution in state space
!
!   output argument list:
!     sval
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: i_kind,r_kind
  use mpimod, only: mype
  use gridmod, only: nnnn1o
  use gsi_4dvar, only: nsubwin
  use mod_vtrans,only: nvmodes_keep
  use state_vectors, only: allocate_state
  use state_vectors, only: deallocate_state
  use gsi_bundlemod, only: gsi_bundle
  use gsi_bundlemod, only: gsi_bundlegetpointer
  use gsi_bundlemod, only: assignment(=)
  use constants, only: izero,zero
  implicit none

! Declare passed variables
  type(gsi_bundle),intent(inout) :: sval(nsubwin)

! Declare local variables
  integer(i_kind) ii,ier,istatus
  integer(i_kind) is_u,is_v,is_t,is_q,is_oz,is_cw,is_p,is_p3d
  real(r_kind),pointer,dimension(:,:,:) :: dhat_dt_u
  real(r_kind),pointer,dimension(:,:,:) :: dhat_dt_v
  real(r_kind),pointer,dimension(:,:,:) :: dhat_dt_t
  real(r_kind),pointer,dimension(:,:,:) :: dhat_dt_q
  real(r_kind),pointer,dimension(:,:,:) :: dhat_dt_oz
  real(r_kind),pointer,dimension(:,:,:) :: dhat_dt_cw
  real(r_kind),pointer,dimension(:,:,:) :: dhat_dt_p3d
  logical fullfield
  type(gsi_bundle) dhat_dt

!************************************************************************************  
! Initialize variable

! Get relevant pointers; return if not found
  ier=0
  call gsi_bundlegetpointer(sval(1),'u',  is_u,  istatus);ier=istatus+ier
  call gsi_bundlegetpointer(sval(1),'v',  is_v,  istatus);ier=istatus+ier
  call gsi_bundlegetpointer(sval(1),'tv', is_t,  istatus);ier=istatus+ier
  call gsi_bundlegetpointer(sval(1),'q',  is_q,  istatus);ier=istatus+ier
  call gsi_bundlegetpointer(sval(1),'oz', is_oz, istatus);ier=istatus+ier
  call gsi_bundlegetpointer(sval(1),'cw', is_cw, istatus);ier=istatus+ier
  call gsi_bundlegetpointer(sval(1),'ps', is_p,  istatus);ier=istatus+ier
  call gsi_bundlegetpointer(sval(1),'p3d',is_p3d,istatus);ier=istatus+ier
  if(ier/=0) then ! for now ... just die ... _RT
    write(6,*) 'strong_baldiag_inc: trouble getting sval pointers, ier =', ier 
    call stop2(999)
  endif
  
  call allocate_state(dhat_dt)
  dhat_dt=zero
  call gsi_bundlegetpointer(dhat_dt,'u',  dhat_dt_u,  istatus);ier=istatus+ier
  call gsi_bundlegetpointer(dhat_dt,'v',  dhat_dt_v,  istatus);ier=istatus+ier
  call gsi_bundlegetpointer(dhat_dt,'tv', dhat_dt_t,  istatus);ier=istatus+ier
  call gsi_bundlegetpointer(dhat_dt,'q',  dhat_dt_q,  istatus);ier=istatus+ier
  call gsi_bundlegetpointer(dhat_dt,'oz', dhat_dt_oz, istatus);ier=istatus+ier
  call gsi_bundlegetpointer(dhat_dt,'cw', dhat_dt_cw, istatus);ier=istatus+ier
  call gsi_bundlegetpointer(dhat_dt,'p3d',dhat_dt_p3d,istatus);ier=istatus+ier
  if(ier/=0) then ! for now ... just die ... _RT
    write(6,*) 'strong_baldiag_inc: trouble getting sval pointers, ier =', ier 
    call stop2(999)
  endif

!     compute derivatives
! Determine how many vertical levels each mpi task will
! handle in computing horizontal derivatives

  do ii=1,nsubwin

     call calctends_tl( &
       sval(ii)%r3(is_u)%q,sval(ii)%r3(is_v)%q ,sval(ii)%r3(is_t)%q,  &
       sval(ii)%r3(is_q)%q,sval(ii)%r3(is_oz)%q,sval(ii)%r3(is_cw)%q, &
       mype, nnnn1o,          &
       dhat_dt_u,dhat_dt_v ,dhat_dt_t,dhat_dt_p3d, &
       dhat_dt_q,dhat_dt_oz,dhat_dt_cw,sval(ii)%r3(is_p3d)%q)
     if(nvmodes_keep>izero) then
        fullfield=.false.
        call strong_bal_correction(dhat_dt_u,dhat_dt_v,dhat_dt_t,dhat_dt_p3d,&
                    mype,sval(ii)%r3(is_u)%q,sval(ii)%r3(is_v)%q,&
                         sval(ii)%r3(is_t)%q,sval(ii)%r2(is_p)%q,&
                   .true.,fullfield,.false.)
     end if

  enddo
  call deallocate_state(dhat_dt)

  return
end subroutine strong_baldiag_inc
