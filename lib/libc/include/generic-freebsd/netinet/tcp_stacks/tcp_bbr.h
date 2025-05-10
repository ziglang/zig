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

#ifndef _NETINET_TCP_BBR_H_
#define _NETINET_TCP_BBR_H_

#define BBR_INITIAL_RTO  1000000	/* 1 second in micro-seconds */
/* Send map flags */
#define BBR_ACKED	  0x0001	/* The remote endpoint acked this */
#define BBR_WAS_RENEGED	  0x0002	/* The peer reneged the ack  */
#define BBR_RXT_CLEARED	  0x0004	/* ACK Cleared by the RXT timer  */
#define BBR_OVERMAX	  0x0008	/* We have more retran's then we can
					 * fit */
#define BBR_SACK_PASSED   0x0010	/* A sack was done above this block */
#define BBR_WAS_SACKPASS  0x0020	/* We retransmitted due to SACK pass */
#define BBR_HAS_FIN	  0x0040	/* segment is sent with fin */
#define BBR_TLP	  	  0x0080	/* segment sent as tail-loss-probe */
#define BBR_HAS_SYN	  0x0100	/* segment has the syn */
#define BBR_MARKED_LOST   0x0200	/*
					 * This segments is lost and
					 * totaled into bbr->rc_ctl.rc_lost
					 */
#define BBR_RWND_COLLAPSED 0x0400	/* The peer collapsed the rwnd on the segment */
#define BBR_NUM_OF_RETRANS 7

/* Defines for socket options to set pacing overheads */
#define BBR_INCL_ENET_OH 0x01
#define BBR_INCL_IP_OH   0x02
#define BBR_INCL_TCP_OH  0x03

/*
 * With the addition of both measurement algorithms
 * I had to move over the size of a
 * cache line (unfortunately). For now there is
 * no way around this. We may be able to cut back
 * at some point I hope.
 */
struct bbr_sendmap {
	TAILQ_ENTRY(bbr_sendmap) r_next;	/* seq number arrayed next */
	TAILQ_ENTRY(bbr_sendmap) r_tnext;	/* Time of tmit based next */
	uint32_t r_start;	/* Sequence number of the segment */
	uint32_t r_end;		/* End seq, this is 1 beyond actually */

	uint32_t r_rtr_bytes;	/* How many bytes have been retransmitted */
	uint32_t r_delivered;	/* Delivered amount at send */

	uint32_t r_del_time;	/* The time of the last delivery update */
	uint8_t r_rtr_cnt:4,	/* Retran count, index this -1 to get time
				 * sent */
		r_rtt_not_allowed:1,	/* No rtt measurement allowed */
	        r_is_drain:1,	/* In a draining cycle */
		r_app_limited:1,/* We went app limited */
	        r_ts_valid:1;	/* Timestamp field is valid (r_del_ack_ts) */
	uint8_t r_dupack;	/* Dup ack count */
	uint8_t r_in_tmap:1,	/* Flag to see if its in the r_tnext array */
	        r_is_smallmap:1,/* Was logged as a small-map send-map item */
		r_is_gain:1,	/* Was in gain cycle */
		r_bbr_state:5;  /* The BBR state at send */
	uint8_t r_limit_type;	/* is this entry counted against a limit? */

	uint16_t r_flags;	/* Flags as defined above */
	uint16_t r_spare16;
	uint32_t r_del_ack_ts;  /* At send what timestamp of peer was (if r_ts_valid set) */
	/****************Cache line*****************/
	uint32_t r_tim_lastsent[BBR_NUM_OF_RETRANS];
	/*
	 * Question, should we instead just grab the sending b/w
	 * from the filter with the gain and store it in a
	 * uint64_t instead?
	 */
	uint32_t r_first_sent_time; /* Time of first pkt in flight sent */
	uint32_t r_pacing_delay;	/* pacing delay of this send */
	uint32_t r_flight_at_send;	/* flight at the time of the send */
#ifdef _KERNEL
}           __aligned(CACHE_LINE_SIZE);
#else
};
#endif
#define BBR_LIMIT_TYPE_SPLIT	1

TAILQ_HEAD(bbr_head, bbr_sendmap);

#define BBR_SEGMENT_TIME_SIZE 1500	/* How many bytes in time_between */

#define BBR_MIN_SEG 1460		/* MSS size */
#define BBR_MAX_GAIN_VALUE 0xffff

#define BBR_TIMER_FUDGE  1500	/* 1.5ms in micro seconds */

/* BW twiddle secret codes */
#define BBR_RED_BW_CONGSIG  	 0	/* We enter recovery and set using b/w */
#define BBR_RED_BW_RATECAL  	 1	/* We are calculating the loss rate */
#define BBR_RED_BW_USELRBW       2	/* We are dropping the lower b/w with
					 * cDR */
#define BBR_RED_BW_SETHIGHLOSS	 3	/* We have set our highloss value at
					 * exit from probe-rtt */
#define BBR_RED_BW_PE_CLREARLY	 4	/* We have decided to clear the
					 * reduction early */
#define BBR_RED_BW_PE_CLAFDEL	 5	/* We are clearing it on schedule
					 * delayed */
#define BBR_RED_BW_REC_ENDCLL	 6	/* Recover exits save high if needed
					 * an clear to start measuring */
#define BBR_RED_BW_PE_NOEARLY_OUT 7	/* Set pkt epoch judged that we do not
					 * get out of jail early */
/* For calculating a rate */
#define BBR_CALC_BW 	1
#define BBR_CALC_LOSS  	2

#define BBR_RTT_BY_TIMESTAMP	0
#define BBR_RTT_BY_EXACTMATCH	1
#define BBR_RTT_BY_EARLIER_RET	2
#define BBR_RTT_BY_THIS_RETRAN  3
#define BBR_RTT_BY_SOME_RETRAN	4
#define BBR_RTT_BY_TSMATCHING	5

/* Markers to track where we enter persists from */
#define BBR_PERSISTS_FROM_1	1
#define BBR_PERSISTS_FROM_2	2
#define BBR_PERSISTS_FROM_3	3
#define BBR_PERSISTS_FROM_4	4
#define BBR_PERSISTS_FROM_5	5

/* magic cookies to ask for the RTT */
#define BBR_RTT_PROP    0
#define BBR_RTT_RACK    1
#define BBR_RTT_PKTRTT  2
#define BBR_SRTT	3

#define BBR_SACKED 0
#define BBR_CUM_ACKED  1

/* threshold in useconds where we consider we need a higher min cwnd */
#define BBR_HIGH_SPEED 1000
#define BBR_HIGHSPEED_NUM_MSS 12

#define MAX_REDUCE_RXT 3	/* What is the maximum times we are willing to
				 * reduce b/w in RTX's. Setting this has a
				 * multiplicative effect e.g. if we are
				 * reducing by 20% then setting it to 3 means
				 * you will have reduced the b/w estimate by >
				 * 60% before you stop. */
/*
 * We use the rate sample structure to
 * assist in single sack/ack rate and rtt
 * calculation. In the future we will expand
 * this in BBR to do forward rate sample
 * b/w estimation.
 */
#define BBR_RS_RTT_EMPTY 0x00000001	/* Nothing yet stored in RTT's */
#define BBR_RS_BW_EMPTY  0x00000002	/* Nothing yet stored in cDR */
#define BBR_RS_RTT_VALID 0x00000004	/* We have at least one valid RTT */
#define BBR_RS_BW_VAILD  0x00000008	/* We have a valid cDR */
#define BBR_RS_EMPTY   (BBR_RS_RTT_EMPTY|BBR_RS_BW_EMPTY)
struct bbr_rtt_sample {
	uint32_t rs_flags;
	uint32_t rs_rtt_lowest;
	uint32_t rs_rtt_lowest_sendtime;
	uint32_t rs_rtt_low_seq_start;

	uint32_t rs_rtt_highest;
	uint32_t rs_rtt_cnt;

	uint64_t rs_rtt_tot;
	uint32_t cur_rtt;
	uint32_t cur_rtt_bytecnt;

	uint32_t cur_rtt_rsmcnt;
	uint32_t rc_crtt_set:1,
		avail_bits:31;
	uint64_t rs_cDR;
};

/* RTT shrink reasons */
#define BBR_RTTS_INIT     0
#define BBR_RTTS_NEWRTT   1
#define BBR_RTTS_RTTPROBE 2
#define BBR_RTTS_WASIDLE  3
#define BBR_RTTS_PERSIST  4
#define BBR_RTTS_REACHTAR 5
#define BBR_RTTS_ENTERPROBE 6
#define BBR_RTTS_SHRINK_PG 7
#define BBR_RTTS_SHRINK_PG_FINAL 8
#define BBR_RTTS_NEW_TARGET 9
#define BBR_RTTS_LEAVE_DRAIN 10
#define BBR_RTTS_RESETS_VALUES 11

#define BBR_NUM_RATES 5
/* Rate flags */
#define BBR_RT_FLAG_FREE       0x00	/* Is on the free list */
#define BBR_RT_FLAG_INUSE      0x01	/* Has been allocated */
#define BBR_RT_FLAG_READY      0x02	/* Ready to initiate a measurement. */
#define BBR_RT_FLAG_CAPPED_PRE 0x04	/* Ready to cap if we send the next segment */
#define BBR_RT_FLAG_CAPPED     0x08	/* Measurement is capped */
#define BBR_RT_FLAG_PASTFA     0x10	/* Past the first ack. */
#define BBR_RT_FLAG_LIMITED    0x20	/* Saw application/cwnd or rwnd limited period */
#define BBR_RT_SEEN_A_ACK      0x40	/* A ack has been saved */
#define BBR_RT_PREV_RTT_SET    0x80	/* There was a RTT set in */
#define BBR_RT_PREV_SEND_TIME  0x100	/*
					 *There was a RTT send time set that can be used
					 * no snd_limits
					 */
#define BBR_RT_SET_GRADIENT    0x200
#define BBR_RT_TS_VALID        0x400

struct bbr_log {
	union {
		struct bbr_sendmap *rsm;	/* For alloc/free */
		uint64_t sb_acc;	/* For out/ack or t-o */
	};
	struct tcpcb *tp;
	uint32_t t_flags;
	uint32_t th_seq;
	uint32_t th_ack;
	uint32_t snd_una;
	uint32_t snd_nxt;
	uint32_t snd_max;
	uint32_t snd_cwnd;
	uint32_t snd_wnd;
	uint32_t rc_lost;
	uint32_t target_cwnd;	/* UU */
	uint32_t inflight;	/* UU */
	uint32_t applimited;	/* UU */
	/* Things for BBR */
	uint32_t delivered;	/* UU */
	uint64_t cur_del_rate;	/* UU */
	uint64_t delRate;	/* UU */
	uint64_t rttProp;	/* UU */
	uint64_t lt_bw;		/* UU */
	uint32_t timeStamp;
	uint32_t time;
	uint32_t slot;		/* UU */
	uint32_t delayed_by;
	uint32_t exp_del;
	uint32_t pkts_out;
	uint32_t new_win;
	uint32_t hptsi_gain;	/* UU */
	uint32_t cwnd_gain;	/* UU */
	uint32_t epoch;		/* UU */
	uint32_t lt_epoch;	/* UU */
	/* Sack fun */
	uint32_t blk_start[4];	/* xx */
	uint32_t blk_end[4];
	uint32_t len;		/* Timeout T3=1, TLP=2, RACK=3 */
	uint8_t type;
	uint8_t n_sackblks;
	uint8_t applied;	/* UU */
	uint8_t inhpts;		/* UU */
	uint8_t __spare;	/* UU */
	uint8_t use_lt_bw;	/* UU */
};

struct bbr_log_sysctl_out {
	uint32_t bbr_log_at;
	uint32_t bbr_log_max;
	struct bbr_log entries[0];
};

/*
 * Magic numbers for logging timeout events if the
 * logging is enabled.
 */
#define BBR_TO_FRM_TMR  1
#define BBR_TO_FRM_TLP  2
#define BBR_TO_FRM_RACK 3
#define BBR_TO_FRM_KEEP 4
#define BBR_TO_FRM_PERSIST 5
#define BBR_TO_FRM_DELACK 6

#define BBR_SEES_STRETCH_ACK 1
#define BBR_SEES_COMPRESSED_ACKS 2

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

#define TT_BBR_FR_TMR	0x2001

#define BBR_SCALE 8
#define BBR_UNIT (1 << BBR_SCALE)

#define BBR_NUM_RTTS_FOR_DEL_LIMIT 8	/* How many pkt-rtts do we keep
					 * Delivery rate for */
#define BBR_NUM_RTTS_FOR_GOOG_DEL_LIMIT 10	/* How many pkt-rtts do we keep
						 * Delivery rate for google */

#define BBR_SECONDS_NO_RTT 10	/* 10 seconds with no RTT shrinkage */
#define BBR_PROBERTT_MAX 200	/* 200ms */
#define BBR_PROBERTT_NUM_MSS 4
#define BBR_STARTUP_EPOCHS 3
#define USECS_IN_MSEC 1000
#define BBR_TIME_TO_SECONDS(a) (a / USECS_IN_SECOND)
#define BBR_TIME_TO_MILLI(a) (a / MS_IN_USEC)

/* BBR keeps time in usec's so we divide by 1000 and round up */
#define BBR_TS_TO_MS(t)  ((t+999)/MS_IN_USEC)

/*
 * Locking for the rack control block.
 * a) Locked by INP_WLOCK
 * b) Locked by the hpts-mutex
 *
 */
#define BBR_STATE_STARTUP   0x01
#define BBR_STATE_DRAIN     0x02
#define BBR_STATE_PROBE_BW  0x03
#define BBR_STATE_PROBE_RTT 0x04
#define BBR_STATE_IDLE_EXIT 0x05

/* Substate defines for STATE == PROBE_BW */
#define BBR_SUB_GAIN  0		/* State 0 where we are 5/4 BBR_UNIT */
#define BBR_SUB_DRAIN 1		/* State 1 where we are at 3/4 BBR_UNIT */
#define BBR_SUB_LEVEL1 2	/* State 1 first BBR_UNIT */
#define BBR_SUB_LEVEL2 3	/* State 2nd BBR_UNIT */
#define BBR_SUB_LEVEL3 4	/* State 3rd BBR_UNIT */
#define BBR_SUB_LEVEL4 5	/* State 4th BBR_UNIT */
#define BBR_SUB_LEVEL5 6	/* State 5th BBR_UNIT */
#define BBR_SUB_LEVEL6 7	/* State last BBR_UNIT */
#define BBR_SUBSTATE_COUNT 8

/* Single remaining reduce log */
#define BBR_REDUCE_AT_FR 5

#define BBR_BIG_LOG_SIZE 300000

struct bbr_stats {
	uint64_t bbr_badfr;		/* 0 */
	uint64_t bbr_badfr_bytes;	/* 1 */
	uint64_t bbr_saw_oerr;		/* 2 */
	uint64_t bbr_saw_emsgsiz;	/* 3 */
	uint64_t bbr_reorder_seen;	/* 4 */
	uint64_t bbr_tlp_tot;		/* 5 */
	uint64_t bbr_tlp_newdata;	/* 6 */
	uint64_t bbr_offset_recovery;	/* 7 */
	uint64_t bbr_tlp_retran_fail;	/* 8 */
	uint64_t bbr_to_tot;		/* 9 */
	uint64_t bbr_to_arm_rack;	/* 10 */
	uint64_t bbr_enter_probertt;	/* 11 */
	uint64_t bbr_tlp_set;		/* 12 */
	uint64_t bbr_resends_set;	/* 13 */
	uint64_t bbr_force_output;	/* 14 */
	uint64_t bbr_to_arm_tlp;	/* 15 */
	uint64_t bbr_paced_segments;	/* 16 */
	uint64_t bbr_saw_enobuf;	/* 17 */
	uint64_t bbr_to_alloc_failed;	/* 18 */
	uint64_t bbr_to_alloc_emerg;	/* 19 */
	uint64_t bbr_sack_proc_all;	/* 20 */
	uint64_t bbr_sack_proc_short;	/* 21 */
	uint64_t bbr_sack_proc_restart;	/* 22 */
	uint64_t bbr_to_alloc;		/* 23 */
	uint64_t bbr_offset_drop;	/* 24 */
	uint64_t bbr_runt_sacks;	/* 25 */
	uint64_t bbr_sack_passed;	/* 26 */
	uint64_t bbr_rlock_left_ret0;	/* 27 */
	uint64_t bbr_rlock_left_ret1;	/* 28 */
	uint64_t bbr_dynamic_rwnd;	/* 29 */
	uint64_t bbr_static_rwnd;	/* 30 */
	uint64_t bbr_sack_blocks;	/* 31 */
	uint64_t bbr_sack_blocks_skip;	/* 32 */
	uint64_t bbr_sack_search_both;	/* 33 */
	uint64_t bbr_sack_search_fwd;	/* 34 */
	uint64_t bbr_sack_search_back;	/* 35 */
	uint64_t bbr_plain_acks;	/* 36 */
	uint64_t bbr_acks_with_sacks;	/* 37 */
	uint64_t bbr_progress_drops;	/* 38 */
	uint64_t bbr_early;		/* 39 */
	uint64_t bbr_reneges_seen;	/* 40 */
	uint64_t bbr_persist_reneg;	/* 41 */
	uint64_t bbr_dropped_af_data;	/* 42 */
	uint64_t bbr_failed_mbuf_aloc;	/* 43 */
	uint64_t bbr_cwnd_limited;	/* 44 */
	uint64_t bbr_rwnd_limited;	/* 45 */
	uint64_t bbr_app_limited;	/* 46 */
	uint64_t bbr_force_timer_start;	/* 47 */
	uint64_t bbr_hpts_min_time;	/* 48 */
	uint64_t bbr_meets_tso_thresh;  /* 49 */
	uint64_t bbr_miss_tso_rwnd;	/* 50 */
	uint64_t bbr_miss_tso_cwnd;	/* 51 */
	uint64_t bbr_miss_tso_app;	/* 52 */
	uint64_t bbr_miss_retran;	/* 53 */
	uint64_t bbr_miss_tlp;		/* 54 */
	uint64_t bbr_miss_unknown;	/* 55 */
	uint64_t bbr_hdwr_rl_add_ok;	/* 56 */
	uint64_t bbr_hdwr_rl_add_fail;	/* 57 */
	uint64_t bbr_hdwr_rl_mod_ok;	/* 58 */
	uint64_t bbr_hdwr_rl_mod_fail;	/* 59 */
	uint64_t bbr_collapsed_win;     /* 60 */
	uint64_t bbr_alloc_limited;	/* 61 */
	uint64_t bbr_alloc_limited_conns; /* 62 */
	uint64_t bbr_split_limited;	/* 63 */
};

/*
 * The structure bbr_opt_stats is a simple
 * way to see how many options are being
 * changed in the stack.
 */
struct bbr_opts_stats {
	uint64_t tcp_bbr_pace_per_sec;
	uint64_t tcp_bbr_pace_del_tar;
	uint64_t tcp_bbr_pace_seg_max;
	uint64_t tcp_bbr_pace_seg_min;
	uint64_t tcp_bbr_pace_cross;
	uint64_t tcp_bbr_drain_inc_extra;
	uint64_t tcp_bbr_unlimited;
	uint64_t tcp_bbr_iwintso;
	uint64_t tcp_bbr_rec_over_hpts;
	uint64_t tcp_bbr_recforce;
	uint64_t tcp_bbr_startup_pg;
	uint64_t tcp_bbr_drain_pg;
	uint64_t tcp_bbr_rwnd_is_app;
	uint64_t tcp_bbr_probe_rtt_int;
	uint64_t tcp_bbr_one_retran;
	uint64_t tcp_bbr_startup_loss_exit;
	uint64_t tcp_bbr_use_lowgain;
	uint64_t tcp_bbr_lowgain_thresh;
	uint64_t tcp_bbr_lowgain_half;
	uint64_t tcp_bbr_lowgain_fd;
	uint64_t tcp_bbr_usedel_rate;
	uint64_t tcp_bbr_min_rto;
	uint64_t tcp_bbr_max_rto;
	uint64_t tcp_rack_pace_max_seg;
	uint64_t tcp_rack_min_to;
	uint64_t tcp_rack_reord_thresh;
	uint64_t tcp_rack_reord_fade;
	uint64_t tcp_rack_tlp_thresh;
	uint64_t tcp_rack_pkt_delay;
	uint64_t tcp_bbr_startup_exit_epoch;
	uint64_t tcp_bbr_ack_comp_alg;
	uint64_t tcp_rack_cheat;
	uint64_t tcp_iwnd_tso;
	uint64_t tcp_utter_max_tso;
	uint64_t tcp_hdwr_pacing;
	uint64_t tcp_extra_state;
	uint64_t tcp_floor_min_tso;
	/* New */
	uint64_t tcp_bbr_algorithm;
	uint64_t tcp_bbr_tslimits;
	uint64_t tcp_bbr_probertt_len;
	uint64_t tcp_bbr_probertt_gain;
	uint64_t tcp_bbr_topaceout;
	uint64_t tcp_use_rackcheat;
	uint64_t tcp_delack;
	uint64_t tcp_maxpeak;
	uint64_t tcp_retran_wtso;
	uint64_t tcp_data_ac;
	uint64_t tcp_ts_raises;
	uint64_t tcp_pacing_oh_tmr;
	uint64_t tcp_pacing_oh;
	uint64_t tcp_policer_det;
};

#ifdef _KERNEL
#define BBR_STAT_SIZE (sizeof(struct bbr_stats)/sizeof(uint64_t))
extern counter_u64_t bbr_stat_arry[BBR_STAT_SIZE];
#define BBR_STAT_ADD(name, amm) counter_u64_add(bbr_stat_arry[(offsetof(struct bbr_stats, name)/sizeof(uint64_t))], (amm))
#define BBR_STAT_INC(name) BBR_STAT_ADD(name, 1)
#define BBR_OPTS_SIZE (sizeof(struct bbr_stats)/sizeof(uint64_t))
extern counter_u64_t bbr_opts_arry[BBR_OPTS_SIZE];
#define BBR_OPTS_ADD(name, amm) counter_u64_add(bbr_opts_arry[(offsetof(struct bbr_opts_stats, name)/sizeof(uint64_t))], (amm))
#define BBR_OPTS_INC(name) BBR_OPTS_ADD(name, 1)
#endif

#define BBR_NUM_LOSS_RATES 3
#define BBR_NUM_BW_RATES 3

#define BBR_RECOVERY_LOWRTT 1
#define BBR_RECOVERY_MEDRTT 2
#define BBR_RECOVERY_HIGHRTT 3
#define BBR_RECOVERY_EXTREMERTT 4

struct bbr_control {
	/*******************************/
	/* Cache line 2 from bbr start */
	/*******************************/
	struct bbr_head rc_map;	/* List of all segments Lock(a) */
	struct bbr_head rc_tmap;	/* List in transmit order Lock(a) */
	struct bbr_sendmap *rc_resend;	/* something we have been asked to
					 * resend */
	uint32_t rc_last_delay_val;	/* How much we expect to delay Lock(a) */
	uint32_t rc_bbr_hptsi_gain:16,	/* Current hptsi gain Lock(a) */
	         rc_hpts_flags:16;	/* flags on whats on the pacer wheel */

	uint32_t rc_delivered;	/* BRR delivered amount Lock(a) */
	uint32_t rc_hptsi_agg_delay;	/* How much time are we behind */

	uint32_t rc_flight_at_input;
	uint32_t rc_lost_bytes;		/* Total bytes currently marked lost */
	/*******************************/
	/* Cache line 3 from bbr start */
	/*******************************/
	struct time_filter rc_delrate;
	/*******************************/
	/* Cache line 4 from bbr start */
	/*******************************/
	struct bbr_head rc_free;	/* List of Free map entries Lock(a) */
	struct bbr_sendmap *rc_tlp_send;	/* something we have been
						 * asked to resend */
	uint32_t rc_del_time;
	uint32_t rc_target_at_state;	/* Target for a state */

	uint16_t rc_free_cnt;	/* Number of free entries on the rc_free list
				 * Lock(a) */
	uint16_t rc_startup_pg;

	uint32_t cur_rtt;	/* Last RTT from ack */

	uint32_t rc_went_idle_time;	/* Used for persits to see if its
					 * probe-rtt qualified */
	uint32_t rc_pace_max_segs:17,	/* How much in any single TSO we send Lock(a) */
		 rc_pace_min_segs:15;	/* The minimum single segment size before we enter persists */

	uint32_t rc_rtt_shrinks;	/* Time of last rtt shrinkage Lock(a) */
	uint32_t r_app_limited_until;
	uint32_t rc_timer_exp;	/* If a timer ticks of expiry */
	uint32_t rc_rcv_epoch_start;	/* Start time of the Epoch Lock(a) */

	/*******************************/
	/* Cache line 5 from bbr start */
	/*******************************/

	uint32_t rc_lost_at_pktepoch;	/* what the lost value was at the last
					 * pkt-epoch */
	uint32_t r_measurement_count;	/* count of measurement applied lock(a) */

	uint32_t rc_last_tlp_seq;	/* Last tlp sequence Lock(a) */
	uint16_t rc_reorder_shift;	/* Socket option value Lock(a) */
	uint16_t rc_pkt_delay;	/* Socket option value Lock(a) */

	struct bbr_sendmap *rc_sacklast;	/* sack remembered place
						 * Lock(a) */
	struct bbr_sendmap *rc_next;	/* remembered place where we next
					 * retransmit at Lock(a) */

	uint32_t rc_sacked;	/* Tot sacked on scoreboard Lock(a) */
	uint32_t rc_holes_rxt;	/* Tot retraned from scoreboard Lock(a) */

	uint32_t rc_reorder_ts;	/* Last time we saw reordering Lock(a) */
	uint32_t rc_init_rwnd;	/* Initial rwnd when we transitioned */
				/*- ---
				 * used only initial and close
				 */
	uint32_t rc_high_rwnd;	/* Highest rwnd seen */
	uint32_t rc_lowest_rtt;	/* Smallest RTT we have seen */

	uint32_t rc_last_rtt;	/* Last valid measured RTT that ack'd data */
	uint32_t bbr_cross_over;

	/*******************************/
	/* Cache line 6 from bbr start */
	/*******************************/
	struct sack_filter bbr_sf;

	/*******************************/
	/* Cache line 7 from bbr start */
	/*******************************/
	struct time_filter_small rc_rttprop;
	uint32_t last_inbound_ts;	/* Peers last timestamp */

	uint32_t rc_inc_tcp_oh: 1,
		 rc_inc_ip_oh: 1,
		 rc_inc_enet_oh:1,
		 rc_incr_tmrs:1,
		 restrict_growth:28;
	uint32_t rc_lt_epoch_use;	/* When we started lt-bw use Lock(a) */

	uint32_t rc_recovery_start;	/* Time we start recovery Lock(a) */
	uint32_t rc_lt_del;	/* Delivered at lt bw sampling start Lock(a) */

	uint64_t rc_bbr_cur_del_rate;	/* Current measured delivery rate
					 * Lock(a) */

	/*******************************/
	/* Cache line 8 from bbr start */
	/*******************************/
	uint32_t rc_cwnd_on_ent;	/* On entry to recovery the cwnd
					 * Lock(a) */
	uint32_t rc_agg_early;	/* aggregate amount early */

	uint32_t rc_rcvtime;	/* When we last received data Lock(a) */
	uint32_t rc_pkt_epoch_del;	/* seq num that we need for RTT epoch */

	uint32_t rc_pkt_epoch;	/* Epoch based on packet RTTs */
	uint32_t rc_pkt_epoch_time;	/* Time we started the pkt epoch */

	uint32_t rc_pkt_epoch_rtt;	/* RTT using the packet epoch */
	uint32_t rc_rtt_epoch;	/* Current RTT epoch, it ticks every rttProp
				 * Lock(a) */
	uint32_t lowest_rtt;
	uint32_t bbr_smallest_srtt_this_state;

	uint32_t rc_lt_epoch;	/* LT epoch start of bw_sampling */
	uint32_t rc_lost_at_startup;

	uint32_t rc_bbr_state_atflight;
	uint32_t rc_bbr_last_startup_epoch;	/* Last startup epoch where we
						 * increased 20% */
	uint32_t rc_bbr_enters_probertt;	/* Timestamp we entered
						 * probertt Lock(a) */
	uint32_t rc_lt_time;	/* Time of lt sampling start Lock(a) */

	/*******************************/
	/* Cache line 9 from bbr start */
	/*******************************/
	uint64_t rc_lt_bw;	/* LT bw calculated Lock(a) */
	uint64_t rc_bbr_lastbtlbw;	/* For startup, what was last btlbw I
					 * saw to check the 20% gain Lock(a) */

	uint32_t rc_bbr_cwnd_gain;	/* Current cwnd gain Lock(a) */
	uint32_t rc_pkt_epoch_loss_rate;	/* pkt-epoch loss rate */

	uint32_t rc_saved_cwnd;	/* Saved cwnd during Probe-rtt drain Lock(a) */
	uint32_t substate_pe;

	uint32_t rc_lost;	/* Number of bytes lost Lock(a) */
	uint32_t rc_exta_time_gd; /* How much extra time we got in d/g */

	uint32_t rc_lt_lost;	/* Number of lt bytes lost at sampling start
				 * Lock(a) */
	uint32_t rc_bbr_state_time;

	uint32_t rc_min_to;	/* Socket option value Lock(a) */
	uint32_t rc_initial_hptsi_bw;	/* Our initial startup bw Lock(a) */

	uint32_t bbr_lost_at_state;	/* Temp counter debug lost value as we
					 * enter a state */
	/*******************************/
	/* Cache line 10 from bbr start */
	/*******************************/
	uint32_t rc_level_state_extra;
	uint32_t rc_red_cwnd_pe;
	const struct tcp_hwrate_limit_table *crte;
	uint64_t red_bw;

	uint32_t rc_probertt_int;
	uint32_t rc_probertt_srttchktim;	/* Time we last did a srtt
						 * check  */
	uint32_t gain_epoch;	/* Epoch we should be out of gain */
	uint32_t rc_min_rto_ms;

	uint32_t rc_reorder_fade;	/* Socket option value Lock(a) */
	uint32_t last_startup_measure;

	int32_t bbr_hptsi_per_second;
	int32_t bbr_hptsi_segments_delay_tar;

	int32_t bbr_hptsi_segments_max;
	uint32_t bbr_rttprobe_gain_val;
	/*******************************/
	/* Cache line 11 from bbr start */
	/*******************************/
	uint32_t cur_rtt_send_time;	/* Time we sent our rtt measured packet */
	uint32_t bbr_peer_tsratio;	/* Our calculated ts ratio to multply */
	uint32_t bbr_ts_check_tstmp;	/* When we filled it the TS that came on the ack */
	uint32_t bbr_ts_check_our_cts;	/* When we filled it the cts of the send */
	uint32_t rc_tlp_rxt_last_time;
	uint32_t bbr_smallest_srtt_state2;
	uint32_t bbr_hdwr_cnt_noset_snt;	/* count of hw pacing sends during delay */
	uint32_t startup_last_srtt;
	uint32_t rc_ack_hdwr_delay;
	uint32_t highest_hdwr_delay;		/* Largest delay we have seen from hardware */
	uint32_t non_gain_extra;
	uint32_t recovery_lr;			/* The sum of the loss rate from the pe's during recovery */
	uint32_t last_in_probertt;
	uint32_t flightsize_at_drain;		/* In draining what was the last marked flight size */
	uint32_t rc_pe_of_prtt;			/* PE we went into probe-rtt */
	uint32_t ts_in;				/* ts that went with the last rtt */

	uint16_t rc_tlp_seg_send_cnt;	/* Number of times we have TLP sent
					 * rc_last_tlp_seq Lock(a) */
	uint16_t rc_drain_pg;
	uint32_t rc_num_maps_alloced;		/* num send map entries allocated */
	uint32_t rc_num_split_allocs;		/* num split map entries allocated */
	uint16_t rc_num_small_maps_alloced;	/* Number of sack blocks
						 * allocated */
	uint16_t bbr_hptsi_bytes_min;

	uint16_t bbr_hptsi_segments_floor;
	uint16_t bbr_utter_max;
	uint16_t bbr_google_discount;

};

struct socket;
struct tcp_bbr {
	/* First cache line 0x00 */
	int32_t(*r_substate) (struct mbuf *, struct tcphdr *,
	    struct socket *, struct tcpcb *, struct tcpopt *,
	    int32_t, int32_t, uint32_t, int32_t, int32_t, uint8_t);	/* Lock(a) */
	struct tcpcb *rc_tp;	/* The tcpcb Lock(a) */
	struct inpcb *rc_inp;	/* The inpcb Lock(a) */
	struct timeval rc_tv;
	uint32_t rc_pacer_started;  /* Time we started the pacer */
	uint16_t no_pacing_until:8, /* No pacing until N packet epochs */
		 ts_can_raise:1,/* TS b/w calculations can raise the bw higher */
		 skip_gain:1,	/* Skip the gain cycle (hardware pacing) */
		 gain_is_limited:1,	/* With hardware pacing we are limiting gain */
		 output_error_seen:1,
		 oerror_cnt:4,
		hw_pacing_set:1;	/* long enough has passed for us to start pacing */
	uint16_t xxx_r_ack_count;	/* During recovery count of ack's received
				 * that added data since output */
	uint16_t bbr_segs_rcvd;	/* In Segment count since we sent a ack */

	uint8_t bbr_timer_src:4,	/* Used for debugging Lock(a) */
		bbr_use_rack_cheat:1,   /* Use the rack cheat */
		bbr_init_win_cheat:1,	/* Send full IW for TSO */
		bbr_attempt_hdwr_pace:1,/* Try to do hardware pacing */
		bbr_hdrw_pacing:1;	/* Hardware pacing is available */
	uint8_t bbr_hdw_pace_ena:1,	/* Does the connection allow hardware pacing to be attempted */
		bbr_prev_in_rec:1,	/* We were previously in recovery */
		pkt_conservation:1,
		use_policer_detection:1,
		xxx_bbr_hdw_pace_idx:4;	/* If hardware pacing is on, index to slot in pace tbl */
	uint16_t r_wanted_output:1,
		 rtt_valid:1,
		 rc_timer_first:1,
		 rc_output_starts_timer:1,
		 rc_resends_use_tso:1,
		 rc_all_timers_stopped:1,
		 rc_loss_exit:1,
		 rc_ack_was_delayed:1,
		 rc_lt_is_sampling:1,
		 rc_filled_pipe:1,
		 rc_tlp_new_data:1,
		 rc_hit_state_1:1,
		 rc_ts_valid:1,
		 rc_prtt_set_ts:1,
		 rc_is_pkt_epoch_now:1,
		 rc_has_collapsed:1;

	uint8_t r_state:4,	/* Current bbr state Lock(a) */
	        r_agg_early_set:1,	/* Did we get called early */
		r_init_rtt:1,
		r_use_policer:1,	/* For google mode only */
		r_recovery_bw:1;
	uint8_t r_timer_override:1,	/* pacer override Lock(a)  0/1 */
	        rc_in_persist:1,
		rc_lt_use_bw:1,
		rc_allow_data_af_clo:1,
		rc_tlp_rtx_out:1,	/* A TLP is in flight  */
	        rc_tlp_in_progress:1,	/* a TLP timer is running needed? */
	        rc_use_idle_restart:1;   /* Do we restart fast after idle (persist or applim) */
	uint8_t rc_bbr_state:3,	/* What is the major BBR state */
	        rc_bbr_substate:3,	/* For probeBW state */
	        r_is_v6:1,
		rc_past_init_win:1;
	uint8_t rc_last_options;
	uint8_t rc_tlp_threshold;	/* Socket option value Lock(a) */
	uint8_t rc_max_rto_sec;
	uint8_t rc_cwnd_limited:1,	/* We are cwnd limited */
		rc_tmr_stopped:7;	/* What timers have been stopped  */
	uint8_t rc_use_google:1,
		rc_use_ts_limit:1,
		rc_ts_data_set:1,	/* We have filled a set point to determine */
		rc_ts_clock_set:1, 	/* We have determined the ts type */
		rc_ts_cant_be_used:1,	/* We determined we can't use ts values */
		rc_ack_is_cumack:1,
		rc_no_pacing:1,
		alloc_limit_reported:1;
	uint8_t rc_init_win;
	/* Cache line 2 0x40 */
	struct bbr_control r_ctl;
#ifdef _KERNEL
}       __aligned(CACHE_LINE_SIZE);
#else
};
#endif

#endif