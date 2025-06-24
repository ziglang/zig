/*	$NetBSD: ipcomp_var.h,v 1.8 2018/04/19 08:27:38 maxv Exp $	*/
/*	$FreeBSD: ipcomp_var.h,v 1.1.4.1 2003/01/24 05:11:35 sam Exp $	*/
/*	$KAME: ipcomp.h,v 1.8 2000/09/26 07:55:14 itojun Exp $	*/

/*
 * Copyright (C) 1999 WIDE Project.
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
 * 3. Neither the name of the project nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _NETIPSEC_IPCOMP_VAR_H_
#define _NETIPSEC_IPCOMP_VAR_H_

#define	IPCOMP_STAT_HDROPS	0	/* packet shorter than header shows */
#define	IPCOMP_STAT_NOPF	1	/* protocol family not supported */
#define	IPCOMP_STAT_NOTDB	2
#define	IPCOMP_STAT_BADKCR	3
#define	IPCOMP_STAT_QFULL	4
#define	IPCOMP_STAT_NOXFORM	5
#define	IPCOMP_STAT_WRAP	6
#define	IPCOMP_STAT_INPUT	7	/* input IPcomp packets */
#define	IPCOMP_STAT_OUTPUT	8	/* output IPcomp packets */
#define	IPCOMP_STAT_INVALID	9	/* trying to use an invalid TDB */
#define	IPCOMP_STAT_IBYTES	10	/* input bytes */
#define	IPCOMP_STAT_OBYTES	11	/* output bytes */
#define	IPCOMP_STAT_TOOBIG	12	/* packet got larger than IP_MAXPACKET */
#define	IPCOMP_STAT_MINLEN	13	/* packet too short to compress */
#define	IPCOMP_STAT_USELESS	14	/* packet compressed > initial packet */
#define	IPCOMP_STAT_PDROPS	15	/* packet blocked due to policy */
#define	IPCOMP_STAT_CRYPTO	16	/* crypto processing failure */
#define	IPCOMP_STAT_HIST	17	/* per-algorithm op count */

/* space for SADB_CALG_STATS_NUM counters */
#define	IPCOMP_ALG_MAX		SADB_CALG_STATS_NUM
#define	IPCOMP_ALG_STR		SADB_CALG_STATS_STR
#define	IPCOMP_NSTATS		(IPCOMP_STAT_HIST + IPCOMP_ALG_MAX)

#ifdef _KERNEL
extern const uint8_t ipcomp_stats[256];
extern	int ipcomp_enable;
#endif /* _KERNEL */
#endif /* !_NETIPSEC_IPCOMP_VAR_H_ */