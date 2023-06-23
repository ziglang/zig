/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef __LINUX_PKT_SCHED_H
#define __LINUX_PKT_SCHED_H

#include <linux/const.h>
#include <linux/types.h>

/* Logical priority bands not depending on specific packet scheduler.
   Every scheduler will map them to real traffic classes, if it has
   no more precise mechanism to classify packets.

   These numbers have no special meaning, though their coincidence
   with obsolete IPv6 values is not occasional :-). New IPv6 drafts
   preferred full anarchy inspired by diffserv group.

   Note: TC_PRIO_BESTEFFORT does not mean that it is the most unhappy
   class, actually, as rule it will be handled with more care than
   filler or even bulk.
 */

#define TC_PRIO_BESTEFFORT		0
#define TC_PRIO_FILLER			1
#define TC_PRIO_BULK			2
#define TC_PRIO_INTERACTIVE_BULK	4
#define TC_PRIO_INTERACTIVE		6
#define TC_PRIO_CONTROL			7

#define TC_PRIO_MAX			15

/* Generic queue statistics, available for all the elements.
   Particular schedulers may have also their private records.
 */

struct tc_stats {
	__u64	bytes;			/* Number of enqueued bytes */
	__u32	packets;		/* Number of enqueued packets	*/
	__u32	drops;			/* Packets dropped because of lack of resources */
	__u32	overlimits;		/* Number of throttle events when this
					 * flow goes out of allocated bandwidth */
	__u32	bps;			/* Current flow byte rate */
	__u32	pps;			/* Current flow packet rate */
	__u32	qlen;
	__u32	backlog;
};

struct tc_estimator {
	signed char	interval;
	unsigned char	ewma_log;
};

/* "Handles"
   ---------

    All the traffic control objects have 32bit identifiers, or "handles".

    They can be considered as opaque numbers from user API viewpoint,
    but actually they always consist of two fields: major and
    minor numbers, which are interpreted by kernel specially,
    that may be used by applications, though not recommended.

    F.e. qdisc handles always have minor number equal to zero,
    classes (or flows) have major equal to parent qdisc major, and
    minor uniquely identifying class inside qdisc.

    Macros to manipulate handles:
 */

#define TC_H_MAJ_MASK (0xFFFF0000U)
#define TC_H_MIN_MASK (0x0000FFFFU)
#define TC_H_MAJ(h) ((h)&TC_H_MAJ_MASK)
#define TC_H_MIN(h) ((h)&TC_H_MIN_MASK)
#define TC_H_MAKE(maj,min) (((maj)&TC_H_MAJ_MASK)|((min)&TC_H_MIN_MASK))

#define TC_H_UNSPEC	(0U)
#define TC_H_ROOT	(0xFFFFFFFFU)
#define TC_H_INGRESS    (0xFFFFFFF1U)
#define TC_H_CLSACT	TC_H_INGRESS

#define TC_H_MIN_PRIORITY	0xFFE0U
#define TC_H_MIN_INGRESS	0xFFF2U
#define TC_H_MIN_EGRESS		0xFFF3U

/* Need to corrospond to iproute2 tc/tc_core.h "enum link_layer" */
enum tc_link_layer {
	TC_LINKLAYER_UNAWARE, /* Indicate unaware old iproute2 util */
	TC_LINKLAYER_ETHERNET,
	TC_LINKLAYER_ATM,
};
#define TC_LINKLAYER_MASK 0x0F /* limit use to lower 4 bits */

struct tc_ratespec {
	unsigned char	cell_log;
	__u8		linklayer; /* lower 4 bits */
	unsigned short	overhead;
	short		cell_align;
	unsigned short	mpu;
	__u32		rate;
};

#define TC_RTAB_SIZE	1024

struct tc_sizespec {
	unsigned char	cell_log;
	unsigned char	size_log;
	short		cell_align;
	int		overhead;
	unsigned int	linklayer;
	unsigned int	mpu;
	unsigned int	mtu;
	unsigned int	tsize;
};

enum {
	TCA_STAB_UNSPEC,
	TCA_STAB_BASE,
	TCA_STAB_DATA,
	__TCA_STAB_MAX
};

#define TCA_STAB_MAX (__TCA_STAB_MAX - 1)

/* FIFO section */

struct tc_fifo_qopt {
	__u32	limit;	/* Queue length: bytes for bfifo, packets for pfifo */
};

/* SKBPRIO section */

/*
 * Priorities go from zero to (SKBPRIO_MAX_PRIORITY - 1).
 * SKBPRIO_MAX_PRIORITY should be at least 64 in order for skbprio to be able
 * to map one to one the DS field of IPV4 and IPV6 headers.
 * Memory allocation grows linearly with SKBPRIO_MAX_PRIORITY.
 */

#define SKBPRIO_MAX_PRIORITY 64

struct tc_skbprio_qopt {
	__u32	limit;		/* Queue length in packets. */
};

/* PRIO section */

#define TCQ_PRIO_BANDS	16
#define TCQ_MIN_PRIO_BANDS 2

struct tc_prio_qopt {
	int	bands;			/* Number of bands */
	__u8	priomap[TC_PRIO_MAX+1];	/* Map: logical priority -> PRIO band */
};

/* MULTIQ section */

struct tc_multiq_qopt {
	__u16	bands;			/* Number of bands */
	__u16	max_bands;		/* Maximum number of queues */
};

/* PLUG section */

#define TCQ_PLUG_BUFFER                0
#define TCQ_PLUG_RELEASE_ONE           1
#define TCQ_PLUG_RELEASE_INDEFINITE    2
#define TCQ_PLUG_LIMIT                 3

struct tc_plug_qopt {
	/* TCQ_PLUG_BUFFER: Inset a plug into the queue and
	 *  buffer any incoming packets
	 * TCQ_PLUG_RELEASE_ONE: Dequeue packets from queue head
	 *   to beginning of the next plug.
	 * TCQ_PLUG_RELEASE_INDEFINITE: Dequeue all packets from queue.
	 *   Stop buffering packets until the next TCQ_PLUG_BUFFER
	 *   command is received (just act as a pass-thru queue).
	 * TCQ_PLUG_LIMIT: Increase/decrease queue size
	 */
	int             action;
	__u32           limit;
};

/* TBF section */

struct tc_tbf_qopt {
	struct tc_ratespec rate;
	struct tc_ratespec peakrate;
	__u32		limit;
	__u32		buffer;
	__u32		mtu;
};

enum {
	TCA_TBF_UNSPEC,
	TCA_TBF_PARMS,
	TCA_TBF_RTAB,
	TCA_TBF_PTAB,
	TCA_TBF_RATE64,
	TCA_TBF_PRATE64,
	TCA_TBF_BURST,
	TCA_TBF_PBURST,
	TCA_TBF_PAD,
	__TCA_TBF_MAX,
};

#define TCA_TBF_MAX (__TCA_TBF_MAX - 1)


/* TEQL section */

/* TEQL does not require any parameters */

/* SFQ section */

struct tc_sfq_qopt {
	unsigned	quantum;	/* Bytes per round allocated to flow */
	int		perturb_period;	/* Period of hash perturbation */
	__u32		limit;		/* Maximal packets in queue */
	unsigned	divisor;	/* Hash divisor  */
	unsigned	flows;		/* Maximal number of flows  */
};

struct tc_sfqred_stats {
	__u32           prob_drop;      /* Early drops, below max threshold */
	__u32           forced_drop;	/* Early drops, after max threshold */
	__u32           prob_mark;      /* Marked packets, below max threshold */
	__u32           forced_mark;    /* Marked packets, after max threshold */
	__u32           prob_mark_head; /* Marked packets, below max threshold */
	__u32           forced_mark_head;/* Marked packets, after max threshold */
};

struct tc_sfq_qopt_v1 {
	struct tc_sfq_qopt v0;
	unsigned int	depth;		/* max number of packets per flow */
	unsigned int	headdrop;
/* SFQRED parameters */
	__u32		limit;		/* HARD maximal flow queue length (bytes) */
	__u32		qth_min;	/* Min average length threshold (bytes) */
	__u32		qth_max;	/* Max average length threshold (bytes) */
	unsigned char   Wlog;		/* log(W)		*/
	unsigned char   Plog;		/* log(P_max/(qth_max-qth_min))	*/
	unsigned char   Scell_log;	/* cell size for idle damping */
	unsigned char	flags;
	__u32		max_P;		/* probability, high resolution */
/* SFQRED stats */
	struct tc_sfqred_stats stats;
};


struct tc_sfq_xstats {
	__s32		allot;
};

/* RED section */

enum {
	TCA_RED_UNSPEC,
	TCA_RED_PARMS,
	TCA_RED_STAB,
	TCA_RED_MAX_P,
	TCA_RED_FLAGS,		/* bitfield32 */
	TCA_RED_EARLY_DROP_BLOCK, /* u32 */
	TCA_RED_MARK_BLOCK,	/* u32 */
	__TCA_RED_MAX,
};

#define TCA_RED_MAX (__TCA_RED_MAX - 1)

struct tc_red_qopt {
	__u32		limit;		/* HARD maximal queue length (bytes)	*/
	__u32		qth_min;	/* Min average length threshold (bytes) */
	__u32		qth_max;	/* Max average length threshold (bytes) */
	unsigned char   Wlog;		/* log(W)		*/
	unsigned char   Plog;		/* log(P_max/(qth_max-qth_min))	*/
	unsigned char   Scell_log;	/* cell size for idle damping */

	/* This field can be used for flags that a RED-like qdisc has
	 * historically supported. E.g. when configuring RED, it can be used for
	 * ECN, HARDDROP and ADAPTATIVE. For SFQ it can be used for ECN,
	 * HARDDROP. Etc. Because this field has not been validated, and is
	 * copied back on dump, any bits besides those to which a given qdisc
	 * has assigned a historical meaning need to be considered for free use
	 * by userspace tools.
	 *
	 * Any further flags need to be passed differently, e.g. through an
	 * attribute (such as TCA_RED_FLAGS above). Such attribute should allow
	 * passing both recent and historic flags in one value.
	 */
	unsigned char	flags;
#define TC_RED_ECN		1
#define TC_RED_HARDDROP		2
#define TC_RED_ADAPTATIVE	4
#define TC_RED_NODROP		8
};

#define TC_RED_HISTORIC_FLAGS (TC_RED_ECN | TC_RED_HARDDROP | TC_RED_ADAPTATIVE)

struct tc_red_xstats {
	__u32           early;          /* Early drops */
	__u32           pdrop;          /* Drops due to queue limits */
	__u32           other;          /* Drops due to drop() calls */
	__u32           marked;         /* Marked packets */
};

/* GRED section */

#define MAX_DPs 16

enum {
       TCA_GRED_UNSPEC,
       TCA_GRED_PARMS,
       TCA_GRED_STAB,
       TCA_GRED_DPS,
       TCA_GRED_MAX_P,
       TCA_GRED_LIMIT,
       TCA_GRED_VQ_LIST,	/* nested TCA_GRED_VQ_ENTRY */
       __TCA_GRED_MAX,
};

#define TCA_GRED_MAX (__TCA_GRED_MAX - 1)

enum {
	TCA_GRED_VQ_ENTRY_UNSPEC,
	TCA_GRED_VQ_ENTRY,	/* nested TCA_GRED_VQ_* */
	__TCA_GRED_VQ_ENTRY_MAX,
};
#define TCA_GRED_VQ_ENTRY_MAX (__TCA_GRED_VQ_ENTRY_MAX - 1)

enum {
	TCA_GRED_VQ_UNSPEC,
	TCA_GRED_VQ_PAD,
	TCA_GRED_VQ_DP,			/* u32 */
	TCA_GRED_VQ_STAT_BYTES,		/* u64 */
	TCA_GRED_VQ_STAT_PACKETS,	/* u32 */
	TCA_GRED_VQ_STAT_BACKLOG,	/* u32 */
	TCA_GRED_VQ_STAT_PROB_DROP,	/* u32 */
	TCA_GRED_VQ_STAT_PROB_MARK,	/* u32 */
	TCA_GRED_VQ_STAT_FORCED_DROP,	/* u32 */
	TCA_GRED_VQ_STAT_FORCED_MARK,	/* u32 */
	TCA_GRED_VQ_STAT_PDROP,		/* u32 */
	TCA_GRED_VQ_STAT_OTHER,		/* u32 */
	TCA_GRED_VQ_FLAGS,		/* u32 */
	__TCA_GRED_VQ_MAX
};

#define TCA_GRED_VQ_MAX (__TCA_GRED_VQ_MAX - 1)

struct tc_gred_qopt {
	__u32		limit;        /* HARD maximal queue length (bytes)    */
	__u32		qth_min;      /* Min average length threshold (bytes) */
	__u32		qth_max;      /* Max average length threshold (bytes) */
	__u32		DP;           /* up to 2^32 DPs */
	__u32		backlog;
	__u32		qave;
	__u32		forced;
	__u32		early;
	__u32		other;
	__u32		pdrop;
	__u8		Wlog;         /* log(W)               */
	__u8		Plog;         /* log(P_max/(qth_max-qth_min)) */
	__u8		Scell_log;    /* cell size for idle damping */
	__u8		prio;         /* prio of this VQ */
	__u32		packets;
	__u32		bytesin;
};

/* gred setup */
struct tc_gred_sopt {
	__u32		DPs;
	__u32		def_DP;
	__u8		grio;
	__u8		flags;
	__u16		pad1;
};

/* CHOKe section */

enum {
	TCA_CHOKE_UNSPEC,
	TCA_CHOKE_PARMS,
	TCA_CHOKE_STAB,
	TCA_CHOKE_MAX_P,
	__TCA_CHOKE_MAX,
};

#define TCA_CHOKE_MAX (__TCA_CHOKE_MAX - 1)

struct tc_choke_qopt {
	__u32		limit;		/* Hard queue length (packets)	*/
	__u32		qth_min;	/* Min average threshold (packets) */
	__u32		qth_max;	/* Max average threshold (packets) */
	unsigned char   Wlog;		/* log(W)		*/
	unsigned char   Plog;		/* log(P_max/(qth_max-qth_min))	*/
	unsigned char   Scell_log;	/* cell size for idle damping */
	unsigned char	flags;		/* see RED flags */
};

struct tc_choke_xstats {
	__u32		early;          /* Early drops */
	__u32		pdrop;          /* Drops due to queue limits */
	__u32		other;          /* Drops due to drop() calls */
	__u32		marked;         /* Marked packets */
	__u32		matched;	/* Drops due to flow match */
};

/* HTB section */
#define TC_HTB_NUMPRIO		8
#define TC_HTB_MAXDEPTH		8
#define TC_HTB_PROTOVER		3 /* the same as HTB and TC's major */

struct tc_htb_opt {
	struct tc_ratespec 	rate;
	struct tc_ratespec 	ceil;
	__u32	buffer;
	__u32	cbuffer;
	__u32	quantum;
	__u32	level;		/* out only */
	__u32	prio;
};
struct tc_htb_glob {
	__u32 version;		/* to match HTB/TC */
    	__u32 rate2quantum;	/* bps->quantum divisor */
    	__u32 defcls;		/* default class number */
	__u32 debug;		/* debug flags */

	/* stats */
	__u32 direct_pkts; /* count of non shaped packets */
};
enum {
	TCA_HTB_UNSPEC,
	TCA_HTB_PARMS,
	TCA_HTB_INIT,
	TCA_HTB_CTAB,
	TCA_HTB_RTAB,
	TCA_HTB_DIRECT_QLEN,
	TCA_HTB_RATE64,
	TCA_HTB_CEIL64,
	TCA_HTB_PAD,
	TCA_HTB_OFFLOAD,
	__TCA_HTB_MAX,
};

#define TCA_HTB_MAX (__TCA_HTB_MAX - 1)

struct tc_htb_xstats {
	__u32 lends;
	__u32 borrows;
	__u32 giants;	/* unused since 'Make HTB scheduler work with TSO.' */
	__s32 tokens;
	__s32 ctokens;
};

/* HFSC section */

struct tc_hfsc_qopt {
	__u16	defcls;		/* default class */
};

struct tc_service_curve {
	__u32	m1;		/* slope of the first segment in bps */
	__u32	d;		/* x-projection of the first segment in us */
	__u32	m2;		/* slope of the second segment in bps */
};

struct tc_hfsc_stats {
	__u64	work;		/* total work done */
	__u64	rtwork;		/* work done by real-time criteria */
	__u32	period;		/* current period */
	__u32	level;		/* class level in hierarchy */
};

enum {
	TCA_HFSC_UNSPEC,
	TCA_HFSC_RSC,
	TCA_HFSC_FSC,
	TCA_HFSC_USC,
	__TCA_HFSC_MAX,
};

#define TCA_HFSC_MAX (__TCA_HFSC_MAX - 1)


/* CBQ section */

#define TC_CBQ_MAXPRIO		8
#define TC_CBQ_MAXLEVEL		8
#define TC_CBQ_DEF_EWMA		5

struct tc_cbq_lssopt {
	unsigned char	change;
	unsigned char	flags;
#define TCF_CBQ_LSS_BOUNDED	1
#define TCF_CBQ_LSS_ISOLATED	2
	unsigned char  	ewma_log;
	unsigned char  	level;
#define TCF_CBQ_LSS_FLAGS	1
#define TCF_CBQ_LSS_EWMA	2
#define TCF_CBQ_LSS_MAXIDLE	4
#define TCF_CBQ_LSS_MINIDLE	8
#define TCF_CBQ_LSS_OFFTIME	0x10
#define TCF_CBQ_LSS_AVPKT	0x20
	__u32		maxidle;
	__u32		minidle;
	__u32		offtime;
	__u32		avpkt;
};

struct tc_cbq_wrropt {
	unsigned char	flags;
	unsigned char	priority;
	unsigned char	cpriority;
	unsigned char	__reserved;
	__u32		allot;
	__u32		weight;
};

struct tc_cbq_ovl {
	unsigned char	strategy;
#define	TC_CBQ_OVL_CLASSIC	0
#define	TC_CBQ_OVL_DELAY	1
#define	TC_CBQ_OVL_LOWPRIO	2
#define	TC_CBQ_OVL_DROP		3
#define	TC_CBQ_OVL_RCLASSIC	4
	unsigned char	priority2;
	__u16		pad;
	__u32		penalty;
};

struct tc_cbq_police {
	unsigned char	police;
	unsigned char	__res1;
	unsigned short	__res2;
};

struct tc_cbq_fopt {
	__u32		split;
	__u32		defmap;
	__u32		defchange;
};

struct tc_cbq_xstats {
	__u32		borrows;
	__u32		overactions;
	__s32		avgidle;
	__s32		undertime;
};

enum {
	TCA_CBQ_UNSPEC,
	TCA_CBQ_LSSOPT,
	TCA_CBQ_WRROPT,
	TCA_CBQ_FOPT,
	TCA_CBQ_OVL_STRATEGY,
	TCA_CBQ_RATE,
	TCA_CBQ_RTAB,
	TCA_CBQ_POLICE,
	__TCA_CBQ_MAX,
};

#define TCA_CBQ_MAX	(__TCA_CBQ_MAX - 1)

/* dsmark section */

enum {
	TCA_DSMARK_UNSPEC,
	TCA_DSMARK_INDICES,
	TCA_DSMARK_DEFAULT_INDEX,
	TCA_DSMARK_SET_TC_INDEX,
	TCA_DSMARK_MASK,
	TCA_DSMARK_VALUE,
	__TCA_DSMARK_MAX,
};

#define TCA_DSMARK_MAX (__TCA_DSMARK_MAX - 1)

/* ATM  section */

enum {
	TCA_ATM_UNSPEC,
	TCA_ATM_FD,		/* file/socket descriptor */
	TCA_ATM_PTR,		/* pointer to descriptor - later */
	TCA_ATM_HDR,		/* LL header */
	TCA_ATM_EXCESS,		/* excess traffic class (0 for CLP)  */
	TCA_ATM_ADDR,		/* PVC address (for output only) */
	TCA_ATM_STATE,		/* VC state (ATM_VS_*; for output only) */
	__TCA_ATM_MAX,
};

#define TCA_ATM_MAX	(__TCA_ATM_MAX - 1)

/* Network emulator */

enum {
	TCA_NETEM_UNSPEC,
	TCA_NETEM_CORR,
	TCA_NETEM_DELAY_DIST,
	TCA_NETEM_REORDER,
	TCA_NETEM_CORRUPT,
	TCA_NETEM_LOSS,
	TCA_NETEM_RATE,
	TCA_NETEM_ECN,
	TCA_NETEM_RATE64,
	TCA_NETEM_PAD,
	TCA_NETEM_LATENCY64,
	TCA_NETEM_JITTER64,
	TCA_NETEM_SLOT,
	TCA_NETEM_SLOT_DIST,
	__TCA_NETEM_MAX,
};

#define TCA_NETEM_MAX (__TCA_NETEM_MAX - 1)

struct tc_netem_qopt {
	__u32	latency;	/* added delay (us) */
	__u32   limit;		/* fifo limit (packets) */
	__u32	loss;		/* random packet loss (0=none ~0=100%) */
	__u32	gap;		/* re-ordering gap (0 for none) */
	__u32   duplicate;	/* random packet dup  (0=none ~0=100%) */
	__u32	jitter;		/* random jitter in latency (us) */
};

struct tc_netem_corr {
	__u32	delay_corr;	/* delay correlation */
	__u32	loss_corr;	/* packet loss correlation */
	__u32	dup_corr;	/* duplicate correlation  */
};

struct tc_netem_reorder {
	__u32	probability;
	__u32	correlation;
};

struct tc_netem_corrupt {
	__u32	probability;
	__u32	correlation;
};

struct tc_netem_rate {
	__u32	rate;	/* byte/s */
	__s32	packet_overhead;
	__u32	cell_size;
	__s32	cell_overhead;
};

struct tc_netem_slot {
	__s64   min_delay; /* nsec */
	__s64   max_delay;
	__s32   max_packets;
	__s32   max_bytes;
	__s64	dist_delay; /* nsec */
	__s64	dist_jitter; /* nsec */
};

enum {
	NETEM_LOSS_UNSPEC,
	NETEM_LOSS_GI,		/* General Intuitive - 4 state model */
	NETEM_LOSS_GE,		/* Gilbert Elliot models */
	__NETEM_LOSS_MAX
};
#define NETEM_LOSS_MAX (__NETEM_LOSS_MAX - 1)

/* State transition probabilities for 4 state model */
struct tc_netem_gimodel {
	__u32	p13;
	__u32	p31;
	__u32	p32;
	__u32	p14;
	__u32	p23;
};

/* Gilbert-Elliot models */
struct tc_netem_gemodel {
	__u32 p;
	__u32 r;
	__u32 h;
	__u32 k1;
};

#define NETEM_DIST_SCALE	8192
#define NETEM_DIST_MAX		16384

/* DRR */

enum {
	TCA_DRR_UNSPEC,
	TCA_DRR_QUANTUM,
	__TCA_DRR_MAX
};

#define TCA_DRR_MAX	(__TCA_DRR_MAX - 1)

struct tc_drr_stats {
	__u32	deficit;
};

/* MQPRIO */
#define TC_QOPT_BITMASK 15
#define TC_QOPT_MAX_QUEUE 16

enum {
	TC_MQPRIO_HW_OFFLOAD_NONE,	/* no offload requested */
	TC_MQPRIO_HW_OFFLOAD_TCS,	/* offload TCs, no queue counts */
	__TC_MQPRIO_HW_OFFLOAD_MAX
};

#define TC_MQPRIO_HW_OFFLOAD_MAX (__TC_MQPRIO_HW_OFFLOAD_MAX - 1)

enum {
	TC_MQPRIO_MODE_DCB,
	TC_MQPRIO_MODE_CHANNEL,
	__TC_MQPRIO_MODE_MAX
};

#define __TC_MQPRIO_MODE_MAX (__TC_MQPRIO_MODE_MAX - 1)

enum {
	TC_MQPRIO_SHAPER_DCB,
	TC_MQPRIO_SHAPER_BW_RATE,	/* Add new shapers below */
	__TC_MQPRIO_SHAPER_MAX
};

#define __TC_MQPRIO_SHAPER_MAX (__TC_MQPRIO_SHAPER_MAX - 1)

struct tc_mqprio_qopt {
	__u8	num_tc;
	__u8	prio_tc_map[TC_QOPT_BITMASK + 1];
	__u8	hw;
	__u16	count[TC_QOPT_MAX_QUEUE];
	__u16	offset[TC_QOPT_MAX_QUEUE];
};

#define TC_MQPRIO_F_MODE		0x1
#define TC_MQPRIO_F_SHAPER		0x2
#define TC_MQPRIO_F_MIN_RATE		0x4
#define TC_MQPRIO_F_MAX_RATE		0x8

enum {
	TCA_MQPRIO_UNSPEC,
	TCA_MQPRIO_MODE,
	TCA_MQPRIO_SHAPER,
	TCA_MQPRIO_MIN_RATE64,
	TCA_MQPRIO_MAX_RATE64,
	__TCA_MQPRIO_MAX,
};

#define TCA_MQPRIO_MAX (__TCA_MQPRIO_MAX - 1)

/* SFB */

enum {
	TCA_SFB_UNSPEC,
	TCA_SFB_PARMS,
	__TCA_SFB_MAX,
};

#define TCA_SFB_MAX (__TCA_SFB_MAX - 1)

/*
 * Note: increment, decrement are Q0.16 fixed-point values.
 */
struct tc_sfb_qopt {
	__u32 rehash_interval;	/* delay between hash move, in ms */
	__u32 warmup_time;	/* double buffering warmup time in ms (warmup_time < rehash_interval) */
	__u32 max;		/* max len of qlen_min */
	__u32 bin_size;		/* maximum queue length per bin */
	__u32 increment;	/* probability increment, (d1 in Blue) */
	__u32 decrement;	/* probability decrement, (d2 in Blue) */
	__u32 limit;		/* max SFB queue length */
	__u32 penalty_rate;	/* inelastic flows are rate limited to 'rate' pps */
	__u32 penalty_burst;
};

struct tc_sfb_xstats {
	__u32 earlydrop;
	__u32 penaltydrop;
	__u32 bucketdrop;
	__u32 queuedrop;
	__u32 childdrop; /* drops in child qdisc */
	__u32 marked;
	__u32 maxqlen;
	__u32 maxprob;
	__u32 avgprob;
};

#define SFB_MAX_PROB 0xFFFF

/* QFQ */
enum {
	TCA_QFQ_UNSPEC,
	TCA_QFQ_WEIGHT,
	TCA_QFQ_LMAX,
	__TCA_QFQ_MAX
};

#define TCA_QFQ_MAX	(__TCA_QFQ_MAX - 1)

struct tc_qfq_stats {
	__u32 weight;
	__u32 lmax;
};

/* CODEL */

enum {
	TCA_CODEL_UNSPEC,
	TCA_CODEL_TARGET,
	TCA_CODEL_LIMIT,
	TCA_CODEL_INTERVAL,
	TCA_CODEL_ECN,
	TCA_CODEL_CE_THRESHOLD,
	__TCA_CODEL_MAX
};

#define TCA_CODEL_MAX	(__TCA_CODEL_MAX - 1)

struct tc_codel_xstats {
	__u32	maxpacket; /* largest packet we've seen so far */
	__u32	count;	   /* how many drops we've done since the last time we
			    * entered dropping state
			    */
	__u32	lastcount; /* count at entry to dropping state */
	__u32	ldelay;    /* in-queue delay seen by most recently dequeued packet */
	__s32	drop_next; /* time to drop next packet */
	__u32	drop_overlimit; /* number of time max qdisc packet limit was hit */
	__u32	ecn_mark;  /* number of packets we ECN marked instead of dropped */
	__u32	dropping;  /* are we in dropping state ? */
	__u32	ce_mark;   /* number of CE marked packets because of ce_threshold */
};

/* FQ_CODEL */

#define FQ_CODEL_QUANTUM_MAX (1 << 20)

enum {
	TCA_FQ_CODEL_UNSPEC,
	TCA_FQ_CODEL_TARGET,
	TCA_FQ_CODEL_LIMIT,
	TCA_FQ_CODEL_INTERVAL,
	TCA_FQ_CODEL_ECN,
	TCA_FQ_CODEL_FLOWS,
	TCA_FQ_CODEL_QUANTUM,
	TCA_FQ_CODEL_CE_THRESHOLD,
	TCA_FQ_CODEL_DROP_BATCH_SIZE,
	TCA_FQ_CODEL_MEMORY_LIMIT,
	TCA_FQ_CODEL_CE_THRESHOLD_SELECTOR,
	TCA_FQ_CODEL_CE_THRESHOLD_MASK,
	__TCA_FQ_CODEL_MAX
};

#define TCA_FQ_CODEL_MAX	(__TCA_FQ_CODEL_MAX - 1)

enum {
	TCA_FQ_CODEL_XSTATS_QDISC,
	TCA_FQ_CODEL_XSTATS_CLASS,
};

struct tc_fq_codel_qd_stats {
	__u32	maxpacket;	/* largest packet we've seen so far */
	__u32	drop_overlimit; /* number of time max qdisc
				 * packet limit was hit
				 */
	__u32	ecn_mark;	/* number of packets we ECN marked
				 * instead of being dropped
				 */
	__u32	new_flow_count; /* number of time packets
				 * created a 'new flow'
				 */
	__u32	new_flows_len;	/* count of flows in new list */
	__u32	old_flows_len;	/* count of flows in old list */
	__u32	ce_mark;	/* packets above ce_threshold */
	__u32	memory_usage;	/* in bytes */
	__u32	drop_overmemory;
};

struct tc_fq_codel_cl_stats {
	__s32	deficit;
	__u32	ldelay;		/* in-queue delay seen by most recently
				 * dequeued packet
				 */
	__u32	count;
	__u32	lastcount;
	__u32	dropping;
	__s32	drop_next;
};

struct tc_fq_codel_xstats {
	__u32	type;
	union {
		struct tc_fq_codel_qd_stats qdisc_stats;
		struct tc_fq_codel_cl_stats class_stats;
	};
};

/* FQ */

enum {
	TCA_FQ_UNSPEC,

	TCA_FQ_PLIMIT,		/* limit of total number of packets in queue */

	TCA_FQ_FLOW_PLIMIT,	/* limit of packets per flow */

	TCA_FQ_QUANTUM,		/* RR quantum */

	TCA_FQ_INITIAL_QUANTUM,		/* RR quantum for new flow */

	TCA_FQ_RATE_ENABLE,	/* enable/disable rate limiting */

	TCA_FQ_FLOW_DEFAULT_RATE,/* obsolete, do not use */

	TCA_FQ_FLOW_MAX_RATE,	/* per flow max rate */

	TCA_FQ_BUCKETS_LOG,	/* log2(number of buckets) */

	TCA_FQ_FLOW_REFILL_DELAY,	/* flow credit refill delay in usec */

	TCA_FQ_ORPHAN_MASK,	/* mask applied to orphaned skb hashes */

	TCA_FQ_LOW_RATE_THRESHOLD, /* per packet delay under this rate */

	TCA_FQ_CE_THRESHOLD,	/* DCTCP-like CE-marking threshold */

	TCA_FQ_TIMER_SLACK,	/* timer slack */

	TCA_FQ_HORIZON,		/* time horizon in us */

	TCA_FQ_HORIZON_DROP,	/* drop packets beyond horizon, or cap their EDT */

	__TCA_FQ_MAX
};

#define TCA_FQ_MAX	(__TCA_FQ_MAX - 1)

struct tc_fq_qd_stats {
	__u64	gc_flows;
	__u64	highprio_packets;
	__u64	tcp_retrans;
	__u64	throttled;
	__u64	flows_plimit;
	__u64	pkts_too_long;
	__u64	allocation_errors;
	__s64	time_next_delayed_flow;
	__u32	flows;
	__u32	inactive_flows;
	__u32	throttled_flows;
	__u32	unthrottle_latency_ns;
	__u64	ce_mark;		/* packets above ce_threshold */
	__u64	horizon_drops;
	__u64	horizon_caps;
};

/* Heavy-Hitter Filter */

enum {
	TCA_HHF_UNSPEC,
	TCA_HHF_BACKLOG_LIMIT,
	TCA_HHF_QUANTUM,
	TCA_HHF_HH_FLOWS_LIMIT,
	TCA_HHF_RESET_TIMEOUT,
	TCA_HHF_ADMIT_BYTES,
	TCA_HHF_EVICT_TIMEOUT,
	TCA_HHF_NON_HH_WEIGHT,
	__TCA_HHF_MAX
};

#define TCA_HHF_MAX	(__TCA_HHF_MAX - 1)

struct tc_hhf_xstats {
	__u32	drop_overlimit; /* number of times max qdisc packet limit
				 * was hit
				 */
	__u32	hh_overlimit;   /* number of times max heavy-hitters was hit */
	__u32	hh_tot_count;   /* number of captured heavy-hitters so far */
	__u32	hh_cur_count;   /* number of current heavy-hitters */
};

/* PIE */
enum {
	TCA_PIE_UNSPEC,
	TCA_PIE_TARGET,
	TCA_PIE_LIMIT,
	TCA_PIE_TUPDATE,
	TCA_PIE_ALPHA,
	TCA_PIE_BETA,
	TCA_PIE_ECN,
	TCA_PIE_BYTEMODE,
	TCA_PIE_DQ_RATE_ESTIMATOR,
	__TCA_PIE_MAX
};
#define TCA_PIE_MAX   (__TCA_PIE_MAX - 1)

struct tc_pie_xstats {
	__u64 prob;			/* current probability */
	__u32 delay;			/* current delay in ms */
	__u32 avg_dq_rate;		/* current average dq_rate in
					 * bits/pie_time
					 */
	__u32 dq_rate_estimating;	/* is avg_dq_rate being calculated? */
	__u32 packets_in;		/* total number of packets enqueued */
	__u32 dropped;			/* packets dropped due to pie_action */
	__u32 overlimit;		/* dropped due to lack of space
					 * in queue
					 */
	__u32 maxq;			/* maximum queue size */
	__u32 ecn_mark;			/* packets marked with ecn*/
};

/* FQ PIE */
enum {
	TCA_FQ_PIE_UNSPEC,
	TCA_FQ_PIE_LIMIT,
	TCA_FQ_PIE_FLOWS,
	TCA_FQ_PIE_TARGET,
	TCA_FQ_PIE_TUPDATE,
	TCA_FQ_PIE_ALPHA,
	TCA_FQ_PIE_BETA,
	TCA_FQ_PIE_QUANTUM,
	TCA_FQ_PIE_MEMORY_LIMIT,
	TCA_FQ_PIE_ECN_PROB,
	TCA_FQ_PIE_ECN,
	TCA_FQ_PIE_BYTEMODE,
	TCA_FQ_PIE_DQ_RATE_ESTIMATOR,
	__TCA_FQ_PIE_MAX
};
#define TCA_FQ_PIE_MAX   (__TCA_FQ_PIE_MAX - 1)

struct tc_fq_pie_xstats {
	__u32 packets_in;	/* total number of packets enqueued */
	__u32 dropped;		/* packets dropped due to fq_pie_action */
	__u32 overlimit;	/* dropped due to lack of space in queue */
	__u32 overmemory;	/* dropped due to lack of memory in queue */
	__u32 ecn_mark;		/* packets marked with ecn */
	__u32 new_flow_count;	/* count of new flows created by packets */
	__u32 new_flows_len;	/* count of flows in new list */
	__u32 old_flows_len;	/* count of flows in old list */
	__u32 memory_usage;	/* total memory across all queues */
};

/* CBS */
struct tc_cbs_qopt {
	__u8 offload;
	__u8 _pad[3];
	__s32 hicredit;
	__s32 locredit;
	__s32 idleslope;
	__s32 sendslope;
};

enum {
	TCA_CBS_UNSPEC,
	TCA_CBS_PARMS,
	__TCA_CBS_MAX,
};

#define TCA_CBS_MAX (__TCA_CBS_MAX - 1)


/* ETF */
struct tc_etf_qopt {
	__s32 delta;
	__s32 clockid;
	__u32 flags;
#define TC_ETF_DEADLINE_MODE_ON	_BITUL(0)
#define TC_ETF_OFFLOAD_ON	_BITUL(1)
#define TC_ETF_SKIP_SOCK_CHECK	_BITUL(2)
};

enum {
	TCA_ETF_UNSPEC,
	TCA_ETF_PARMS,
	__TCA_ETF_MAX,
};

#define TCA_ETF_MAX (__TCA_ETF_MAX - 1)


/* CAKE */
enum {
	TCA_CAKE_UNSPEC,
	TCA_CAKE_PAD,
	TCA_CAKE_BASE_RATE64,
	TCA_CAKE_DIFFSERV_MODE,
	TCA_CAKE_ATM,
	TCA_CAKE_FLOW_MODE,
	TCA_CAKE_OVERHEAD,
	TCA_CAKE_RTT,
	TCA_CAKE_TARGET,
	TCA_CAKE_AUTORATE,
	TCA_CAKE_MEMORY,
	TCA_CAKE_NAT,
	TCA_CAKE_RAW,
	TCA_CAKE_WASH,
	TCA_CAKE_MPU,
	TCA_CAKE_INGRESS,
	TCA_CAKE_ACK_FILTER,
	TCA_CAKE_SPLIT_GSO,
	TCA_CAKE_FWMARK,
	__TCA_CAKE_MAX
};
#define TCA_CAKE_MAX	(__TCA_CAKE_MAX - 1)

enum {
	__TCA_CAKE_STATS_INVALID,
	TCA_CAKE_STATS_PAD,
	TCA_CAKE_STATS_CAPACITY_ESTIMATE64,
	TCA_CAKE_STATS_MEMORY_LIMIT,
	TCA_CAKE_STATS_MEMORY_USED,
	TCA_CAKE_STATS_AVG_NETOFF,
	TCA_CAKE_STATS_MIN_NETLEN,
	TCA_CAKE_STATS_MAX_NETLEN,
	TCA_CAKE_STATS_MIN_ADJLEN,
	TCA_CAKE_STATS_MAX_ADJLEN,
	TCA_CAKE_STATS_TIN_STATS,
	TCA_CAKE_STATS_DEFICIT,
	TCA_CAKE_STATS_COBALT_COUNT,
	TCA_CAKE_STATS_DROPPING,
	TCA_CAKE_STATS_DROP_NEXT_US,
	TCA_CAKE_STATS_P_DROP,
	TCA_CAKE_STATS_BLUE_TIMER_US,
	__TCA_CAKE_STATS_MAX
};
#define TCA_CAKE_STATS_MAX (__TCA_CAKE_STATS_MAX - 1)

enum {
	__TCA_CAKE_TIN_STATS_INVALID,
	TCA_CAKE_TIN_STATS_PAD,
	TCA_CAKE_TIN_STATS_SENT_PACKETS,
	TCA_CAKE_TIN_STATS_SENT_BYTES64,
	TCA_CAKE_TIN_STATS_DROPPED_PACKETS,
	TCA_CAKE_TIN_STATS_DROPPED_BYTES64,
	TCA_CAKE_TIN_STATS_ACKS_DROPPED_PACKETS,
	TCA_CAKE_TIN_STATS_ACKS_DROPPED_BYTES64,
	TCA_CAKE_TIN_STATS_ECN_MARKED_PACKETS,
	TCA_CAKE_TIN_STATS_ECN_MARKED_BYTES64,
	TCA_CAKE_TIN_STATS_BACKLOG_PACKETS,
	TCA_CAKE_TIN_STATS_BACKLOG_BYTES,
	TCA_CAKE_TIN_STATS_THRESHOLD_RATE64,
	TCA_CAKE_TIN_STATS_TARGET_US,
	TCA_CAKE_TIN_STATS_INTERVAL_US,
	TCA_CAKE_TIN_STATS_WAY_INDIRECT_HITS,
	TCA_CAKE_TIN_STATS_WAY_MISSES,
	TCA_CAKE_TIN_STATS_WAY_COLLISIONS,
	TCA_CAKE_TIN_STATS_PEAK_DELAY_US,
	TCA_CAKE_TIN_STATS_AVG_DELAY_US,
	TCA_CAKE_TIN_STATS_BASE_DELAY_US,
	TCA_CAKE_TIN_STATS_SPARSE_FLOWS,
	TCA_CAKE_TIN_STATS_BULK_FLOWS,
	TCA_CAKE_TIN_STATS_UNRESPONSIVE_FLOWS,
	TCA_CAKE_TIN_STATS_MAX_SKBLEN,
	TCA_CAKE_TIN_STATS_FLOW_QUANTUM,
	__TCA_CAKE_TIN_STATS_MAX
};
#define TCA_CAKE_TIN_STATS_MAX (__TCA_CAKE_TIN_STATS_MAX - 1)
#define TC_CAKE_MAX_TINS (8)

enum {
	CAKE_FLOW_NONE = 0,
	CAKE_FLOW_SRC_IP,
	CAKE_FLOW_DST_IP,
	CAKE_FLOW_HOSTS,    /* = CAKE_FLOW_SRC_IP | CAKE_FLOW_DST_IP */
	CAKE_FLOW_FLOWS,
	CAKE_FLOW_DUAL_SRC, /* = CAKE_FLOW_SRC_IP | CAKE_FLOW_FLOWS */
	CAKE_FLOW_DUAL_DST, /* = CAKE_FLOW_DST_IP | CAKE_FLOW_FLOWS */
	CAKE_FLOW_TRIPLE,   /* = CAKE_FLOW_HOSTS  | CAKE_FLOW_FLOWS */
	CAKE_FLOW_MAX,
};

enum {
	CAKE_DIFFSERV_DIFFSERV3 = 0,
	CAKE_DIFFSERV_DIFFSERV4,
	CAKE_DIFFSERV_DIFFSERV8,
	CAKE_DIFFSERV_BESTEFFORT,
	CAKE_DIFFSERV_PRECEDENCE,
	CAKE_DIFFSERV_MAX
};

enum {
	CAKE_ACK_NONE = 0,
	CAKE_ACK_FILTER,
	CAKE_ACK_AGGRESSIVE,
	CAKE_ACK_MAX
};

enum {
	CAKE_ATM_NONE = 0,
	CAKE_ATM_ATM,
	CAKE_ATM_PTM,
	CAKE_ATM_MAX
};


/* TAPRIO */
enum {
	TC_TAPRIO_CMD_SET_GATES = 0x00,
	TC_TAPRIO_CMD_SET_AND_HOLD = 0x01,
	TC_TAPRIO_CMD_SET_AND_RELEASE = 0x02,
};

enum {
	TCA_TAPRIO_SCHED_ENTRY_UNSPEC,
	TCA_TAPRIO_SCHED_ENTRY_INDEX, /* u32 */
	TCA_TAPRIO_SCHED_ENTRY_CMD, /* u8 */
	TCA_TAPRIO_SCHED_ENTRY_GATE_MASK, /* u32 */
	TCA_TAPRIO_SCHED_ENTRY_INTERVAL, /* u32 */
	__TCA_TAPRIO_SCHED_ENTRY_MAX,
};
#define TCA_TAPRIO_SCHED_ENTRY_MAX (__TCA_TAPRIO_SCHED_ENTRY_MAX - 1)

/* The format for schedule entry list is:
 * [TCA_TAPRIO_SCHED_ENTRY_LIST]
 *   [TCA_TAPRIO_SCHED_ENTRY]
 *     [TCA_TAPRIO_SCHED_ENTRY_CMD]
 *     [TCA_TAPRIO_SCHED_ENTRY_GATES]
 *     [TCA_TAPRIO_SCHED_ENTRY_INTERVAL]
 */
enum {
	TCA_TAPRIO_SCHED_UNSPEC,
	TCA_TAPRIO_SCHED_ENTRY,
	__TCA_TAPRIO_SCHED_MAX,
};

#define TCA_TAPRIO_SCHED_MAX (__TCA_TAPRIO_SCHED_MAX - 1)

/* The format for the admin sched (dump only):
 * [TCA_TAPRIO_SCHED_ADMIN_SCHED]
 *   [TCA_TAPRIO_ATTR_SCHED_BASE_TIME]
 *   [TCA_TAPRIO_ATTR_SCHED_ENTRY_LIST]
 *     [TCA_TAPRIO_ATTR_SCHED_ENTRY]
 *       [TCA_TAPRIO_ATTR_SCHED_ENTRY_CMD]
 *       [TCA_TAPRIO_ATTR_SCHED_ENTRY_GATES]
 *       [TCA_TAPRIO_ATTR_SCHED_ENTRY_INTERVAL]
 */

#define TCA_TAPRIO_ATTR_FLAG_TXTIME_ASSIST	_BITUL(0)
#define TCA_TAPRIO_ATTR_FLAG_FULL_OFFLOAD	_BITUL(1)

enum {
	TCA_TAPRIO_TC_ENTRY_UNSPEC,
	TCA_TAPRIO_TC_ENTRY_INDEX,		/* u32 */
	TCA_TAPRIO_TC_ENTRY_MAX_SDU,		/* u32 */

	/* add new constants above here */
	__TCA_TAPRIO_TC_ENTRY_CNT,
	TCA_TAPRIO_TC_ENTRY_MAX = (__TCA_TAPRIO_TC_ENTRY_CNT - 1)
};

enum {
	TCA_TAPRIO_ATTR_UNSPEC,
	TCA_TAPRIO_ATTR_PRIOMAP, /* struct tc_mqprio_qopt */
	TCA_TAPRIO_ATTR_SCHED_ENTRY_LIST, /* nested of entry */
	TCA_TAPRIO_ATTR_SCHED_BASE_TIME, /* s64 */
	TCA_TAPRIO_ATTR_SCHED_SINGLE_ENTRY, /* single entry */
	TCA_TAPRIO_ATTR_SCHED_CLOCKID, /* s32 */
	TCA_TAPRIO_PAD,
	TCA_TAPRIO_ATTR_ADMIN_SCHED, /* The admin sched, only used in dump */
	TCA_TAPRIO_ATTR_SCHED_CYCLE_TIME, /* s64 */
	TCA_TAPRIO_ATTR_SCHED_CYCLE_TIME_EXTENSION, /* s64 */
	TCA_TAPRIO_ATTR_FLAGS, /* u32 */
	TCA_TAPRIO_ATTR_TXTIME_DELAY, /* u32 */
	TCA_TAPRIO_ATTR_TC_ENTRY, /* nest */
	__TCA_TAPRIO_ATTR_MAX,
};

#define TCA_TAPRIO_ATTR_MAX (__TCA_TAPRIO_ATTR_MAX - 1)

/* ETS */

#define TCQ_ETS_MAX_BANDS 16

enum {
	TCA_ETS_UNSPEC,
	TCA_ETS_NBANDS,		/* u8 */
	TCA_ETS_NSTRICT,	/* u8 */
	TCA_ETS_QUANTA,		/* nested TCA_ETS_QUANTA_BAND */
	TCA_ETS_QUANTA_BAND,	/* u32 */
	TCA_ETS_PRIOMAP,	/* nested TCA_ETS_PRIOMAP_BAND */
	TCA_ETS_PRIOMAP_BAND,	/* u8 */
	__TCA_ETS_MAX,
};

#define TCA_ETS_MAX (__TCA_ETS_MAX - 1)

#endif