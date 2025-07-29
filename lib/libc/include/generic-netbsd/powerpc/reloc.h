/*	$NetBSD: reloc.h,v 1.2 2020/07/06 09:34:17 rin Exp $	*/

/*-
 * Copyright (C) 1995, 1996 Wolfgang Solfrank.
 * Copyright (C) 1995, 1996 TooLs GmbH.
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
 *	This product includes software developed by TooLs GmbH.
 * 4. The name of TooLs GmbH may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY TOOLS GMBH ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL TOOLS GMBH BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef	_MACH_RELOC_H_
#define	_MACH_RELOC_H_

/*
 * Quite a number of relocation types
 */
enum reloc_type {
	RELOC_NONE,
	RELOC_32,
	RELOC_24,
	RELOC_16,
	RELOC_16_LO,
	RELOC_16_HI,	/* RELOC_ADDIS = 5 */
	RELOC_16_HA,
	RELOC_14,
	RELOC_14_TAKEN,
	RELOC_14_NTAKEN,
	RELOC_REL24,	/* RELOC_BRANCH = 10 */
	RELOC_REL14,
	RELOC_REL14_TAKEN,
	RELOC_REL14_NTAKEN,
	RELOC_GOT16,
	RELOC_GOT16_LO,
	RELOC_GOT16_HI,
	RELOC_GOT16_HA,
	RELOC_PLT24,
	RELOC_COPY,
	RELOC_GLOB_DAT,
	RELOC_JMP_SLOT,
	RELOC_RELATIVE,
	RELOC_LOCAL24PC,
	RELOC_U32,
	RELOC_U16,
	RELOC_REL32,
	RELOC_PLT32,
	RELOC_PLTREL32,
	RELOC_PLT16_LO,
	RELOC_PLT16_HI,
	RELOC_PLT16_HA,
    /* ABI defines this as 32nd entry, but we ignore this, at least for now */
	RELOC_SDAREL,
	RELOC_MAX
};

#endif	/* _MACH_RELOC_H_ */