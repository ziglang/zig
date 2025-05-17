/*	$NetBSD: if_bridgevar.h,v 1.37.4.1 2024/09/05 09:27:12 martin Exp $	*/

/*
 * Copyright 2001 Wasabi Systems, Inc.
 * All rights reserved.
 *
 * Written by Jason R. Thorpe for Wasabi Systems, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed for the NetBSD Project by
 *	Wasabi Systems, Inc.
 * 4. The name of Wasabi Systems, Inc. may not be used to endorse
 *    or promote products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY WASABI SYSTEMS, INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL WASABI SYSTEMS, INC
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Copyright (c) 1999, 2000 Jason L. Wright (jason@thought.net)
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by Jason L. Wright
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 * OpenBSD: if_bridge.h,v 1.14 2001/03/22 03:48:29 jason Exp
 */

/*
 * Data structure and control definitions for bridge interfaces.
 */

#ifndef _NET_IF_BRIDGEVAR_H_
#define _NET_IF_BRIDGEVAR_H_

#include <sys/callout.h>
#include <sys/queue.h>
#include <sys/mutex.h>
#include <sys/condvar.h>

/*
 * Commands used in the SIOCSDRVSPEC ioctl.  Note the lookup of the
 * bridge interface itself is keyed off the ifdrv structure.
 */
#define	BRDGADD			0	/* add bridge member (ifbreq) */
#define	BRDGDEL			1	/* delete bridge member (ifbreq) */
#define	BRDGGIFFLGS		2	/* get member if flags (ifbreq) */
#define	BRDGSIFFLGS		3	/* set member if flags (ifbreq) */
#define	BRDGSCACHE		4	/* set cache size (ifbrparam) */
#define	BRDGGCACHE		5	/* get cache size (ifbrparam) */
#define	OBRDGGIFS		6	/* get member list (ifbifconf) */
#define	OBRDGRTS		7	/* get address list (ifbaconf) */
#define	BRDGSADDR		8	/* set static address (ifbareq) */
#define	BRDGSTO			9	/* set cache timeout (ifbrparam) */
#define	BRDGGTO			10	/* get cache timeout (ifbrparam) */
#define	BRDGDADDR		11	/* delete address (ifbareq) */
#define	BRDGFLUSH		12	/* flush address cache (ifbreq) */

#define	BRDGGPRI		13	/* get priority (ifbrparam) */
#define	BRDGSPRI		14	/* set priority (ifbrparam) */
#define	BRDGGHT			15	/* get hello time (ifbrparam) */
#define	BRDGSHT			16	/* set hello time (ifbrparam) */
#define	BRDGGFD			17	/* get forward delay (ifbrparam) */
#define	BRDGSFD			18	/* set forward delay (ifbrparam) */
#define	BRDGGMA			19	/* get max age (ifbrparam) */
#define	BRDGSMA			20	/* set max age (ifbrparam) */
#define	BRDGSIFPRIO		21	/* set if priority (ifbreq) */
#define BRDGSIFCOST		22	/* set if path cost (ifbreq) */
#define BRDGGFILT	        23	/* get filter flags (ifbrparam) */
#define BRDGSFILT	        24	/* set filter flags (ifbrparam) */

#define	BRDGGIFS		25	/* get member list */
#define	BRDGRTS			26	/* get address list */

/*
 * Generic bridge control request.
 */
struct ifbreq {
	char		ifbr_ifsname[IFNAMSIZ];	/* member if name */
	uint32_t	ifbr_ifsflags;		/* member if flags */
	uint8_t		ifbr_state;		/* member if STP state */
	uint8_t		ifbr_priority;		/* member if STP priority */
	uint8_t		ifbr_path_cost;		/* member if STP cost */
	uint8_t		ifbr_portno;		/* member if port number */
};

/* BRDGGIFFLAGS, BRDGSIFFLAGS */
#define	IFBIF_LEARNING		0x01	/* if can learn */
#define	IFBIF_DISCOVER		0x02	/* if sends packets w/ unknown dest. */
#define	IFBIF_STP		0x04	/* if participates in spanning tree */
#define	IFBIF_PROTECTED		0x08	/* if participates in protected mode */

#define	IFBIFBITS	"\020\1LEARNING\2DISCOVER\3STP\4PROTECTED"

/* BRDGFLUSH */
#define	IFBF_FLUSHDYN		0x00	/* flush learned addresses only */
#define	IFBF_FLUSHALL		0x01	/* flush all addresses */

/* BRDGSFILT */
#define IFBF_FILT_USEIPF	0x00000001 /* enable ipf on bridge */
#define IFBF_FILT_MASK		0x00000001 /* mask of valid values */

/* STP port states */
#define	BSTP_IFSTATE_DISABLED	0
#define	BSTP_IFSTATE_LISTENING	1
#define	BSTP_IFSTATE_LEARNING	2
#define	BSTP_IFSTATE_FORWARDING	3
#define	BSTP_IFSTATE_BLOCKING	4

/*
 * Interface list structure.
 */
struct ifbifconf {
	uint32_t	ifbic_len;	/* buffer size */
	union {
		void *	ifbicu_buf;
		struct ifbreq *ifbicu_req;
	} ifbic_ifbicu;
#define	ifbic_buf	ifbic_ifbicu.ifbicu_buf
#define	ifbic_req	ifbic_ifbicu.ifbicu_req
};

/*
 * Bridge address request.
 */
struct ifbareq {
	char		ifba_ifsname[IFNAMSIZ];	/* member if name */
	time_t		ifba_expire;		/* address expire time */
	uint8_t		ifba_flags;		/* address flags */
	uint8_t		ifba_dst[ETHER_ADDR_LEN];/* destination address */
};

#define	IFBAF_TYPEMASK	0x03	/* address type mask */
#define	IFBAF_DYNAMIC	0x00	/* dynamically learned address */
#define	IFBAF_STATIC	0x01	/* static address */

#define	IFBAFBITS	"\020\1STATIC"

/*
 * Address list structure.
 */
struct ifbaconf {
	uint32_t	ifbac_len;	/* buffer size */
	union {
		void *ifbacu_buf;
		struct ifbareq *ifbacu_req;
	} ifbac_ifbacu;
#define	ifbac_buf	ifbac_ifbacu.ifbacu_buf
#define	ifbac_req	ifbac_ifbacu.ifbacu_req
};

/*
 * Bridge parameter structure.
 */
struct ifbrparam {
	union {
		uint32_t ifbrpu_int32;
		uint16_t ifbrpu_int16;
		uint8_t ifbrpu_int8;
	} ifbrp_ifbrpu;
};
#define	ifbrp_csize	ifbrp_ifbrpu.ifbrpu_int32	/* cache size */
#define	ifbrp_ctime	ifbrp_ifbrpu.ifbrpu_int32	/* cache time (sec) */
#define	ifbrp_prio	ifbrp_ifbrpu.ifbrpu_int16	/* bridge priority */
#define	ifbrp_hellotime	ifbrp_ifbrpu.ifbrpu_int8	/* hello time (sec) */
#define	ifbrp_fwddelay	ifbrp_ifbrpu.ifbrpu_int8	/* fwd time (sec) */
#define	ifbrp_maxage	ifbrp_ifbrpu.ifbrpu_int8	/* max age (sec) */
#define	ifbrp_filter	ifbrp_ifbrpu.ifbrpu_int32	/* filtering flags */

#ifdef _KERNEL
#ifdef _KERNEL_OPT
#include "opt_net_mpsafe.h"
#endif /* _KERNEL_OPT */

#include <sys/pserialize.h>
#include <sys/pslist.h>
#include <sys/psref.h>
#include <sys/workqueue.h>

#include <net/pktqueue.h>

/*
 * Timekeeping structure used in spanning tree code.
 */
struct bridge_timer {
	uint16_t	active;
	uint16_t	value;
};

struct bstp_config_unit {
	uint64_t	cu_rootid;
	uint64_t	cu_bridge_id;
	uint32_t	cu_root_path_cost;
	uint16_t	cu_message_age;
	uint16_t	cu_max_age;
	uint16_t	cu_hello_time;
	uint16_t	cu_forward_delay;
	uint16_t	cu_port_id;
	uint8_t		cu_message_type;
	uint8_t		cu_topology_change_acknowledgment;
	uint8_t		cu_topology_change;
};

struct bstp_tcn_unit {
	uint8_t		tu_message_type;
};

/*
 * Bridge interface list entry.
 */
struct bridge_iflist {
	struct pslist_entry	bif_next;
	uint64_t		bif_designated_root;
	uint64_t		bif_designated_bridge;
	uint32_t		bif_path_cost;
	uint32_t		bif_designated_cost;
	struct bridge_timer	bif_hold_timer;
	struct bridge_timer	bif_message_age_timer;
	struct bridge_timer	bif_forward_delay_timer;
	uint16_t		bif_port_id;
	uint16_t		bif_designated_port;
	struct bstp_config_unit	bif_config_bpdu;
	uint8_t			bif_state;
	uint8_t			bif_topology_change_acknowledge;
	uint8_t			bif_config_pending;
	uint8_t			bif_change_detection_enabled;
	uint8_t			bif_priority;
	struct ifnet		*bif_ifp;	/* member if */
	uint32_t		bif_flags;	/* member if flags */
	struct psref_target	bif_psref;
	void *			*bif_linkstate_hook;
	void *			*bif_ifdetach_hook;
};

/*
 * Bridge route node.
 */
struct bridge_rtnode {
	struct pslist_entry     brt_hash;	/* hash table linkage */
	struct pslist_entry     brt_list;	/* list linkage */
	struct ifnet		*brt_ifp;	/* destination if */
	time_t			brt_expire;	/* expiration time */
	uint8_t			brt_flags;	/* address flags */
	uint8_t			brt_addr[ETHER_ADDR_LEN];
};

struct bridge_iflist_psref {
	struct pslist_head	bip_iflist;	/* member interface list */
	kmutex_t		bip_lock;
	pserialize_t		bip_psz;
};

/*
 * Software state for each bridge.
 */
struct bridge_softc {
	struct ifnet		sc_if;
	LIST_ENTRY(bridge_softc) sc_list;
	uint64_t		sc_designated_root;
	uint64_t		sc_bridge_id;
	struct bridge_iflist	*sc_root_port;
	uint32_t		sc_root_path_cost;
	uint16_t		sc_max_age;
	uint16_t		sc_hello_time;
	uint16_t		sc_forward_delay;
	uint16_t		sc_bridge_max_age;
	uint16_t		sc_bridge_hello_time;
	uint16_t		sc_bridge_forward_delay;
	uint16_t		sc_topology_change_time;
	uint16_t		sc_hold_time;
	uint16_t		sc_bridge_priority;
	uint8_t			sc_topology_change_detected;
	uint8_t			sc_topology_change;
	struct bridge_timer	sc_hello_timer;
	struct bridge_timer	sc_topology_change_timer;
	struct bridge_timer	sc_tcn_timer;
	uint32_t		sc_brtmax;	/* max # of addresses */
	uint32_t		sc_brtcnt;	/* cur. # of addresses */
	uint32_t		sc_brttimeout;	/* rt timeout in seconds */
	callout_t		sc_brcallout;	/* bridge callout */
	callout_t		sc_bstpcallout;	/* STP callout */
	struct bridge_iflist_psref	sc_iflist_psref;
	struct pslist_head	*sc_rthash;	/* our forwarding table */
	struct pslist_head	sc_rtlist;	/* list version of above */
	kmutex_t		*sc_rtlist_lock;
	pserialize_t		sc_rtlist_psz;
	struct workqueue	*sc_rtage_wq;
	struct work		sc_rtage_wk;
	uint32_t		sc_rthash_key;	/* key for hash */
	uint32_t		sc_filter_flags; /* ipf and flags */
	int			sc_csum_flags_tx;
	int			sc_capenable;
};

extern const uint8_t bstp_etheraddr[];

int	bridge_output(struct ifnet *, struct mbuf *, const struct sockaddr *,
	    const struct rtentry *);

void	bstp_initialization(struct bridge_softc *);
void	bstp_stop(struct bridge_softc *);
void	bstp_input(struct bridge_softc *, struct bridge_iflist *, struct mbuf *);

void	bridge_enqueue(struct bridge_softc *, struct ifnet *, struct mbuf *,
	    int);

void	bridge_calc_csum_flags(struct bridge_softc *);

#define BRIDGE_LOCK_OBJ(_sc)	(&(_sc)->sc_iflist_psref.bip_lock)
#define BRIDGE_LOCK(_sc)	mutex_enter(BRIDGE_LOCK_OBJ(_sc))
#define BRIDGE_UNLOCK(_sc)	mutex_exit(BRIDGE_LOCK_OBJ(_sc))
#define BRIDGE_LOCKED(_sc)	mutex_owned(BRIDGE_LOCK_OBJ(_sc))

#define BRIDGE_PSZ_RENTER(__s)	do { __s = pserialize_read_enter(); } while (0)
#define BRIDGE_PSZ_REXIT(__s)	do { pserialize_read_exit(__s); } while (0)
#define BRIDGE_PSZ_PERFORM(_sc)	pserialize_perform((_sc)->sc_iflist_psref.bip_psz)

#define BRIDGE_IFLIST_READER_FOREACH(_bif, _sc) \
	PSLIST_READER_FOREACH((_bif), &((_sc)->sc_iflist_psref.bip_iflist), \
	    struct bridge_iflist, bif_next)
#define BRIDGE_IFLIST_WRITER_FOREACH(_bif, _sc) \
	PSLIST_WRITER_FOREACH((_bif), &((_sc)->sc_iflist_psref.bip_iflist), \
	    struct bridge_iflist, bif_next)

/*
 * Locking notes:
 * - Updates of sc_iflist are serialized by sc_iflist_lock (an adaptive mutex)
 *   - The mutex is also used for STP
 * - Items of sc_iflist (bridge_iflist) is protected by both pserialize
 *   (sc_iflist_psz) and reference counting (bridge_iflist#bif_refs)
 * - Before destroying an item of sc_iflist, we have to do pserialize_perform
 *   and synchronize with the reference counting via a conditional variable
 *   (sc_iflist_cz)
 * - Updates of sc_rtlist are serialized by sc_rtlist_lock (an adaptive mutex)
 *   - The mutex is also used for pserialize
 * - A workqueue is used to run bridge_rtage in LWP context via bridge_timer callout
 *   - bridge_rtage uses pserialize that requires non-interrupt context
 */
#endif /* _KERNEL */
#endif /* !_NET_IF_BRIDGEVAR_H_ */