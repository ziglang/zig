/*	$NetBSD: psl.h,v 1.19 2016/07/30 06:27:45 matt Exp $	*/

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Ralph Campbell.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)psl.h	8.1 (Berkeley) 6/10/93
 */

/*
 * Define PSL_LOWIPL, PSL_USERSET, USERMODE for MI code, for
 * MIPS1, MIPS3+, or both, depending on the configured CPU types.
 */

#include <machine/cdefs.h>	/* for API selection */
#include <mips/cpuregs.h>

/*
 * mips3 (or greater)-specific  definitions
 */
#define	MIPS3_PSL_LOWIPL	(MIPS3_INT_MASK | MIPS_SR_INT_IE)

#if !defined(__mips_o32)
# define MIPS3_PSL_XFLAGS	(MIPS3_SR_XX | MIPS_SR_KX)
#else
# define MIPS3_PSL_XFLAGS	(0)
#endif

#define	MIPS3_PSL_USERSET 	\
	(MIPS3_SR_KSU_USER |	\
	 MIPS3_PSL_XFLAGS |	\
	 MIPS_SR_INT_IE |	\
	 MIPS3_SR_EXL |		\
	 MIPS3_INT_MASK)

#define	MIPS3_USERMODE(ps) \
	(((ps) & MIPS3_SR_KSU_MASK) == MIPS3_SR_KSU_USER)

/*
 * mips1-specific definitions
 */
#define	MIPS1_PSL_LOWIPL	(MIPS_INT_MASK | MIPS_SR_INT_IE)

#define	MIPS1_PSL_USERSET \
	(MIPS1_SR_KU_OLD |	\
	 MIPS1_SR_INT_ENA_OLD |	\
	 MIPS1_SR_KU_PREV |	\
	 MIPS1_SR_INT_ENA_PREV |\
	 MIPS_INT_MASK)

#define	MIPS1_USERMODE(ps) \
	((ps) & MIPS1_SR_KU_PREV)

/*
 * Choose mips3-only, mips1-only, or runtime-selected values.
 */

#if defined(MIPS3_PLUS) && !defined(MIPS1) /* mips3 or greater only */
# define  PSL_LOWIPL	MIPS3_PSL_LOWIPL
# define  PSL_USERSET	MIPS3_PSL_USERSET
# define  USERMODE(ps)	MIPS3_USERMODE(ps)
#endif /* mips3 only */


#if !defined(MIPS3_PLUS) && defined(MIPS1) /* mips1 only */
# define  PSL_LOWIPL	MIPS1_PSL_LOWIPL
# define  PSL_USERSET	MIPS1_PSL_USERSET
# define  USERMODE(ps)	MIPS1_USERMODE(ps)
#endif /* mips1 only */


#if  MIPS3_PLUS +  MIPS1 > 1
# define PSL_LOWIPL	(CPUISMIPS3 ? MIPS3_PSL_LOWIPL : MIPS1_PSL_LOWIPL)
# define PSL_USERSET	(CPUISMIPS3 ? MIPS3_PSL_USERSET : MIPS1_PSL_USERSET)
# define USERMODE(ps)	(CPUISMIPS3 ? MIPS3_USERMODE(ps) : MIPS1_USERMODE(ps))
#endif