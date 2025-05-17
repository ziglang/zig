/*	$NetBSD: aout_machdep.h,v 1.10 2012/03/17 21:45:39 martin Exp $ */

/*
 * Copyright (c) 1993 Christopher G. Demetriou
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
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SPARC_EXEC_H_
#define _SPARC_EXEC_H_

#define AOUT_LDPGSZ	8192	/* linker page size */

enum reloc_type {
	RELOC_8,	RELOC_16, 	RELOC_32,
	RELOC_DISP8,	RELOC_DISP16,	RELOC_DISP32,
	RELOC_WDISP30,	RELOC_WDISP22,
	RELOC_HI22,	RELOC_22,
	RELOC_13,	RELOC_LO10,
	RELOC_UNUSED1,	RELOC_UNUSED2,
	RELOC_BASE10,	RELOC_BASE13,	RELOC_BASE22,
	RELOC_PC10,	RELOC_PC22,
	RELOC_JMP_TBL,
	RELOC_UNUSED3,
	RELOC_GLOB_DAT,	RELOC_JMP_SLOT,	RELOC_RELATIVE
};

/* Relocation format. */
struct relocation_info_sparc {
	int r_address;			/* offset in text or data segment */
	unsigned int r_symbolnum : 24,	/* ordinal number of add symbol */
			r_extern :  1,	/* 1 if need to add symbol to value */
				 :  2;	/* unused bits */
	/*BITFIELDTYPE*/
	enum reloc_type r_type   :  5;	/* relocation type time copy */
	long r_addend;			/* relocation addend */
};
#define relocation_info	relocation_info_sparc

#endif  /* _SPARC_EXEC_H_ */