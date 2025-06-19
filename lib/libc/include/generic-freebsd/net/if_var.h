/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1986, 1989, 1993
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
 *	From: @(#)if.h	8.1 (Berkeley) 6/10/93
 */

#ifndef	_NET_IF_VAR_H_
#define	_NET_IF_VAR_H_

/*
 * Structures defining a network interface, providing a packet
 * transport mechanism (ala level 0 of the PUP protocols).
 *
 * Each interface accepts output datagrams of a specified maximum
 * length, and provides higher level routines with input datagrams
 * received from its medium.
 *
 * Output occurs when the routine if_output is called, with three parameters:
 *	(*ifp->if_output)(ifp, m, dst, ro)
 * Here m is the mbuf chain to be sent and dst is the destination address.
 * The output routine encapsulates the supplied datagram if necessary,
 * and then transmits it on its medium.
 *
 * On input, each interface unwraps the data received by it, and either
 * places it on the input queue of an internetwork datagram routine
 * and posts the associated software interrupt, or passes the datagram to a raw
 * packet input routine.
 *
 * Routines exist for locating interfaces by their addresses
 * or for locating an interface on a certain network, as well as more general
 * routing and gateway routines maintaining information used to locate
 * interfaces.  These routines live in the files if.c and route.c
 */

struct	rtentry;		/* ifa_rtrequest */
struct	socket;
struct	carp_if;
struct	carp_softc;
struct  ifvlantrunk;
struct	route;			/* if_output */
struct	vnet;
struct	ifmedia;
struct	netmap_adapter;
struct	debugnet_methods;

#ifdef _KERNEL
#include <sys/_eventhandler.h>
#include <sys/mbuf.h>		/* ifqueue only? */
#include <sys/buf_ring.h>
#include <net/vnet.h>
#endif /* _KERNEL */
#include <sys/ck.h>
#include <sys/counter.h>
#include <sys/epoch.h>
#include <sys/lock.h>		/* XXX */
#include <sys/mutex.h>		/* struct ifqueue */
#include <sys/rwlock.h>		/* XXX */
#include <sys/sx.h>		/* XXX */
#include <sys/_task.h>		/* if_link_task */
#define	IF_DUNIT_NONE	-1

#include <net/altq/if_altq.h>

CK_STAILQ_HEAD(ifnethead, ifnet);	/* we use TAILQs so that the order of */
CK_STAILQ_HEAD(ifaddrhead, ifaddr);	/* instantiation is preserved in the list */
CK_STAILQ_HEAD(ifmultihead, ifmultiaddr);
CK_STAILQ_HEAD(ifgrouphead, ifg_group);

#ifdef _KERNEL
VNET_DECLARE(struct pfil_head *, link_pfil_head);
#define	V_link_pfil_head	VNET(link_pfil_head)
#define	PFIL_ETHER_NAME		"ethernet"

#define	HHOOK_IPSEC_INET	0
#define	HHOOK_IPSEC_INET6	1
#define	HHOOK_IPSEC_COUNT	2
VNET_DECLARE(struct hhook_head *, ipsec_hhh_in[HHOOK_IPSEC_COUNT]);
VNET_DECLARE(struct hhook_head *, ipsec_hhh_out[HHOOK_IPSEC_COUNT]);
#define	V_ipsec_hhh_in	VNET(ipsec_hhh_in)
#define	V_ipsec_hhh_out	VNET(ipsec_hhh_out)
#endif /* _KERNEL */

typedef enum {
	IFCOUNTER_IPACKETS = 0,
	IFCOUNTER_IERRORS,
	IFCOUNTER_OPACKETS,
	IFCOUNTER_OERRORS,
	IFCOUNTER_COLLISIONS,
	IFCOUNTER_IBYTES,
	IFCOUNTER_OBYTES,
	IFCOUNTER_IMCASTS,
	IFCOUNTER_OMCASTS,
	IFCOUNTER_IQDROPS,
	IFCOUNTER_OQDROPS,
	IFCOUNTER_NOPROTO,
	IFCOUNTERS /* Array size. */
} ift_counter;

typedef	void (*if_start_fn_t)(if_t);
typedef	int (*if_ioctl_fn_t)(if_t, u_long, caddr_t);
typedef	void (*if_init_fn_t)(void *);
typedef	void (*if_input_fn_t)(if_t, struct mbuf *);
typedef	int (*if_output_fn_t)(if_t, struct mbuf *, const struct sockaddr *,
    struct route *);
typedef void (*if_qflush_fn_t)(if_t);
typedef int (*if_transmit_fn_t)(if_t, struct mbuf *);
typedef	uint64_t (*if_get_counter_t)(if_t, ift_counter);
typedef	void (*if_reassign_fn_t)(if_t, struct vnet *, char *);

struct ifnet_hw_tsomax {
	u_int	tsomaxbytes;	/* TSO total burst length limit in bytes */
	u_int	tsomaxsegcount;	/* TSO maximum segment count */
	u_int	tsomaxsegsize;	/* TSO maximum segment size in bytes */
};

/* Interface encap request types */
typedef enum {
	IFENCAP_LL = 1			/* pre-calculate link-layer header */
} ife_type;

/*
 * The structure below allows to request various pre-calculated L2/L3 headers
 * for different media. Requests varies by type (rtype field).
 *
 * IFENCAP_LL type: pre-calculates link header based on address family
 *   and destination lladdr.
 *
 *   Input data fields:
 *     buf: pointer to destination buffer
 *     bufsize: buffer size
 *     flags: IFENCAP_FLAG_BROADCAST if destination is broadcast
 *     family: address family defined by AF_ constant.
 *     lladdr: pointer to link-layer address
 *     lladdr_len: length of link-layer address
 *     hdata: pointer to L3 header (optional, used for ARP requests).
 *   Output data fields:
 *     buf: encap data is stored here
 *     bufsize: resulting encap length is stored here
 *     lladdr_off: offset of link-layer address from encap hdr start
 *     hdata: L3 header may be altered if necessary
 */

struct if_encap_req {
	u_char		*buf;		/* Destination buffer (w) */
	size_t		bufsize;	/* size of provided buffer (r) */
	ife_type	rtype;		/* request type (r) */
	uint32_t	flags;		/* Request flags (r) */
	int		family;		/* Address family AF_* (r) */
	int		lladdr_off;	/* offset from header start (w) */
	int		lladdr_len;	/* lladdr length (r) */
	char		*lladdr;	/* link-level address pointer (r) */
	char		*hdata;		/* Upper layer header data (rw) */
};

#define	IFENCAP_FLAG_BROADCAST	0x02	/* Destination is broadcast */

/*
 * Network interface send tag support. The storage of "struct
 * m_snd_tag" comes from the network driver and it is free to allocate
 * as much additional space as it wants for its own use.
 */
struct ktls_session;
struct m_snd_tag;

#define	IF_SND_TAG_TYPE_RATE_LIMIT 0
#define	IF_SND_TAG_TYPE_UNLIMITED 1
#define	IF_SND_TAG_TYPE_TLS 2
#define	IF_SND_TAG_TYPE_TLS_RATE_LIMIT 3
#define	IF_SND_TAG_TYPE_TLS_RX 4
#define	IF_SND_TAG_TYPE_MAX 5

struct if_snd_tag_alloc_header {
	uint32_t type;		/* send tag type, see IF_SND_TAG_XXX */
	uint32_t flowid;	/* mbuf hash value */
	uint32_t flowtype;	/* mbuf hash type */
	uint8_t numa_domain;	/* numa domain of associated inp */
};

struct if_snd_tag_alloc_rate_limit {
	struct if_snd_tag_alloc_header hdr;
	uint64_t max_rate;	/* in bytes/s */
	uint32_t flags;		/* M_NOWAIT or M_WAITOK */
	uint32_t reserved;	/* alignment */
};

struct if_snd_tag_alloc_tls {
	struct if_snd_tag_alloc_header hdr;
	struct inpcb *inp;
	const struct ktls_session *tls;
};

struct if_snd_tag_alloc_tls_rx {
	struct if_snd_tag_alloc_header hdr;
	struct inpcb *inp;
	const struct ktls_session *tls;
	uint16_t vlan_id;	/* valid if non-zero */
};

struct if_snd_tag_alloc_tls_rate_limit {
	struct if_snd_tag_alloc_header hdr;
	struct inpcb *inp;
	const struct ktls_session *tls;
	uint64_t max_rate;	/* in bytes/s */
};

struct if_snd_tag_rate_limit_params {
	uint64_t max_rate;	/* in bytes/s */
	uint32_t queue_level;	/* 0 (empty) .. 65535 (full) */
#define	IF_SND_QUEUE_LEVEL_MIN 0
#define	IF_SND_QUEUE_LEVEL_MAX 65535
	uint32_t flags;		/* M_NOWAIT or M_WAITOK */
};

struct if_snd_tag_modify_tls_rx {
	/* TCP sequence number of TLS header in host endian format */
	uint32_t tls_hdr_tcp_sn;

	/*
	 * TLS record length, including all headers, data and trailers.
	 * If the tls_rec_length is zero, it means HW encryption resumed.
	 */
	uint32_t tls_rec_length;

	/* TLS sequence number in host endian format */
	uint64_t tls_seq_number;
};

union if_snd_tag_alloc_params {
	struct if_snd_tag_alloc_header hdr;
	struct if_snd_tag_alloc_rate_limit rate_limit;
	struct if_snd_tag_alloc_rate_limit unlimited;
	struct if_snd_tag_alloc_tls tls;
	struct if_snd_tag_alloc_tls_rx tls_rx;
	struct if_snd_tag_alloc_tls_rate_limit tls_rate_limit;
};

union if_snd_tag_modify_params {
	struct if_snd_tag_rate_limit_params rate_limit;
	struct if_snd_tag_rate_limit_params unlimited;
	struct if_snd_tag_rate_limit_params tls_rate_limit;
	struct if_snd_tag_modify_tls_rx tls_rx;
};

union if_snd_tag_query_params {
	struct if_snd_tag_rate_limit_params rate_limit;
	struct if_snd_tag_rate_limit_params unlimited;
	struct if_snd_tag_rate_limit_params tls_rate_limit;
};

typedef int (if_snd_tag_alloc_t)(if_t, union if_snd_tag_alloc_params *,
    struct m_snd_tag **);
typedef int (if_snd_tag_modify_t)(struct m_snd_tag *, union if_snd_tag_modify_params *);
typedef int (if_snd_tag_query_t)(struct m_snd_tag *, union if_snd_tag_query_params *);
typedef void (if_snd_tag_free_t)(struct m_snd_tag *);
typedef struct m_snd_tag *(if_next_send_tag_t)(struct m_snd_tag *);

struct if_snd_tag_sw {
	if_snd_tag_modify_t *snd_tag_modify;
	if_snd_tag_query_t *snd_tag_query;
	if_snd_tag_free_t *snd_tag_free;
	if_next_send_tag_t *next_snd_tag;
	u_int	type;			/* One of IF_SND_TAG_TYPE_*. */
};

/* Query return flags */
#define RT_NOSUPPORT	  0x00000000	/* Not supported */
#define RT_IS_INDIRECT    0x00000001	/*
					 * Interface like a lagg, select
					 * the actual interface for
					 * capabilities.
					 */
#define RT_IS_SELECTABLE  0x00000002	/*
					 * No rate table, you select
					 * rates and the first
					 * number_of_rates are created.
					 */
#define RT_IS_FIXED_TABLE 0x00000004	/* A fixed table is attached */
#define RT_IS_UNUSABLE	  0x00000008	/* It is not usable for this */
#define RT_IS_SETUP_REQ	  0x00000010	/* The interface setup must be called before use */

struct if_ratelimit_query_results {
	const uint64_t *rate_table;	/* Pointer to table if present */
	uint32_t flags;			/* Flags indicating results */
	uint32_t max_flows;		/* Max flows using, 0=unlimited */
	uint32_t number_of_rates;	/* How many unique rates can be created */
	uint32_t min_segment_burst;	/* The amount the adapter bursts at each send */
};

typedef void (if_ratelimit_query_t)(if_t,
    struct if_ratelimit_query_results *);
typedef int (if_ratelimit_setup_t)(if_t, uint64_t, uint32_t);
#define	IF_NODOM	255
/*
 * Locks for address lists on the network interface.
 */
#define	IF_ADDR_LOCK_INIT(if)	mtx_init(&(if)->if_addr_lock, "if_addr_lock", NULL, MTX_DEF)
#define	IF_ADDR_LOCK_DESTROY(if)	mtx_destroy(&(if)->if_addr_lock)

#define	IF_ADDR_WLOCK(if)	mtx_lock(&(if)->if_addr_lock)
#define	IF_ADDR_WUNLOCK(if)	mtx_unlock(&(if)->if_addr_lock)
#define	IF_ADDR_LOCK_ASSERT(if)	MPASS(in_epoch(net_epoch_preempt) || mtx_owned(&(if)->if_addr_lock))
#define	IF_ADDR_WLOCK_ASSERT(if) mtx_assert(&(if)->if_addr_lock, MA_OWNED)

#ifdef _KERNEL
/* interface link layer address change event */
typedef void (*iflladdr_event_handler_t)(void *, if_t);
EVENTHANDLER_DECLARE(iflladdr_event, iflladdr_event_handler_t);
/* interface address change event */
typedef void (*ifaddr_event_handler_t)(void *, if_t);
EVENTHANDLER_DECLARE(ifaddr_event, ifaddr_event_handler_t);
typedef void (*ifaddr_event_ext_handler_t)(void *, if_t, struct ifaddr *, int);
EVENTHANDLER_DECLARE(ifaddr_event_ext, ifaddr_event_ext_handler_t);
#define	IFADDR_EVENT_ADD	0
#define	IFADDR_EVENT_DEL	1
/* new interface arrival event */
typedef void (*ifnet_arrival_event_handler_t)(void *, if_t);
EVENTHANDLER_DECLARE(ifnet_arrival_event, ifnet_arrival_event_handler_t);
/* interface departure event */
typedef void (*ifnet_departure_event_handler_t)(void *, if_t);
EVENTHANDLER_DECLARE(ifnet_departure_event, ifnet_departure_event_handler_t);
/* Interface link state change event */
typedef void (*ifnet_link_event_handler_t)(void *, if_t, int);
EVENTHANDLER_DECLARE(ifnet_link_event, ifnet_link_event_handler_t);
/* Interface up/down event */
#define IFNET_EVENT_UP		0
#define IFNET_EVENT_DOWN	1
#define IFNET_EVENT_PCP		2	/* priority code point, PCP */
#define	IFNET_EVENT_UPDATE_BAUDRATE	3

typedef void (*ifnet_event_fn)(void *, if_t ifp, int event);
EVENTHANDLER_DECLARE(ifnet_event, ifnet_event_fn);

/*
 * interface groups
 */
struct ifg_group {
	char				 ifg_group[IFNAMSIZ];
	u_int				 ifg_refcnt;
	void				*ifg_pf_kif;
	CK_STAILQ_HEAD(, ifg_member)	 ifg_members; /* (CK_) */
	CK_STAILQ_ENTRY(ifg_group)		 ifg_next; /* (CK_) */
};

struct ifg_member {
	CK_STAILQ_ENTRY(ifg_member)	 ifgm_next; /* (CK_) */
	if_t				 ifgm_ifp;
};

struct ifg_list {
	struct ifg_group	*ifgl_group;
	CK_STAILQ_ENTRY(ifg_list)	 ifgl_next; /* (CK_) */
};

#ifdef _SYS_EVENTHANDLER_H_
/* group attach event */
typedef void (*group_attach_event_handler_t)(void *, struct ifg_group *);
EVENTHANDLER_DECLARE(group_attach_event, group_attach_event_handler_t);
/* group detach event */
typedef void (*group_detach_event_handler_t)(void *, struct ifg_group *);
EVENTHANDLER_DECLARE(group_detach_event, group_detach_event_handler_t);
/* group change event */
typedef void (*group_change_event_handler_t)(void *, const char *);
EVENTHANDLER_DECLARE(group_change_event, group_change_event_handler_t);
#endif /* _SYS_EVENTHANDLER_H_ */

/*
 * 72 was chosen below because it is the size of a TCP/IP
 * header (40) + the minimum mss (32).
 */
#define	IF_MINMTU	72
#define	IF_MAXMTU	65535

#define	TOEDEV(ifp)		if_getllsoftc(ifp)
#define	SETTOEDEV(ifp, sc)	if_setllsoftc((ifp), (sc))

/*
 * The ifaddr structure contains information about one address
 * of an interface.  They are maintained by the different address families,
 * are allocated and attached when an address is set, and are linked
 * together so all addresses for an interface can be located.
 *
 * NOTE: a 'struct ifaddr' is always at the beginning of a larger
 * chunk of malloc'ed memory, where we store the three addresses
 * (ifa_addr, ifa_dstaddr and ifa_netmask) referenced here.
 */
struct ifaddr {
	struct	sockaddr *ifa_addr;	/* address of interface */
	struct	sockaddr *ifa_dstaddr;	/* other end of p-to-p link */
#define	ifa_broadaddr	ifa_dstaddr	/* broadcast address interface */
	struct	sockaddr *ifa_netmask;	/* used to determine subnet */
	if_t		 ifa_ifp;		/* back-pointer to interface */
	struct	carp_softc *ifa_carp;	/* pointer to CARP data */
	CK_STAILQ_ENTRY(ifaddr) ifa_link;	/* queue macro glue */
	u_short	ifa_flags;		/* mostly rt_flags for cloning */
#define	IFA_ROUTE	RTF_UP		/* route installed */
#define	IFA_RTSELF	RTF_HOST	/* loopback route to self installed */
	u_int	ifa_refcnt;		/* references to this structure */

	counter_u64_t	ifa_ipackets;
	counter_u64_t	ifa_opackets;
	counter_u64_t	ifa_ibytes;
	counter_u64_t	ifa_obytes;
	struct	epoch_context	ifa_epoch_ctx;
};

struct ifaddr *	ifa_alloc(size_t size, int flags);
void	ifa_free(struct ifaddr *ifa);
void	ifa_ref(struct ifaddr *ifa);
int __result_use_check ifa_try_ref(struct ifaddr *ifa);

/*
 * Multicast address structure.  This is analogous to the ifaddr
 * structure except that it keeps track of multicast addresses.
 */
#define IFMA_F_ENQUEUED		0x1
struct ifmultiaddr {
	CK_STAILQ_ENTRY(ifmultiaddr) ifma_link; /* queue macro glue */
	struct	sockaddr *ifma_addr; 	/* address this membership is for */
	struct	sockaddr *ifma_lladdr;	/* link-layer translation, if any */
	if_t	ifma_ifp;		/* back-pointer to interface */
	u_int	ifma_refcount;		/* reference count */
	int	ifma_flags;
	void	*ifma_protospec;	/* protocol-specific state, if any */
	struct	ifmultiaddr *ifma_llifma; /* pointer to ifma for ifma_lladdr */
	struct	epoch_context	ifma_epoch_ctx;
};

extern	struct sx ifnet_sxlock;

#define	IFNET_WLOCK()		sx_xlock(&ifnet_sxlock)
#define	IFNET_WUNLOCK()		sx_xunlock(&ifnet_sxlock)
#define	IFNET_RLOCK_ASSERT()	sx_assert(&ifnet_sxlock, SA_SLOCKED)
#define	IFNET_WLOCK_ASSERT()	sx_assert(&ifnet_sxlock, SA_XLOCKED)
#define	IFNET_RLOCK()		sx_slock(&ifnet_sxlock)
#define	IFNET_RUNLOCK()		sx_sunlock(&ifnet_sxlock)

/*
 * Look up an ifnet given its index.  The returned value protected from
 * being freed by the network epoch.  The _ref variant also acquires a
 * reference that must be freed using if_rele().
 */
if_t ifnet_byindex(u_int);
if_t ifnet_byindex_ref(u_int);

/*
 * ifnet_byindexgen() looks up ifnet by index and generation count,
 * attempting to restore a weak pointer that had been stored across
 * the epoch.
 */
if_t ifnet_byindexgen(uint16_t idx, uint16_t gen);

VNET_DECLARE(struct ifnethead, ifnet);
VNET_DECLARE(struct ifgrouphead, ifg_head);
VNET_DECLARE(if_t, loif);	/* first loopback interface */

#define	V_ifnet		VNET(ifnet)
#define	V_ifg_head	VNET(ifg_head)
#define	V_loif		VNET(loif)

#ifdef MCAST_VERBOSE
#define MCDPRINTF printf
#else
#define MCDPRINTF(...)
#endif

int	if_addgroup(if_t, const char *);
int	if_delgroup(if_t, const char *);
int	if_addmulti(if_t, struct sockaddr *, struct ifmultiaddr **);
int	if_allmulti(if_t, int);
if_t	if_alloc(u_char);
if_t	if_alloc_dev(u_char, device_t dev);
void	if_attach(if_t);
void	if_dead(if_t);
int	if_delmulti(if_t, struct sockaddr *);
void	if_delmulti_ifma(struct ifmultiaddr *);
void	if_delmulti_ifma_flags(struct ifmultiaddr *, int flags);
void	if_detach(if_t);
void	if_purgeaddrs(if_t);
void	if_delallmulti(if_t);
void	if_down(if_t);
struct ifmultiaddr *
	if_findmulti(if_t, const struct sockaddr *);
void	if_freemulti(struct ifmultiaddr *ifma);
void	if_free(if_t);
void	if_initname(if_t, const char *, int);
void	if_link_state_change(if_t, int);
int	if_printf(if_t, const char *, ...) __printflike(2, 3);
int	if_log(if_t, int, const char *, ...) __printflike(3, 4);
void	if_ref(if_t);
void	if_rele(if_t);
bool	__result_use_check if_try_ref(if_t);
int	if_setlladdr(if_t, const u_char *, int);
int	if_tunnel_check_nesting(if_t, struct mbuf *, uint32_t, int);
void	if_up(if_t);
int	ifioctl(struct socket *, u_long, caddr_t, struct thread *);
int	ifpromisc(if_t, int);
if_t	ifunit(const char *);
if_t	ifunit_ref(const char *);

int	ifa_add_loopback_route(struct ifaddr *, struct sockaddr *);
int	ifa_del_loopback_route(struct ifaddr *, struct sockaddr *);
int	ifa_switch_loopback_route(struct ifaddr *, struct sockaddr *);

struct	ifaddr *ifa_ifwithaddr(const struct sockaddr *);
int		ifa_ifwithaddr_check(const struct sockaddr *);
struct	ifaddr *ifa_ifwithbroadaddr(const struct sockaddr *, int);
struct	ifaddr *ifa_ifwithdstaddr(const struct sockaddr *, int);
struct	ifaddr *ifa_ifwithnet(const struct sockaddr *, int, int);
struct	ifaddr *ifa_ifwithroute(int, const struct sockaddr *,
    const struct sockaddr *, u_int);
struct	ifaddr *ifaof_ifpforaddr(const struct sockaddr *, if_t);
int	ifa_preferred(struct ifaddr *, struct ifaddr *);

int	if_simloop(if_t ifp, struct mbuf *m, int af, int hlen);

typedef	void *if_com_alloc_t(u_char type, if_t ifp);
typedef	void if_com_free_t(void *com, u_char type);
void	if_register_com_alloc(u_char type, if_com_alloc_t *a, if_com_free_t *f);
void	if_deregister_com_alloc(u_char type);
void	if_data_copy(if_t, struct if_data *);
uint64_t if_get_counter_default(if_t, ift_counter);
void	if_inc_counter(if_t, ift_counter, int64_t);

uint64_t if_setbaudrate(if_t ifp, uint64_t baudrate);
uint64_t if_getbaudrate(const if_t ifp);
int if_setcapabilities(if_t ifp, int capabilities);
int if_setcapabilitiesbit(if_t ifp, int setbit, int clearbit);
int if_getcapabilities(const if_t ifp);
int if_togglecapenable(if_t ifp, int togglecap);
int if_setcapenable(if_t ifp, int capenable);
int if_setcapenablebit(if_t ifp, int setcap, int clearcap);
int if_getcapenable(const if_t ifp);
int if_setcapabilities2(if_t ifp, int capabilities);
int if_setcapabilities2bit(if_t ifp, int setbit, int clearbit);
int if_getcapabilities2(const if_t ifp);
int if_togglecapenable2(if_t ifp, int togglecap);
int if_setcapenable2(if_t ifp, int capenable);
int if_setcapenable2bit(if_t ifp, int setcap, int clearcap);
int if_getcapenable2(const if_t ifp);
int if_getdunit(const if_t ifp);
int if_getindex(const if_t ifp);
int if_getidxgen(const if_t ifp);
const char *if_getdname(const if_t ifp);
void if_setdname(if_t ifp, const char *name);
const char *if_name(if_t ifp);
int if_setname(if_t ifp, const char *name);
int if_rename(if_t ifp, char *new_name);
const char *if_getdescr(if_t ifp);
void if_setdescr(if_t ifp, char *descrbuf);
char *if_allocdescr(size_t sz, int malloc_flag);
void if_freedescr(char *descrbuf);
void if_setlastchange(if_t ifp);
int if_getalloctype(const if_t ifp);
int if_gettype(const if_t ifp);
int if_setdev(if_t ifp, void *dev);
int if_setdrvflagbits(if_t ifp, int if_setflags, int clear_flags);
int if_getdrvflags(const if_t ifp);
int if_setdrvflags(if_t ifp, int flags);
int if_getlinkstate(if_t ifp);
int if_clearhwassist(if_t ifp);
int if_sethwassistbits(if_t ifp, int toset, int toclear);
int if_sethwassist(if_t ifp, int hwassist_bit);
int if_gethwassist(const if_t ifp);
int if_togglehwassist(if_t ifp, int toggle_bits);
int if_setsoftc(if_t ifp, void *softc);
void *if_getsoftc(if_t ifp);
int if_setflags(if_t ifp, int flags);
void if_setllsoftc(if_t ifp, void *softc);
void *if_getllsoftc(if_t ifp);
u_int if_getfib(if_t ifp);
uint8_t if_getaddrlen(if_t ifp);
int if_gethwaddr(const if_t ifp, struct ifreq *);
const uint8_t *if_getbroadcastaddr(const if_t ifp);
void if_setbroadcastaddr(if_t ifp, const uint8_t *);
int if_setmtu(if_t ifp, int mtu);
int if_getmtu(const if_t ifp);
int if_getmtu_family(const if_t ifp, int family);
void if_notifymtu(if_t ifp);
int if_setflagbits(if_t ifp, int set, int clear);
int if_setflags(if_t ifp, int flags);
int if_getflags(const if_t ifp);
int if_getnumadomain(if_t ifp);
int if_sendq_empty(if_t ifp);
int if_setsendqready(if_t ifp);
int if_setsendqlen(if_t ifp, int tx_desc_count);
int if_sethwtsomax(if_t ifp, u_int if_hw_tsomax);
int if_sethwtsomaxsegcount(if_t ifp, u_int if_hw_tsomaxsegcount);
int if_sethwtsomaxsegsize(if_t ifp, u_int if_hw_tsomaxsegsize);
u_int if_gethwtsomax(const if_t ifp);
u_int if_gethwtsomaxsegcount(const if_t ifp);
u_int if_gethwtsomaxsegsize(const if_t ifp);
void if_setnetmapadapter(if_t ifp, struct netmap_adapter *na);
struct netmap_adapter *if_getnetmapadapter(if_t ifp);
void if_input(if_t ifp, struct mbuf* sendmp);
int if_sendq_prepend(if_t ifp, struct mbuf *m);
struct mbuf *if_dequeue(if_t ifp);
int if_setifheaderlen(if_t ifp, int len);
void if_setrcvif(struct mbuf *m, if_t ifp);
void if_setvtag(struct mbuf *m, u_int16_t tag);
u_int16_t if_getvtag(struct mbuf *m);
int if_vlantrunkinuse(if_t ifp);
caddr_t if_getlladdr(const if_t ifp);
struct vnet *if_getvnet(const if_t ifp);
void *if_gethandle(u_char);
void if_bpfmtap(if_t ifp, struct mbuf *m);
void if_etherbpfmtap(if_t ifp, struct mbuf *m);
void if_vlancap(if_t ifp);
int if_transmit(if_t ifp, struct mbuf *m);
void if_init(if_t ifp, void *ctx);
int if_ioctl(if_t ifp, u_long cmd, void *data);
int if_resolvemulti(if_t ifp, struct sockaddr **, struct sockaddr *);
uint64_t if_getcounter(if_t ifp, ift_counter counter);
struct label *if_getmaclabel(if_t ifp);
void if_setmaclabel(if_t ifp, struct label *label);
struct bpf_if *if_getbpf(if_t ifp);
uint8_t if_getpcp(if_t ifp);
void *if_getl2com(if_t ifp);
struct ifvlantrunk *if_getvlantrunk(if_t ifp);
bool if_altq_is_enabled(if_t ifp);

void *if_getafdata(if_t ifp, int);

int if_snd_tag_alloc(if_t ifp, union if_snd_tag_alloc_params *params,
    struct m_snd_tag **mstp);
/*
 * Traversing through interface address lists.
 */
struct sockaddr_dl;
typedef u_int iflladdr_cb_t(void *, struct sockaddr_dl *, u_int);
u_int if_foreach_lladdr(if_t, iflladdr_cb_t, void *);
u_int if_foreach_llmaddr(if_t, iflladdr_cb_t, void *);
u_int if_lladdr_count(if_t);
u_int if_llmaddr_count(if_t);
bool if_maddr_empty(if_t);

struct ifaddr * if_getifaddr(const if_t ifp);
typedef u_int if_addr_cb_t(void *, struct ifaddr *, u_int);
u_int if_foreach_addr_type(if_t ifp, int type, if_addr_cb_t cb, void *cb_arg);

typedef int (*if_foreach_cb_t)(if_t, void *);
typedef bool (*if_foreach_match_t)(if_t, void *);
int	if_foreach(if_foreach_cb_t, void *);
int	if_foreach_sleep(if_foreach_match_t, void *, if_foreach_cb_t, void *);

/* Opaque iterator structure for iterating over interfaces. */
struct if_iter {
	void *context[4];
};

if_t	if_iter_start(struct if_iter *);
if_t	if_iter_next(struct if_iter *);
void	if_iter_finish(struct if_iter *);

struct ifa_iter {
	void *context[4];
};

struct ifaddr *ifa_iter_start(if_t ifp, struct ifa_iter *iter);
struct ifaddr *ifa_iter_next(struct ifa_iter *iter);
void ifa_iter_finish(struct ifa_iter *iter);

/* Functions */
void if_setinitfn(if_t ifp, if_init_fn_t);
void if_setinputfn(if_t ifp, if_input_fn_t);
if_input_fn_t if_getinputfn(if_t ifp);
void if_setioctlfn(if_t ifp, if_ioctl_fn_t);
void if_setoutputfn(if_t ifp, if_output_fn_t);
void if_setstartfn(if_t ifp, if_start_fn_t);
if_start_fn_t if_getstartfn(if_t ifp);
void if_settransmitfn(if_t ifp, if_transmit_fn_t);
if_transmit_fn_t if_gettransmitfn(if_t ifp);
void if_setqflushfn(if_t ifp, if_qflush_fn_t);
void if_setgetcounterfn(if_t ifp, if_get_counter_t);
void if_setsndtagallocfn(if_t ifp, if_snd_tag_alloc_t);
void if_setdebugnet_methods(if_t, struct debugnet_methods *);
void if_setreassignfn(if_t ifp, if_reassign_fn_t);
void if_setratelimitqueryfn(if_t ifp, if_ratelimit_query_t);

/* TSO */
void if_hw_tsomax_common(if_t ifp, struct ifnet_hw_tsomax *);
int if_hw_tsomax_update(if_t ifp, struct ifnet_hw_tsomax *);

/* accessors for struct ifreq */
void *ifr_data_get_ptr(void *ifrp);
void *ifr_buffer_get_buffer(void *data);
size_t ifr_buffer_get_length(void *data);

int ifhwioctl(u_long, if_t, caddr_t, struct thread *);

#ifdef DEVICE_POLLING
enum poll_cmd { POLL_ONLY, POLL_AND_CHECK_STATUS };

typedef	int poll_handler_t(if_t ifp, enum poll_cmd cmd, int count);
int    ether_poll_register(poll_handler_t *h, if_t ifp);
int    ether_poll_deregister(if_t ifp);
#endif /* DEVICE_POLLING */

#endif /* _KERNEL */

#include <net/if_private.h>	/* XXX: temporary until drivers converted. */
#include <net/ifq.h>	/* XXXAO: temporary unconditional include */

#endif /* !_NET_IF_VAR_H_ */