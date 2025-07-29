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

#ifndef	_NET_IF_PRIVATE_H_
#define	_NET_IF_PRIVATE_H_

#ifdef	_KERNEL
/*
 * Structure defining a network interface.
 */
struct ifnet {
	/* General book keeping of interface lists. */
	CK_STAILQ_ENTRY(ifnet) if_link; 	/* all struct ifnets are chained (CK_) */
	LIST_ENTRY(ifnet) if_clones;	/* interfaces of a cloner */
	CK_STAILQ_HEAD(, ifg_list) if_groups; /* linked list of groups per if (CK_) */
					/* protected by if_addr_lock */
	u_char	if_alloctype;		/* if_type at time of allocation */
	uint8_t	if_numa_domain;		/* NUMA domain of device */
	/* Driver and protocol specific information that remains stable. */
	void	*if_softc;		/* pointer to driver state */
	void	*if_llsoftc;		/* link layer softc */
	void	*if_l2com;		/* pointer to protocol bits */
	const char *if_dname;		/* driver name */
	int	if_dunit;		/* unit or IF_DUNIT_NONE */
	u_short	if_index;		/* numeric abbreviation for this if  */
	u_short	if_idxgen;		/* ... and its generation count */
	char	if_xname[IFNAMSIZ];	/* external name (name + unit) */
	char	*if_description;	/* interface description */

	/* Variable fields that are touched by the stack and drivers. */
	int	if_flags;		/* up/down, broadcast, etc. */
	int	if_drv_flags;		/* driver-managed status flags */
	int	if_capabilities;	/* interface features & capabilities */
	int	if_capabilities2;	/* part 2 */
	int	if_capenable;		/* enabled features & capabilities */
	int	if_capenable2;		/* part 2 */
	void	*if_linkmib;		/* link-type-specific MIB data */
	size_t	if_linkmiblen;		/* length of above data */
	u_int	if_refcount;		/* reference count */

	/* These fields are shared with struct if_data. */
	uint8_t		if_type;	/* ethernet, tokenring, etc */
	uint8_t		if_addrlen;	/* media address length */
	uint8_t		if_hdrlen;	/* media header length */
	uint8_t		if_link_state;	/* current link state */
	uint32_t	if_mtu;		/* maximum transmission unit */
	uint32_t	if_metric;	/* routing metric (external only) */
	uint64_t	if_baudrate;	/* linespeed */
	uint64_t	if_hwassist;	/* HW offload capabilities, see IFCAP */
	time_t		if_epoch;	/* uptime at attach or stat reset */
	struct timeval	if_lastchange;	/* time of last administrative change */

	struct  ifaltq if_snd;		/* output queue (includes altq) */
	struct	task if_linktask;	/* task for link change events */
	struct	task if_addmultitask;	/* task for SIOCADDMULTI */

	/* Addresses of different protocol families assigned to this if. */
	struct mtx if_addr_lock;	/* lock to protect address lists */
		/*
		 * if_addrhead is the list of all addresses associated to
		 * an interface.
		 * Some code in the kernel assumes that first element
		 * of the list has type AF_LINK, and contains sockaddr_dl
		 * addresses which store the link-level address and the name
		 * of the interface.
		 * However, access to the AF_LINK address through this
		 * field is deprecated. Use if_addr instead.
		 */
	struct	ifaddrhead if_addrhead;	/* linked list of addresses per if */
	struct	ifmultihead if_multiaddrs; /* multicast addresses configured */
	int	if_amcount;		/* number of all-multicast requests */
	struct	ifaddr	*if_addr;	/* pointer to link-level address */
	void	*if_hw_addr;		/* hardware link-level address */
	const u_int8_t *if_broadcastaddr; /* linklevel broadcast bytestring */
	struct	mtx if_afdata_lock;
	void	*if_afdata[AF_MAX];
	int	if_afdata_initialized;

	/* Additional features hung off the interface. */
	u_int	if_fib;			/* interface FIB */
	struct	vnet *if_vnet;		/* pointer to network stack instance */
	struct	vnet *if_home_vnet;	/* where this ifnet originates from */
	struct  ifvlantrunk *if_vlantrunk; /* pointer to 802.1q data */
	struct	bpf_if *if_bpf;		/* packet filter structure */
	int	if_pcount;		/* number of promiscuous listeners */
	void	*if_bridge;		/* bridge glue */
	void	*if_lagg;		/* lagg glue */
	void	*if_pf_kif;		/* pf glue */
	struct	carp_if *if_carp;	/* carp interface structure */
	struct	label *if_label;	/* interface MAC label */
	struct	netmap_adapter *if_netmap; /* netmap(4) softc */

	/* Various procedures of the layer2 encapsulation and drivers. */
	if_output_fn_t if_output;	/* output routine (enqueue) */
	if_input_fn_t if_input;		/* input routine (from h/w driver) */
	struct mbuf *(*if_bridge_input)(struct ifnet *, struct mbuf *);
	int	(*if_bridge_output)(struct ifnet *, struct mbuf *, struct sockaddr *,
		    struct rtentry *);
	void (*if_bridge_linkstate)(struct ifnet *ifp);
	if_start_fn_t	if_start;	/* initiate output routine */
	if_ioctl_fn_t	if_ioctl;	/* ioctl routine */
	if_init_fn_t	if_init;	/* Init routine */
	int	(*if_resolvemulti)	/* validate/resolve multicast */
		(struct ifnet *, struct sockaddr **, struct sockaddr *);
	if_qflush_fn_t	if_qflush;	/* flush any queue */
	if_transmit_fn_t if_transmit;   /* initiate output routine */

	if_reassign_fn_t if_reassign;		/* reassign to vnet routine */
	if_get_counter_t if_get_counter; /* get counter values */
	int	(*if_requestencap)	/* make link header from request */
		(struct ifnet *, struct if_encap_req *);

	/* Statistics. */
	counter_u64_t	if_counters[IFCOUNTERS];

	/* Stuff that's only temporary and doesn't belong here. */

	/*
	 * Network adapter TSO limits:
	 * ===========================
	 *
	 * If the "if_hw_tsomax" field is zero the maximum segment
	 * length limit does not apply. If the "if_hw_tsomaxsegcount"
	 * or the "if_hw_tsomaxsegsize" field is zero the TSO segment
	 * count limit does not apply. If all three fields are zero,
	 * there is no TSO limit.
	 *
	 * NOTE: The TSO limits should reflect the values used in the
	 * BUSDMA tag a network adapter is using to load a mbuf chain
	 * for transmission. The TCP/IP network stack will subtract
	 * space for all linklevel and protocol level headers and
	 * ensure that the full mbuf chain passed to the network
	 * adapter fits within the given limits.
	 */
	u_int	if_hw_tsomax;		/* TSO maximum size in bytes */
	u_int	if_hw_tsomaxsegcount;	/* TSO maximum segment count */
	u_int	if_hw_tsomaxsegsize;	/* TSO maximum segment size in bytes */

	/*
	 * Network adapter send tag support:
	 */
	if_snd_tag_alloc_t *if_snd_tag_alloc;

	/* Ratelimit (packet pacing) */
	if_ratelimit_query_t *if_ratelimit_query;
	if_ratelimit_setup_t *if_ratelimit_setup;

	/* Ethernet PCP */
	uint8_t if_pcp;

	/*
	 * Debugnet (Netdump) hooks to be called while in db/panic.
	 */
	struct debugnet_methods *if_debugnet_methods;
	struct epoch_context	if_epoch_ctx;

	/*
	 * Spare fields to be added before branching a stable branch, so
	 * that structure can be enhanced without changing the kernel
	 * binary interface.
	 */
	int	if_ispare[4];		/* general use */
};

#define	IF_AFDATA_LOCK_INIT(ifp)	\
	mtx_init(&(ifp)->if_afdata_lock, "if_afdata", NULL, MTX_DEF)

#define	IF_AFDATA_WLOCK(ifp)	mtx_lock(&(ifp)->if_afdata_lock)
#define	IF_AFDATA_WUNLOCK(ifp)	mtx_unlock(&(ifp)->if_afdata_lock)
#define	IF_AFDATA_LOCK(ifp)	IF_AFDATA_WLOCK(ifp)
#define	IF_AFDATA_UNLOCK(ifp)	IF_AFDATA_WUNLOCK(ifp)
#define	IF_AFDATA_TRYLOCK(ifp)	mtx_trylock(&(ifp)->if_afdata_lock)
#define	IF_AFDATA_DESTROY(ifp)	mtx_destroy(&(ifp)->if_afdata_lock)

#define	IF_AFDATA_LOCK_ASSERT(ifp)	MPASS(in_epoch(net_epoch_preempt) || mtx_owned(&(ifp)->if_afdata_lock))
#define	IF_AFDATA_WLOCK_ASSERT(ifp)	mtx_assert(&(ifp)->if_afdata_lock, MA_OWNED)
#define	IF_AFDATA_UNLOCK_ASSERT(ifp)	mtx_assert(&(ifp)->if_afdata_lock, MA_NOTOWNED)

#define IF_LLADDR(ifp)							\
    LLADDR((struct sockaddr_dl *)((ifp)->if_addr->ifa_addr))

#endif	/* _KERNEL */

#endif	/* _NET_IF_PRIVATE_H_ */