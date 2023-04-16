/* Copyright (C) 2000-2023 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _LINUX_S390_SYSDEP_H
#define _LINUX_S390_SYSDEP_H

#include <sysdeps/s390/s390-32/sysdep.h>
#include <sysdeps/unix/sysdep.h>
#include <sysdeps/unix/sysv/linux/s390/sysdep.h>
#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <dl-sysdep.h>	/* For RTLD_PRIVATE_ERRNO.  */
#include <tls.h>

/* For Linux we can use the system call table in the header file
	/usr/include/asm/unistd.h
   of the kernel.  But these symbols do not follow the SYS_* syntax
   so we have to redefine the `SYS_ify' macro here.  */
/* in newer 2.1 kernels __NR_syscall is missing so we define it here */
#define __NR_syscall 0

#ifdef __ASSEMBLER__

/* Linux uses a negative return value to indicate syscall errors, unlike
   most Unices, which use the condition codes' carry flag.

   Since version 2.1 the return value of a system call might be negative
   even if the call succeeded.  E.g., the `lseek' system call might return
   a large offset.  Therefore we must not anymore test for < 0, but test
   for a real error by making sure the value in gpr2 is a real error
   number.  Linus said he will make sure that no syscall returns a value
   in -1 .. -4095 as a valid result so we can savely test with -4095.  */

#undef PSEUDO
#define	PSEUDO(name, syscall_name, args)				      \
  .text;                                                                      \
  ENTRY (name)								      \
    DO_CALL (syscall_name, args);                                             \
    lhi  %r4,-4095 ;                                                          \
    clr  %r2,%r4 ;							      \
    jnl  SYSCALL_ERROR_LABEL

#undef PSEUDO_END
#define PSEUDO_END(name)						      \
  SYSCALL_ERROR_HANDLER;						      \
  END (name)

#undef PSEUDO_NOERRNO
#define	PSEUDO_NOERRNO(name, syscall_name, args)			      \
  .text;                                                                      \
  ENTRY (name)								      \
    DO_CALL (syscall_name, args)

#undef PSEUDO_END_NOERRNO
#define PSEUDO_END_NOERRNO(name)					      \
  END (name)

#undef PSEUDO_ERRVAL
#define	PSEUDO_ERRVAL(name, syscall_name, args)				      \
  .text;                                                                      \
  ENTRY (name)								      \
    DO_CALL (syscall_name, args);					      \
    lcr %r2,%r2

#undef PSEUDO_END_ERRVAL
#define PSEUDO_END_ERRVAL(name)						      \
  END (name)

#undef SYSCALL_ERROR_LABEL
#ifndef PIC
# undef SYSCALL_ERROR_LABEL
# define SYSCALL_ERROR_LABEL 0f
# define SYSCALL_ERROR_HANDLER \
0:  basr  %r1,0;							      \
1:  l     %r1,2f-1b(%r1);						      \
    br    %r1;								      \
2:  .long syscall_error
#else
# if RTLD_PRIVATE_ERRNO
#  undef SYSCALL_ERROR_LABEL
#  define SYSCALL_ERROR_LABEL 0f
#  define SYSCALL_ERROR_HANDLER \
0:  basr  %r1,0;							      \
1:  al    %r1,2f-1b(%r1);						      \
    lcr   %r2,%r2;							      \
    st    %r2,0(%r1);							      \
    lhi   %r2,-1;							      \
    br    %r14;								      \
2:  .long rtld_errno-1b
# elif defined _LIBC_REENTRANT
#  if IS_IN (libc)
#   define SYSCALL_ERROR_ERRNO __libc_errno
#  else
#   define SYSCALL_ERROR_ERRNO errno
#  endif
#  undef SYSCALL_ERROR_LABEL
#  define SYSCALL_ERROR_LABEL 0f
#  define SYSCALL_ERROR_HANDLER \
0:  lcr   %r0,%r2;							      \
    basr  %r1,0;							      \
1:  al    %r1,2f-1b(%r1);						      \
    l     %r1,SYSCALL_ERROR_ERRNO@gotntpoff(%r1);			      \
    ear   %r2,%a0;							      \
    st    %r0,0(%r1,%r2);						      \
    lhi   %r2,-1;							      \
    br    %r14;								      \
2:  .long _GLOBAL_OFFSET_TABLE_-1b
# else
#  undef SYSCALL_ERROR_LABEL
#  define SYSCALL_ERROR_LABEL 0f
#  define SYSCALL_ERROR_HANDLER \
0:  basr  %r1,0;							      \
1:  al    %r1,2f-1b(%r1);						      \
    l     %r1,errno@GOT(%r1);						      \
    lcr   %r2,%r2;							      \
    st    %r2,0(%r1);							      \
    lhi   %r2,-1;							      \
    br    %r14;								      \
2:  .long _GLOBAL_OFFSET_TABLE_-1b
# endif /* _LIBC_REENTRANT */
#endif /* PIC */

/* Linux takes system call arguments in registers:

	syscall number	1	     call-clobbered
	arg 1		2	     call-clobbered
	arg 2		3	     call-clobbered
	arg 3		4	     call-clobbered
	arg 4		5	     call-clobbered
	arg 5		6	     call-saved
	arg 6		7	     call-saved

   (Of course a function with say 3 arguments does not have entries for
   arguments 4 and 5.)
   For system calls with 6 parameters a stack operation is required
   to load the 6th parameter to register 7. Call saved register 7 is
   moved to register 0 and back to avoid an additional stack frame.
 */

#define DO_CALL(syscall, args)						      \
  .if args > 5;								      \
    lr %r0,%r7;								      \
    l %r7,96(%r15);							      \
  .endif;								      \
    lhi %r1,SYS_ify (syscall);						      \
    svc 0;								      \
  .if args > 5;								      \
    lr %r7,%r0;								      \
  .endif

#define ret                                                                   \
    br      14

#define ret_NOERRNO							      \
    br      14

#define ret_ERRVAL							      \
    br      14

#else

# undef HAVE_INTERNAL_BRK_ADDR_SYMBOL
# define HAVE_INTERNAL_BRK_ADDR_SYMBOL 1

#endif /* __ASSEMBLER__ */

#endif /* _LINUX_S390_SYSDEP_H */
