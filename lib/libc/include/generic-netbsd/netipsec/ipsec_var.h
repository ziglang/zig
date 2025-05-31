/*	$NetBSD: ipsec_var.h,v 1.8 2018/08/22 01:05:24 msaitoh Exp $ */
/*	$FreeBSD: ipsec.h,v 1.2.4.2 2004/02/14 22:23:23 bms Exp $	*/

/*-
 * Copyright (c) 2002, 2003 Sam Leffler, Errno Consulting
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
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $FreeBSD: src/tools/tools/crypto/ipsecstats.c,v 1.1.4.1 2003/06/03 00:13:13 sam Exp $
 */

#ifndef _NETIPSEC_IPSEC_VAR_H_
#define _NETIPSEC_IPSEC_VAR_H_

/*
 * statistics for ipsec processing
 * Each counter is an unsigned 64-bit value.
 */
#define	IPSEC_STAT_IN_POLVIO	0	/* input: sec policy violation */
#define	IPSEC_STAT_OUT_POLVIO	1	/* output: sec policy violation */
#define	IPSEC_STAT_OUT_NOSA	2	/* output: SA unavailable */
#define	IPSEC_STAT_OUT_NOMEM	3	/* output: no memory available */
#define	IPSEC_STAT_OUT_NOROUTE	4	/* output: no route available */
#define	IPSEC_STAT_OUT_INVAL	5	/* output: generic error */
#define	IPSEC_STAT_OUT_BUNDLESA	6	/* output: bundled SA processed */
#define	IPSEC_STAT_MBCOALESCED	7	/* mbufs coalesced during clone */
#define	IPSEC_STAT_CLCOALESCED	8	/* clusters coalesced during clone */
#define	IPSEC_STAT_CLCOPIED	9	/* clusters copied during clone */
#define	IPSEC_STAT_MBINSERTED	10	/* mbufs inserted during makespace */
#define	IPSEC_STAT_SPDCACHELOOKUP 11
#define	IPSEC_STAT_SPDCACHEMISS	12
#define	IPSEC_STAT_INPUT_FRONT	13
#define	IPSEC_STAT_INPUT_MIDDLE	14
#define	IPSEC_STAT_INPUT_END	15

#define	IPSEC_NSTATS		16

/*
 * Names for IPsec & Key sysctl objects
 */
#define IPSECCTL_STATS			1	/* KAME compat stats */
#define IPSECCTL_DEF_POLICY		2
#define IPSECCTL_DEF_ESP_TRANSLEV	3	/* int; ESP transport mode */
#define IPSECCTL_DEF_ESP_NETLEV		4	/* int; ESP tunnel mode */
#define IPSECCTL_DEF_AH_TRANSLEV	5	/* int; AH transport mode */
#define IPSECCTL_DEF_AH_NETLEV		6	/* int; AH tunnel mode */
#if 0	/* obsolete, do not reuse */
#define IPSECCTL_INBOUND_CALL_IKE	7
#endif
#define	IPSECCTL_AH_CLEARTOS		8
#define	IPSECCTL_AH_OFFSETMASK		9
#define	IPSECCTL_DFBIT			10
#define	IPSECCTL_ECN			11
#define	IPSECCTL_DEBUG			12
#define	IPSECCTL_ESP_RANDPAD		13

#endif /* !_NETIPSEC_IPSEC_VAR_H_ */