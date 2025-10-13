/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1986, 1990, 1993
 *	The Regents of the University of California.
 * Copyright (c) 2010-2011 Juniper Networks, Inc.
 * All rights reserved.
 *
 * Portions of this software were developed by Robert N. M. Watson under
 * contract to Juniper Networks, Inc.
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

#include <sys/queue.h>
#include <sys/epoch.h>
#include <sys/_lock.h>
#include <sys/_mutex.h>
#include <sys/_rwlock.h>
#include <sys/_smr.h>
#include <net/route.h>

#ifdef _KERNEL
#include <sys/lock.h>
#include <sys/proc.h>
#include <sys/rwlock.h>
#include <sys/sysctl.h>
#include <net/vnet.h>
#include <vm/uma.h>
#endif
#include <sys/ck.h>

/*
 * struct inpcb is the common protocol control block structure used in most
 * IP transport protocols.
 *
 * Pointers to local and foreign host table entries, local and foreign socket
 * numbers, and pointers up (to a socket structure) and down (to a
 * protocol-specific control block) are stored here.
 */
CK_LIST_HEAD(inpcbhead, inpcb);
CK_LIST_HEAD(inpcbporthead, inpcbport);
CK_LIST_HEAD(inpcblbgrouphead, inpcblbgroup);
typedef	uint64_t	inp_gen_t;

/*
 * PCB with AF_INET6 null bind'ed laddr can receive AF_INET input packet.
 * So, AF_INET6 null laddr is also used as AF_INET null laddr, by utilizing
 * the following structure.  This requires padding always be zeroed out,
 * which is done right after inpcb allocation and stays through its lifetime.
 */
struct in_addr_4in6 {
	u_int32_t	ia46_pad32[3];
	struct	in_addr	ia46_addr4;
};

union in_dependaddr {
	struct in_addr_4in6 id46_addr;
	struct in6_addr	id6_addr;
};

/*
 * NOTE: ipv6 addrs should be 64-bit aligned, per RFC 2553.  in_conninfo has
 * some extra padding to accomplish this.
 * NOTE 2: tcp_syncache.c uses first 5 32-bit words, which identify fport,
 * lport, faddr to generate hash, so these fields shouldn't be moved.
 */
struct in_endpoints {
	u_int16_t	ie_fport;		/* foreign port */
	u_int16_t	ie_lport;		/* local port */
	/* protocol dependent part, local and foreign addr */
	union in_dependaddr ie_dependfaddr;	/* foreign host table entry */
	union in_dependaddr ie_dependladdr;	/* local host table entry */
#define	ie_faddr	ie_dependfaddr.id46_addr.ia46_addr4
#define	ie_laddr	ie_dependladdr.id46_addr.ia46_addr4
#define	ie6_faddr	ie_dependfaddr.id6_addr
#define	ie6_laddr	ie_dependladdr.id6_addr
	u_int32_t	ie6_zoneid;		/* scope zone id */
};

/*
 * XXX The defines for inc_* are hacks and should be changed to direct
 * references.
 */
struct in_conninfo {
	u_int8_t	inc_flags;
	u_int8_t	inc_len;
	u_int16_t	inc_fibnum;	/* XXX was pad, 16 bits is plenty */
	/* protocol dependent part */
	struct	in_endpoints inc_ie;
};

/*
 * Flags for inc_flags.
 */
#define	INC_ISIPV6	0x01
#define	INC_IPV6MINMTU	0x02

#define	inc_fport	inc_ie.ie_fport
#define	inc_lport	inc_ie.ie_lport
#define	inc_faddr	inc_ie.ie_faddr
#define	inc_laddr	inc_ie.ie_laddr
#define	inc6_faddr	inc_ie.ie6_faddr
#define	inc6_laddr	inc_ie.ie6_laddr
#define	inc6_zoneid	inc_ie.ie6_zoneid

#if defined(_KERNEL) || defined(_WANT_INPCB)
/*
 * struct inpcb captures the network layer state for TCP, UDP, and raw IPv4 and
 * IPv6 sockets.  In the case of TCP and UDP, further per-connection state is
 * hung off of inp_ppcb most of the time.  Almost all fields of struct inpcb
 * are static after creation or protected by a per-inpcb rwlock, inp_lock.
 *
 * A inpcb database is indexed by addresses/ports hash as well as list of
 * all pcbs that belong to a certain proto. Database lookups or list traversals
 * are be performed inside SMR section. Once desired PCB is found its own
 * lock is to be obtained and SMR section exited.
 *
 * Key:
 * (c) - Constant after initialization
 * (e) - Protected by the SMR section
 * (i) - Protected by the inpcb lock
 * (p) - Protected by the pcbinfo lock for the inpcb
 * (h) - Protected by the pcbhash lock for the inpcb
 * (s) - Protected by another subsystem's locks
 * (x) - Undefined locking
 *
 * A few other notes:
 *
 * When a read lock is held, stability of the field is guaranteed; to write
 * to a field, a write lock must generally be held.
 *
 * netinet/netinet6-layer code should not assume that the inp_socket pointer
 * is safe to dereference without inp_lock being held, there may be
 * close(2)-related races.
 *
 * The inp_vflag field is overloaded, and would otherwise ideally be (c).
 */
struct icmp6_filter;
struct inpcbpolicy;
struct m_snd_tag;
struct inpcb {
	/* Cache line #1 (amd64) */
	CK_LIST_ENTRY(inpcb) inp_hash_exact;	/* hash table linkage */
	CK_LIST_ENTRY(inpcb) inp_hash_wild;	/* hash table linkage */
	struct rwlock	inp_lock;
	/* Cache line #2 (amd64) */
#define	inp_start_zero	inp_refcount
#define	inp_zero_size	(sizeof(struct inpcb) - \
			    offsetof(struct inpcb, inp_start_zero))
	u_int	inp_refcount;		/* (i) refcount */
	int	inp_flags;		/* (i) generic IP/datagram flags */
	int	inp_flags2;		/* (i) generic IP/datagram flags #2*/
	uint8_t inp_numa_domain;	/* numa domain */
	void	*inp_ppcb;		/* (i) pointer to per-protocol pcb */
	struct	socket *inp_socket;	/* (i) back pointer to socket */
	struct	inpcbinfo *inp_pcbinfo;	/* (c) PCB list info */
	struct	ucred	*inp_cred;	/* (c) cache of socket cred */
	u_int32_t inp_flow;		/* (i) IPv6 flow information */
	u_char	inp_vflag;		/* (i) IP version flag (v4/v6) */
	u_char	inp_ip_ttl;		/* (i) time to live proto */
	u_char	inp_ip_p;		/* (c) protocol proto */
	u_char	inp_ip_minttl;		/* (i) minimum TTL or drop */
	uint32_t inp_flowid;		/* (x) flow id / queue id */
	smr_seq_t inp_smr;		/* (i) sequence number at disconnect */
	struct m_snd_tag *inp_snd_tag;	/* (i) send tag for outgoing mbufs */
	uint32_t inp_flowtype;		/* (x) M_HASHTYPE value */

	/* Local and foreign ports, local and foreign addr. */
	struct	in_conninfo inp_inc;	/* (i,h) list for PCB's local port */

	/* MAC and IPSEC policy information. */
	struct	label *inp_label;	/* (i) MAC label */
	struct	inpcbpolicy *inp_sp;    /* (s) for IPSEC */

	/* Protocol-dependent part; options. */
	struct {
		u_char	inp_ip_tos;		/* (i) type of service proto */
		struct mbuf		*inp_options;	/* (i) IP options */
		struct ip_moptions	*inp_moptions;	/* (i) mcast options */
	};
	struct {
		/* (i) IP options */
		struct mbuf		*in6p_options;
		/* (i) IP6 options for outgoing packets */
		struct ip6_pktopts	*in6p_outputopts;
		/* (i) IP multicast options */
		struct ip6_moptions	*in6p_moptions;
		/* (i) ICMPv6 code type filter */
		struct icmp6_filter	*in6p_icmp6filt;
		/* (i) IPV6_CHECKSUM setsockopt */
		int	in6p_cksum;
		short	in6p_hops;
	};
	CK_LIST_ENTRY(inpcb) inp_portlist;	/* (r:e/w:h) port list */
	struct	inpcbport *inp_phd;	/* (r:e/w:h) head of this list */
	inp_gen_t	inp_gencnt;	/* (c) generation count */
	void		*spare_ptr;	/* Spare pointer. */
	rt_gen_t	inp_rt_cookie;	/* generation for route entry */
	union {				/* cached L3 information */
		struct route inp_route;
		struct route_in6 inp_route6;
	};
	CK_LIST_ENTRY(inpcb) inp_list;	/* (r:e/w:p) all PCBs for proto */
};
#endif	/* _KERNEL */

#define	inp_fport	inp_inc.inc_fport
#define	inp_lport	inp_inc.inc_lport
#define	inp_faddr	inp_inc.inc_faddr
#define	inp_laddr	inp_inc.inc_laddr

#define	in6p_faddr	inp_inc.inc6_faddr
#define	in6p_laddr	inp_inc.inc6_laddr
#define	in6p_zoneid	inp_inc.inc6_zoneid

#define	inp_vnet	inp_pcbinfo->ipi_vnet

/*
 * The range of the generation count, as used in this implementation, is 9e19.
 * We would have to create 300 billion connections per second for this number
 * to roll over in a year.  This seems sufficiently unlikely that we simply
 * don't concern ourselves with that possibility.
 */

/*
 * Interface exported to userland by various protocols which use inpcbs.  Hack
 * alert -- only define if struct xsocket is in scope.
 * Fields prefixed with "xi_" are unique to this structure, and the rest
 * match fields in the struct inpcb, to ease coding and porting.
 *
 * Legend:
 * (s) - used by userland utilities in src
 * (p) - used by utilities in ports
 * (3) - is known to be used by third party software not in ports
 * (n) - no known usage
 */
#ifdef _SYS_SOCKETVAR_H_
struct xinpcb {
	ksize_t		xi_len;			/* length of this structure */
	struct xsocket	xi_socket;		/* (s,p) */
	struct in_conninfo inp_inc;		/* (s,p) */
	uint64_t	inp_gencnt;		/* (s,p) */
	kvaddr_t	inp_ppcb;		/* (s) netstat(1) */
	int64_t		inp_spare64[4];
	uint32_t	inp_flow;		/* (s) */
	uint32_t	inp_flowid;		/* (s) */
	uint32_t	inp_flowtype;		/* (s) */
	int32_t		inp_flags;		/* (s,p) */
	int32_t		inp_flags2;		/* (s) */
	uint32_t	inp_unused;
	int32_t		in6p_cksum;		/* (n) */
	int32_t		inp_spare32[4];
	uint16_t	in6p_hops;		/* (n) */
	uint8_t		inp_ip_tos;		/* (n) */
	int8_t		pad8;
	uint8_t		inp_vflag;		/* (s,p) */
	uint8_t		inp_ip_ttl;		/* (n) */
	uint8_t		inp_ip_p;		/* (n) */
	uint8_t		inp_ip_minttl;		/* (n) */
	int8_t		inp_spare8[4];
} __aligned(8);

struct xinpgen {
	ksize_t	xig_len;	/* length of this structure */
	u_int		xig_count;	/* number of PCBs at this time */
	uint32_t	_xig_spare32;
	inp_gen_t	xig_gen;	/* generation count at this time */
	so_gen_t	xig_sogen;	/* socket generation count this time */
	uint64_t	_xig_spare64[4];
} __aligned(8);

struct sockopt_parameters {
	struct in_conninfo sop_inc;
	uint64_t sop_id;
	int sop_level;
	int sop_optname;
	char sop_optval[];
};

#ifdef	_KERNEL
int	sysctl_setsockopt(SYSCTL_HANDLER_ARGS, struct inpcbinfo *pcbinfo,
	    int (*ctloutput_set)(struct inpcb *, struct sockopt *));
void	in_pcbtoxinpcb(const struct inpcb *, struct xinpcb *);
#endif
#endif /* _SYS_SOCKETVAR_H_ */

#ifdef _KERNEL
/*
 * Per-VNET pcb database for each high-level protocol (UDP, TCP, ...) in both
 * IPv4 and IPv6.
 *
 * The pcbs are protected with SMR section and thus all lists in inpcbinfo
 * are CK-lists.  Locking is required to insert a pcb into database. Two
 * locks are provided: one for the hash and one for the global list of pcbs,
 * as well as overall count and generation count.
 *
 * Locking key:
 *
 * (c) Constant or nearly constant after initialisation
 * (e) Protected by SMR section
 * (g) Locked by ipi_lock
 * (h) Locked by ipi_hash_lock
 */
struct inpcbinfo {
	/*
	 * Global lock protecting inpcb list modification
	 */
	struct mtx		 ipi_lock;
	struct inpcbhead	 ipi_listhead;		/* (r:e/w:g) */
	u_int			 ipi_count;		/* (g) */

	/*
	 * Generation count -- incremented each time a connection is allocated
	 * or freed.
	 */
	u_quad_t		 ipi_gencnt;		/* (g) */

	/*
	 * Fields associated with port lookup and allocation.
	 */
	u_short			 ipi_lastport;		/* (h) */
	u_short			 ipi_lastlow;		/* (h) */
	u_short			 ipi_lasthi;		/* (h) */

	/*
	 * UMA zone from which inpcbs are allocated for this protocol.
	 */
	uma_zone_t		 ipi_zone;		/* (c) */
	uma_zone_t		 ipi_portzone;		/* (c) */
	smr_t			 ipi_smr;		/* (c) */

	/*
	 * Global hash of inpcbs, hashed by local and foreign addresses and
	 * port numbers.  The "exact" hash holds PCBs connected to a foreign
	 * address, and "wild" holds the rest.
	 */
	struct mtx		 ipi_hash_lock;
	struct inpcbhead 	*ipi_hash_exact;	/* (r:e/w:h) */
	struct inpcbhead 	*ipi_hash_wild;		/* (r:e/w:h) */
	u_long			 ipi_hashmask;		/* (c) */

	/*
	 * Global hash of inpcbs, hashed by only local port number.
	 */
	struct inpcbporthead	*ipi_porthashbase;	/* (h) */
	u_long			 ipi_porthashmask;	/* (h) */

	/*
	 * Load balance groups used for the SO_REUSEPORT_LB option,
	 * hashed by local port.
	 */
	struct	inpcblbgrouphead *ipi_lbgrouphashbase;	/* (r:e/w:h) */
	u_long			 ipi_lbgrouphashmask;	/* (h) */

	/*
	 * Pointer to network stack instance
	 */
	struct vnet		*ipi_vnet;		/* (c) */
};

/*
 * Global allocation storage for each high-level protocol (UDP, TCP, ...).
 * Each corresponding per-VNET inpcbinfo points into this one.
 */
struct inpcbstorage {
	uma_zone_t	ips_zone;
	uma_zone_t	ips_portzone;
	uma_init	ips_pcbinit;
	size_t		ips_size;
	const char *	ips_zone_name;
	const char *	ips_portzone_name;
	const char *	ips_infolock_name;
	const char *	ips_hashlock_name;
};

#define INPCBSTORAGE_DEFINE(prot, ppcb, lname, zname, iname, hname)	\
static int								\
prot##_inpcb_init(void *mem, int size __unused, int flags __unused)	\
{									\
	struct inpcb *inp = mem;					\
									\
	rw_init_flags(&inp->inp_lock, lname, RW_RECURSE | RW_DUPOK);	\
	return (0);							\
}									\
static struct inpcbstorage prot = {					\
	.ips_size = sizeof(struct ppcb),				\
	.ips_pcbinit = prot##_inpcb_init,				\
	.ips_zone_name = zname,						\
	.ips_portzone_name = zname " ports",				\
	.ips_infolock_name = iname,					\
	.ips_hashlock_name = hname,					\
};									\
SYSINIT(prot##_inpcbstorage_init, SI_SUB_PROTO_DOMAIN,			\
    SI_ORDER_SECOND, in_pcbstorage_init, &prot);			\
SYSUNINIT(prot##_inpcbstorage_uninit, SI_SUB_PROTO_DOMAIN,		\
    SI_ORDER_SECOND, in_pcbstorage_destroy, &prot)

/*
 * Load balance groups used for the SO_REUSEPORT_LB socket option. Each group
 * (or unique address:port combination) can be re-used at most
 * INPCBLBGROUP_SIZMAX (256) times. The inpcbs are stored in il_inp which
 * is dynamically resized as processes bind/unbind to that specific group.
 */
struct inpcblbgroup {
	CK_LIST_ENTRY(inpcblbgroup) il_list;
	struct epoch_context il_epoch_ctx;
	struct ucred	*il_cred;
	uint16_t	il_lport;			/* (c) */
	u_char		il_vflag;			/* (c) */
	uint8_t		il_numa_domain;
	uint32_t	il_pad2;
	union in_dependaddr il_dependladdr;		/* (c) */
#define	il_laddr	il_dependladdr.id46_addr.ia46_addr4
#define	il6_laddr	il_dependladdr.id6_addr
	uint32_t	il_inpsiz; /* max count in il_inp[] (h) */
	uint32_t	il_inpcnt; /* cur count in il_inp[] (h) */
	struct inpcb	*il_inp[];			/* (h) */
};

#define INP_LOCK_DESTROY(inp)	rw_destroy(&(inp)->inp_lock)
#define INP_RLOCK(inp)		rw_rlock(&(inp)->inp_lock)
#define INP_WLOCK(inp)		rw_wlock(&(inp)->inp_lock)
#define INP_TRY_RLOCK(inp)	rw_try_rlock(&(inp)->inp_lock)
#define INP_TRY_WLOCK(inp)	rw_try_wlock(&(inp)->inp_lock)
#define INP_RUNLOCK(inp)	rw_runlock(&(inp)->inp_lock)
#define INP_WUNLOCK(inp)	rw_wunlock(&(inp)->inp_lock)
#define INP_UNLOCK(inp)		rw_unlock(&(inp)->inp_lock)
#define	INP_TRY_UPGRADE(inp)	rw_try_upgrade(&(inp)->inp_lock)
#define	INP_DOWNGRADE(inp)	rw_downgrade(&(inp)->inp_lock)
#define	INP_WLOCKED(inp)	rw_wowned(&(inp)->inp_lock)
#define	INP_LOCK_ASSERT(inp)	rw_assert(&(inp)->inp_lock, RA_LOCKED)
#define	INP_RLOCK_ASSERT(inp)	rw_assert(&(inp)->inp_lock, RA_RLOCKED)
#define	INP_WLOCK_ASSERT(inp)	rw_assert(&(inp)->inp_lock, RA_WLOCKED)
#define	INP_UNLOCK_ASSERT(inp)	rw_assert(&(inp)->inp_lock, RA_UNLOCKED)

/*
 * These locking functions are for inpcb consumers outside of sys/netinet,
 * more specifically, they were added for the benefit of TOE drivers. The
 * macros are reserved for use by the stack.
 */
void inp_wlock(struct inpcb *);
void inp_wunlock(struct inpcb *);
void inp_rlock(struct inpcb *);
void inp_runlock(struct inpcb *);

#ifdef INVARIANT_SUPPORT
void inp_lock_assert(struct inpcb *);
void inp_unlock_assert(struct inpcb *);
#else
#define	inp_lock_assert(inp)	do {} while (0)
#define	inp_unlock_assert(inp)	do {} while (0)
#endif

void	inp_apply_all(struct inpcbinfo *, void (*func)(struct inpcb *, void *),
	    void *arg);
int 	inp_ip_tos_get(const struct inpcb *inp);
void 	inp_ip_tos_set(struct inpcb *inp, int val);
struct socket *
	inp_inpcbtosocket(struct inpcb *inp);
struct tcpcb *
	inp_inpcbtotcpcb(struct inpcb *inp);
void 	inp_4tuple_get(struct inpcb *inp, uint32_t *laddr, uint16_t *lp,
		uint32_t *faddr, uint16_t *fp);

#endif /* _KERNEL */

#define INP_INFO_WLOCK(ipi)	mtx_lock(&(ipi)->ipi_lock)
#define INP_INFO_WLOCKED(ipi)	mtx_owned(&(ipi)->ipi_lock)
#define INP_INFO_WUNLOCK(ipi)	mtx_unlock(&(ipi)->ipi_lock)
#define	INP_INFO_LOCK_ASSERT(ipi)	MPASS(SMR_ENTERED((ipi)->ipi_smr) || \
					mtx_owned(&(ipi)->ipi_lock))
#define INP_INFO_WLOCK_ASSERT(ipi)	mtx_assert(&(ipi)->ipi_lock, MA_OWNED)
#define INP_INFO_WUNLOCK_ASSERT(ipi)	\
				mtx_assert(&(ipi)->ipi_lock, MA_NOTOWNED)

#define	INP_HASH_WLOCK(ipi)		mtx_lock(&(ipi)->ipi_hash_lock)
#define	INP_HASH_WUNLOCK(ipi)		mtx_unlock(&(ipi)->ipi_hash_lock)
#define	INP_HASH_LOCK_ASSERT(ipi)	MPASS(SMR_ENTERED((ipi)->ipi_smr) || \
					mtx_owned(&(ipi)->ipi_hash_lock))
#define	INP_HASH_WLOCK_ASSERT(ipi)	mtx_assert(&(ipi)->ipi_hash_lock, \
					MA_OWNED)

/*
 * Wildcard matching hash is not just a microoptimisation!  The hash for
 * wildcard IPv4 and wildcard IPv6 must be the same, otherwise AF_INET6
 * wildcard bound pcb won't be able to receive AF_INET connections, while:
 * jenkins_hash(&zeroes, 1, s) != jenkins_hash(&zeroes, 4, s)
 * See also comment above struct in_addr_4in6.
 */
#define	IN_ADDR_JHASH32(addr)						\
	((addr)->s_addr == INADDR_ANY ? V_in_pcbhashseed :		\
	    jenkins_hash32((&(addr)->s_addr), 1, V_in_pcbhashseed))
#define	IN6_ADDR_JHASH32(addr)						\
	(memcmp((addr), &in6addr_any, sizeof(in6addr_any)) == 0 ?	\
	    V_in_pcbhashseed :						\
	    jenkins_hash32((addr)->__u6_addr.__u6_addr32,		\
	    nitems((addr)->__u6_addr.__u6_addr32), V_in_pcbhashseed))

#define INP_PCBHASH(faddr, lport, fport, mask)				\
	((IN_ADDR_JHASH32(faddr) ^ ntohs((lport) ^ (fport))) & (mask))
#define	INP6_PCBHASH(faddr, lport, fport, mask)				\
	((IN6_ADDR_JHASH32(faddr) ^ ntohs((lport) ^ (fport))) & (mask))

#define	INP_PCBHASH_WILD(lport, mask)					\
	((V_in_pcbhashseed ^ ntohs(lport)) & (mask))

#define	INP_PCBLBGROUP_PKTHASH(faddr, lport, fport)			\
	(IN_ADDR_JHASH32(faddr) ^ ntohs((lport) ^ (fport)))
#define	INP6_PCBLBGROUP_PKTHASH(faddr, lport, fport)			\
	(IN6_ADDR_JHASH32(faddr) ^ ntohs((lport) ^ (fport)))

#define INP_PCBPORTHASH(lport, mask)	(ntohs((lport)) & (mask))

/*
 * Flags for inp_vflags -- historically version flags only
 */
#define	INP_IPV4	0x1
#define	INP_IPV6	0x2
#define	INP_IPV6PROTO	0x4		/* opened under IPv6 protocol */

/*
 * Flags for inp_flags.
 */
#define	INP_RECVOPTS		0x00000001 /* receive incoming IP options */
#define	INP_RECVRETOPTS		0x00000002 /* receive IP options for reply */
#define	INP_RECVDSTADDR		0x00000004 /* receive IP dst address */
#define	INP_HDRINCL		0x00000008 /* user supplies entire IP header */
#define	INP_HIGHPORT		0x00000010 /* user wants "high" port binding */
#define	INP_LOWPORT		0x00000020 /* user wants "low" port binding */
#define	INP_ANONPORT		0x00000040 /* read by netstat(1) */
#define	INP_RECVIF		0x00000080 /* receive incoming interface */
#define	INP_MTUDISC		0x00000100 /* user can do MTU discovery */
/*	INP_FREED		0x00000200 private to in_pcb.c */
#define	INP_RECVTTL		0x00000400 /* receive incoming IP TTL */
#define	INP_DONTFRAG		0x00000800 /* don't fragment packet */
#define	INP_BINDANY		0x00001000 /* allow bind to any address */
#define	INP_INHASHLIST		0x00002000 /* in_pcbinshash() has been called */
#define	INP_RECVTOS		0x00004000 /* receive incoming IP TOS */
#define	IN6P_IPV6_V6ONLY	0x00008000 /* restrict AF_INET6 socket for v6 */
#define	IN6P_PKTINFO		0x00010000 /* receive IP6 dst and I/F */
#define	IN6P_HOPLIMIT		0x00020000 /* receive hoplimit */
#define	IN6P_HOPOPTS		0x00040000 /* receive hop-by-hop options */
#define	IN6P_DSTOPTS		0x00080000 /* receive dst options after rthdr */
#define	IN6P_RTHDR		0x00100000 /* receive routing header */
#define	IN6P_RTHDRDSTOPTS	0x00200000 /* receive dstoptions before rthdr */
#define	IN6P_TCLASS		0x00400000 /* receive traffic class value */
#define	IN6P_AUTOFLOWLABEL	0x00800000 /* attach flowlabel automatically */
/*	INP_INLBGROUP		0x01000000 private to in_pcb.c */
#define	INP_ONESBCAST		0x02000000 /* send all-ones broadcast */
#define	INP_DROPPED		0x04000000 /* protocol drop flag */
#define	INP_SOCKREF		0x08000000 /* strong socket reference */
#define	INP_RESERVED_0          0x10000000 /* reserved field */
#define	INP_RESERVED_1          0x20000000 /* reserved field */
#define	IN6P_RFC2292		0x40000000 /* used RFC2292 API on the socket */
#define	IN6P_MTU		0x80000000 /* receive path MTU */

#define	INP_CONTROLOPTS		(INP_RECVOPTS|INP_RECVRETOPTS|INP_RECVDSTADDR|\
				 INP_RECVIF|INP_RECVTTL|INP_RECVTOS|\
				 IN6P_PKTINFO|IN6P_HOPLIMIT|IN6P_HOPOPTS|\
				 IN6P_DSTOPTS|IN6P_RTHDR|IN6P_RTHDRDSTOPTS|\
				 IN6P_TCLASS|IN6P_AUTOFLOWLABEL|IN6P_RFC2292|\
				 IN6P_MTU)

/*
 * Flags for inp_flags2.
 */
/*				0x00000001 */
/*				0x00000002 */
/*				0x00000004 */
/*				0x00000008 */
/*				0x00000010 */
/*				0x00000020 */
/*				0x00000040 */
/*				0x00000080 */
#define	INP_RECVFLOWID		0x00000100 /* populate recv datagram with flow info */
#define	INP_RECVRSSBUCKETID	0x00000200 /* populate recv datagram with bucket id */
#define	INP_RATE_LIMIT_CHANGED	0x00000400 /* rate limit needs attention */
#define	INP_ORIGDSTADDR		0x00000800 /* receive IP dst address/port */
/*				0x00001000 */
/*				0x00002000 */
/*				0x00004000 */
/*				0x00008000 */
/*				0x00010000 */
#define INP_2PCP_SET		0x00020000 /* If the Eth PCP should be set explicitly */
#define INP_2PCP_BIT0		0x00040000 /* Eth PCP Bit 0 */
#define INP_2PCP_BIT1		0x00080000 /* Eth PCP Bit 1 */
#define INP_2PCP_BIT2		0x00100000 /* Eth PCP Bit 2 */
#define INP_2PCP_BASE	INP_2PCP_BIT0
#define INP_2PCP_MASK	(INP_2PCP_BIT0 | INP_2PCP_BIT1 | INP_2PCP_BIT2)
#define INP_2PCP_SHIFT		18         /* shift PCP field in/out of inp_flags2 */

/*
 * Flags passed to in_pcblookup*(), inp_smr_lock() and inp_next().
 */
typedef	enum {
	INPLOOKUP_WILDCARD = 0x00000001,	/* Allow wildcard sockets. */
	INPLOOKUP_RLOCKPCB = 0x00000002,	/* Return inpcb read-locked. */
	INPLOOKUP_WLOCKPCB = 0x00000004,	/* Return inpcb write-locked. */
} inp_lookup_t;

#define	INPLOOKUP_MASK	(INPLOOKUP_WILDCARD | INPLOOKUP_RLOCKPCB | \
	    INPLOOKUP_WLOCKPCB)
#define	INPLOOKUP_LOCKMASK	(INPLOOKUP_RLOCKPCB | INPLOOKUP_WLOCKPCB)

#define	sotoinpcb(so)	((struct inpcb *)(so)->so_pcb)

#define	INP_SOCKAF(so) so->so_proto->pr_domain->dom_family

#define	INP_CHECK_SOCKAF(so, af)	(INP_SOCKAF(so) == af)

#ifdef _KERNEL
VNET_DECLARE(int, ipport_reservedhigh);
VNET_DECLARE(int, ipport_reservedlow);
VNET_DECLARE(int, ipport_lowfirstauto);
VNET_DECLARE(int, ipport_lowlastauto);
VNET_DECLARE(int, ipport_firstauto);
VNET_DECLARE(int, ipport_lastauto);
VNET_DECLARE(int, ipport_hifirstauto);
VNET_DECLARE(int, ipport_hilastauto);
VNET_DECLARE(int, ipport_randomized);

#define	V_ipport_reservedhigh	VNET(ipport_reservedhigh)
#define	V_ipport_reservedlow	VNET(ipport_reservedlow)
#define	V_ipport_lowfirstauto	VNET(ipport_lowfirstauto)
#define	V_ipport_lowlastauto	VNET(ipport_lowlastauto)
#define	V_ipport_firstauto	VNET(ipport_firstauto)
#define	V_ipport_lastauto	VNET(ipport_lastauto)
#define	V_ipport_hifirstauto	VNET(ipport_hifirstauto)
#define	V_ipport_hilastauto	VNET(ipport_hilastauto)
#define	V_ipport_randomized	VNET(ipport_randomized)

void	in_pcbinfo_init(struct inpcbinfo *, struct inpcbstorage *,
	    u_int, u_int);
void	in_pcbinfo_destroy(struct inpcbinfo *);
void	in_pcbstorage_init(void *);
void	in_pcbstorage_destroy(void *);

void	in_pcbpurgeif0(struct inpcbinfo *, struct ifnet *);
int	in_pcballoc(struct socket *, struct inpcbinfo *);
int	in_pcbbind(struct inpcb *, struct sockaddr_in *, struct ucred *);
int	in_pcbbind_setup(struct inpcb *, struct sockaddr_in *, in_addr_t *,
	    u_short *, struct ucred *);
int	in_pcbconnect(struct inpcb *, struct sockaddr_in *, struct ucred *,
	    bool);
int	in_pcbconnect_setup(struct inpcb *, struct sockaddr_in *, in_addr_t *,
	    u_short *, in_addr_t *, u_short *, struct ucred *);
void	in_pcbdisconnect(struct inpcb *);
void	in_pcbdrop(struct inpcb *);
void	in_pcbfree(struct inpcb *);
int	in_pcbinshash(struct inpcb *);
int	in_pcbladdr(struct inpcb *, struct in_addr *, struct in_addr *,
	    struct ucred *);
int	in_pcblbgroup_numa(struct inpcb *, int arg);
struct inpcb *
	in_pcblookup(struct inpcbinfo *, struct in_addr, u_int,
	    struct in_addr, u_int, int, struct ifnet *);
struct inpcb *
	in_pcblookup_mbuf(struct inpcbinfo *, struct in_addr, u_int,
	    struct in_addr, u_int, int, struct ifnet *, struct mbuf *);
void	in_pcbnotifyall(struct inpcbinfo *pcbinfo, struct in_addr,
	    int, struct inpcb *(*)(struct inpcb *, int));
void	in_pcbref(struct inpcb *);
void	in_pcbrehash(struct inpcb *);
void	in_pcbremhash_locked(struct inpcb *);
bool	in_pcbrele(struct inpcb *, inp_lookup_t);
bool	in_pcbrele_rlocked(struct inpcb *);
bool	in_pcbrele_wlocked(struct inpcb *);

typedef bool inp_match_t(const struct inpcb *, void *);
struct inpcb_iterator {
	const struct inpcbinfo	*ipi;
	struct inpcb		*inp;
	inp_match_t		*match;
	void			*ctx;
	int			hash;
#define	INP_ALL_LIST		-1
	const inp_lookup_t	lock;
};

/* Note: sparse initializers guarantee .inp = NULL. */
#define	INP_ITERATOR(_ipi, _lock, _match, _ctx)		\
	{						\
		.ipi = (_ipi),				\
		.lock = (_lock),			\
		.hash = INP_ALL_LIST,			\
		.match = (_match),			\
		.ctx = (_ctx),				\
	}
#define	INP_ALL_ITERATOR(_ipi, _lock)			\
	{						\
		.ipi = (_ipi),				\
		.lock = (_lock),			\
		.hash = INP_ALL_LIST,			\
	}

struct inpcb *inp_next(struct inpcb_iterator *);
void	in_losing(struct inpcb *);
void	in_pcbsetsolabel(struct socket *so);
int	in_getpeeraddr(struct socket *so, struct sockaddr **nam);
int	in_getsockaddr(struct socket *so, struct sockaddr **nam);
struct sockaddr *
	in_sockaddr(in_port_t port, struct in_addr *addr);
void	in_pcbsosetlabel(struct socket *so);
#ifdef RATELIMIT
int
in_pcboutput_txrtlmt_locked(struct inpcb *, struct ifnet *,
	    struct mbuf *, uint32_t);
int	in_pcbattach_txrtlmt(struct inpcb *, struct ifnet *, uint32_t, uint32_t,
	    uint32_t, struct m_snd_tag **);
void	in_pcbdetach_txrtlmt(struct inpcb *);
void    in_pcbdetach_tag(struct m_snd_tag *);
int	in_pcbmodify_txrtlmt(struct inpcb *, uint32_t);
int	in_pcbquery_txrtlmt(struct inpcb *, uint32_t *);
int	in_pcbquery_txrlevel(struct inpcb *, uint32_t *);
void	in_pcboutput_txrtlmt(struct inpcb *, struct ifnet *, struct mbuf *);
void	in_pcboutput_eagain(struct inpcb *);
#endif
#endif /* _KERNEL */

#endif /* !_NETINET_IN_PCB_H_ */