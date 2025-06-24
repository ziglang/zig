/*	$NetBSD: in_pcb.h,v 1.76 2022/11/04 09:03:20 ozaki-r Exp $	*/

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
 * Copyright (c) 1982, 1986, 1990, 1993
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
 *	@(#)in_pcb.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NETINET_IN_PCB_H_
#define _NETINET_IN_PCB_H_

#include <sys/types.h>

#include <net/route.h>

#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/ip6.h>

typedef int (*pcb_overudp_cb_t)(struct mbuf **, int, struct socket *,
    struct sockaddr *, void *);

struct ip_moptions;
struct mbuf;
struct icmp6_filter;

/*
 * Common structure pcb for internet protocol implementation.
 * Here are stored pointers to local and foreign host table
 * entries, local and foreign socket numbers, and pointers
 * up (to a socket structure) and down (to a protocol-specific)
 * control block.
 */

struct inpcb {
	LIST_ENTRY(inpcb) inp_hash;
	LIST_ENTRY(inpcb) inp_lhash;
	TAILQ_ENTRY(inpcb) inp_queue;
	int	  inp_af;		/* address family - AF_INET or AF_INET6 */
	void *	  inp_ppcb;		/* pointer to per-protocol pcb */
	int	  inp_state;		/* bind/connect state */
#define	INP_ATTACHED		0
#define	INP_BOUND		1
#define	INP_CONNECTED		2
	int       inp_portalgo;
	struct	  socket *inp_socket;	/* back pointer to socket */
	struct	  inpcbtable *inp_table;
	struct	  inpcbpolicy *inp_sp;	/* security policy */
	struct route	inp_route;	/* placeholder for routing entry */
	in_port_t	inp_fport;	/* foreign port */
	in_port_t	inp_lport;	/* local port */
	int	 	inp_flags;	/* generic IP/datagram flags */
	struct mbuf	*inp_options;	/* IP options */
	bool		inp_bindportonsend;

	/* We still need it for IPv6 due to v4-mapped addresses */
	struct ip_moptions *inp_moptions;	/* IPv4 multicast options */

	pcb_overudp_cb_t	inp_overudp_cb;
	void		*inp_overudp_arg;
};

struct in4pcb {
	struct inpcb	in4p_pcb;
	struct ip	in4p_ip;
	int		in4p_errormtu;	/* MTU of last xmit status = EMSGSIZE */
	uint8_t		in4p_ip_minttl;
	struct in_addr	in4p_prefsrcip; /* preferred src IP when wild  */
};

#define in4p_faddr(inpcb)	(((struct in4pcb *)(inpcb))->in4p_ip.ip_dst)
#define in4p_laddr(inpcb)	(((struct in4pcb *)(inpcb))->in4p_ip.ip_src)
#define const_in4p_faddr(inpcb)	(((const struct in4pcb *)(inpcb))->in4p_ip.ip_dst)
#define const_in4p_laddr(inpcb)	(((const struct in4pcb *)(inpcb))->in4p_ip.ip_src)
#define in4p_ip(inpcb)		(((struct in4pcb *)(inpcb))->in4p_ip)
#define in4p_errormtu(inpcb)	(((struct in4pcb *)(inpcb))->in4p_errormtu)
#define in4p_ip_minttl(inpcb)	(((struct in4pcb *)(inpcb))->in4p_ip_minttl)
#define in4p_prefsrcip(inpcb)	(((struct in4pcb *)(inpcb))->in4p_prefsrcip)

struct in6pcb {
	struct inpcb	in6p_pcb;
	struct ip6_hdr	in6p_ip6;
	int		in6p_hops;	/* default IPv6 hop limit */
	int		in6p_cksum;	/* IPV6_CHECKSUM setsockopt */
	struct icmp6_filter	*in6p_icmp6filt;
	struct ip6_pktopts	*in6p_outputopts; /* IP6 options for outgoing packets */
	struct ip6_moptions *in6p_moptions;	/* IPv6 multicast options */
};

#define in6p_faddr(inpcb)	(((struct in6pcb *)(inpcb))->in6p_ip6.ip6_dst)
#define in6p_laddr(inpcb)	(((struct in6pcb *)(inpcb))->in6p_ip6.ip6_src)
#define const_in6p_faddr(inpcb)	(((const struct in6pcb *)(inpcb))->in6p_ip6.ip6_dst)
#define const_in6p_laddr(inpcb)	(((const struct in6pcb *)(inpcb))->in6p_ip6.ip6_src)
#define in6p_ip6(inpcb)		(((struct in6pcb *)(inpcb))->in6p_ip6)
#define in6p_flowinfo(inpcb)	(((struct in6pcb *)(inpcb))->in6p_ip6.ip6_flow)
#define const_in6p_flowinfo(inpcb)	(((const struct in6pcb *)(inpcb))->in6p_ip6.ip6_flow)
#define in6p_hops6(inpcb)	(((struct in6pcb *)(inpcb))->in6p_hops)
#define in6p_cksum(inpcb)	(((struct in6pcb *)(inpcb))->in6p_cksum)
#define in6p_icmp6filt(inpcb)	(((struct in6pcb *)(inpcb))->in6p_icmp6filt)
#define in6p_outputopts(inpcb)	(((struct in6pcb *)(inpcb))->in6p_outputopts)
#define in6p_moptions(inpcb)	(((struct in6pcb *)(inpcb))->in6p_moptions)

LIST_HEAD(inpcbhead, inpcb);

/* flags in inp_flags: */
#define	INP_RECVOPTS		0x0001	/* receive incoming IP options */
#define	INP_RECVRETOPTS		0x0002	/* receive IP options for reply */
#define	INP_RECVDSTADDR		0x0004	/* receive IP dst address */
#define	INP_HDRINCL		0x0008	/* user supplies entire IP header */
#define	INP_HIGHPORT		0x0010	/* (unused; FreeBSD compat) */
#define	INP_LOWPORT		0x0020	/* user wants "low" port binding */
#define	INP_ANONPORT		0x0040	/* port chosen for user */
#define	INP_RECVIF		0x0080	/* receive incoming interface */
/* XXX should move to an UDP control block */
#define INP_ESPINUDP		0x0100	/* ESP over UDP for NAT-T */
#define INP_ESPINUDP_NON_IKE	0x0200	/* ESP over UDP for NAT-T */
#define INP_NOHEADER		0x0400	/* Kernel removes IP header
					 * before feeding a packet
					 * to the raw socket user.
					 * The socket user will
					 * not supply an IP header.
					 * Cancels INP_HDRINCL.
					 */
#define	INP_RECVTTL		0x0800	/* receive incoming IP TTL */
#define	INP_RECVPKTINFO		0x1000	/* receive IP dst if/addr */
#define	INP_BINDANY		0x2000	/* allow bind to any address */
#define	INP_CONTROLOPTS		(INP_RECVOPTS|INP_RECVRETOPTS|INP_RECVDSTADDR|\
				INP_RECVIF|INP_RECVTTL|INP_RECVPKTINFO)

/*
 * Flags for IPv6 in inp_flags
 * We define KAME's original flags in higher 16 bits as much as possible
 * for compatibility with *bsd*s.
 */
#define IN6P_RECVOPTS		0x00001000 /* receive incoming IP6 options */
#define IN6P_RECVRETOPTS	0x00002000 /* receive IP6 options for reply */
#define IN6P_RECVDSTADDR	0x00004000 /* receive IP6 dst address */
#define IN6P_IPV6_V6ONLY	0x00008000 /* restrict AF_INET6 socket for v6 */
#define IN6P_PKTINFO		0x00010000 /* receive IP6 dst and I/F */
#define IN6P_HOPLIMIT		0x00020000 /* receive hoplimit */
#define IN6P_HOPOPTS		0x00040000 /* receive hop-by-hop options */
#define IN6P_DSTOPTS		0x00080000 /* receive dst options after rthdr */
#define IN6P_RTHDR		0x00100000 /* receive routing header */
#define IN6P_RTHDRDSTOPTS	0x00200000 /* receive dstoptions before rthdr */
#define IN6P_TCLASS		0x00400000 /* traffic class */
#define IN6P_BINDANY		0x00800000 /* allow bind to any address */
#define IN6P_HIGHPORT		0x01000000 /* user wants "high" port binding */
#define IN6P_LOWPORT		0x02000000 /* user wants "low" port binding */
#define IN6P_ANONPORT		0x04000000 /* port chosen for user */
#define IN6P_FAITH		0x08000000 /* accept FAITH'ed connections */
/* XXX should move to an UDP control block */
#define IN6P_ESPINUDP		INP_ESPINUDP /* ESP over UDP for NAT-T */

#define IN6P_RFC2292		0x40000000 /* RFC2292 */
#define IN6P_MTU		0x80000000 /* use minimum MTU */

#define IN6P_CONTROLOPTS	(IN6P_PKTINFO|IN6P_HOPLIMIT|IN6P_HOPOPTS|\
				 IN6P_DSTOPTS|IN6P_RTHDR|IN6P_RTHDRDSTOPTS|\
				 IN6P_TCLASS|IN6P_RFC2292|\
				 IN6P_MTU)

#define	sotoinpcb(so)		((struct inpcb *)(so)->so_pcb)
#define soaf(so) 		(so->so_proto->pr_domain->dom_family)
#define	inp_lock(inp)		solock((inp)->inp_socket)
#define	inp_unlock(inp)		sounlock((inp)->inp_socket)
#define	inp_locked(inp)		solocked((inp)->inp_socket)

TAILQ_HEAD(inpcbqueue, inpcb);

struct vestigial_hooks;

/* It's still referenced by kvm users */
struct inpcbtable {
	struct	  inpcbqueue inpt_queue;
	struct	  inpcbhead *inpt_porthashtbl;
	struct	  inpcbhead *inpt_bindhashtbl;
	struct	  inpcbhead *inpt_connecthashtbl;
	u_long	  inpt_porthash;
	u_long	  inpt_bindhash;
	u_long	  inpt_connecthash;
	in_port_t inpt_lastport;
	in_port_t inpt_lastlow;

	struct vestigial_hooks *vestige;
};
#define inpt_lasthi inpt_lastport

#ifdef _KERNEL

#include <sys/kauth.h>
#include <sys/queue.h>

struct lwp;
struct rtentry;
struct sockaddr_in;
struct socket;
struct vestigial_inpcb;

void	inpcb_losing(struct inpcb *);
int	inpcb_create(struct socket *, void *);
int	inpcb_bindableaddr(const struct inpcb *, struct sockaddr_in *,
    kauth_cred_t);
int	inpcb_bind(void *, struct sockaddr_in *, struct lwp *);
int	inpcb_connect(void *, struct sockaddr_in *, struct lwp *);
void	inpcb_destroy(void *);
void	inpcb_disconnect(void *);
void	inpcb_init(struct inpcbtable *, int, int);
struct inpcb *
	inpcb_lookup_local(struct inpcbtable *,
			  struct in_addr, u_int, int, struct vestigial_inpcb *);
struct inpcb *
	inpcb_lookup_bound(struct inpcbtable *,
	    struct in_addr, u_int);
struct inpcb *
	inpcb_lookup(struct inpcbtable *,
			     struct in_addr, u_int, struct in_addr, u_int,
			     struct vestigial_inpcb *);
int	inpcb_notify(struct inpcbtable *, struct in_addr, u_int,
	    struct in_addr, u_int, int, void (*)(struct inpcb *, int));
void	inpcb_notifyall(struct inpcbtable *, struct in_addr, int,
	    void (*)(struct inpcb *, int));
void	inpcb_purgeif0(struct inpcbtable *, struct ifnet *);
void	inpcb_purgeif(struct inpcbtable *, struct ifnet *);
void	in_purgeifmcast(struct ip_moptions *, struct ifnet *);
void	inpcb_set_state(struct inpcb *, int);
void	inpcb_rtchange(struct inpcb *, int);
void	inpcb_fetch_peeraddr(struct inpcb *, struct sockaddr_in *);
void	inpcb_fetch_sockaddr(struct inpcb *, struct sockaddr_in *);
struct rtentry *
	inpcb_rtentry(struct inpcb *);
void	inpcb_rtentry_unref(struct rtentry *, struct inpcb *);

void	in6pcb_init(struct inpcbtable *, int, int);
int	in6pcb_bind(void *, struct sockaddr_in6 *, struct lwp *);
int	in6pcb_connect(void *, struct sockaddr_in6 *, struct lwp *);
void	in6pcb_destroy(struct inpcb *);
void	in6pcb_disconnect(struct inpcb *);
struct	inpcb *in6pcb_lookup_local(struct inpcbtable *, struct in6_addr *,
				   u_int, int, struct vestigial_inpcb *);
int	in6pcb_notify(struct inpcbtable *, const struct sockaddr *,
	u_int, const struct sockaddr *, u_int, int, void *,
	void (*)(struct inpcb *, int));
void	in6pcb_purgeif0(struct inpcbtable *, struct ifnet *);
void	in6pcb_purgeif(struct inpcbtable *, struct ifnet *);
void	in6pcb_set_state(struct inpcb *, int);
void	in6pcb_rtchange(struct inpcb *, int);
void	in6pcb_fetch_peeraddr(struct inpcb *, struct sockaddr_in6 *);
void	in6pcb_fetch_sockaddr(struct inpcb *, struct sockaddr_in6 *);

/* in in6_src.c */
int	in6pcb_selecthlim(struct inpcb *, struct ifnet *);
int	in6pcb_selecthlim_rt(struct inpcb *);
int	in6pcb_set_port(struct sockaddr_in6 *, struct inpcb *, struct lwp *);

extern struct rtentry *
	in6pcb_rtentry(struct inpcb *);
extern void
	in6pcb_rtentry_unref(struct rtentry *, struct inpcb *);
extern struct inpcb *in6pcb_lookup(struct inpcbtable *,
					    const struct in6_addr *, u_int, const struct in6_addr *, u_int, int,
					    struct vestigial_inpcb *);
extern struct inpcb *in6pcb_lookup_bound(struct inpcbtable *,
	const struct in6_addr *, u_int, int);

static inline void
inpcb_register_overudp_cb(struct inpcb *inp, pcb_overudp_cb_t cb, void *arg)
{

	inp->inp_overudp_cb = cb;
	inp->inp_overudp_arg = arg;
}

/* compute hash value for foreign and local in6_addr and port */
#define IN6_HASH(faddr, fport, laddr, lport) 			\
	(((faddr)->s6_addr32[0] ^ (faddr)->s6_addr32[1] ^	\
	  (faddr)->s6_addr32[2] ^ (faddr)->s6_addr32[3] ^	\
	  (laddr)->s6_addr32[0] ^ (laddr)->s6_addr32[1] ^	\
	  (laddr)->s6_addr32[2] ^ (laddr)->s6_addr32[3])	\
	 + (fport) + (lport))

// from in_pcb_hdr.h
struct vestigial_inpcb;
struct in6_addr;

/* Hooks for vestigial pcb entries.
 * If vestigial entries exist for a table (TCP only)
 * the vestigial pointer is set.
 */
typedef struct vestigial_hooks {
	/* IPv4 hooks */
	void	*(*init_ports4)(struct in_addr, u_int, int);
	int	(*next_port4)(void *, struct vestigial_inpcb *);
	int	(*lookup4)(struct in_addr, uint16_t,
			   struct in_addr, uint16_t,
			   struct vestigial_inpcb *);
	/* IPv6 hooks */
	void	*(*init_ports6)(const struct in6_addr*, u_int, int);
	int	(*next_port6)(void *, struct vestigial_inpcb *);
	int	(*lookup6)(const struct in6_addr *, uint16_t,
			   const struct in6_addr *, uint16_t,
			   struct vestigial_inpcb *);
} vestigial_hooks_t;

#endif	/* _KERNEL */

#endif	/* !_NETINET_IN_PCB_H_ */