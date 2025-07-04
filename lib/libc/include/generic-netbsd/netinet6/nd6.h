/*	$NetBSD: nd6.h,v 1.91 2020/09/11 15:03:33 roy Exp $	*/
/*	$KAME: nd6.h,v 1.95 2002/06/08 11:31:06 itojun Exp $	*/

/*
 * Copyright (C) 1995, 1996, 1997, and 1998 WIDE Project.
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

#ifndef _NETINET6_ND6_H_
#define _NETINET6_ND6_H_

#include <sys/queue.h>
#include <sys/callout.h>

#ifndef _KERNEL
/* Backwards compat */
#include <net/nd.h>
#define ND6_LLINFO_PURGE	ND_LLINFO_PURGE
#define ND6_LLINFO_NOSTATE	ND_LLINFO_NOSTATE
#define ND6_LLINFO_WAITDELETE	ND_LLINFO_WAITDELETE
#define ND6_LLINFO_INCOMPLETE	ND_LLINFO_INCOMPLETE
#define ND6_LLINFO_REACHABLE	ND_LLINFO_REACHABLE
#define ND6_LLINFO_STALE	ND_LLINFO_STALE
#define ND6_LLINFO_DELAY	ND_LLINFO_DELAY
#define ND6_LLINFO_PROBE	ND_LLINFO_PROBE
#endif

struct nd_ifinfo {
	uint8_t chlim;			/* CurHopLimit */
	uint32_t basereachable;		/* BaseReachableTime */
	uint32_t retrans;		/* Retrans Timer */
	uint32_t flags;			/* Flags */
};
#ifdef _KERNEL
struct nd_kifinfo {
	uint8_t chlim;			/* CurHopLimit */
	uint32_t basereachable;		/* BaseReachableTime */
	uint32_t retrans;		/* Retrans Timer */
	uint32_t flags;			/* Flags */
	int recalctm;			/* BaseReacable re-calculation timer */
	uint32_t reachable;		/* Reachable Time */
};
#endif

#define ND6_IFF_PERFORMNUD	0x01
/* 0x02 was ND6_IFF_ACCEPT_RTADV */
#define ND6_IFF_PREFER_SOURCE	0x04	/* XXX: not related to ND. */
#define ND6_IFF_IFDISABLED	0x08	/* IPv6 operation is disabled due to
					 * DAD failure.  (XXX: not ND-specific)
					 */
/* 0x10 was ND6_IFF_OVERRIDE_RTADV */
#define	ND6_IFF_AUTO_LINKLOCAL	0x20

#ifdef _KERNEL
#define ND_IFINFO(ifp) \
	(((struct in6_ifextra *)(ifp)->if_afdata[AF_INET6])->nd_ifinfo)
#endif

struct in6_nbrinfo {
	char ifname[IFNAMSIZ];	/* if name, e.g. "en0" */
	struct in6_addr addr;	/* IPv6 address of the neighbor */
	long	asked;		/* number of queries already sent for this addr */
	int	isrouter;	/* if it acts as a router */
	int	state;		/* reachability state */
	int	expire;		/* lifetime for NDP state transition */
};

struct	in6_ndireq {
	char ifname[IFNAMSIZ];
	struct nd_ifinfo ndi;
};

/* protocol constants */
#define MAX_RTR_SOLICITATION_DELAY	1	/* 1sec */
#define ND6_INFINITE_LIFETIME		((u_int32_t)~0)

#ifdef _KERNEL
#include <sys/mallocvar.h>
MALLOC_DECLARE(M_IP6NDP);

/* nd6.c */
extern int nd6_prune;
extern int nd6_useloopback;
extern int nd6_debug;

extern struct nd_domain nd6_nd_domain;

#define nd6log(level, fmt, args...) \
	do { if (nd6_debug) log(level, "%s: " fmt, __func__, ##args);} while (0)

extern krwlock_t nd6_lock;

#define ND6_RLOCK()		rw_enter(&nd6_lock, RW_READER)
#define ND6_WLOCK()		rw_enter(&nd6_lock, RW_WRITER)
#define ND6_UNLOCK()		rw_exit(&nd6_lock)
#define ND6_ASSERT_WLOCK()	KASSERT(rw_write_held(&nd6_lock))
#define ND6_ASSERT_LOCK()	KASSERT(rw_lock_held(&nd6_lock))

union nd_opts {
	struct nd_opt_hdr *nd_opt_array[16];	/* max = ND_OPT_NONCE */
	struct {
		struct nd_opt_hdr *zero;
		struct nd_opt_hdr *src_lladdr;
		struct nd_opt_hdr *tgt_lladdr;
		struct nd_opt_prefix_info *pi_beg; /* multiple opts, start */
		struct nd_opt_rd_hdr *rh;
		struct nd_opt_mtu *mtu;
		struct nd_opt_hdr *__res6;
		struct nd_opt_hdr *__res7;
		struct nd_opt_hdr *__res8;
		struct nd_opt_hdr *__res9;
		struct nd_opt_hdr *__res10;
		struct nd_opt_hdr *__res11;
		struct nd_opt_hdr *__res12;
		struct nd_opt_hdr *__res13;
		struct nd_opt_nonce *nonce;
		struct nd_opt_hdr *__res15;
		struct nd_opt_hdr *search;	/* multiple opts */
		struct nd_opt_hdr *last;	/* multiple opts */
		int done;
		struct nd_opt_prefix_info *pi_end;/* multiple opts, end */
	} nd_opt_each;
};
#define nd_opts_src_lladdr	nd_opt_each.src_lladdr
#define nd_opts_tgt_lladdr	nd_opt_each.tgt_lladdr
#define nd_opts_pi		nd_opt_each.pi_beg
#define nd_opts_pi_end		nd_opt_each.pi_end
#define nd_opts_rh		nd_opt_each.rh
#define nd_opts_mtu		nd_opt_each.mtu
#define nd_opts_nonce		nd_opt_each.nonce
#define nd_opts_search		nd_opt_each.search
#define nd_opts_last		nd_opt_each.last
#define nd_opts_done		nd_opt_each.done

#include <net/if_llatbl.h>

/* XXX: need nd6_var.h?? */
/* nd6.c */
void nd6_init(void);
void nd6_nbr_init(void);
struct nd_kifinfo *nd6_ifattach(struct ifnet *);
void nd6_ifdetach(struct ifnet *, struct in6_ifextra *);
int nd6_is_addr_neighbor(const struct sockaddr_in6 *, struct ifnet *);
void nd6_option_init(void *, int, union nd_opts *);
int nd6_options(union nd_opts *);
struct llentry *nd6_lookup(const struct in6_addr *, const struct ifnet *, bool);
struct llentry *nd6_create(const struct in6_addr *, const struct ifnet *);
void nd6_purge(struct ifnet *, struct in6_ifextra *);
void nd6_nud_hint(struct rtentry *);
int nd6_resolve(struct ifnet *, const struct rtentry *, struct mbuf *,
	const struct sockaddr *, uint8_t *, size_t);
void nd6_rtrequest(int, struct rtentry *, const struct rt_addrinfo *);
int nd6_ioctl(u_long, void *, struct ifnet *);
void nd6_cache_lladdr(struct ifnet *, struct in6_addr *,
	char *, int, int, int);
int nd6_sysctl(int, void *, size_t *, void *, size_t);
int nd6_need_cache(struct ifnet *);
void nd6_llinfo_release_pkts(struct llentry *, struct ifnet *);

/* nd6_nbr.c */
void nd6_na_input(struct mbuf *, int, int);
void nd6_na_output(struct ifnet *, const struct in6_addr *,
	const struct in6_addr *, u_long, int, const struct sockaddr *);
void nd6_ns_input(struct mbuf *, int, int);
void nd6_ns_output(struct ifnet *, const struct in6_addr *,
	const struct in6_addr *, const struct in6_addr *, const uint8_t *);
const void *nd6_ifptomac(const struct ifnet *);
void nd6_dad_start(struct ifaddr *, int);
void nd6_dad_stop(struct ifaddr *);

/* nd6_rtr.c */
void nd6_rtr_cache(struct mbuf *, int, int, int);

#endif /* _KERNEL */

#endif /* !_NETINET6_ND6_H_ */