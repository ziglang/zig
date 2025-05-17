/*	$NetBSD: bioscall.h,v 1.11 2008/04/28 20:23:24 martin Exp $ */

/*-
 * Copyright (c) 1997, 2000 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by John Kohl and Jason R. Thorpe.
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

#ifndef __I386_BIOSCALL_H__
#define __I386_BIOSCALL_H__

/*
 * virtual & physical address of the trampoline
 * that we use: page 1.
 */
#define BIOSTRAMP_BASE	PAGE_SIZE

#ifndef _LOCORE
#define	BIOSREG_LO	0
#define	BIOSREG_HI	1

typedef	union {
	u_char biosreg_quarter[4];
	u_short biosreg_half[2];
	u_int biosreg_long;
} bios_reg;

struct bioscallregs {
    bios_reg r_ax;
    bios_reg r_bx;
    bios_reg r_cx;
    bios_reg r_dx;
    bios_reg r_si;
    bios_reg r_di;
    bios_reg r_flags;
    bios_reg r_es;
};

#define	AL	r_ax.biosreg_quarter[BIOSREG_LO]
#define	AH	r_ax.biosreg_quarter[BIOSREG_HI]
#define	AX	r_ax.biosreg_half[BIOSREG_LO]
#define	AX_HI	r_ax.biosreg_half[BIOSREG_HI]
#define	EAX	r_ax.biosreg_long

#define	BL	r_bx.biosreg_quarter[BIOSREG_LO]
#define	BH	r_bx.biosreg_quarter[BIOSREG_HI]
#define	BX	r_bx.biosreg_half[BIOSREG_LO]
#define	BX_HI	r_bx.biosreg_half[BIOSREG_HI]
#define	EBX	r_bx.biosreg_long

#define	CL	r_cx.biosreg_quarter[BIOSREG_LO]
#define	CH	r_cx.biosreg_quarter[BIOSREG_HI]
#define	CX	r_cx.biosreg_half[BIOSREG_LO]
#define	CX_HI	r_cx.biosreg_half[BIOSREG_HI]
#define	ECX	r_cx.biosreg_long

#define	DL	r_dx.biosreg_quarter[BIOSREG_LO]
#define	DH	r_dx.biosreg_quarter[BIOSREG_HI]
#define	DX	r_dx.biosreg_half[BIOSREG_LO]
#define	DX_HI	r_dx.biosreg_half[BIOSREG_HI]
#define	EDX	r_dx.biosreg_long

#define	SI	r_si.biosreg_half[BIOSREG_LO]
#define	SI_HI	r_si.biosreg_half[BIOSREG_HI]
#define	ESI	r_si.biosreg_long

#define	DI	r_di.biosreg_half[BIOSREG_LO]
#define	DI_HI	r_di.biosreg_half[BIOSREG_HI]
#define	EDI	r_di.biosreg_long

#define	FLAGS	 r_flags.biosreg_half[BIOSREG_LO]
#define	FLAGS_HI r_flags.biosreg_half[BIOSREG_HI]
#define	EFLAGS	 r_flags.biosreg_long

#define ES	r_es.biosreg_half[BIOSREG_LO]

void bioscall(int /* function*/ , struct bioscallregs * /* regs */);
#endif
#endif /* __I386_BIOSCALL_H__ */