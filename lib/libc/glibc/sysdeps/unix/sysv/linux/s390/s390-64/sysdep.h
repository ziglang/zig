/* Assembler macros for 64 bit S/390.
   Copyright (C) 2001-2020 Free Software Foundation, Inc.
   Contributed by Martin Schwidefsky (schwidefsky@de.ibm.com).
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

#include <sysdeps/s390/s390-64/sysdep.h>
#include <sysdeps/unix/sysdep.h>
#include <sysdeps/unix/sysv/linux/s390/sysdep.h>
#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <dl-sysdep.h>	/* For RTLD_PRIVATE_ERRNO.  */
#include <tls.h>

/* Define __set_errno() for INLINE_SYSCALL macro below.  */
#ifndef __ASSEMBLER__
#include <errno.h>
#endif

/* For Linux we can use the system call table in the header file
	/usr/include/asm/unistd.h
   of the kernel.  But these symbols do not follow the SYS_* syntax
   so we have to redefine the `SYS_ify' macro here.  */
/* In newer 2.1 kernels __NR_syscall is missing so we define it here.  */
#define __NR_syscall 0

/*
 * Newer kernel versions redefined __NR_pread and __NR_pwrite to
 * __NR_pread64 and __NR_pwrite64.
 */
#ifndef __NR_pread
# define __NR_pread __NR_pread64
#endif
#ifndef __NR_pwrite
# define __NR_pwrite __NR_pwrite64
#endif

#undef SYS_ify
#define SYS_ify(syscall_name)	__NR_##syscall_name

#ifdef __ASSEMBLER__

/* Linux uses a negative return value to indicate syscall errors, unlike
   most Unices, which use the condition codes' carry flag.

   Since version 2.1 the return value of a system call might be negative
   even if the call succeeded.	E.g., the `lseek' system call might return
   a large offset.  Therefore we must not anymore test for < 0, but test
   for a real error by making sure the value in gpr2 is a real error
   number.  Linus said he will make sure that no syscall returns a value
   in -1 .. -4095 as a valid result so we can savely test with -4095.  */

#undef PSEUDO
#define	PSEUDO(name, syscall_name, args)				      \
  .text;								      \
  ENTRY (name)								      \
    DO_CALL (syscall_name, args);					      \
    lghi %r4,-4095 ;							      \
    clgr %r2,%r4 ;							      \
    jgnl SYSCALL_ERROR_LABEL

#undef PSEUDO_END
#define PSEUDO_END(name)						      \
  SYSCALL_ERROR_HANDLER;						      \
  END (name)

#undef PSEUDO_NOERRNO
#define	PSEUDO_NOERRNO(name, syscall_name, args)			      \
  .text;								      \
  ENTRY (name)								      \
    DO_CALL (syscall_name, args)

#undef PSEUDO_END_NOERRNO
#define PSEUDO_END_NOERRNO(name)					      \
  SYSCALL_ERROR_HANDLER;						      \
  END (name)

#undef PSEUDO_ERRVAL
#define	PSEUDO_ERRVAL(name, syscall_name, args)				      \
  .text;								      \
  ENTRY (name)								      \
    DO_CALL (syscall_name, args);					      \
    lcgr %r2,%r2

#undef PSEUDO_END_ERRVAL
#define PSEUDO_END_ERRVAL(name)						      \
  SYSCALL_ERROR_HANDLER;						      \
  END (name)

#ifndef PIC
# define SYSCALL_ERROR_LABEL syscall_error
# define SYSCALL_ERROR_HANDLER
#else
# if RTLD_PRIVATE_ERRNO
#  define SYSCALL_ERROR_LABEL 0f
#  define SYSCALL_ERROR_HANDLER \
0:  larl  %r1,rtld_errno;						      \
    lcr   %r2,%r2;							      \
    st    %r2,0(%r1);							      \
    lghi  %r2,-1;							      \
    br    %r14
# elif defined _LIBC_REENTRANT
#  if IS_IN (libc)
#   define SYSCALL_ERROR_ERRNO __libc_errno
#  else
#   define SYSCALL_ERROR_ERRNO errno
#  endif
#  define SYSCALL_ERROR_LABEL 0f
#  define SYSCALL_ERROR_HANDLER \
0:  lcr   %r0,%r2;							      \
    larl  %r1,SYSCALL_ERROR_ERRNO@indntpoff;				      \
    lg    %r1,0(%r1);							      \
    ear   %r2,%a0;							      \
    sllg  %r2,%r2,32;							      \
    ear   %r2,%a1;							      \
    st    %r0,0(%r1,%r2);						      \
    lghi   %r2,-1;							      \
    br    %r14
# else
#  define SYSCALL_ERROR_LABEL 0f
#  define SYSCALL_ERROR_HANDLER \
0:  larl  %r1,_GLOBAL_OFFSET_TABLE_;					      \
    lg    %r1,errno@GOT(%r1);						      \
    lcr   %r2,%r2;							      \
    st    %r2,0(%r1);							      \
    lghi  %r2,-1;							      \
    br    %r14
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
    lgr %r0,%r7;							      \
    lg %r7,160(%r15);							      \
  .endif;								      \
  .if SYS_ify (syscall) < 256;						      \
    svc SYS_ify (syscall);						      \
  .else;								      \
    lghi %r1,SYS_ify (syscall);						      \
    svc 0;								      \
  .endif;								      \
  .if args > 5;								      \
    lgr %r7,%r0;							      \
  .endif

#define ret								      \
    br	    14

#define ret_NOERRNO							      \
    br	    14

#define ret_ERRVAL							      \
    br	    14

#endif /* __ASSEMBLER__ */

#undef INLINE_SYSCALL
#define INLINE_SYSCALL(name, nr, args...)				      \
  ({									      \
    long _ret = INTERNAL_SYSCALL (name, , nr, args);			      \
    if (__glibc_unlikely (INTERNAL_SYSCALL_ERROR_P (_ret, )))		      \
     {									      \
       __set_errno (INTERNAL_SYSCALL_ERRNO (_ret, ));			      \
       _ret = -1;							      \
     }									      \
    _ret; })

#undef INTERNAL_SYSCALL_DECL
#define INTERNAL_SYSCALL_DECL(err) do { } while (0)

#undef INTERNAL_SYSCALL_DIRECT
#define INTERNAL_SYSCALL_DIRECT(name, err, nr, args...)			      \
  ({									      \
    DECLARGS_##nr(args)							      \
    register long _ret __asm__("2");					      \
    __asm__ __volatile__ (						      \
			  "svc    %b1\n\t"				      \
			  : "=d" (_ret)					      \
			  : "i" (__NR_##name) ASMFMT_##nr		      \
			  : "memory" );					      \
    _ret; })

#undef INTERNAL_SYSCALL_SVC0
#define INTERNAL_SYSCALL_SVC0(name, err, nr, args...)			      \
  ({									      \
    DECLARGS_##nr(args)							      \
    register unsigned long _nr __asm__("1") = (unsigned long)(__NR_##name);   \
    register long _ret __asm__("2");					      \
    __asm__ __volatile__ (						      \
			  "svc    0\n\t"				      \
			  : "=d" (_ret)					      \
			  : "d" (_nr) ASMFMT_##nr			      \
			  : "memory" );					      \
    _ret; })

#undef INTERNAL_SYSCALL_NCS
#define INTERNAL_SYSCALL_NCS(no, err, nr, args...)			      \
  ({									      \
    DECLARGS_##nr(args)							      \
    register unsigned long _nr __asm__("1") = (unsigned long)(no);	      \
    register long _ret __asm__("2");					      \
    __asm__ __volatile__ (						      \
			  "svc    0\n\t"				      \
			  : "=d" (_ret)					      \
			  : "d" (_nr) ASMFMT_##nr			      \
			  : "memory" );					      \
    _ret; })

#undef INTERNAL_SYSCALL
#define INTERNAL_SYSCALL(name, err, nr, args...)			      \
  (((__NR_##name) < 256)						      \
   ? INTERNAL_SYSCALL_DIRECT(name, err, nr, args)			      \
   : INTERNAL_SYSCALL_SVC0(name, err,nr, args))

#undef INTERNAL_SYSCALL_ERROR_P
#define INTERNAL_SYSCALL_ERROR_P(val, err)				      \
  ((unsigned long) (val) >= -4095UL)

#undef INTERNAL_SYSCALL_ERRNO
#define INTERNAL_SYSCALL_ERRNO(val, err)	(-(val))

#define DECLARGS_0()
#define DECLARGS_1(arg1) \
	register unsigned long gpr2 __asm__ ("2") = (unsigned long)(arg1);
#define DECLARGS_2(arg1, arg2) \
	DECLARGS_1(arg1) \
	register unsigned long gpr3 __asm__ ("3") = (unsigned long)(arg2);
#define DECLARGS_3(arg1, arg2, arg3) \
	DECLARGS_2(arg1, arg2) \
	register unsigned long gpr4 __asm__ ("4") = (unsigned long)(arg3);
#define DECLARGS_4(arg1, arg2, arg3, arg4) \
	DECLARGS_3(arg1, arg2, arg3) \
	register unsigned long gpr5 __asm__ ("5") = (unsigned long)(arg4);
#define DECLARGS_5(arg1, arg2, arg3, arg4, arg5) \
	DECLARGS_4(arg1, arg2, arg3, arg4) \
	register unsigned long gpr6 __asm__ ("6") = (unsigned long)(arg5);
#define DECLARGS_6(arg1, arg2, arg3, arg4, arg5, arg6) \
	DECLARGS_5(arg1, arg2, arg3, arg4, arg5) \
	register unsigned long gpr7 __asm__ ("7") = (unsigned long)(arg6);

#define ASMFMT_0
#define ASMFMT_1 , "0" (gpr2)
#define ASMFMT_2 , "0" (gpr2), "d" (gpr3)
#define ASMFMT_3 , "0" (gpr2), "d" (gpr3), "d" (gpr4)
#define ASMFMT_4 , "0" (gpr2), "d" (gpr3), "d" (gpr4), "d" (gpr5)
#define ASMFMT_5 , "0" (gpr2), "d" (gpr3), "d" (gpr4), "d" (gpr5), "d" (gpr6)
#define ASMFMT_6 , "0" (gpr2), "d" (gpr3), "d" (gpr4), "d" (gpr5), "d" (gpr6), "d" (gpr7)

#define SINGLE_THREAD_BY_GLOBAL		1

/* Pointer mangling support.  */
#if IS_IN (rtld)
/* We cannot use the thread descriptor because in ld.so we use setjmp
   earlier than the descriptor is initialized.  */
#else
/* For the time being just use stack_guard rather than a separate
   pointer_guard.  */
# ifdef __ASSEMBLER__
#  define PTR_MANGLE(reg, tmpreg) \
  ear     tmpreg,%a0;			\
  sllg    tmpreg,tmpreg,32;		\
  ear     tmpreg,%a1;			\
  xg      reg,STACK_GUARD(tmpreg)
#  define PTR_MANGLE2(reg, tmpreg) \
  xg      reg,STACK_GUARD(tmpreg)
#  define PTR_DEMANGLE(reg, tmpreg) PTR_MANGLE (reg, tmpreg)
# else
#  define PTR_MANGLE(var) \
  (var) = (void *) ((uintptr_t) (var) ^ THREAD_GET_POINTER_GUARD ())
#  define PTR_DEMANGLE(var)	PTR_MANGLE (var)
# endif
#endif

#endif /* _LINUX_S390_SYSDEP_H */
