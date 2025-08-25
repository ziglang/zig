/*	$NetBSD: in6_var.h,v 1.104 2020/06/16 17:12:18 maxv Exp $	*/
/*	$KAME: in6_var.h,v 1.81 2002/06/08 11:16:51 itojun Exp $	*/

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
 * Copyright (c) 1985, 1986, 1993
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
 *	@(#)in_var.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NETINET6_IN6_VAR_H_
#define _NETINET6_IN6_VAR_H_

#include <sys/callout.h>
#include <sys/ioccom.h>

/*
 * Interface address, Internet version.  One of these structures
 * is allocated for each interface with an Internet address.
 * The ifaddr structure contains the protocol-independent part
 * of the structure and is assumed to be first.
 */

/*
 * pltime/vltime are just for future reference (required to implements 2
 * hour rule for hosts).  they should never be modified by nd6_timeout or
 * anywhere else.
 *	userland -> kernel: accept pltime/vltime
 *	kernel -> userland: throw up everything
 *	in kernel: modify preferred/expire only
 */
struct in6_addrlifetime {
	time_t ia6t_expire;	/* valid lifetime expiration time */
	time_t ia6t_preferred;	/* preferred lifetime expiration time */
	u_int32_t ia6t_vltime;	/* valid lifetime */
	u_int32_t ia6t_pltime;	/* prefix lifetime */
};

struct lltable;
struct nd_kifinfo;
struct in6_ifextra {
	struct in6_ifstat *in6_ifstat;
	struct icmp6_ifstat *icmp6_ifstat;
	struct nd_kifinfo *nd_ifinfo;
	struct scope6_id *scope6_id;
	struct lltable *lltable;
};

LIST_HEAD(in6_multihead, in6_multi);
struct	in6_ifaddr {
	struct	ifaddr ia_ifa;		/* protocol-independent info */
#define	ia_ifp		ia_ifa.ifa_ifp
#define ia_flags	ia_ifa.ifa_flags
	struct	sockaddr_in6 ia_addr;	/* interface address */
	struct	sockaddr_in6 ia_net;	/* network number of interface */
	struct	sockaddr_in6 ia_dstaddr; /* space for destination addr */
	struct	sockaddr_in6 ia_prefixmask; /* prefix mask */
	u_int32_t ia_plen;		/* prefix length */
	/* DEPRECATED. Keep it to avoid breaking kvm(3) users */
	struct	in6_ifaddr *ia_next;	/* next in6 list of IP6 addresses */
	/* DEPRECATED. Keep it to avoid breaking kvm(3) users */
	struct	in6_multihead _ia6_multiaddrs;
					/* list of multicast addresses */
	int	ia6_flags;

	struct in6_addrlifetime ia6_lifetime;
	time_t	ia6_createtime; /* the creation time of this address, which is
				 * currently used for temporary addresses only.
				 */
	time_t	ia6_updatetime;

	/* multicast addresses joined from the kernel */
	LIST_HEAD(, in6_multi_mship) ia6_memberships;

#ifdef _KERNEL
	struct pslist_entry	ia6_pslist_entry;
#endif
};

#ifdef _KERNEL
static __inline void
ia6_acquire(struct in6_ifaddr *ia, struct psref *psref)
{

	KASSERT(ia != NULL);
	ifa_acquire(&ia->ia_ifa, psref);
}

static __inline void
ia6_release(struct in6_ifaddr *ia, struct psref *psref)
{

	if (ia == NULL)
		return;
	ifa_release(&ia->ia_ifa, psref);
}
#endif

/* control structure to manage address selection policy */
struct in6_addrpolicy {
	struct sockaddr_in6 addr; /* prefix address */
	struct sockaddr_in6 addrmask; /* prefix mask */
	int preced;		/* precedence */
	int label;		/* matching label */
	u_quad_t use;		/* statistics */
};

/*
 * IPv6 interface statistics, as defined in RFC2465 Ipv6IfStatsEntry (p12).
 */
struct in6_ifstat {
	u_quad_t ifs6_in_receive;	/* # of total input datagram */
	u_quad_t ifs6_in_hdrerr;	/* # of datagrams with invalid hdr */
	u_quad_t ifs6_in_toobig;	/* # of datagrams exceeded MTU */
	u_quad_t ifs6_in_noroute;	/* # of datagrams with no route */
	u_quad_t ifs6_in_addrerr;	/* # of datagrams with invalid dst */
	u_quad_t ifs6_in_protounknown;	/* # of datagrams with unknown proto */
					/* NOTE: increment on final dst if */
	u_quad_t ifs6_in_truncated;	/* # of truncated datagrams */
	u_quad_t ifs6_in_discard;	/* # of discarded datagrams */
					/* NOTE: fragment timeout is not here */
	u_quad_t ifs6_in_deliver;	/* # of datagrams delivered to ULP */
					/* NOTE: increment on final dst if */
	u_quad_t ifs6_out_forward;	/* # of datagrams forwarded */
					/* NOTE: increment on outgoing if */
	u_quad_t ifs6_out_request;	/* # of outgoing datagrams from ULP */
					/* NOTE: does not include forwrads */
	u_quad_t ifs6_out_discard;	/* # of discarded datagrams */
	u_quad_t ifs6_out_fragok;	/* # of datagrams fragmented */
	u_quad_t ifs6_out_fragfail;	/* # of datagrams failed on fragment */
	u_quad_t ifs6_out_fragcreat;	/* # of fragment datagrams */
					/* NOTE: this is # after fragment */
	u_quad_t ifs6_reass_reqd;	/* # of incoming fragmented packets */
					/* NOTE: increment on final dst if */
	u_quad_t ifs6_reass_ok;		/* # of reassembled packets */
					/* NOTE: this is # after reass */
					/* NOTE: increment on final dst if */
	u_quad_t ifs6_reass_fail;	/* # of reass failures */
					/* NOTE: may not be packet count */
					/* NOTE: increment on final dst if */
	u_quad_t ifs6_in_mcast;		/* # of inbound multicast datagrams */
	u_quad_t ifs6_out_mcast;	/* # of outbound multicast datagrams */
};

/*
 * ICMPv6 interface statistics, as defined in RFC2466 Ipv6IfIcmpEntry.
 * XXX: I'm not sure if this file is the right place for this structure...
 */
struct icmp6_ifstat {
	/*
	 * Input statistics
	 */
	/* ipv6IfIcmpInMsgs, total # of input messages */
	u_quad_t ifs6_in_msg;
	/* ipv6IfIcmpInErrors, # of input error messages */
	u_quad_t ifs6_in_error;
	/* ipv6IfIcmpInDestUnreachs, # of input dest unreach errors */
	u_quad_t ifs6_in_dstunreach;
	/* ipv6IfIcmpInAdminProhibs, # of input administratively prohibited errs */
	u_quad_t ifs6_in_adminprohib;
	/* ipv6IfIcmpInTimeExcds, # of input time exceeded errors */
	u_quad_t ifs6_in_timeexceed;
	/* ipv6IfIcmpInParmProblems, # of input parameter problem errors */
	u_quad_t ifs6_in_paramprob;
	/* ipv6IfIcmpInPktTooBigs, # of input packet too big errors */
	u_quad_t ifs6_in_pkttoobig;
	/* ipv6IfIcmpInEchos, # of input echo requests */
	u_quad_t ifs6_in_echo;
	/* ipv6IfIcmpInEchoReplies, # of input echo replies */
	u_quad_t ifs6_in_echoreply;
	/* ipv6IfIcmpInRouterSolicits, # of input router solicitations */
	u_quad_t ifs6_in_routersolicit;
	/* ipv6IfIcmpInRouterAdvertisements, # of input router advertisements */
	u_quad_t ifs6_in_routeradvert;
	/* ipv6IfIcmpInNeighborSolicits, # of input neighbor solicitations */
	u_quad_t ifs6_in_neighborsolicit;
	/* ipv6IfIcmpInNeighborAdvertisements, # of input neighbor advertisements */
	u_quad_t ifs6_in_neighboradvert;
	/* ipv6IfIcmpInRedirects, # of input redirects */
	u_quad_t ifs6_in_redirect;
	/* ipv6IfIcmpInGroupMembQueries, # of input MLD queries */
	u_quad_t ifs6_in_mldquery;
	/* ipv6IfIcmpInGroupMembResponses, # of input MLD reports */
	u_quad_t ifs6_in_mldreport;
	/* ipv6IfIcmpInGroupMembReductions, # of input MLD done */
	u_quad_t ifs6_in_mlddone;

	/*
	 * Output statistics. We should solve unresolved routing problem...
	 */
	/* ipv6IfIcmpOutMsgs, total # of output messages */
	u_quad_t ifs6_out_msg;
	/* ipv6IfIcmpOutErrors, # of output error messages */
	u_quad_t ifs6_out_error;
	/* ipv6IfIcmpOutDestUnreachs, # of output dest unreach errors */
	u_quad_t ifs6_out_dstunreach;
	/* ipv6IfIcmpOutAdminProhibs, # of output administratively prohibited errs */
	u_quad_t ifs6_out_adminprohib;
	/* ipv6IfIcmpOutTimeExcds, # of output time exceeded errors */
	u_quad_t ifs6_out_timeexceed;
	/* ipv6IfIcmpOutParmProblems, # of output parameter problem errors */
	u_quad_t ifs6_out_paramprob;
	/* ipv6IfIcmpOutPktTooBigs, # of output packet too big errors */
	u_quad_t ifs6_out_pkttoobig;
	/* ipv6IfIcmpOutEchos, # of output echo requests */
	u_quad_t ifs6_out_echo;
	/* ipv6IfIcmpOutEchoReplies, # of output echo replies */
	u_quad_t ifs6_out_echoreply;
	/* ipv6IfIcmpOutRouterSolicits, # of output router solicitations */
	u_quad_t ifs6_out_routersolicit;
	/* ipv6IfIcmpOutRouterAdvertisements, # of output router advertisements */
	u_quad_t ifs6_out_routeradvert;
	/* ipv6IfIcmpOutNeighborSolicits, # of output neighbor solicitations */
	u_quad_t ifs6_out_neighborsolicit;
	/* ipv6IfIcmpOutNeighborAdvertisements, # of output neighbor advertisements */
	u_quad_t ifs6_out_neighboradvert;
	/* ipv6IfIcmpOutRedirects, # of output redirects */
	u_quad_t ifs6_out_redirect;
	/* ipv6IfIcmpOutGroupMembQueries, # of output MLD queries */
	u_quad_t ifs6_out_mldquery;
	/* ipv6IfIcmpOutGroupMembResponses, # of output MLD reports */
	u_quad_t ifs6_out_mldreport;
	/* ipv6IfIcmpOutGroupMembReductions, # of output MLD done */
	u_quad_t ifs6_out_mlddone;
};

/*
 * If you make changes that change the size of in6_ifreq,
 * make sure you fix compat/netinet6/in6_var.h
 */
struct	in6_ifreq {
	char	ifr_name[IFNAMSIZ];
	union {
		struct	sockaddr_in6 ifru_addr;
		struct	sockaddr_in6 ifru_dstaddr;
		short	ifru_flags;
		int	ifru_flags6;
		int	ifru_metric;
		void *	ifru_data;
		struct in6_addrlifetime ifru_lifetime;
		struct in6_ifstat ifru_stat;
		struct icmp6_ifstat ifru_icmp6stat;
	} ifr_ifru;
};

struct	in6_aliasreq {
	char	ifra_name[IFNAMSIZ];
	struct	sockaddr_in6 ifra_addr;
	struct	sockaddr_in6 ifra_dstaddr;
	struct	sockaddr_in6 ifra_prefixmask;
	int	ifra_flags;
	struct in6_addrlifetime ifra_lifetime;
};

/*
 * Given a pointer to an in6_ifaddr (ifaddr),
 * return a pointer to the addr as a sockaddr_in6
 */
#define IA6_IN6(ia)	(&((ia)->ia_addr.sin6_addr))
#define IA6_DSTIN6(ia)	(&((ia)->ia_dstaddr.sin6_addr))
#define IA6_MASKIN6(ia)	(&((ia)->ia_prefixmask.sin6_addr))
#define IA6_SIN6(ia)	(&((ia)->ia_addr))
#define IA6_DSTSIN6(ia)	(&((ia)->ia_dstaddr))
#define IFA_IN6(x)	(&((struct sockaddr_in6 *)((x)->ifa_addr))->sin6_addr)
#define IFA_DSTIN6(x)	(&((struct sockaddr_in6 *)((x)->ifa_dstaddr))->sin6_addr)

#ifdef _KERNEL
#define IN6_ARE_MASKED_ADDR_EQUAL(d, a, m)	(	\
	(((d)->s6_addr32[0] ^ (a)->s6_addr32[0]) & (m)->s6_addr32[0]) == 0 && \
	(((d)->s6_addr32[1] ^ (a)->s6_addr32[1]) & (m)->s6_addr32[1]) == 0 && \
	(((d)->s6_addr32[2] ^ (a)->s6_addr32[2]) & (m)->s6_addr32[2]) == 0 && \
	(((d)->s6_addr32[3] ^ (a)->s6_addr32[3]) & (m)->s6_addr32[3]) == 0 )
#endif

#define SIOCSIFADDR_IN6		 _IOW('i', 12, struct in6_ifreq)
#define SIOCGIFADDR_IN6		_IOWR('i', 33, struct in6_ifreq)

#ifdef _KERNEL
/*
 * SIOCSxxx ioctls should be unused (see comments in in6.c), but
 * we do not shift numbers for binary compatibility.
 */
#define SIOCSIFDSTADDR_IN6	 _IOW('i', 14, struct in6_ifreq)
#define SIOCSIFNETMASK_IN6	 _IOW('i', 22, struct in6_ifreq)
#endif

#define SIOCGIFDSTADDR_IN6	_IOWR('i', 34, struct in6_ifreq)
#define SIOCGIFNETMASK_IN6	_IOWR('i', 37, struct in6_ifreq)

#define SIOCDIFADDR_IN6		 _IOW('i', 25, struct in6_ifreq)
/* 26 was OSIOCAIFADDR_IN6 */

/* 70 was OSIOCSIFPHYADDR_IN6 */
#define	SIOCGIFPSRCADDR_IN6	_IOWR('i', 71, struct in6_ifreq)
#define	SIOCGIFPDSTADDR_IN6	_IOWR('i', 72, struct in6_ifreq)

#define SIOCGIFAFLAG_IN6	_IOWR('i', 73, struct in6_ifreq)

/*
 * 74 was SIOCGDRLST_IN6
 * 75 was SIOCGPRLST_IN6
 * 76 was OSIOCGIFINFO_IN6
 * 77 was SIOCSNDFLUSH_IN6
 */
#define SIOCGNBRINFO_IN6	_IOWR('i', 78, struct in6_nbrinfo)
/*
 * 79 was SIOCSPFXFLUSH_IN6
 * 80 was SIOCSRTRFLUSH_IN6
 * 81 was SIOCGIFALIFETIME_IN6
 */
#if 0
/* withdrawn - do not reuse number 82 */
#define SIOCSIFALIFETIME_IN6	_IOWR('i', 82, struct in6_ifreq)
#endif
#define SIOCGIFSTAT_IN6		_IOWR('i', 83, struct in6_ifreq)
#define SIOCGIFSTAT_ICMP6	_IOWR('i', 84, struct in6_ifreq)

/*
 * 85 was SIOCSDEFIFACE_IN6
 * 86 was SIOCGDEFIFACE_IN6
 * 87 was OSIOCSIFINFO_FLAGS
 * 100 was SIOCSIFPREFIX_IN6
 * 101 was SIOCGIFPREFIX_IN6
 * 102 was SIOCDIFPREFIX_IN6
 * 103 was SIOCAIFPREFIX_IN6
 * 104 was SIOCCIFPREFIX_IN6
 * 105 was SIOCSGIFPREFIX_IN6
 */
#define SIOCGIFALIFETIME_IN6	_IOWR('i', 106, struct in6_ifreq)
#define SIOCAIFADDR_IN6		_IOW('i', 107, struct in6_aliasreq)
/* 108 was OSIOCGIFINFO_IN6_90
 * 109 was OSIOCSIFINFO_IN6_90 */
#define SIOCSIFPHYADDR_IN6      _IOW('i', 110, struct in6_aliasreq)
/* 110 - 112 are defined in net/if_pppoe.h */
#define SIOCGIFINFO_IN6		_IOWR('i', 113, struct in6_ndireq)
#define SIOCSIFINFO_IN6		_IOWR('i', 114, struct in6_ndireq)
#define SIOCSIFINFO_FLAGS	_IOWR('i', 115, struct in6_ndireq)

/* XXX: Someone decided to switch to 'u' here for unknown reasons! */
#define SIOCGETSGCNT_IN6	_IOWR('u', 106, \
				      struct sioc_sg_req6) /* get s,g pkt cnt */
#define SIOCGETMIFCNT_IN6	_IOWR('u', 107, \
				      struct sioc_mif_req6) /* get pkt cnt per if */
#define SIOCAADDRCTL_POLICY	_IOW('u', 108, struct in6_addrpolicy)
#define SIOCDADDRCTL_POLICY	_IOW('u', 109, struct in6_addrpolicy)

#define IN6_IFF_ANYCAST		0x01	/* anycast address */
#define IN6_IFF_TENTATIVE	0x02	/* tentative address */
#define IN6_IFF_DUPLICATED	0x04	/* DAD detected duplicate */
#define IN6_IFF_DETACHED	0x08	/* may be detached from the link */
#define IN6_IFF_DEPRECATED	0x10	/* deprecated address */
#define IN6_IFF_NODAD		0x20	/* don't perform DAD on this address
					 * (used only at first SIOC* call)
					 */
#define IN6_IFF_AUTOCONF	0x40	/* autoconfigurable address. */
#define IN6_IFF_TEMPORARY	0x80	/* temporary (anonymous) address. */

#define IN6_IFFBITS \
    "\020\1ANYCAST\2TENTATIVE\3DUPLICATED\4DETACHED\5DEPRECATED\6NODAD" \
    "\7AUTOCONF\10TEMPORARY"


/* do not input/output */
#define IN6_IFF_NOTREADY (IN6_IFF_TENTATIVE|IN6_IFF_DUPLICATED)

#ifdef _KERNEL
#define IN6_ARE_SCOPE_CMP(a,b) ((a)-(b))
#define IN6_ARE_SCOPE_EQUAL(a,b) ((a)==(b))
#endif

#ifdef _KERNEL

#include <sys/mutex.h>
#include <sys/pserialize.h>

#include <net/pktqueue.h>

extern pktqueue_t *ip6_pktq;

MALLOC_DECLARE(M_IP6OPT);

extern struct pslist_head	in6_ifaddr_list;
extern kmutex_t			in6_ifaddr_lock;

#define IN6_ADDRLIST_ENTRY_INIT(__ia) \
	PSLIST_ENTRY_INIT((__ia), ia6_pslist_entry)
#define IN6_ADDRLIST_ENTRY_DESTROY(__ia) \
	PSLIST_ENTRY_DESTROY((__ia), ia6_pslist_entry)
#define IN6_ADDRLIST_READER_EMPTY() \
	(PSLIST_READER_FIRST(&in6_ifaddr_list, struct in6_ifaddr, \
	                     ia6_pslist_entry) == NULL)
#define IN6_ADDRLIST_READER_FIRST() \
	PSLIST_READER_FIRST(&in6_ifaddr_list, struct in6_ifaddr, \
	                    ia6_pslist_entry)
#define IN6_ADDRLIST_READER_NEXT(__ia) \
	PSLIST_READER_NEXT((__ia), struct in6_ifaddr, ia6_pslist_entry)
#define IN6_ADDRLIST_READER_FOREACH(__ia) \
	PSLIST_READER_FOREACH((__ia), &in6_ifaddr_list, \
	                      struct in6_ifaddr, ia6_pslist_entry)
#define IN6_ADDRLIST_WRITER_INSERT_HEAD(__ia) \
	PSLIST_WRITER_INSERT_HEAD(&in6_ifaddr_list, (__ia), ia6_pslist_entry)
#define IN6_ADDRLIST_WRITER_REMOVE(__ia) \
	PSLIST_WRITER_REMOVE((__ia), ia6_pslist_entry)
#define IN6_ADDRLIST_WRITER_FOREACH(__ia) \
	PSLIST_WRITER_FOREACH((__ia), &in6_ifaddr_list, struct in6_ifaddr, \
	                      ia6_pslist_entry)
#define IN6_ADDRLIST_WRITER_FIRST() \
	PSLIST_WRITER_FIRST(&in6_ifaddr_list, struct in6_ifaddr, \
	                    ia6_pslist_entry)
#define IN6_ADDRLIST_WRITER_NEXT(__ia) \
	PSLIST_WRITER_NEXT((__ia), struct in6_ifaddr, ia6_pslist_entry)
#define IN6_ADDRLIST_WRITER_INSERT_AFTER(__ia, __new) \
	PSLIST_WRITER_INSERT_AFTER((__ia), (__new), ia6_pslist_entry)
#define IN6_ADDRLIST_WRITER_EMPTY() \
	(PSLIST_WRITER_FIRST(&in6_ifaddr_list, struct in6_ifaddr, \
	    ia6_pslist_entry) == NULL)
#define IN6_ADDRLIST_WRITER_INSERT_TAIL(__new)				\
	do {								\
		if (IN6_ADDRLIST_WRITER_EMPTY()) {			\
			IN6_ADDRLIST_WRITER_INSERT_HEAD((__new));	\
		} else {						\
			struct in6_ifaddr *__ia;			\
			IN6_ADDRLIST_WRITER_FOREACH(__ia) {		\
				if (IN6_ADDRLIST_WRITER_NEXT(__ia) == NULL) { \
					IN6_ADDRLIST_WRITER_INSERT_AFTER(__ia,\
					    (__new));			\
					break;				\
				}					\
			}						\
		}							\
	} while (0)

#define in6_ifstat_inc(ifp, tag) \
do {								\
	if (ifp)						\
		((struct in6_ifextra *)((ifp)->if_afdata[AF_INET6]))->in6_ifstat->tag++; \
} while (/*CONSTCOND*/ 0)

extern const struct in6_addr zeroin6_addr;
extern const u_char inet6ctlerrmap[];
extern bool in6_present;

/*
 * Macro for finding the internet address structure (in6_ifaddr) corresponding
 * to a given interface (ifnet structure).
 */
static __inline struct in6_ifaddr *
in6_get_ia_from_ifp(struct ifnet *ifp)
{
	struct ifaddr *ifa;

	IFADDR_READER_FOREACH(ifa, ifp) {
		if (ifa->ifa_addr->sa_family == AF_INET6)
			break;
	}
	return (struct in6_ifaddr *)ifa;
}

static __inline struct in6_ifaddr *
in6_get_ia_from_ifp_psref(struct ifnet *ifp, struct psref *psref)
{
	struct in6_ifaddr *ia;
	int s;

	s = pserialize_read_enter();
	ia = in6_get_ia_from_ifp(ifp);
	if (ia != NULL)
		ia6_acquire(ia, psref);
	pserialize_read_exit(s);

	return ia;
}
#endif /* _KERNEL */

/*
 * Multi-cast membership entry.  One for each group/ifp that a PCB
 * belongs to.
 */
struct in6_multi_mship {
	struct	in6_multi *i6mm_maddr;	/* Multicast address pointer */
	LIST_ENTRY(in6_multi_mship) i6mm_chain;  /* multicast options chain */
};

struct	in6_multi {
	LIST_ENTRY(in6_multi) in6m_entry; /* list glue */
	struct	in6_addr in6m_addr;	/* IP6 multicast address */
	struct	ifnet *in6m_ifp;	/* back pointer to ifnet */
	/* DEPRECATED. Keep it to avoid breaking kvm(3) users */
	struct	in6_ifaddr *_in6m_ia;	/* back pointer to in6_ifaddr */
	u_int	in6m_refcount;		/* # membership claims by sockets */
	u_int	in6m_state;		/* state of the membership */
	int	in6m_timer;		/* delay to send the 1st report */
	struct timeval in6m_timer_expire; /* when the timer expires */
	callout_t in6m_timer_ch;
};
 
#define IN6M_TIMER_UNDEF -1


#ifdef _KERNEL
/* flags to in6_update_ifa */
#define IN6_IFAUPDATE_DADDELAY	0x1 /* first time to configure an address */

#if 0
/*
 * Macros for looking up the in6_multi_mship record for a given IP6 multicast
 * address on a given interface. If no matching record is found, "imm"
 * returns NULL.
 */
static __inline struct in6_multi_mship *
in6_lookup_mship(struct in6_addr *addr, struct ifnet *ifp,
    struct ip6_moptions *imop)
{
	struct in6_multi_mship *imm;

	LIST_FOREACH(imm, &imop->im6o_memberships, i6mm_chain) {
		if (imm->i6mm_maddr->in6m_ifp != ifp)
		    	continue;
		if (IN6_ARE_ADDR_EQUAL(&imm->i6mm_maddr->in6m_addr,
		    addr))
			break;
	}
	return imm;
}

#define IN6_LOOKUP_MSHIP(__addr, __ifp, __imop, __imm)			\
/* struct in6_addr __addr; */						\
/* struct ifnet *__ifp; */						\
/* struct ip6_moptions *__imop */					\
/* struct in6_multi_mship *__imm; */					\
do {									\
	(__imm) = in6_lookup_mship(&(__addr), (__ifp), (__imop));	\
} while (/*CONSTCOND*/ 0)
#endif

void	in6_init(void);

void	in6_multi_lock(int);
void	in6_multi_unlock(void);
bool	in6_multi_locked(int);
struct in6_multi *
	in6_lookup_multi(const struct in6_addr *, const struct ifnet *);
bool	in6_multi_group(const struct in6_addr *, const struct ifnet *);
void	in6_purge_multi(struct ifnet *);
struct	in6_multi *in6_addmulti(struct in6_addr *, struct ifnet *,
	int *, int);
void	in6_delmulti(struct in6_multi *);
void	in6_delmulti_locked(struct in6_multi *);
void	in6_lookup_and_delete_multi(const struct in6_addr *,
	    const struct ifnet *);
struct in6_multi_mship *in6_joingroup(struct ifnet *, struct in6_addr *,
	int *, int);
int	in6_leavegroup(struct in6_multi_mship *);
int	in6_mask2len(struct in6_addr *, u_char *);
int	in6_control(struct socket *, u_long, void *, struct ifnet *);
int	in6_update_ifa(struct ifnet *, struct in6_aliasreq *, int);
void	in6_purgeaddr(struct ifaddr *);
void	in6_purgeif(struct ifnet *);
void	*in6_domifattach(struct ifnet *);
void	in6_domifdetach(struct ifnet *, void *);
void	in6_ifremlocal(struct ifaddr *);
void	in6_ifaddlocal(struct ifaddr *);
struct in6_ifaddr *
	in6ifa_ifpforlinklocal(const struct ifnet *, int);
struct in6_ifaddr *
	in6ifa_ifpforlinklocal_psref(const struct ifnet *, int, struct psref *);
struct in6_ifaddr *
	in6ifa_ifpwithaddr(const struct ifnet *, const struct in6_addr *);
struct in6_ifaddr *
	in6ifa_ifpwithaddr_psref(const struct ifnet *, const struct in6_addr *,
	    struct psref *);
struct in6_ifaddr *in6ifa_ifwithaddr(const struct in6_addr *, uint32_t);
int	in6_matchlen(struct in6_addr *, struct in6_addr *);
void	in6_prefixlen2mask(struct in6_addr *, int);
void	in6_purge_mcast_references(struct in6_multi *);

int	ip6flow_fastforward(struct mbuf **); /* IPv6 fast forward routine */

int in6_src_ioctl(u_long, void *);
int	in6_is_addr_deprecated(struct sockaddr_in6 *);
struct in6pcb;

#define	LLTABLE6(ifp)	(((struct in6_ifextra *)(ifp)->if_afdata[AF_INET6])->lltable)

void	in6_sysctl_multicast_setup(struct sysctllog **);

#endif /* _KERNEL */

#endif /* !_NETINET6_IN6_VAR_H_ */