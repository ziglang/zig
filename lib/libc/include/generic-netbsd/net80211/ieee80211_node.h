/*	$NetBSD: ieee80211_node.h,v 1.31 2022/02/16 22:00:56 andvar Exp $	*/
/*-
 * Copyright (c) 2001 Atsushi Onoe
 * Copyright (c) 2002-2005 Sam Leffler, Errno Consulting
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
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * Alternatively, this software may be distributed under the terms of the
 * GNU General Public License ("GPL") version 2 as published by the Free
 * Software Foundation.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * $FreeBSD: src/sys/net80211/ieee80211_node.h,v 1.22 2005/08/10 16:22:29 sam Exp $
 */
#ifndef _NET80211_IEEE80211_NODE_H_
#define _NET80211_IEEE80211_NODE_H_

#include <sys/atomic.h>
#include <net80211/ieee80211_netbsd.h>
#include <net80211/ieee80211_ioctl.h>		/* for ieee80211_nodestats */

#ifdef _KERNEL
/*
 * Each ieee80211com instance has a single timer that fires once a
 * second.  This is used to initiate various work depending on the
 * state of the instance: scanning (passive or active), ``transition''
 * (waiting for a response to a management frame when operating
 * as a station), and node inactivity processing (when operating
 * as an AP).  For inactivity processing each node has a timeout
 * set in its ni_inact field that is decremented on each timeout
 * and the node is reclaimed when the counter goes to zero.  We
 * use different inactivity timeout values depending on whether
 * the node is associated and authorized (either by 802.1x or
 * open/shared key authentication) or associated but yet to be
 * authorized.  The latter timeout is shorter to more aggressively
 * reclaim nodes that leave part way through the 802.1x exchange.
 */
#define	IEEE80211_INACT_WAIT	15		/* inactivity interval (secs) */
#define	IEEE80211_INACT_INIT	(30/IEEE80211_INACT_WAIT)	/* initial */
#define	IEEE80211_INACT_AUTH	(180/IEEE80211_INACT_WAIT)	/* associated but not authorized */
#define	IEEE80211_INACT_RUN	(300/IEEE80211_INACT_WAIT)	/* authorized */
#define	IEEE80211_INACT_PROBE	(30/IEEE80211_INACT_WAIT)	/* probe */
#define	IEEE80211_INACT_SCAN	(300/IEEE80211_INACT_WAIT)	/* scanned */

#define	IEEE80211_TRANS_WAIT 	5		/* mgt frame tx timer (secs) */

#define	IEEE80211_NODE_HASHSIZE	32
/* simple hash is enough for variation of macaddr */
#define	IEEE80211_NODE_HASH(addr)	\
	(((const u_int8_t *)(addr))[IEEE80211_ADDR_LEN - 1] % \
		IEEE80211_NODE_HASHSIZE)

struct ieee80211_rsnparms {
	u_int8_t	rsn_mcastcipher;	/* mcast/group cipher */
	u_int8_t	rsn_mcastkeylen;	/* mcast key length */
	u_int8_t	rsn_ucastcipherset;	/* unicast cipher set */
	u_int8_t	rsn_ucastcipher;	/* selected unicast cipher */
	u_int8_t	rsn_ucastkeylen;	/* unicast key length */
	u_int8_t	rsn_keymgmtset;		/* key management algorithms */
	u_int8_t	rsn_keymgmt;		/* selected key mgmt algo */
	u_int16_t	rsn_caps;		/* capabilities */
};

struct ieee80211_node_table;
struct ieee80211com;

/*
 * Node specific information.  Note that drivers are expected
 * to derive from this structure to add device-specific per-node
 * state.  This is done by overriding the ic_node_* methods in
 * the ieee80211com structure.
 */
struct ieee80211_node {
	struct ieee80211com	*ni_ic;
	struct ieee80211_node_table *ni_table;
	TAILQ_ENTRY(ieee80211_node)	ni_list;
	LIST_ENTRY(ieee80211_node)	ni_hash;
	u_int			ni_refcnt;
	u_int			ni_scangen;	/* gen# for timeout scan */
	u_int8_t		ni_authmode;	/* authentication algorithm */
	u_int16_t		ni_flags;	/* special-purpose state */
#define	IEEE80211_NODE_AUTH	0x0001		/* authorized for data */
#define	IEEE80211_NODE_QOS	0x0002		/* QoS enabled */
#define	IEEE80211_NODE_ERP	0x0004		/* ERP enabled */
/* NB: this must have the same value as IEEE80211_FC1_PWR_MGT */
#define	IEEE80211_NODE_PWR_MGT	0x0010		/* power save mode enabled */
#define	IEEE80211_NODE_AREF	0x0020		/* authentication ref held */
	u_int16_t		ni_associd;	/* assoc response */
	u_int16_t		ni_txpower;	/* current transmit power */
	u_int16_t		ni_vlan;	/* vlan tag */
	u_int32_t		*ni_challenge;	/* shared-key challenge */
	u_int8_t		*ni_wpa_ie;	/* captured WPA/RSN ie */
	u_int8_t		*ni_wme_ie;	/* captured WME ie */
	u_int16_t		ni_txseqs[17];	/* tx seq per-tid */
	u_int16_t		ni_rxseqs[17];	/* rx seq previous per-tid*/
	u_int32_t		ni_rxfragstamp;	/* time stamp of last rx frag */
	struct mbuf		*ni_rxfrag[3];	/* rx frag reassembly */
	struct ieee80211_rsnparms ni_rsn;	/* RSN/WPA parameters */
	struct ieee80211_key	ni_ucastkey;	/* unicast key */

	/* hardware */
	u_int32_t		ni_rstamp;	/* recv timestamp */
	u_int8_t		ni_rssi;	/* recv ssi */

	/* header */
	u_int8_t		ni_macaddr[IEEE80211_ADDR_LEN];
	u_int8_t		ni_bssid[IEEE80211_ADDR_LEN];

	/* beacon, probe response */
	union {
		u_int8_t	data[8];
		u_int64_t	tsf;
	} ni_tstamp;				/* from last rcv'd beacon */
	u_int16_t		ni_intval;	/* beacon interval */
	u_int16_t		ni_capinfo;	/* capabilities */
	u_int8_t		ni_esslen;
	u_int8_t		ni_essid[IEEE80211_NWID_LEN];
	struct ieee80211_rateset ni_rates;	/* negotiated rate set */
	struct ieee80211_channel *ni_chan;	/* XXX multiple uses */
	u_int16_t		ni_fhdwell;	/* FH only */
	u_int8_t		ni_fhindex;	/* FH only */
	u_int8_t		ni_erp;		/* ERP from beacon/probe resp */
	u_int16_t		ni_timoff;	/* byte offset to TIM ie */
	u_int8_t		ni_dtim_period;	/* DTIM period */
	u_int8_t		ni_dtim_count;	/* DTIM count for last bcn */

	/* others */
	int			ni_fails;	/* failure count to associate */
	short			ni_inact;	/* inactivity mark count */
	short			ni_inact_reload;/* inactivity reload value */
	int			ni_txrate;	/* index to ni_rates[] */
	struct	ifqueue		ni_savedq;	/* ps-poll queue */
	struct ieee80211_nodestats ni_stats;	/* per-node statistics */
};
MALLOC_DECLARE(M_80211_NODE);

#define	IEEE80211_NODE_AID(ni)	IEEE80211_AID(ni->ni_associd)

#define	IEEE80211_NODE_STAT(ni,stat)	(ni->ni_stats.ns_##stat++)
#define	IEEE80211_NODE_STAT_ADD(ni,stat,v)	(ni->ni_stats.ns_##stat += v)
#define	IEEE80211_NODE_STAT_SET(ni,stat,v)	(ni->ni_stats.ns_##stat = v)

struct ieee80211com;

void	ieee80211_node_attach(struct ieee80211com *);
void	ieee80211_node_lateattach(struct ieee80211com *);
void	ieee80211_node_detach(struct ieee80211com *);

static __inline int
ieee80211_node_is_authorized(const struct ieee80211_node *ni)
{
	return (ni->ni_flags & IEEE80211_NODE_AUTH);
}

void	ieee80211_node_authorize(struct ieee80211_node *);
void	ieee80211_node_unauthorize(struct ieee80211_node *);

void	ieee80211_begin_scan(struct ieee80211com *, int);
int	ieee80211_next_scan(struct ieee80211com *);
void	ieee80211_probe_curchan(struct ieee80211com *, int);
void	ieee80211_create_ibss(struct ieee80211com*, struct ieee80211_channel *);
void	ieee80211_reset_bss(struct ieee80211com *);
void	ieee80211_cancel_scan(struct ieee80211com *);
void	ieee80211_end_scan(struct ieee80211com *);
int	ieee80211_ibss_merge(struct ieee80211_node *);
int	ieee80211_sta_join(struct ieee80211com *, struct ieee80211_node *);
void	ieee80211_sta_leave(struct ieee80211com *, struct ieee80211_node *);

/*
 * Table of ieee80211_node instances.  Each ieee80211com
 * has at least one for holding the scan candidates.
 * When operating as an access point or in ibss mode there
 * is a second table for associated stations or neighbors.
 */
struct ieee80211_node_table {
	struct ieee80211com	*nt_ic;		/* back reference */
	ieee80211_node_lock_t	nt_nodelock;	/* on node table */
	TAILQ_HEAD(, ieee80211_node) nt_node;	/* information of all nodes */
	LIST_HEAD(, ieee80211_node) nt_hash[IEEE80211_NODE_HASHSIZE];
	const char		*nt_name;	/* for debugging */
	ieee80211_scan_lock_t	nt_scanlock;	/* on nt_scangen */
	u_int			nt_scangen;	/* gen# for timeout scan */
	int			nt_inact_timer;	/* inactivity timer */
	int			nt_inact_init;	/* initial node inact setting */
	struct ieee80211_node	**nt_keyixmap;	/* key ix -> node map */
	int			nt_keyixmax;	/* keyixmap size */

	void			(*nt_timeout)(struct ieee80211_node_table *);
};
void	ieee80211_node_table_reset(struct ieee80211_node_table *);

struct ieee80211_node *ieee80211_alloc_node(
		struct ieee80211_node_table *, const u_int8_t *);
struct ieee80211_node *ieee80211_tmp_node(struct ieee80211com *,
		const u_int8_t *macaddr);
struct ieee80211_node *ieee80211_dup_bss(struct ieee80211_node_table *,
		const u_int8_t *);
#ifdef IEEE80211_DEBUG_REFCNT
void	ieee80211_free_node_debug(struct ieee80211_node *,
		const char *func, int line);
struct ieee80211_node *ieee80211_find_node_debug(
		struct ieee80211_node_table *, const u_int8_t *,
		const char *func, int line);
struct ieee80211_node * ieee80211_find_rxnode_debug(
		struct ieee80211com *, const struct ieee80211_frame_min *,
		const char *func, int line);
struct ieee80211_node * ieee80211_find_rxnode_withkey_debug(
		struct ieee80211com *,
		const struct ieee80211_frame_min *, u_int16_t keyix,
		const char *func, int line);
struct ieee80211_node *ieee80211_find_txnode_debug(
		struct ieee80211com *, const u_int8_t *,
		const char *func, int line);
struct ieee80211_node *ieee80211_find_node_with_channel_debug(
		struct ieee80211_node_table *, const u_int8_t *macaddr,
		struct ieee80211_channel *, const char *func, int line);
struct ieee80211_node *ieee80211_find_node_with_ssid_debug(
		struct ieee80211_node_table *, const u_int8_t *macaddr,
		u_int ssidlen, const u_int8_t *ssid,
		const char *func, int line);
#define	ieee80211_free_node(ni) \
	ieee80211_free_node_debug(ni, __func__, __LINE__)
#define	ieee80211_find_node(nt, mac) \
	ieee80211_find_node_debug(nt, mac, __func__, __LINE__)
#define	ieee80211_find_rxnode(nt, wh) \
	ieee80211_find_rxnode_debug(nt, wh, __func__, __LINE__)
#define	ieee80211_find_rxnode_withkey(nt, wh, keyix) \
	ieee80211_find_rxnode_withkey_debug(nt, wh, keyix, __func__, __LINE__)
#define	ieee80211_find_txnode(nt, mac) \
	ieee80211_find_txnode_debug(nt, mac, __func__, __LINE__)
#define	ieee80211_find_node_with_channel(nt, mac, c) \
	ieee80211_find_node_with_channel_debug(nt, mac, c, __func__, __LINE__)
#define	ieee80211_find_node_with_ssid(nt, mac, sl, ss) \
	ieee80211_find_node_with_ssid_debug(nt, mac, sl, ss, __func__, __LINE__)
#else
void	ieee80211_free_node(struct ieee80211_node *);
struct ieee80211_node *ieee80211_find_node(
		struct ieee80211_node_table *, const u_int8_t *);
struct ieee80211_node * ieee80211_find_rxnode(
		struct ieee80211com *, const struct ieee80211_frame_min *);
struct ieee80211_node * ieee80211_find_rxnode_withkey(struct ieee80211com *,
		const struct ieee80211_frame_min *, u_int16_t keyix);
struct ieee80211_node *ieee80211_find_txnode(
		struct ieee80211com *, const u_int8_t *);
struct ieee80211_node *ieee80211_find_node_with_channel(
		struct ieee80211_node_table *, const u_int8_t *macaddr,
		struct ieee80211_channel *);
struct ieee80211_node *ieee80211_find_node_with_ssid(
		struct ieee80211_node_table *, const u_int8_t *macaddr,
		u_int ssidlen, const u_int8_t *ssid);
#endif
int	ieee80211_node_delucastkey(struct ieee80211_node *);

struct ieee80211_node *ieee80211_refine_node_for_beacon(
		struct ieee80211com *, struct ieee80211_node *,
		struct ieee80211_channel *, const u_int8_t *ssid);
typedef void ieee80211_iter_func(void *, struct ieee80211_node *);
void	ieee80211_iterate_nodes(struct ieee80211_node_table *,
		ieee80211_iter_func *, void *);

void	ieee80211_dump_node(struct ieee80211_node_table *,
		struct ieee80211_node *);
void	ieee80211_dump_nodes(struct ieee80211_node_table *);

struct ieee80211_node *ieee80211_fakeup_adhoc_node(
		struct ieee80211_node_table *, const u_int8_t macaddr[]);
void	ieee80211_node_join(struct ieee80211com *, struct ieee80211_node *,int);
void	ieee80211_node_leave(struct ieee80211com *, struct ieee80211_node *);
u_int8_t ieee80211_getrssi(struct ieee80211com *ic);

/*
 * Parameters supplied when adding/updating an entry in a
 * scan cache.  Pointer variables should be set to NULL
 * if no data is available.  Pointer references can be to
 * local data; any information that is saved will be copied.
 * All multi-byte values must be in host byte order.
 */
struct ieee80211_scanparams {
	u_int16_t	sp_capinfo;	/* 802.11 capabilities */
	u_int16_t	sp_fhdwell;	/* FHSS dwell interval */
	u_int8_t	sp_chan;		/* */
	u_int8_t	sp_bchan;
	u_int8_t	sp_fhindex;
	u_int8_t	sp_erp;
	u_int16_t	sp_bintval;
	u_int16_t	sp_timoff;
	u_int8_t	*sp_tim;
	u_int8_t	*sp_tstamp;
	u_int8_t	*sp_country;
	u_int8_t	*sp_ssid;
	u_int8_t	*sp_rates;
	u_int8_t	*sp_xrates;
	u_int8_t	*sp_wpa;
	u_int8_t	*sp_wme;
};

/*
 * Node reference counting definitions.
 *
 * ieee80211_node_initref	initialize the reference count to 1
 * ieee80211_node_incref	add a reference
 * ieee80211_node_decref	remove a reference
 * ieee80211_node_dectestref	remove a reference and return 1 if this
 *				is the last reference, otherwise 0
 * ieee80211_node_refcnt	reference count for printing (only)
 */

static __inline void
ieee80211_node_initref(struct ieee80211_node *ni)
{
	ni->ni_refcnt = 1;
}

static __inline void
ieee80211_node_incref(struct ieee80211_node *ni)
{
	atomic_inc_uint(&ni->ni_refcnt);
}

static __inline void
ieee80211_node_decref(struct ieee80211_node *ni)
{
	atomic_dec_uint(&ni->ni_refcnt);
}

int ieee80211_node_dectestref(struct ieee80211_node *ni);

static __inline unsigned int
ieee80211_node_refcnt(const struct ieee80211_node *ni)
{
	return ni->ni_refcnt;
}

static __inline struct ieee80211_node *
ieee80211_ref_node(struct ieee80211_node *ni)
{
	ieee80211_node_incref(ni);
	return ni;
}

static __inline void
ieee80211_unref_node(struct ieee80211_node **ni)
{
	ieee80211_node_decref(*ni);
	*ni = NULL;			/* guard against use */
}

void	ieee80211_add_scan(struct ieee80211com *,
		const struct ieee80211_scanparams *,
		const struct ieee80211_frame *,
		int subtype, int rssi, int rstamp);
void ieee80211_init_neighbor(struct ieee80211com *, struct ieee80211_node *,
		const struct ieee80211_frame *,
		const struct ieee80211_scanparams *, int);
struct ieee80211_node *ieee80211_add_neighbor(struct ieee80211com *,
		const struct ieee80211_frame *,
		const struct ieee80211_scanparams *);
#endif /* _KERNEL */
#endif /* !_NET80211_IEEE80211_NODE_H_ */