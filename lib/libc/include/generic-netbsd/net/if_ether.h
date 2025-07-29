/*	$NetBSD: if_ether.h,v 1.89 2022/06/20 08:14:48 yamaguchi Exp $	*/

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
 *	@(#)if_ether.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NET_IF_ETHER_H_
#define _NET_IF_ETHER_H_

#ifdef _KERNEL
#ifdef _KERNEL_OPT
#include "opt_mbuftrace.h"
#endif
#include <sys/mbuf.h>
#endif

#ifndef _STANDALONE
#include <net/if.h>
#endif

/*
 * Some basic Ethernet constants.
 */
#define	ETHER_ADDR_LEN	6	/* length of an Ethernet address */
#define	ETHER_TYPE_LEN	2	/* length of the Ethernet type field */
#define	ETHER_CRC_LEN	4	/* length of the Ethernet CRC */
#define	ETHER_HDR_LEN	((ETHER_ADDR_LEN * 2) + ETHER_TYPE_LEN)
#define	ETHER_MIN_LEN	64	/* minimum frame length, including CRC */
#define	ETHER_MAX_LEN	1518	/* maximum frame length, including CRC */
#define	ETHER_MAX_LEN_JUMBO 9018 /* maximum jumbo frame len, including CRC */

/*
 * Some Ethernet extensions.
 */
#define	ETHER_VLAN_ENCAP_LEN	4     /* length of 802.1Q VLAN encapsulation */
#define	EVL_VLANOFTAG(tag)	((tag) & 4095)		/* VLAN ID */
#define	EVL_PRIOFTAG(tag)	(((tag) >> 13) & 7)	/* Priority */
#define	EVL_CFIOFTAG(tag)	(((tag) >> 12) & 1)	/* CFI */
#define	ETHER_PPPOE_ENCAP_LEN	8	/* length of PPPoE encapsulation */

/*
 * Mbuf adjust factor to force 32-bit alignment of IP header.
 * Drivers should do m_adj(m, ETHER_ALIGN) when setting up a
 * receive so the upper layers get the IP header properly aligned
 * past the 14-byte Ethernet header.
 */
#define	ETHER_ALIGN	2	/* driver adjust for IP hdr alignment */

/*
 * Ethernet address - 6 octets
 * this is only used by the ethers(3) functions.
 */
struct ether_addr {
	uint8_t ether_addr_octet[ETHER_ADDR_LEN];
};

/*
 * Structure of a 10Mb/s Ethernet header.
 */
struct ether_header {
	uint8_t  ether_dhost[ETHER_ADDR_LEN];
	uint8_t  ether_shost[ETHER_ADDR_LEN];
	uint16_t ether_type;
};

#include <net/ethertypes.h>

#define	ETHER_IS_MULTICAST(addr) (*(addr) & 0x01) /* is address mcast/bcast? */
#define	ETHER_IS_LOCAL(addr) (*(addr) & 0x02) /* is address local? */

#define	ETHERMTU_JUMBO	(ETHER_MAX_LEN_JUMBO - ETHER_HDR_LEN - ETHER_CRC_LEN)
#define	ETHERMTU	(ETHER_MAX_LEN - ETHER_HDR_LEN - ETHER_CRC_LEN)
#define	ETHERMIN	(ETHER_MIN_LEN - ETHER_HDR_LEN - ETHER_CRC_LEN)

/*
 * Compute the maximum frame size based on ethertype (i.e. possible
 * encapsulation) and whether or not an FCS is present.
 */
#define	ETHER_MAX_FRAME(ifp, etype, hasfcs)				\
	((ifp)->if_mtu + ETHER_HDR_LEN +				\
	 ((hasfcs) ? ETHER_CRC_LEN : 0) +				\
	 (((etype) == ETHERTYPE_VLAN) ? ETHER_VLAN_ENCAP_LEN : 0) +	\
	 (((etype) == ETHERTYPE_PPPOE) ? ETHER_PPPOE_ENCAP_LEN : 0))

/*
 * Ethernet CRC32 polynomials (big- and little-endian verions).
 */
#define	ETHER_CRC_POLY_LE	0xedb88320
#define	ETHER_CRC_POLY_BE	0x04c11db6

#ifndef _STANDALONE

/*
 * Ethernet-specific mbuf flags.
 */
#define	M_HASFCS	M_LINK0	/* FCS included at end of frame */
#define	M_PROMISC	M_LINK1	/* this packet is not for us */

#ifdef _KERNEL
/*
 * Macro to map an IP multicast address to an Ethernet multicast address.
 * The high-order 25 bits of the Ethernet address are statically assigned,
 * and the low-order 23 bits are taken from the low end of the IP address.
 */
#define ETHER_MAP_IP_MULTICAST(ipaddr, enaddr)				\
	/* const struct in_addr *ipaddr; */				\
	/* uint8_t enaddr[ETHER_ADDR_LEN]; */				\
do {									\
	(enaddr)[0] = 0x01;						\
	(enaddr)[1] = 0x00;						\
	(enaddr)[2] = 0x5e;						\
	(enaddr)[3] = ((const uint8_t *)ipaddr)[1] & 0x7f;		\
	(enaddr)[4] = ((const uint8_t *)ipaddr)[2];			\
	(enaddr)[5] = ((const uint8_t *)ipaddr)[3];			\
} while (/*CONSTCOND*/0)
/*
 * Macro to map an IP6 multicast address to an Ethernet multicast address.
 * The high-order 16 bits of the Ethernet address are statically assigned,
 * and the low-order 32 bits are taken from the low end of the IP6 address.
 */
#define ETHER_MAP_IPV6_MULTICAST(ip6addr, enaddr)			\
	/* struct in6_addr *ip6addr; */					\
	/* uint8_t enaddr[ETHER_ADDR_LEN]; */				\
{                                                                       \
	(enaddr)[0] = 0x33;						\
	(enaddr)[1] = 0x33;						\
	(enaddr)[2] = ((const uint8_t *)ip6addr)[12];			\
	(enaddr)[3] = ((const uint8_t *)ip6addr)[13];			\
	(enaddr)[4] = ((const uint8_t *)ip6addr)[14];			\
	(enaddr)[5] = ((const uint8_t *)ip6addr)[15];			\
}
#endif

struct mii_data;

struct ethercom;

typedef int (*ether_cb_t)(struct ethercom *);
typedef int (*ether_vlancb_t)(struct ethercom *, uint16_t, bool);

/*
 * Structure shared between the ethernet driver modules and
 * the multicast list code.  For example, each ec_softc or il_softc
 * begins with this structure.
 */
struct ethercom {
	struct	ifnet ec_if;			/* network-visible interface */
	LIST_HEAD(, ether_multi) ec_multiaddrs;	/* list of ether multicast
						   addrs */
	int	ec_multicnt;			/* length of ec_multiaddrs
						   list */
	int	ec_capabilities;		/* capabilities, provided by
						   driver */
	int	ec_capenable;			/* tells hardware which
						   capabilities to enable */

	int	ec_nvlans;			/* # VLANs on this interface */
	SIMPLEQ_HEAD(, vlanid_list) ec_vids;	/* list of VLAN IDs */
	/* The device handle for the MII bus child device. */
	struct mii_data				*ec_mii;
	struct ifmedia				*ec_ifmedia;
	/*
	 * Called after a change to ec_if.if_flags.  Returns
	 * ENETRESET if the device should be reinitialized with
	 * ec_if.if_init, 0 on success, not 0 on failure.
	 */
	ether_cb_t				ec_ifflags_cb;
	/*
	 * Called whenever a vlan interface is configured or unconfigured.
	 * Args include the vlan tag and a flag indicating whether the tag is
	 * being added or removed.
	 */
	ether_vlancb_t				ec_vlan_cb;
	/* Hooks called at the beginning of detach of this interface */
	khook_list_t				*ec_ifdetach_hooks;
	kmutex_t				*ec_lock;
	/* Flags used only by the kernel */
	int					ec_flags;
#ifdef MBUFTRACE
	struct	mowner ec_rx_mowner;		/* mbufs received */
	struct	mowner ec_tx_mowner;		/* mbufs transmitted */
#endif
};

#define	ETHERCAP_VLAN_MTU	0x00000001 /* VLAN-compatible MTU */
#define	ETHERCAP_VLAN_HWTAGGING	0x00000002 /* hardware VLAN tag support */
#define	ETHERCAP_JUMBO_MTU	0x00000004 /* 9000 byte MTU supported */
#define	ETHERCAP_VLAN_HWFILTER	0x00000008 /* iface hw can filter vlan tag */
#define	ETHERCAP_EEE		0x00000010 /* Energy Efficiency Ethernet */
#define	ETHERCAP_MASK		0x0000001f

#define	ECCAPBITS		\
	"\020"			\
	"\1VLAN_MTU"		\
	"\2VLAN_HWTAGGING"	\
	"\3JUMBO_MTU"		\
	"\4VLAN_HWFILTER"	\
	"\5EEE"

/* ioctl() for Ethernet capabilities */
struct eccapreq {
	char		eccr_name[IFNAMSIZ];	/* if name, e.g. "en0" */
	int		eccr_capabilities;	/* supported capabiliites */
	int		eccr_capenable;		/* capabilities enabled */
};

/* sysctl for Ethernet multicast addresses */
struct ether_multi_sysctl {
	u_int   enm_refcount;
	uint8_t enm_addrlo[ETHER_ADDR_LEN];
	uint8_t enm_addrhi[ETHER_ADDR_LEN];
};

#ifdef	_KERNEL
/*
 * Flags for ec_flags
 */
/* Store IFF_ALLMULTI in ec_flags instead of if_flags to avoid data races. */
#define ETHER_F_ALLMULTI	__BIT(0)

extern const uint8_t etherbroadcastaddr[ETHER_ADDR_LEN];
extern const uint8_t ethermulticastaddr_slowprotocols[ETHER_ADDR_LEN];
extern const uint8_t ether_ipmulticast_min[ETHER_ADDR_LEN];
extern const uint8_t ether_ipmulticast_max[ETHER_ADDR_LEN];

void	ether_set_ifflags_cb(struct ethercom *, ether_cb_t);
void	ether_set_vlan_cb(struct ethercom *, ether_vlancb_t);
int	ether_ioctl(struct ifnet *, u_long, void *);
int	ether_addmulti(const struct sockaddr *, struct ethercom *);
int	ether_delmulti(const struct sockaddr *, struct ethercom *);
int	ether_multiaddr(const struct sockaddr *, uint8_t[], uint8_t[]);
void    ether_input(struct ifnet *, struct mbuf *);

/*
 * Ethernet multicast address structure.  There is one of these for each
 * multicast address or range of multicast addresses that we are supposed
 * to listen to on a particular interface.  They are kept in a linked list,
 * rooted in the interface's ethercom structure.
 */
struct ether_multi {
	uint8_t enm_addrlo[ETHER_ADDR_LEN]; /* low  or only address of range */
	uint8_t enm_addrhi[ETHER_ADDR_LEN]; /* high or only address of range */
	u_int	enm_refcount;		/* no. claims to this addr/range */
	LIST_ENTRY(ether_multi) enm_list;
};

/*
 * Structure used by macros below to remember position when stepping through
 * all of the ether_multi records.
 */
struct ether_multistep {
	struct ether_multi  *e_enm;
};

/*
 * lookup the ether_multi record for a given range of Ethernet
 * multicast addresses connected to a given ethercom structure.
 * If no matching record is found, NULL is returned.
 */
static __inline struct ether_multi *
ether_lookup_multi(const uint8_t *addrlo, const uint8_t *addrhi,
    const struct ethercom *ec)
{
	struct ether_multi *enm;

	LIST_FOREACH(enm, &ec->ec_multiaddrs, enm_list) {
		if (memcmp(enm->enm_addrlo, addrlo, ETHER_ADDR_LEN) != 0)
			continue;
		if (memcmp(enm->enm_addrhi, addrhi, ETHER_ADDR_LEN) != 0)
			continue;

		break;
	}

	return enm;
}

/*
 * step through all of the ether_multi records, one at a time.
 * The current position is remembered in "step", which the caller must
 * provide.  ether_first_multi(), below, must be called to initialize "step"
 * and get the first record.  Both functions return a NULL when there
 * are no remaining records.
 */
static __inline struct ether_multi *
ether_next_multi(struct ether_multistep *step)
{
	struct ether_multi *enm;

	enm = step->e_enm;
	if (enm != NULL)
		step->e_enm = LIST_NEXT(enm, enm_list);

	return enm;
}
#define ETHER_NEXT_MULTI(step, enm)		\
	/* struct ether_multistep step; */	\
	/* struct ether_multi *enm; */		\
	(enm) = ether_next_multi(&(step))

static __inline struct ether_multi *
ether_first_multi(struct ether_multistep *step, const struct ethercom *ec)
{

	step->e_enm = LIST_FIRST(&ec->ec_multiaddrs);

	return ether_next_multi(step);
}

#define ETHER_FIRST_MULTI(step, ec, enm)		\
	/* struct ether_multistep step; */		\
	/* struct ethercom *ec; */			\
	/* struct ether_multi *enm; */			\
	(enm) = ether_first_multi(&(step), (ec))

#define ETHER_LOCK(ec)		mutex_enter((ec)->ec_lock)
#define ETHER_UNLOCK(ec)	mutex_exit((ec)->ec_lock)

/*
 * Ethernet 802.1Q VLAN structures.
 */

/* for ethercom */
struct vlanid_list {
	uint16_t vid;
	SIMPLEQ_ENTRY(vlanid_list) vid_list;
};

/* add VLAN tag to input/received packet */
static __inline void
vlan_set_tag(struct mbuf *m, uint16_t vlantag)
{
	/* VLAN tag contains priority, CFI and VLAN ID */
	KASSERT((m->m_flags & M_PKTHDR) != 0);
	m->m_pkthdr.ether_vtag = vlantag;
	m->m_flags |= M_VLANTAG;
	return;
}

/* extract VLAN ID value from a VLAN tag */
static __inline uint16_t
vlan_get_tag(struct mbuf *m)
{
	KASSERT((m->m_flags & M_PKTHDR) != 0);
	KASSERT(m->m_flags & M_VLANTAG);
	return m->m_pkthdr.ether_vtag;
}

static __inline bool
vlan_has_tag(struct mbuf *m)
{
	return (m->m_flags & M_VLANTAG) != 0;
}

static __inline bool
vlan_is_hwtag_enabled(struct ifnet *_ifp)
{
	struct ethercom *ec = (void *)_ifp;

	if (ec->ec_capenable & ETHERCAP_VLAN_HWTAGGING)
		return true;

	return false;
}

/* test if any VLAN is configured for this interface */
#define VLAN_ATTACHED(ec)	((ec)->ec_nvlans > 0)

void	etherinit(void);
void	ether_ifattach(struct ifnet *, const uint8_t *);
void	ether_ifdetach(struct ifnet *);
int	ether_mediachange(struct ifnet *);
void	ether_mediastatus(struct ifnet *, struct ifmediareq *);
void *	ether_ifdetachhook_establish(struct ifnet *,
	    void (*)(void *), void *arg);
void	ether_ifdetachhook_disestablish(struct ifnet *,
	    void *, kmutex_t *);

char	*ether_sprintf(const uint8_t *);
char	*ether_snprintf(char *, size_t, const uint8_t *);

uint32_t ether_crc32_le(const uint8_t *, size_t);
uint32_t ether_crc32_be(const uint8_t *, size_t);

int	ether_aton_r(u_char *, size_t, const char *);
int	ether_enable_vlan_mtu(struct ifnet *);
int	ether_disable_vlan_mtu(struct ifnet *);
int	ether_add_vlantag(struct ifnet *, uint16_t, bool *);
int	ether_del_vlantag(struct ifnet *, uint16_t);
int	ether_inject_vlantag(struct mbuf **, uint16_t, uint16_t);
struct mbuf *
	ether_strip_vlantag(struct mbuf *);
#else
/*
 * Prototype ethers(3) functions.
 */
#include <sys/cdefs.h>
__BEGIN_DECLS
char *	ether_ntoa(const struct ether_addr *);
struct ether_addr *
	ether_aton(const char *);
int	ether_ntohost(char *, const struct ether_addr *);
int	ether_hostton(const char *, struct ether_addr *);
int	ether_line(const char *, struct ether_addr *, char *);
__END_DECLS
#endif

#endif /* _STANDALONE */

#endif /* !_NET_IF_ETHER_H_ */