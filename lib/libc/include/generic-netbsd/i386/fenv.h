/*	$NetBSD: fenv.h,v 1.2 2014/02/12 23:04:43 dsl Exp $	*/
/*-
 * Copyright (c) 2004-2005 David Schultz <das (at) FreeBSD.ORG>
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
 */

#ifndef	_X86_FENV_H_
#define	_X86_FENV_H_

#ifndef _KERNEL
#include <sys/stdint.h>
#endif

/* Default x87 control word. */
#define __INITIAL_NPXCW__       0x037f  
/* Modern NetBSD uses the default control word.. */
#define __NetBSD_NPXCW__        __INITIAL_NPXCW__
/* NetBSD before 6.99.26 forced IEEE double precision. */
#define __NetBSD_COMPAT_NPXCW__ 0x127f

/* Default values for the mxcsr. All traps masked. */
#define __INITIAL_MXCSR__       0x1f80

#ifndef _KERNEL
/*
 * Each symbol representing a floating point exception expands to an integer
 * constant expression with values, such that bitwise-inclusive ORs of _all
 * combinations_ of the constants result in distinct values.
 *
 * We use such values that allow direct bitwise operations on FPU/SSE registers.
 */
#define	FE_INVALID	0x01	/* 000000000001 */
#define	FE_DENORMAL	0x02	/* 000000000010 */
#define	FE_DIVBYZERO	0x04	/* 000000000100 */
#define	FE_OVERFLOW	0x08	/* 000000001000 */
#define	FE_UNDERFLOW	0x10	/* 000000010000 */
#define	FE_INEXACT	0x20	/* 000000100000 */

/*
 * The following symbol is simply the bitwise-inclusive OR of all floating-point
 * exception constants defined above.
 */
#define FE_ALL_EXCEPT	(FE_DIVBYZERO | FE_DENORMAL | FE_INEXACT | \
			 FE_INVALID | FE_OVERFLOW | FE_UNDERFLOW)

/*
 * Each symbol representing the rounding direction, expands to an integer
 * constant expression whose value is distinct non-negative value.
 *
 * We use such values that allow direct bitwise operations on FPU/SSE registers.
 */
#define	FE_TONEAREST	0x000	/* 000000000000 */
#define	FE_DOWNWARD	0x400	/* 010000000000 */
#define	FE_UPWARD	0x800	/* 100000000000 */
#define	FE_TOWARDZERO	0xC00	/* 110000000000 */

/*
 * As compared to the x87 control word, the SSE unit's control has the rounding
 * control bits offset by 3 and the exception mask bits offset by 7
 */
#define	__X87_ROUND_MASK	0xC00		/* 110000000000 */
#define	__SSE_ROUND_SHIFT	3
#define	__SSE_EMASK_SHIFT	7

/*
 * fenv_t represents the entire floating-point environment
 */
typedef struct {
	struct {
		uint16_t control;	/* Control word register */
		uint16_t unused1;
		uint16_t status;	/* Status word register */
		uint16_t unused2;
		uint16_t tag;		/* Tag word register */
		uint16_t unused3;
		uint32_t others[4];	/* EIP, Pointer Selector, etc */
	} x87;
		
	uint32_t mxcsr;			/* Control and status register */
} fenv_t;

/*
 * The following constant represents the default floating-point environment
 * (that is, the one installed at program startup) and has type pointer to
 * const-qualified fenv_t.
 *
 * It can be used as an argument to the functions within the <fenv.h> header
 * that manage the floating-point environment.
 */
extern  fenv_t		__fe_dfl_env;
#define FE_DFL_ENV      ((const fenv_t *) &__fe_dfl_env)

/*
 * fexcept_t represents the floating-point status flags collectively, including
 * any status the implementation associates with the flags.
 *
 * A floating-point status flag is a system variable whose value is set (but
 * never cleared) when a floating-point exception is raised, which occurs as a
 * side effect of exceptional floating-point arithmetic to provide auxiliary
 * information.
 *
 * A floating-point control mode is a system variable whose value may be set by
 * the user to affect the subsequent behavior of floating-point arithmetic.
 */
typedef uint32_t fexcept_t;
#endif

#endif	/* ! _X86_FENV_H_ */