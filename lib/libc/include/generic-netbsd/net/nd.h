/*	$NetBSD: nd.h,v 1.3 2020/09/15 10:05:36 roy Exp $	*/

/*
 * Copyright (c) 2020 The NetBSD Foundation, Inc.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Roy Marples.
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

#ifndef _NET_ND_H_
#define _NET_ND_H_

/* ND LLINFO states */
#define	ND_LLINFO_PURGE		-3
#define	ND_LLINFO_NOSTATE	-2
#define	ND_LLINFO_WAITDELETE	-1
#define	ND_LLINFO_INCOMPLETE	0
#define	ND_LLINFO_REACHABLE	1
#define	ND_LLINFO_STALE		2
#define	ND_LLINFO_DELAY		3
#define	ND_LLINFO_PROBE		4
#define	ND_LLINFO_UNREACHABLE	5

#ifdef _KERNEL
#define	ND_IS_LLINFO_PROBREACH(ln)	\
	((ln)->ln_state > ND_LLINFO_INCOMPLETE)
#define	ND_IS_LLINFO_PERMANENT(ln)	\
	(((ln)->ln_expire == 0) && ((ln)->ln_state > ND_LLINFO_INCOMPLETE))

/* ND timer types */
#define	ND_TIMER_IMMEDIATE		0
#define	ND_TIMER_TICK			1
#define	ND_TIMER_REACHABLE		2
#define	ND_TIMER_RETRANS		3
#define	ND_TIMER_RETRANS_BACKOFF	4
#define	ND_TIMER_EXPIRE			5
#define	ND_TIMER_DELAY			6
#define	ND_TIMER_GC			7

/* node constants */
#define	MAX_REACHABLE_TIME		3600000	/* msec */
#define	REACHABLE_TIME			30000	/* msec */
#define	RETRANS_TIMER			1000	/* msec */
#define	MAX_RETRANS_TIMER		60000	/* msec */
#define	BACKOFF_MULTIPLE		3
#define	MIN_RANDOM_FACTOR		512	/* 1024 * 0.5 */
#define	MAX_RANDOM_FACTOR		1536	/* 1024 * 1.5 */
#define	ND_COMPUTE_RTIME(x) \
		((MIN_RANDOM_FACTOR * (x >> 10)) + (cprng_fast32() & \
		((MAX_RANDOM_FACTOR - MIN_RANDOM_FACTOR) * (x >> 10))))

struct nd_domain {
	int nd_family;
	int nd_delay;		/* delay first probe time in seconds */
	int nd_mmaxtries;	/* maximum multicast query */
	int nd_umaxtries;	/* maximum unicast query */
	int nd_retransmultiple;	/* retransmission multiplier for backoff */
	int nd_maxretrans;	/* maximum retransmission time in msec */
	int nd_maxnudhint;	/* max # of subsequent upper layer hints */
	int nd_maxqueuelen;	/* max # of packets in unresolved ND entries */
	bool (*nd_nud_enabled)(struct ifnet *);
	unsigned int (*nd_reachable)(struct ifnet *);	/* msec */
	unsigned int (*nd_retrans)(struct ifnet *);	/* msec */
	union l3addr *(*nd_holdsrc)(struct llentry *, union l3addr *);
	void (*nd_output)(struct ifnet *, const union l3addr *,
	    const union l3addr *, const uint8_t *, const union l3addr *);
	void (*nd_missed)(struct ifnet *, const union l3addr *,
	    int16_t, struct mbuf *);
	void (*nd_free)(struct llentry *, int);
};

int nd_resolve(struct llentry *, const struct rtentry *, struct mbuf *,
    uint8_t *, size_t);
void nd_set_timer(struct llentry *, int);
void nd_nud_hint(struct llentry *);

void nd_attach_domain(struct nd_domain *);
#endif /* !_KERNEL */
#endif /* !_NET_ND_H_ */