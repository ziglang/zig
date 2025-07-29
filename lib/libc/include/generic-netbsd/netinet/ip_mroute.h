/*	$NetBSD: ip_mroute.h,v 1.35 2021/02/03 18:13:13 roy Exp $	*/

#ifndef _NETINET_IP_MROUTE_H_
#define _NETINET_IP_MROUTE_H_

/*
 * Definitions for IP multicast forwarding.
 *
 * Written by David Waitzman, BBN Labs, August 1988.
 * Modified by Steve Deering, Stanford, February 1989.
 * Modified by Ajit Thyagarajan, PARC, August 1993.
 * Modified by Ajit Thyagarajan, PARC, August 1994.
 * Modified by Ahmed Helmy, SGI, June 1996.
 * Modified by Pavlin Radoslavov, ICSI, October 2002.
 *
 * MROUTING Revision: 1.2
 * and PIM-SMv2 and PIM-DM support, advanced API support,
 * bandwidth metering and signaling.
 */

#include <sys/queue.h>
#include <sys/callout.h>

#ifdef _KERNEL
struct sockopt; /* from <sys/socketvar.h> */
#endif

/*
 * Multicast Routing set/getsockopt commands.
 */
#define	MRT_INIT		100	/* initialize forwarder */
#define	MRT_DONE		101	/* shut down forwarder */
#define	MRT_ADD_VIF		102	/* create virtual interface */
#define	MRT_DEL_VIF		103	/* delete virtual interface */
#define	MRT_ADD_MFC		104	/* insert forwarding cache entry */
#define	MRT_DEL_MFC		105	/* delete forwarding cache entry */
#define	MRT_VERSION		106	/* get kernel version number */
#define	MRT_ASSERT		107	/* enable assert processing */
#define MRT_PIM			MRT_ASSERT /* enable PIM processing */
#define MRT_API_SUPPORT		109	/* supported MRT API */
#define MRT_API_CONFIG		110	/* config MRT API */
#define MRT_ADD_BW_UPCALL	111	/* create bandwidth monitor */
#define MRT_DEL_BW_UPCALL	112	/* delete bandwidth monitor */


/*
 * Types and macros for handling bitmaps with one bit per virtual interface.
 */
#define	MAXVIFS 32
typedef u_int32_t vifbitmap_t;
typedef u_int16_t vifi_t;		/* type of a vif index */

#define	VIFM_SET(n, m)			((m) |= (1 << (n)))
#define	VIFM_CLR(n, m)			((m) &= ~(1 << (n)))
#define	VIFM_ISSET(n, m)		((m) & (1 << (n)))
#define	VIFM_SETALL(m)			((m) = 0xffffffff)
#define	VIFM_CLRALL(m)			((m) = 0x00000000)
#define	VIFM_COPY(mfrom, mto)		((mto) = (mfrom))
#define	VIFM_SAME(m1, m2)		((m1) == (m2))

#define	VIFF_TUNNEL	0x1		/* vif represents a tunnel end-point */
#define	VIFF_SRCRT	0x2		/* tunnel uses IP src routing */
#define VIFF_REGISTER	0x4		/* used for PIM Register encap/decap */

/*
 * Argument structure for MRT_ADD_VIF.
 * (MRT_DEL_VIF takes a single vifi_t argument.)
 */
struct vifctl {
	vifi_t	  vifc_vifi;	    	/* the index of the vif to be added */
	u_int8_t  vifc_flags;     	/* VIFF_ flags defined below */
	u_int8_t  vifc_threshold; 	/* min ttl required to forward on vif */
	u_int32_t vifc_rate_limit;	/* max rate */
	struct	  in_addr vifc_lcl_addr;/* local interface address */
	struct	  in_addr vifc_rmt_addr;/* remote address (tunnels only) */
};

/*
 * Argument structure for MRT_ADD_MFC and MRT_DEL_MFC.
 * XXX if you change this, make sure to change struct mfcctl2 as well.
 */
struct mfcctl {
	struct	 in_addr mfcc_origin;	/* ip origin of mcasts */
	struct	 in_addr mfcc_mcastgrp;	/* multicast group associated */
	vifi_t	 mfcc_parent;		/* incoming vif */
	u_int8_t mfcc_ttls[MAXVIFS];	/* forwarding ttls on vifs */
};

/*
 * The new argument structure for MRT_ADD_MFC and MRT_DEL_MFC overlays
 * and extends the old struct mfcctl.
 */
struct mfcctl2 {
	/* the mfcctl fields */
	struct in_addr	mfcc_origin;		/* ip origin of mcasts	     */
	struct in_addr	mfcc_mcastgrp;		/* multicast group associated*/
	vifi_t		mfcc_parent;		/* incoming vif		     */
	u_int8_t	mfcc_ttls[MAXVIFS]; 	/* forwarding ttls on vifs   */

	/* extension fields */
	u_int8_t	mfcc_flags[MAXVIFS];	/* the MRT_MFC_FLAGS_* flags */
	struct in_addr	mfcc_rp;		/* the RP address            */
};
/*
 * The advanced-API flags.
 *
 * The MRT_MFC_FLAGS_XXX API flags are also used as flags
 * for the mfcc_flags field.
 */
#define	MRT_MFC_FLAGS_DISABLE_WRONGVIF	(1 << 0) /* disable WRONGVIF signals */
#define	MRT_MFC_FLAGS_BORDER_VIF	(1 << 1) /* border vif		     */
#define MRT_MFC_RP			(1 << 8) /* enable RP address	     */
#define MRT_MFC_BW_UPCALL		(1 << 9) /* enable bw upcalls	     */
#define MRT_MFC_FLAGS_ALL		(MRT_MFC_FLAGS_DISABLE_WRONGVIF |    \
					 MRT_MFC_FLAGS_BORDER_VIF)
#define MRT_API_FLAGS_ALL		(MRT_MFC_FLAGS_ALL |		     \
					 MRT_MFC_RP |			     \
					 MRT_MFC_BW_UPCALL)

/*
 * Structure for installing or delivering an upcall if the
 * measured bandwidth is above or below a threshold.
 *
 * User programs (e.g. daemons) may have a need to know when the
 * bandwidth used by some data flow is above or below some threshold.
 * This interface allows the userland to specify the threshold (in
 * bytes and/or packets) and the measurement interval. Flows are
 * all packet with the same source and destination IP address.
 * At the moment the code is only used for multicast destinations
 * but there is nothing that prevents its use for unicast.
 *
 * The measurement interval cannot be shorter than some Tmin (currently, 3s).
 * The threshold is set in packets and/or bytes per_interval.
 *
 * Measurement works as follows:
 *
 * For >= measurements:
 * The first packet marks the start of a measurement interval.
 * During an interval we count packets and bytes, and when we
 * pass the threshold we deliver an upcall and we are done.
 * The first packet after the end of the interval resets the
 * count and restarts the measurement.
 *
 * For <= measurement:
 * We start a timer to fire at the end of the interval, and
 * then for each incoming packet we count packets and bytes.
 * When the timer fires, we compare the value with the threshold,
 * schedule an upcall if we are below, and restart the measurement
 * (reschedule timer and zero counters).
 */

struct bw_data {
	struct timeval	b_time;
	u_int64_t	b_packets;
	u_int64_t	b_bytes;
};

struct bw_upcall {
	struct in_addr	bu_src;			/* source address            */
	struct in_addr	bu_dst;			/* destination address       */
	u_int32_t	bu_flags;		/* misc flags (see below)    */
#define BW_UPCALL_UNIT_PACKETS   (1 << 0)	/* threshold (in packets)    */
#define BW_UPCALL_UNIT_BYTES     (1 << 1)	/* threshold (in bytes)      */
#define BW_UPCALL_GEQ            (1 << 2)	/* upcall if bw >= threshold */
#define BW_UPCALL_LEQ            (1 << 3)	/* upcall if bw <= threshold */
#define BW_UPCALL_DELETE_ALL     (1 << 4)	/* delete all upcalls for s,d*/
	struct bw_data	bu_threshold;		/* the bw threshold	     */
	struct bw_data	bu_measured;		/* the measured bw	     */
};

/* max. number of upcalls to deliver together */
#define BW_UPCALLS_MAX				128
/* min. threshold time interval for bandwidth measurement */
#define BW_UPCALL_THRESHOLD_INTERVAL_MIN_SEC	3
#define BW_UPCALL_THRESHOLD_INTERVAL_MIN_USEC	0

/*
 * Argument structure used by mrouted to get src-grp pkt counts.
 */
struct sioc_sg_req {
	struct	in_addr src;
	struct	in_addr grp;
	u_long	pktcnt;
	u_long	bytecnt;
	u_long	wrong_if;
};

/*
 * Argument structure used by mrouted to get vif pkt counts.
 */
struct sioc_vif_req {
	vifi_t	vifi;			/* vif number */
	u_long	icount;			/* input packet count on vif */
	u_long	ocount;			/* output packet count on vif */
	u_long	ibytes;			/* input byte count on vif */
	u_long	obytes;			/* output byte count on vif */
};


/*
 * The kernel's multicast routing statistics.
 */
struct mrtstat {
	u_long	mrts_mfc_lookups;	/* # forw. cache hash table hits */
	u_long	mrts_mfc_misses;	/* # forw. cache hash table misses */
	u_long	mrts_upcalls;		/* # calls to mrouted */
	u_long	mrts_no_route;		/* no route for packet's origin */
	u_long	mrts_bad_tunnel;	/* malformed tunnel options */
	u_long	mrts_cant_tunnel;	/* no room for tunnel options */
	u_long	mrts_wrong_if;		/* arrived on wrong interface */
	u_long	mrts_upq_ovflw;		/* upcall Q overflow */
	u_long	mrts_cache_cleanups;	/* # entries with no upcalls */
	u_long	mrts_drop_sel;     	/* pkts dropped selectively */
	u_long	mrts_q_overflow;    	/* pkts dropped - Q overflow */
	u_long	mrts_pkt2large;     	/* pkts dropped - size > BKT SIZE */
	u_long	mrts_upq_sockfull;	/* upcalls dropped - socket full */
};


#ifdef _KERNEL

/*
 * The kernel's virtual-interface structure.
 */
struct encaptab;
struct vif {
	struct	  mbuf *tbf_q, **tbf_t;	/* packet queue */
	struct	  timeval tbf_last_pkt_t; /* arr. time of last pkt */
	u_int32_t tbf_n_tok;		/* no of tokens in bucket */
	u_int32_t tbf_q_len;		/* length of queue at this vif */
	u_int32_t tbf_max_q_len;	/* max. queue length */

	u_int8_t  v_flags;		/* VIFF_ flags defined above */
	u_int8_t  v_threshold;		/* min ttl required to forward on vif */
	u_int32_t v_rate_limit;		/* max rate */
	struct	  in_addr v_lcl_addr;	/* local interface address */
	struct	  in_addr v_rmt_addr;	/* remote address (tunnels only) */
	struct	  ifnet *v_ifp;		/* pointer to interface */
	u_long	  v_pkt_in;		/* # pkts in on interface */
	u_long	  v_pkt_out;		/* # pkts out on interface */
	u_long	  v_bytes_in;		/* # bytes in on interface */
	u_long	  v_bytes_out;		/* # bytes out on interface */
	struct	  route v_route;	/* cached route if this is a tunnel */
	callout_t v_repq_ch;		/* for tbf_reprocess_q() */
	const struct encaptab *v_encap_cookie;
};

/*
 * The kernel's multicast forwarding cache entry structure.
 * (A field for the type of service (mfc_tos) is to be added
 * at a future point.)
 */
struct mfc {
	LIST_ENTRY(mfc) mfc_hash;
	struct	 in_addr mfc_origin;	 	/* ip origin of mcasts */
	struct	 in_addr mfc_mcastgrp;  	/* multicast group associated */
	vifi_t	 mfc_parent;			/* incoming vif */
	u_int8_t mfc_ttls[MAXVIFS]; 		/* forwarding ttls on vifs */
	u_long	 mfc_pkt_cnt;			/* pkt count for src-grp */
	u_long	 mfc_byte_cnt;			/* byte count for src-grp */
	u_long	 mfc_wrong_if;			/* wrong if for src-grp	*/
	int	 mfc_expire;			/* time to clean entry up */
	struct	 timeval mfc_last_assert;	/* last time I sent an assert */
	struct	 rtdetq *mfc_stall;		/* pkts waiting for route */
	u_int8_t mfc_flags[MAXVIFS];		/* the MRT_MFC_FLAGS_* flags */
	struct	 in_addr mfc_rp;		/* the RP address	     */
	struct	 bw_meter *mfc_bw_meter;	/* list of bandwidth meters  */
};

/*
 * Structure used to communicate from kernel to multicast router.
 * (Note the convenient similarity to an IP packet.)
 */
struct igmpmsg {
	u_int32_t unused1;
	u_int32_t unused2;
	u_int8_t  im_msgtype;		/* what type of message */
#define IGMPMSG_NOCACHE		1	/* no MFC in the kernel		    */
#define IGMPMSG_WRONGVIF	2	/* packet came from wrong interface */
#define	IGMPMSG_WHOLEPKT	3	/* PIM pkt for user level encap.    */
#define	IGMPMSG_BW_UPCALL	4	/* BW monitoring upcall		    */
	u_int8_t  im_mbz;		/* must be zero */
	u_int8_t  im_vif;		/* vif rec'd on */
	u_int8_t  unused3;
	struct	  in_addr im_src, im_dst;
};
#ifdef __CTASSERT
__CTASSERT(sizeof(struct igmpmsg) == 20);
#endif

/*
 * Argument structure used for pkt info. while upcall is made.
 */
struct rtdetq {
	struct	mbuf *m;		/* a copy of the packet */
	struct	ifnet *ifp;		/* interface pkt came in on */
#ifdef UPCALL_TIMING
	struct	timeval t;		/* timestamp */
#endif /* UPCALL_TIMING */
	struct	rtdetq *next;
};

#define	MFCTBLSIZ	256
#define	MAX_UPQ		4		/* max. no of pkts in upcall Q */

/*
 * Token bucket filter code
 */
#define	MAX_BKT_SIZE    10000		/* 10K bytes size */
#define	MAXQSIZE        10		/* max. no of pkts in token queue */

/*
 * Structure for measuring the bandwidth and sending an upcall if the
 * measured bandwidth is above or below a threshold.
 */
struct bw_meter {
	struct bw_meter	*bm_mfc_next;		/* next bw meter (same mfc)  */
	struct bw_meter	*bm_time_next;		/* next bw meter (same time) */
	uint32_t	bm_time_hash;		/* the time hash value       */
	struct mfc	*bm_mfc;		/* the corresponding mfc     */
	uint32_t	bm_flags;		/* misc flags (see below)    */
#define BW_METER_UNIT_PACKETS	(1 << 0)	/* threshold (in packets)    */
#define BW_METER_UNIT_BYTES	(1 << 1)	/* threshold (in bytes)      */
#define BW_METER_GEQ		(1 << 2)	/* upcall if bw >= threshold */
#define BW_METER_LEQ		(1 << 3)	/* upcall if bw <= threshold */
#define BW_METER_USER_FLAGS 	(BW_METER_UNIT_PACKETS |		\
				 BW_METER_UNIT_BYTES |			\
				 BW_METER_GEQ |				\
				 BW_METER_LEQ)

#define BW_METER_UPCALL_DELIVERED (1 << 24)	/* upcall was delivered      */

	struct bw_data	bm_threshold;		/* the upcall threshold	     */
	struct bw_data	bm_measured;		/* the measured bw	     */
	struct timeval	bm_start_time;		/* abs. time		     */
};

int	ip_mrouter_set(struct socket *, struct sockopt *);
int	ip_mrouter_get(struct socket *, struct sockopt *);
int	mrt_ioctl(struct socket *, u_long, void *);
int	ip_mrouter_done(void);
void	ip_mrouter_detach(struct ifnet *);
void	reset_vif(struct vif *);
int	ip_mforward(struct mbuf *, struct ifnet *);

#endif /* _KERNEL */

#endif /* !_NETINET_IP_MROUTE_H_ */