/*	$NetBSD: route.h,v 1.132 2022/09/20 02:23:37 knakahara Exp $	*/

/*
 * Copyright (c) 1980, 1986, 1993
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
 *	@(#)route.h	8.5 (Berkeley) 2/8/95
 */

#ifndef _NET_ROUTE_H_
#define _NET_ROUTE_H_

#include <sys/queue.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <net/if.h>
#ifdef _KERNEL
#include <sys/rwlock.h>
#include <sys/condvar.h>
#include <sys/pserialize.h>
#include <sys/percpu.h>
#endif
#include <sys/psref.h>

#if !(defined(_KERNEL) || defined(_STANDALONE))
#include <stdbool.h>
#endif

/*
 * Kernel resident routing tables.
 *
 * The routing tables are initialized when interface addresses
 * are set by making entries for all directly connected interfaces.
 */

/*
 * A route consists of a destination address and a reference
 * to a routing entry.  These are often held by protocols
 * in their control blocks, e.g. inpcb.
 */
struct route {
	struct	rtentry		*_ro_rt;
	struct	sockaddr	*ro_sa;
	uint64_t		ro_rtcache_generation;
	struct	psref		ro_psref;
	int			ro_bound;
};

/*
 * These numbers are used by reliable protocols for determining
 * retransmission behavior and are included in the routing structure.
 */
struct rt_metrics {
	uint64_t rmx_locks;	/* Kernel must leave these values alone */
	uint64_t rmx_mtu;	/* MTU for this path */
	uint64_t rmx_hopcount;	/* max hops expected */
	uint64_t rmx_recvpipe;	/* inbound delay-bandwidth product */
	uint64_t rmx_sendpipe;	/* outbound delay-bandwidth product */
	uint64_t rmx_ssthresh;	/* outbound gateway buffer limit */
	uint64_t rmx_rtt;	/* estimated round trip time */
	uint64_t rmx_rttvar;	/* estimated rtt variance */
	time_t	rmx_expire;	/* lifetime for route, e.g. redirect */
	time_t	rmx_pksent;	/* packets sent using this route */
};

/*
 * rmx_rtt and rmx_rttvar are stored as microseconds;
 * RTTTOPRHZ(rtt) converts to a value suitable for use
 * by a protocol slowtimo counter.
 */
#define	RTM_RTTUNIT	1000000	/* units for rtt, rttvar, as units per sec */
#define	RTTTOPRHZ(r)	((r) / (RTM_RTTUNIT / PR_SLOWHZ))

/*
 * We distinguish between routes to hosts and routes to networks,
 * preferring the former if available.  For each route we infer
 * the interface to use from the gateway address supplied when
 * the route was entered.  Routes that forward packets through
 * gateways are marked so that the output routines know to address the
 * gateway rather than the ultimate destination.
 */
#ifndef RNF_NORMAL
#include <net/radix.h>
#endif
struct rtentry {
	struct	radix_node rt_nodes[2];	/* tree glue, and other values */
#define	rt_mask(r)	((const struct sockaddr *)((r)->rt_nodes->rn_mask))
	struct	sockaddr *rt_gateway;	/* value */
	int	rt_flags;		/* up/down?, host/net */
	int	rt_refcnt;		/* # held references */
	uint64_t rt_use;			/* raw # packets forwarded */
	struct	ifnet *rt_ifp;		/* the answer: interface to use */
	struct	ifaddr *rt_ifa;		/* the answer: interface to use */
	uint32_t rt_ifa_seqno;
	void *	rt_llinfo;		/* pointer to link level info cache */
	struct	rt_metrics rt_rmx;	/* metrics used by rx'ing protocols */
	struct	rtentry *rt_gwroute;	/* implied entry for gatewayed routes */
	LIST_HEAD(, rttimer) rt_timer;  /* queue of timeouts for misc funcs */
	struct	rtentry *rt_parent;	/* parent of cloned route */
	struct	sockaddr *_rt_key;
	struct	sockaddr *rt_tag;	/* route tagging info */
#ifdef _KERNEL
	kcondvar_t rt_cv;
	struct psref_target rt_psref;
	SLIST_ENTRY(rtentry) rt_free;	/* queue of deferred frees */
#endif
};

static __inline const struct sockaddr *
rt_getkey(const struct rtentry *rt)
{
	return rt->_rt_key;
}

/*
 * Following structure necessary for 4.3 compatibility;
 * We should eventually move it to a compat file.
 */
struct ortentry {
	uint32_t rt_hash;		/* to speed lookups */
	struct	sockaddr rt_dst;	/* key */
	struct	sockaddr rt_gateway;	/* value */
	int16_t	rt_flags;		/* up/down?, host/net */
	int16_t	rt_refcnt;		/* # held references */
	uint32_t rt_use;		/* raw # packets forwarded */
	struct	ifnet *rt_ifp;		/* the answer: interface to use */
};

#define	RTF_UP		0x1		/* route usable */
#define	RTF_GATEWAY	0x2		/* destination is a gateway */
#define	RTF_HOST	0x4		/* host entry (net otherwise) */
#define	RTF_REJECT	0x8		/* host or net unreachable */
#define	RTF_DYNAMIC	0x10		/* created dynamically (by redirect) */
#define	RTF_MODIFIED	0x20		/* modified dynamically (by redirect) */
#define RTF_DONE	0x40		/* message confirmed */
#define RTF_MASK	0x80		/* subnet mask present */
// #define RTF_CLONING	0x100		/* generate new routes on use */
#define RTF_CONNECTED	0x100		/* hosts on this route are neighbours */
// #define RTF_XRESOLVE	0x200		/* external daemon resolves name */
// #define RTF_LLINFO	0x400		/* generated by ARP or NDP */
#define RTF_LLDATA	0x400		/* used by apps to add/del L2 entries */
#define RTF_STATIC	0x800		/* manually added */
#define RTF_BLACKHOLE	0x1000		/* just discard pkts (during updates) */
// #define RTF_CLONED	0x2000		/* this is a cloned route */
#define RTF_PROTO2	0x4000		/* protocol specific routing flag */
#define RTF_PROTO1	0x8000		/* protocol specific routing flag */
#define RTF_SRC		0x10000		/* route has fixed source address */
#define RTF_ANNOUNCE	0x20000		/* announce new ARP or NDP entry */
#define RTF_LOCAL	0x40000		/* route represents a local address */
#define RTF_BROADCAST	0x80000		/* route represents a bcast address */
#define RTF_UPDATING	0x100000	/* route is updating */
/*
 * The flag is nevert set to rt_flags.  It just tells rtrequest1 to set a passed
 * ifa to rt_ifa (via rti_ifa) and not replace rt_ifa in ifa_rtrequest.
 */
#define RTF_DONTCHANGEIFA	0x200000	/* suppress rt_ifa replacement */

/*
 * 0x400 is exposed to userland just for backward compatibility. For that
 * purpose, it should be shown as LLINFO.
 */
#define RTFBITS "\020\1UP\2GATEWAY\3HOST\4REJECT\5DYNAMIC\6MODIFIED\7DONE" \
    "\010MASK_PRESENT\011CONNECTED\012XRESOLVE\013LLINFO\014STATIC" \
    "\015BLACKHOLE\016CLONED\017PROTO2\020PROTO1\021SRC\022ANNOUNCE" \
    "\023LOCAL\024BROADCAST\025UPDATING"


/*
 * Routing statistics.
 */
struct	rtstat {
	uint64_t rts_badredirect;	/* bogus redirect calls */
	uint64_t rts_dynamic;		/* routes created by redirects */
	uint64_t rts_newgateway;	/* routes modified by redirects */
	uint64_t rts_unreach;		/* lookups which failed */
	uint64_t rts_wildcard;		/* lookups satisfied by a wildcard */
};

/*
 * Structures for routing messages.  By forcing the first member to be aligned
 * at a 64-bit boundary, we also force the size to be a multiple of 64-bits.
 */

#if !defined(_KERNEL) || !defined(COMPAT_RTSOCK)
/*
 * If we aren't being compiled for backwards compatibility, enforce 64-bit
 * alignment so any routing message is the same regardless if the kernel
 * is an ILP32 or LP64 kernel.
 */
#define	__align64	__aligned(sizeof(uint64_t))
#else
#define	__align64
#endif

struct rt_msghdr {
	u_short	rtm_msglen __align64;
				/* to skip over non-understood messages */
	u_char	rtm_version;	/* future binary compatibility */
	u_char	rtm_type;	/* message type */
	u_short	rtm_index;	/* index for associated ifp */
	int	rtm_flags;	/* flags, incl. kern & message, e.g. DONE */
	int	rtm_addrs;	/* bitmask identifying sockaddrs in msg */
	pid_t	rtm_pid;	/* identify sender */
	int	rtm_seq;	/* for sender to identify action */
	int	rtm_errno;	/* why failed */
	int	rtm_use;	/* from rtentry */
	int	rtm_inits;	/* which metrics we are initializing */
	struct	rt_metrics rtm_rmx __align64;
				/* metrics themselves */
};

#undef __align64

#define RTM_VERSION	4	/* Up the ante and ignore older versions */

#define RTM_ADD		0x1	/* Add Route */
#define RTM_DELETE	0x2	/* Delete Route */
#define RTM_CHANGE	0x3	/* Change Metrics or flags */
#define RTM_GET		0x4	/* Report Metrics */
#define RTM_LOSING	0x5	/* Kernel Suspects Partitioning */
#define RTM_REDIRECT	0x6	/* Told to use different route */
#define RTM_MISS	0x7	/* Lookup failed on this address */
#define RTM_LOCK	0x8	/* fix specified metrics */
#define RTM_OLDADD	0x9	/* caused by SIOCADDRT */
#define RTM_OLDDEL	0xa	/* caused by SIOCDELRT */
// #define RTM_RESOLVE	0xb	/* req to resolve dst to LL addr */
#define RTM_ONEWADDR	0xc	/* Old (pre-8.0) RTM_NEWADDR message */
#define RTM_ODELADDR	0xd	/* Old (pre-8.0) RTM_DELADDR message */
#define RTM_OOIFINFO	0xe	/* Old (pre-1.5) RTM_IFINFO message */
#define RTM_OIFINFO	0xf	/* Old (pre-64bit time) RTM_IFINFO message */
#define	RTM_IFANNOUNCE	0x10	/* iface arrival/departure */
#define	RTM_IEEE80211	0x11	/* IEEE80211 wireless event */
#define	RTM_SETGATE	0x12	/* set prototype gateway for clones
				 * (see example in arp_rtrequest).
				 */
#define	RTM_LLINFO_UPD	0x13	/* indication to ARP/NDP/etc. that link-layer
				 * address has changed
				 */
#define RTM_IFINFO	0x14	/* iface/link going up/down etc. */
#define RTM_OCHGADDR	0x15	/* Old (pre-8.0) RTM_CHGADDR message */
#define RTM_NEWADDR	0x16	/* address being added to iface */
#define RTM_DELADDR	0x17	/* address being removed from iface */
#define RTM_CHGADDR	0x18	/* address properties changed */

#ifdef RTM_NAMES
static const char *rtm_names[] = {
    "*none*", "add", "delete", "change", "get",
    "losing", "redirect", "miss", "lock", "oldadd",
    "olddel", "*resolve*", "onewaddr", "odeladdr", "ooifinfo",
    "oifinfo", "ifannounce", "ieee80211", "setgate", "llinfo_upd",
    "ifinfo", "ochgaddr",  "newaddr", "deladdr", "chgaddr",
};
#endif

/*
 * setsockopt defines used for the filtering.
 */
#define	RO_MSGFILTER	1	/* array of which rtm_type to send to client */
#define	RO_MISSFILTER	2	/* array of sockaddrs to match miss dst */

#define	RO_FILTSA_MAX	30	/* maximum number of sockaddrs per filter */

#define RTV_MTU		0x1	/* init or lock _mtu */
#define RTV_HOPCOUNT	0x2	/* init or lock _hopcount */
#define RTV_EXPIRE	0x4	/* init or lock _expire */
#define RTV_RPIPE	0x8	/* init or lock _recvpipe */
#define RTV_SPIPE	0x10	/* init or lock _sendpipe */
#define RTV_SSTHRESH	0x20	/* init or lock _ssthresh */
#define RTV_RTT		0x40	/* init or lock _rtt */
#define RTV_RTTVAR	0x80	/* init or lock _rttvar */

#define RTVBITS "\020\1MTU\2HOPCOUNT\3EXPIRE\4RECVPIPE\5SENDPIPE" \
    "\6SSTHRESH\7RTT\010RTTVAR"

/*
 * Bitmask values for rtm_addr.
 */
#define RTA_DST		0x1	/* destination sockaddr present */
#define RTA_GATEWAY	0x2	/* gateway sockaddr present */
#define RTA_NETMASK	0x4	/* netmask sockaddr present */
#define RTA_GENMASK	0x8	/* cloning mask sockaddr present */
#define RTA_IFP		0x10	/* interface name sockaddr present */
#define RTA_IFA		0x20	/* interface addr sockaddr present */
#define RTA_AUTHOR	0x40	/* sockaddr for author of redirect */
#define RTA_BRD		0x80	/* for NEWADDR, broadcast or p-p dest addr */
#define RTA_TAG		0x100	/* route tag */

#define RTABITS "\020\1DST\2GATEWAY\3NETMASK\4GENMASK\5IFP\6IFA\7AUTHOR" \
    "\010BRD\011TAG"

/*
 * Index offsets for sockaddr array for alternate internal encoding.
 */
#define RTAX_DST	0	/* destination sockaddr present */
#define RTAX_GATEWAY	1	/* gateway sockaddr present */
#define RTAX_NETMASK	2	/* netmask sockaddr present */
#define RTAX_GENMASK	3	/* cloning mask sockaddr present */
#define RTAX_IFP	4	/* interface name sockaddr present */
#define RTAX_IFA	5	/* interface addr sockaddr present */
#define RTAX_AUTHOR	6	/* sockaddr for author of redirect */
#define RTAX_BRD	7	/* for NEWADDR, broadcast or p-p dest addr */
#define RTAX_TAG	8	/* route tag */
#define RTAX_MAX	9	/* size of array to allocate */

#define RT_ROUNDUP2(a, n)	((a) > 0 ? (1 + (((a) - 1U) | ((n) - 1))) : (n))
#define RT_ROUNDUP(a)		RT_ROUNDUP2((a), sizeof(uint64_t))
#define RT_ADVANCE(x, n)	(x += RT_ROUNDUP((n)->sa_len))

struct rt_addrinfo {
	int	rti_addrs;
	const struct	sockaddr *rti_info[RTAX_MAX];
	int	rti_flags;
	struct	ifaddr *rti_ifa;
	struct	ifnet *rti_ifp;
};

struct route_cb {
	int	ip_count;
	int	ip6_count;
	int	unused1;
	int	mpls_count;
	int	any_count;
};

/*
 * This structure, and the prototypes for the rt_timer_{init,remove_all,
 * add,timer} functions all used with the kind permission of BSDI.
 * These allow functions to be called for routes at specific times.
 */

struct rttimer {
	TAILQ_ENTRY(rttimer)	rtt_next;  /* entry on timer queue */
	LIST_ENTRY(rttimer) 	rtt_link;  /* multiple timers per rtentry */
	struct rttimer_queue   *rtt_queue; /* back pointer to queue */
	struct rtentry         *rtt_rt;    /* Back pointer to the route */
	void		      (*rtt_func)(struct rtentry *, struct rttimer *);
	time_t          	rtt_time;  /* When this timer was registered */
};

struct rttimer_queue {
	long				rtq_timeout;
	unsigned long			rtq_count;
	TAILQ_HEAD(, rttimer)		rtq_head;
	LIST_ENTRY(rttimer_queue)	rtq_link;
};


struct rtbl;
typedef struct rtbl rtbl_t;

#ifdef _KERNEL

struct rtbl {
	struct radix_node_head t_rnh;
};

struct rt_walkarg {
	int	w_op;
	int	w_arg;
	int	w_given;
	int	w_needed;
	void *	w_where;
	int	w_tmemsize;
	int	w_tmemneeded;
	void *	w_tmem;
};

#if 0
#define	RT_DPRINTF(__fmt, ...)	do { } while (/*CONSTCOND*/0)
#else
#define	RT_DPRINTF(__fmt, ...)	/* do nothing */
#endif

struct rtwalk {
	int (*rw_f)(struct rtentry *, void *);
	void *rw_v;
};

/*
 * Global data specific to the routing socket.
 */
struct route_info {
	struct sockaddr ri_dst;
	struct sockaddr ri_src;
	struct route_cb ri_cb;
	int ri_maxqlen;
	struct ifqueue ri_intrq;
	void *ri_sih;
};

extern	struct	route_info route_info;
extern	struct	rtstat	rtstat;

struct socket;

void	rt_init(void);

int	rt_timer_add(struct rtentry *,
	    void(*)(struct rtentry *, struct rttimer *),
	    struct rttimer_queue *);
unsigned long
	rt_timer_count(struct rttimer_queue *);
void	rt_timer_queue_change(struct rttimer_queue *, long);
struct rttimer_queue *
	rt_timer_queue_create(u_int);
void	rt_timer_queue_destroy(struct rttimer_queue *);

void	rt_free(struct rtentry *);
void	rt_unref(struct rtentry *);

int	rt_update(struct rtentry *, struct rt_addrinfo *, void *);
int	rt_update_prepare(struct rtentry *);
void	rt_update_finish(struct rtentry *);

void	rt_newmsg(const int, const struct rtentry *);
void	rt_newmsg_dynamic(const int, const struct rtentry *);
struct rtentry *
	rtalloc1(const struct sockaddr *, int);
int	rtinit(struct ifaddr *, int, int);
void	rtredirect(const struct sockaddr *, const struct sockaddr *,
	    const struct sockaddr *, int, const struct sockaddr *,
	    struct rtentry **);
int	rtrequest(int, const struct sockaddr *,
	    const struct sockaddr *, const struct sockaddr *, int,
	    struct rtentry **);
int	rtrequest1(int, struct rt_addrinfo *, struct rtentry **);

int	rt_ifa_addlocal(struct ifaddr *);
int	rt_ifa_remlocal(struct ifaddr *, struct ifaddr *);
struct ifaddr *
	rt_get_ifa(struct rtentry *);
void	rt_replace_ifa(struct rtentry *, struct ifaddr *);
int	rt_setgate(struct rtentry *, const struct sockaddr *);

const struct sockaddr *
	rt_settag(struct rtentry *, const struct sockaddr *);
struct sockaddr *
	rt_gettag(const struct rtentry *);

int	rt_check_reject_route(const struct rtentry *, const struct ifnet *);
void	rt_delete_matched_entries(sa_family_t,
	    int (*)(struct rtentry *, void *), void *, bool);
void	rt_replace_ifa_matched_entries(sa_family_t,
	    int (*)(struct rtentry *, void *), void *, struct ifaddr *);
int	rt_walktree(sa_family_t, int (*)(struct rtentry *, void *), void *);

static __inline void
rt_assert_referenced(const struct rtentry *rt)
{

	KASSERT(rt->rt_refcnt > 0);
}

void	rtcache_copy(struct route *, struct route *);
void	rtcache_free(struct route *);
struct rtentry *
	rtcache_init(struct route *);
struct rtentry *
	rtcache_init_noclone(struct route *);
struct rtentry *
	rtcache_lookup2(struct route *, const struct sockaddr *, int,
	    int *);
int	rtcache_setdst(struct route *, const struct sockaddr *);
struct rtentry *
	rtcache_update(struct route *, int);

static __inline void
rtcache_invariants(const struct route *ro)
{

	KASSERT(ro->ro_sa != NULL || ro->_ro_rt == NULL);
}

static __inline struct rtentry *
rtcache_lookup1(struct route *ro, const struct sockaddr *dst, int clone)
{
	int hit;

	return rtcache_lookup2(ro, dst, clone, &hit);
}

static __inline struct rtentry *
rtcache_lookup(struct route *ro, const struct sockaddr *dst)
{
	return rtcache_lookup1(ro, dst, 1);
}

static __inline const struct sockaddr *
rtcache_getdst(const struct route *ro)
{

	rtcache_invariants(ro);
	return ro->ro_sa;
}

struct rtentry *
	rtcache_validate(struct route *);

void	rtcache_unref(struct rtentry *, struct route *);

percpu_t *
	rtcache_percpu_alloc(void);

static inline struct route *
rtcache_percpu_getref(percpu_t *pc)
{

	return *(struct route **)percpu_getref(pc);
}

static inline void
rtcache_percpu_putref(percpu_t *pc)
{

	percpu_putref(pc);
}


/* rtsock */
void	rt_ieee80211msg(struct ifnet *, int, void *, size_t);
void	rt_ifannouncemsg(struct ifnet *, int);
void	rt_ifmsg(struct ifnet *);
void	rt_missmsg(int, const struct rt_addrinfo *, int, int);
struct mbuf *
	rt_msg1(int, struct rt_addrinfo *, void *, int);
int	rt_msg3(int, struct rt_addrinfo *, void *, struct rt_walkarg *, int *);
void	rt_addrmsg(int, struct ifaddr *);
void	rt_addrmsg_src(int, struct ifaddr *, const struct sockaddr *);
void	rt_addrmsg_rt(int, struct ifaddr *, int, struct rtentry *);
void	route_enqueue(struct mbuf *, int);

struct llentry;
void	rt_clonedmsg(int, const struct sockaddr *, const struct sockaddr *,
	    const uint8_t *, const struct ifnet *);

void	rt_setmetrics(void *, struct rtentry *);

/* rtbl */
int	rt_addaddr(rtbl_t *, struct rtentry *, const struct sockaddr *);
void	rt_assert_inactive(const struct rtentry *);
struct rtentry *
	rt_deladdr(rtbl_t *, const struct sockaddr *,
	    const struct sockaddr *);
rtbl_t *rt_gettable(sa_family_t);
int	rt_inithead(rtbl_t **, int);
struct rtentry *
	rt_lookup(rtbl_t *, const struct sockaddr *,
	    const struct sockaddr *);
struct rtentry *
	rt_matchaddr(rtbl_t *, const struct sockaddr *);
int	rt_refines(const struct sockaddr *, const struct sockaddr *);
int	rtbl_walktree(sa_family_t, int (*)(struct rtentry *, void *), void *);
struct rtentry *
	rtbl_search_matched_entry(sa_family_t,
	    int (*)(struct rtentry *, void *), void *);
void	rtbl_init(void);

void sysctl_net_route_setup(struct sysctllog **, int, const char *);

#endif /* _KERNEL */

#endif /* !_NET_ROUTE_H_ */