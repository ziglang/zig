/*	$NetBSD: kcore.h,v 1.5 2005/12/11 12:18:43 christos Exp $	*/

/*
 * Copyright (c) 2005 Wasabi Systems, Inc.
 * All rights reserved.
 *
 * Written by Allen Briggs for Wasabi Systems, Inc.
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

#ifndef	_POWERPC_KCORE_H_
#define	_POWERPC_KCORE_H_

/*
 * Support for 4xx/8xx/82xx/etc, will probably make this a union.
 * The pad/pvr should be kept in the same place, though, so we can
 * tell the difference.
 */
typedef struct cpu_kcore_hdr {
	uint32_t	pad;		/* Pad for 64-bit register_t */
	uint32_t	pvr;		/* PVR */
	register_t	sdr1;		/* SDR1 */
	register_t	sr[16];		/* Segment registers */
	register_t	dbatl[8];	/* DBATL[] */
	register_t	dbatu[8];	/* DBATU[] */
	register_t	ibatl[8];	/* IBATL[] */
	register_t	ibatu[8];	/* IBATU[] */
	register_t	pad_reg;	/* Pad for 32-bit systems */
} cpu_kcore_hdr_t;

#endif	/* _POWERPC_KCORE_H_ */