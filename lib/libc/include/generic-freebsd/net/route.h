/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
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
 *	@(#)route.h	8.4 (Berkeley) 1/9/95
 */

#ifndef _NET_ROUTE_H_
#define _NET_ROUTE_H_

#include <net/vnet.h>

/*
 * Kernel resident routing tables.
 *
 * The routing tables are initialized when interface addresses
 * are set by making entries for all directly connected interfaces.
 */

/*
 * Struct route consiste of a destination address,
 * a route entry pointer, link-layer prepend data pointer along
 * with its length.
 */
struct route {
	struct	nhop_object *ro_nh;
	struct	llentry *ro_lle;
	/*
	 * ro_prepend and ro_plen are only used for bpf to pass in a
	 * preformed header.  They are not cacheable.
	 */
	char		*ro_prepend;
	uint16_t	ro_plen;
	uint16_t	ro_flags;
	uint16_t	ro_mtu;	/* saved ro_rt mtu */
	uint16_t	spare;
	struct	sockaddr ro_dst;
};

#define	RT_L2_ME_BIT		2	/* dst L2 addr is our address */
#define	RT_MAY_LOOP_BIT		3	/* dst may require loop copy */
#define	RT_HAS_HEADER_BIT	4	/* mbuf already have its header prepended */

#define	RT_L2_ME		(1 << RT_L2_ME_BIT)		/* 0x0004 */
#define	RT_MAY_LOOP		(1 << RT_MAY_LOOP_BIT)		/* 0x0008 */
#define	RT_HAS_HEADER		(1 << RT_HAS_HEADER_BIT)	/* 0x0010 */

#define	RT_REJECT		0x0020		/* Destination is reject */
#define	RT_BLACKHOLE		0x0040		/* Destination is blackhole */
#define	RT_HAS_GW		0x0080		/* Destination has GW  */
#define	RT_LLE_CACHE		0x0100		/* Cache link layer  */

struct rt_metrics {
	u_long	rmx_locks;	/* Kernel must leave these values alone */
	u_long	rmx_mtu;	/* MTU for this path */
	u_long	rmx_hopcount;	/* max hops expected */
	u_long	rmx_expire;	/* lifetime for route, e.g. redirect */
	u_long	rmx_recvpipe;	/* inbound delay-bandwidth product */
	u_long	rmx_sendpipe;	/* outbound delay-bandwidth product */
	u_long	rmx_ssthresh;	/* outbound gateway buffer limit */
	u_long	rmx_rtt;	/* estimated round trip time */
	u_long	rmx_rttvar;	/* estimated rtt variance */
	u_long	rmx_pksent;	/* packets sent using this route */
	u_long	rmx_weight;	/* route weight */
	u_long	rmx_nhidx;	/* route nexhop index */
	u_long	rmx_filler[2];	/* will be used for T/TCP later */
};

/*
 * rmx_rtt and rmx_rttvar are stored as microseconds;
 */
#define	RTM_RTTUNIT	1000000	/* units for rtt, rttvar, as units per sec */

/* lle state is exported in rmx_state rt_metrics field */
#define	rmx_state	rmx_weight

/* default route weight */
#define	RT_DEFAULT_WEIGHT	1
#define	RT_MAX_WEIGHT		16777215	/* 3 bytes */

/*
 * Keep a generation count of routing table, incremented on route addition,
 * so we can invalidate caches.  This is accessed without a lock, as precision
 * is not required.
 */
typedef volatile u_int rt_gen_t;	/* tree generation (for adds) */
#define RT_GEN(fibnum, af)	rt_tables_get_gen(fibnum, af)

#define	RT_DEFAULT_FIB	0	/* Explicitly mark fib=0 restricted cases */
#define	RT_ALL_FIBS	-1	/* Announce event for every fib */
#ifdef _KERNEL
VNET_DECLARE(uint32_t, _rt_numfibs);	/* number of existing route tables */
#define	V_rt_numfibs		VNET(_rt_numfibs)
/* temporary compat arg */
#define	rt_numfibs		V_rt_numfibs
VNET_DECLARE(u_int, rt_add_addr_allfibs); /* Announce interfaces to all fibs */
#define	V_rt_add_addr_allfibs	VNET(rt_add_addr_allfibs)

/* Calculate flowid for locally-originated packets */
#define	V_fib_hash_outbound	VNET(fib_hash_outbound)
VNET_DECLARE(u_int, fib_hash_outbound);

/* Outbound flowid generation rules */
#ifdef RSS

#define fib4_calc_packet_hash		xps_proto_software_hash_v4
#define fib6_calc_packet_hash		xps_proto_software_hash_v6
#define	CALC_FLOWID_OUTBOUND_SENDTO	true

#ifdef ROUTE_MPATH
#define	CALC_FLOWID_OUTBOUND		V_fib_hash_outbound
#else
#define	CALC_FLOWID_OUTBOUND		false
#endif

#else /* !RSS */

#define fib4_calc_packet_hash		fib4_calc_software_hash
#define fib6_calc_packet_hash		fib6_calc_software_hash

#ifdef ROUTE_MPATH
#define	CALC_FLOWID_OUTBOUND_SENDTO	V_fib_hash_outbound
#define	CALC_FLOWID_OUTBOUND		V_fib_hash_outbound
#else
#define	CALC_FLOWID_OUTBOUND_SENDTO	false
#define	CALC_FLOWID_OUTBOUND		false
#endif

#endif /* RSS */


#endif /* _KERNEL */

/*
 * We distinguish between routes to hosts and routes to networks,
 * preferring the former if available.  For each route we infer
 * the interface to use from the gateway address supplied when
 * the route was entered.  Routes that forward packets through
 * gateways are marked so that the output routines know to address the
 * gateway rather than the ultimate destination.
 */
#define	RTF_UP		0x1		/* route usable */
#define	RTF_GATEWAY	0x2		/* destination is a gateway */
#define	RTF_HOST	0x4		/* host entry (net otherwise) */
#define	RTF_REJECT	0x8		/* host or net unreachable */
#define	RTF_DYNAMIC	0x10		/* created dynamically (by redirect) */
#define	RTF_MODIFIED	0x20		/* modified dynamically (by redirect) */
#define RTF_DONE	0x40		/* message confirmed */
/*			0x80		   unused, was RTF_DELCLONE */
/*			0x100		   unused, was RTF_CLONING */
#define RTF_XRESOLVE	0x200		/* external daemon resolves name */
#define RTF_LLINFO	0x400		/* DEPRECATED - exists ONLY for backward 
					   compatibility */
#define RTF_LLDATA	0x400		/* used by apps to add/del L2 entries */
#define RTF_STATIC	0x800		/* manually added */
#define RTF_BLACKHOLE	0x1000		/* just discard pkts (during updates) */
#define RTF_PROTO2	0x4000		/* protocol specific routing flag */
#define RTF_PROTO1	0x8000		/* protocol specific routing flag */
/*			0x10000		   unused, was RTF_PRCLONING */
/*			0x20000		   unused, was RTF_WASCLONED */
#define RTF_PROTO3	0x40000		/* protocol specific routing flag */
#define	RTF_FIXEDMTU	0x80000		/* MTU was explicitly specified */
#define RTF_PINNED	0x100000	/* route is immutable */
#define	RTF_LOCAL	0x200000 	/* route represents a local address */
#define	RTF_BROADCAST	0x400000	/* route represents a bcast address */
#define	RTF_MULTICAST	0x800000	/* route represents a mcast address */
					/* 0x8000000 and up unassigned */
#define	RTF_STICKY	 0x10000000	/* always route dst->src */

/*			0x40000000	   unused, was RTF_RNH_LOCKED */

#define	RTF_GWFLAG_COMPAT 0x80000000	/* a compatibility bit for interacting
					   with existing routing apps */

/* Mask of RTF flags that are allowed to be modified by RTM_CHANGE. */
#define RTF_FMASK	\
	(RTF_PROTO1 | RTF_PROTO2 | RTF_PROTO3 | RTF_BLACKHOLE | \
	 RTF_REJECT | RTF_STATIC | RTF_STICKY)

/*
 * fib_ nexthop API flags.
 */

/* Consumer-visible nexthop info flags */
#define	NHF_MULTIPATH		0x0008	/* Nexhop is a nexthop group */
#define	NHF_REJECT		0x0010	/* RTF_REJECT */
#define	NHF_BLACKHOLE		0x0020	/* RTF_BLACKHOLE */
#define	NHF_REDIRECT		0x0040	/* RTF_DYNAMIC|RTF_MODIFIED */
#define	NHF_DEFAULT		0x0080	/* Default route */
#define	NHF_BROADCAST		0x0100	/* RTF_BROADCAST */
#define	NHF_GATEWAY		0x0200	/* RTF_GATEWAY */
#define	NHF_HOST		0x0400	/* RTF_HOST */

/* Nexthop request flags */
#define	NHR_NONE		0x00	/* empty flags field */
#define	NHR_REF			0x01	/* reference nexhop */
#define	NHR_NODEFAULT		0x02	/* uRPF: do not consider default route */

/* Control plane route request flags */
#define	NHR_COPY		0x100	/* Copy rte data */
#define	NHR_UNLOCKED		0x200	/* Do not lock table */

/*
 * Routing statistics.
 */
struct rtstat {
	uint64_t rts_badredirect;	/* bogus redirect calls */
	uint64_t rts_dynamic;		/* routes created by redirects */
	uint64_t rts_newgateway;	/* routes modified by redirects */
	uint64_t rts_unreach;		/* lookups which failed */
	uint64_t rts_wildcard;		/* lookups satisfied by a wildcard */
	uint64_t rts_nh_idx_alloc_failure;	/* nexthop index alloc failure*/
	uint64_t rts_nh_alloc_failure;	/* nexthop allocation failure*/
	uint64_t rts_add_failure;	/* # of route addition failures */
	uint64_t rts_add_retry;		/* # of route addition retries */
	uint64_t rts_del_failure;	/* # of route deletion failure */
	uint64_t rts_del_retry;		/* # of route deletion retries */
};

/*
 * Structures for routing messages.
 */
struct rt_msghdr {
	u_short	rtm_msglen;	/* to skip over non-understood messages */
	u_char	rtm_version;	/* future binary compatibility */
	u_char	rtm_type;	/* message type */
	u_short	rtm_index;	/* index for associated ifp */
	u_short _rtm_spare1;
	int	rtm_flags;	/* flags, incl. kern & message, e.g. DONE */
	int	rtm_addrs;	/* bitmask identifying sockaddrs in msg */
	pid_t	rtm_pid;	/* identify sender */
	int	rtm_seq;	/* for sender to identify action */
	int	rtm_errno;	/* why failed */
	int	rtm_fmask;	/* bitmask used in RTM_CHANGE message */
	u_long	rtm_inits;	/* which metrics we are initializing */
	struct	rt_metrics rtm_rmx; /* metrics themselves */
};

#define RTM_VERSION	5	/* Up the ante and ignore older versions */

#ifndef NETLINK_COMPAT
/*
 * Message types.
 *
 * The format for each message is annotated below using the following
 * identifiers:
 *
 * (1) struct rt_msghdr
 * (2) struct ifa_msghdr
 * (3) struct if_msghdr
 * (4) struct ifma_msghdr
 * (5) struct if_announcemsghdr
 *
 */
#define	RTM_ADD		0x1	/* (1) Add Route */
#define	RTM_DELETE	0x2	/* (1) Delete Route */
#define	RTM_CHANGE	0x3	/* (1) Change Metrics or flags */
#define	RTM_GET		0x4	/* (1) Report Metrics */
#define	RTM_LOSING	0x5	/* (1) Kernel Suspects Partitioning */
#define	RTM_REDIRECT	0x6	/* (1) Told to use different route */
#define	RTM_MISS	0x7	/* (1) Lookup failed on this address */
#define	RTM_LOCK	0x8	/* (1) fix specified metrics */
		    /*	0x9  */
		    /*	0xa  */
#define	RTM_RESOLVE	0xb	/* (1) req to resolve dst to LL addr */
#define	RTM_NEWADDR	0xc	/* (2) address being added to iface */
#define	RTM_DELADDR	0xd	/* (2) address being removed from iface */
#define	RTM_IFINFO	0xe	/* (3) iface going up/down etc. */
#define	RTM_NEWMADDR	0xf	/* (4) mcast group membership being added to if */
#define	RTM_DELMADDR	0x10	/* (4) mcast group membership being deleted */
#define	RTM_IFANNOUNCE	0x11	/* (5) iface arrival/departure */
#define	RTM_IEEE80211	0x12	/* (5) IEEE80211 wireless event */

#endif /* NETLINK_COMPAT*/

/*
 * Bitmask values for rtm_inits and rmx_locks.
 */
#define RTV_MTU		0x1	/* init or lock _mtu */
#define RTV_HOPCOUNT	0x2	/* init or lock _hopcount */
#define RTV_EXPIRE	0x4	/* init or lock _expire */
#define RTV_RPIPE	0x8	/* init or lock _recvpipe */
#define RTV_SPIPE	0x10	/* init or lock _sendpipe */
#define RTV_SSTHRESH	0x20	/* init or lock _ssthresh */
#define RTV_RTT		0x40	/* init or lock _rtt */
#define RTV_RTTVAR	0x80	/* init or lock _rttvar */
#define RTV_WEIGHT	0x100	/* init or lock _weight */

#ifndef NETLINK_COMPAT

/*
 * Bitmask values for rtm_addrs.
 */
#define RTA_DST		0x1	/* destination sockaddr present */
#define RTA_GATEWAY	0x2	/* gateway sockaddr present */
#define RTA_NETMASK	0x4	/* netmask sockaddr present */
#define RTA_GENMASK	0x8	/* cloning mask sockaddr present */
#define RTA_IFP		0x10	/* interface name sockaddr present */
#define RTA_IFA		0x20	/* interface addr sockaddr present */
#define RTA_AUTHOR	0x40	/* sockaddr for author of redirect */
#define RTA_BRD		0x80	/* for NEWADDR, broadcast or p-p dest addr */

#endif /* NETLINK_COMPAT*/

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
#define RTAX_MAX	8	/* size of array to allocate */

struct rtentry;
struct nhop_object;
typedef int rib_filter_f_t(const struct rtentry *, const struct nhop_object *,
    void *);

struct rt_addrinfo {
	int	rti_addrs;			/* Route RTF_ flags */
	int	rti_flags;			/* Route RTF_ flags */
	struct	sockaddr *rti_info[RTAX_MAX];	/* Sockaddr data */
	struct	ifaddr *rti_ifa;		/* value of rt_ifa addr */
	struct	ifnet *rti_ifp;			/* route interface */
	rib_filter_f_t	*rti_filter;		/* filter function */
	void	*rti_filterdata;		/* filter parameters */
	u_long	rti_mflags;			/* metrics RTV_ flags */
	u_long	rti_spare;			/* Will be used for fib */
	struct	rt_metrics *rti_rmx;		/* Pointer to route metrics */
};

/*
 * This macro returns the size of a struct sockaddr when passed
 * through a routing socket. Basically we round up sa_len to
 * a multiple of sizeof(long), with a minimum of sizeof(long).
 * The case sa_len == 0 should only apply to empty structures.
 */
#define SA_SIZE(sa)						\
    (  (((struct sockaddr *)(sa))->sa_len == 0) ?		\
	sizeof(long)		:				\
	1 + ( (((struct sockaddr *)(sa))->sa_len - 1) | (sizeof(long) - 1) ) )

#define	sa_equal(a, b) (	\
    (((const struct sockaddr *)(a))->sa_len == ((const struct sockaddr *)(b))->sa_len) && \
    (bcmp((a), (b), ((const struct sockaddr *)(b))->sa_len) == 0))

#ifdef _KERNEL

#define RT_LINK_IS_UP(ifp)	(!((ifp)->if_capabilities & IFCAP_LINKSTATE) \
				 || (ifp)->if_link_state == LINK_STATE_UP)

#define	RO_NHFREE(_ro) do {					\
	if ((_ro)->ro_nh) {					\
		NH_FREE((_ro)->ro_nh);				\
		(_ro)->ro_nh = NULL;				\
	}							\
} while (0)

#define	RO_INVALIDATE_CACHE(ro) do {					\
		if ((ro)->ro_lle != NULL) {				\
			LLE_FREE((ro)->ro_lle);				\
			(ro)->ro_lle = NULL;				\
		}							\
		if ((ro)->ro_nh != NULL) {				\
			NH_FREE((ro)->ro_nh);				\
			(ro)->ro_nh = NULL;				\
		}							\
	} while (0)

#define RO_GET_FAMILY(ro, dst)	((ro) != NULL &&		\
	(ro)->ro_flags & RT_HAS_GW				\
	? (ro)->ro_dst.sa_family : (dst)->sa_family)

/*
 * Validate a cached route based on a supplied cookie.  If there is an
 * out-of-date cache, simply free it.  Update the generation number
 * for the new allocation
 */
#define NH_VALIDATE(ro, cookiep, fibnum) do {				\
	rt_gen_t cookie = RT_GEN(fibnum, (ro)->ro_dst.sa_family);	\
	if (*(cookiep) != cookie) {					\
		RO_INVALIDATE_CACHE(ro);				\
		*(cookiep) = cookie;					\
	}								\
} while (0)

struct ifmultiaddr;
struct rib_head;

void	 rt_ieee80211msg(struct ifnet *, int, void *, size_t);
void	 rt_ifmsg(struct ifnet *, int);
void	 rt_missmsg(int, struct rt_addrinfo *, int, int);
void	 rt_missmsg_fib(int, struct rt_addrinfo *, int, int, int);
int	 rt_addrmsg(int, struct ifaddr *, int);
int	 rt_routemsg(int, struct rtentry *, struct nhop_object *, int);
int	 rt_routemsg_info(int, struct rt_addrinfo *, int);
void	 rt_newmaddrmsg(int, struct ifmultiaddr *);
void 	 rt_maskedcopy(const struct sockaddr *, struct sockaddr *,
	    const struct sockaddr *);
struct rib_head *rt_table_init(int, int, u_int);
void	rt_table_destroy(struct rib_head *);
u_int	rt_tables_get_gen(uint32_t table, sa_family_t family);

struct sockaddr *rtsock_fix_netmask(const struct sockaddr *dst,
	    const struct sockaddr *smask, struct sockaddr_storage *dmask);

void	rt_updatemtu(struct ifnet *);

void	rt_flushifroutes(struct ifnet *ifp);

/* XXX MRT NEW VERSIONS THAT USE FIBs
 * For now the protocol indepedent versions are the same as the AF_INET ones
 * but this will change.. 
 */
int	rtioctl_fib(u_long, caddr_t, u_int);

/* New API */
void rib_flush_routes_family(int family);
struct nhop_object *rib_lookup(uint32_t fibnum, const struct sockaddr *dst,
	    uint32_t flags, uint32_t flowid);
const char *rib_print_family(int family);
#endif

#endif