/* $NetBSD: ieee80211_sysctl.h,v 1.9 2009/10/19 23:19:39 rmind Exp $ */
/*-
 * Copyright (c) 2005 David Young.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials provided
 *    with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY David Young ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL David
 * Young BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 */
#ifndef _NET80211_IEEE80211_SYSCTL_H_
#define _NET80211_IEEE80211_SYSCTL_H_

#include <net80211/_ieee80211.h>

/* sysctl(9) interface to net80211 client/peer records */   

/* Name index, offset from net.link.ieee80211.node. */

#define	IEEE80211_SYSCTL_NODENAME_IF		0
#define	IEEE80211_SYSCTL_NODENAME_OP		1
#define	IEEE80211_SYSCTL_NODENAME_ARG		2
#define	IEEE80211_SYSCTL_NODENAME_TYPE		3
#define	IEEE80211_SYSCTL_NODENAME_ELTSIZE	4
#define	IEEE80211_SYSCTL_NODENAME_ELTCOUNT	5
#define	IEEE80211_SYSCTL_NODENAMELEN		6

/* Record type numbers. */
#define	IEEE80211_SYSCTL_T_NODE		0	/* client/peer record */
#define	IEEE80211_SYSCTL_T_RSSADAPT	1	/* rssadapt(9) record
						 * (optional)
						 */
#define	IEEE80211_SYSCTL_T_DRVSPEC	2	/* driver-specific record
						 * (optional)
						 */

#define	IEEE80211_SYSCTL_OP_ALL		0
 
/* Every record begins with this information. */
struct ieee80211_node_sysctlhdr {
/*00*/	u_int16_t	sh_ifindex;
/*02*/	u_int8_t	sh_macaddr[IEEE80211_ADDR_LEN];
/*08*/	u_int8_t	sh_bssid[IEEE80211_ADDR_LEN];
};

/* Exportable node. */
struct ieee80211_node_sysctl {
/*00*/	u_int16_t	ns_ifindex;
/*02*/	u_int8_t	ns_macaddr[IEEE80211_ADDR_LEN];
/*08*/	u_int8_t	ns_bssid[IEEE80211_ADDR_LEN];
/*0e*/	u_int16_t	ns_capinfo;	/* capabilities */
/*10*/	u_int32_t	ns_flags;	/* properties of this node,
					 * IEEE80211_NODE_SYSCTL_F_*
					 */
/*14*/	u_int16_t	ns_freq;
/*16*/	u_int16_t	ns_chanflags;
/*18*/	u_int16_t	ns_chanidx;
/*1a*/	u_int8_t	ns_rssi;	/* recv ssi */
/*1b*/	u_int8_t	ns_esslen;
/*1c*/	u_int8_t	ns_essid[IEEE80211_NWID_LEN];
/*3c*/	u_int8_t	ns_rsvd0;	/* reserved */
/*3d*/	u_int8_t	ns_erp;		/* 11g only */
/*3e*/	u_int16_t	ns_associd;	/* assoc response */
/*40*/	u_int32_t	ns_inact;	/* inactivity mark count */
/*44*/	u_int32_t	ns_rstamp;	/* recv timestamp */
/*48*/	struct ieee80211_rateset ns_rates;	/* negotiated rate set */
/*58*/	u_int16_t	ns_txrate;	/* index to ns_rates[] */
/*5a*/	u_int16_t	ns_intval;	/* beacon interval */
/*5c*/	u_int8_t	ns_tstamp[8];	/* from last rcv'd beacon */
/*64*/	u_int16_t	ns_txseq;	/* seq to be transmitted */
/*66*/	u_int16_t	ns_rxseq;	/* seq previous received */
/*68*/	u_int16_t	ns_fhdwell;	/* FH only */
/*6a*/	u_int8_t	ns_fhindex;	/* FH only */
/*6b*/	u_int8_t	ns_fails;	/* failure count to associate */
/*6c*/
#ifdef notyet
	/* DTIM and contention free period (CFP) */
	u_int8_t	ns_dtimperiod;
	u_int8_t	ns_cfpperiod;	/* # of DTIMs between CFPs */
	u_int16_t	ns_cfpduremain;	/* remaining cfp duration */
	u_int16_t	ns_cfpmaxduration;/* max CFP duration in TU */
	u_int16_t	ns_nextdtim;	/* time to next DTIM */
	u_int16_t	ns_timoffset;
#endif
} __packed;

#ifdef __NetBSD__
enum ieee80211_node_walk_state {
	IEEE80211_WALK_BSS = 0,
	IEEE80211_WALK_SCAN,
	IEEE80211_WALK_STA
};

struct ieee80211_node_walk {
	struct ieee80211com		*nw_ic;
	struct ieee80211_node_table	*nw_nt;
	struct ieee80211_node		*nw_ni;
	u_short				nw_ifindex;
};
#endif /* __NetBSD__ */

#define	IEEE80211_NODE_SYSCTL_F_BSS	0x00000001	/* this node is the
							 * ic->ic_bss
							 */
#define	IEEE80211_NODE_SYSCTL_F_STA	0x00000002	/* this node is in
							 * the neighbor/sta
							 * table
							 */
#define	IEEE80211_NODE_SYSCTL_F_SCAN	0x00000004	/* this node is in
							 * the scan table
							 */
#endif /* !_NET80211_IEEE80211_SYSCTL_H_ */