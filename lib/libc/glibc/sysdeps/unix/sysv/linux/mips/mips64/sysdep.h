/* Copyright (C) 2000-2024 Free Software Foundation, Inc.
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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _LINUX_MIPS_SYSDEP_H
#define _LINUX_MIPS_SYSDEP_H 1

/* There is some commonality.  */
#include <sysdeps/unix/sysv/linux/mips/sysdep.h>
#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <sysdeps/unix/mips/mips64/sysdep.h>

#include <tls.h>

/* For Linux we can use the system call table in the header file
	/usr/include/asm/unistd.h
   of the kernel.  But these symbols do not follow the SYS_* syntax
   so we have to redefine the `SYS_ify' macro here.  */
#undef SYS_ify
#define SYS_ify(syscall_name)	__NR_##syscall_name

#ifdef __ASSEMBLER__

/* We don't want the label for the error handler to be visible in the symbol
   table when we define it here.  */
# undef SYSCALL_ERROR_LABEL
# define SYSCALL_ERROR_LABEL 99b

#else   /* ! __ASSEMBLER__ */

#undef HAVE_INTERNAL_BRK_ADDR_SYMBOL
#define HAVE_INTERNAL_BRK_ADDR_SYMBOL 1

#if _MIPS_SIM == _ABIN32
/* Convert X to a long long, without losing any bits if it is one
   already or warning if it is a 32-bit pointer.  */
# define ARGIFY(X) ((long long int) (__typeof__ ((X) - (X))) (X))
typedef long long int __syscall_arg_t;
#else
# define ARGIFY(X) ((long int) (X))
typedef long int __syscall_arg_t;
#endif

/* Note that the original Linux syscall restart convention required the
   instruction immediately preceding SYSCALL to initialize $v0 with the
   syscall number.  Then if a restart triggered, $v0 would have been
   clobbered by the syscall interrupted, and needed to be reinititalized.
   The kernel would decrement the PC by 4 before switching back to the
   user mode so that $v0 had been reloaded before SYSCALL was executed
   again.  This implied the place $v0 was loaded from must have been
   preserved across a syscall, e.g. an immediate, static register, stack
   slot, etc.

   The convention was relaxed in Linux with a change applied to the kernel
   GIT repository as commit 96187fb0bc30cd7919759d371d810e928048249d, that
   first appeared in the 2.6.36 release.  Since then the kernel has had
   code that reloads $v0 upon syscall restart and resumes right at the
   SYSCALL instruction, so no special arrangement is needed anymore.

   For backwards compatibility with existing kernel binaries we support
   the old convention by choosing the instruction preceding SYSCALL
   carefully.  This also means we have to force a 32-bit encoding of the
   microMIPS MOVE instruction if one is used.  */

#ifdef __mips_micromips
# define MOVE32 "move32"
#else
# define MOVE32 "move"
#endif

#undef INTERNAL_SYSCALL
#define INTERNAL_SYSCALL(name, nr, args...)			\
	internal_syscall##nr ("li\t%0, %2\t\t\t# " #name "\n\t",	\
			      "IK" (SYS_ify (name)),			\
			      0, args)

#undef INTERNAL_SYSCALL_NCS
#define INTERNAL_SYSCALL_NCS(number, nr, args...)			\
	internal_syscall##nr (MOVE32 "\t%0, %2\n\t",			\
			      "r" (__s0),				\
			      number, args)

#define internal_syscall0(v0_init, input, number, dummy...)	\
({									\
	long int _sys_result;						\
									\
	{								\
	register __syscall_arg_t __s0 asm ("$16") __attribute__ ((unused))\
	  = (number);							\
	register __syscall_arg_t __v0 asm ("$2");			\
	register __syscall_arg_t __a3 asm ("$7");			\
	__asm__ volatile (						\
	".set\tnoreorder\n\t"						\
	v0_init								\
	"syscall\n\t"							\
	".set reorder"							\
	: "=r" (__v0), "=r" (__a3)					\
	: input								\
	: __SYSCALL_CLOBBERS);						\
	_sys_result = __a3 != 0 ? -__v0 : __v0;				\
	}								\
	_sys_result;							\
})

#define internal_syscall1(v0_init, input, number, arg1)		\
({									\
	long int _sys_result;						\
									\
	{								\
	__syscall_arg_t _arg1 = ARGIFY (arg1);				\
	register __syscall_arg_t __s0 asm ("$16") __attribute__ ((unused))\
	  = (number);							\
	register __syscall_arg_t __v0 asm ("$2");			\
	register __syscall_arg_t __a0 asm ("$4") = _arg1;		\
	register __syscall_arg_t __a3 asm ("$7");			\
	__asm__ volatile (						\
	".set\tnoreorder\n\t"						\
	v0_init								\
	"syscall\n\t"							\
	".set reorder"							\
	: "=r" (__v0), "=r" (__a3)					\
	: input, "r" (__a0)						\
	: __SYSCALL_CLOBBERS);						\
	_sys_result = __a3 != 0 ? -__v0 : __v0;				\
	}								\
	_sys_result;							\
})

#define internal_syscall2(v0_init, input, number, arg1, arg2)	\
({									\
	long int _sys_result;						\
									\
	{								\
	__syscall_arg_t _arg1 = ARGIFY (arg1);				\
	__syscall_arg_t _arg2 = ARGIFY (arg2);				\
	register __syscall_arg_t __s0 asm ("$16") __attribute__ ((unused))\
	  = (number);							\
	register __syscall_arg_t __v0 asm ("$2");			\
	register __syscall_arg_t __a0 asm ("$4") = _arg1;		\
	register __syscall_arg_t __a1 asm ("$5") = _arg2;		\
	register __syscall_arg_t __a3 asm ("$7");			\
	__asm__ volatile (						\
	".set\tnoreorder\n\t"						\
	v0_init								\
	"syscall\n\t"							\
	".set\treorder"							\
	: "=r" (__v0), "=r" (__a3)					\
	: input, "r" (__a0), "r" (__a1)					\
	: __SYSCALL_CLOBBERS);						\
	_sys_result = __a3 != 0 ? -__v0 : __v0;				\
	}								\
	_sys_result;							\
})

#define internal_syscall3(v0_init, input, number, arg1, arg2, arg3)	\
({									\
	long int _sys_result;						\
									\
	{								\
	__syscall_arg_t _arg1 = ARGIFY (arg1);				\
	__syscall_arg_t _arg2 = ARGIFY (arg2);				\
	__syscall_arg_t _arg3 = ARGIFY (arg3);				\
	register __syscall_arg_t __s0 asm ("$16") __attribute__ ((unused))\
	  = (number);							\
	register __syscall_arg_t __v0 asm ("$2");			\
	register __syscall_arg_t __a0 asm ("$4") = _arg1;		\
	register __syscall_arg_t __a1 asm ("$5") = _arg2;		\
	register __syscall_arg_t __a2 asm ("$6") = _arg3;		\
	register __syscall_arg_t __a3 asm ("$7");			\
	__asm__ volatile (						\
	".set\tnoreorder\n\t"						\
	v0_init								\
	"syscall\n\t"							\
	".set\treorder"							\
	: "=r" (__v0), "=r" (__a3)					\
	: input, "r" (__a0), "r" (__a1), "r" (__a2)			\
	: __SYSCALL_CLOBBERS);						\
	_sys_result = __a3 != 0 ? -__v0 : __v0;				\
	}								\
	_sys_result;							\
})

#define internal_syscall4(v0_init, input, number, arg1, arg2, arg3, 	\
			  arg4)						\
({									\
	long int _sys_result;						\
									\
	{								\
	__syscall_arg_t _arg1 = ARGIFY (arg1);				\
	__syscall_arg_t _arg2 = ARGIFY (arg2);				\
	__syscall_arg_t _arg3 = ARGIFY (arg3);				\
	__syscall_arg_t _arg4 = ARGIFY (arg4);				\
	register __syscall_arg_t __s0 asm ("$16") __attribute__ ((unused))\
	  = (number);							\
	register __syscall_arg_t __v0 asm ("$2");			\
	register __syscall_arg_t __a0 asm ("$4") = _arg1;		\
	register __syscall_arg_t __a1 asm ("$5") = _arg2;		\
	register __syscall_arg_t __a2 asm ("$6") = _arg3;		\
	register __syscall_arg_t __a3 asm ("$7") = _arg4;		\
	__asm__ volatile (						\
	".set\tnoreorder\n\t"						\
	v0_init								\
	"syscall\n\t"							\
	".set\treorder"							\
	: "=r" (__v0), "+r" (__a3)					\
	: input, "r" (__a0), "r" (__a1), "r" (__a2)			\
	: __SYSCALL_CLOBBERS);						\
	_sys_result = __a3 != 0 ? -__v0 : __v0;				\
	}								\
	_sys_result;							\
})

#define internal_syscall5(v0_init, input, number, arg1, arg2, arg3, 	\
			  arg4, arg5)					\
({									\
	long int _sys_result;						\
									\
	{								\
	__syscall_arg_t _arg1 = ARGIFY (arg1);				\
	__syscall_arg_t _arg2 = ARGIFY (arg2);				\
	__syscall_arg_t _arg3 = ARGIFY (arg3);				\
	__syscall_arg_t _arg4 = ARGIFY (arg4);				\
	__syscall_arg_t _arg5 = ARGIFY (arg5);				\
	register __syscall_arg_t __s0 asm ("$16") __attribute__ ((unused))\
	  = (number);							\
	register __syscall_arg_t __v0 asm ("$2");			\
	register __syscall_arg_t __a0 asm ("$4") = _arg1;		\
	register __syscall_arg_t __a1 asm ("$5") = _arg2;		\
	register __syscall_arg_t __a2 asm ("$6") = _arg3;		\
	register __syscall_arg_t __a3 asm ("$7") = _arg4;		\
	register __syscall_arg_t __a4 asm ("$8") = _arg5;		\
	__asm__ volatile (						\
	".set\tnoreorder\n\t"						\
	v0_init								\
	"syscall\n\t"							\
	".set\treorder"							\
	: "=r" (__v0), "+r" (__a3)					\
	: input, "r" (__a0), "r" (__a1), "r" (__a2), "r" (__a4)		\
	: __SYSCALL_CLOBBERS);						\
	_sys_result = __a3 != 0 ? -__v0 : __v0;				\
	}								\
	_sys_result;							\
})

#define internal_syscall6(v0_init, input, number, arg1, arg2, arg3, 	\
			  arg4, arg5, arg6)				\
({									\
	long int _sys_result;						\
									\
	{								\
	__syscall_arg_t _arg1 = ARGIFY (arg1);				\
	__syscall_arg_t _arg2 = ARGIFY (arg2);				\
	__syscall_arg_t _arg3 = ARGIFY (arg3);				\
	__syscall_arg_t _arg4 = ARGIFY (arg4);				\
	__syscall_arg_t _arg5 = ARGIFY (arg5);				\
	__syscall_arg_t _arg6 = ARGIFY (arg6);				\
	register __syscall_arg_t __s0 asm ("$16") __attribute__ ((unused))\
	  = (number);							\
	register __syscall_arg_t __v0 asm ("$2");			\
	register __syscall_arg_t __a0 asm ("$4") = _arg1;		\
	register __syscall_arg_t __a1 asm ("$5") = _arg2;		\
	register __syscall_arg_t __a2 asm ("$6") = _arg3;		\
	register __syscall_arg_t __a3 asm ("$7") = _arg4;		\
	register __syscall_arg_t __a4 asm ("$8") = _arg5;		\
	register __syscall_arg_t __a5 asm ("$9") = _arg6;		\
	__asm__ volatile (						\
	".set\tnoreorder\n\t"						\
	v0_init								\
	"syscall\n\t"							\
	".set\treorder"							\
	: "=r" (__v0), "+r" (__a3)					\
	: input, "r" (__a0), "r" (__a1), "r" (__a2), "r" (__a4),	\
	  "r" (__a5)							\
	: __SYSCALL_CLOBBERS);						\
	_sys_result = __a3 != 0 ? -__v0 : __v0;				\
	}								\
	_sys_result;							\
})

#if __mips_isa_rev >= 6
# define __SYSCALL_CLOBBERS "$1", "$3", "$10", "$11", "$12", "$13", \
	 "$14", "$15", "$24", "$25", "memory"
#else
# define __SYSCALL_CLOBBERS "$1", "$3", "$10", "$11", "$12", "$13", \
	 "$14", "$15", "$24", "$25", "hi", "lo", "memory"
#endif

#endif /* __ASSEMBLER__ */

#endif /* linux/mips/sysdep.h */
