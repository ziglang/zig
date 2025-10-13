/*	$NetBSD: tss.h,v 1.12 2018/07/07 21:35:16 kamil Exp $	*/

/*-
 * Copyright (c) 1990 The Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * William Jolitz.
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
 *	@(#)tss.h	5.4 (Berkeley) 1/18/91
 */

#ifndef _I386_TSS_H_
#define _I386_TSS_H_

/*
 * Intel 386 Context Data Type
 */

struct i386tss {
	int	__tss_link;
	int	tss_esp0; 	/* kernel stack pointer at privilege level 0 */
	int	tss_ss0;	/* kernel stack segment at privilege level 0 */
	int	__tss_esp1;
	int	__tss_ss1;
	int	__tss_esp2;
	int	__tss_ss2;
	int	tss_cr3;	/* page directory paddr */
	int	__tss_eip;
	int	__tss_eflags;
	int	__tss_eax; 
	int	__tss_ecx; 
	int	__tss_edx; 
	int	__tss_ebx; 
	int	tss_esp;	/* saved stack pointer */
	int	tss_ebp;	/* saved frame pointer */
	int	__tss_esi; 
	int	__tss_edi; 
	int	__tss_es;
	int	__tss_cs;
	int	__tss_ss;
	int	__tss_ds;
	int	tss_fs;		/* saved segment register */
	int	tss_gs;		/* saved segment register */
	int	tss_ldt;	/* LDT selector */
	int	tss_iobase;	/* options and I/O permission map offset */
};

/*
 * I/O bitmap offset beyond TSS's segment limit means no bitmaps.
 * (i.e. any I/O attempt generates an exception.)
 */
#define	IOMAP_INVALOFF	0xffffu

/*
 * If we have an I/O bitmap, there is only one valid offset.
 */
#define	IOMAP_VALIDOFF	sizeof(struct i386tss)

#endif /* #ifndef _I386_TSS_H_ */