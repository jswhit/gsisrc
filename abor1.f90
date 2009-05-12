subroutine abor1(error_msg)
!$$$  subprogram documentation block
!
! abstract:  Print error message and abort execution of mpi code.
!
! program history log:
!   2007-04-13  tremolet - initial code
!
!   input argument list:
!     error_msg - Error message
!     ierror_code - Error code
!
!$$$
use kinds, only: i_kind
use mpimod, only: mpi_comm_world,ierror
implicit none
character(len=*), intent(in) :: error_msg
!integer(i_kind), optional, intent(in) :: ierror_code
integer(i_kind) :: ierr

!if (PRESENT(ierror_code)) then
!  ierr=ierror_code
!else
  ierr=100
!endif

write(6,*)'ABOR1 called: ',error_msg
write(0,*)'ABOR1 called: ',error_msg

call flush(6)
call flush(0)

call system("sleep 1")

call mpi_abort(mpi_comm_world,ierr,ierror)

stop
return
end subroutine abor1
