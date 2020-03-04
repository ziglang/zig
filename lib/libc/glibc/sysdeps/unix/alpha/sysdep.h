/* Copyright (C) 1992-2020 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Brendan Kehoe (brendan@zen.org).

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

#include <sysdeps/unix/sysdep.h>
#include <dl-sysdep.h>         /* Defines RTLD_PRIVATE_ERRNO.  */

#ifdef __ASSEMBLER__

#ifdef __linux__
# include <alpha/regdef.h>
#else
# include <regdef.h>
#endif

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

/* In order to get __set_errno() definition in INLINE_SYSCALL.  */
#include <errno.h>

/* ??? Linux needs to be able to override INLINE_SYSCALL for one
   particular special case.  Make this easy.  */

#undef INLINE_SYSCALL
#define INLINE_SYSCALL(name, nr, args...) \
	INLINE_SYSCALL1(name, nr, args)

#define INLINE_SYSCALL1(name, nr, args...)	\
({						\
	long _sc_ret, _sc_err;			\
	inline_syscall##nr(__NR_##name, args);	\
	if (__builtin_expect (_sc_err, 0))	\
	  {					\
	    __set_errno (_sc_ret);		\
	    _sc_ret = -1L;			\
	  }					\
	_sc_ret;				\
})

#define INTERNAL_SYSCALL(name, err_out, nr, args...) \
	INTERNAL_SYSCALL1(name, err_out, nr, args)

#define INTERNAL_SYSCALL1(name, err_out, nr, args...)	\
	INTERNAL_SYSCALL_NCS(__NR_##name, err_out, nr, args)

#define INTERNAL_SYSCALL_NCS(name, err_out, nr, args...) \
({							\
	long _sc_ret, _sc_err;				\
	inline_syscall##nr(name, args);			\
	err_out = _sc_err;				\
	_sc_ret;					\
})

#define INTERNAL_SYSCALL_DECL(err) \
	long int err __attribute__((unused))

/* The normal Alpha calling convention sign-extends 32-bit quantties
   no matter what the "real" sign of the 32-bit type.  We want to
   preserve that when filling in values for the kernel.  */
#define syscall_promote(arg) \
  (sizeof (arg) == 4 ? (long)(int)(long)(arg) : (long)(arg))

/* Make sure and "use" the variable that we're not returning,
   in order to suppress unused variable warnings.  */
#define INTERNAL_SYSCALL_ERROR_P(val, err)	((void)val, err)
#define INTERNAL_SYSCALL_ERRNO(val, err)	((void)err, val)

#define inline_syscall_clobbers				\
	"$1", "$2", "$3", "$4", "$5", "$6", "$7", "$8",	\
	"$22", "$23", "$24", "$25", "$27", "$28", "memory"

/* It is moderately important optimization-wise to limit the lifetime
   of the hard-register variables as much as possible.  Thus we copy
   in/out as close to the asm as possible.  */

#define inline_syscall0(name, args...)				\
{								\
	register long _sc_19 __asm__("$19");			\
	register long _sc_0 = name;				\
	__asm__ __volatile__					\
	  ("callsys # %0 %1 <= %2"				\
	   : "+v"(_sc_0), "=r"(_sc_19)				\
	   : : inline_syscall_clobbers,				\
	     "$16", "$17", "$18", "$20", "$21");		\
	_sc_ret = _sc_0, _sc_err = _sc_19;			\
}

#define inline_syscall1(name,arg1)				\
{								\
	register long _tmp_16 = syscall_promote (arg1);		\
	register long _sc_0 = name;				\
	register long _sc_16 __asm__("$16") = _tmp_16;		\
	register long _sc_19 __asm__("$19");			\
	__asm__ __volatile__					\
	  ("callsys # %0 %1 <= %2 %3"				\
	   : "+v"(_sc_0), "=r"(_sc_19), "+r"(_sc_16)		\
	   : : inline_syscall_clobbers,				\
	     "$17", "$18", "$20", "$21");			\
	_sc_ret = _sc_0, _sc_err = _sc_19;			\
}

#define inline_syscall2(name,arg1,arg2)				\
{								\
	register long _tmp_16 = syscall_promote (arg1);		\
	register long _tmp_17 = syscall_promote (arg2);		\
	register long _sc_0 = name;				\
	register long _sc_16 __asm__("$16") = _tmp_16;		\
	register long _sc_17 __asm__("$17") = _tmp_17;		\
	register long _sc_19 __asm__("$19");			\
	__asm__ __volatile__					\
	  ("callsys # %0 %1 <= %2 %3 %4"			\
	   : "+v"(_sc_0), "=r"(_sc_19),				\
	     "+r"(_sc_16), "+r"(_sc_17)				\
	   : : inline_syscall_clobbers,				\
	     "$18", "$20", "$21");				\
	_sc_ret = _sc_0, _sc_err = _sc_19;			\
}

#define inline_syscall3(name,arg1,arg2,arg3)			\
{								\
	register long _tmp_16 = syscall_promote (arg1);		\
	register long _tmp_17 = syscall_promote (arg2);		\
	register long _tmp_18 = syscall_promote (arg3);		\
	register long _sc_0 = name;				\
	register long _sc_16 __asm__("$16") = _tmp_16;		\
	register long _sc_17 __asm__("$17") = _tmp_17;		\
	register long _sc_18 __asm__("$18") = _tmp_18;		\
	register long _sc_19 __asm__("$19");			\
	__asm__ __volatile__					\
	  ("callsys # %0 %1 <= %2 %3 %4 %5"			\
	   : "+v"(_sc_0), "=r"(_sc_19), "+r"(_sc_16),		\
	     "+r"(_sc_17), "+r"(_sc_18)				\
	   : : inline_syscall_clobbers, "$20", "$21");		\
	_sc_ret = _sc_0, _sc_err = _sc_19;			\
}

#define inline_syscall4(name,arg1,arg2,arg3,arg4)		\
{								\
	register long _tmp_16 = syscall_promote (arg1);		\
	register long _tmp_17 = syscall_promote (arg2);		\
	register long _tmp_18 = syscall_promote (arg3);		\
	register long _tmp_19 = syscall_promote (arg4);		\
	register long _sc_0 = name;				\
	register long _sc_16 __asm__("$16") = _tmp_16;		\
	register long _sc_17 __asm__("$17") = _tmp_17;		\
	register long _sc_18 __asm__("$18") = _tmp_18;		\
	register long _sc_19 __asm__("$19") = _tmp_19;		\
	__asm__ __volatile__					\
	  ("callsys # %0 %1 <= %2 %3 %4 %5 %6"			\
	   : "+v"(_sc_0), "+r"(_sc_19), "+r"(_sc_16),		\
	     "+r"(_sc_17), "+r"(_sc_18)				\
	   : : inline_syscall_clobbers, "$20", "$21");		\
	_sc_ret = _sc_0, _sc_err = _sc_19;			\
}

#define inline_syscall5(name,arg1,arg2,arg3,arg4,arg5)		\
{								\
	register long _tmp_16 = syscall_promote (arg1);		\
	register long _tmp_17 = syscall_promote (arg2);		\
	register long _tmp_18 = syscall_promote (arg3);		\
	register long _tmp_19 = syscall_promote (arg4);		\
	register long _tmp_20 = syscall_promote (arg5);		\
	register long _sc_0 = name;				\
	register long _sc_16 __asm__("$16") = _tmp_16;		\
	register long _sc_17 __asm__("$17") = _tmp_17;		\
	register long _sc_18 __asm__("$18") = _tmp_18;		\
	register long _sc_19 __asm__("$19") = _tmp_19;		\
	register long _sc_20 __asm__("$20") = _tmp_20;		\
	__asm__ __volatile__					\
	  ("callsys # %0 %1 <= %2 %3 %4 %5 %6 %7"		\
	   : "+v"(_sc_0), "+r"(_sc_19), "+r"(_sc_16),		\
	     "+r"(_sc_17), "+r"(_sc_18), "+r"(_sc_20)		\
	   : : inline_syscall_clobbers, "$21");			\
	_sc_ret = _sc_0, _sc_err = _sc_19;			\
}

#define inline_syscall6(name,arg1,arg2,arg3,arg4,arg5,arg6)	\
{								\
	register long _tmp_16 = syscall_promote (arg1);		\
	register long _tmp_17 = syscall_promote (arg2);		\
	register long _tmp_18 = syscall_promote (arg3);		\
	register long _tmp_19 = syscall_promote (arg4);		\
	register long _tmp_20 = syscall_promote (arg5);		\
	register long _tmp_21 = syscall_promote (arg6);		\
	register long _sc_0 = name;				\
	register long _sc_16 __asm__("$16") = _tmp_16;		\
	register long _sc_17 __asm__("$17") = _tmp_17;		\
	register long _sc_18 __asm__("$18") = _tmp_18;		\
	register long _sc_19 __asm__("$19") = _tmp_19;		\
	register long _sc_20 __asm__("$20") = _tmp_20;		\
	register long _sc_21 __asm__("$21") = _tmp_21;		\
	__asm__ __volatile__					\
	  ("callsys # %0 %1 <= %2 %3 %4 %5 %6 %7 %8"		\
	   : "+v"(_sc_0), "+r"(_sc_19), "+r"(_sc_16),		\
	     "+r"(_sc_17), "+r"(_sc_18), "+r"(_sc_20),		\
	     "+r"(_sc_21)					\
	   : : inline_syscall_clobbers);			\
	_sc_ret = _sc_0, _sc_err = _sc_19;			\
}
#endif /* ASSEMBLER */

/* Pointer mangling support.  Note that tls access is slow enough that
   we don't deoptimize things by placing the pointer check value there.  */

#ifdef __ASSEMBLER__
# if IS_IN (rtld)
#  define PTR_MANGLE(dst, src, tmp)				\
	ldah	tmp, __pointer_chk_guard_local($29) !gprelhigh;	\
	ldq	tmp, __pointer_chk_guard_local(tmp) !gprellow;	\
	xor	src, tmp, dst
#  define PTR_MANGLE2(dst, src, tmp)				\
	xor	src, tmp, dst
# elif defined SHARED
#  define PTR_MANGLE(dst, src, tmp)		\
	ldq	tmp, __pointer_chk_guard;	\
	xor	src, tmp, dst
# else
#  define PTR_MANGLE(dst, src, tmp)		\
	ldq	tmp, __pointer_chk_guard_local;	\
	xor	src, tmp, dst
# endif
# define PTR_MANGLE2(dst, src, tmp)		\
	xor	src, tmp, dst
# define PTR_DEMANGLE(dst, tmp)   PTR_MANGLE(dst, dst, tmp)
# define PTR_DEMANGLE2(dst, tmp)  PTR_MANGLE2(dst, dst, tmp)
#else
# include <stdint.h>
# if (IS_IN (rtld) \
      || (!defined SHARED && (IS_IN (libc) \
			      || IS_IN (libpthread))))
extern uintptr_t __pointer_chk_guard_local attribute_relro attribute_hidden;
#  define PTR_MANGLE(var) \
	(var) = (__typeof (var)) ((uintptr_t) (var) ^ __pointer_chk_guard_local)
# else
extern uintptr_t __pointer_chk_guard attribute_relro;
#  define PTR_MANGLE(var) \
	(var) = (__typeof(var)) ((uintptr_t) (var) ^ __pointer_chk_guard)
# endif
# define PTR_DEMANGLE(var)  PTR_MANGLE(var)
#endif /* ASSEMBLER */
