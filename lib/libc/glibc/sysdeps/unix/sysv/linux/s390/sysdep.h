/* Syscall definitions, Linux s390 version.
   Copyright (C) 2019-2021 Free Software Foundation, Inc.
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
   <http://www.gnu.org/licenses/>.  */

#ifndef __ASSEMBLY__

#undef SYS_ify
#define SYS_ify(syscall_name)	__NR_##syscall_name

#undef INTERNAL_SYSCALL_DIRECT
#define INTERNAL_SYSCALL_DIRECT(name, nr, args...)			      \
  ({									      \
    DECLARGS_##nr(args)							      \
    register long int _ret __asm__("2");				      \
    __asm__ __volatile__ (						      \
			  "svc    %b1\n\t"				      \
			  : "=d" (_ret)					      \
			  : "i" (__NR_##name) ASMFMT_##nr		      \
			  : "memory" );					      \
    _ret; })

#undef INTERNAL_SYSCALL_SVC0
#define INTERNAL_SYSCALL_SVC0(name, nr, args...)			      \
  ({									      \
    DECLARGS_##nr(args)							      \
    register unsigned long int _nr __asm__("1") =			      \
      (unsigned long int)(__NR_##name);					      \
    register long int _ret __asm__("2");				      \
    __asm__ __volatile__ (						      \
			  "svc    0\n\t"				      \
			  : "=d" (_ret)					      \
			  : "d" (_nr) ASMFMT_##nr			      \
			  : "memory" );					      \
    _ret; })

#undef INTERNAL_SYSCALL_NCS
#define INTERNAL_SYSCALL_NCS(no, nr, args...)				      \
  ({									      \
    DECLARGS_##nr(args)							      \
    register unsigned long int _nr __asm__("1") = (unsigned long int)(no);    \
    register long int _ret __asm__("2");				      \
    __asm__ __volatile__ (						      \
			  "svc    0\n\t"				      \
			  : "=d" (_ret)					      \
			  : "d" (_nr) ASMFMT_##nr			      \
			  : "memory" );					      \
    _ret; })

#undef INTERNAL_SYSCALL
#define INTERNAL_SYSCALL(name, nr, args...)				      \
  (((__NR_##name) < 256)						      \
   ? INTERNAL_SYSCALL_DIRECT(name, nr, args)				      \
   : INTERNAL_SYSCALL_SVC0(name, nr, args))

#define DECLARGS_0()
#define DECLARGS_1(arg1) \
  register unsigned long int gpr2 __asm__ ("2") = (unsigned long int)(arg1);
#define DECLARGS_2(arg1, arg2) \
  DECLARGS_1(arg1) \
  register unsigned long int gpr3 __asm__ ("3") = (unsigned long int)(arg2);
#define DECLARGS_3(arg1, arg2, arg3) \
  DECLARGS_2(arg1, arg2) \
  register unsigned long int gpr4 __asm__ ("4") = (unsigned long int)(arg3);
#define DECLARGS_4(arg1, arg2, arg3, arg4) \
  DECLARGS_3(arg1, arg2, arg3) \
  register unsigned long int gpr5 __asm__ ("5") = (unsigned long int)(arg4);
#define DECLARGS_5(arg1, arg2, arg3, arg4, arg5) \
  DECLARGS_4(arg1, arg2, arg3, arg4) \
  register unsigned long int gpr6 __asm__ ("6") = (unsigned long int)(arg5);
#define DECLARGS_6(arg1, arg2, arg3, arg4, arg5, arg6) \
  DECLARGS_5(arg1, arg2, arg3, arg4, arg5) \
  register unsigned long int gpr7 __asm__ ("7") = (unsigned long int)(arg6);

#define ASMFMT_0
#define ASMFMT_1 , "0" (gpr2)
#define ASMFMT_2 , "0" (gpr2), "d" (gpr3)
#define ASMFMT_3 , "0" (gpr2), "d" (gpr3), "d" (gpr4)
#define ASMFMT_4 , "0" (gpr2), "d" (gpr3), "d" (gpr4), "d" (gpr5)
#define ASMFMT_5 , "0" (gpr2), "d" (gpr3), "d" (gpr4), "d" (gpr5), "d" (gpr6)
#define ASMFMT_6 , "0" (gpr2), "d" (gpr3), "d" (gpr4), "d" (gpr5), "d" (gpr6), "d" (gpr7)

#define SINGLE_THREAD_BY_GLOBAL		1


#define VDSO_NAME  "LINUX_2.6.29"
#define VDSO_HASH  123718585

/* List of system calls which are supported as vsyscalls.  */
#ifdef __s390x__
#define HAVE_CLOCK_GETRES64_VSYSCALL	"__kernel_clock_getres"
#define HAVE_CLOCK_GETTIME64_VSYSCALL	"__kernel_clock_gettime"
#else
#define HAVE_CLOCK_GETRES_VSYSCALL	"__kernel_clock_getres"
#define HAVE_CLOCK_GETTIME_VSYSCALL	"__kernel_clock_gettime"
#endif
#define HAVE_GETTIMEOFDAY_VSYSCALL	"__kernel_gettimeofday"
#define HAVE_GETCPU_VSYSCALL		"__kernel_getcpu"

#endif
