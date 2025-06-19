/*	$NetBSD: ip6_var.h,v 1.93 2022/10/28 05:18:39 ozaki-r Exp $	*/
/*	$KAME: ip6_var.h,v 1.33 2000/06/11 14:59:20 jinmei Exp $	*/

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
 *	@(#)ip_var.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NETINET6_IP6_VAR_H_
#define _NETINET6_IP6_VAR_H_

#include <sys/types.h>
#include <sys/queue.h>
#include <sys/socketvar.h>

#include <net/if.h>
#include <net/route.h>

#include <netinet/in.h>
#include <netinet/ip6.h>

struct	ip6_moptions {
	if_index_t im6o_multicast_if_index; /* I/F for outgoing multicasts */
	u_char	im6o_multicast_hlim;	/* hoplimit for outgoing multicasts */
	u_char	im6o_multicast_loop;	/* 1 >= hear sends if a member */
	LIST_HEAD(, in6_multi_mship) im6o_memberships;
};

/*
 * Control options for outgoing packets
 */

/* Routing header related info */
struct	ip6po_rhinfo {
	struct	ip6_rthdr *ip6po_rhi_rthdr; /* Routing header */
	struct	route ip6po_rhi_route; /* Route to the 1st hop */
};
#define ip6po_rthdr	ip6po_rhinfo.ip6po_rhi_rthdr
#define ip6po_route	ip6po_rhinfo.ip6po_rhi_route

/* Nexthop related info */
struct	ip6po_nhinfo {
	struct	sockaddr *ip6po_nhi_nexthop;
	struct	route ip6po_nhi_route; /* Route to the nexthop */
};
#define ip6po_nexthop	ip6po_nhinfo.ip6po_nhi_nexthop
#define ip6po_nextroute	ip6po_nhinfo.ip6po_nhi_route

struct	ip6_pktopts {
	int	ip6po_hlim;		/* Hoplimit for outgoing packets */
	struct	in6_pktinfo *ip6po_pktinfo; /* Outgoing IF/address information */
	struct	ip6po_nhinfo ip6po_nhinfo; /* Next-hop address information */
	struct	ip6_hbh *ip6po_hbh; /* Hop-by-Hop options header */
	struct	ip6_dest *ip6po_dest1; /* Destination options header(1st part) */
	struct	ip6po_rhinfo ip6po_rhinfo; /* Routing header related info. */
	struct	ip6_dest *ip6po_dest2; /* Destination options header(2nd part) */
	int	ip6po_tclass;	/* traffic class */
	int	ip6po_minmtu;  /* fragment vs PMTU discovery policy */
#define IP6PO_MINMTU_MCASTONLY	-1 /* default; send at min MTU for multicast*/
#define IP6PO_MINMTU_DISABLE	 0 /* always perform pmtu disc */
#define IP6PO_MINMTU_ALL	 1 /* always send at min MTU */
	int	ip6po_prefer_tempaddr;	/* whether temporary addresses are
					 * preferred as source address */
#define IP6PO_TEMPADDR_SYSTEM	-1 /* follow the system default */
#define IP6PO_TEMPADDR_NOTPREFER 0 /* not prefer temporary address */
#define IP6PO_TEMPADDR_PREFER	 1 /* prefer temporary address */
	int ip6po_flags;
#if 0	/* parameters in this block is obsolete. do not reuse the values. */
#define IP6PO_REACHCONF	0x01	/* upper-layer reachability confirmation. */
#define IP6PO_MINMTU	0x02	/* use minimum MTU (IPV6_USE_MIN_MTU) */
#endif
#define IP6PO_DONTFRAG	0x04	/* disable fragmentation (IPV6_DONTFRAG) */
};

/*
 * IPv6 statistics.
 * Each counter is an unsigned 64-bit value.
 */
#define	IP6_STAT_TOTAL		0	/* total packets received */
#define	IP6_STAT_TOOSHORT	1	/* packet too short */
#define	IP6_STAT_TOOSMALL	2	/* not enough data */
#define	IP6_STAT_FRAGMENTS	3	/* fragments received */
#define	IP6_STAT_FRAGDROPPED	4	/* frags dropped (dups, out of space) */
#define	IP6_STAT_FRAGTIMEOUT	5	/* fragments timed out */
#define	IP6_STAT_FRAGOVERFLOW	6	/* fragments that exceed limit */
#define IP6_STAT_FORWARD	7	/* packets forwarded */
#define	IP6_STAT_CANTFORWARD	8	/* packets rcvd for uncreachable dst */
#define	IP6_STAT_REDIRECTSENT	9	/* packets forwarded on same net */
#define	IP6_STAT_DELIVERED	10	/* datagrams delivered to upper level */
#define	IP6_STAT_LOCALOUT	11	/* total IP packets generated here */
#define	IP6_STAT_ODROPPED	12	/* lost packets due to nobufs, etc. */
#define	IP6_STAT_REASSEMBLED	13	/* total packets reassembled ok */
#define	IP6_STAT_FRAGMENTED	14	/* datagrams successfully fragmented */
#define	IP6_STAT_OFRAGMENTS	15	/* output fragments created */
#define	IP6_STAT_CANTFRAG	16	/* don't fragment flag was set, etc. */
#define	IP6_STAT_BADOPTIONS	17	/* error in option processing */
#define	IP6_STAT_NOROUTE	18	/* packets discarded due to no route */
#define	IP6_STAT_BADVERS	19	/* ip6 version != 6 */
#define	IP6_STAT_RAWOUT		20	/* total raw ip packets generated */
#define	IP6_STAT_BADSCOPE	21	/* scope error */
#define	IP6_STAT_NOTMEMBER	22	/* don't join this multicast group */
#define	IP6_STAT_NXTHIST	23	/* next header histogram */
		/* space for 256 counters */
#define	IP6_STAT_M1		279	/* one mbuf */
#define	IP6_STAT_M2M		280	/* two or more mbuf */
		/* space for 32 counters */
#define	IP6_STAT_MEXT1		312	/* one ext mbuf */
#define	IP6_STAT_MEXT2M		313	/* two or more ext mbuf */
#define	IP6_STAT_EXTHDRTOOLONG	314	/* ext hdr are not contiguous */
#define	IP6_STAT_NOGIF		315	/* no match gif found */
#define	IP6_STAT_TOOMANYHDR	316	/* discarded due to too many headers */
	/*
	 * statistics for improvement of the source address selection
	 * algorithm:
	 * XXX: hardcoded 16 = # of ip6 multicast scope types + 1
	 */
#define	IP6_STAT_SOURCES_NONE	317	/* number of times that address
					   selection fails */
#define	IP6_STAT_SOURCES_SAMEIF	318	/* number of times that an address
					   on the outgoing I/F is chosen */
		/* space for 16 counters */
#define	IP6_STAT_SOURCES_OTHERIF 334	/* number of times that an address on
					   a non-outgoing I/F is chosen */
		/* space for 16 counters */
#define	IP6_STAT_SOURCES_SAMESCOPE 350	/* number of times that an address that
					   has the same scope from the dest.
					   is chosen */
		/* space for 16 counters */
#define	IP6_STAT_SOURCES_OTHERSCOPE 366	/* number of times that an address that
					   has a different scope from the dest.
					   is chosen */
		/* space for 16 counters */
#define	IP6_STAT_SOURCES_DEPRECATED 382	/* number of times that a deprecated
					   address is chosen */
		/* space for 16 counters */
#define	IP6_STAT_FORWARD_CACHEHIT 398
#define	IP6_STAT_FORWARD_CACHEMISS 399
#define	IP6_STAT_FASTFORWARD	400	/* packets fast forwarded */
#define	IP6_STAT_FASTFORWARDFLOWS 401	/* number of fast forward flows */
#define	IP6_STAT_NOIPSEC	402	/* no match ipsec(4) found */
#define	IP6_STAT_PFILDROP_IN	403	/* dropped by pfil (PFIL_IN) */
#define	IP6_STAT_PFILDROP_OUT	404	/* dropped by pfil (PFIL_OUT) */
#define	IP6_STAT_IPSECDROP_IN	405	/* dropped by IPsec SP check */
#define	IP6_STAT_IPSECDROP_OUT	406	/* dropped by IPsec SP check */
#define	IP6_STAT_IFDROP		407	/* dropped due to interface state */
#define	IP6_STAT_IDROPPED	408	/* lost packets due to nobufs, etc. */
#define	IP6_STAT_TIMXCEED	409	/* hop limit exceeded */
#define	IP6_STAT_TOOBIG		410	/* packet bigger than MTU */
#define	IP6_STAT_RTREJECT	411	/* rejected by route */

#define	IP6_NSTATS		412

#define IP6FLOW_HASHBITS         6 /* should not be a multiple of 8 */

/* 
 * Structure for an IPv6 flow (ip6_fastforward).
 */
struct ip6flow {
	TAILQ_ENTRY(ip6flow) ip6f_list;  /* next in active list */
	TAILQ_ENTRY(ip6flow) ip6f_hash;  /* next ip6flow in bucket */
	size_t ip6f_hashidx;             /* own hash index of ipflowtable[] */
	struct in6_addr ip6f_dst;       /* destination address */
	struct in6_addr ip6f_src;       /* source address */
	struct route ip6f_ro;       /* associated route entry */
	u_int32_t ip6f_flow;		/* flow (tos) */
	u_quad_t ip6f_uses;               /* number of uses in this period */
	u_quad_t ip6f_last_uses;          /* number of uses in last period */
	u_quad_t ip6f_dropped;            /* ENOBUFS returned by if_output */
	u_quad_t ip6f_forwarded;          /* packets forwarded */
	u_int ip6f_timer;               /* lifetime timer */
};

#ifdef _KERNEL

#include <sys/protosw.h>
#include <sys/cprng.h>

/*
 * Auxiliary attributes of incoming IPv6 packets, which is initialized when we
 * come into ip6_input().
 * XXX do not make it a kitchen sink!
 */
struct ip6aux {
	/* ip6.ip6_dst */
	struct in6_addr	ip6a_src;
	uint32_t	ip6a_scope_id;
	int		ip6a_flags;
};

/* flags passed to ip6_output as last parameter */
#define	IPV6_UNSPECSRC		0x01	/* allow :: as the source address */
#define	IPV6_FORWARDING		0x02	/* most of IPv6 header exists */
#define	IPV6_MINMTU		0x04	/* use minimum MTU (IPV6_USE_MIN_MTU) */

extern u_int32_t ip6_id;		/* fragment identifier */
extern int	ip6_defhlim;		/* default hop limit */
extern int	ip6_defmcasthlim;	/* default multicast hop limit */
extern int	ip6_forwarding;		/* act as router? */
extern int	ip6_sendredirect;	/* send ICMPv6 redirect? */
extern int	ip6_use_deprecated;	/* allow deprecated addr as source */
extern int	ip6_mcast_pmtu;		/* enable pMTU discovery for multicast? */
extern int	ip6_v6only;
extern int	ip6_neighborgcthresh;	/* Threshold # of NDP entries for GC */
extern int	ip6_maxdynroutes; /* Max # of routes created via redirect */
extern int	ip6_param_rt_msg;  /* How to send parmeter changing rtm */


extern struct socket *ip6_mrouter; 	/* multicast routing daemon */
extern int	ip6_sendredirects;	/* send IP redirects when forwarding? */
extern int	ip6_maxfragpackets; /* Maximum packets in reassembly queue */
extern int	ip6_maxfrags;	/* Maximum fragments in reassembly queue */
extern int	ip6_keepfaith;		/* Firewall Aided Internet Translator */
extern int	ip6_log_interval;
extern time_t	ip6_log_time;
extern int	ip6_hdrnestlimit; /* upper limit of # of extension headers */
extern int	ip6_dad_count;		/* DupAddrDetectionTransmits */

extern int ip6_auto_flowlabel;
extern int ip6_auto_linklocal;

extern int   ip6_anonportmin;		/* minimum ephemeral port */
extern int   ip6_anonportmax;		/* maximum ephemeral port */
extern int   ip6_lowportmin;		/* minimum reserved port */
extern int   ip6_lowportmax;		/* maximum reserved port */

extern int	ip6_prefer_tempaddr; /* whether to prefer temporary addresses
					in the source address selection */
extern int	ip6_use_defzone; /* whether to use the default scope zone
				    when unspecified */

#ifdef GATEWAY
extern int      ip6_maxflows;           /* maximum amount of flows for ip6ff */
extern int	ip6_hashsize;		/* size of hash table */
#endif

struct inpcb;
extern const struct pr_usrreqs rip6_usrreqs;

int	icmp6_ctloutput(int, struct socket *, struct sockopt *);

struct mbuf;
void	ip6_init(void);
const struct ip6aux *ip6_getdstifaddr(struct mbuf *);
void	ip6_freepcbopts(struct ip6_pktopts *);
void	ip6_freemoptions(struct ip6_moptions *);
int	ip6_unknown_opt(u_int8_t *, struct mbuf *, int);
int	ip6_get_prevhdr(struct mbuf *, int);
int	ip6_nexthdr(struct mbuf *, int, int, int *);
int	ip6_lasthdr(struct mbuf *, int, int, int *);

struct ip6_hdr;
int	ip6_mforward(struct ip6_hdr *, struct ifnet *, struct mbuf *);
int	ip6_hopopts_input(u_int32_t *, u_int32_t *, struct mbuf **, int *);
void	ip6_savecontrol(struct inpcb *, struct mbuf **, struct ip6_hdr *,
		struct mbuf *);
void	ip6_notify_pmtu(struct inpcb *, const struct sockaddr_in6 *,
		u_int32_t *);
int	ip6_sysctl(int *, u_int, void *, size_t *, void *, size_t);

void	ip6_forward(struct mbuf *, int, struct ifnet *);

void	ip6_mloopback(struct ifnet *, struct mbuf *,
	              const struct sockaddr_in6 *);
int	ip6_output(struct mbuf *, struct ip6_pktopts *, struct route *, int,
	    struct ip6_moptions *, struct inpcb *, struct ifnet **);
int	ip6_if_output(struct ifnet * const, struct ifnet * const,
	    struct mbuf * const,
	    const struct sockaddr_in6 * const, const struct rtentry *);
int	ip6_ctloutput(int, struct socket *, struct sockopt *);
int	ip6_raw_ctloutput(int, struct socket *, struct sockopt *);
void	ip6_initpktopts(struct ip6_pktopts *);
int	ip6_setpktopts(struct mbuf *, struct ip6_pktopts *,
			    struct ip6_pktopts *, kauth_cred_t, int);
void	ip6_clearpktopts(struct ip6_pktopts *, int);
struct ip6_pktopts *ip6_copypktopts(struct ip6_pktopts *, int);
int	ip6_optlen(struct inpcb *);

void	ip6_statinc(u_int);

int	route6_input(struct mbuf **, int *, int);

void	frag6_init(void);
int	frag6_input(struct mbuf **, int *, int);
int	ip6_reass_packet(struct mbuf **, int);
void	frag6_slowtimo(void);
void	frag6_fasttimo(void);
void	frag6_drain(void);
void	frag6_drainstub(void);

int	ip6flow_init(int);
void	ip6flow_poolinit(void);
struct  ip6flow *ip6flow_reap(int);
void    ip6flow_create(struct route *, struct mbuf *);
void    ip6flow_slowtimo(void);
int	ip6flow_invalidate_all(int);

void	rip6_init(void);
int	rip6_input(struct mbuf **, int *, int);
void	*rip6_ctlinput(int, const struct sockaddr *, void *);
int	rip6_ctloutput(int, struct socket *, struct sockopt *);
int	rip6_output(struct mbuf *, struct socket *, struct sockaddr_in6 *,
			 struct mbuf *);
int	rip6_attach(struct socket *, int);
int	rip6_usrreq(struct socket *,
	    int, struct mbuf *, struct mbuf *, struct mbuf *, struct lwp *);

int	dest6_input(struct mbuf **, int *, int);
int	none_input(struct mbuf **, int *, int);

struct route;

int	in6_selectsrc(struct sockaddr_in6 *, struct ip6_pktopts *,
	   struct ip6_moptions *, struct route *, struct in6_addr *,
	   struct ifnet **, struct psref *, struct in6_addr *);
int in6_selectroute(struct sockaddr_in6 *, struct ip6_pktopts *,
	struct route **, struct rtentry **, bool);
int	ip6_get_membership(const struct sockopt *, struct ifnet **,
	    struct psref *, void *, size_t);

static __inline uint32_t
ip6_randomid(void)
{

	return cprng_fast32();
}

static __inline uint32_t
ip6_randomflowlabel(void)
{

	return cprng_fast32() & 0xfffff;
}

static __inline bool
ip6_dad_enabled(void)
{

	return ip6_dad_count > 0;
}
#endif /* _KERNEL */

#endif /* !_NETINET6_IP6_VAR_H_ */