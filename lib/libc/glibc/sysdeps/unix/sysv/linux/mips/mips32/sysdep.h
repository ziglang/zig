/* Copyright (C) 2000-2025 Free Software Foundation, Inc.
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

#ifndef _LINUX_MIPS_MIPS32_SYSDEP_H
#define _LINUX_MIPS_MIPS32_SYSDEP_H 1

/* mips32 have cancelable syscalls with 7 arguments (currently only
   sync_file_range).  */
#define HAVE_CANCELABLE_SYSCALL_WITH_7_ARGS	1

/* There is some commonality.  */
#include <sysdeps/unix/sysv/linux/mips/sysdep.h>
#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <sysdeps/unix/mips/mips32/sysdep.h>

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
#ifdef __PIC__
# undef SYSCALL_ERROR_LABEL
# define SYSCALL_ERROR_LABEL 99b
#endif

#else   /* ! __ASSEMBLER__ */

#undef HAVE_INTERNAL_BRK_ADDR_SYMBOL
#define HAVE_INTERNAL_BRK_ADDR_SYMBOL 1

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
#undef INTERNAL_SYSCALL_NCS

#define __nomips16 __attribute__ ((nomips16))

union __mips_syscall_return
  {
    long long int val;
    struct
      {
	long int v0;
	long int v1;
      }
    reg;
  };

#ifdef __mips16
/* There's no MIPS16 syscall instruction, so we go through out-of-line
   standard MIPS wrappers.  These do use inline snippets below though,
   through INTERNAL_SYSCALL_MIPS16.  Spilling the syscall number to
   memory gives the best code in that case, avoiding the need to save
   and restore a static register.  */

# include <mips16-syscall.h>

# define INTERNAL_SYSCALL(name, nr, args...)				\
	INTERNAL_SYSCALL_NCS (SYS_ify (name), nr, args)

# define INTERNAL_SYSCALL_NCS(number, nr, args...)			\
({									\
	union __mips_syscall_return _sc_ret;				\
	_sc_ret.val = __mips16_syscall##nr (args, number);		\
	_sc_ret.reg.v0;							\
})

# define INTERNAL_SYSCALL_MIPS16(number, err, nr, args...)		\
	internal_syscall##nr ("lw\t%0, %2\n\t",				\
			      "R" (number),				\
			      number, err, args)

#else /* !__mips16 */
# define INTERNAL_SYSCALL(name, nr, args...)				\
	internal_syscall##nr ("li\t%0, %2\t\t\t# " #name "\n\t",	\
			      "IK" (SYS_ify (name)),			\
			      SYS_ify (name), err, args)

# define INTERNAL_SYSCALL_NCS(number, nr, args...)			\
	internal_syscall##nr (MOVE32 "\t%0, %2\n\t",			\
			      "r" (__s0),				\
			      number, err, args)

#endif /* !__mips16 */

#define internal_syscall0(v0_init, input, number, err, dummy...)	\
({									\
	long int _sys_result;						\
									\
	{								\
	register long int __s0 asm ("$16") __attribute__ ((unused))	\
	  = (number);							\
	register long int __v0 asm ("$2");				\
	register long int __a3 asm ("$7");				\
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

#define internal_syscall1(v0_init, input, number, err, arg1)		\
({									\
	long int _sys_result;						\
									\
	{								\
	long int _arg1 = (long int) (arg1);				\
	register long int __s0 asm ("$16") __attribute__ ((unused))	\
	  = (number);							\
	register long int __v0 asm ("$2");				\
	register long int __a0 asm ("$4") = _arg1;			\
	register long int __a3 asm ("$7");				\
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

#define internal_syscall2(v0_init, input, number, err, arg1, arg2)	\
({									\
	long int _sys_result;						\
									\
	{								\
	long int _arg1 = (long int) (arg1);				\
	long int _arg2 = (long int) (arg2);				\
	register long int __s0 asm ("$16") __attribute__ ((unused))	\
	  = (number);							\
	register long int __v0 asm ("$2");				\
	register long int __a0 asm ("$4") = _arg1;			\
	register long int __a1 asm ("$5") = _arg2;			\
	register long int __a3 asm ("$7");				\
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

#define internal_syscall3(v0_init, input, number, err,			\
			  arg1, arg2, arg3)				\
({									\
	long int _sys_result;						\
									\
	{								\
	long int _arg1 = (long int) (arg1);				\
	long int _arg2 = (long int) (arg2);				\
	long int _arg3 = (long int) (arg3);				\
	register long int __s0 asm ("$16") __attribute__ ((unused))	\
	  = (number);							\
	register long int __v0 asm ("$2");				\
	register long int __a0 asm ("$4") = _arg1;			\
	register long int __a1 asm ("$5") = _arg2;			\
	register long int __a2 asm ("$6") = _arg3;			\
	register long int __a3 asm ("$7");				\
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

#define internal_syscall4(v0_init, input, number, err,			\
			  arg1, arg2, arg3, arg4)			\
({									\
	long int _sys_result;						\
									\
	{								\
	long int _arg1 = (long int) (arg1);				\
	long int _arg2 = (long int) (arg2);				\
	long int _arg3 = (long int) (arg3);				\
	long int _arg4 = (long int) (arg4);				\
	register long int __s0 asm ("$16") __attribute__ ((unused))	\
	  = (number);							\
	register long int __v0 asm ("$2");				\
	register long int __a0 asm ("$4") = _arg1;			\
	register long int __a1 asm ("$5") = _arg2;			\
	register long int __a2 asm ("$6") = _arg3;			\
	register long int __a3 asm ("$7") = _arg4;			\
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

/* Standalone MIPS wrappers used for 5, 6, and 7 argument syscalls,
   which require stack arguments.  We rely on the compiler arranging
   wrapper's arguments according to the MIPS o32 function calling
   convention, which is reused by syscalls, except for the syscall
   number passed and the error flag returned (taken care of in the
   wrapper called).  This relieves us from relying on non-guaranteed
   compiler specifics required for the stack arguments to be pushed,
   which would be the case if these syscalls were inlined.  */

long long int __nomips16 __mips_syscall5 (long int arg1, long int arg2,
					  long int arg3, long int arg4,
					  long int arg5,
					  long int number);
libc_hidden_proto (__mips_syscall5, nomips16)

#define internal_syscall5(v0_init, input, number, err,			\
			  arg1, arg2, arg3, arg4, arg5)			\
({									\
	union __mips_syscall_return _sc_ret;				\
	_sc_ret.val = __mips_syscall5 ((long int) (arg1),		\
				       (long int) (arg2),		\
				       (long int) (arg3),		\
				       (long int) (arg4),		\
				       (long int) (arg5),		\
				       (long int) (number));		\
	_sc_ret.reg.v1 != 0 ? -_sc_ret.reg.v0 : _sc_ret.reg.v0;		\
})

long long int __nomips16 __mips_syscall6 (long int arg1, long int arg2,
					  long int arg3, long int arg4,
					  long int arg5, long int arg6,
					  long int number);
libc_hidden_proto (__mips_syscall6, nomips16)

#define internal_syscall6(v0_init, input, number, err,			\
			  arg1, arg2, arg3, arg4, arg5, arg6)		\
({									\
	union __mips_syscall_return _sc_ret;				\
	_sc_ret.val = __mips_syscall6 ((long int) (arg1),		\
				       (long int) (arg2),		\
				       (long int) (arg3),		\
				       (long int) (arg4),		\
				       (long int) (arg5),		\
				       (long int) (arg6),		\
				       (long int) (number));		\
	_sc_ret.reg.v1 != 0 ? -_sc_ret.reg.v0 : _sc_ret.reg.v0;		\
})

long long int __nomips16 __mips_syscall7 (long int arg1, long int arg2,
					  long int arg3, long int arg4,
					  long int arg5, long int arg6,
					  long int arg7,
					  long int number);
libc_hidden_proto (__mips_syscall7, nomips16)

#define internal_syscall7(v0_init, input, number, err,			\
			  arg1, arg2, arg3, arg4, arg5, arg6, arg7)	\
({									\
	union __mips_syscall_return _sc_ret;				\
	_sc_ret.val = __mips_syscall7 ((long int) (arg1),		\
				       (long int) (arg2),		\
				       (long int) (arg3),		\
				       (long int) (arg4),		\
				       (long int) (arg5),		\
				       (long int) (arg6),		\
				       (long int) (arg7),		\
				       (long int) (number));		\
	_sc_ret.reg.v1 != 0 ? -_sc_ret.reg.v0 : _sc_ret.reg.v0;		\
})

#if __mips_isa_rev >= 6
# define __SYSCALL_CLOBBERS "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13", \
	 "$14", "$15", "$24", "$25", "memory"
#else
# define __SYSCALL_CLOBBERS "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13", \
	 "$14", "$15", "$24", "$25", "hi", "lo", "memory"
#endif

#endif /* __ASSEMBLER__ */

#endif /* linux/mips/mips32/sysdep.h */
