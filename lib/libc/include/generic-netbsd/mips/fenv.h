/*	$NetBSD: fenv.h,v 1.6 2020/07/26 08:08:41 simonb Exp $	*/

/*-
 * Copyright (c) 2004-2005 David Schultz <das@FreeBSD.ORG>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $FreeBSD: head/lib/msun/mips/fenv.h 226218 2011-10-10 15:43:09Z das $
 */

#ifndef	_MIPS_FENV_H_
#define	_MIPS_FENV_H_

#include <sys/stdint.h>

/* Exception flags */
#define	FE_INEXACT	0x0004
#define	FE_UNDERFLOW	0x0008
#define	FE_OVERFLOW	0x0010
#define	FE_DIVBYZERO	0x0020
#define	FE_INVALID	0x0040
#define	FE_ALL_EXCEPT	(FE_DIVBYZERO | FE_INEXACT | \
			 FE_INVALID | FE_OVERFLOW | FE_UNDERFLOW)

/* Rounding modes */
#define	FE_TONEAREST	0x0000
#define	FE_TOWARDZERO	0x0001
#define	FE_UPWARD	0x0002
#define	FE_DOWNWARD	0x0003
#define	_ROUND_MASK	(FE_TONEAREST | FE_DOWNWARD | \
			 FE_UPWARD | FE_TOWARDZERO)

#ifndef __mips_soft_float

#ifndef	__fenv_static
#define	__fenv_static	static
#endif

typedef	uint32_t 	fpu_control_t __attribute__((__mode__(__SI__)));
typedef	fpu_control_t	fenv_t;
typedef	fpu_control_t	fexcept_t;

__BEGIN_DECLS

/* Default floating-point environment */
extern const fenv_t	__fe_dfl_env;
#define	FE_DFL_ENV	(&__fe_dfl_env)

/* We need to be able to map status flag positions to mask flag positions */
#define	_ENABLE_MASK	(FE_ALL_EXCEPT << _ENABLE_SHIFT)
#define	_ENABLE_SHIFT    5

static inline fpu_control_t
__rfs(void)
{
	fpu_control_t __fpsr;

	__asm __volatile("cfc1 %0,$31" : "=r" (__fpsr));
	return __fpsr;
}

static inline void
__wfs(fpu_control_t __fpsr)
{

	__asm __volatile("ctc1 %0,$31" : : "r" (__fpsr));
}

#if __GNUC_PREREQ__(8, 0)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#endif

__fenv_static inline int
feclearexcept(int __excepts)
{
	fexcept_t __fpsr;

	__excepts &= FE_ALL_EXCEPT;
	__fpsr = __rfs();
	__fpsr &= ~(__excepts | (__excepts << _ENABLE_SHIFT));
	__wfs(__fpsr);
	return 0;
}

__fenv_static inline int
fegetexceptflag(fexcept_t *__flagp, int __excepts)
{
	fexcept_t __fpsr;

	__fpsr = __rfs();
	*__flagp = __fpsr & __excepts;
	return (0);
}

__fenv_static inline int
fesetexceptflag(const fexcept_t *__flagp, int __excepts)
{
	fexcept_t __fpsr;

	__fpsr = __rfs();
	__fpsr &= ~__excepts;
	__fpsr |= *__flagp & __excepts;
	__wfs(__fpsr);
	return (0);
}

__fenv_static inline int
feraiseexcept(int __excepts)
{
	fexcept_t __ex = __excepts;

	fesetexceptflag(&__ex, __excepts);	/* XXX */
	return (0);
}

__fenv_static inline int
fetestexcept(int __excepts)
{
	fexcept_t __fpsr;

	__fpsr = __rfs();
	return (__fpsr & __excepts);
}

__fenv_static inline int
fegetround(void)
{
	fexcept_t __fpsr;

	__fpsr = __rfs();
	return __fpsr & _ROUND_MASK;
}

__fenv_static inline int
fesetround(int __round)
{
	fexcept_t __fpsr;

	if (__round & ~_ROUND_MASK)
		return 1;
	__fpsr = __rfs();
	__fpsr &= ~_ROUND_MASK;
	__fpsr |= __round;
	__wfs(__fpsr);

	return 0;
}

__fenv_static inline int
fegetenv(fenv_t *__envp)
{

	*__envp = __rfs();
	return (0);
}

__fenv_static inline int
feholdexcept(fenv_t *__envp)
{
	fenv_t __env;

	__env = __rfs();
	*__envp = __env;
	__env &= ~(FE_ALL_EXCEPT | _ENABLE_MASK);
	__wfs(__env);
	return (0);
}

__fenv_static inline int
fesetenv(const fenv_t *__envp)
{

	__wfs(*__envp);
	return (0);
}

__fenv_static inline int
feupdateenv(const fenv_t *__envp)
{
	fexcept_t __fpsr;

	__fpsr = __rfs();
	__wfs(*__envp);
	feraiseexcept(__fpsr & FE_ALL_EXCEPT);
	return (0);
}

#if __GNUC_PREREQ__(8, 0)
#pragma GCC diagnostic pop
#endif

#if defined(_NETBSD_SOURCE) || defined(_GNU_SOURCE)

__fenv_static inline int
feenableexcept(int __excepts)
{
	fenv_t __old_fpsr, __new_fpsr;

	__new_fpsr = __rfs();
	__old_fpsr = (__new_fpsr & _ENABLE_MASK) >> _ENABLE_SHIFT;
	__excepts &= FE_ALL_EXCEPT;
	__new_fpsr |= __excepts << _ENABLE_SHIFT;
	__wfs(__new_fpsr);
	return __old_fpsr;
}

__fenv_static inline int
fedisableexcept(int __excepts)
{
	fenv_t __old_fpsr, __new_fpsr;

	__new_fpsr = __rfs();
	__old_fpsr = (__new_fpsr & _ENABLE_MASK) >> _ENABLE_SHIFT;
	__excepts &= FE_ALL_EXCEPT;
	__new_fpsr &= ~(__excepts << _ENABLE_SHIFT);
	__wfs(__new_fpsr);
	return __old_fpsr;
}

__fenv_static inline int
fegetexcept(void)
{
	fenv_t __fpsr;

	__fpsr = __rfs();
	return ((__fpsr & _ENABLE_MASK) >> _ENABLE_SHIFT);
}

#endif /* _NETBSD_SOURCE || _GNU_SOURCE */

__END_DECLS

#endif /* __mips_soft_float */

#endif	/* !_FENV_H_ */