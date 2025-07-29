/*	$NetBSD: if_cnwioctl.h,v 1.5 2015/09/06 06:01:00 dholland Exp $	*/

/*
 * Copyright (c) 1996, 1997 Berkeley Software Design, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that this notice is retained,
 * the conditions in the following notices are met, and terms applying
 * to contributors in the following notices also apply to Berkeley
 * Software Design, Inc.
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by
 *	Berkeley Software Design, Inc.
 * 4. Neither the name of the Berkeley Software Design, Inc. nor the names
 *    of its contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BERKELEY SOFTWARE DESIGN, INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL BERKELEY SOFTWARE DESIGN, INC. BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	PAO2 Id: if_cnwioctl.h,v 1.1.8.1 1998/12/05 22:47:11 itojun Exp
 *
 * Paul Borman, December 1996
 *
 * This driver is derived from a generic frame work which is
 * Copyright(c) 1994,1995,1996
 * Yoichi Shinoda, Yoshitaka Tokugawa, WIDE Project, Wildboar Project
 * and Foretune.  All rights reserved.
 *
 * A linux driver was used as the "hardware reference manual" (i.e.,
 * to determine registers and a general outline of how the card works)
 * That driver is publically available and copyright
 *
 * John Markus Bj,Ax(Brndalen
 * Department of Computer Science
 * University of Troms,Ax(B
 * Norway
 * johnm@staff.cs.uit.no, http://www.cs.uit.no/~johnm/
 */

#include <sys/ioccom.h>

struct cnwstatus {
	struct ifreq	ifr;
	u_char		data[0x100];
};

struct cnwstats {
	u_quad_t nws_rx;
	u_quad_t nws_rxerr;
	u_quad_t nws_rxoverflow;
	u_quad_t nws_rxoverrun;
	u_quad_t nws_rxcrcerror;
	u_quad_t nws_rxframe;
	u_quad_t nws_rxerrors;
	u_quad_t nws_rxavail;
	u_quad_t nws_rxone;
	u_quad_t nws_tx;
	u_quad_t nws_txokay;
	u_quad_t nws_txabort;
	u_quad_t nws_txlostcd;
	u_quad_t nws_txerrors;
	u_quad_t nws_txretries[16];
};

struct cnwistats {
	struct ifreq	ifr;
	struct cnwstats stats;
};

struct cnwtrail {
	u_char		what;
	u_char		status;
	u_short		length;
	struct timeval	when;
	struct timeval	done;
};

struct cnwitrail {
	struct ifreq	ifr;
	int		head;
	struct cnwtrail trail[128];
};

#define ifr_domain	ifr_ifru.ifru_flags     /* domain */
#define ifr_key		ifr_ifru.ifru_flags     /* scramble key */

#define SIOCSCNWDOMAIN	_IOW('i', 254, struct ifreq)	/* set domain */
#define SIOCGCNWDOMAIN	_IOWR('i', 253, struct ifreq)	/* get domain */
#define SIOCSCNWKEY	_IOWR('i', 252, struct ifreq)	/* set scramble key */
#define	SIOCGCNWSTATUS	_IOWR('i', 251, struct cnwstatus)/* get raw status */
#define	SIOCGCNWSTATS	_IOWR('i', 250, struct cnwistats)/* get stats */
#define	SIOCGCNWTRAIL	_IOWR('i', 249, struct cnwitrail)/* get trail */