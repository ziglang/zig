/*	$NetBSD: in_var.h,v 1.103 2022/11/19 08:00:51 yamt Exp $	*/

/*-
 * Copyright (c) 1998 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Public Access Networks Corporation ("Panix").  It was developed under
 * contract to Panix by Eric Haszlakiewicz and Thor Lancelot Simon.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
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
 *	@(#)in_var.h	8.2 (Berkeley) 1/9/95
 */

#ifndef _NETINET_IN_VAR_H_
#define _NETINET_IN_VAR_H_

#include <sys/queue.h>

#define IN_IFF_TENTATIVE	0x01	/* tentative address */
#define IN_IFF_DUPLICATED	0x02	/* DAD detected duplicate */
#define IN_IFF_DETACHED		0x04	/* may be detached from the link */
#define IN_IFF_TRYTENTATIVE	0x08	/* intent to try DAD */

#define IN_IFFBITS \
    "\020\1TENTATIVE\2DUPLICATED\3DETACHED\4TRYTENTATIVE"

/* do not input/output */
#define IN_IFF_NOTREADY \
    (IN_IFF_TRYTENTATIVE | IN_IFF_TENTATIVE | IN_IFF_DUPLICATED)

/*
 * Interface address, Internet version.  One of these structures
 * is allocated for each interface with an Internet address.
 * The ifaddr structure contains the protocol-independent part
 * of the structure and is assumed to be first.
 */
struct in_ifaddr {
	struct	ifaddr ia_ifa;		/* protocol-independent info */
#define	ia_ifp		ia_ifa.ifa_ifp
#define ia_flags	ia_ifa.ifa_flags
					/* ia_{,sub}net{,mask} in host order */
	u_int32_t ia_net;		/* network number of interface */
	u_int32_t ia_netmask;		/* mask of net part */
	u_int32_t ia_subnet;		/* subnet number, including net */
	u_int32_t ia_subnetmask;	/* mask of subnet part */
	struct	in_addr ia_netbroadcast; /* to recognize net broadcasts */
	LIST_ENTRY(in_ifaddr) ia_hash;	/* entry in bucket of inet addresses */
	TAILQ_ENTRY(in_ifaddr) ia_list;	/* list of internet addresses */
	struct	sockaddr_in ia_addr;	/* reserve space for interface name */
	struct	sockaddr_in ia_dstaddr;	/* reserve space for broadcast addr */
#define	ia_broadaddr	ia_dstaddr
	struct	sockaddr_in ia_sockmask; /* reserve space for general netmask */
	LIST_HEAD(, in_multi) ia_multiaddrs; /* list of multicast addresses */
	struct	in_multi *ia_allhosts;	/* multicast address record for
					   the allhosts multicast group */
	uint16_t ia_idsalt;		/* ip_id salt for this ia */
	int	ia4_flags;		/* address flags */
	void	(*ia_dad_start) (struct ifaddr *);	/* DAD start function */
	void	(*ia_dad_stop) (struct ifaddr *);	/* DAD stop function */
	time_t	ia_dad_defended;	/* last time of DAD defence */

#ifdef _KERNEL
	struct pslist_entry	ia_hash_pslist_entry;
	struct pslist_entry	ia_pslist_entry;
#endif
};

struct in_nbrinfo {
	char ifname[IFNAMSIZ];	/* if name, e.g. "en0" */
	struct in_addr addr;	/* IPv4 address of the neighbor */
	long	asked;		/* number of queries already sent for this addr */
	int	state;		/* reachability state */
	int	expire;		/* lifetime for NDP state transition */
};

#ifdef _KERNEL
static __inline void
ia4_acquire(struct in_ifaddr *ia, struct psref *psref)
{

	KASSERT(ia != NULL);
	ifa_acquire(&ia->ia_ifa, psref);
}

static __inline void
ia4_release(struct in_ifaddr *ia, struct psref *psref)
{

	if (ia == NULL)
		return;
	ifa_release(&ia->ia_ifa, psref);
}
#endif

struct	in_aliasreq {
	char	ifra_name[IFNAMSIZ];		/* if name, e.g. "en0" */
	struct	sockaddr_in ifra_addr;
	struct	sockaddr_in ifra_dstaddr;
#define	ifra_broadaddr	ifra_dstaddr
	struct	sockaddr_in ifra_mask;
};

/*
 * Given a pointer to an in_ifaddr (ifaddr),
 * return a pointer to the addr as a sockaddr_in.
 */
#define	IA_SIN(ia) (&(((struct in_ifaddr *)(ia))->ia_addr))

#ifdef _KERNEL

/* Note: 61, 127, 251, 509, 1021, 2039 are good. */
#ifndef IN_IFADDR_HASH_SIZE
#define IN_IFADDR_HASH_SIZE	509
#endif

/*
 * This is a bit unconventional, and wastes a little bit of space, but
 * because we want a very even hash function we don't use & in_ifaddrhash
 * here, but rather % the hash size, which should obviously be prime.
 */

#define	IN_IFADDR_HASH(x) in_ifaddrhashtbl[(u_long)(x) % IN_IFADDR_HASH_SIZE]

LIST_HEAD(in_ifaddrhashhead, in_ifaddr);	/* Type of the hash head */
TAILQ_HEAD(in_ifaddrhead, in_ifaddr);		/* Type of the list head */

extern	u_long in_ifaddrhash;			/* size of hash table - 1 */
extern  struct in_ifaddrhashhead *in_ifaddrhashtbl;	/* Hash table head */
extern  struct in_ifaddrhead in_ifaddrhead;		/* List head (in ip_input) */

extern pserialize_t in_ifaddrhash_psz;
extern struct pslist_head *in_ifaddrhashtbl_pslist;
extern u_long in_ifaddrhash_pslist;
extern struct pslist_head in_ifaddrhead_pslist;

#define IN_IFADDR_HASH_PSLIST(x)					\
	in_ifaddrhashtbl_pslist[(u_long)(x) % IN_IFADDR_HASH_SIZE]

#define IN_ADDRHASH_READER_FOREACH(__ia, __addr)			\
	PSLIST_READER_FOREACH((__ia), &IN_IFADDR_HASH_PSLIST(__addr),	\
	    struct in_ifaddr, ia_hash_pslist_entry)
#define IN_ADDRHASH_WRITER_INSERT_HEAD(__ia)				\
	PSLIST_WRITER_INSERT_HEAD(					\
	    &IN_IFADDR_HASH_PSLIST((__ia)->ia_addr.sin_addr.s_addr),	\
	    (__ia), ia_hash_pslist_entry)
#define IN_ADDRHASH_WRITER_REMOVE(__ia)					\
	PSLIST_WRITER_REMOVE((__ia), ia_hash_pslist_entry)
#define IN_ADDRHASH_ENTRY_INIT(__ia)					\
	PSLIST_ENTRY_INIT((__ia), ia_hash_pslist_entry);
#define IN_ADDRHASH_ENTRY_DESTROY(__ia)					\
	PSLIST_ENTRY_DESTROY((__ia), ia_hash_pslist_entry);
#define IN_ADDRHASH_READER_NEXT(__ia)					\
	PSLIST_READER_NEXT((__ia), struct in_ifaddr, ia_hash_pslist_entry)

#define IN_ADDRLIST_ENTRY_INIT(__ia)					\
	PSLIST_ENTRY_INIT((__ia), ia_pslist_entry)
#define IN_ADDRLIST_ENTRY_DESTROY(__ia)					\
	PSLIST_ENTRY_DESTROY((__ia), ia_pslist_entry);
#define IN_ADDRLIST_READER_EMPTY()					\
	(PSLIST_READER_FIRST(&in_ifaddrhead_pslist, struct in_ifaddr,	\
	                     ia_pslist_entry) == NULL)
#define IN_ADDRLIST_READER_FIRST()					\
	PSLIST_READER_FIRST(&in_ifaddrhead_pslist, struct in_ifaddr,	\
	                    ia_pslist_entry)
#define IN_ADDRLIST_READER_NEXT(__ia)					\
	PSLIST_READER_NEXT((__ia), struct in_ifaddr, ia_pslist_entry)
#define IN_ADDRLIST_READER_FOREACH(__ia)				\
	PSLIST_READER_FOREACH((__ia), &in_ifaddrhead_pslist,		\
	                      struct in_ifaddr, ia_pslist_entry)
#define IN_ADDRLIST_WRITER_INSERT_HEAD(__ia)				\
	PSLIST_WRITER_INSERT_HEAD(&in_ifaddrhead_pslist, (__ia),	\
	    ia_pslist_entry)
#define IN_ADDRLIST_WRITER_REMOVE(__ia)					\
	PSLIST_WRITER_REMOVE((__ia), ia_pslist_entry)
#define IN_ADDRLIST_WRITER_FOREACH(__ia)				\
	PSLIST_WRITER_FOREACH((__ia), &in_ifaddrhead_pslist,		\
	                      struct in_ifaddr, ia_pslist_entry)
#define IN_ADDRLIST_WRITER_FIRST()					\
	PSLIST_WRITER_FIRST(&in_ifaddrhead_pslist, struct in_ifaddr,	\
	                    ia_pslist_entry)
#define IN_ADDRLIST_WRITER_NEXT(__ia)					\
	PSLIST_WRITER_NEXT((__ia), struct in_ifaddr, ia_pslist_entry)
#define IN_ADDRLIST_WRITER_INSERT_AFTER(__ia, __new)			\
	PSLIST_WRITER_INSERT_AFTER((__ia), (__new), ia_pslist_entry)
#define IN_ADDRLIST_WRITER_EMPTY()					\
	(PSLIST_WRITER_FIRST(&in_ifaddrhead_pslist, struct in_ifaddr,	\
	    ia_pslist_entry) == NULL)
#define IN_ADDRLIST_WRITER_INSERT_TAIL(__new)				\
	do {								\
		if (IN_ADDRLIST_WRITER_EMPTY()) {			\
			IN_ADDRLIST_WRITER_INSERT_HEAD((__new));	\
		} else {						\
			struct in_ifaddr *__ia;				\
			IN_ADDRLIST_WRITER_FOREACH(__ia) {		\
				if (IN_ADDRLIST_WRITER_NEXT(__ia) == NULL) { \
					IN_ADDRLIST_WRITER_INSERT_AFTER(__ia,\
					    (__new));			\
					break;				\
				}					\
			}						\
		}							\
	} while (0)

extern	const	int	inetctlerrmap[];

/*
 * Find whether an internet address (in_addr) belongs to one
 * of our interfaces (in_ifaddr).  NULL if the address isn't ours.
 */
static __inline struct in_ifaddr *
in_get_ia(struct in_addr addr)
{
	struct in_ifaddr *ia;

	IN_ADDRHASH_READER_FOREACH(ia, addr.s_addr) {
		if (in_hosteq(ia->ia_addr.sin_addr, addr))
			break;
	}

	return ia;
}

static __inline struct in_ifaddr *
in_get_ia_psref(struct in_addr addr, struct psref *psref)
{
	struct in_ifaddr *ia;
	int s;

	s = pserialize_read_enter();
	ia = in_get_ia(addr);
	if (ia != NULL)
		ia4_acquire(ia, psref);
	pserialize_read_exit(s);

	return ia;
}

/*
 * Find whether an internet address (in_addr) belongs to a specified
 * interface.  NULL if the address isn't ours.
 */
static __inline struct in_ifaddr *
in_get_ia_on_iface(struct in_addr addr, struct ifnet *ifp)
{
	struct in_ifaddr *ia;

	IN_ADDRHASH_READER_FOREACH(ia, addr.s_addr) {
		if (in_hosteq(ia->ia_addr.sin_addr, addr) &&
		    ia->ia_ifp == ifp)
			break;
	}

	return ia;
}

static __inline struct in_ifaddr *
in_get_ia_on_iface_psref(struct in_addr addr, struct ifnet *ifp, struct psref *psref)
{
	struct in_ifaddr *ia;
	int s;

	s = pserialize_read_enter();
	ia = in_get_ia_on_iface(addr, ifp);
	if (ia != NULL)
		ia4_acquire(ia, psref);
	pserialize_read_exit(s);

	return ia;
}

/*
 * Find an internet address structure (in_ifaddr) corresponding
 * to a given interface (ifnet structure).
 */
static __inline struct in_ifaddr *
in_get_ia_from_ifp(struct ifnet *ifp)
{
	struct ifaddr *ifa;

	IFADDR_READER_FOREACH(ifa, ifp) {
		if (ifa->ifa_addr->sa_family == AF_INET)
			break;
	}

	return ifatoia(ifa);
}

static __inline struct in_ifaddr *
in_get_ia_from_ifp_psref(struct ifnet *ifp, struct psref *psref)
{
	struct in_ifaddr *ia;
	int s;

	s = pserialize_read_enter();
	ia = in_get_ia_from_ifp(ifp);
	if (ia != NULL)
		ia4_acquire(ia, psref);
	pserialize_read_exit(s);

	return ia;
}

#include <netinet/in_selsrc.h>
/*
 * IPv4 per-interface state.
 */
struct in_ifinfo {
	struct lltable		*ii_llt;	/* ARP state */
	struct in_ifsysctl	*ii_selsrc;
#ifdef MBUFTRACE
	struct mowner		ii_mowner;
#endif
};

#endif /* _KERNEL */

/*
 * Internet multicast address structure.  There is one of these for each IP
 * multicast group to which this host belongs on a given network interface.
 * They are kept in a linked list, rooted in the interface's in_ifaddr
 * structure.
 */
struct router_info;

struct in_multi {
	LIST_ENTRY(in_multi) inm_list;	/* list of multicast addresses */
	struct	router_info *inm_rti;	/* router version info */
	struct	ifnet *inm_ifp;		/* back pointer to ifnet */
	struct	in_addr inm_addr;	/* IP multicast address */
	u_int	inm_refcount;		/* no. membership claims by sockets */
	u_int	inm_timer;		/* IGMP membership report timer */
	u_int	inm_state;		/* state of membership */
};

#ifdef _KERNEL

#include <net/pktqueue.h>
#include <sys/cprng.h>

extern pktqueue_t *ip_pktq;

extern int ip_dad_count;		/* Duplicate Address Detection probes */

static inline bool
ip_dad_enabled(void)
{
#if NARP > 0
	return ip_dad_count > 0;
#else
	return false;
#endif
}

#if defined(INET) && NARP > 0
extern int arp_debug;
#define ARPLOGADDR(a) IN_PRINT(_ipbuf, a)
#define ARPLOG(level, fmt, args...) 					\
	do {								\
		char _ipbuf[INET_ADDRSTRLEN];	 			\
		(void)_ipbuf;						\
		if (arp_debug) 						\
			log(level, "%s: " fmt, __func__, ##args);	\
	} while (/*CONSTCOND*/0)
#else
#define ARPLOG(level, fmt, args...)
#endif

/*
 * Structure used by functions below to remember position when stepping
 * through all of the in_multi records.
 */
struct in_multistep {
	int i_n;
	struct in_multi *i_inm;
};

bool in_multi_group(struct in_addr, struct ifnet *, int);
struct in_multi *in_first_multi(struct in_multistep *);
struct in_multi *in_next_multi(struct in_multistep *);
struct in_multi *in_lookup_multi(struct in_addr, struct ifnet *);
struct in_multi *in_addmulti(struct in_addr *, struct ifnet *);
void in_delmulti(struct in_multi *);

void in_multi_lock(int);
void in_multi_unlock(void);
int in_multi_lock_held(void);

struct ifaddr;

int	in_ifinit(struct ifnet *, struct in_ifaddr *,
    const struct sockaddr_in *, const struct sockaddr_in *, int);
void	in_savemkludge(struct in_ifaddr *);
void	in_restoremkludge(struct in_ifaddr *, struct ifnet *);
void	in_purgemkludge(struct ifnet *);
void	in_setmaxmtu(void);
int	in_control(struct socket *, u_long, void *, struct ifnet *);
void	in_purgeaddr(struct ifaddr *);
void	in_purgeif(struct ifnet *);
void	in_addrhash_insert(struct in_ifaddr *);
void	in_addrhash_remove(struct in_ifaddr *);
int	ipflow_fastforward(struct mbuf *);

extern uint16_t		ip_id;
extern int		ip_do_randomid;

static __inline uint16_t
ip_randomid(void)
{

	uint16_t id = (uint16_t)cprng_fast32();
	return id ? id : 1;
}

/*
 * ip_newid_range: "allocate" num contiguous IP IDs.
 *
 * => Return the first ID.
 */
static __inline uint16_t
ip_newid_range(const struct in_ifaddr *ia, u_int num)
{
	uint16_t id;

	if (ip_do_randomid) {
		/* XXX ignore num */
		return ip_randomid();
	}

	/* Never allow an IP ID of 0 (detect wrap). */
	if ((uint16_t)(ip_id + num) < ip_id) {
		ip_id = 1;
	}
	id = htons(ip_id);
	ip_id += num;
	return id;
}

static __inline uint16_t
ip_newid(const struct in_ifaddr *ia)
{

	return ip_newid_range(ia, 1);
}

#ifdef SYSCTLFN_PROTO
int	sysctl_inpcblist(SYSCTLFN_PROTO);
#endif

#define LLTABLE(ifp)	\
	((struct in_ifinfo *)(ifp)->if_afdata[AF_INET])->ii_llt

#endif	/* !_KERNEL */

/* INET6 stuff */
#include <netinet6/in6_var.h>

#endif /* !_NETINET_IN_VAR_H_ */