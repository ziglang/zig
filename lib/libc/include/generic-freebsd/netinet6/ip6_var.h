/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
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
 *
 *	$KAME: ip6_var.h,v 1.62 2001/05/03 14:51:48 itojun Exp $
 */

/*-
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

#include <sys/epoch.h>

#ifdef _KERNEL
struct ip6asfrag;		/* frag6.c */
TAILQ_HEAD(ip6fraghead, ip6asfrag);

/*
 * IP6 reassembly queue structure.  Each fragment
 * being reassembled is attached to one of these structures.
 */
struct	ip6q {
	struct ip6fraghead ip6q_frags;
	u_int32_t	ip6q_ident;
	u_int8_t	ip6q_nxt;
	u_int8_t	ip6q_ecn;
	u_int16_t	ip6q_ttl;
	struct in6_addr ip6q_src, ip6q_dst;
	TAILQ_ENTRY(ip6q) ip6q_tq;
	int		ip6q_unfrglen;	/* len of unfragmentable part */
	int		ip6q_nfrag;	/* # of fragments */
	struct label	*ip6q_label;
};
#endif /* _KERNEL */

/*
 * IP6 reinjecting structure.
 */
struct ip6_direct_ctx {
	uint32_t	ip6dc_nxt;	/* next header to process */
	uint32_t	ip6dc_off;	/* offset to next header */
};

#if defined(_NETINET6_IN6_VAR_H_) && defined(_KERNEL)
/*
 * Structure attached to inpcb.in6p_moptions and
 * passed to ip6_output when IPv6 multicast options are in use.
 * This structure is lazy-allocated.
 */
struct ip6_moptions {
	struct	ifnet *im6o_multicast_ifp; /* ifp for outgoing multicasts */
	u_char	im6o_multicast_hlim;	/* hoplimit for outgoing multicasts */
	u_char	im6o_multicast_loop;	/* 1 >= hear sends if a member */
	struct ip6_mfilter_head im6o_head; /* group membership list */
};
#else
struct ip6_moptions;
#endif
/*
 * Control options for outgoing packets
 */

/* Routing header related info */
struct	ip6po_rhinfo {
	struct	ip6_rthdr *ip6po_rhi_rthdr; /* Routing header */
	struct	route_in6 ip6po_rhi_route; /* Route to the 1st hop */
};
#define ip6po_rthdr	ip6po_rhinfo.ip6po_rhi_rthdr
#define ip6po_route	ip6po_rhinfo.ip6po_rhi_route

/* Nexthop related info */
struct	ip6po_nhinfo {
	struct	sockaddr *ip6po_nhi_nexthop;
	struct	route_in6 ip6po_nhi_route; /* Route to the nexthop */
};
#define ip6po_nexthop	ip6po_nhinfo.ip6po_nhi_nexthop
#define ip6po_nextroute	ip6po_nhinfo.ip6po_nhi_route

struct	ip6_pktopts {
	struct	mbuf *ip6po_m;	/* Pointer to mbuf storing the data */
	int	ip6po_hlim;	/* Hoplimit for outgoing packets */

	/* Outgoing IF/address information */
	struct	in6_pktinfo *ip6po_pktinfo;

	/* Next-hop address information */
	struct	ip6po_nhinfo ip6po_nhinfo;

	struct	ip6_hbh *ip6po_hbh; /* Hop-by-Hop options header */

	/* Destination options header (before a routing header) */
	struct	ip6_dest *ip6po_dest1;

	/* Routing header related info. */
	struct	ip6po_rhinfo ip6po_rhinfo;

	/* Destination options header (after a routing header) */
	struct	ip6_dest *ip6po_dest2;

	int	ip6po_tclass;	/* traffic class */

	int	ip6po_minmtu;  /* fragment vs PMTU discovery policy */
#define IP6PO_MINMTU_MCASTONLY	-1 /* default; send at min MTU for multicast*/
#define IP6PO_MINMTU_DISABLE	 0 /* always perform pmtu disc */
#define IP6PO_MINMTU_ALL	 1 /* always send at min MTU */

	int	ip6po_prefer_tempaddr;  /* whether temporary addresses are
					   preferred as source address */
#define IP6PO_TEMPADDR_SYSTEM	-1 /* follow the system default */
#define IP6PO_TEMPADDR_NOTPREFER 0 /* not prefer temporary address */
#define IP6PO_TEMPADDR_PREFER	 1 /* prefer temporary address */

	int ip6po_flags;
#if 0	/* parameters in this block is obsolete. do not reuse the values. */
#define IP6PO_REACHCONF	0x01	/* upper-layer reachability confirmation. */
#define IP6PO_MINMTU	0x02	/* use minimum MTU (IPV6_USE_MIN_MTU) */
#endif
#define IP6PO_DONTFRAG	0x04	/* disable fragmentation (IPV6_DONTFRAG) */
#define IP6PO_USECOA	0x08	/* use care of address */
};

/*
 * Control options for incoming packets
 */

struct	ip6stat {
	uint64_t ip6s_total;		/* total packets received */
	uint64_t ip6s_tooshort;		/* packet too short */
	uint64_t ip6s_toosmall;		/* not enough data */
	uint64_t ip6s_fragments;	/* fragments received */
	uint64_t ip6s_fragdropped;	/* frags dropped(dups, out of space) */
	uint64_t ip6s_fragtimeout;	/* fragments timed out */
	uint64_t ip6s_fragoverflow;	/* fragments that exceeded limit */
	uint64_t ip6s_forward;		/* packets forwarded */
	uint64_t ip6s_cantforward;	/* packets rcvd for unreachable dest */
	uint64_t ip6s_redirectsent;	/* packets forwarded on same net */
	uint64_t ip6s_delivered;	/* datagrams delivered to upper level*/
	uint64_t ip6s_localout;		/* total ip packets generated here */
	uint64_t ip6s_odropped;		/* lost packets due to nobufs, etc. */
	uint64_t ip6s_reassembled;	/* total packets reassembled ok */
	uint64_t ip6s_atomicfrags;	/* atomic fragments */
	uint64_t ip6s_fragmented;	/* datagrams successfully fragmented */
	uint64_t ip6s_ofragments;	/* output fragments created */
	uint64_t ip6s_cantfrag;		/* don't fragment flag was set, etc. */
	uint64_t ip6s_badoptions;	/* error in option processing */
	uint64_t ip6s_noroute;		/* packets discarded due to no route */
	uint64_t ip6s_badvers;		/* ip6 version != 6 */
	uint64_t ip6s_rawout;		/* total raw ip packets generated */
	uint64_t ip6s_badscope;		/* scope error */
	uint64_t ip6s_notmember;	/* don't join this multicast group */
#define	IP6S_HDRCNT		256	/* headers count */
	uint64_t ip6s_nxthist[IP6S_HDRCNT]; /* next header history */
	uint64_t ip6s_m1;		/* one mbuf */
#define	IP6S_M2MMAX		32
	uint64_t ip6s_m2m[IP6S_M2MMAX];	/* two or more mbuf */
	uint64_t ip6s_mext1;		/* one ext mbuf */
	uint64_t ip6s_mext2m;		/* two or more ext mbuf */
	uint64_t ip6s_exthdrtoolong;	/* ext hdr are not contiguous */
	uint64_t ip6s_nogif;		/* no match gif found */
	uint64_t ip6s_toomanyhdr;	/* discarded due to too many headers */

	/*
	 * statistics for improvement of the source address selection
	 * algorithm:
	 * XXX: hardcoded 16 = # of ip6 multicast scope types + 1
	 */
#define	IP6S_RULESMAX		16
#define	IP6S_SCOPECNT		16
	/* number of times that address selection fails */
	uint64_t ip6s_sources_none;
	/* number of times that an address on the outgoing I/F is chosen */
	uint64_t ip6s_sources_sameif[IP6S_SCOPECNT];
	/* number of times that an address on a non-outgoing I/F is chosen */
	uint64_t ip6s_sources_otherif[IP6S_SCOPECNT];
	/*
	 * number of times that an address that has the same scope
	 * from the destination is chosen.
	 */
	uint64_t ip6s_sources_samescope[IP6S_SCOPECNT];
	/*
	 * number of times that an address that has a different scope
	 * from the destination is chosen.
	 */
	uint64_t ip6s_sources_otherscope[IP6S_SCOPECNT];
	/* number of times that a deprecated address is chosen */
	uint64_t ip6s_sources_deprecated[IP6S_SCOPECNT];

	/* number of times that each rule of source selection is applied. */
	uint64_t ip6s_sources_rule[IP6S_RULESMAX];
};

#ifdef _KERNEL
#include <sys/counter.h>

VNET_PCPUSTAT_DECLARE(struct ip6stat, ip6stat);
#define	IP6STAT_ADD(name, val)	\
    VNET_PCPUSTAT_ADD(struct ip6stat, ip6stat, name, (val))
#define	IP6STAT_SUB(name, val)	IP6STAT_ADD(name, -(val))
#define	IP6STAT_INC(name)	IP6STAT_ADD(name, 1)
#define	IP6STAT_DEC(name)	IP6STAT_SUB(name, 1)
#endif

#ifdef _KERNEL
/* flags passed to ip6_output as last parameter */
#define	IPV6_UNSPECSRC		0x01	/* allow :: as the source address */
#define	IPV6_FORWARDING		0x02	/* most of IPv6 header exists */
#define	IPV6_MINMTU		0x04	/* use minimum MTU (IPV6_USE_MIN_MTU) */

#ifdef __NO_STRICT_ALIGNMENT
#define IP6_HDR_ALIGNED_P(ip)	1
#else
#define IP6_HDR_ALIGNED_P(ip)	((((intptr_t) (ip)) & 3) == 0)
#endif

VNET_DECLARE(int, ip6_defhlim);		/* default hop limit */
VNET_DECLARE(int, ip6_defmcasthlim);	/* default multicast hop limit */
VNET_DECLARE(int, ip6_forwarding);	/* act as router? */
VNET_DECLARE(int, ip6_use_deprecated);	/* allow deprecated addr as source */
VNET_DECLARE(int, ip6_rr_prune);	/* router renumbering prefix
					 * walk list every 5 sec.    */
VNET_DECLARE(int, ip6_mcast_pmtu);	/* enable pMTU discovery for multicast? */
VNET_DECLARE(int, ip6_v6only);
#define	V_ip6_defhlim			VNET(ip6_defhlim)
#define	V_ip6_defmcasthlim		VNET(ip6_defmcasthlim)
#define	V_ip6_forwarding		VNET(ip6_forwarding)
#define	V_ip6_use_deprecated		VNET(ip6_use_deprecated)
#define	V_ip6_rr_prune			VNET(ip6_rr_prune)
#define	V_ip6_mcast_pmtu		VNET(ip6_mcast_pmtu)
#define	V_ip6_v6only			VNET(ip6_v6only)

VNET_DECLARE(struct socket *, ip6_mrouter);	/* multicast routing daemon */
VNET_DECLARE(int, ip6_sendredirects);	/* send IP redirects when forwarding? */
VNET_DECLARE(int, ip6_accept_rtadv);	/* Acts as a host not a router */
VNET_DECLARE(int, ip6_no_radr);		/* No defroute from RA */
VNET_DECLARE(int, ip6_norbit_raif);	/* Disable R-bit in NA on RA
					 * receiving IF. */
VNET_DECLARE(int, ip6_rfc6204w3);	/* Accept defroute from RA even when
					   forwarding enabled */
VNET_DECLARE(int, ip6_hdrnestlimit);	/* upper limit of # of extension
					 * headers */
VNET_DECLARE(int, ip6_dad_count);	/* DupAddrDetectionTransmits */
#define	V_ip6_mrouter			VNET(ip6_mrouter)
#define	V_ip6_sendredirects		VNET(ip6_sendredirects)
#define	V_ip6_accept_rtadv		VNET(ip6_accept_rtadv)
#define	V_ip6_no_radr			VNET(ip6_no_radr)
#define	V_ip6_norbit_raif		VNET(ip6_norbit_raif)
#define	V_ip6_rfc6204w3			VNET(ip6_rfc6204w3)
#define	V_ip6_hdrnestlimit		VNET(ip6_hdrnestlimit)
#define	V_ip6_dad_count			VNET(ip6_dad_count)

VNET_DECLARE(int, ip6_auto_flowlabel);
VNET_DECLARE(int, ip6_auto_linklocal);
#define	V_ip6_auto_flowlabel		VNET(ip6_auto_flowlabel)
#define	V_ip6_auto_linklocal		VNET(ip6_auto_linklocal)

VNET_DECLARE(int, ip6_use_tempaddr);	/* Whether to use temporary addresses */
VNET_DECLARE(int, ip6_prefer_tempaddr);	/* Whether to prefer temporary
					 * addresses in the source address
					 * selection */
#define	V_ip6_use_tempaddr		VNET(ip6_use_tempaddr)
#define	V_ip6_prefer_tempaddr		VNET(ip6_prefer_tempaddr)

VNET_DECLARE(int, ip6_use_defzone);	/* Whether to use the default scope
					 * zone when unspecified */
#define	V_ip6_use_defzone		VNET(ip6_use_defzone)

VNET_DECLARE(struct pfil_head *, inet6_pfil_head);
#define	V_inet6_pfil_head	VNET(inet6_pfil_head)
#define	PFIL_INET6_NAME		"inet6"

VNET_DECLARE(struct pfil_head *, inet6_local_pfil_head);
#define	V_inet6_local_pfil_head	VNET(inet6_local_pfil_head)
#define	PFIL_INET6_LOCAL_NAME	"inet6-local"

#ifdef IPSTEALTH
VNET_DECLARE(int, ip6stealth);
#define	V_ip6stealth			VNET(ip6stealth)
#endif

VNET_DECLARE(bool, ip6_log_cannot_forward);
#define	V_ip6_log_cannot_forward	VNET(ip6_log_cannot_forward)

extern struct	pr_usrreqs rip6_usrreqs;
struct sockopt;

struct inpcb;
struct ucred;

int	icmp6_ctloutput(struct socket *, struct sockopt *sopt);

void	ip6_input(struct mbuf *);
void	ip6_direct_input(struct mbuf *);
void	ip6_freepcbopts(struct ip6_pktopts *);

int	ip6_unknown_opt(u_int8_t *, struct mbuf *, int);
int	ip6_get_prevhdr(const struct mbuf *, int);
int	ip6_nexthdr(const struct mbuf *, int, int, int *);
int	ip6_lasthdr(const struct mbuf *, int, int, int *);

extern int	(*ip6_mforward)(struct ip6_hdr *, struct ifnet *,
    struct mbuf *);

int	ip6_process_hopopts(struct mbuf *, u_int8_t *, int, u_int32_t *,
				 u_int32_t *);
struct mbuf	**ip6_savecontrol_v4(struct inpcb *, struct mbuf *,
	    struct mbuf **, int *);
void	ip6_savecontrol(struct inpcb *, struct mbuf *, struct mbuf **);
void	ip6_notify_pmtu(struct inpcb *, struct sockaddr_in6 *, u_int32_t);
int	ip6_sysctl(int *, u_int, void *, size_t *, void *, size_t);

void	ip6_forward(struct mbuf *, int);

void	ip6_mloopback(struct ifnet *, struct mbuf *);
int	ip6_output(struct mbuf *, struct ip6_pktopts *,
			struct route_in6 *,
			int,
			struct ip6_moptions *, struct ifnet **,
			struct inpcb *);
int	ip6_ctloutput(struct socket *, struct sockopt *);
int	ip6_raw_ctloutput(struct socket *, struct sockopt *);
void	ip6_initpktopts(struct ip6_pktopts *);
int	ip6_setpktopts(struct mbuf *, struct ip6_pktopts *,
	struct ip6_pktopts *, struct ucred *, int);
void	ip6_clearpktopts(struct ip6_pktopts *, int);
struct ip6_pktopts *ip6_copypktopts(struct ip6_pktopts *, int);
int	ip6_optlen(struct inpcb *);
int	ip6_deletefraghdr(struct mbuf *, int, int);
int	ip6_fragment(struct ifnet *, struct mbuf *, int, u_char, int,
			uint32_t);

int	route6_input(struct mbuf **, int *, int);

void	frag6_init(void);
void	frag6_destroy(void);
int	frag6_input(struct mbuf **, int *, int);
void	frag6_drain(void);

void	rip6_init(void);
int	rip6_ctloutput(struct socket *, struct sockopt *);
int	rip6_usrreq(struct socket *,
	    int, struct mbuf *, struct mbuf *, struct mbuf *, struct thread *);

int	dest6_input(struct mbuf **, int *, int);
int	none_input(struct mbuf **, int *, int);

int	in6_selectsrc_socket(struct sockaddr_in6 *, struct ip6_pktopts *,
    struct inpcb *, struct ucred *, int, struct in6_addr *, int *);
int	in6_selectsrc_addr(uint32_t, const struct in6_addr *,
    uint32_t, struct ifnet *, struct in6_addr *, int *);
int in6_selectroute(struct sockaddr_in6 *, struct ip6_pktopts *,
	struct ip6_moptions *, struct route_in6 *, struct ifnet **,
	struct nhop_object **, u_int, uint32_t);
u_int32_t ip6_randomid(void);
u_int32_t ip6_randomflowlabel(void);
void in6_delayed_cksum(struct mbuf *m, uint32_t plen, u_short offset);

int	ip6_log_ratelimit(void);

/*
 * Argument type for the last arg of ip6proto_ctlinput_t().
 *
 * IPv6 ICMP IPv6 [exthdrs] finalhdr payload
 * ^    ^    ^              ^
 * |    |    ip6c_ip6       ip6c_off
 * |    ip6c_icmp6
 * ip6c_m
 *
 * ip6c_finaldst's sin6_addr usually points to ip6c_ip6->ip6_dst.  If the
 * original * (internal) packet carries a routing header, it may point the
 * final * destination address in the routing header.
 *
 * ip6c_src: ip6c_ip6->ip6_src + scope info + flowlabel in ip6c_ip6
 *	(beware of flowlabel, if you try to compare it against others)
 * ip6c_dst: ip6c_finaldst + scope info
 */
struct ip6ctlparam {
	struct mbuf *ip6c_m;		/* start of mbuf chain */
	struct icmp6_hdr *ip6c_icmp6;	/* icmp6 header of target packet */
	struct ip6_hdr *ip6c_ip6;	/* ip6 header of target packet */
	int ip6c_off;			/* offset of the target proto header */
	struct sockaddr_in6 *ip6c_src;	/* srcaddr w/ additional info */
	struct sockaddr_in6 *ip6c_dst;	/* (final) dstaddr w/ additional info */
	struct sockaddr_in6 *ip6c_finaldst;	/* final destination address */
	void *ip6c_cmdarg;		/* control command dependent data */
	u_int8_t ip6c_nxt;		/* final next header field */
};

typedef int	ip6proto_input_t(struct mbuf **, int *, int);
typedef void	ip6proto_ctlinput_t(struct ip6ctlparam *);
int	ip6proto_register(uint8_t, ip6proto_input_t, ip6proto_ctlinput_t);
int	ip6proto_unregister(uint8_t);
#define	IP6PROTO_REGISTER(prot, input, ctl)	do {			\
	int error __diagused;						\
	error = ip6proto_register(prot, input, ctl);			\
	MPASS(error == 0);						\
} while (0)

ip6proto_input_t	rip6_input;
ip6proto_ctlinput_t	rip6_ctlinput;

#endif /* _KERNEL */

#endif /* !_NETINET6_IP6_VAR_H_ */