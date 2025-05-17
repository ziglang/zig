/*	$NetBSD: if_inarp.h,v 1.53 2022/09/03 01:35:03 thorpej Exp $	*/

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
 *	@(#)if_ether.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NETINET_IF_INARP_H_
#define _NETINET_IF_INARP_H_

#include <sys/queue.h>		/* for LIST_ENTRY */
#include <netinet/in.h>		/* for struct in_addr */

struct llinfo_arp {
	LIST_ENTRY(llinfo_arp) la_list;
	struct	rtentry *la_rt;
	struct	mbuf *la_hold;		/* last packet until resolved/timeout */
	long	la_asked;		/* last time we QUERIED for this addr */
};

struct sockaddr_inarp {
	u_int8_t  sin_len;
	u_int8_t  sin_family;
	u_int16_t sin_port;
	struct	  in_addr sin_addr;
	struct	  in_addr sin_srcaddr;
	u_int16_t sin_tos;
	u_int16_t sin_other;
#define SIN_PROXY 1
};

#ifdef _KERNEL

#include <net/pktqueue.h>

/* ARP timings from RFC5227 */
#define PROBE_WAIT               1
#define PROBE_NUM                3
#define PROBE_MIN                1
#define PROBE_MAX                2
#define ANNOUNCE_WAIT            2
#define ANNOUNCE_NUM             2
#define ANNOUNCE_INTERVAL        2
#define MAX_CONFLICTS           10
#define RATE_LIMIT_INTERVAL     60
#define DEFEND_INTERVAL         10

extern pktqueue_t *arp_pktq;
void arp_ifinit(struct ifnet *, struct ifaddr *);
void arp_rtrequest(int, struct rtentry *, const struct rt_addrinfo *);
int arpresolve(struct ifnet *, const struct rtentry *, struct mbuf *,
    const struct sockaddr *, void *, size_t);
void arpintr(void *);
void arpannounce(struct ifnet *, struct ifaddr *, const uint8_t *);
struct llentry *arplookup(struct ifnet *,
    const struct in_addr *, const struct sockaddr *, int);
void arp_drain(void);
int arpioctl(u_long, void *);
void arpwhohas(struct ifnet *, struct in_addr *);
void arp_nud_hint(struct rtentry *);

void revarpinput(struct mbuf *);
int revarpwhoarewe(struct ifnet *, struct in_addr *, struct in_addr *);
#endif

#endif /* !_NETINET_IF_INARP_H_ */