/*	$NetBSD: altq_flowvalve.h,v 1.4 2020/03/05 07:46:36 riastradh Exp $	*/
/*	$KAME: altq_flowvalve.h,v 1.5 2002/04/03 05:38:50 kjc Exp $	*/

/*
 * Copyright (C) 1998-2002
 *	Sony Computer Science Laboratories Inc.  All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY SONY CSL AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL SONY CSL OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _ALTQ_ALTQ_FLOWVALVE_H_
#define	_ALTQ_ALTQ_FLOWVALVE_H_

#ifdef _KERNEL

#ifdef _KERNEL_OPT
#include "opt_inet.h"
#endif

/* fv_flow structure to define a unique address pair */
struct fv_flow {
	int flow_af;		/* address family */
	union {
		struct {
			struct in_addr ip_src;
			struct in_addr ip_dst;
		} _ip;
#ifdef INET6
		struct {
			struct in6_addr ip6_src;
			struct in6_addr ip6_dst;
		} _ip6;
#endif
	} flow_un;
};

#define	flow_ip		flow_un._ip
#define	flow_ip6	flow_un._ip6

/* flowvalve entry */
struct fve {
	TAILQ_ENTRY(fve) fve_lru;	/* for LRU list */

	enum fv_state { Green, Red } fve_state;

	int	fve_p;			/* scaled average drop rate */
	int	fve_f;			/* scaled average fraction */
	int	fve_count;		/* counter to update f */
	u_int	fve_ifseq;		/* ifseq at the last update of f */
	struct timeval	fve_lastdrop;	/* timestamp of the last drop */

	struct fv_flow fve_flow;	/* unique address pair */
};

/* flowvalve structure */
struct flowvalve {
	u_int	fv_ifseq;	/* packet sequence number */
	int	fv_flows;	/* number of valid flows in the flowlist */
	int	fv_pthresh;	/* drop rate threshold */

	TAILQ_HEAD(fv_flowhead, fve) fv_flowlist;		/* LRU list */

	struct fve *fv_fves;	/* pointer to the allocated fves */

	int	*fv_p2ftab;	/* drop rate to fraction table */

	struct {
		u_int	pass;		/* # of packets that have the fve
					   but aren't predropped */
		u_int	predrop;	/* # of packets predropped */
		u_int	alloc;		/* # of fves assigned */
		u_int	escape;		/* # of fves escaped */
	} fv_stats;
};

#endif /* _KERNEL */

#endif /* _ALTQ_ALTQ_FLOWVALVE_H_ */