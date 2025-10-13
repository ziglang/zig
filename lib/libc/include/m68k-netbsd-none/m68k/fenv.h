/*	$NetBSD: fenv.h,v 1.8 2019/10/26 17:51:49 christos Exp $	*/

/*-
 * Copyright (c) 2015 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Christos Zoulas.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _M68K_FENV_H_
#define _M68K_FENV_H_

#include <sys/stdint.h>
#include <m68k/float.h>
#include <m68k/fpreg.h>

/* Exception bits, from FPSR */
#define	FE_INEXACT	FPSR_AINEX
#define	FE_DIVBYZERO	FPSR_ADZ
#define	FE_UNDERFLOW	FPSR_AUNFL
#define	FE_OVERFLOW	FPSR_AOVFL
#define	FE_INVALID	FPSR_AIOP

#define FE_ALL_EXCEPT \
    (FE_INEXACT | FE_DIVBYZERO | FE_UNDERFLOW | FE_OVERFLOW | FE_INVALID)

/* Rounding modes, from FPCR */
#define FE_TONEAREST	FPCR_NEAR
#define	FE_TOWARDZERO	FPCR_ZERO
#define	FE_DOWNWARD	FPCR_MINF
#define	FE_UPWARD	FPCR_PINF

#define _ROUND_MASK	\
    (FE_TONEAREST | FE_TOWARDZERO | FE_DOWNWARD | FE_UPWARD)

#if defined(__HAVE_68881__)

#ifndef __fenv_static
#define __fenv_static   static
#endif

typedef uint32_t fexcept_t;

/* same layout as fmovem */
typedef struct {
	uint32_t fpcr;
	uint32_t fpsr;
	uint32_t fppc;
} fenv_t;

#define FE_DFL_ENV	((fenv_t *) -1)

#define __get_fpcr(__fpcr) \
    __asm__ __volatile__ ("fmove%.l %!,%0" : "=dm" (__fpcr))
#define __set_fpcr(__fpcr) \
    __asm__ __volatile__ ("fmove%.l %0,%!" : : "dm" (__fpcr))

#define __get_fpsr(__fpsr) \
    __asm__ __volatile__ ("fmove%.l %/fpsr,%0" : "=dm" (__fpsr))
#define __set_fpsr(__fpsr) \
    __asm__ __volatile__ ("fmove%.l %0,%/fpsr" : : "dm" (__fpsr))

#define __fmul(__s, __t, __d) \
    do { \
	    __t d = __d; \
	    __asm__ __volatile__ ("fmul" __s "; fnop" : "=f" (d) : "0" (d)); \
    } while (/*CONSTCOND*/0) 

#define __fdiv(__s, __t, __d) \
    do { \
	    __t d = __d; \
	    __asm__ __volatile__ ("fdiv" __s "; fnop" : "=f" (d) : "0" (d)); \
    } while (/*CONSTCOND*/0) 

#define __fetox(__s, __t, __d) \
    do { \
	    __t d = __d; \
	    __asm__ __volatile__ ("fetox" __s "; fnop" : "=f" (d) : "0" (d)); \
    } while (/*CONSTCOND*/0) 

#define __fgetenv(__envp) \
    __asm__ __volatile__ ("fmovem%.l %/fpcr/%/fpsr/%/fpiar,%0" : "=m" (__envp))

#define __fsetenv(__envp) \
    __asm__ __volatile__ ("fmovem%.l %0,%/fpcr/%/fpsr/%/fpiar" : : "m" (__envp))

__BEGIN_DECLS

#if __GNUC_PREREQ__(8, 0)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#endif

__fenv_static inline int
feclearexcept(int __excepts)
{
	fexcept_t __fpsr;

	__excepts &= FE_ALL_EXCEPT;

	__get_fpsr(__fpsr);
	__fpsr &= ~__excepts;
	__set_fpsr(__fpsr);

	return 0;
}

__fenv_static inline int
fegetexceptflag(fexcept_t *__flagp, int __excepts)
{
	fexcept_t __fpsr;

	__get_fpsr(__fpsr);

	*__flagp = __fpsr & __excepts & FE_ALL_EXCEPT;

	return 0;
}

__fenv_static inline int
fesetexceptflag(const fexcept_t *__flagp, int __excepts)
{
	fexcept_t __fpsr;

	__get_fpsr(__fpsr);

	__fpsr &= ~(__excepts & FE_ALL_EXCEPT);
	__fpsr |= *__flagp & __excepts & FE_ALL_EXCEPT;

	__set_fpsr(__fpsr);

	return 0;
}

__fenv_static inline int
feraiseexcept(int __excepts)
{
	if (__excepts & FE_INVALID)	/* Inf * 0 */
		__fmul("%.s %#0r0,%0", double, __builtin_huge_val());

	if (__excepts & FE_DIVBYZERO)	/* 1.0 / 0 */
		__fdiv("%.s %#0r0,%0", double, 1.0);

	if (__excepts & FE_OVERFLOW)	/* MAX * MAX */
		__fmul("%.x %0,%0", long double, LDBL_MAX);

	if (__excepts & FE_UNDERFLOW)	/* e ^ -MAX */
		__fetox("%.x %0", long double, -LDBL_MAX);

	if (__excepts & FE_INEXACT)	/* 1 / 3 */
		__fdiv("%.s %#0r3,%0", long double, 1.0);

	return 0;
}

__fenv_static inline int
fetestexcept(int __excepts)
{
	fexcept_t __fpsr;

	__get_fpsr(__fpsr);

	return __fpsr & __excepts & FE_ALL_EXCEPT;
}

__fenv_static inline int
fegetround(void)
{
	fexcept_t __fpcr;

	__get_fpcr(__fpcr);
	return __fpcr & _ROUND_MASK;
}

__fenv_static inline int
fesetround(int __round)
{
	fexcept_t __fpcr;

	if (__round & ~_ROUND_MASK)
		return -1;

	__get_fpcr(__fpcr);

	__fpcr &= ~_ROUND_MASK;
	__fpcr |= __round;

	__set_fpcr(__fpcr);

	return 0;
}

__fenv_static inline int
fegetenv(fenv_t *__envp)
{
	__fgetenv(*__envp);

	return 0;
}

__fenv_static inline int
feholdexcept(fenv_t *__envp)
{
	fexcept_t __fpcr, __fpsr;

	__fgetenv(*__envp);
	__fpsr = __envp->fpsr & ~FE_ALL_EXCEPT;
	__set_fpsr(__fpsr);	/* clear all */
	__fpcr = __envp->fpcr & ~(FE_ALL_EXCEPT << 6);
	__set_fpcr(__fpcr);	/* set non/stop */

	return 0;
}

__fenv_static inline int
fesetenv(const fenv_t *__envp)
{
	fenv_t __tenv;

	__fgetenv(__tenv);

	if (__envp == FE_DFL_ENV) {
		__tenv.fpcr |=
		    __envp->fpcr & ((FE_ALL_EXCEPT << 6) | FE_UPWARD);
		__tenv.fpsr |= __envp->fpsr & FE_ALL_EXCEPT;
	}

	__fsetenv(__tenv);

	return 0;
}

__fenv_static inline int
feupdateenv(const fenv_t *__envp)
{
	fexcept_t __fpsr;

	__get_fpsr(__fpsr);
	__fpsr &= FE_ALL_EXCEPT;
	fesetenv(__envp);
	feraiseexcept((int)__fpsr);
	return 0;
}

#if __GNUC_PREREQ__(8, 0)
#pragma GCC diagnostic pop
#endif

#if defined(_NETBSD_SOURCE) || defined(_GNU_SOURCE)

__fenv_static inline int
feenableexcept(int __mask)
{
	fexcept_t __fpcr, __oldmask;

	__get_fpcr(__fpcr);
	__oldmask = (__fpcr >> 6) & FE_ALL_EXCEPT;
	__fpcr |= (__mask & FE_ALL_EXCEPT) << 6;
	__set_fpcr(__fpcr);

	return __oldmask;
}

__fenv_static inline int
fedisableexcept(int __mask)
{
	fexcept_t __fpcr, __oldmask;

	__get_fpcr(__fpcr);
	__oldmask = (__fpcr >> 6) & FE_ALL_EXCEPT;
	__fpcr &= ~((__mask & FE_ALL_EXCEPT) << 6);
	__set_fpcr(__fpcr);

	return __oldmask;
}

__fenv_static inline int
fegetexcept(void)
{
	fexcept_t __fpcr;

	__get_fpcr(__fpcr);

	return (__fpcr >> 6) & FE_ALL_EXCEPT;
}

#endif /* _NETBSD_SOURCE || _GNU_SOURCE */

__END_DECLS

#endif /* __HAVE_68881__ */

#endif /* _M68K_FENV_H_ */