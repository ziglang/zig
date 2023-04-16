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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _LINUX_ALPHA_SYSDEP_H
#define _LINUX_ALPHA_SYSDEP_H 1

/* There is some commonality.  */
#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <sysdeps/unix/sysdep.h>
#include <dl-sysdep.h>         /* Defines RTLD_PRIVATE_ERRNO.  */

#include <tls.h>

/* For Linux we can use the system call table in the header file
	/usr/include/asm/unistd.h
   of the kernel.  But these symbols do not follow the SYS_* syntax
   so we have to redefine the `SYS_ify' macro here.  */
#undef SYS_ify
#define SYS_ify(syscall_name)	__NR_##syscall_name

#ifdef __ASSEMBLER__
#include <asm/pal.h>
#include <alpha/regdef.h>

#define __LABEL(x)	x##:

#define LEAF(name, framesize)			\
  .globl name;					\
  .align 4;					\
  .ent name, 0;					\
  __LABEL(name)					\
  .frame sp, framesize, ra

#define ENTRY(name)				\
  .globl name;					\
  .align 4;					\
  .ent name, 0;					\
  __LABEL(name)					\
  .frame sp, 0, ra

/* Mark the end of function SYM.  */
#undef END
#define END(sym)	.end sym

#ifdef PROF
# define PSEUDO_PROF				\
	.set noat;				\
	lda	AT, _mcount;			\
	jsr	AT, (AT), _mcount;		\
	.set at
#else
# define PSEUDO_PROF
#endif

#ifdef PROF
# define PSEUDO_PROLOGUE			\
	.frame sp, 0, ra;			\
	ldgp	gp,0(pv);			\
	PSEUDO_PROF;				\
	.prologue 1
#elif defined PIC
# define PSEUDO_PROLOGUE			\
	.frame sp, 0, ra;			\
	.prologue 0
#else
# define PSEUDO_PROLOGUE			\
	.frame sp, 0, ra;			\
	ldgp	gp,0(pv);			\
	.prologue 1
#endif /* PROF */

#ifdef PROF
# define USEPV_PROF	std
#else
# define USEPV_PROF	no
#endif

#undef SYSCALL_ERROR_LABEL
#if RTLD_PRIVATE_ERRNO
# define SYSCALL_ERROR_LABEL	$syscall_error
# define SYSCALL_ERROR_HANDLER			\
$syscall_error:					\
	stl	v0, rtld_errno(gp)	!gprel;	\
	lda	v0, -1;				\
	ret
# define SYSCALL_ERROR_FALLTHRU
#elif defined(PIC)
# define SYSCALL_ERROR_LABEL		__syscall_error !samegp
# define SYSCALL_ERROR_HANDLER
# define SYSCALL_ERROR_FALLTHRU		br SYSCALL_ERROR_LABEL
#else
# define SYSCALL_ERROR_LABEL		$syscall_error
# define SYSCALL_ERROR_HANDLER			\
$syscall_error:					\
	jmp $31, __syscall_error
# define SYSCALL_ERROR_FALLTHRU
#endif /* RTLD_PRIVATE_ERRNO */

/* Overridden by specific syscalls.  */
#undef PSEUDO_PREPARE_ARGS
#define PSEUDO_PREPARE_ARGS	/* Nothing.  */

#define PSEUDO(name, syscall_name, args)	\
	.globl name;				\
	.align 4;				\
	.ent name,0;				\
__LABEL(name)					\
	PSEUDO_PROLOGUE;			\
	PSEUDO_PREPARE_ARGS			\
	lda	v0, SYS_ify(syscall_name);	\
	call_pal PAL_callsys;			\
	bne	a3, SYSCALL_ERROR_LABEL

#undef PSEUDO_END
#define PSEUDO_END(sym)				\
	SYSCALL_ERROR_HANDLER;			\
	END(sym)

#define PSEUDO_NOERRNO(name, syscall_name, args)	\
	.globl name;					\
	.align 4;					\
	.ent name,0;					\
__LABEL(name)						\
	PSEUDO_PROLOGUE;				\
	PSEUDO_PREPARE_ARGS				\
	lda	v0, SYS_ify(syscall_name);		\
	call_pal PAL_callsys;

#undef PSEUDO_END_NOERRNO
#define PSEUDO_END_NOERRNO(sym)  END(sym)

#define ret_NOERRNO ret

#define PSEUDO_ERRVAL(name, syscall_name, args)	\
	.globl name;					\
	.align 4;					\
	.ent name,0;					\
__LABEL(name)						\
	PSEUDO_PROLOGUE;				\
	PSEUDO_PREPARE_ARGS				\
	lda	v0, SYS_ify(syscall_name);		\
	call_pal PAL_callsys;

#undef PSEUDO_END_ERRVAL
#define PSEUDO_END_ERRVAL(sym)  END(sym)

#define ret_ERRVAL ret

#define r0	v0
#define r1	a4

#define MOVE(x,y)	mov x,y

#else /* !ASSEMBLER */

#define INTERNAL_SYSCALL(name, nr, args...) \
	internal_syscall##nr(__NR_##name, args)

#define INTERNAL_SYSCALL_NCS(name, nr, args...) \
	internal_syscall##nr(name, args)

/* The normal Alpha calling convention sign-extends 32-bit quantties
   no matter what the "real" sign of the 32-bit type.  We want to
   preserve that when filling in values for the kernel.  */
#define syscall_promote(arg) \
  (sizeof (arg) == 4 ? (long int)(int)(long int)(arg) : (long int)(arg))

#define internal_syscall_clobbers				\
	"$1", "$2", "$3", "$4", "$5", "$6", "$7", "$8",	\
	"$22", "$23", "$24", "$25", "$27", "$28", "memory"

/* It is moderately important optimization-wise to limit the lifetime
   of the hard-register variables as much as possible.  Thus we copy
   in/out as close to the asm as possible.  */

#define internal_syscall0(name, args...)			\
({								\
	register long int _sc_19 __asm__("$19");		\
	register long int _sc_0 = name;				\
	__asm__ __volatile__					\
	  ("callsys # %0 %1 <= %2"				\
	   : "+v"(_sc_0), "=r"(_sc_19)				\
	   : : internal_syscall_clobbers,			\
	     "$16", "$17", "$18", "$20", "$21");		\
	_sc_19 != 0 ? -_sc_0 : _sc_0;				\
})

#define internal_syscall1(name,arg1)				\
({								\
	register long int _tmp_16 = syscall_promote (arg1);	\
	register long int _sc_0 = name;				\
	register long int _sc_16 __asm__("$16") = _tmp_16;	\
	register long int _sc_19 __asm__("$19");		\
	__asm__ __volatile__					\
	  ("callsys # %0 %1 <= %2 %3"				\
	   : "+v"(_sc_0), "=r"(_sc_19), "+r"(_sc_16)		\
	   : : internal_syscall_clobbers,			\
	     "$17", "$18", "$20", "$21");			\
	_sc_19 != 0 ? -_sc_0 : _sc_0;				\
})

#define internal_syscall2(name,arg1,arg2)			\
({								\
	register long int _tmp_16 = syscall_promote (arg1);	\
	register long int _tmp_17 = syscall_promote (arg2);	\
	register long int _sc_0 = name;				\
	register long int _sc_16 __asm__("$16") = _tmp_16;	\
	register long int _sc_17 __asm__("$17") = _tmp_17;	\
	register long int _sc_19 __asm__("$19");		\
	__asm__ __volatile__					\
	  ("callsys # %0 %1 <= %2 %3 %4"			\
	   : "+v"(_sc_0), "=r"(_sc_19),				\
	     "+r"(_sc_16), "+r"(_sc_17)				\
	   : : internal_syscall_clobbers,			\
	     "$18", "$20", "$21");				\
	_sc_19 != 0 ? -_sc_0 : _sc_0;				\
})

#define internal_syscall3(name,arg1,arg2,arg3)			\
({								\
	register long int _tmp_16 = syscall_promote (arg1);	\
	register long int _tmp_17 = syscall_promote (arg2);	\
	register long int _tmp_18 = syscall_promote (arg3);	\
	register long int _sc_0 = name;				\
	register long int _sc_16 __asm__("$16") = _tmp_16;	\
	register long int _sc_17 __asm__("$17") = _tmp_17;	\
	register long int _sc_18 __asm__("$18") = _tmp_18;	\
	register long int _sc_19 __asm__("$19");		\
	__asm__ __volatile__					\
	  ("callsys # %0 %1 <= %2 %3 %4 %5"			\
	   : "+v"(_sc_0), "=r"(_sc_19), "+r"(_sc_16),		\
	     "+r"(_sc_17), "+r"(_sc_18)				\
	   : : internal_syscall_clobbers, "$20", "$21");	\
	_sc_19 != 0 ? -_sc_0 : _sc_0;				\
})

#define internal_syscall4(name,arg1,arg2,arg3,arg4)		\
({								\
	register long int _tmp_16 = syscall_promote (arg1);	\
	register long int _tmp_17 = syscall_promote (arg2);	\
	register long int _tmp_18 = syscall_promote (arg3);	\
	register long int _tmp_19 = syscall_promote (arg4);	\
	register long int _sc_0 = name;				\
	register long int _sc_16 __asm__("$16") = _tmp_16;	\
	register long int _sc_17 __asm__("$17") = _tmp_17;	\
	register long int _sc_18 __asm__("$18") = _tmp_18;	\
	register long int _sc_19 __asm__("$19") = _tmp_19;	\
	__asm__ __volatile__					\
	  ("callsys # %0 %1 <= %2 %3 %4 %5 %6"			\
	   : "+v"(_sc_0), "+r"(_sc_19), "+r"(_sc_16),		\
	     "+r"(_sc_17), "+r"(_sc_18)				\
	   : : internal_syscall_clobbers, "$20", "$21");	\
	_sc_19 != 0 ? -_sc_0 : _sc_0;				\
})

#define internal_syscall5(name,arg1,arg2,arg3,arg4,arg5)	\
({								\
	register long int _tmp_16 = syscall_promote (arg1);	\
	register long int _tmp_17 = syscall_promote (arg2);	\
	register long int _tmp_18 = syscall_promote (arg3);	\
	register long int _tmp_19 = syscall_promote (arg4);	\
	register long int _tmp_20 = syscall_promote (arg5);	\
	register long int _sc_0 = name;				\
	register long int _sc_16 __asm__("$16") = _tmp_16;	\
	register long int _sc_17 __asm__("$17") = _tmp_17;	\
	register long int _sc_18 __asm__("$18") = _tmp_18;	\
	register long int _sc_19 __asm__("$19") = _tmp_19;	\
	register long int _sc_20 __asm__("$20") = _tmp_20;	\
	__asm__ __volatile__					\
	  ("callsys # %0 %1 <= %2 %3 %4 %5 %6 %7"		\
	   : "+v"(_sc_0), "+r"(_sc_19), "+r"(_sc_16),		\
	     "+r"(_sc_17), "+r"(_sc_18), "+r"(_sc_20)		\
	   : : internal_syscall_clobbers, "$21");		\
	_sc_19 != 0 ? -_sc_0 : _sc_0;				\
})

#define internal_syscall6(name,arg1,arg2,arg3,arg4,arg5,arg6)	\
({								\
	register long int _tmp_16 = syscall_promote (arg1);	\
	register long int _tmp_17 = syscall_promote (arg2);	\
	register long int _tmp_18 = syscall_promote (arg3);	\
	register long int _tmp_19 = syscall_promote (arg4);	\
	register long int _tmp_20 = syscall_promote (arg5);	\
	register long int _tmp_21 = syscall_promote (arg6);	\
	register long int _sc_0 = name;				\
	register long int _sc_16 __asm__("$16") = _tmp_16;	\
	register long int _sc_17 __asm__("$17") = _tmp_17;	\
	register long int _sc_18 __asm__("$18") = _tmp_18;	\
	register long int _sc_19 __asm__("$19") = _tmp_19;	\
	register long int _sc_20 __asm__("$20") = _tmp_20;	\
	register long int _sc_21 __asm__("$21") = _tmp_21;	\
	__asm__ __volatile__					\
	  ("callsys # %0 %1 <= %2 %3 %4 %5 %6 %7 %8"		\
	   : "+v"(_sc_0), "+r"(_sc_19), "+r"(_sc_16),		\
	     "+r"(_sc_17), "+r"(_sc_18), "+r"(_sc_20),		\
	     "+r"(_sc_21)					\
	   : : internal_syscall_clobbers);			\
	_sc_19 != 0 ? -_sc_0 : _sc_0;				\
})
#endif /* ASSEMBLER */

#endif /* _LINUX_ALPHA_SYSDEP_H  */
