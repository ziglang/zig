/*	$NetBSD: aout_machdep.h,v 1.8 2018/03/17 04:16:09 ryo Exp $	*/

/*
 * Copyright (c) 1994-1996 Mark Brinicombe.
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by Mark Brinicombe
 * 4. The name of the author may not be used to endorse or promote
 *    products derived from this software without specific prior written
 *    permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _ARM_AOUT_MACHDEP_H_
#define _ARM_AOUT_MACHDEP_H_

#define	AOUT_LDPGSZ	4096

/* Relocation format. */

struct relocation_info_arm6 {
	int r_address;		/* offset in text or data segment */
	unsigned r_symbolnum:24;/* ordinal number of add symbol */
	unsigned r_pcrel:1;	/* 1 if value should be pc-relative */
	unsigned r_length:2;	/* 0=byte, 1=word, 2=long, 3=24bits shifted by 2 */
	unsigned r_extern:1;	/* 1 if need to add symbol to value */
	unsigned r_neg:1;	/* 1 if addend is negative */
	unsigned r_baserel:1;	/* 1 if linkage table relative */
	unsigned r_jmptable:1;	/* 1 if relocation to jump table */
	unsigned r_relative:1;	/* 1 if load address relative */
};

#define relocation_info relocation_info_arm6

/* No special executable format */
#define	cpu_exec_aout_makecmds(a, b)	ENOEXEC

#endif	/* _ARM_AOUT_MACHDEP_H_ */