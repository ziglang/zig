/*	$NetBSD: fenv.h,v 1.26 2017/04/09 15:29:07 christos Exp $	*/
/*
 * Copyright (c) 2010 The NetBSD Foundation, Inc.
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
#ifndef _FENV_H_
#define _FENV_H_

#include <sys/featuretest.h>

#if defined(__vax__)
# ifndef __TEST_FENV
#  error	"fenv.h is currently not supported for this architecture"
# endif
typedef int fexcept_t;
typedef int fenv_t;
#else
# define __HAVE_FENV
# include <machine/fenv.h>
#endif

#if \
	(defined(__arm__) && defined(__SOFTFP__)) || \
	(defined(__m68k__) && !defined(__HAVE_68881__)) || \
	defined(__mips_soft_float) || \
	(defined(__powerpc__) && defined(_SOFT_FLOAT)) || \
	(defined(__sh__) && !defined(__SH_FPU_ANY__)) || \
	0

/*
 * Common definitions for softfloat.
 */

#ifndef __HAVE_FENV_SOFTFLOAT_DEFS

typedef int fexcept_t;

typedef struct {
	int	__flags;
	int	__mask;
	int	__round;
} fenv_t;

#define __FENV_GET_FLAGS(__envp)	(__envp)->__flags
#define __FENV_GET_MASK(__envp)		(__envp)->__mask
#define __FENV_GET_ROUND(__envp)	(__envp)->__round
#define __FENV_SET_FLAGS(__envp, __val) \
	(__envp)->__flags = (__val)
#define __FENV_SET_MASK(__envp, __val) \
	(__envp)->__mask = (__val)
#define __FENV_SET_ROUND(__envp, __val) \
	(__envp)->__round = (__val)

#endif /* __FENV_GET_FLAGS */

#endif /* softfloat */

__BEGIN_DECLS

/* Function prototypes */
int	feclearexcept(int);
int	fegetexceptflag(fexcept_t *, int);
int	feraiseexcept(int);
int	fesetexceptflag(const fexcept_t *, int);
int	fetestexcept(int);
int	fegetround(void);
int	fesetround(int);
int	fegetenv(fenv_t *);
int	feholdexcept(fenv_t *);
int	fesetenv(const fenv_t *);
int	feupdateenv(const fenv_t *);

#if defined(_NETBSD_SOURCE) || defined(_GNU_SOURCE)

int	feenableexcept(int);
int	fedisableexcept(int);
int	fegetexcept(void);

#endif /* _NETBSD_SOURCE || _GNU_SOURCE */

__END_DECLS

#endif /* ! _FENV_H_ */