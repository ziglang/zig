/*	$NetBSD: ip_var.h,v 1.134 2022/04/10 09:50:46 andvar Exp $	*/

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
 *	@(#)ip_var.h	8.2 (Berkeley) 1/9/95
 */

#ifndef _NETINET_IP_VAR_H_
#define _NETINET_IP_VAR_H_

#include <sys/queue.h>
#include <net/route.h>

/*
 * Overlay for ip header used by other protocols (tcp, udp).
 */
struct ipovly {
	u_int8_t  ih_x1[9];		/* (unused) */
	u_int8_t  ih_pr;		/* protocol */
	u_int16_t ih_len;		/* protocol length */
	struct	  in_addr ih_src;	/* source internet address */
	struct	  in_addr ih_dst;	/* destination internet address */
};
#ifdef __CTASSERT
__CTASSERT(sizeof(struct ipovly) == 20);
#endif

/*
 * IP Flow structure
 */
struct ipflow {
	TAILQ_ENTRY(ipflow) ipf_list;	/* next in active list */
	TAILQ_ENTRY(ipflow) ipf_hash;	/* next ipflow in bucket */
	size_t ipf_hashidx;		/* own hash index of ipflowtable[] */
	struct in_addr ipf_dst;		/* destination address */
	struct in_addr ipf_src;		/* source address */
	uint8_t ipf_tos;		/* type-of-service */
	struct route ipf_ro;		/* associated route entry */
	u_long ipf_uses;		/* number of uses in this period */
	u_long ipf_last_uses;		/* number of uses in last period */
	u_long ipf_dropped;		/* ENOBUFS returned by if_output */
	u_long ipf_errors;		/* other errors returned by if_output */
	u_int ipf_timer;		/* lifetime timer */
};

/*
 * TCP sequence queue structure.
 */
TAILQ_HEAD(ipqehead, ipqent);
struct ipqent {
	TAILQ_ENTRY(ipqent) ipqe_q;
	struct mbuf *ipqe_m;
	TAILQ_ENTRY(ipqent) ipqe_timeq;
	u_int32_t ipqe_seq;
	u_int32_t ipqe_len;
	u_int32_t ipqe_flags;
};

/*
 * Structure stored in mbuf in inpcb.ip_options
 * and passed to ip_output when ip options are in use.
 * The actual length of the options (including ipopt_dst)
 * is in m_len.
 */
#define	MAX_IPOPTLEN	40

struct ipoption {
	struct	in_addr ipopt_dst;	/* first-hop dst if source routed */
	int8_t	ipopt_list[MAX_IPOPTLEN];	/* options proper */
};

/*
 * Structure attached to inpcb.ip_moptions and
 * passed to ip_output when IP multicast options are in use.
 */
struct ip_moptions {
	if_index_t imo_multicast_if_index; /* I/F for outgoing multicasts */
	struct in_addr imo_multicast_addr; /* ifindex/addr on MULTICAST_IF */
	u_int8_t  imo_multicast_ttl;	/* TTL for outgoing multicasts */
	u_int8_t  imo_multicast_loop;	/* 1 => hear sends if a member */
	u_int16_t imo_num_memberships;	/* no. memberships this socket */
	struct	  in_multi *imo_membership[IP_MAX_MEMBERSHIPS];
};

struct ip_pktopts {
	struct sockaddr_in ippo_laddr;	/* source address */
	struct ip_moptions *ippo_imo;	/* inp->inp_moptions or &ippo_imobuf */
	struct ip_moptions ippo_imobuf;	/* use when IP_PKTINFO */
};

/*
 * IP statistics.
 * Each counter is an unsigned 64-bit value.
 */
#define	IP_STAT_TOTAL		0	/* total packets received */
#define	IP_STAT_BADSUM		1	/* checksum bad */
#define	IP_STAT_TOOSHORT	2	/* packet too short */
#define	IP_STAT_TOOSMALL	3	/* not enough data */
#define	IP_STAT_BADHLEN		4	/* ip header length < data size */
#define	IP_STAT_BADLEN		5	/* ip length < ip header length */
#define	IP_STAT_FRAGMENTS	6	/* fragments received */
#define	IP_STAT_FRAGDROPPED	7	/* frags dropped (dups, out of space) */
#define	IP_STAT_FRAGTIMEOUT	8	/* fragments timed out */
#define	IP_STAT_FORWARD		9	/* packets forwarded */
#define	IP_STAT_FASTFORWARD	10	/* packets fast forwarded */
#define	IP_STAT_CANTFORWARD	11	/* packets rcvd for unreachable dest */
#define	IP_STAT_REDIRECTSENT	12	/* packets forwareded on same net */
#define	IP_STAT_NOPROTO		13	/* unknown or unsupported protocol */
#define	IP_STAT_DELIVERED	14	/* datagrams delivered to upper level */
#define	IP_STAT_LOCALOUT	15	/* total ip packets generated here */
#define	IP_STAT_ODROPPED	16	/* lost packets due to nobufs, etc. */
#define	IP_STAT_REASSEMBLED	17	/* total packets reassembled ok */
#define	IP_STAT_FRAGMENTED	18	/* datagrams successfully fragmented */
#define	IP_STAT_OFRAGMENTS	19	/* output fragments created */
#define	IP_STAT_CANTFRAG	20	/* don't fragment flag was set, etc. */
#define	IP_STAT_BADOPTIONS	21	/* error in option processing */
#define	IP_STAT_NOROUTE		22	/* packets discarded due to no route */
#define	IP_STAT_BADVERS		23	/* ip version != 4 */
#define	IP_STAT_RAWOUT		24	/* total raw ip packets generated */
#define	IP_STAT_BADFRAGS	25	/* malformed fragments (bad length) */
#define	IP_STAT_RCVMEMDROP	26	/* frags dropped for lack of memory */
#define	IP_STAT_TOOLONG		27	/* ip length > max ip packet size */
#define	IP_STAT_NOGIF		28	/* no match gif found */
#define	IP_STAT_BADADDR		29	/* invalid address on header */
#define	IP_STAT_NOL2TP		30	/* no match l2tp found */
#define	IP_STAT_NOIPSEC		31	/* no match ipsec(4) found */
#define	IP_STAT_PFILDROP_IN	32	/* dropped by pfil (PFIL_IN) */
#define	IP_STAT_PFILDROP_OUT	33	/* dropped by pfil (PFIL_OUT) */
#define	IP_STAT_IPSECDROP_IN	34	/* dropped by IPsec SP check */
#define	IP_STAT_IPSECDROP_OUT	35	/* dropped by IPsec SP check */
#define	IP_STAT_IFDROP		36	/* dropped due to interface state */
#define	IP_STAT_TIMXCEED	37	/* time to live exceeded */
#define	IP_STAT_IFNOADDR	38	/* interface has no IP address */
#define	IP_STAT_RTREJECT	39	/* rejected by route */
#define	IP_STAT_BCASTDENIED	40	/* broadcast prohibited */

#define	IP_NSTATS		41

#ifdef _KERNEL

#ifdef _KERNEL_OPT
#include "opt_gateway.h"
#include "opt_mbuftrace.h"
#endif

/*
 * The following flags can be passed to ip_output() as last parameter
 */
#define	IP_FORWARDING		0x0001		/* most of ip header exists */
#define	IP_RAWOUTPUT		0x0002		/* raw ip header exists */
#define	IP_RETURNMTU		0x0004		/* pass back mtu on EMSGSIZE */
#define	IP_NOIPNEWID		0x0008		/* don't fill in ip_id */
__CTASSERT(SO_DONTROUTE ==	0x0010);
__CTASSERT(SO_BROADCAST ==	0x0020);
#define	IP_ROUTETOIF		SO_DONTROUTE	/* bypass routing tables */
#define	IP_ALLOWBROADCAST	SO_BROADCAST	/* can send broadcast packets */

#define	IP_IGMP_MCAST		0x0040		/* IGMP for mcast join/leave */
#define	IP_MTUDISC		0x0400		/* Path MTU Discovery; set DF */
#define	IP_ROUTETOIFINDEX	0x0800	/* force route imo_multicast_if_index */

extern struct domain inetdomain;
extern const struct pr_usrreqs rip_usrreqs;

extern int   ip_defttl;			/* default IP ttl */
extern int   ipforwarding;		/* ip forwarding */
extern int   ip_mtudisc;		/* mtu discovery */
extern int   ip_mtudisc_timeout;	/* seconds to timeout mtu discovery */
extern int   anonportmin;		/* minimum ephemeral port */
extern int   anonportmax;		/* maximum ephemeral port */
extern int   lowportmin;		/* minimum reserved port */
extern int   lowportmax;		/* maximum reserved port */
extern int   ip_do_loopback_cksum;	/* do IP checksum on loopback? */
extern struct rttimer_queue *ip_mtudisc_timeout_q;
#ifdef MBUFTRACE
extern struct mowner ip_rx_mowner;
extern struct mowner ip_tx_mowner;
#endif
struct	 inpcb;
struct   sockopt;

void	ip_init(void);
void	in_init(void);

int	 ip_ctloutput(int, struct socket *, struct sockopt *);
int	 ip_setpktopts(struct mbuf *, struct ip_pktopts *, int *,
	    struct inpcb *, kauth_cred_t);
void	 ip_drain(void);
void	 ip_drainstub(void);
void	 ip_freemoptions(struct ip_moptions *);
int	 ip_optcopy(struct ip *, struct ip *);
u_int	 ip_optlen(struct inpcb *);
int	 ip_output(struct mbuf *, struct mbuf *, struct route *, int,
	    struct ip_moptions *, struct inpcb *);
int	 ip_fragment(struct mbuf *, struct ifnet *, u_long);

void	 ip_reass_init(void);
int	 ip_reass_packet(struct mbuf **);
void	 ip_reass_slowtimo(void);
void	 ip_reass_drain(void);

void	 ip_savecontrol(struct inpcb *, struct mbuf **, struct ip *,
	   struct mbuf *);
void	 ip_slowtimo(void);
void	 ip_fasttimo(void);
struct mbuf *
	 ip_srcroute(struct mbuf *);
int	 ip_sysctl(int *, u_int, void *, size_t *, void *, size_t);
void	 ip_statinc(u_int);
void *	 rip_ctlinput(int, const struct sockaddr *, void *);
int	 rip_ctloutput(int, struct socket *, struct sockopt *);
void	 rip_init(void);
void	 rip_input(struct mbuf *, int, int);
int	 rip_output(struct mbuf *, struct inpcb *, struct mbuf *, struct lwp *);
int	 rip_usrreq(struct socket *,
	    int, struct mbuf *, struct mbuf *, struct mbuf *, struct lwp *);

int	ip_setmoptions(struct ip_moptions **, const struct sockopt *sopt);
int	ip_getmoptions(struct ip_moptions *, struct sockopt *sopt);

int	ip_if_output(struct ifnet * const, struct mbuf * const,
	    const struct sockaddr * const, const struct rtentry *);

/* IP Flow interface. */
void	ipflow_init(void);
void	ipflow_poolinit(void);
void	ipflow_create(struct route *, struct mbuf *);
void	ipflow_slowtimo(void);
int	ipflow_invalidate_all(int);

#endif  /* _KERNEL */

#endif /* !_NETINET_IP_VAR_H_ */