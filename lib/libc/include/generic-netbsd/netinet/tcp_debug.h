/*	$NetBSD: tcp_debug.h,v 1.21 2021/02/03 18:13:13 roy Exp $	*/

/*
 * Copyright (c) 1982, 1986, 1993
 *	The Regents of the University of California.  All rights reserved.
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
 *	@(#)tcp_debug.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NETINET_TCP_DEBUG_H_
#define _NETINET_TCP_DEBUG_H_

#if defined(_KERNEL_OPT)
#include "opt_inet.h"
#endif

struct	tcp_debug {
	n_time	td_time;
	short	td_act;
	short	td_ostate;
	void *	td_tcb;
	int	td_family;
	struct {
		struct ip ip4;
		struct tcphdr th;
	} __packed td_ti; /* XXX is __packed needed here? */
	struct {
#ifdef INET6
		struct ip6_hdr ip6;
#else
		u_char ip6_dummy[40];	/* just to keep struct align/size */
#endif
		struct tcphdr th;
	} td_ti6;
	short	td_req;
	struct	tcpcb td_cb;
};

#define	TA_INPUT	0
#define	TA_OUTPUT	1
#define	TA_USER		2
#define	TA_RESPOND	3
#define	TA_DROP		4

#ifdef TANAMES
const char	*tanames[] =
    { "input", "output", "user", "respond", "drop" };
#endif

#ifndef TCP_NDEBUG
#define	TCP_NDEBUG 100
#endif

#endif /* !_NETINET_TCP_DEBUG_H_ */