/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef __LINUX_PKT_SCHED_H
#define __LINUX_PKT_SCHED_H
#include <linux/const.h>
#include <linux/types.h>
#define TC_PRIO_BESTEFFORT 0
#define TC_PRIO_FILLER 1
#define TC_PRIO_BULK 2
#define TC_PRIO_INTERACTIVE_BULK 4
#define TC_PRIO_INTERACTIVE 6
#define TC_PRIO_CONTROL 7
#define TC_PRIO_MAX 15
struct tc_stats {
  __u64 bytes;
  __u32 packets;
  __u32 drops;
  __u32 overlimits;
  __u32 bps;
  __u32 pps;
  __u32 qlen;
  __u32 backlog;
};
struct tc_estimator {
  signed char interval;
  unsigned char ewma_log;
};
#define TC_H_MAJ_MASK (0xFFFF0000U)
#define TC_H_MIN_MASK (0x0000FFFFU)
#define TC_H_MAJ(h) ((h) & TC_H_MAJ_MASK)
#define TC_H_MIN(h) ((h) & TC_H_MIN_MASK)
#define TC_H_MAKE(maj,min) (((maj) & TC_H_MAJ_MASK) | ((min) & TC_H_MIN_MASK))
#define TC_H_UNSPEC (0U)
#define TC_H_ROOT (0xFFFFFFFFU)
#define TC_H_INGRESS (0xFFFFFFF1U)
#define TC_H_CLSACT TC_H_INGRESS
#define TC_H_MIN_PRIORITY 0xFFE0U
#define TC_H_MIN_INGRESS 0xFFF2U
#define TC_H_MIN_EGRESS 0xFFF3U
enum tc_link_layer {
  TC_LINKLAYER_UNAWARE,
  TC_LINKLAYER_ETHERNET,
  TC_LINKLAYER_ATM,
};
#define TC_LINKLAYER_MASK 0x0F
struct tc_ratespec {
  unsigned char cell_log;
  __u8 linklayer;
  unsigned short overhead;
  short cell_align;
  unsigned short mpu;
  __u32 rate;
};
#define TC_RTAB_SIZE 1024
struct tc_sizespec {
  unsigned char cell_log;
  unsigned char size_log;
  short cell_align;
  int overhead;
  unsigned int linklayer;
  unsigned int mpu;
  unsigned int mtu;
  unsigned int tsize;
};
enum {
  TCA_STAB_UNSPEC,
  TCA_STAB_BASE,
  TCA_STAB_DATA,
  __TCA_STAB_MAX
};
#define TCA_STAB_MAX (__TCA_STAB_MAX - 1)
struct tc_fifo_qopt {
  __u32 limit;
};
#define SKBPRIO_MAX_PRIORITY 64
struct tc_skbprio_qopt {
  __u32 limit;
};
#define TCQ_PRIO_BANDS 16
#define TCQ_MIN_PRIO_BANDS 2
struct tc_prio_qopt {
  int bands;
  __u8 priomap[TC_PRIO_MAX + 1];
};
struct tc_multiq_qopt {
  __u16 bands;
  __u16 max_bands;
};
#define TCQ_PLUG_BUFFER 0
#define TCQ_PLUG_RELEASE_ONE 1
#define TCQ_PLUG_RELEASE_INDEFINITE 2
#define TCQ_PLUG_LIMIT 3
struct tc_plug_qopt {
  int action;
  __u32 limit;
};
struct tc_tbf_qopt {
  struct tc_ratespec rate;
  struct tc_ratespec peakrate;
  __u32 limit;
  __u32 buffer;
  __u32 mtu;
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
struct tc_sfq_qopt {
  unsigned quantum;
  int perturb_period;
  __u32 limit;
  unsigned divisor;
  unsigned flows;
};
struct tc_sfqred_stats {
  __u32 prob_drop;
  __u32 forced_drop;
  __u32 prob_mark;
  __u32 forced_mark;
  __u32 prob_mark_head;
  __u32 forced_mark_head;
};
struct tc_sfq_qopt_v1 {
  struct tc_sfq_qopt v0;
  unsigned int depth;
  unsigned int headdrop;
  __u32 limit;
  __u32 qth_min;
  __u32 qth_max;
  unsigned char Wlog;
  unsigned char Plog;
  unsigned char Scell_log;
  unsigned char flags;
  __u32 max_P;
  struct tc_sfqred_stats stats;
};
struct tc_sfq_xstats {
  __s32 allot;
};
enum {
  TCA_RED_UNSPEC,
  TCA_RED_PARMS,
  TCA_RED_STAB,
  TCA_RED_MAX_P,
  TCA_RED_FLAGS,
  TCA_RED_EARLY_DROP_BLOCK,
  TCA_RED_MARK_BLOCK,
  __TCA_RED_MAX,
};
#define TCA_RED_MAX (__TCA_RED_MAX - 1)
struct tc_red_qopt {
  __u32 limit;
  __u32 qth_min;
  __u32 qth_max;
  unsigned char Wlog;
  unsigned char Plog;
  unsigned char Scell_log;
  unsigned char flags;
#define TC_RED_ECN 1
#define TC_RED_HARDDROP 2
#define TC_RED_ADAPTATIVE 4
#define TC_RED_NODROP 8
};
#define TC_RED_HISTORIC_FLAGS (TC_RED_ECN | TC_RED_HARDDROP | TC_RED_ADAPTATIVE)
struct tc_red_xstats {
  __u32 early;
  __u32 pdrop;
  __u32 other;
  __u32 marked;
};
#define MAX_DPs 16
enum {
  TCA_GRED_UNSPEC,
  TCA_GRED_PARMS,
  TCA_GRED_STAB,
  TCA_GRED_DPS,
  TCA_GRED_MAX_P,
  TCA_GRED_LIMIT,
  TCA_GRED_VQ_LIST,
  __TCA_GRED_MAX,
};
#define TCA_GRED_MAX (__TCA_GRED_MAX - 1)
enum {
  TCA_GRED_VQ_ENTRY_UNSPEC,
  TCA_GRED_VQ_ENTRY,
  __TCA_GRED_VQ_ENTRY_MAX,
};
#define TCA_GRED_VQ_ENTRY_MAX (__TCA_GRED_VQ_ENTRY_MAX - 1)
enum {
  TCA_GRED_VQ_UNSPEC,
  TCA_GRED_VQ_PAD,
  TCA_GRED_VQ_DP,
  TCA_GRED_VQ_STAT_BYTES,
  TCA_GRED_VQ_STAT_PACKETS,
  TCA_GRED_VQ_STAT_BACKLOG,
  TCA_GRED_VQ_STAT_PROB_DROP,
  TCA_GRED_VQ_STAT_PROB_MARK,
  TCA_GRED_VQ_STAT_FORCED_DROP,
  TCA_GRED_VQ_STAT_FORCED_MARK,
  TCA_GRED_VQ_STAT_PDROP,
  TCA_GRED_VQ_STAT_OTHER,
  TCA_GRED_VQ_FLAGS,
  __TCA_GRED_VQ_MAX
};
#define TCA_GRED_VQ_MAX (__TCA_GRED_VQ_MAX - 1)
struct tc_gred_qopt {
  __u32 limit;
  __u32 qth_min;
  __u32 qth_max;
  __u32 DP;
  __u32 backlog;
  __u32 qave;
  __u32 forced;
  __u32 early;
  __u32 other;
  __u32 pdrop;
  __u8 Wlog;
  __u8 Plog;
  __u8 Scell_log;
  __u8 prio;
  __u32 packets;
  __u32 bytesin;
};
struct tc_gred_sopt {
  __u32 DPs;
  __u32 def_DP;
  __u8 grio;
  __u8 flags;
  __u16 pad1;
};
enum {
  TCA_CHOKE_UNSPEC,
  TCA_CHOKE_PARMS,
  TCA_CHOKE_STAB,
  TCA_CHOKE_MAX_P,
  __TCA_CHOKE_MAX,
};
#define TCA_CHOKE_MAX (__TCA_CHOKE_MAX - 1)
struct tc_choke_qopt {
  __u32 limit;
  __u32 qth_min;
  __u32 qth_max;
  unsigned char Wlog;
  unsigned char Plog;
  unsigned char Scell_log;
  unsigned char flags;
};
struct tc_choke_xstats {
  __u32 early;
  __u32 pdrop;
  __u32 other;
  __u32 marked;
  __u32 matched;
};
#define TC_HTB_NUMPRIO 8
#define TC_HTB_MAXDEPTH 8
#define TC_HTB_PROTOVER 3
struct tc_htb_opt {
  struct tc_ratespec rate;
  struct tc_ratespec ceil;
  __u32 buffer;
  __u32 cbuffer;
  __u32 quantum;
  __u32 level;
  __u32 prio;
};
struct tc_htb_glob {
  __u32 version;
  __u32 rate2quantum;
  __u32 defcls;
  __u32 debug;
  __u32 direct_pkts;
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
  __TCA_HTB_MAX,
};
#define TCA_HTB_MAX (__TCA_HTB_MAX - 1)
struct tc_htb_xstats {
  __u32 lends;
  __u32 borrows;
  __u32 giants;
  __s32 tokens;
  __s32 ctokens;
};
struct tc_hfsc_qopt {
  __u16 defcls;
};
struct tc_service_curve {
  __u32 m1;
  __u32 d;
  __u32 m2;
};
struct tc_hfsc_stats {
  __u64 work;
  __u64 rtwork;
  __u32 period;
  __u32 level;
};
enum {
  TCA_HFSC_UNSPEC,
  TCA_HFSC_RSC,
  TCA_HFSC_FSC,
  TCA_HFSC_USC,
  __TCA_HFSC_MAX,
};
#define TCA_HFSC_MAX (__TCA_HFSC_MAX - 1)
#define TC_CBQ_MAXPRIO 8
#define TC_CBQ_MAXLEVEL 8
#define TC_CBQ_DEF_EWMA 5
struct tc_cbq_lssopt {
  unsigned char change;
  unsigned char flags;
#define TCF_CBQ_LSS_BOUNDED 1
#define TCF_CBQ_LSS_ISOLATED 2
  unsigned char ewma_log;
  unsigned char level;
#define TCF_CBQ_LSS_FLAGS 1
#define TCF_CBQ_LSS_EWMA 2
#define TCF_CBQ_LSS_MAXIDLE 4
#define TCF_CBQ_LSS_MINIDLE 8
#define TCF_CBQ_LSS_OFFTIME 0x10
#define TCF_CBQ_LSS_AVPKT 0x20
  __u32 maxidle;
  __u32 minidle;
  __u32 offtime;
  __u32 avpkt;
};
struct tc_cbq_wrropt {
  unsigned char flags;
  unsigned char priority;
  unsigned char cpriority;
  unsigned char __reserved;
  __u32 allot;
  __u32 weight;
};
struct tc_cbq_ovl {
  unsigned char strategy;
#define TC_CBQ_OVL_CLASSIC 0
#define TC_CBQ_OVL_DELAY 1
#define TC_CBQ_OVL_LOWPRIO 2
#define TC_CBQ_OVL_DROP 3
#define TC_CBQ_OVL_RCLASSIC 4
  unsigned char priority2;
  __u16 pad;
  __u32 penalty;
};
struct tc_cbq_police {
  unsigned char police;
  unsigned char __res1;
  unsigned short __res2;
};
struct tc_cbq_fopt {
  __u32 split;
  __u32 defmap;
  __u32 defchange;
};
struct tc_cbq_xstats {
  __u32 borrows;
  __u32 overactions;
  __s32 avgidle;
  __s32 undertime;
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
#define TCA_CBQ_MAX (__TCA_CBQ_MAX - 1)
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
enum {
  TCA_ATM_UNSPEC,
  TCA_ATM_FD,
  TCA_ATM_PTR,
  TCA_ATM_HDR,
  TCA_ATM_EXCESS,
  TCA_ATM_ADDR,
  TCA_ATM_STATE,
  __TCA_ATM_MAX,
};
#define TCA_ATM_MAX (__TCA_ATM_MAX - 1)
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
  __u32 latency;
  __u32 limit;
  __u32 loss;
  __u32 gap;
  __u32 duplicate;
  __u32 jitter;
};
struct tc_netem_corr {
  __u32 delay_corr;
  __u32 loss_corr;
  __u32 dup_corr;
};
struct tc_netem_reorder {
  __u32 probability;
  __u32 correlation;
};
struct tc_netem_corrupt {
  __u32 probability;
  __u32 correlation;
};
struct tc_netem_rate {
  __u32 rate;
  __s32 packet_overhead;
  __u32 cell_size;
  __s32 cell_overhead;
};
struct tc_netem_slot {
  __s64 min_delay;
  __s64 max_delay;
  __s32 max_packets;
  __s32 max_bytes;
  __s64 dist_delay;
  __s64 dist_jitter;
};
enum {
  NETEM_LOSS_UNSPEC,
  NETEM_LOSS_GI,
  NETEM_LOSS_GE,
  __NETEM_LOSS_MAX
};
#define NETEM_LOSS_MAX (__NETEM_LOSS_MAX - 1)
struct tc_netem_gimodel {
  __u32 p13;
  __u32 p31;
  __u32 p32;
  __u32 p14;
  __u32 p23;
};
struct tc_netem_gemodel {
  __u32 p;
  __u32 r;
  __u32 h;
  __u32 k1;
};
#define NETEM_DIST_SCALE 8192
#define NETEM_DIST_MAX 16384
enum {
  TCA_DRR_UNSPEC,
  TCA_DRR_QUANTUM,
  __TCA_DRR_MAX
};
#define TCA_DRR_MAX (__TCA_DRR_MAX - 1)
struct tc_drr_stats {
  __u32 deficit;
};
#define TC_QOPT_BITMASK 15
#define TC_QOPT_MAX_QUEUE 16
enum {
  TC_MQPRIO_HW_OFFLOAD_NONE,
  TC_MQPRIO_HW_OFFLOAD_TCS,
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
  TC_MQPRIO_SHAPER_BW_RATE,
  __TC_MQPRIO_SHAPER_MAX
};
#define __TC_MQPRIO_SHAPER_MAX (__TC_MQPRIO_SHAPER_MAX - 1)
struct tc_mqprio_qopt {
  __u8 num_tc;
  __u8 prio_tc_map[TC_QOPT_BITMASK + 1];
  __u8 hw;
  __u16 count[TC_QOPT_MAX_QUEUE];
  __u16 offset[TC_QOPT_MAX_QUEUE];
};
#define TC_MQPRIO_F_MODE 0x1
#define TC_MQPRIO_F_SHAPER 0x2
#define TC_MQPRIO_F_MIN_RATE 0x4
#define TC_MQPRIO_F_MAX_RATE 0x8
enum {
  TCA_MQPRIO_UNSPEC,
  TCA_MQPRIO_MODE,
  TCA_MQPRIO_SHAPER,
  TCA_MQPRIO_MIN_RATE64,
  TCA_MQPRIO_MAX_RATE64,
  __TCA_MQPRIO_MAX,
};
#define TCA_MQPRIO_MAX (__TCA_MQPRIO_MAX - 1)
enum {
  TCA_SFB_UNSPEC,
  TCA_SFB_PARMS,
  __TCA_SFB_MAX,
};
#define TCA_SFB_MAX (__TCA_SFB_MAX - 1)
struct tc_sfb_qopt {
  __u32 rehash_interval;
  __u32 warmup_time;
  __u32 max;
  __u32 bin_size;
  __u32 increment;
  __u32 decrement;
  __u32 limit;
  __u32 penalty_rate;
  __u32 penalty_burst;
};
struct tc_sfb_xstats {
  __u32 earlydrop;
  __u32 penaltydrop;
  __u32 bucketdrop;
  __u32 queuedrop;
  __u32 childdrop;
  __u32 marked;
  __u32 maxqlen;
  __u32 maxprob;
  __u32 avgprob;
};
#define SFB_MAX_PROB 0xFFFF
enum {
  TCA_QFQ_UNSPEC,
  TCA_QFQ_WEIGHT,
  TCA_QFQ_LMAX,
  __TCA_QFQ_MAX
};
#define TCA_QFQ_MAX (__TCA_QFQ_MAX - 1)
struct tc_qfq_stats {
  __u32 weight;
  __u32 lmax;
};
enum {
  TCA_CODEL_UNSPEC,
  TCA_CODEL_TARGET,
  TCA_CODEL_LIMIT,
  TCA_CODEL_INTERVAL,
  TCA_CODEL_ECN,
  TCA_CODEL_CE_THRESHOLD,
  __TCA_CODEL_MAX
};
#define TCA_CODEL_MAX (__TCA_CODEL_MAX - 1)
struct tc_codel_xstats {
  __u32 maxpacket;
  __u32 count;
  __u32 lastcount;
  __u32 ldelay;
  __s32 drop_next;
  __u32 drop_overlimit;
  __u32 ecn_mark;
  __u32 dropping;
  __u32 ce_mark;
};
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
  __TCA_FQ_CODEL_MAX
};
#define TCA_FQ_CODEL_MAX (__TCA_FQ_CODEL_MAX - 1)
enum {
  TCA_FQ_CODEL_XSTATS_QDISC,
  TCA_FQ_CODEL_XSTATS_CLASS,
};
struct tc_fq_codel_qd_stats {
  __u32 maxpacket;
  __u32 drop_overlimit;
  __u32 ecn_mark;
  __u32 new_flow_count;
  __u32 new_flows_len;
  __u32 old_flows_len;
  __u32 ce_mark;
  __u32 memory_usage;
  __u32 drop_overmemory;
};
struct tc_fq_codel_cl_stats {
  __s32 deficit;
  __u32 ldelay;
  __u32 count;
  __u32 lastcount;
  __u32 dropping;
  __s32 drop_next;
};
struct tc_fq_codel_xstats {
  __u32 type;
  union {
    struct tc_fq_codel_qd_stats qdisc_stats;
    struct tc_fq_codel_cl_stats class_stats;
  };
};
enum {
  TCA_FQ_UNSPEC,
  TCA_FQ_PLIMIT,
  TCA_FQ_FLOW_PLIMIT,
  TCA_FQ_QUANTUM,
  TCA_FQ_INITIAL_QUANTUM,
  TCA_FQ_RATE_ENABLE,
  TCA_FQ_FLOW_DEFAULT_RATE,
  TCA_FQ_FLOW_MAX_RATE,
  TCA_FQ_BUCKETS_LOG,
  TCA_FQ_FLOW_REFILL_DELAY,
  TCA_FQ_ORPHAN_MASK,
  TCA_FQ_LOW_RATE_THRESHOLD,
  TCA_FQ_CE_THRESHOLD,
  TCA_FQ_TIMER_SLACK,
  TCA_FQ_HORIZON,
  TCA_FQ_HORIZON_DROP,
  __TCA_FQ_MAX
};
#define TCA_FQ_MAX (__TCA_FQ_MAX - 1)
struct tc_fq_qd_stats {
  __u64 gc_flows;
  __u64 highprio_packets;
  __u64 tcp_retrans;
  __u64 throttled;
  __u64 flows_plimit;
  __u64 pkts_too_long;
  __u64 allocation_errors;
  __s64 time_next_delayed_flow;
  __u32 flows;
  __u32 inactive_flows;
  __u32 throttled_flows;
  __u32 unthrottle_latency_ns;
  __u64 ce_mark;
  __u64 horizon_drops;
  __u64 horizon_caps;
};
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
#define TCA_HHF_MAX (__TCA_HHF_MAX - 1)
struct tc_hhf_xstats {
  __u32 drop_overlimit;
  __u32 hh_overlimit;
  __u32 hh_tot_count;
  __u32 hh_cur_count;
};
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
#define TCA_PIE_MAX (__TCA_PIE_MAX - 1)
struct tc_pie_xstats {
  __u64 prob;
  __u32 delay;
  __u32 avg_dq_rate;
  __u32 dq_rate_estimating;
  __u32 packets_in;
  __u32 dropped;
  __u32 overlimit;
  __u32 maxq;
  __u32 ecn_mark;
};
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
#define TCA_FQ_PIE_MAX (__TCA_FQ_PIE_MAX - 1)
struct tc_fq_pie_xstats {
  __u32 packets_in;
  __u32 dropped;
  __u32 overlimit;
  __u32 overmemory;
  __u32 ecn_mark;
  __u32 new_flow_count;
  __u32 new_flows_len;
  __u32 old_flows_len;
  __u32 memory_usage;
};
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
struct tc_etf_qopt {
  __s32 delta;
  __s32 clockid;
  __u32 flags;
#define TC_ETF_DEADLINE_MODE_ON _BITUL(0)
#define TC_ETF_OFFLOAD_ON _BITUL(1)
#define TC_ETF_SKIP_SOCK_CHECK _BITUL(2)
};
enum {
  TCA_ETF_UNSPEC,
  TCA_ETF_PARMS,
  __TCA_ETF_MAX,
};
#define TCA_ETF_MAX (__TCA_ETF_MAX - 1)
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
#define TCA_CAKE_MAX (__TCA_CAKE_MAX - 1)
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
  CAKE_FLOW_HOSTS,
  CAKE_FLOW_FLOWS,
  CAKE_FLOW_DUAL_SRC,
  CAKE_FLOW_DUAL_DST,
  CAKE_FLOW_TRIPLE,
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
enum {
  TC_TAPRIO_CMD_SET_GATES = 0x00,
  TC_TAPRIO_CMD_SET_AND_HOLD = 0x01,
  TC_TAPRIO_CMD_SET_AND_RELEASE = 0x02,
};
enum {
  TCA_TAPRIO_SCHED_ENTRY_UNSPEC,
  TCA_TAPRIO_SCHED_ENTRY_INDEX,
  TCA_TAPRIO_SCHED_ENTRY_CMD,
  TCA_TAPRIO_SCHED_ENTRY_GATE_MASK,
  TCA_TAPRIO_SCHED_ENTRY_INTERVAL,
  __TCA_TAPRIO_SCHED_ENTRY_MAX,
};
#define TCA_TAPRIO_SCHED_ENTRY_MAX (__TCA_TAPRIO_SCHED_ENTRY_MAX - 1)
enum {
  TCA_TAPRIO_SCHED_UNSPEC,
  TCA_TAPRIO_SCHED_ENTRY,
  __TCA_TAPRIO_SCHED_MAX,
};
#define TCA_TAPRIO_SCHED_MAX (__TCA_TAPRIO_SCHED_MAX - 1)
#define TCA_TAPRIO_ATTR_FLAG_TXTIME_ASSIST _BITUL(0)
#define TCA_TAPRIO_ATTR_FLAG_FULL_OFFLOAD _BITUL(1)
enum {
  TCA_TAPRIO_ATTR_UNSPEC,
  TCA_TAPRIO_ATTR_PRIOMAP,
  TCA_TAPRIO_ATTR_SCHED_ENTRY_LIST,
  TCA_TAPRIO_ATTR_SCHED_BASE_TIME,
  TCA_TAPRIO_ATTR_SCHED_SINGLE_ENTRY,
  TCA_TAPRIO_ATTR_SCHED_CLOCKID,
  TCA_TAPRIO_PAD,
  TCA_TAPRIO_ATTR_ADMIN_SCHED,
  TCA_TAPRIO_ATTR_SCHED_CYCLE_TIME,
  TCA_TAPRIO_ATTR_SCHED_CYCLE_TIME_EXTENSION,
  TCA_TAPRIO_ATTR_FLAGS,
  TCA_TAPRIO_ATTR_TXTIME_DELAY,
  __TCA_TAPRIO_ATTR_MAX,
};
#define TCA_TAPRIO_ATTR_MAX (__TCA_TAPRIO_ATTR_MAX - 1)
#define TCQ_ETS_MAX_BANDS 16
enum {
  TCA_ETS_UNSPEC,
  TCA_ETS_NBANDS,
  TCA_ETS_NSTRICT,
  TCA_ETS_QUANTA,
  TCA_ETS_QUANTA_BAND,
  TCA_ETS_PRIOMAP,
  TCA_ETS_PRIOMAP_BAND,
  __TCA_ETS_MAX,
};
#define TCA_ETS_MAX (__TCA_ETS_MAX - 1)
#endif