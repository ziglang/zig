/*	$NetBSD: profile.h,v 1.25 2021/02/18 20:37:02 skrll Exp $	*/

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
 *	@(#)profile.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _MIPS_PROFILE_H_
#define	_MIPS_PROFILE_H_

#if defined(_KERNEL_OPT)
#include "opt_gprof.h"
#endif

#ifdef _KERNEL
 /*
  *  Declare non-profiled _splhigh() /_splx() entrypoints for _mcount.
  *  see MCOUNT_ENTER and MCOUNT_EXIT.
  */
#define	_KERNEL_MCOUNT_DECL		\
	int splhigh_noprof(void);	\
	void splx_noprof(int);
#else   /* !_KERNEL */
/* Make __mcount static. */
#define	_KERNEL_MCOUNT_DECL	static
#endif	/* !_KERNEL */

#ifdef _KERNEL
# define _PROF_CPLOAD	""
#else
# define _PROF_CPLOAD	".cpload $25;"
#endif


#define	_MCOUNT_DECL \
    _KERNEL_MCOUNT_DECL \
    void __attribute__((unused)) __mcount

#ifdef __mips_o32	/* 32-bit version */
#define	MCOUNT \
	__asm(".globl _mcount;" \
	      ".type _mcount,@function;" \
	      "_mcount:;" \
	      ".set noreorder;" \
	      ".set noat;" \
	      _PROF_CPLOAD \
	      "addu $29,$29,-16;" \
	      "sw $4,8($29);" \
	      "sw $5,12($29);" \
	      "sw $6,16($29);" \
	      "sw $7,20($29);" \
	      "sw $1,0($29);" \
	      "sw $31,4($29);" \
	      "move $5,$31;" \
	      "move $4,$1;" \
	      "jal __mcount;" \
	      " nop;" \
	      "lw $4,8($29);" \
	      "lw $5,12($29);" \
	      "lw $6,16($29);" \
	      "lw $7,20($29);" \
	      "lw $31,4($29);" \
	      "lw $1,0($29);" \
	      "addu $29,$29,24;" \
	      "j $31;" \
	      " move $31,$1;" \
	      ".set reorder;" \
	      ".set at");
#else /* 64-bit */
#ifdef __mips_o64
# error yeahnah
#endif
#define	MCOUNT \
	__asm(".globl _mcount;" \
	      ".type _mcount,@function;" \
	      "_mcount:;" \
	      ".set noreorder;" \
	      ".set noat;" \
	      _PROF_CPLOAD \
	      "daddu $29,$29,-80;"\
	      "sd $4,16($29);" \
	      "sd $5,24($29);" \
	      "sd $6,32($29);" \
	      "sd $7,40($29);" \
	      "sd $8,48($29);" \
	      "sd $9,56($29);" \
	      "sd $10,64($29);" \
	      "sd $11,72($29);" \
	      "sd $1,0($29);" \
	      "sd $31,8($29);" \
	      "move $5,$31;" \
	      "move $4,$1;" \
	      "jal __mcount;" \
	      " nop;" \
	      "ld $4,16($29);" \
	      "ld $5,24($29);" \
	      "ld $6,32($29);" \
	      "ld $7,40($29);" \
	      "ld $8,48($29);" \
	      "ld $9,56($29);" \
	      "ld $10,64($29);" \
	      "ld $11,72($29);" \
	      "ld $31,8($29);" \
	      "ld $1,0($29);" \
	      "daddu $29,$29,80;" \
	      "j $31;" \
	      " move $31,$1;" \
	      ".set reorder;" \
	      ".set at");
#endif /* 64-bit */

#ifdef _KERNEL
/*
 * The following two macros do splhigh and splx respectively.
 * We use versions of _splraise() and _splset that don't
 * including profiling support.
 */

#define	MCOUNT_ENTER	s = splhigh_noprof()

#define	MCOUNT_EXIT	splx_noprof(s)
#endif /* _KERNEL */

#endif /* _MIPS_PROFILE_H_ */