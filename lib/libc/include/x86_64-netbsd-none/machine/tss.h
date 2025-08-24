/*	$NetBSD: tss.h,v 1.8 2018/07/07 21:35:16 kamil Exp $	*/

/*
 * Copyright (c) 2001 Wasabi Systems, Inc.
 * All rights reserved.
 *
 * Written by Frank van der Linden for Wasabi Systems, Inc.
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
 *      This product includes software developed for the NetBSD Project by
 *      Wasabi Systems, Inc.
 * 4. The name of Wasabi Systems, Inc. may not be used to endorse
 *    or promote products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY WASABI SYSTEMS, INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL WASABI SYSTEMS, INC
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _AMD64_TSS_H_
#define _AMD64_TSS_H_

#ifdef __x86_64__

/*
 * TSS structure. Since TSS hw switching is not supported in long
 * mode, this is mainly there for the I/O permission map in
 * normal processes.
 */

struct x86_64_tss {
	uint32_t	tss_reserved1;
	uint64_t	tss_rsp0;
	uint64_t	tss_rsp1;
	uint64_t	tss_rsp2;
	uint32_t	tss_reserved2;
	uint32_t	tss_reserved3;
	uint64_t	tss_ist[7];
	uint32_t	tss_reserved4;
	uint32_t	tss_reserved5;
	uint32_t	tss_iobase;
} __packed;

/*
 * I/O bitmap offset beyond TSS's segment limit means no bitmaps.
 * (i.e. any I/O attempt generates an exception.)
 */
#define	IOMAP_INVALOFF	0xffffu

/*
 * If we have an I/O bitmap, there is only one valid offset.
 */
#define	IOMAP_VALIDOFF	sizeof(struct x86_64_tss)

#else	/*	__x86_64__	*/

#include <i386/tss.h>

#endif	/*	__x86_64__	*/

#endif /* _AMD64_TSS_H_ */