/*	$NetBSD: sr_601.h,v 1.6 2021/02/27 01:16:52 thorpej Exp $	*/

/*-
 * Copyright (c) 2002, 2004 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Klaus J. Klein.
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

#ifndef _POWERPC_OEA_SR_601_H_
#define _POWERPC_OEA_SR_601_H_

/*
 * I/O Controller Interface Address Translation segment register
 * format specific to the PowerPC 601, per PowerPC 601 RISC
 * Microprocessor User's Manual, section 6.10.1.
 *
 * This format applies to a segment register only when its T bit is set.
 */

#define	SR601_T		0x80000000	/* Selects this format */
#define	SR601_Ks	0x40000000	/* Key-supervisor */
#define	SR601_Ku	0x20000000	/* Key-user */
#define	SR601_BUID	0x1ff00000	/* Bus unit ID */
#define	SR601_BUID_SHFT	20
#define	SR601_CSI	0x000ffff0	/* Controller Specific Information */
#define	SR601_CSI_SHFT	4
#define	SR601_PACKET1	0x0000000f	/* Address bits 0:3 of packet 1 cycle */

#define	SR601_BUID_MEMFORCED	0x07f	/* Translate to memory access, taking
					   PA[0:3] from the PACKET1 field */

#define	SR601(key, buid, csi, p1)				\
	(SR601_T |						\
	 (key) |						\
	 (buid) << SR601_BUID_SHFT |				\
	 (csi) << SR601_CSI_SHFT | (p1))

#define SR601_VALID_P(sr)					\
	((sr) & SR601_T)

#define	SR601_PA_MATCH_P(sr, pa) 				\
	 (((sr) & SR601_PACKET1) == ((pa) >> ADDR_SR_SHFT))

#endif /* !_POWERPC_OEA_SR_601_H_ */