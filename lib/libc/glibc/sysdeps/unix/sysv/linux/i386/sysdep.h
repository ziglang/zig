/* Copyright (C) 1992-2023 Free Software Foundation, Inc.
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

#ifndef _LINUX_I386_SYSDEP_H
#define _LINUX_I386_SYSDEP_H 1

/* There is some commonality.  */
#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <sysdeps/unix/i386/sysdep.h>
/* Defines RTLD_PRIVATE_ERRNO and USE_DL_SYSINFO.  */
#include <dl-sysdep.h>
#include <tls.h>


/* For Linux we can use the system call table in the header file
	/usr/include/asm/unistd.h
   of the kernel.  But these symbols do not follow the SYS_* syntax
   so we have to redefine the `SYS_ify' macro here.  */
#undef SYS_ify
#define SYS_ify(syscall_name)	__NR_##syscall_name

#ifndef I386_USE_SYSENTER
# if defined USE_DL_SYSINFO \
     && (IS_IN (libc) || IS_IN (libpthread))
#  define I386_USE_SYSENTER	1
# else
#  define I386_USE_SYSENTER	0
# endif
#endif

#if !I386_USE_SYSENTER && IS_IN (libc) && !defined SHARED
/* Inside static libc, we have two versions.  For compilation units
   with !I386_USE_SYSENTER, the vDSO entry mechanism cannot be
   used. */
# define I386_DO_SYSCALL_STRING "__libc_do_syscall_int80"
#else
# define I386_DO_SYSCALL_STRING "__libc_do_syscall"
#endif

#ifdef __ASSEMBLER__

/* Linux uses a negative return value to indicate syscall errors,
   unlike most Unices, which use the condition codes' carry flag.

   Since version 2.1 the return value of a system call might be
   negative even if the call succeeded.  E.g., the `lseek' system call
   might return a large offset.  Therefore we must not anymore test
   for < 0, but test for a real error by making sure the value in %eax
   is a real error number.  Linus said he will make sure the no syscall
   returns a value in -1 .. -4095 as a valid result so we can safely
   test with -4095.  */

/* We don't want the label for the error handle to be global when we define
   it here.  */
#undef SYSCALL_ERROR_LABEL
#define SYSCALL_ERROR_LABEL __syscall_error

#undef	PSEUDO
#define	PSEUDO(name, syscall_name, args)				      \
  .text;								      \
  ENTRY (name)								      \
    DO_CALL (syscall_name, args);					      \
    cmpl $-4095, %eax;							      \
    jae SYSCALL_ERROR_LABEL

#undef	PSEUDO_END
#define	PSEUDO_END(name)						      \
  SYSCALL_ERROR_HANDLER							      \
  END (name)

#undef	PSEUDO_NOERRNO
#define	PSEUDO_NOERRNO(name, syscall_name, args)			      \
  .text;								      \
  ENTRY (name)								      \
    DO_CALL (syscall_name, args)

#undef	PSEUDO_END_NOERRNO
#define	PSEUDO_END_NOERRNO(name)					      \
  END (name)

#define ret_NOERRNO ret

/* The function has to return the error code.  */
#undef	PSEUDO_ERRVAL
#define	PSEUDO_ERRVAL(name, syscall_name, args) \
  .text;								      \
  ENTRY (name)								      \
    DO_CALL (syscall_name, args);					      \
    negl %eax

#undef	PSEUDO_END_ERRVAL
#define	PSEUDO_END_ERRVAL(name) \
  END (name)

#define ret_ERRVAL ret

#define SYSCALL_ERROR_HANDLER	/* Nothing here; code in sysdep.c is used.  */

/* The original calling convention for system calls on Linux/i386 is
   to use int $0x80.  */
#if I386_USE_SYSENTER
# ifdef PIC
#  define ENTER_KERNEL call *%gs:SYSINFO_OFFSET
# else
#  define ENTER_KERNEL call *_dl_sysinfo
# endif
#else
# define ENTER_KERNEL int $0x80
#endif

/* Linux takes system call arguments in registers:

	syscall number	%eax	     call-clobbered
	arg 1		%ebx	     call-saved
	arg 2		%ecx	     call-clobbered
	arg 3		%edx	     call-clobbered
	arg 4		%esi	     call-saved
	arg 5		%edi	     call-saved
	arg 6		%ebp	     call-saved

   The stack layout upon entering the function is:

	24(%esp)	Arg# 6
	20(%esp)	Arg# 5
	16(%esp)	Arg# 4
	12(%esp)	Arg# 3
	 8(%esp)	Arg# 2
	 4(%esp)	Arg# 1
	  (%esp)	Return address

   (Of course a function with say 3 arguments does not have entries for
   arguments 4, 5, and 6.)

   The following code tries hard to be optimal.  A general assumption
   (which is true according to the data books I have) is that

	2 * xchg	is more expensive than	pushl + movl + popl

   Beside this a neat trick is used.  The calling conventions for Linux
   tell that among the registers used for parameters %ecx and %edx need
   not be saved.  Beside this we may clobber this registers even when
   they are not used for parameter passing.

   As a result one can see below that we save the content of the %ebx
   register in the %edx register when we have less than 3 arguments
   (2 * movl is less expensive than pushl + popl).

   Second unlike for the other registers we don't save the content of
   %ecx and %edx when we have more than 1 and 2 registers resp.

   The code below might look a bit long but we have to take care for
   the pipelined processors (i586).  Here the `pushl' and `popl'
   instructions are marked as NP (not pairable) but the exception is
   two consecutive of these instruction.  This gives no penalty on
   other processors though.  */

#undef	DO_CALL
#define DO_CALL(syscall_name, args)			      		      \
    PUSHARGS_##args							      \
    DOARGS_##args							      \
    movl $SYS_ify (syscall_name), %eax;					      \
    ENTER_KERNEL							      \
    POPARGS_##args

#define PUSHARGS_0	/* No arguments to push.  */
#define	DOARGS_0	/* No arguments to frob.  */
#define	POPARGS_0	/* No arguments to pop.  */
#define	_PUSHARGS_0	/* No arguments to push.  */
#define _DOARGS_0(n)	/* No arguments to frob.  */
#define	_POPARGS_0	/* No arguments to pop.  */

#define PUSHARGS_1	movl %ebx, %edx; L(SAVEBX1): PUSHARGS_0
#define	DOARGS_1	_DOARGS_1 (4)
#define	POPARGS_1	POPARGS_0; movl %edx, %ebx; L(RESTBX1):
#define	_PUSHARGS_1	pushl %ebx; cfi_adjust_cfa_offset (4); \
			cfi_rel_offset (ebx, 0); L(PUSHBX1): _PUSHARGS_0
#define _DOARGS_1(n)	movl n(%esp), %ebx; _DOARGS_0(n-4)
#define	_POPARGS_1	_POPARGS_0; popl %ebx; cfi_adjust_cfa_offset (-4); \
			cfi_restore (ebx); L(POPBX1):

#define PUSHARGS_2	PUSHARGS_1
#define	DOARGS_2	_DOARGS_2 (8)
#define	POPARGS_2	POPARGS_1
#define _PUSHARGS_2	_PUSHARGS_1
#define	_DOARGS_2(n)	movl n(%esp), %ecx; _DOARGS_1 (n-4)
#define	_POPARGS_2	_POPARGS_1

#define PUSHARGS_3	_PUSHARGS_2
#define DOARGS_3	_DOARGS_3 (16)
#define POPARGS_3	_POPARGS_3
#define _PUSHARGS_3	_PUSHARGS_2
#define _DOARGS_3(n)	movl n(%esp), %edx; _DOARGS_2 (n-4)
#define _POPARGS_3	_POPARGS_2

#define PUSHARGS_4	_PUSHARGS_4
#define DOARGS_4	_DOARGS_4 (24)
#define POPARGS_4	_POPARGS_4
#define _PUSHARGS_4	pushl %esi; cfi_adjust_cfa_offset (4); \
			cfi_rel_offset (esi, 0); L(PUSHSI1): _PUSHARGS_3
#define _DOARGS_4(n)	movl n(%esp), %esi; _DOARGS_3 (n-4)
#define _POPARGS_4	_POPARGS_3; popl %esi; cfi_adjust_cfa_offset (-4); \
			cfi_restore (esi); L(POPSI1):

#define PUSHARGS_5	_PUSHARGS_5
#define DOARGS_5	_DOARGS_5 (32)
#define POPARGS_5	_POPARGS_5
#define _PUSHARGS_5	pushl %edi; cfi_adjust_cfa_offset (4); \
			cfi_rel_offset (edi, 0); L(PUSHDI1): _PUSHARGS_4
#define _DOARGS_5(n)	movl n(%esp), %edi; _DOARGS_4 (n-4)
#define _POPARGS_5	_POPARGS_4; popl %edi; cfi_adjust_cfa_offset (-4); \
			cfi_restore (edi); L(POPDI1):

#define PUSHARGS_6	_PUSHARGS_6
#define DOARGS_6	_DOARGS_6 (40)
#define POPARGS_6	_POPARGS_6
#define _PUSHARGS_6	pushl %ebp; cfi_adjust_cfa_offset (4); \
			cfi_rel_offset (ebp, 0); L(PUSHBP1): _PUSHARGS_5
#define _DOARGS_6(n)	movl n(%esp), %ebp; _DOARGS_5 (n-4)
#define _POPARGS_6	_POPARGS_5; popl %ebp; cfi_adjust_cfa_offset (-4); \
			cfi_restore (ebp); L(POPBP1):

#else	/* !__ASSEMBLER__ */

extern int __syscall_error (int)
  attribute_hidden __attribute__ ((__regparm__ (1)));

/* Six-argument syscalls use an out-of-line helper, because an inline
   asm using all registers apart from %esp cannot work reliably and
   the assembler does not support describing an asm that saves and
   restores %ebp itself as a separate stack frame.  This structure
   stores the arguments not passed in registers; %edi is passed with a
   pointer to this structure.  */
struct libc_do_syscall_args
{
  int ebx, edi, ebp;
};

# define VDSO_NAME  "LINUX_2.6"
# define VDSO_HASH  61765110

/* List of system calls which are supported as vsyscalls.  */
# define HAVE_CLOCK_GETTIME_VSYSCALL    "__vdso_clock_gettime"
# define HAVE_CLOCK_GETTIME64_VSYSCALL  "__vdso_clock_gettime64"
# define HAVE_GETTIMEOFDAY_VSYSCALL     "__vdso_gettimeofday"
# define HAVE_TIME_VSYSCALL             "__vdso_time"
# define HAVE_CLOCK_GETRES_VSYSCALL     "__vdso_clock_getres"

# define HAVE_CLONE3_WRAPPER		1

# undef HAVE_INTERNAL_BRK_ADDR_SYMBOL
# define HAVE_INTERNAL_BRK_ADDR_SYMBOL 1

/* Define a macro which expands inline into the wrapper code for a system
   call.  This use is for internal calls that do not need to handle errors
   normally.  It will never touch errno.  This returns just what the kernel
   gave back.

   The _NCS variant allows non-constant syscall numbers but it is not
   possible to use more than four parameters.  */
#undef INTERNAL_SYSCALL
#define INTERNAL_SYSCALL_MAIN_0(name, args...) \
    INTERNAL_SYSCALL_MAIN_INLINE(name, 0, args)
#define INTERNAL_SYSCALL_MAIN_1(name, args...) \
    INTERNAL_SYSCALL_MAIN_INLINE(name, 1, args)
#define INTERNAL_SYSCALL_MAIN_2(name, args...) \
    INTERNAL_SYSCALL_MAIN_INLINE(name, 2, args)
#define INTERNAL_SYSCALL_MAIN_3(name, args...) \
    INTERNAL_SYSCALL_MAIN_INLINE(name, 3, args)
#define INTERNAL_SYSCALL_MAIN_4(name, args...) \
    INTERNAL_SYSCALL_MAIN_INLINE(name, 4, args)
#define INTERNAL_SYSCALL_MAIN_5(name, args...) \
    INTERNAL_SYSCALL_MAIN_INLINE(name, 5, args)

#define INTERNAL_SYSCALL_MAIN_NCS_0(name, args...) \
    INTERNAL_SYSCALL_MAIN_NCS(name, 0, args)
#define INTERNAL_SYSCALL_MAIN_NCS_1(name, args...) \
    INTERNAL_SYSCALL_MAIN_NCS(name, 1, args)
#define INTERNAL_SYSCALL_MAIN_NCS_2(name, args...) \
    INTERNAL_SYSCALL_MAIN_NCS(name, 2, args)
#define INTERNAL_SYSCALL_MAIN_NCS_3(name, args...) \
    INTERNAL_SYSCALL_MAIN_NCS(name, 3, args)
#define INTERNAL_SYSCALL_MAIN_NCS_4(name, args...) \
    INTERNAL_SYSCALL_MAIN_NCS(name, 4, args)
#define INTERNAL_SYSCALL_MAIN_NCS_5(name, args...) \
    INTERNAL_SYSCALL_MAIN_NCS(name, 5, args)

/* Each object using 6-argument inline syscalls must include a
   definition of __libc_do_syscall.  */
#define INTERNAL_SYSCALL_MAIN_6(name, arg1, arg2, arg3,			\
				arg4, arg5, arg6)			\
  struct libc_do_syscall_args _xv =					\
    {									\
      (int) (arg1),							\
      (int) (arg5),							\
      (int) (arg6)							\
    };									\
    asm volatile (							\
    "movl %1, %%eax\n\t"						\
    "call " I386_DO_SYSCALL_STRING					\
    : "=a" (resultvar)							\
    : "i" (__NR_##name), "c" (arg2), "d" (arg3), "S" (arg4), "D" (&_xv) \
    : "memory", "cc")
#define INTERNAL_SYSCALL_MAIN_NCS_6(name, arg1, arg2, arg3,		\
				    arg4, arg5, arg6)			\
  struct libc_do_syscall_args _xv =					\
    {									\
      (int) (arg1),							\
      (int) (arg5),							\
      (int) (arg6)							\
    };									\
    asm volatile (							\
    "movl %1, %%eax\n\t"						\
    "call " I386_DO_SYSCALL_STRING					\
    : "=a" (resultvar)							\
    : "a" (name), "c" (arg2), "d" (arg3), "S" (arg4), "D" (&_xv)	\
    : "memory", "cc")

#define INTERNAL_SYSCALL(name, nr, args...) \
  ({									      \
    register unsigned int resultvar;					      \
    INTERNAL_SYSCALL_MAIN_##nr (name, args);			      	      \
    (int) resultvar; })
#define INTERNAL_SYSCALL_NCS(name, nr, args...) \
  ({									      \
    register unsigned int resultvar;					      \
    INTERNAL_SYSCALL_MAIN_NCS_##nr (name, args);		      	      \
    (int) resultvar; })

#if I386_USE_SYSENTER
# ifdef PIC
#  define INTERNAL_SYSCALL_MAIN_INLINE(name, nr, args...) \
    LOADREGS_##nr(args)							\
    asm volatile (							\
    "call *%%gs:%P2"							\
    : "=a" (resultvar)							\
    : "a" (__NR_##name), "i" (offsetof (tcbhead_t, sysinfo))		\
      ASMARGS_##nr(args) : "memory", "cc")
#  define INTERNAL_SYSCALL_MAIN_NCS(name, nr, args...) \
    LOADREGS_##nr(args)							\
    asm volatile (							\
    "call *%%gs:%P2"							\
    : "=a" (resultvar)							\
    : "a" (name), "i" (offsetof (tcbhead_t, sysinfo))			\
      ASMARGS_##nr(args) : "memory", "cc")
# else /* I386_USE_SYSENTER && !PIC */
#  define INTERNAL_SYSCALL_MAIN_INLINE(name, nr, args...) \
    LOADREGS_##nr(args)							\
    asm volatile (							\
    "call *_dl_sysinfo"							\
    : "=a" (resultvar)							\
    : "a" (__NR_##name) ASMARGS_##nr(args) : "memory", "cc")
#  define INTERNAL_SYSCALL_MAIN_NCS(name, nr, args...) \
    LOADREGS_##nr(args)							\
    asm volatile (							\
    "call *_dl_sysinfo"							\
    : "=a" (resultvar)							\
    : "a" (name) ASMARGS_##nr(args) : "memory", "cc")
# endif /* I386_USE_SYSENTER && !PIC */
#else /* !I386_USE_SYSENTER */
# define INTERNAL_SYSCALL_MAIN_INLINE(name, nr, args...) \
    LOADREGS_##nr(args)							\
    asm volatile (							\
    "int $0x80"								\
    : "=a" (resultvar)							\
    : "a" (__NR_##name) ASMARGS_##nr(args) : "memory", "cc")
# define INTERNAL_SYSCALL_MAIN_NCS(name, nr, args...) \
    LOADREGS_##nr(args)							\
    asm volatile (							\
    "int $0x80"								\
    : "=a" (resultvar)							\
    : "a" (name) ASMARGS_##nr(args) : "memory", "cc")
#endif /* !I386_USE_SYSENTER */

#define LOADREGS_0()
#define ASMARGS_0()
#define LOADREGS_1(arg1) \
	LOADREGS_0 ()
#define ASMARGS_1(arg1) \
	ASMARGS_0 (), "b" ((unsigned int) (arg1))
#define LOADREGS_2(arg1, arg2) \
	LOADREGS_1 (arg1)
#define ASMARGS_2(arg1, arg2) \
	ASMARGS_1 (arg1), "c" ((unsigned int) (arg2))
#define LOADREGS_3(arg1, arg2, arg3) \
	LOADREGS_2 (arg1, arg2)
#define ASMARGS_3(arg1, arg2, arg3) \
	ASMARGS_2 (arg1, arg2), "d" ((unsigned int) (arg3))
#define LOADREGS_4(arg1, arg2, arg3, arg4) \
	LOADREGS_3 (arg1, arg2, arg3)
#define ASMARGS_4(arg1, arg2, arg3, arg4) \
	ASMARGS_3 (arg1, arg2, arg3), "S" ((unsigned int) (arg4))
#define LOADREGS_5(arg1, arg2, arg3, arg4, arg5) \
	LOADREGS_4 (arg1, arg2, arg3, arg4)
#define ASMARGS_5(arg1, arg2, arg3, arg4, arg5) \
	ASMARGS_4 (arg1, arg2, arg3, arg4), "D" ((unsigned int) (arg5))

#define ASMFMT_0()
#ifdef __PIC__
# define ASMFMT_1(arg1) \
	, "cd" (arg1)
# define ASMFMT_2(arg1, arg2) \
	, "d" (arg1), "c" (arg2)
# define ASMFMT_3(arg1, arg2, arg3) \
	, "D" (arg1), "c" (arg2), "d" (arg3)
# define ASMFMT_4(arg1, arg2, arg3, arg4) \
	, "D" (arg1), "c" (arg2), "d" (arg3), "S" (arg4)
# define ASMFMT_5(arg1, arg2, arg3, arg4, arg5) \
	, "0" (arg1), "m" (_xv), "c" (arg2), "d" (arg3), "S" (arg4), "D" (arg5)
#else
# define ASMFMT_1(arg1) \
	, "b" (arg1)
# define ASMFMT_2(arg1, arg2) \
	, "b" (arg1), "c" (arg2)
# define ASMFMT_3(arg1, arg2, arg3) \
	, "b" (arg1), "c" (arg2), "d" (arg3)
# define ASMFMT_4(arg1, arg2, arg3, arg4) \
	, "b" (arg1), "c" (arg2), "d" (arg3), "S" (arg4)
# define ASMFMT_5(arg1, arg2, arg3, arg4, arg5) \
	, "b" (arg1), "c" (arg2), "d" (arg3), "S" (arg4), "D" (arg5)
#endif

#define EXTRAVAR_0
#define EXTRAVAR_1
#define EXTRAVAR_2
#define EXTRAVAR_3
#define EXTRAVAR_4
#ifdef __PIC__
# define EXTRAVAR_5 int _xv;
#else
# define EXTRAVAR_5
#endif

#endif	/* __ASSEMBLER__ */

/* Each shadow stack slot takes 4 bytes.  Assuming that each stack
   frame takes 128 bytes, this is used to compute shadow stack size
   from stack size.  */
#define STACK_SIZE_TO_SHADOW_STACK_SIZE_SHIFT 5

#endif /* linux/i386/sysdep.h */
