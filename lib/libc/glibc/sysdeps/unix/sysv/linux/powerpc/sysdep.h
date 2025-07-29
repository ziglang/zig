/* Syscall definitions, Linux PowerPC generic version.
   Copyright (C) 2019-2025 Free Software Foundation, Inc.
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

#ifndef _LINUX_POWERPC_SYSDEP_H
#define _LINUX_POWERPC_SYSDEP_H 1

#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <sysdeps/unix/powerpc/sysdep.h>
#include <tls.h>
/* Define __set_errno() for INLINE_SYSCALL macro below.  */
#include <errno.h>

/* For Linux we can use the system call table in the header file
       /usr/include/asm/unistd.h
   of the kernel.  But these symbols do not follow the SYS_* syntax
   so we have to redefine the `SYS_ify' macro here.  */
#undef SYS_ify
#define SYS_ify(syscall_name)  __NR_##syscall_name

#define tostring(s) #s
#define stringify(s) tostring(s)

#ifdef _ARCH_PWR4
/* Power4 and later cpus introduced a faster instruction to copy one
   CR field, rather than the slower microcoded mfcr which copies all
   CR fields.  */
# define MFCR0(REG) "mfocrf " stringify(REG) ",0x80"
#else
# define MFCR0(REG) "mfcr " stringify(REG)
#endif

/* Define a macro which expands inline into the wrapper code for a system
   call. This use is for internal calls that do not need to handle errors
   normally. It will never touch errno. This returns just what the kernel
   gave back in the non-error (CR0.SO cleared) case, otherwise (CR0.SO set)
   the negation of the return value in the kernel gets reverted.  */

#define INTERNAL_VSYSCALL_CALL_TYPE(funcptr, type, nr, args...)         \
  ({									\
    register void *r0  __asm__ ("r0");					\
    register long int r3  __asm__ ("r3");				\
    register long int r4  __asm__ ("r4");				\
    register long int r5  __asm__ ("r5");				\
    register long int r6  __asm__ ("r6");				\
    register long int r7  __asm__ ("r7");				\
    register long int r8  __asm__ ("r8");				\
    register type rval  __asm__ ("r3");				        \
    LOADARGS_##nr (funcptr, args);					\
    __asm__ __volatile__						\
      ("mtctr %0\n\t"							\
       "bctrl\n\t"							\
       MFCR0(%0) "\n\t"							\
       "0:"								\
       : "+r" (r0), "+r" (r3), "+r" (r4), "+r" (r5),  "+r" (r6),        \
         "+r" (r7), "+r" (r8)						\
       : : "r9", "r10", "r11", "r12",					\
           "cr0", "cr1", "cr5", "cr6", "cr7",				\
           "xer", "lr", "ctr", "memory");				\
    __asm__ __volatile__ ("" : "=r" (rval) : "r" (r3));		        \
    (long int) r0 & (1 << 28) ? -rval : rval;				\
  })

#define INTERNAL_VSYSCALL_CALL(funcptr, nr, args...)			\
  INTERNAL_VSYSCALL_CALL_TYPE(funcptr, long int, nr, args)

#define DECLARE_REGS				\
  register long int r0  __asm__ ("r0");		\
  register long int r3  __asm__ ("r3");		\
  register long int r4  __asm__ ("r4");		\
  register long int r5  __asm__ ("r5");		\
  register long int r6  __asm__ ("r6");		\
  register long int r7  __asm__ ("r7");		\
  register long int r8  __asm__ ("r8");

#define SYSCALL_SCV(nr)				\
  ({						\
    __asm__ __volatile__			\
      (".machine \"push\"\n\t"			\
       ".machine \"power9\"\n\t"		\
       "scv 0\n\t"				\
       ".machine \"pop\"\n\t"			\
       "0:"					\
       : "+r" (r0),				\
	 "+r" (r3), "+r" (r4), "+r" (r5),	\
	 "+r" (r6), "+r" (r7), "+r" (r8)	\
       : : "r9", "r10", "r11", "r12",		\
	 "cr0", "cr1", "cr5", "cr6", "cr7",	\
	 "xer", "lr", "ctr", "memory"); 	\
    r3;					\
  })

#define SYSCALL_SC(nr)				\
  ({						\
    __asm__ __volatile__			\
      ("sc\n\t"				\
       MFCR0(%0) "\n\t"				\
       "0:"					\
       : "+r" (r0),				\
	 "+r" (r3), "+r" (r4), "+r" (r5),	\
	 "+r" (r6), "+r" (r7), "+r" (r8)	\
       : : "r9", "r10", "r11", "r12",		\
	 "xer", "cr0", "ctr", "memory");	\
    r0 & (1 << 28) ? -r3 : r3;			\
  })

/* This will only be non-empty for 64-bit systems, see below.  */
#define TRY_SYSCALL_SCV(nr)

#if defined(__PPC64__) || defined(__powerpc64__)
# define SYSCALL_ARG_SIZE 8

/* For the static case, unlike the dynamic loader, there is no compile-time way
   to check if we are inside startup code.  So we need to check if the thread
   pointer has already been setup before trying to access the TLS.  */
# ifndef SHARED
#  define CHECK_THREAD_POINTER (__thread_register != 0)
# else
#  define CHECK_THREAD_POINTER (1)
# endif

/* When inside the dynamic loader, the thread pointer may not have been
   initialized yet, so don't check for scv support in that case.  */
# if defined(USE_PPC_SCV) && !IS_IN(rtld)
#  undef TRY_SYSCALL_SCV
#  define TRY_SYSCALL_SCV(nr)						\
  CHECK_THREAD_POINTER && THREAD_GET_HWCAP() & PPC_FEATURE2_SCV ?	\
      SYSCALL_SCV(nr) :
# endif

#else
# define SYSCALL_ARG_SIZE 4
#endif

# define INTERNAL_SYSCALL_NCS(name, nr, args...)	\
  ({							\
    DECLARE_REGS;					\
    LOADARGS_##nr (name, ##args);			\
    TRY_SYSCALL_SCV(nr)					\
    SYSCALL_SC(nr);					\
  })

#undef INTERNAL_SYSCALL
#define INTERNAL_SYSCALL(name, nr, args...)				\
  INTERNAL_SYSCALL_NCS (__NR_##name, nr, args)

#define LOADARGS_0(name, dummy) \
	r0 = name
#define LOADARGS_1(name, __arg1) \
	long int _arg1 = (long int) (__arg1); \
	LOADARGS_0(name, 0); \
	extern void __illegally_sized_syscall_arg1 (void); \
	if (__builtin_classify_type (__arg1) != 5 \
	    && sizeof (__arg1) > SYSCALL_ARG_SIZE) \
	  __illegally_sized_syscall_arg1 (); \
	r3 = _arg1
#define LOADARGS_2(name, __arg1, __arg2) \
	long int _arg2 = (long int) (__arg2); \
	LOADARGS_1(name, __arg1); \
	extern void __illegally_sized_syscall_arg2 (void); \
	if (__builtin_classify_type (__arg2) != 5 \
	    && sizeof (__arg2) > SYSCALL_ARG_SIZE) \
	  __illegally_sized_syscall_arg2 (); \
	r4 = _arg2
#define LOADARGS_3(name, __arg1, __arg2, __arg3) \
	long int _arg3 = (long int) (__arg3); \
	LOADARGS_2(name, __arg1, __arg2); \
	extern void __illegally_sized_syscall_arg3 (void); \
	if (__builtin_classify_type (__arg3) != 5 \
	    && sizeof (__arg3) > SYSCALL_ARG_SIZE) \
	  __illegally_sized_syscall_arg3 (); \
	r5 = _arg3
#define LOADARGS_4(name, __arg1, __arg2, __arg3, __arg4) \
	long int _arg4 = (long int) (__arg4); \
	LOADARGS_3(name, __arg1, __arg2, __arg3); \
	extern void __illegally_sized_syscall_arg4 (void); \
	if (__builtin_classify_type (__arg4) != 5 \
	    && sizeof (__arg4) > SYSCALL_ARG_SIZE) \
	  __illegally_sized_syscall_arg4 (); \
	r6 = _arg4
#define LOADARGS_5(name, __arg1, __arg2, __arg3, __arg4, __arg5) \
	long int _arg5 = (long int) (__arg5); \
	LOADARGS_4(name, __arg1, __arg2, __arg3, __arg4); \
	extern void __illegally_sized_syscall_arg5 (void); \
	if (__builtin_classify_type (__arg5) != 5 \
	    && sizeof (__arg5) > SYSCALL_ARG_SIZE) \
	  __illegally_sized_syscall_arg5 (); \
	r7 = _arg5
#define LOADARGS_6(name, __arg1, __arg2, __arg3, __arg4, __arg5, __arg6) \
	long int _arg6 = (long int) (__arg6); \
	LOADARGS_5(name, __arg1, __arg2, __arg3, __arg4, __arg5); \
	extern void __illegally_sized_syscall_arg6 (void); \
	if (__builtin_classify_type (__arg6) != 5 \
	    && sizeof (__arg6) > SYSCALL_ARG_SIZE) \
	  __illegally_sized_syscall_arg6 (); \
	r8 = _arg6

/* List of system calls which are supported as vsyscalls.  */
#define VDSO_NAME  "LINUX_2.6.15"
#define VDSO_HASH  123718565

#if defined(__PPC64__) || defined(__powerpc64__)
#define HAVE_CLOCK_GETRES64_VSYSCALL	"__kernel_clock_getres"
#define HAVE_CLOCK_GETTIME64_VSYSCALL	"__kernel_clock_gettime"
#define HAVE_CLONE3_WRAPPER		1
#else
#define HAVE_CLOCK_GETRES_VSYSCALL	"__kernel_clock_getres"
#define HAVE_CLOCK_GETTIME_VSYSCALL	"__kernel_clock_gettime"
#endif
#define HAVE_GETCPU_VSYSCALL		"__kernel_getcpu"
#define HAVE_TIME_VSYSCALL		"__kernel_time"
#define HAVE_GETTIMEOFDAY_VSYSCALL      "__kernel_gettimeofday"
#define HAVE_GET_TBFREQ                 "__kernel_get_tbfreq"
#define HAVE_GETRANDOM_VSYSCALL         "__kernel_getrandom"

#endif /* _LINUX_POWERPC_SYSDEP_H  */
