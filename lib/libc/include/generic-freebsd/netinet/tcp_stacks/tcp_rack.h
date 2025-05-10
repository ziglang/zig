/*-
 * Copyright (c) 2016-2020 Netflix, Inc.
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
 */

#ifndef _NETINET_TCP_RACK_H_
#define _NETINET_TCP_RACK_H_

#define RACK_ACKED	    0x000001/* The remote endpoint acked this */
#define RACK_TO_REXT	    0x000002/* A timeout occurred on this sendmap entry */
#define RACK_DEFERRED	    0x000004/* We can't use this for RTT calc - not used */
#define RACK_OVERMAX	    0x000008/* We have more retran's then we can fit */
#define RACK_SACK_PASSED    0x000010/* A sack was done above this block */
#define RACK_WAS_SACKPASS   0x000020/* We retransmitted due to SACK pass */
#define RACK_HAS_FIN	    0x000040/* segment is sent with fin */
#define RACK_TLP	    0x000080/* segment sent as tail-loss-probe */
#define RACK_RWND_COLLAPSED 0x000100/* The peer collapsed the rwnd on the segment */
#define RACK_APP_LIMITED    0x000200/* We went app limited after this send */
#define RACK_WAS_ACKED	    0x000400/* a RTO undid the ack, but it already had a rtt calc done */
#define RACK_HAS_SYN	    0x000800/* SYN is on this guy */
#define RACK_SENT_W_DSACK   0x001000/* Sent with a dsack */
#define RACK_SENT_SP	    0x002000/* sent in slow path */
#define RACK_SENT_FP        0x004000/* sent in fast path */
#define RACK_HAD_PUSH	    0x008000/* Push was sent on original send */
#define RACK_MUST_RXT	    0x010000/* We must retransmit this rsm (non-sack/mtu chg)*/
#define RACK_IN_GP_WIN	    0x020000/* Send was in GP window when sent */
#define RACK_SHUFFLED	    0x040000/* The RSM was shuffled some data from one to another */
#define RACK_MERGED	    0x080000/* The RSM was merged */
#define RACK_PMTU_CHG	    0x100000/* The path mtu changed on this guy */
#define RACK_STRADDLE	    0x200000/* The seq straddles the bucket line */
#define RACK_NUM_OF_RETRANS 3

#define RACK_INITIAL_RTO 1000000 /* 1 second in microseconds */

#define RACK_REQ_AVG 3 	/* Must be less than 256 */

struct rack_sendmap {
	TAILQ_ENTRY(rack_sendmap) next;
	TAILQ_ENTRY(rack_sendmap) r_tnext;	/* Time of transmit based next */
	uint32_t bindex;
	uint32_t r_start;	/* Sequence number of the segment */
	uint32_t r_end;		/* End seq, this is 1 beyond actually */
	uint32_t r_rtr_bytes;	/* How many bytes have been retransmitted */
	uint32_t r_flags : 24,	/* Flags as defined above */
		 r_rtr_cnt : 8;	/* Retran count, index this -1 to get time */
	struct mbuf *m;
	uint32_t soff;
	uint32_t orig_m_len;	/* The original mbuf len when we sent (can update) */
	uint32_t orig_t_space;	/* The original trailing space when we sent (can update) */
	uint32_t r_nseq_appl;	/* If this one is app limited, this is the nxt seq limited */
	uint8_t r_dupack;	/* Dup ack count */
	uint8_t r_in_tmap;	/* Flag to see if its in the r_tnext array */
	uint8_t r_limit_type;	/* is this entry counted against a limit? */
	uint8_t r_just_ret : 1, /* After sending, the next pkt was just returned, i.e. limited  */
		r_one_out_nr : 1,	/* Special case 1 outstanding and not in recovery */
		r_no_rtt_allowed : 1, /* No rtt measurement allowed */
		r_hw_tls : 1,
		r_avail : 4;
	uint64_t r_tim_lastsent[RACK_NUM_OF_RETRANS];
	uint64_t r_ack_arrival;	/* This is the time of ack-arrival (if SACK'd) */
	uint32_t r_fas;		/* Flight at send */
	uint8_t r_bas;		/* The burst size (burst at send = bas)  */
};

struct deferred_opt_list {
	TAILQ_ENTRY(deferred_opt_list) next;
	int optname;
	uint64_t optval;
};

/*
 * Timestamps in the rack sendmap are now moving to be
 * uint64_t's. This means that if you want a uint32_t
 * usec timestamp (the old usecond timestamp) you simply have
 * to cast it to uint32_t. The reason we do this is not for
 * wrap, but we need to get back, at times, to the millisecond
 * timestamp that is used in the TSTMP option. To do this we
 * can use the rack_ts_to_msec() inline below which can take
 * the 64bit ts and make into the correct timestamp millisecond
 * wise. Thats not possible with the 32bit usecond timestamp since
 * the seconds wrap too quickly to cover all bases.
 *
 * There are quite a few places in rack where I simply cast
 * back to uint32_t and then end up using the TSTMP_XX()
 * macros. This is ok, but we could do simple compares if
 * we ever decided to move all of those variables to 64 bits
 * as well.
 */

static inline uint64_t
rack_to_usec_ts(struct timeval *tv)
{
	return ((tv->tv_sec * HPTS_USEC_IN_SEC) + tv->tv_usec);
}

static inline uint32_t
rack_ts_to_msec(uint64_t ts)
{
	return((uint32_t)(ts / HPTS_MSEC_IN_SEC));
}


TAILQ_HEAD(rack_head, rack_sendmap);
TAILQ_HEAD(def_opt_head, deferred_opt_list);

/* Map change logging */
#define MAP_MERGE	0x01
#define MAP_SPLIT	0x02
#define MAP_NEW		0x03
#define MAP_SACK_M1	0x04
#define MAP_SACK_M2	0x05
#define MAP_SACK_M3	0x06
#define MAP_SACK_M4	0x07
#define MAP_SACK_M5	0x08
#define MAP_FREE	0x09
#define MAP_TRIM_HEAD	0x0a

#define RACK_LIMIT_TYPE_SPLIT	1

/*
 * We use the rate sample structure to
 * assist in single sack/ack rate and rtt
 * calculation. In the future we will expand
 * this in BBR to do forward rate sample
 * b/w estimation.
 */
#define RACK_RTT_EMPTY 0x00000001	/* Nothing yet stored in RTT's */
#define RACK_RTT_VALID 0x00000002	/* We have at least one valid RTT */
struct rack_rtt_sample {
	uint32_t rs_flags;
	uint32_t rs_rtt_lowest;
	uint32_t rs_rtt_highest;
	uint32_t rs_rtt_cnt;
	uint32_t rs_us_rtt;
	int32_t  confidence;
	uint64_t rs_rtt_tot;
	uint16_t rs_us_rtrcnt;
};

#define RACK_LOG_TYPE_ACK	0x01
#define RACK_LOG_TYPE_OUT	0x02
#define RACK_LOG_TYPE_TO	0x03
#define RACK_LOG_TYPE_ALLOC     0x04
#define RACK_LOG_TYPE_FREE      0x05

/*
 * Magic numbers for logging timeout events if the
 * logging is enabled.
 */
#define RACK_TO_FRM_TMR  1
#define RACK_TO_FRM_TLP  2
#define RACK_TO_FRM_RACK 3
#define RACK_TO_FRM_KEEP 4
#define RACK_TO_FRM_PERSIST 5
#define RACK_TO_FRM_DELACK 6

struct rack_opts_stats {
	uint64_t tcp_rack_tlp_reduce;
	uint64_t tcp_rack_pace_always;
	uint64_t tcp_rack_pace_reduce;
	uint64_t tcp_rack_max_seg;
	uint64_t tcp_rack_prr_sendalot;
	uint64_t tcp_rack_min_to;
	uint64_t tcp_rack_early_seg;
	uint64_t tcp_rack_reord_thresh;
	uint64_t tcp_rack_reord_fade;
	uint64_t tcp_rack_tlp_thresh;
	uint64_t tcp_rack_pkt_delay;
	uint64_t tcp_rack_tlp_inc_var;
	uint64_t tcp_tlp_use;
	uint64_t tcp_rack_idle_reduce;
	uint64_t tcp_rack_idle_reduce_high;
	uint64_t rack_no_timer_in_hpts;
	uint64_t tcp_rack_min_pace_seg;
	uint64_t tcp_rack_pace_rate_ca;
	uint64_t tcp_rack_rr;
	uint64_t tcp_rack_do_detection;
	uint64_t tcp_rack_rrr_no_conf_rate;
	uint64_t tcp_initial_rate;
	uint64_t tcp_initial_win;
	uint64_t tcp_hdwr_pacing;
	uint64_t tcp_gp_inc_ss;
	uint64_t tcp_gp_inc_ca;
	uint64_t tcp_gp_inc_rec;
	uint64_t tcp_rack_force_max_seg;
	uint64_t tcp_rack_pace_rate_ss;
	uint64_t tcp_rack_pace_rate_rec;
	/* Temp counters for dsack */
	uint64_t tcp_sack_path_1; /* not used */
	uint64_t tcp_sack_path_2a; /* not used */
	uint64_t tcp_sack_path_2b; /* not used */
	uint64_t tcp_sack_path_3; /* not used */
	uint64_t tcp_sack_path_4; /* not used */
	/* non temp counters */
	uint64_t tcp_rack_scwnd;
	uint64_t tcp_rack_noprr;
	uint64_t tcp_rack_cfg_rate;
	uint64_t tcp_timely_dyn;
	uint64_t tcp_rack_mbufq;
	uint64_t tcp_fillcw;
	uint64_t tcp_npush;
	uint64_t tcp_lscwnd;
	uint64_t tcp_profile;
	uint64_t tcp_hdwr_rate_cap;
	uint64_t tcp_pacing_rate_cap;
	uint64_t tcp_pacing_up_only;
	uint64_t tcp_use_cmp_acks;
	uint64_t tcp_rack_abc_val;
	uint64_t tcp_rec_abc_val;
	uint64_t tcp_rack_measure_cnt;
	uint64_t tcp_rack_delayed_ack;
	uint64_t tcp_rack_rtt_use;
	uint64_t tcp_data_after_close;
	uint64_t tcp_defer_opt;
	uint64_t tcp_rxt_clamp;
	uint64_t tcp_rack_beta;
	uint64_t tcp_rack_beta_ecn;
	uint64_t tcp_rack_timer_slop;
	uint64_t tcp_rack_dsack_opt;
	uint64_t tcp_rack_hi_beta;
	uint64_t tcp_split_limit;
	uint64_t tcp_rack_pacing_divisor;
	uint64_t tcp_rack_min_seg;
	uint64_t tcp_dgp_in_rec;
};

/* RTT shrink reasons */
#define RACK_RTTS_INIT     0
#define RACK_RTTS_NEWRTT   1
#define RACK_RTTS_EXITPROBE 2
#define RACK_RTTS_ENTERPROBE 3
#define RACK_RTTS_REACHTARGET 4
#define RACK_RTTS_SEEHBP 5
#define RACK_RTTS_NOBACKOFF 6
#define RACK_RTTS_SAFETY 7

#define RACK_USE_BEG 1
#define RACK_USE_END 2
#define RACK_USE_END_OR_THACK 3

#define TLP_USE_ID	1	/* Internet draft behavior */
#define TLP_USE_TWO_ONE 2	/* Use 2.1 behavior */
#define TLP_USE_TWO_TWO 3	/* Use 2.2 behavior */
#define RACK_MIN_BW 8000	/* 64kbps in Bps */

/* Rack quality indicators for GPUT measurements */
#define RACK_QUALITY_NONE	0	/* No quality stated */
#define RACK_QUALITY_HIGH 	1	/* A normal measurement of a GP RTT */
#define RACK_QUALITY_APPLIMITED	2 	/* An app limited case that may be of lower quality */
#define RACK_QUALITY_PERSIST	3	/* A measurement where we went into persists */
#define RACK_QUALITY_PROBERTT	4	/* A measurement where we went into or exited probe RTT */
#define RACK_QUALITY_ALLACKED	5	/* All data is now acknowledged */

#define MIN_GP_WIN 6	/* We need at least 6 MSS in a GP measurement */
#ifdef _KERNEL
#define RACK_OPTS_SIZE (sizeof(struct rack_opts_stats)/sizeof(uint64_t))
extern counter_u64_t rack_opts_arry[RACK_OPTS_SIZE];
#define RACK_OPTS_ADD(name, amm) counter_u64_add(rack_opts_arry[(offsetof(struct rack_opts_stats, name)/sizeof(uint64_t))], (amm))
#define RACK_OPTS_INC(name) RACK_OPTS_ADD(name, 1)
#endif
/*
 * As we get each SACK we wade through the
 * rc_map and mark off what is acked.
 * We also increment rc_sacked as well.
 *
 * We also pay attention to missing entries
 * based on the time and possibly mark them
 * for retransmit. If we do and we are not already
 * in recovery we enter recovery. In doing
 * so we claer prr_delivered/holes_rxt and prr_sent_dur_rec.
 * We also setup rc_next/rc_snd_nxt/rc_send_end so
 * we will know where to send from. When not in
 * recovery rc_next will be NULL and rc_snd_nxt should
 * equal snd_max.
 *
 * Whenever we retransmit from recovery we increment
 * rc_holes_rxt as we retran a block and mark it as retransmitted
 * with the time it was sent. During non-recovery sending we
 * add to our map and note the time down of any send expanding
 * the rc_map at the tail and moving rc_snd_nxt up with snd_max.
 *
 * In recovery during SACK/ACK processing if a chunk has
 * been retransmitted and it is now acked, we decrement rc_holes_rxt.
 * When we retransmit from the scoreboard we use
 * rc_next and rc_snd_nxt/rc_send_end to help us
 * find what needs to be retran.
 *
 * To calculate pipe we simply take (snd_max - snd_una) + rc_holes_rxt
 * This gets us the effect of RFC6675 pipe, counting twice for
 * bytes retransmitted.
 */

#define TT_RACK_FR_TMR	0x2000

/*
 * Locking for the rack control block.
 * a) Locked by INP_WLOCK
 * b) Locked by the hpts-mutex
 *
 */
#define RACK_GP_HIST 4	/* How much goodput history do we maintain? */

#define RACK_NUM_FSB_DEBUG 16
#ifdef _KERNEL
struct rack_fast_send_blk {
	uint32_t left_to_send;
	uint16_t tcp_ip_hdr_len;
	uint8_t tcp_flags;
	uint8_t hoplimit;
	uint8_t *tcp_ip_hdr;
	uint32_t recwin;
	uint32_t off;
	struct tcphdr *th;
	struct udphdr *udp;
	struct mbuf *m;
	uint32_t o_m_len;
	uint32_t o_t_len;
	uint32_t rfo_apply_push : 1,
		hw_tls : 1,
		unused : 30;
};

struct tailq_hash;

struct rack_control {
	/* Second cache line 0x40 from tcp_rack */
	struct tailq_hash *tqh; /* Tree of all segments Lock(a) */
	struct rack_head rc_tmap;	/* List in transmit order Lock(a) */
	struct rack_sendmap *rc_tlpsend;	/* Remembered place for
						 * tlp_sending Lock(a) */
	struct rack_sendmap *rc_resend;	/* something we have been asked to
					 * resend */
	struct rack_fast_send_blk fsb;	/* The fast-send block */
	uint32_t timer_slop;
	uint16_t pace_len_divisor;
	uint16_t rc_user_set_min_segs;
	uint32_t rc_hpts_flags;
	uint32_t rc_fixed_pacing_rate_ca;
	uint32_t rc_fixed_pacing_rate_rec;
	uint32_t rc_fixed_pacing_rate_ss;
	uint32_t cwnd_to_use;	/* The cwnd in use */
	uint32_t rc_timer_exp;	/* If a timer ticks of expiry */
	uint32_t rc_rack_min_rtt;	/* lowest RTT seen Lock(a) */
	uint32_t rc_rack_largest_cwnd;	/* Largest CWND we have seen Lock(a) */

	/* Third Cache line 0x80 */
	struct rack_head rc_free;	/* Allocation array */
	uint64_t last_hw_bw_req;
	uint64_t crte_prev_rate;
	uint64_t bw_rate_cap;
	uint64_t last_cumack_advance; /* Last time cumack moved forward */
	uint32_t rc_reorder_ts;	/* Last time we saw reordering Lock(a) */

	uint32_t rc_tlp_new_data;	/* we need to send new-data on a TLP
					 * Lock(a) */
	uint32_t rc_prr_out;	/* bytes sent during recovery Lock(a) */

	uint32_t rc_prr_recovery_fs;	/* recovery fs point Lock(a) */

	uint32_t rc_prr_sndcnt;	/* Prr sndcnt Lock(a) */

	uint32_t rc_sacked;	/* Tot sacked on scoreboard Lock(a) */
	uint32_t last_sent_tlp_seq;	/* Last tlp sequence that was retransmitted Lock(a) */

	uint32_t rc_prr_delivered;	/* during recovery prr var Lock(a) */

	uint16_t rc_tlp_cnt_out;	/* count of times we have sent a TLP without new data */
	uint16_t last_sent_tlp_len;	/* Number of bytes in the last sent tlp */

	uint32_t rc_loss_count;	/* How many bytes have been retransmitted
				 * Lock(a) */
	uint32_t rc_reorder_fade;	/* Socket option value Lock(a) */

	/* Forth cache line 0xc0  */
	/* Times */

	uint32_t rc_rack_tmit_time;	/* Rack transmit time Lock(a) */
	uint32_t rc_holes_rxt;	/* Tot retraned from scoreboard Lock(a) */

	uint32_t rc_num_maps_alloced;	/* Number of map blocks (sacks) we
					 * have allocated */
	uint32_t rc_rcvtime;	/* When we last received data */
	uint32_t rc_num_split_allocs;	/* num split map entries allocated */
	uint32_t rc_split_limit;	/* Limit from control var can be set by socket opt */

	uint32_t rc_last_output_to;
	uint32_t rc_went_idle_time;

	struct rack_sendmap *rc_sacklast;	/* sack remembered place
						 * Lock(a) */

	struct rack_sendmap *rc_first_appl;	/* Pointer to first app limited */
	struct rack_sendmap *rc_end_appl;	/* Pointer to last app limited */
	/* Cache line split 0x100 */
	struct sack_filter rack_sf;
	/* Cache line split 0x140 */
	/* Flags for various things */
	uint32_t rc_pace_max_segs;
	uint32_t rc_pace_min_segs;
	uint32_t rc_app_limited_cnt;
	uint16_t rack_per_of_gp_ss; /* 100 = 100%, so from 65536 = 655 x bw  */
	uint16_t rack_per_of_gp_ca; /* 100 = 100%, so from 65536 = 655 x bw  */
	uint16_t rack_per_of_gp_rec; /* 100 = 100%, so from 65536 = 655 x bw, 0=off */
	uint16_t rack_per_of_gp_probertt; /* 100 = 100%, so from 65536 = 655 x bw, 0=off */
	uint32_t rc_high_rwnd;
	uint32_t ack_count;
	uint32_t sack_count;
	uint32_t sack_noextra_move;
	uint32_t sack_moved_extra;
	struct rack_rtt_sample rack_rs;
	const struct tcp_hwrate_limit_table *crte;
	uint32_t rc_agg_early;
	uint32_t rc_agg_delayed;
	uint32_t rc_tlp_rxt_last_time;
	uint32_t rc_saved_cwnd;
	uint64_t rc_gp_output_ts; /* chg*/
	uint64_t rc_gp_cumack_ts; /* chg*/
	struct timeval act_rcv_time;
	struct timeval rc_last_time_decay;	/* SAD time decay happened here */
	uint64_t gp_bw;
	uint64_t init_rate;
#ifdef NETFLIX_SHARED_CWND
	struct shared_cwnd *rc_scw;
#endif
	uint64_t last_gp_comp_bw;
	uint64_t last_max_bw;	/* Our calculated max b/w last */
	struct time_filter_small rc_gp_min_rtt;
	struct def_opt_head opt_list;
	uint64_t lt_bw_time;	/* Total time with data outstanding (lt_bw = long term bandwidth)  */
	uint64_t lt_bw_bytes;	/* Total bytes acked */
	uint64_t lt_timemark;	/* 64 bit timestamp when we started sending */
	struct tcp_sendfile_track *rc_last_sft;
	uint32_t lt_seq;	/* Seq at start of lt_bw gauge */
	int32_t rc_rtt_diff;		/* Timely style rtt diff of our gp_srtt */
	uint64_t last_sndbytes;
	uint64_t last_snd_rxt_bytes;
	uint64_t rxt_threshold;
	uint64_t last_tmit_time_acked;	/* Holds the last cumack point's last send time */
	uint32_t last_rnd_rxt_clamped;
	uint32_t num_of_clamps_applied;
	uint32_t clamp_options;
	uint32_t max_clamps;

	uint32_t rc_gp_srtt;		/* Current GP srtt */
	uint32_t rc_prev_gp_srtt;	/* Previous RTT */
	uint32_t rc_entry_gp_rtt;	/* Entry to PRTT gp-rtt */
	uint32_t rc_loss_at_start;	/* At measurement window where was our lost value */

	uint32_t dsack_round_end;	/* In a round of seeing a DSACK */
	uint32_t current_round;		/* Starting at zero */
	uint32_t roundends;		/* acked value above which round ends */
	uint32_t num_dsack;		/* Count of dsack's seen  (1 per window)*/
	uint32_t forced_ack_ts;
 	uint32_t last_collapse_point;	/* Last point peer collapsed too */
	uint32_t high_collapse_point;
	uint32_t rc_lower_rtt_us_cts;	/* Time our GP rtt was last lowered */
	uint32_t rc_time_probertt_entered;
	uint32_t rc_time_probertt_starts;
	uint32_t rc_lowest_us_rtt;
	uint32_t rc_highest_us_rtt;
	uint32_t rc_last_us_rtt;
	uint32_t rc_time_of_last_probertt;
	uint32_t rc_target_probertt_flight;
	uint32_t rc_probertt_sndmax_atexit;	/* Highest sent to in probe-rtt */
	uint32_t rc_cwnd_at_erec;
	uint32_t rc_ssthresh_at_erec;
	uint32_t dsack_byte_cnt;
	uint32_t retran_during_recovery;
	uint32_t rc_gp_lowrtt;			/* Lowest rtt seen during GPUT measurement */
	uint32_t rc_gp_high_rwnd;		/* Highest rwnd seen during GPUT measurement */
	uint32_t rc_snd_max_at_rto;	/* For non-sack when the RTO occurred what was snd-max */
	uint32_t rc_out_at_rto;
	int32_t rc_scw_index;
	uint32_t rc_tlp_threshold;	/* Socket option value Lock(a) */
	uint32_t rc_last_timeout_snduna;
	uint32_t last_tlp_acked_start;
	uint32_t last_tlp_acked_end;
	uint32_t challenge_ack_ts;
	uint32_t challenge_ack_cnt;
	uint32_t rc_min_to;	/* Socket option value Lock(a) */
	uint32_t rc_pkt_delay;	/* Socket option value Lock(a) */
	uint32_t persist_lost_ends;
	uint32_t ack_during_sd;
	uint32_t input_pkt;
	uint32_t saved_input_pkt;
	uint32_t saved_rxt_clamp_val; 	/* The encoded value we used to setup clamping */
	struct newreno rc_saved_beta;	/*
					 * For newreno cc:
					 * rc_saved_cc are the values we have had
					 * set by the user, if pacing is not happening
					 * (i.e. its early and we have not turned on yet
					 *  or it was turned off). The minute pacing
					 * is turned on we pull out the values currently
					 * being used by newreno and replace them with
					 * these values, then save off the old values here,
					 * we also set the flag (if ecn_beta is set) to make
					 * new_reno do less of a backoff for ecn (think abe).
					 */
	uint16_t rc_early_recovery_segs;	/* Socket option value Lock(a) */
	uint16_t rc_reorder_shift;	/* Socket option value Lock(a) */
	uint8_t rack_per_upper_bound_ss;
	uint8_t rack_per_upper_bound_ca;
	uint8_t dsack_persist;
	uint8_t rc_no_push_at_mrtt;	/* No push when we exceed max rtt */
	uint8_t num_measurements;	/* Number of measurements (up to 0xff, we freeze at 0xff)  */
	uint8_t req_measurements;	/* How many measurements are required? */
	uint8_t saved_hibeta;
	uint8_t rc_tlp_cwnd_reduce;	/* Socket option value Lock(a) */
	uint8_t rc_prr_sendalot;/* Socket option value Lock(a) */
	uint8_t rc_rate_sample_method;
	uint8_t rc_dgp_bl_agg;		/* Buffer Level aggression during DGP */
	uint8_t full_dgp_in_rec;	/* Flag to say if we do full DGP in recovery */
	uint8_t client_suggested_maxseg;	/* Not sure what to do with this yet */
	uint8_t pacing_discount_amm;	/*
					 * This is a multipler to the base discount that
					 * can be used to increase the discount.
					 */
	uint8_t already_had_a_excess;
};
#endif

/* DGP with no buffer level mitigations */
#define DGP_LEVEL0	0

/*
 * DGP with buffer level mitigation where BL:4 caps fillcw and BL:5
 * turns off fillcw.
 */
#define DGP_LEVEL1	1

/*
 * DGP with buffer level mitigation where BL:3 caps fillcw and BL:4 turns off fillcw
 * and BL:5 reduces by 10%
 */
#define DGP_LEVEL2	2

/*
 * DGP with buffer level mitigation where BL:2 caps fillcw and BL:3 turns off
 * fillcw  BL:4 reduces by 10% and BL:5 reduces by 20%
 */
#define DGP_LEVEL3	3

/* Hybrid pacing log defines */
#define HYBRID_LOG_NO_ROOM	0	/* No room for the clients request */
#define HYBRID_LOG_TURNED_OFF	1	/* Turned off hybrid pacing */
#define HYBRID_LOG_NO_PACING	2	/* Failed to set pacing on */
#define HYBRID_LOG_RULES_SET	3	/* Hybrid pacing for this chunk is set */
#define HYBRID_LOG_NO_RANGE	4	/* In DGP mode, no range found */
#define HYBRID_LOG_RULES_APP	5	/* The specified rules were applied */
#define HYBRID_LOG_REQ_COMP	6	/* The request completed */
#define HYBRID_LOG_BW_MEASURE	7	/* Follow up b/w measurements to the previous completed log */
#define HYBRID_LOG_RATE_CAP	8	/* We had a rate cap apply */
#define HYBRID_LOG_CAP_CALC	9	/* How we calculate the cap */
#define HYBRID_LOG_ISSAME	10	/* Same as before  -- temp */
#define HYBRID_LOG_ALLSENT	11	/* We sent it all no more rate-cap */
#define HYBRID_LOG_OUTOFTIME	12	/* We are past the deadline DGP */
#define HYBRID_LOG_CAPERROR	13	/* Hit one of the TSNH cases */
#define HYBRID_LOG_EXTEND	14	/* We extended the end */
#define HYBRID_LOG_SENT_LOST	15	/* A closing sent/lost report */

#define RACK_TIMELY_CNT_BOOST 5	/* At 5th increase boost */
#define RACK_MINRTT_FILTER_TIM 10 /* Seconds */

#define RACK_HYSTART_OFF	0
#define RACK_HYSTART_ON		1	/* hystart++ on */
#define RACK_HYSTART_ON_W_SC	2	/* hystart++ on +Slam Cwnd */
#define RACK_HYSTART_ON_W_SC_C	3	/* hystart++ on,
					 * Conservative ssthresh and
					 * +Slam cwnd
					 */

#define MAX_USER_SET_SEG 0x3f	/* The max we can set is 63 which is probably too many */

#ifdef _KERNEL

struct tcp_rack {
	/* First cache line 0x00 */
	TAILQ_ENTRY(tcp_rack) r_hpts;	/* hptsi queue next Lock(b) */
	int32_t(*r_substate) (struct mbuf *, struct tcphdr *,
	    struct socket *, struct tcpcb *, struct tcpopt *,
	    int32_t, int32_t, uint32_t, int, int, uint8_t);	/* Lock(a) */
	struct tcpcb *rc_tp;	/* The tcpcb Lock(a) */
	struct inpcb *rc_inp;	/* The inpcb Lock(a) */
	uint8_t rc_free_cnt;	/* Number of free entries on the rc_free list
				 * Lock(a) */
	uint8_t client_bufferlvl : 3, /* Expected range [0,5]: 0=unset, 1=low/empty */
		rack_deferred_inited : 1,
	        /* ******************************************************************** */
	        /* Note for details of next two fields see rack_init_retransmit_rate()  */
	        /* ******************************************************************** */
		full_size_rxt: 1,
		shape_rxt_to_pacing_min : 1,
	        /* ******************************************************************** */
		rc_ack_required: 1,
		r_pacing_discount : 1;
	uint8_t no_prr_addback : 1,
		gp_ready : 1,
		defer_options: 1,
		excess_rxt_on: 1,	/* Are actions on for excess retransmissions? */
		rc_ack_can_sendout_data: 1, /*
					     * If set it will override pacing restrictions on not sending
					     * data when the pacing timer is running. I.e. you set this
					     * and an ACK will send data. Default is off and its only used
					     * without pacing when we are doing 5G speed up for there
					     * ack filtering.
					     */
		rc_pacing_cc_set: 1,	     /*
					      * If we are pacing (pace_always=1) and we have reached the
					      * point where we start pacing (fixed or gp has reached its
					      * magic gp_ready state) this flag indicates we have set in
					      * values to effect CC's backoff's. If pacing is turned off
					      * then we must restore the values saved in rc_saved_beta,
					      * if its going to gp_ready we need to copy the values into
					      * the CC module and set our flags.
					      *
					      * Note this only happens if the cc name is newreno (CCALGONAME_NEWRENO).
					      */

		rc_rack_tmr_std_based :1,
		rc_rack_use_dsack: 1;
	uint8_t rc_dsack_round_seen: 1,
		rc_last_tlp_acked_set: 1,
		rc_last_tlp_past_cumack: 1,
		rc_last_sent_tlp_seq_valid: 1,
		rc_last_sent_tlp_past_cumack: 1,
		probe_not_answered: 1,
		rack_hibeta : 1,
		lt_bw_up : 1;
	uint32_t rc_rack_rtt;	/* RACK-RTT Lock(a) */
	uint16_t r_mbuf_queue : 1,	/* Do we do mbuf queue for non-paced */
		 rtt_limit_mul : 4,	/* muliply this by low rtt */
		 r_limit_scw : 1,
		 r_must_retran : 1,	/* For non-sack customers we hit an RTO and new data should be resends */
		 r_use_cmp_ack: 1,	/* Do we use compressed acks */
		 r_ent_rec_ns: 1,	/* We entered recovery and have not sent */
		 r_might_revert: 1,	/* Flag to find out if we might need to revert */
		 r_fast_output: 1, 	/* Fast output is in progress we can skip the bulk of rack_output */
		 r_fsb_inited: 1,
		 r_rack_hw_rate_caps: 1,
		 r_up_only: 1,
		 r_via_fill_cw : 1,
		 r_fill_less_agg : 1;

	uint8_t rc_user_set_max_segs : 7,	/* Socket option value Lock(a) */
		rc_fillcw_apply_discount;
	uint8_t rc_labc;		/* Appropriate Byte Counting Value */
	uint16_t forced_ack : 1,
		rc_gp_incr : 1,
		rc_gp_bwred : 1,
		rc_gp_timely_inc_cnt : 3,
		rc_gp_timely_dec_cnt : 3,
		r_use_labc_for_rec: 1,
		rc_highly_buffered: 1,		/* The path is highly buffered */
		rc_dragged_bottom: 1,
		rc_pace_dnd : 1,		/* The pace do not disturb bit */
		rc_avali2 : 1,
		rc_gp_filled : 1,
		rc_hw_nobuf : 1;
	uint8_t r_state : 4, 	/* Current rack state Lock(a) */
		rc_catch_up : 1,	/* catch up mode in dgp */
		rc_hybrid_mode : 1,	/* We are in hybrid mode */
		rc_suspicious : 1,	/* Suspect sacks have been given */
		rc_new_rnd_needed: 1;
	uint8_t rc_tmr_stopped : 7,
		t_timers_stopped : 1;
	uint8_t rc_enobuf : 7,	/* count of enobufs on connection provides */
		rc_on_min_to : 1;
	uint8_t r_timer_override : 1,	/* hpts override Lock(a) */
		r_is_v6 : 1,	/* V6 pcb Lock(a)  */
		rc_in_persist : 1,
		rc_tlp_in_progress : 1,
		rc_always_pace : 1,	/* Socket option value Lock(a) */
		rc_pace_to_cwnd : 1,
		rc_pace_fill_if_rttin_range : 1,
		rc_srtt_measure_made : 1;
	uint8_t app_limited_needs_set : 1,
		use_fixed_rate : 1,
		rc_has_collapsed : 1,
		r_cwnd_was_clamped : 1,
		r_clamped_gets_lower : 1,
		rack_hdrw_pacing : 1,  /* We are doing Hardware pacing */
		rack_hdw_pace_ena : 1, /* Is hardware pacing enabled? */
		rack_attempt_hdwr_pace : 1; /* Did we attempt hdwr pacing (if allowed) */
	uint8_t rack_tlp_threshold_use : 3,	/* only 1, 2 and 3 used so far */
		rack_rec_nonrxt_use_cr : 1,
		rack_enable_scwnd : 1,
		rack_attempted_scwnd : 1,
		rack_no_prr : 1,
		rack_scwnd_is_idle : 1;
	uint8_t rc_allow_data_af_clo: 1,
		delayed_ack : 1,
		set_pacing_done_a_iw : 1,
		use_rack_rr : 1,
		alloc_limit_reported : 1,
		sack_attack_disable : 1,
		do_detection : 1,
		rc_force_max_seg : 1;
	uint8_t r_early : 1,
		r_late : 1,
		r_wanted_output: 1,
		r_rr_config : 2,
		r_persist_lt_bw_off : 1,
		r_collapse_point_valid : 1,
		dgp_on : 1;
	uint16_t rc_init_win : 8,
		rc_gp_rtt_set : 1,
		rc_gp_dyn_mul : 1,
		rc_gp_saw_rec : 1,
		rc_gp_saw_ca : 1,
		rc_gp_saw_ss : 1,
		rc_gp_no_rec_chg : 1,
		in_probe_rtt : 1,
		measure_saw_probe_rtt : 1;
	/* Cache line 2 0x40 */
	struct rack_control r_ctl;
}        __aligned(CACHE_LINE_SIZE);

#endif
#endif