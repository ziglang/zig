/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1986, 1993, 1994, 1995
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
 *	@(#)tcp_var.h	8.4 (Berkeley) 5/24/95
 */

#ifndef _NETINET_TCP_VAR_H_
#define _NETINET_TCP_VAR_H_

#include <netinet/tcp.h>
#include <netinet/tcp_fsm.h>

#ifdef _KERNEL
#include <net/vnet.h>
#include <sys/mbuf.h>
#include <sys/ktls.h>
#endif

#define TCP_END_BYTE_INFO 8	/* Bytes that makeup the "end information array" */
/* Types of ending byte info */
#define TCP_EI_EMPTY_SLOT	0
#define TCP_EI_STATUS_CLIENT_FIN	0x1
#define TCP_EI_STATUS_CLIENT_RST	0x2
#define TCP_EI_STATUS_SERVER_FIN	0x3
#define TCP_EI_STATUS_SERVER_RST	0x4
#define TCP_EI_STATUS_RETRAN		0x5
#define TCP_EI_STATUS_PROGRESS		0x6
#define TCP_EI_STATUS_PERSIST_MAX	0x7
#define TCP_EI_STATUS_KEEP_MAX		0x8
#define TCP_EI_STATUS_DATA_A_CLOSE	0x9
#define TCP_EI_STATUS_RST_IN_FRONT	0xa
#define TCP_EI_STATUS_2MSL		0xb
#define TCP_EI_STATUS_MAX_VALUE		0xb

#define TCP_TRK_REQ_LOG_NEW		0x01
#define TCP_TRK_REQ_LOG_COMPLETE	0x02
#define TCP_TRK_REQ_LOG_FREED		0x03
#define TCP_TRK_REQ_LOG_ALLOCFAIL	0x04
#define TCP_TRK_REQ_LOG_MOREYET	0x05
#define TCP_TRK_REQ_LOG_FORCEFREE	0x06
#define TCP_TRK_REQ_LOG_STALE		0x07
#define TCP_TRK_REQ_LOG_SEARCH		0x08

/************************************************/
/* Status bits we track to assure no duplicates,
 * the bits here are not used by the code but
 * for human representation. To check a bit we
 * take and shift over by 1 minus the value (1-8).
 */
/************************************************/
#define TCP_EI_BITS_CLIENT_FIN	0x001
#define TCP_EI_BITS_CLIENT_RST	0x002
#define TCP_EI_BITS_SERVER_FIN	0x004
#define TCP_EI_BITS_SERVER_RST	0x008
#define TCP_EI_BITS_RETRAN	0x010
#define TCP_EI_BITS_PROGRESS	0x020
#define TCP_EI_BITS_PRESIST_MAX	0x040
#define TCP_EI_BITS_KEEP_MAX	0x080
#define TCP_EI_BITS_DATA_A_CLO  0x100
#define TCP_EI_BITS_RST_IN_FR	0x200	/* a front state reset */
#define TCP_EI_BITS_2MS_TIMER	0x400	/* 2 MSL timer expired */

#if defined(_KERNEL) || defined(_WANT_TCPCB)
#include <sys/_callout.h>
#include <sys/osd.h>

#include <netinet/cc/cc.h>

/* TCP segment queue entry */
struct tseg_qent {
	TAILQ_ENTRY(tseg_qent) tqe_q;
	struct	mbuf   *tqe_m;		/* mbuf contains packet */
	struct  mbuf   *tqe_last;	/* last mbuf in chain */
	tcp_seq tqe_start;		/* TCP Sequence number start */
	int	tqe_len;		/* TCP segment data length */
	uint32_t tqe_flags;		/* The flags from tcp_get_flags() */
	uint32_t tqe_mbuf_cnt;		/* Count of mbuf overhead */
};
TAILQ_HEAD(tsegqe_head, tseg_qent);

struct sackblk {
	tcp_seq start;		/* start seq no. of sack block */
	tcp_seq end;		/* end seq no. */
};

struct sackhole {
	tcp_seq start;		/* start seq no. of hole */
	tcp_seq end;		/* end seq no. */
	tcp_seq rxmit;		/* next seq. no in hole to be retransmitted */
	TAILQ_ENTRY(sackhole) scblink;	/* scoreboard linkage */
};

struct sackhint {
	struct sackhole	*nexthole;
	int32_t		sack_bytes_rexmit;
	tcp_seq		last_sack_ack;	/* Most recent/largest sacked ack */

	int32_t		delivered_data; /* Newly acked data from last SACK */

	int32_t		sacked_bytes;	/* Total sacked bytes reported by the
					 * receiver via sack option
					 */
	uint32_t	recover_fs;	/* Flight Size at the start of Loss recovery */
	uint32_t	prr_delivered;	/* Total bytes delivered using PRR */
	uint32_t	prr_out;	/* Bytes sent during IN_RECOVERY */
};

#define SEGQ_EMPTY(tp) TAILQ_EMPTY(&(tp)->t_segq)

STAILQ_HEAD(tcp_log_stailq, tcp_log_mem);

#define TCP_TRK_TRACK_FLG_EMPTY 0x00	/* Available */
#define TCP_TRK_TRACK_FLG_USED  0x01	/* In use */
#define TCP_TRK_TRACK_FLG_OPEN  0x02	/* End is not valid (open range request) */
#define TCP_TRK_TRACK_FLG_SEQV  0x04	/* We had a sendfile that touched it  */
#define TCP_TRK_TRACK_FLG_COMP  0x08	/* Sendfile as placed the last bits (range req only) */
#define TCP_TRK_TRACK_FLG_FSND	 0x10	/* First send has been done into the seq space */
#define MAX_TCP_TRK_REQ 5		/* Max we will have at once */

struct tcp_sendfile_track {
	uint64_t timestamp;	/* User sent timestamp */
	uint64_t start;		/* Start of sendfile offset */
	uint64_t end;		/* End if not open-range req */
	uint64_t localtime;	/* Time we actually got the req */
	uint64_t deadline;	/* If in CU mode, deadline to delivery */
	uint64_t first_send;	/* Time of first send in the range */
	uint64_t cspr;		/* Client suggested pace rate */
	uint64_t sent_at_fs;	/* What was t_sndbytes as we begun sending */
	uint64_t rxt_at_fs;	/* What was t_snd_rxt_bytes as we begun sending */
	tcp_seq start_seq;	/* First TCP Seq assigned */
	tcp_seq end_seq;	/* If range req last seq */
	uint32_t flags;		/* Type of request open etc */
	uint32_t sbcc_at_s;	/* When we allocate what is the sb_cc */
	uint32_t hint_maxseg;	/* Client hinted maxseg */
	uint32_t hybrid_flags;	/* Hybrid flags on this request */
};


/*
 * Change Query responses for a stack switch we create a structure
 * that allows query response from the new stack to the old, if
 * supported.
 *
 * There are three queries currently defined.
 *  - sendmap
 *  - timers
 *  - rack_times
 *
 * For the sendmap query the caller fills in the
 * req and the req_param as the first seq (usually
 * snd_una). When the response comes back indicating
 * that there was data (return value 1), then the caller
 * can build a sendmap entry based on the range and the
 * times. The next query would then be done at the 
 * newly created sendmap_end. Repeated until sendmap_end == snd_max.
 *
 * Flags in sendmap_flags are defined below as well.
 *
 * For timers the standard PACE_TMR_XXXX flags are returned indicating
 * a pacing timer (possibly) and one other timer. If pacing timer then
 * the expiration timeout time in microseconds is in timer_pacing_to.
 * And the value used with whatever timer (if a flag is set) is in
 * timer_rxt. If no timers are running a 0 is returned and of
 * course no flags are set in timer_hpts_flags.
 *
 * The rack_times are a misc collection of information that
 * the old stack might possibly fill in. Of course its possible
 * that an old stack may not have a piece of information. If so
 * then setting that value to zero is advised. Setting any 
 * timestamp passed should only place a zero in it when it
 * is unfilled. This may mean that a time is off by a micro-second
 * but this is ok in the grand scheme of things.
 *
 * When switching stacks it is desireable to get as much information
 * from the old stack to the new stack as possible. Though not always
 * will the stack be compatible in the types of information. The
 * init() function needs to take care when it begins changing 
 * things such as inp_flags2 and the timer units to position these
 * changes at a point where it is unlikely they will fail after
 * making such changes. A stack optionally can have an "undo"
 * function  
 *
 * To transfer information to the old stack from the new in 
 * respect to LRO and the inp_flags2, the new stack should set
 * the inp_flags2 to what it supports. The old stack in its
 * fini() function should call the tcp_handle_orphaned_packets()
 * to clean up any packets. Note that a new stack should attempt
 */

/* Query types */
#define TCP_QUERY_SENDMAP	1
#define TCP_QUERY_TIMERS_UP	2
#define TCP_QUERY_RACK_TIMES	3

/* Flags returned in sendmap_flags */
#define SNDMAP_ACKED		0x000001/* The remote endpoint acked this */
#define SNDMAP_OVERMAX		0x000008/* We have more retran's then we can fit */
#define SNDMAP_SACK_PASSED	0x000010/* A sack was done above this block */
#define SNDMAP_HAS_FIN		0x000040/* segment is sent with fin */
#define SNDMAP_TLP		0x000080/* segment sent as tail-loss-probe */
#define SNDMAP_HAS_SYN		0x000800/* SYN is on this guy */
#define SNDMAP_HAD_PUSH		0x008000/* Push was sent on original send */
#define SNDMAP_MASK  (SNDMAP_ACKED|SNDMAP_OVERMAX|SNDMAP_SACK_PASSED|SNDMAP_HAS_FIN\
		      |SNDMAP_TLP|SNDMAP_HAS_SYN|SNDMAP_HAD_PUSH)
#define SNDMAP_NRTX 3

struct tcp_query_resp {
	int req;
	uint32_t req_param;
	union {
		struct {
			tcp_seq sendmap_start;
			tcp_seq sendmap_end;
			int sendmap_send_cnt;
			uint64_t sendmap_time[SNDMAP_NRTX];
			uint64_t sendmap_ack_arrival;
			int sendmap_flags;
			uint32_t sendmap_r_rtr_bytes;
			/* If FAS is available if not 0 */
			uint32_t sendmap_fas;
			uint8_t sendmap_dupacks;
		};
		struct {
			uint32_t timer_hpts_flags;
			uint32_t timer_pacing_to;
			uint32_t timer_timer_exp;
		};
		struct {
			/* Timestamps and rtt's */
			uint32_t rack_reorder_ts;	/* Last uscts that reordering was seen */
			uint32_t rack_num_dsacks;	/* Num of dsacks seen */
			uint32_t rack_rxt_last_time; 	/* Last time a RXT/TLP or rack tmr  went off */
			uint32_t rack_min_rtt;		/* never 0 smallest rtt seen */
			uint32_t rack_rtt;		/* Last rtt used by rack */
			uint32_t rack_tmit_time;	/* The time the rtt seg was tmited */
			uint32_t rack_time_went_idle;	/* If in persist the time we went idle */
			/* Prr data  */
			uint32_t rack_sacked;
			uint32_t rack_holes_rxt;
			uint32_t rack_prr_delivered;
			uint32_t rack_prr_recovery_fs;
			uint32_t rack_prr_out;
			uint32_t rack_prr_sndcnt;
			/* TLP data */
			uint16_t rack_tlp_cnt_out;	/* How many tlp's have been sent */
			/* Various bits */
			uint8_t  rack_tlp_out;		/* Is a TLP outstanding */
			uint8_t  rack_srtt_measured;	/* The previous stack has measured srtt */
			uint8_t  rack_in_persist;	/* Is the old stack in persists? */
			uint8_t	 rack_wanted_output;	/* Did the prevous stack have a want output set */
		};
	};
};

#define TCP_TMR_GRANULARITY_TICKS	1	/* TCP timers are in ticks (msec if hz=1000)  */
#define TCP_TMR_GRANULARITY_USEC	2	/* TCP timers are in microseconds */

typedef enum {
	TT_REXMT = 0,
	TT_PERSIST,
	TT_KEEP,
	TT_2MSL,
	TT_DELACK,
	TT_N,
} tt_which;

typedef enum {
	TT_PROCESSING = 0,
	TT_PROCESSED,
	TT_STARTING,
	TT_STOPPING,
} tt_what;

/*
 * Tcp control block, one per tcp connection.
 */
struct tcpcb {
	struct inpcb t_inpcb;		/* embedded protocol independent cb */
#define	t_start_zero	t_fb
#define	t_zero_size	(sizeof(struct tcpcb) - \
			    offsetof(struct tcpcb, t_start_zero))
	struct tcp_function_block *t_fb;/* TCP function call block */
	void	*t_fb_ptr;		/* Pointer to t_fb specific data */

	struct callout t_callout;
	sbintime_t t_timers[TT_N];
	sbintime_t t_precisions[TT_N];

	/* HPTS. Used by BBR and Rack stacks. See tcp_hpts.c for more info. */
	TAILQ_ENTRY(tcpcb)	t_hpts;		/* linkage to HPTS ring */
	STAILQ_HEAD(, mbuf)	t_inqueue;	/* HPTS input packets queue */
	uint32_t t_hpts_request;	/* Current hpts request, zero if
					 * fits in the pacing window. */
	uint32_t t_hpts_slot;		/* HPTS wheel slot this tcb is. */
	uint32_t t_hpts_drop_reas;	/* Reason we are dropping the pcb. */
	uint32_t t_hpts_gencnt;
	uint16_t t_hpts_cpu;		/* CPU chosen by hpts_cpuid(). */
	uint16_t t_lro_cpu;		/* CPU derived from LRO. */
#define	HPTS_CPU_NONE	((uint16_t)-1)
	enum {
		IHPTS_NONE = 0,
		IHPTS_ONQUEUE,
		IHPTS_MOVING,
	} t_in_hpts;			/* Is it linked into HPTS? */

	uint32_t t_maxseg:24,		/* maximum segment size */
		_t_logstate:8;		/* State of "black box" logging */
	uint32_t t_port:16,		/* Tunneling (over udp) port */
		t_state:4,		/* state of this connection */
		t_idle_reduce : 1,
		t_delayed_ack: 7,	/* Delayed ack variable */
		t_fin_is_rst: 1,	/* Are fin's treated as resets */
		t_log_state_set: 1,
		bits_spare : 2;
	u_int	t_flags;
	tcp_seq	snd_una;		/* sent but unacknowledged */
	tcp_seq	snd_max;		/* highest sequence number sent;
					 * used to recognize retransmits
					 */
	tcp_seq snd_nxt;		/* send next */
	tcp_seq snd_up;			/* send urgent pointer */
	uint32_t snd_wnd;		/* send window */
	uint32_t snd_cwnd;		/* congestion-controlled window */
	uint32_t ts_offset;		/* our timestamp offset */
	uint32_t rfbuf_ts;		/* recv buffer autoscaling timestamp */
	int	rcv_numsacks;		/* # distinct sack blks present */
	u_int	t_tsomax;		/* TSO total burst length limit */
	u_int	t_tsomaxsegcount;	/* TSO maximum segment count */
	u_int	t_tsomaxsegsize;	/* TSO maximum segment size in bytes */
	tcp_seq	rcv_nxt;		/* receive next */
	tcp_seq	rcv_adv;		/* advertised window */
	uint32_t rcv_wnd;		/* receive window */
	u_int	t_flags2;		/* More tcpcb flags storage */
	int	t_srtt;			/* smoothed round-trip time */
	int	t_rttvar;		/* variance in round-trip time */
	uint32_t ts_recent;		/* timestamp echo data */
	u_char	snd_scale;		/* window scaling for send window */
	u_char	rcv_scale;		/* window scaling for recv window */
	u_char	snd_limited;		/* segments limited transmitted */
	u_char	request_r_scale;	/* pending window scaling */
	tcp_seq	last_ack_sent;
	u_int	t_rcvtime;		/* inactivity time */
	tcp_seq	rcv_up;			/* receive urgent pointer */
	int	t_segqlen;		/* segment reassembly queue length */
	uint32_t t_segqmbuflen;		/* total reassembly queue byte length */
	struct	tsegqe_head t_segq;	/* segment reassembly queue */
	uint32_t snd_ssthresh;		/* snd_cwnd size threshold for
					 * for slow start exponential to
					 * linear switch
					 */
	tcp_seq	snd_wl1;		/* window update seg seq number */
	tcp_seq	snd_wl2;		/* window update seg ack number */

	tcp_seq	irs;			/* initial receive sequence number */
	tcp_seq	iss;			/* initial send sequence number */
	u_int	t_acktime;		/* RACK and BBR incoming new data was acked */
	u_int	t_sndtime;		/* time last data was sent */
	u_int	ts_recent_age;		/* when last updated */
	tcp_seq	snd_recover;		/* for use in NewReno Fast Recovery */
	char	t_oobflags;		/* have some */
	char	t_iobc;			/* input character */
	uint8_t t_nic_ktls_xmit:1,	/* active nic ktls xmit sessions */
		t_nic_ktls_xmit_dis:1,	/* disabled nic xmit ktls? */
		t_nic_ktls_spare:6;	/* spare nic ktls */
	int	t_rxtcur;		/* current retransmit value (ticks) */

	int	t_rxtshift;		/* log(2) of rexmt exp. backoff */
	u_int	t_rtttime;		/* RTT measurement start time */

	tcp_seq	t_rtseq;		/* sequence number being timed */
	u_int	t_starttime;		/* time connection was established */
	u_int	t_fbyte_in;		/* ticks time first byte queued in */
	u_int	t_fbyte_out;		/* ticks time first byte queued out */

	u_int	t_pmtud_saved_maxseg;	/* pre-blackhole MSS */
	int	t_blackhole_enter;	/* when to enter blackhole detection */
	int	t_blackhole_exit;	/* when to exit blackhole detection */
	u_int	t_rttmin;		/* minimum rtt allowed */

	int	t_softerror;		/* possible error not yet reported */
	uint32_t max_sndwnd;		/* largest window peer has offered */
	uint32_t snd_cwnd_prev;		/* cwnd prior to retransmit */
	uint32_t snd_ssthresh_prev;	/* ssthresh prior to retransmit */
	tcp_seq	snd_recover_prev;	/* snd_recover prior to retransmit */
	int	t_sndzerowin;		/* zero-window updates sent */
	int	snd_numholes;		/* number of holes seen by sender */
	u_int	t_badrxtwin;		/* window for retransmit recovery */
	TAILQ_HEAD(sackhole_head, sackhole) snd_holes;
					/* SACK scoreboard (sorted) */
	tcp_seq	snd_fack;		/* last seq number(+1) sack'd by rcv'r*/
	struct sackblk sackblks[MAX_SACK_BLKS]; /* seq nos. of sack blocks */
	struct sackhint	sackhint;	/* SACK scoreboard hint */
	int	t_rttlow;		/* smallest observerved RTT */
	int	rfbuf_cnt;		/* recv buffer autoscaling byte count */
	struct toedev	*tod;		/* toedev handling this connection */
	int	t_sndrexmitpack;	/* retransmit packets sent */
	int	t_rcvoopack;		/* out-of-order packets received */
	void	*t_toe;			/* TOE pcb pointer */
	struct cc_algo	*t_cc;		/* congestion control algorithm */
	struct cc_var	t_ccv;		/* congestion control specific vars */
	int	t_bytes_acked;		/* # bytes acked during current RTT */
	u_int	t_maxunacktime;
	u_int	t_keepinit;		/* time to establish connection */
	u_int	t_keepidle;		/* time before keepalive probes begin */
	u_int	t_keepintvl;		/* interval between keepalives */
	u_int	t_keepcnt;		/* number of keepalives before close */
	int	t_dupacks;		/* consecutive dup acks recd */
	int	t_lognum;		/* Number of log entries */
	int	t_loglimit;		/* Maximum number of log entries */
	uint32_t t_rcep;		/* Number of received CE marked pkts */
	uint32_t t_scep;		/* Synced number of delivered CE pkts */
	int64_t	t_pacing_rate;		/* bytes / sec, -1 => unlimited */
	struct tcp_log_stailq t_logs;	/* Log buffer */
	struct tcp_log_id_node *t_lin;
	struct tcp_log_id_bucket *t_lib;
	const char *t_output_caller;	/* Function that called tcp_output */
	struct statsblob *t_stats;	/* Per-connection stats */
	/* Should these be a pointer to the arrays or an array? */
	uint32_t t_logsn;		/* Log "serial number" */
	uint32_t gput_ts;		/* Time goodput measurement started */
	tcp_seq gput_seq;		/* Outbound measurement seq */
	tcp_seq gput_ack;		/* Inbound measurement ack */
	int32_t t_stats_gput_prev;	/* XXXLAS: Prev gput measurement */
	uint32_t t_maxpeakrate;		/* max peak rate set by user, bytes/s */
	uint32_t t_sndtlppack;		/* tail loss probe packets sent */
	uint64_t t_sndtlpbyte;		/* total tail loss probe bytes sent */
	uint64_t t_sndbytes;		/* total bytes sent */
	uint64_t t_snd_rxt_bytes;	/* total bytes retransmitted */
	uint32_t t_dsack_bytes;		/* dsack bytes received */
	uint32_t t_dsack_tlp_bytes;	/* dsack bytes received for TLPs sent */
	uint32_t t_dsack_pack;		/* dsack packets we have eceived */
	uint8_t t_tmr_granularity;	/* Granularity of all timers srtt etc */
	uint8_t t_rttupdated;		/* number of times rtt sampled */
	/* TCP Fast Open */
	uint8_t t_tfo_client_cookie_len; /* TFO client cookie length */
	uint32_t t_end_info_status;	/* Status flag of end info */
	sbintime_t t_challenge_ack_end;	/* End of the challenge ack epoch */
	uint32_t t_challenge_ack_cnt;	/* Number of challenge ACKs sent in
					 * current epoch
					 */

	unsigned int *t_tfo_pending;	/* TFO server pending counter */
	union {
		uint8_t client[TCP_FASTOPEN_MAX_COOKIE_LEN];
		uint64_t server;
	} t_tfo_cookie;			/* TCP Fast Open cookie to send */
	union {
		uint8_t t_end_info_bytes[TCP_END_BYTE_INFO];
		uint64_t t_end_info;
	};
	struct osd	t_osd;		/* storage for Khelp module data */
	uint8_t _t_logpoint;	/* Used when a BB log points is enabled */
	/*
	 * Keep all #ifdef'ed components at the end of the structure!
	 * This is important to minimize problems when compiling modules
	 * using this structure from within the modules' directory.
	 */
#ifdef TCP_REQUEST_TRK
	/* Response tracking addons. */
	uint8_t t_tcpreq_req;	/* Request count */
	uint8_t t_tcpreq_open;	/* Number of open range requests */
	uint8_t t_tcpreq_closed;	/* Number of closed range requests */
	uint32_t tcp_hybrid_start;	/* Num of times we started hybrid pacing */
	uint32_t tcp_hybrid_stop;	/* Num of times we stopped hybrid pacing */
	uint32_t tcp_hybrid_error;	/* Num of times we failed to start hybrid pacing */
	struct tcp_sendfile_track t_tcpreq_info[MAX_TCP_TRK_REQ];
#endif
#ifdef TCP_ACCOUNTING
	uint64_t tcp_cnt_counters[TCP_NUM_CNT_COUNTERS];
	uint64_t tcp_proc_time[TCP_NUM_CNT_COUNTERS];
#endif
#ifdef TCPPCAP
	struct mbufq t_inpkts;		/* List of saved input packets. */
	struct mbufq t_outpkts;		/* List of saved output packets. */
#endif
};
#endif	/* _KERNEL || _WANT_TCPCB */

#ifdef _KERNEL
struct tcptemp {
	u_char	tt_ipgen[40]; /* the size must be of max ip header, now IPv6 */
	struct	tcphdr tt_t;
};

/* SACK scoreboard update status */
typedef enum {
	SACK_NOCHANGE = 0,
	SACK_CHANGE,
	SACK_NEWLOSS
} sackstatus_t;

/* Enable TCP/UDP tunneling port */
#define TCP_TUNNELING_PORT_MIN		0
#define TCP_TUNNELING_PORT_MAX		65535
#define TCP_TUNNELING_PORT_DEFAULT	0

/* Enable TCP/UDP tunneling port */
#define TCP_TUNNELING_OVERHEAD_MIN	sizeof(struct udphdr)
#define TCP_TUNNELING_OVERHEAD_MAX	1024
#define TCP_TUNNELING_OVERHEAD_DEFAULT	TCP_TUNNELING_OVERHEAD_MIN

/* Minimum map entries limit value, if set */
#define TCP_MIN_MAP_ENTRIES_LIMIT	128

/*
 * TODO: We yet need to brave plowing in
 * to tcp_input() and the pru_usrreq() block.
 * Right now these go to the old standards which
 * are somewhat ok, but in the long term may
 * need to be changed. If we do tackle tcp_input()
 * then we need to get rid of the tcp_do_segment()
 * function below.
 */
/* Flags for tcp functions */
#define	TCP_FUNC_BEING_REMOVED	0x01   	/* Can no longer be referenced */
#define	TCP_FUNC_OUTPUT_CANDROP	0x02   	/* tfb_tcp_output may ask tcp_drop */
#define	TCP_FUNC_DEFAULT_OK	0x04   	/* Can be used as default */

/**
 * If defining the optional tcp_timers, in the
 * tfb_tcp_timer_stop call you must use the
 * callout_async_drain() function with the
 * tcp_timer_discard callback. You should check
 * the return of callout_async_drain() and if 0
 * increment tt_draincnt. Since the timer sub-system
 * does not know your callbacks you must provide a
 * stop_all function that loops through and calls
 * tcp_timer_stop() with each of your defined timers.
 *
 * tfb_tcp_handoff_ok is a mandatory function allowing
 * to query a stack, if it can take over a tcpcb.
 * You return 0 to say you can take over and run your stack,
 * you return non-zero (an error number) to say no you can't.
 *
 * tfb_tcp_fb_init is used to allow the new stack to
 * setup its control block. Among the things it must
 * do is:
 * a) Make sure that the inp_flags2 is setup correctly
 *    for LRO. There are two flags that the previous
 *    stack may have set INP_MBUF_ACKCMP and 
 *    INP_SUPPORTS_MBUFQ. If the new stack does not
 *    support these it *should* clear the flags.
 * b) Make sure that the timers are in the proper
 *    granularity that the stack wants. The stack
 *    should check the t_tmr_granularity field. Currently
 *    there are two values that it may hold 
 *    TCP_TMR_GRANULARITY_TICKS and TCP_TMR_GRANULARITY_USEC.
 *    Use the functions tcp_timer_convert(tp, granularity);
 *    to move the timers to the correct format for your stack.
 *
 * The new stack may also optionally query the tfb_chg_query
 * function if the old stack has one. The new stack may ask
 * for one of three entries and can also state to the old
 * stack its support for the INP_MBUF_ACKCMP and 
 * INP_SUPPORTS_MBUFQ. This is important since if there are
 * queued ack's without that statement the old stack will
 * be forced to discard the queued acks. The requests that
 * can be made for information by the new stacks are:
 *
 * Note also that the tfb_tcp_fb_init() when called can
 * determine if a query is needed by looking at the 
 * value passed in the ptr. The ptr is designed to be
 * set in with any allocated memory, but the address
 * of the condtion (ptr == &tp->t_fb_ptr) will be
 * true if this is not a stack switch but the initial
 * setup of a tcb (which means no query would be needed).
 * If, however, the value is not t_fb_ptr, then the caller
 * is in the middle of a stack switch and is the new stack.
 * A query would be appropriate (if the new stack support 
 * the query mechanism).
 *
 * TCP_QUERY_SENDMAP - Query of outstanding data.
 * TCP_QUERY_TIMERS_UP	- Query about running timers.
 * TCP_SUPPORTED_LRO - Declaration in req_param of 
 *                     the inp_flags2 supported by 
 *                     the new stack.
 * TCP_QUERY_RACK_TIMES	- Enquire about various timestamps
 *                        and states the old stack may be in.
 * 
 * tfb_tcp_fb_fini is changed to add a flag to tell
 * the old stack if the tcb is being destroyed or
 * not. A one in the flag means the TCB is being
 * destroyed, a zero indicates its transitioning to
 * another stack (via socket option). The
 * tfb_tcp_fb_fini() function itself should not change timers
 * or inp_flags2 (the tfb_tcp_fb_init() must do that). However
 * if the old stack supports the LRO mbuf queuing, and the new
 * stack does not communicate via chg messages that it too does,
 * it must assume it does not and free any queued mbufs.
 *
 */
struct tcp_function_block {
	char tfb_tcp_block_name[TCP_FUNCTION_NAME_LEN_MAX];
	int	(*tfb_tcp_output)(struct tcpcb *);
	void	(*tfb_tcp_do_segment)(struct tcpcb *, struct mbuf *,
		    struct tcphdr *, int, int, uint8_t);
	int      (*tfb_do_segment_nounlock)(struct tcpcb *, struct mbuf *,
		    struct tcphdr *, int, int, uint8_t, int, struct timeval *);
	int     (*tfb_do_queued_segments)(struct tcpcb *, int);
	int     (*tfb_tcp_ctloutput)(struct tcpcb *, struct sockopt *);
	/* Optional memory allocation/free routine */
	int	(*tfb_tcp_fb_init)(struct tcpcb *, void **);
	void	(*tfb_tcp_fb_fini)(struct tcpcb *, int);
	/* Optional timers, must define all if you define one */
	int	(*tfb_tcp_timer_stop_all)(struct tcpcb *);
	void	(*tfb_tcp_rexmit_tmr)(struct tcpcb *);
	int	(*tfb_tcp_handoff_ok)(struct tcpcb *);
	void	(*tfb_tcp_mtu_chg)(struct tcpcb *tp);
	int	(*tfb_pru_options)(struct tcpcb *, int);
	void	(*tfb_hwtls_change)(struct tcpcb *, int);
	int	(*tfb_chg_query)(struct tcpcb *, struct tcp_query_resp *);
	void	(*tfb_switch_failed)(struct tcpcb *);
	bool	(*tfb_early_wake_check)(struct tcpcb *);
	int     (*tfb_compute_pipe)(struct tcpcb *tp);
	volatile uint32_t tfb_refcnt;
	uint32_t  tfb_flags;
	uint8_t	tfb_id;
};

/* Maximum number of names each TCP function block can be registered with. */
#define	TCP_FUNCTION_NAME_NUM_MAX	8

struct tcp_function {
	TAILQ_ENTRY(tcp_function)	tf_next;
	char				tf_name[TCP_FUNCTION_NAME_LEN_MAX];
	struct tcp_function_block	*tf_fb;
};

TAILQ_HEAD(tcp_funchead, tcp_function);

struct tcpcb * tcp_drop(struct tcpcb *, int);

#ifdef _NETINET_IN_PCB_H_
#define	intotcpcb(inp)	__containerof((inp), struct tcpcb, t_inpcb)
#define	sototcpcb(so)	intotcpcb(sotoinpcb(so))
#define	tptoinpcb(tp)	(&(tp)->t_inpcb)
#define	tptosocket(tp)	(tp)->t_inpcb.inp_socket

/*
 * tcp_output()
 * Handles tcp_drop request from advanced stacks and reports that inpcb is
 * gone with negative return code.
 * Drop in replacement for the default stack.
 */
static inline int
tcp_output(struct tcpcb *tp)
{
	struct inpcb *inp = tptoinpcb(tp);
	int rv;

	INP_WLOCK_ASSERT(inp);

	rv = tp->t_fb->tfb_tcp_output(tp);
	if (rv < 0) {
		KASSERT(tp->t_fb->tfb_flags & TCP_FUNC_OUTPUT_CANDROP,
		    ("TCP stack %s requested tcp_drop(%p)",
		    tp->t_fb->tfb_tcp_block_name, tp));
		tp = tcp_drop(tp, -rv);
		if (tp)
			INP_WUNLOCK(inp);
	}

	return (rv);
}

/*
 * tcp_output_unlock()
 * Always returns unlocked, handles drop request from advanced stacks.
 * Always returns positive error code.
 */
static inline int
tcp_output_unlock(struct tcpcb *tp)
{
	struct inpcb *inp = tptoinpcb(tp);
	int rv;

	INP_WLOCK_ASSERT(inp);

	rv = tp->t_fb->tfb_tcp_output(tp);
	if (rv < 0) {
		KASSERT(tp->t_fb->tfb_flags & TCP_FUNC_OUTPUT_CANDROP,
		    ("TCP stack %s requested tcp_drop(%p)",
		    tp->t_fb->tfb_tcp_block_name, tp));
		rv = -rv;
		tp = tcp_drop(tp, rv);
		if (tp)
			INP_WUNLOCK(inp);
	} else
		INP_WUNLOCK(inp);

	return (rv);
}

/*
 * tcp_output_nodrop()
 * Always returns locked.  It is caller's responsibility to run tcp_drop()!
 * Useful in syscall implementations, when we want to perform some logging
 * and/or tracing with tcpcb before calling tcp_drop().  To be used with
 * tcp_unlock_or_drop() later.
 *
 * XXXGL: maybe don't allow stacks to return a drop request at certain
 * TCP states? Why would it do in connect(2)? In recv(2)?
 */
static inline int
tcp_output_nodrop(struct tcpcb *tp)
{
	int rv;

	INP_WLOCK_ASSERT(tptoinpcb(tp));

	rv = tp->t_fb->tfb_tcp_output(tp);
	KASSERT(rv >= 0 || tp->t_fb->tfb_flags & TCP_FUNC_OUTPUT_CANDROP,
	    ("TCP stack %s requested tcp_drop(%p)",
	    tp->t_fb->tfb_tcp_block_name, tp));
	return (rv);
}

/*
 * tcp_unlock_or_drop()
 * Handle return code from tfb_tcp_output() after we have logged/traced,
 * to be used with tcp_output_nodrop().
 */
static inline int
tcp_unlock_or_drop(struct tcpcb *tp, int tcp_output_retval)
{
	struct inpcb *inp = tptoinpcb(tp);

	INP_WLOCK_ASSERT(inp);

        if (tcp_output_retval < 0) {
                tcp_output_retval = -tcp_output_retval;
                if (tcp_drop(tp, tcp_output_retval) != NULL)
                        INP_WUNLOCK(inp);
        } else
		INP_WUNLOCK(inp);

	return (tcp_output_retval);
}
#endif	/* _NETINET_IN_PCB_H_ */

static int inline
tcp_packets_this_ack(struct tcpcb *tp, tcp_seq ack)
{
	return ((ack - tp->snd_una) / tp->t_maxseg +
		((((ack - tp->snd_una) % tp->t_maxseg) != 0) ? 1 : 0));
}
#endif	/* _KERNEL */

/*
 * Flags and utility macros for the t_flags field.
 */
#define	TF_ACKNOW	0x00000001	/* ack peer immediately */
#define	TF_DELACK	0x00000002	/* ack, but try to delay it */
#define	TF_NODELAY	0x00000004	/* don't delay packets to coalesce */
#define	TF_NOOPT	0x00000008	/* don't use tcp options */
#define	TF_SENTFIN	0x00000010	/* have sent FIN */
#define	TF_REQ_SCALE	0x00000020	/* have/will request window scaling */
#define	TF_RCVD_SCALE	0x00000040	/* other side has requested scaling */
#define	TF_REQ_TSTMP	0x00000080	/* have/will request timestamps */
#define	TF_RCVD_TSTMP	0x00000100	/* a timestamp was received in SYN */
#define	TF_SACK_PERMIT	0x00000200	/* other side said I could SACK */
#define	TF_NEEDSYN	0x00000400	/* send SYN (implicit state) */
#define	TF_NEEDFIN	0x00000800	/* send FIN (implicit state) */
#define	TF_NOPUSH	0x00001000	/* don't push */
#define	TF_PREVVALID	0x00002000	/* saved values for bad rxmit valid
					 * Note: accessing and restoring from
					 * these may only be done in the 1st
					 * RTO recovery round (t_rxtshift == 1)
					 */
#define	TF_WAKESOR	0x00004000	/* wake up receive socket */
#define	TF_GPUTINPROG	0x00008000	/* Goodput measurement in progress */
#define	TF_MORETOCOME	0x00010000	/* More data to be appended to sock */
#define	TF_SONOTCONN	0x00020000	/* needs soisconnected() on ESTAB */
#define	TF_LASTIDLE	0x00040000	/* connection was previously idle */
#define	TF_RXWIN0SENT	0x00080000	/* sent a receiver win 0 in response */
#define	TF_FASTRECOVERY	0x00100000	/* in NewReno Fast Recovery */
#define	TF_WASFRECOVERY	0x00200000	/* was in NewReno Fast Recovery */
#define	TF_SIGNATURE	0x00400000	/* require MD5 digests (RFC2385) */
#define	TF_FORCEDATA	0x00800000	/* force out a byte */
#define	TF_TSO		0x01000000	/* TSO enabled on this connection */
#define	TF_TOE		0x02000000	/* this connection is offloaded */
#define	TF_CLOSED	0x04000000	/* close(2) called on socket */
#define	TF_UNUSED1	0x08000000	/* unused */
#define	TF_LRD		0x10000000	/* Lost Retransmission Detection */
#define	TF_CONGRECOVERY	0x20000000	/* congestion recovery mode */
#define	TF_WASCRECOVERY	0x40000000	/* was in congestion recovery */
#define	TF_FASTOPEN	0x80000000	/* TCP Fast Open indication */

#define	IN_FASTRECOVERY(t_flags)	(t_flags & TF_FASTRECOVERY)
#define	ENTER_FASTRECOVERY(t_flags)	t_flags |= TF_FASTRECOVERY
#define	EXIT_FASTRECOVERY(t_flags)	t_flags &= ~TF_FASTRECOVERY

#define	IN_CONGRECOVERY(t_flags)	(t_flags & TF_CONGRECOVERY)
#define	ENTER_CONGRECOVERY(t_flags)	t_flags |= TF_CONGRECOVERY
#define	EXIT_CONGRECOVERY(t_flags)	t_flags &= ~TF_CONGRECOVERY

#define	IN_RECOVERY(t_flags) (t_flags & (TF_CONGRECOVERY | TF_FASTRECOVERY))
#define	ENTER_RECOVERY(t_flags) t_flags |= (TF_CONGRECOVERY | TF_FASTRECOVERY)
#define	EXIT_RECOVERY(t_flags) t_flags &= ~(TF_CONGRECOVERY | TF_FASTRECOVERY)

#if defined(_KERNEL)
#if !defined(TCP_RFC7413)
#define	IS_FASTOPEN(t_flags)		(false)
#else
#define	IS_FASTOPEN(t_flags)		(t_flags & TF_FASTOPEN)
#endif
#endif

#define	BYTES_THIS_ACK(tp, th)	(th->th_ack - tp->snd_una)

/*
 * Flags for the t_oobflags field.
 */
#define	TCPOOB_HAVEDATA	0x01
#define	TCPOOB_HADDATA	0x02

/*
 * Flags for the extended TCP flags field, t_flags2
 */
#define	TF2_PLPMTU_BLACKHOLE	0x00000001 /* Possible PLPMTUD Black Hole. */
#define	TF2_PLPMTU_PMTUD	0x00000002 /* Allowed to attempt PLPMTUD. */
#define	TF2_PLPMTU_MAXSEGSNT	0x00000004 /* Last seg sent was full seg. */
#define	TF2_LOG_AUTO		0x00000008 /* Session is auto-logging. */
#define	TF2_DROP_AF_DATA	0x00000010 /* Drop after all data ack'd */
#define	TF2_ECN_PERMIT		0x00000020 /* connection ECN-ready */
#define	TF2_ECN_SND_CWR		0x00000040 /* ECN CWR in queue */
#define	TF2_ECN_SND_ECE		0x00000080 /* ECN ECE in queue */
#define	TF2_ACE_PERMIT		0x00000100 /* Accurate ECN mode */
#define	TF2_HPTS_CPU_SET	0x00000200 /* t_hpts_cpu is not random */
#define	TF2_FBYTES_COMPLETE	0x00000400 /* We have first bytes in and out */
#define	TF2_ECN_USE_ECT1	0x00000800 /* Use ECT(1) marking on session */
#define TF2_TCP_ACCOUNTING	0x00001000 /* Do TCP accounting */
#define	TF2_HPTS_CALLS		0x00002000 /* tcp_output() called via HPTS */
#define	TF2_MBUF_L_ACKS		0x00004000 /* large mbufs for ack compression */
#define	TF2_MBUF_ACKCMP		0x00008000 /* mbuf ack compression ok */
#define	TF2_SUPPORTS_MBUFQ	0x00010000 /* Supports the mbuf queue method */
#define	TF2_MBUF_QUEUE_READY	0x00020000 /* Inputs can be queued */
#define	TF2_DONT_SACK_QUEUE	0x00040000 /* Don't wake on sack */
#define	TF2_CANNOT_DO_ECN	0x00080000 /* The stack does not do ECN */
#define	TF2_NO_ISS_CHECK	0x00400000 /* Don't check SEG.ACK against ISS */

/*
 * Structure to hold TCP options that are only used during segment
 * processing (in tcp_input), but not held in the tcpcb.
 * It's basically used to reduce the number of parameters
 * to tcp_dooptions and tcp_addoptions.
 * The binary order of the to_flags is relevant for packing of the
 * options in tcp_addoptions.
 */
struct tcpopt {
	u_int32_t	to_flags;	/* which options are present */
#define	TOF_MSS		0x0001		/* maximum segment size */
#define	TOF_SCALE	0x0002		/* window scaling */
#define	TOF_SACKPERM	0x0004		/* SACK permitted */
#define	TOF_TS		0x0010		/* timestamp */
#define	TOF_SIGNATURE	0x0040		/* TCP-MD5 signature option (RFC2385) */
#define	TOF_SACK	0x0080		/* Peer sent SACK option */
#define	TOF_FASTOPEN	0x0100		/* TCP Fast Open (TFO) cookie */
#define	TOF_MAXOPT	0x0200
	u_int32_t	to_tsval;	/* new timestamp */
	u_int32_t	to_tsecr;	/* reflected timestamp */
	u_char		*to_sacks;	/* pointer to the first SACK blocks */
	u_char		*to_signature;	/* pointer to the TCP-MD5 signature */
	u_int8_t	*to_tfo_cookie; /* pointer to the TFO cookie */
	u_int16_t	to_mss;		/* maximum segment size */
	u_int8_t	to_wscale;	/* window scaling */
	u_int8_t	to_nsacks;	/* number of SACK blocks */
	u_int8_t	to_tfo_len;	/* TFO cookie length */
	u_int32_t	to_spare;	/* UTO */
};

/*
 * Flags for tcp_dooptions.
 */
#define	TO_SYN		0x01		/* parse SYN-only options */

struct hc_metrics_lite {	/* must stay in sync with hc_metrics */
	uint32_t	rmx_mtu;	/* MTU for this path */
	uint32_t	rmx_ssthresh;	/* outbound gateway buffer limit */
	uint32_t	rmx_rtt;	/* estimated round trip time */
	uint32_t	rmx_rttvar;	/* estimated rtt variance */
	uint32_t	rmx_cwnd;	/* congestion window */
	uint32_t	rmx_sendpipe;   /* outbound delay-bandwidth product */
	uint32_t	rmx_recvpipe;   /* inbound delay-bandwidth product */
};

/*
 * Used by tcp_maxmtu() to communicate interface specific features
 * and limits at the time of connection setup.
 */
struct tcp_ifcap {
	int	ifcap;
	u_int	tsomax;
	u_int	tsomaxsegcount;
	u_int	tsomaxsegsize;
};

#ifndef _NETINET_IN_PCB_H_
struct in_conninfo;
#endif /* _NETINET_IN_PCB_H_ */

/*
 * The smoothed round-trip time and estimated variance
 * are stored as fixed point numbers scaled by the values below.
 * For convenience, these scales are also used in smoothing the average
 * (smoothed = (1/scale)sample + ((scale-1)/scale)smoothed).
 * With these scales, srtt has 3 bits to the right of the binary point,
 * and thus an "ALPHA" of 0.875.  rttvar has 2 bits to the right of the
 * binary point, and is smoothed with an ALPHA of 0.75.
 */
#define	TCP_RTT_SCALE		32	/* multiplier for srtt; 5 bits frac. */
#define	TCP_RTT_SHIFT		5	/* shift for srtt; 5 bits frac. */
#define	TCP_RTTVAR_SCALE	16	/* multiplier for rttvar; 4 bits */
#define	TCP_RTTVAR_SHIFT	4	/* shift for rttvar; 4 bits */
#define	TCP_DELTA_SHIFT		2	/* see tcp_input.c */

/*
 * The initial retransmission should happen at rtt + 4 * rttvar.
 * Because of the way we do the smoothing, srtt and rttvar
 * will each average +1/2 tick of bias.  When we compute
 * the retransmit timer, we want 1/2 tick of rounding and
 * 1 extra tick because of +-1/2 tick uncertainty in the
 * firing of the timer.  The bias will give us exactly the
 * 1.5 tick we need.  But, because the bias is
 * statistical, we have to test that we don't drop below
 * the minimum feasible timer (which is 2 ticks).
 * This version of the macro adapted from a paper by Lawrence
 * Brakmo and Larry Peterson which outlines a problem caused
 * by insufficient precision in the original implementation,
 * which results in inappropriately large RTO values for very
 * fast networks.
 */
#define	TCP_REXMTVAL(tp) \
	max((tp)->t_rttmin, (((tp)->t_srtt >> (TCP_RTT_SHIFT - TCP_DELTA_SHIFT))  \
	  + (tp)->t_rttvar) >> TCP_DELTA_SHIFT)

/*
 * TCP statistics.
 * Many of these should be kept per connection,
 * but that's inconvenient at the moment.
 */
struct	tcpstat {
	uint64_t tcps_connattempt;	/* connections initiated */
	uint64_t tcps_accepts;		/* connections accepted */
	uint64_t tcps_connects;		/* connections established */
	uint64_t tcps_drops;		/* connections dropped */
	uint64_t tcps_conndrops;	/* embryonic connections dropped */
	uint64_t tcps_minmssdrops;	/* average minmss too low drops */
	uint64_t tcps_closed;		/* conn. closed (includes drops) */
	uint64_t tcps_segstimed;	/* segs where we tried to get rtt */
	uint64_t tcps_rttupdated;	/* times we succeeded */
	uint64_t tcps_delack;		/* delayed acks sent */
	uint64_t tcps_timeoutdrop;	/* conn. dropped in rxmt timeout */
	uint64_t tcps_rexmttimeo;	/* retransmit timeouts */
	uint64_t tcps_persisttimeo;	/* persist timeouts */
	uint64_t tcps_keeptimeo;	/* keepalive timeouts */
	uint64_t tcps_keepprobe;	/* keepalive probes sent */
	uint64_t tcps_keepdrops;	/* connections dropped in keepalive */
	uint64_t tcps_progdrops;	/* drops due to no progress */

	uint64_t tcps_sndtotal;		/* total packets sent */
	uint64_t tcps_sndpack;		/* data packets sent */
	uint64_t tcps_sndbyte;		/* data bytes sent */
	uint64_t tcps_sndrexmitpack;	/* data packets retransmitted */
	uint64_t tcps_sndrexmitbyte;	/* data bytes retransmitted */
	uint64_t tcps_sndrexmitbad;	/* unnecessary packet retransmissions */
	uint64_t tcps_sndacks;		/* ack-only packets sent */
	uint64_t tcps_sndprobe;		/* window probes sent */
	uint64_t tcps_sndurg;		/* packets sent with URG only */
	uint64_t tcps_sndwinup;		/* window update-only packets sent */
	uint64_t tcps_sndctrl;		/* control (SYN|FIN|RST) packets sent */

	uint64_t tcps_rcvtotal;		/* total packets received */
	uint64_t tcps_rcvpack;		/* packets received in sequence */
	uint64_t tcps_rcvbyte;		/* bytes received in sequence */
	uint64_t tcps_rcvbadsum;	/* packets received with ccksum errs */
	uint64_t tcps_rcvbadoff;	/* packets received with bad offset */
	uint64_t tcps_rcvreassfull;	/* packets dropped for no reass space */
	uint64_t tcps_rcvshort;		/* packets received too short */
	uint64_t tcps_rcvduppack;	/* duplicate-only packets received */
	uint64_t tcps_rcvdupbyte;	/* duplicate-only bytes received */
	uint64_t tcps_rcvpartduppack;	/* packets with some duplicate data */
	uint64_t tcps_rcvpartdupbyte;	/* dup. bytes in part-dup. packets */
	uint64_t tcps_rcvoopack;	/* out-of-order packets received */
	uint64_t tcps_rcvoobyte;	/* out-of-order bytes received */
	uint64_t tcps_rcvpackafterwin;	/* packets with data after window */
	uint64_t tcps_rcvbyteafterwin;	/* bytes rcvd after window */
	uint64_t tcps_rcvafterclose;	/* packets rcvd after "close" */
	uint64_t tcps_rcvwinprobe;	/* rcvd window probe packets */
	uint64_t tcps_rcvdupack;	/* rcvd duplicate acks */
	uint64_t tcps_rcvacktoomuch;	/* rcvd acks for unsent data */
	uint64_t tcps_rcvackpack;	/* rcvd ack packets */
	uint64_t tcps_rcvackbyte;	/* bytes acked by rcvd acks */
	uint64_t tcps_rcvwinupd;	/* rcvd window update packets */
	uint64_t tcps_pawsdrop;		/* segments dropped due to PAWS */
	uint64_t tcps_predack;		/* times hdr predict ok for acks */
	uint64_t tcps_preddat;		/* times hdr predict ok for data pkts */
	uint64_t tcps_pcbcachemiss;
	uint64_t tcps_cachedrtt;	/* times cached RTT in route updated */
	uint64_t tcps_cachedrttvar;	/* times cached rttvar updated */
	uint64_t tcps_cachedssthresh;	/* times cached ssthresh updated */
	uint64_t tcps_usedrtt;		/* times RTT initialized from route */
	uint64_t tcps_usedrttvar;	/* times RTTVAR initialized from rt */
	uint64_t tcps_usedssthresh;	/* times ssthresh initialized from rt*/
	uint64_t tcps_persistdrop;	/* timeout in persist state */
	uint64_t tcps_badsyn;		/* bogus SYN, e.g. premature ACK */
	uint64_t tcps_mturesent;	/* resends due to MTU discovery */
	uint64_t tcps_listendrop;	/* listen queue overflows */
	uint64_t tcps_badrst;		/* ignored RSTs in the window */

	uint64_t tcps_sc_added;		/* entry added to syncache */
	uint64_t tcps_sc_retransmitted;	/* syncache entry was retransmitted */
	uint64_t tcps_sc_dupsyn;	/* duplicate SYN packet */
	uint64_t tcps_sc_dropped;	/* could not reply to packet */
	uint64_t tcps_sc_completed;	/* successful extraction of entry */
	uint64_t tcps_sc_bucketoverflow;/* syncache per-bucket limit hit */
	uint64_t tcps_sc_cacheoverflow;	/* syncache cache limit hit */
	uint64_t tcps_sc_reset;		/* RST removed entry from syncache */
	uint64_t tcps_sc_stale;		/* timed out or listen socket gone */
	uint64_t tcps_sc_aborted;	/* syncache entry aborted */
	uint64_t tcps_sc_badack;	/* removed due to bad ACK */
	uint64_t tcps_sc_unreach;	/* ICMP unreachable received */
	uint64_t tcps_sc_zonefail;	/* zalloc() failed */
	uint64_t tcps_sc_sendcookie;	/* SYN cookie sent */
	uint64_t tcps_sc_recvcookie;	/* SYN cookie received */

	uint64_t tcps_hc_added;		/* entry added to hostcache */
	uint64_t tcps_hc_bucketoverflow;/* hostcache per bucket limit hit */

	uint64_t tcps_finwait2_drops;    /* Drop FIN_WAIT_2 connection after time limit */

	/* SACK related stats */
	uint64_t tcps_sack_recovery_episode; /* SACK recovery episodes */
	uint64_t tcps_sack_rexmits;	    /* SACK rexmit segments   */
	uint64_t tcps_sack_rexmit_bytes;    /* SACK rexmit bytes      */
	uint64_t tcps_sack_rcv_blocks;	    /* SACK blocks (options) received */
	uint64_t tcps_sack_send_blocks;	    /* SACK blocks (options) sent     */
	uint64_t tcps_sack_lostrexmt;	    /* SACK lost retransmission recovered */
	uint64_t tcps_sack_sboverflow;	    /* times scoreboard overflowed */

	/* ECN related stats */
	uint64_t tcps_ecn_rcvce;		/* ECN Congestion Experienced */
	uint64_t tcps_ecn_rcvect0;		/* ECN Capable Transport */
	uint64_t tcps_ecn_rcvect1;		/* ECN Capable Transport */
	uint64_t tcps_ecn_shs;		/* ECN successful handshakes */
	uint64_t tcps_ecn_rcwnd;	/* # times ECN reduced the cwnd */

	/* TCP_SIGNATURE related stats */
	uint64_t tcps_sig_rcvgoodsig;	/* Total matching signature received */
	uint64_t tcps_sig_rcvbadsig;	/* Total bad signature received */
	uint64_t tcps_sig_err_buildsig;	/* Failed to make signature */
	uint64_t tcps_sig_err_sigopt;	/* No signature expected by socket */
	uint64_t tcps_sig_err_nosigopt;	/* No signature provided by segment */

	/* Path MTU Discovery Black Hole Detection related stats */
	uint64_t tcps_pmtud_blackhole_activated;	 /* Black Hole Count */
	uint64_t tcps_pmtud_blackhole_activated_min_mss; /* BH at min MSS Count */
	uint64_t tcps_pmtud_blackhole_failed;		 /* Black Hole Failure Count */

	uint64_t tcps_tunneled_pkts;	/* Packets encap's in UDP received */
	uint64_t tcps_tunneled_errs;	/* Packets that had errors that were UDP encaped */

	/* Dsack related stats */
	uint64_t tcps_dsack_count;	/* Number of ACKs arriving with DSACKs */
	uint64_t tcps_dsack_bytes;	/* Number of bytes DSACK'ed no TLP */
	uint64_t tcps_dsack_tlp_bytes;	/* Number of bytes DSACK'ed due to TLPs */

	/* TCPS_TIME_WAIT usage stats */
	uint64_t tcps_tw_recycles;	/* Times time-wait was recycled. */
	uint64_t tcps_tw_resets;	/* Times time-wait sent a reset. */
	uint64_t tcps_tw_responds;	/* Times time-wait sent a valid ack. */

	/* Accurate ECN Handshake stats */
	uint64_t tcps_ace_nect;		/* ACE SYN packet with Non-ECT */
	uint64_t tcps_ace_ect1;		/* ACE SYN packet with ECT1 */
	uint64_t tcps_ace_ect0;		/* ACE SYN packet with ECT0 */
	uint64_t tcps_ace_ce;		/* ACE SYN packet with CE */

	/* ECN related stats */
	uint64_t tcps_ecn_sndect0;		/* ECN Capable Transport */
	uint64_t tcps_ecn_sndect1;		/* ECN Capable Transport */

	/*
	 * BBR and Rack implement TLP's these values count TLP bytes in
	 * two catagories, bytes that were retransmitted and bytes that
	 * were newly transmited. Both types can serve as TLP's but they
	 * are accounted differently.
	 */
	uint64_t tcps_tlpresends;	/* number of tlp resends */
	uint64_t tcps_tlpresend_bytes;	/* number of bytes resent by tlp */

	/* SEG.ACK validation failures */
	uint64_t tcps_rcvghostack;	/* received ACK for data never sent */
	uint64_t tcps_rcvacktooold;	/* received ACK for data too long ago */

	uint64_t _pad[2];		/* 2 TBD placeholder for STABLE */
};

#define	tcps_rcvmemdrop	tcps_rcvreassfull	/* compat */

#ifdef _KERNEL
#define	TI_UNLOCKED	1
#define	TI_RLOCKED	2
#include <sys/counter.h>

VNET_PCPUSTAT_DECLARE(struct tcpstat, tcpstat);	/* tcp statistics */
/*
 * In-kernel consumers can use these accessor macros directly to update
 * stats.
 */
#define	TCPSTAT_ADD(name, val)	\
    VNET_PCPUSTAT_ADD(struct tcpstat, tcpstat, name, (val))
#define	TCPSTAT_INC(name)	TCPSTAT_ADD(name, 1)

/*
 * Kernel module consumers must use this accessor macro.
 */
void	kmod_tcpstat_add(int statnum, int val);
#define	KMOD_TCPSTAT_ADD(name, val)					\
    kmod_tcpstat_add(offsetof(struct tcpstat, name) / sizeof(uint64_t), val)
#define	KMOD_TCPSTAT_INC(name)	KMOD_TCPSTAT_ADD(name, 1)

/*
 * Running TCP connection count by state.
 */
VNET_DECLARE(counter_u64_t, tcps_states[TCP_NSTATES]);
#define	V_tcps_states	VNET(tcps_states)
#define	TCPSTATES_INC(state)	counter_u64_add(V_tcps_states[state], 1)
#define	TCPSTATES_DEC(state)	counter_u64_add(V_tcps_states[state], -1)

/*
 * TCP specific helper hook point identifiers.
 */
#define	HHOOK_TCP_EST_IN		0
#define	HHOOK_TCP_EST_OUT		1
#define	HHOOK_TCP_LAST			HHOOK_TCP_EST_OUT

struct tcp_hhook_data {
	struct tcpcb	*tp;
	struct tcphdr	*th;
	struct tcpopt	*to;
	uint32_t	len;
	int		tso;
	tcp_seq		curack;
};
#ifdef TCP_HHOOK
void hhook_run_tcp_est_out(struct tcpcb *tp,
	struct tcphdr *th, struct tcpopt *to,
	uint32_t len, int tso);
#endif
#endif

/*
 * TCB structure exported to user-land via sysctl(3).
 *
 * Fields prefixed with "xt_" are unique to the export structure, and fields
 * with "t_" or other prefixes match corresponding fields of 'struct tcpcb'.
 *
 * Legend:
 * (s) - used by userland utilities in src
 * (p) - used by utilities in ports
 * (3) - is known to be used by third party software not in ports
 * (n) - no known usage
 *
 * Evil hack: declare only if in_pcb.h and sys/socketvar.h have been
 * included.  Not all of our clients do.
 */
#if defined(_NETINET_IN_PCB_H_) && defined(_SYS_SOCKETVAR_H_)
struct xtcpcb {
	ksize_t	xt_len;		/* length of this structure */
	struct xinpcb	xt_inp;
	char		xt_stack[TCP_FUNCTION_NAME_LEN_MAX];	/* (s) */
	char		xt_logid[TCP_LOG_ID_LEN];	/* (s) */
	char		xt_cc[TCP_CA_NAME_MAX];	/* (s) */
	int64_t		spare64[6];
	int32_t		t_state;		/* (s,p) */
	uint32_t	t_flags;		/* (s,p) */
	int32_t		t_sndzerowin;		/* (s) */
	int32_t		t_sndrexmitpack;	/* (s) */
	int32_t		t_rcvoopack;		/* (s) */
	int32_t		t_rcvtime;		/* (s) */
	int32_t		tt_rexmt;		/* (s) */
	int32_t		tt_persist;		/* (s) */
	int32_t		tt_keep;		/* (s) */
	int32_t		tt_2msl;		/* (s) */
	int32_t		tt_delack;		/* (s) */
	int32_t		t_logstate;		/* (3) */
	uint32_t	t_snd_cwnd;		/* (s) */
	uint32_t	t_snd_ssthresh;		/* (s) */
	uint32_t	t_maxseg;		/* (s) */
	uint32_t	t_rcv_wnd;		/* (s) */
	uint32_t	t_snd_wnd;		/* (s) */
	uint32_t	xt_ecn;			/* (s) */
	uint32_t	t_dsack_bytes;		/* (n) */
	uint32_t	t_dsack_tlp_bytes;	/* (n) */
	uint32_t	t_dsack_pack;		/* (n) */
	uint16_t	xt_encaps_port;		/* (s) */
	int16_t		spare16;
	int32_t		spare32[22];
} __aligned(8);

#ifdef _KERNEL
void	tcp_inptoxtp(const struct inpcb *, struct xtcpcb *);
#endif
#endif

/*
 * TCP function information (name-to-id mapping, aliases, and refcnt)
 * exported to user-land via sysctl(3).
 */
struct tcp_function_info {
	uint32_t	tfi_refcnt;
	uint8_t		tfi_id;
	char		tfi_name[TCP_FUNCTION_NAME_LEN_MAX];
	char		tfi_alias[TCP_FUNCTION_NAME_LEN_MAX];
};

/*
 * Identifiers for TCP sysctl nodes
 */
#define	TCPCTL_DO_RFC1323	1	/* use RFC-1323 extensions */
#define	TCPCTL_MSSDFLT		3	/* MSS default */
#define TCPCTL_STATS		4	/* statistics */
#define	TCPCTL_RTTDFLT		5	/* default RTT estimate */
#define	TCPCTL_KEEPIDLE		6	/* keepalive idle timer */
#define	TCPCTL_KEEPINTVL	7	/* interval to send keepalives */
#define	TCPCTL_SENDSPACE	8	/* send buffer space */
#define	TCPCTL_RECVSPACE	9	/* receive buffer space */
#define	TCPCTL_KEEPINIT		10	/* timeout for establishing syn */
#define	TCPCTL_PCBLIST		11	/* list of all outstanding PCBs */
#define	TCPCTL_DELACKTIME	12	/* time before sending delayed ACK */
#define	TCPCTL_V6MSSDFLT	13	/* MSS default for IPv6 */
#define	TCPCTL_SACK		14	/* Selective Acknowledgement,rfc 2018 */
#define	TCPCTL_DROP		15	/* drop tcp connection */
#define	TCPCTL_STATES		16	/* connection counts by TCP state */

#ifdef _KERNEL
#ifdef SYSCTL_DECL
SYSCTL_DECL(_net_inet_tcp);
SYSCTL_DECL(_net_inet_tcp_sack);
MALLOC_DECLARE(M_TCPLOG);
#endif

VNET_DECLARE(int, tcp_log_in_vain);
#define	V_tcp_log_in_vain		VNET(tcp_log_in_vain)

/*
 * Global TCP tunables shared between different stacks.
 * Please keep the list sorted.
 */
VNET_DECLARE(int, drop_synfin);
VNET_DECLARE(int, path_mtu_discovery);
VNET_DECLARE(int, tcp_abc_l_var);
VNET_DECLARE(uint32_t, tcp_ack_war_cnt);
VNET_DECLARE(uint32_t, tcp_ack_war_time_window);
VNET_DECLARE(int, tcp_autorcvbuf_max);
VNET_DECLARE(int, tcp_autosndbuf_inc);
VNET_DECLARE(int, tcp_autosndbuf_max);
VNET_DECLARE(int, tcp_delack_enabled);
VNET_DECLARE(int, tcp_do_autorcvbuf);
VNET_DECLARE(int, tcp_do_autosndbuf);
VNET_DECLARE(int, tcp_do_ecn);
VNET_DECLARE(int, tcp_do_lrd);
VNET_DECLARE(int, tcp_do_prr);
VNET_DECLARE(int, tcp_do_prr_conservative);
VNET_DECLARE(int, tcp_do_newcwv);
VNET_DECLARE(int, tcp_do_rfc1323);
VNET_DECLARE(int, tcp_tolerate_missing_ts);
VNET_DECLARE(int, tcp_do_rfc3042);
VNET_DECLARE(int, tcp_do_rfc3390);
VNET_DECLARE(int, tcp_do_rfc3465);
VNET_DECLARE(int, tcp_do_newsack);
VNET_DECLARE(int, tcp_do_sack);
VNET_DECLARE(int, tcp_do_tso);
VNET_DECLARE(int, tcp_ecn_maxretries);
VNET_DECLARE(int, tcp_initcwnd_segments);
VNET_DECLARE(int, tcp_insecure_rst);
VNET_DECLARE(int, tcp_insecure_syn);
VNET_DECLARE(int, tcp_insecure_ack);
VNET_DECLARE(uint32_t, tcp_map_entries_limit);
VNET_DECLARE(uint32_t, tcp_map_split_limit);
VNET_DECLARE(int, tcp_minmss);
VNET_DECLARE(int, tcp_mssdflt);
#ifdef STATS
VNET_DECLARE(int, tcp_perconn_stats_dflt_tpl);
VNET_DECLARE(int, tcp_perconn_stats_enable);
#endif /* STATS */
VNET_DECLARE(int, tcp_recvspace);
VNET_DECLARE(int, tcp_retries);
VNET_DECLARE(int, tcp_sack_globalholes);
VNET_DECLARE(int, tcp_sack_globalmaxholes);
VNET_DECLARE(int, tcp_sack_maxholes);
VNET_DECLARE(int, tcp_sc_rst_sock_fail);
VNET_DECLARE(int, tcp_sendspace);
VNET_DECLARE(int, tcp_udp_tunneling_overhead);
VNET_DECLARE(int, tcp_udp_tunneling_port);
VNET_DECLARE(struct inpcbinfo, tcbinfo);

#define	V_tcp_do_lrd			VNET(tcp_do_lrd)
#define	V_tcp_do_prr			VNET(tcp_do_prr)
#define	V_tcp_do_newcwv			VNET(tcp_do_newcwv)
#define	V_drop_synfin			VNET(drop_synfin)
#define	V_path_mtu_discovery		VNET(path_mtu_discovery)
#define	V_tcbinfo			VNET(tcbinfo)
#define	V_tcp_abc_l_var			VNET(tcp_abc_l_var)
#define	V_tcp_ack_war_cnt		VNET(tcp_ack_war_cnt)
#define	V_tcp_ack_war_time_window	VNET(tcp_ack_war_time_window)
#define	V_tcp_autorcvbuf_max		VNET(tcp_autorcvbuf_max)
#define	V_tcp_autosndbuf_inc		VNET(tcp_autosndbuf_inc)
#define	V_tcp_autosndbuf_max		VNET(tcp_autosndbuf_max)
#define	V_tcp_delack_enabled		VNET(tcp_delack_enabled)
#define	V_tcp_do_autorcvbuf		VNET(tcp_do_autorcvbuf)
#define	V_tcp_do_autosndbuf		VNET(tcp_do_autosndbuf)
#define	V_tcp_do_ecn			VNET(tcp_do_ecn)
#define	V_tcp_do_rfc1323		VNET(tcp_do_rfc1323)
#define	V_tcp_tolerate_missing_ts	VNET(tcp_tolerate_missing_ts)
#define V_tcp_ts_offset_per_conn	VNET(tcp_ts_offset_per_conn)
#define	V_tcp_do_rfc3042		VNET(tcp_do_rfc3042)
#define	V_tcp_do_rfc3390		VNET(tcp_do_rfc3390)
#define	V_tcp_do_rfc3465		VNET(tcp_do_rfc3465)
#define	V_tcp_do_newsack		VNET(tcp_do_newsack)
#define	V_tcp_do_sack			VNET(tcp_do_sack)
#define	V_tcp_do_tso			VNET(tcp_do_tso)
#define	V_tcp_ecn_maxretries		VNET(tcp_ecn_maxretries)
#define	V_tcp_initcwnd_segments		VNET(tcp_initcwnd_segments)
#define	V_tcp_insecure_rst		VNET(tcp_insecure_rst)
#define	V_tcp_insecure_syn		VNET(tcp_insecure_syn)
#define	V_tcp_insecure_ack		VNET(tcp_insecure_ack)
#define	V_tcp_map_entries_limit		VNET(tcp_map_entries_limit)
#define	V_tcp_map_split_limit		VNET(tcp_map_split_limit)
#define	V_tcp_minmss			VNET(tcp_minmss)
#define	V_tcp_mssdflt			VNET(tcp_mssdflt)
#ifdef STATS
#define	V_tcp_perconn_stats_dflt_tpl	VNET(tcp_perconn_stats_dflt_tpl)
#define	V_tcp_perconn_stats_enable	VNET(tcp_perconn_stats_enable)
#endif /* STATS */
#define	V_tcp_recvspace			VNET(tcp_recvspace)
#define	V_tcp_retries			VNET(tcp_retries)
#define	V_tcp_sack_globalholes		VNET(tcp_sack_globalholes)
#define	V_tcp_sack_globalmaxholes	VNET(tcp_sack_globalmaxholes)
#define	V_tcp_sack_maxholes		VNET(tcp_sack_maxholes)
#define	V_tcp_sc_rst_sock_fail		VNET(tcp_sc_rst_sock_fail)
#define	V_tcp_sendspace			VNET(tcp_sendspace)
#define	V_tcp_udp_tunneling_overhead	VNET(tcp_udp_tunneling_overhead)
#define	V_tcp_udp_tunneling_port	VNET(tcp_udp_tunneling_port)

#ifdef TCP_HHOOK
VNET_DECLARE(struct hhook_head *, tcp_hhh[HHOOK_TCP_LAST + 1]);
#define	V_tcp_hhh		VNET(tcp_hhh)
#endif

void	tcp_account_for_send(struct tcpcb *, uint32_t, uint8_t, uint8_t, bool);
int	 tcp_addoptions(struct tcpopt *, u_char *);
struct tcpcb *
	 tcp_close(struct tcpcb *);
void	 tcp_discardcb(struct tcpcb *);
void	 tcp_twstart(struct tcpcb *);
int	 tcp_ctloutput(struct socket *, struct sockopt *);
void	 tcp_fini(void *);
char	*tcp_log_addrs(struct in_conninfo *, struct tcphdr *, const void *,
	    const void *);
char	*tcp_log_vain(struct in_conninfo *, struct tcphdr *, const void *,
	    const void *);
int	 tcp_reass(struct tcpcb *, struct tcphdr *, tcp_seq *, int *,
	    struct mbuf *);
void	 tcp_reass_global_init(void);
void	 tcp_reass_flush(struct tcpcb *);
void	 tcp_dooptions(struct tcpopt *, u_char *, int, int);
void	tcp_dropwithreset(struct mbuf *, struct tcphdr *,
		     struct tcpcb *, int, int);
void	tcp_pulloutofband(struct socket *,
		     struct tcphdr *, struct mbuf *, int);
void	tcp_xmit_timer(struct tcpcb *, int);
void	tcp_newreno_partial_ack(struct tcpcb *, struct tcphdr *);
void	cc_ack_received(struct tcpcb *tp, struct tcphdr *th,
			    uint16_t nsegs, uint16_t type);
void 	cc_conn_init(struct tcpcb *tp);
void 	cc_post_recovery(struct tcpcb *tp, struct tcphdr *th);
void    cc_ecnpkt_handler(struct tcpcb *tp, struct tcphdr *th, uint8_t iptos);
void	cc_ecnpkt_handler_flags(struct tcpcb *tp, uint16_t flags, uint8_t iptos);
void	cc_cong_signal(struct tcpcb *tp, struct tcphdr *th, uint32_t type);
#ifdef TCP_HHOOK
void	hhook_run_tcp_est_in(struct tcpcb *tp,
			    struct tcphdr *th, struct tcpopt *to);
#endif

int	 tcp_input(struct mbuf **, int *, int);
int	 tcp_autorcvbuf(struct mbuf *, struct tcphdr *, struct socket *,
	    struct tcpcb *, int);
int	 tcp_input_with_port(struct mbuf **, int *, int, uint16_t);
void	tcp_do_segment(struct tcpcb *, struct mbuf *, struct tcphdr *, int,
    int, uint8_t);

int register_tcp_functions(struct tcp_function_block *blk, int wait);
int register_tcp_functions_as_names(struct tcp_function_block *blk,
    int wait, const char *names[], int *num_names);
int register_tcp_functions_as_name(struct tcp_function_block *blk,
    const char *name, int wait);
int deregister_tcp_functions(struct tcp_function_block *blk, bool quiesce,
    bool force);
struct tcp_function_block *find_and_ref_tcp_functions(struct tcp_function_set *fs);
int find_tcp_function_alias(struct tcp_function_block *blk, struct tcp_function_set *fs);
uint32_t tcp_get_srtt(struct tcpcb *tp, int granularity);
void tcp_switch_back_to_default(struct tcpcb *tp);
struct tcp_function_block *
find_and_ref_tcp_fb(struct tcp_function_block *fs);
int tcp_default_ctloutput(struct tcpcb *tp, struct sockopt *sopt);
int tcp_ctloutput_set(struct inpcb *inp, struct sockopt *sopt);
void tcp_log_socket_option(struct tcpcb *tp, uint32_t option_num,
    uint32_t option_val, int err);


extern counter_u64_t tcp_inp_lro_direct_queue;
extern counter_u64_t tcp_inp_lro_wokeup_queue;
extern counter_u64_t tcp_inp_lro_compressed;
extern counter_u64_t tcp_inp_lro_locks_taken;
extern counter_u64_t tcp_extra_mbuf;
extern counter_u64_t tcp_would_have_but;
extern counter_u64_t tcp_comp_total;
extern counter_u64_t tcp_uncomp_total;
extern counter_u64_t tcp_bad_csums;

#ifdef TCP_SAD_DETECTION
/* Various SACK attack thresholds */
extern int32_t tcp_force_detection;
extern int32_t tcp_sad_limit;
extern int32_t tcp_sack_to_ack_thresh;
extern int32_t tcp_sack_to_move_thresh;
extern int32_t tcp_restoral_thresh;
extern int32_t tcp_sad_decay_val;
extern int32_t tcp_sad_pacing_interval;
extern int32_t tcp_sad_low_pps;
extern int32_t tcp_map_minimum;
extern int32_t tcp_attack_on_turns_on_logging;
#endif
extern uint32_t tcp_ack_war_time_window;
extern uint32_t tcp_ack_war_cnt;

uint32_t tcp_maxmtu(struct in_conninfo *, struct tcp_ifcap *);
uint32_t tcp_maxmtu6(struct in_conninfo *, struct tcp_ifcap *);
void	 tcp6_use_min_mtu(struct tcpcb *);
u_int	 tcp_maxseg(const struct tcpcb *);
u_int	 tcp_fixed_maxseg(const struct tcpcb *);
void	 tcp_mss_update(struct tcpcb *, int, int, struct hc_metrics_lite *,
	    struct tcp_ifcap *);
void	 tcp_mss(struct tcpcb *, int);
int	 tcp_mssopt(struct in_conninfo *);
struct tcpcb *
	 tcp_newtcpcb(struct inpcb *, struct tcpcb *);
int	 tcp_default_output(struct tcpcb *);
void	 tcp_state_change(struct tcpcb *, int);
void	 tcp_respond(struct tcpcb *, void *,
	    struct tcphdr *, struct mbuf *, tcp_seq, tcp_seq, uint16_t);
void	 tcp_send_challenge_ack(struct tcpcb *, struct tcphdr *, struct mbuf *);
bool	 tcp_twcheck(struct inpcb *, struct tcpopt *, struct tcphdr *,
	    struct mbuf *, int);
void	 tcp_setpersist(struct tcpcb *);
void	 tcp_record_dsack(struct tcpcb *tp, tcp_seq start, tcp_seq end, int tlp);
struct tcptemp *
	 tcpip_maketemplate(struct inpcb *);
void	 tcpip_fillheaders(struct inpcb *, uint16_t, void *, void *);
void	 tcp_timer_activate(struct tcpcb *, tt_which, u_int);
bool	 tcp_timer_active(struct tcpcb *, tt_which);
void	 tcp_timer_stop(struct tcpcb *);
int	 inp_to_cpuid(struct inpcb *inp);
/*
 * All tcp_hc_* functions are IPv4 and IPv6 (via in_conninfo)
 */
void	 tcp_hc_init(void);
#ifdef VIMAGE
void	 tcp_hc_destroy(void);
#endif
void	 tcp_hc_get(struct in_conninfo *, struct hc_metrics_lite *);
uint32_t tcp_hc_getmtu(struct in_conninfo *);
void	 tcp_hc_updatemtu(struct in_conninfo *, uint32_t);
void	 tcp_hc_update(struct in_conninfo *, struct hc_metrics_lite *);
void 	 cc_after_idle(struct tcpcb *tp);

extern	struct protosw tcp_protosw;		/* shared for TOE */
extern	struct protosw tcp6_protosw;		/* shared for TOE */

uint32_t tcp_new_ts_offset(struct in_conninfo *);
tcp_seq	 tcp_new_isn(struct in_conninfo *);

sackstatus_t
	 tcp_sack_doack(struct tcpcb *, struct tcpopt *, tcp_seq);
int	 tcp_dsack_block_exists(struct tcpcb *);
void	 tcp_update_dsack_list(struct tcpcb *, tcp_seq, tcp_seq);
void	 tcp_update_sack_list(struct tcpcb *tp, tcp_seq rcv_laststart, tcp_seq rcv_lastend);
void	 tcp_clean_dsack_blocks(struct tcpcb *tp);
void	 tcp_clean_sackreport(struct tcpcb *tp);
int	 tcp_sack_adjust(struct tcpcb *tp);
struct sackhole *tcp_sack_output(struct tcpcb *tp, int *sack_bytes_rexmt);
void	 tcp_do_prr_ack(struct tcpcb *, struct tcphdr *, struct tcpopt *, sackstatus_t);
void	 tcp_lost_retransmission(struct tcpcb *, struct tcphdr *);
void	 tcp_sack_partialack(struct tcpcb *, struct tcphdr *);
void	 tcp_free_sackholes(struct tcpcb *tp);
void	 tcp_sack_lost_retransmission(struct tcpcb *, struct tcphdr *);
int	 tcp_newreno(struct tcpcb *, struct tcphdr *);
int	 tcp_compute_pipe(struct tcpcb *);
uint32_t tcp_compute_initwnd(uint32_t);
void	 tcp_sndbuf_autoscale(struct tcpcb *, struct socket *, uint32_t);
int	 tcp_stats_sample_rollthedice(struct tcpcb *tp, void *seed_bytes,
    size_t seed_len);
int tcp_can_enable_pacing(void);
void tcp_decrement_paced_conn(void);
void tcp_change_time_units(struct tcpcb *, int);
void tcp_handle_orphaned_packets(struct tcpcb *);

struct mbuf *
	 tcp_m_copym(struct mbuf *m, int32_t off0, int32_t *plen,
	   int32_t seglimit, int32_t segsize, struct sockbuf *sb, bool hw_tls);

int	tcp_stats_init(void);
void tcp_log_end_status(struct tcpcb *tp, uint8_t status);
#ifdef TCP_REQUEST_TRK
void tcp_req_free_a_slot(struct tcpcb *tp, struct tcp_sendfile_track *ent);
struct tcp_sendfile_track *
tcp_req_find_a_req_that_is_completed_by(struct tcpcb *tp, tcp_seq th_ack, int *ip);
int tcp_req_check_for_comp(struct tcpcb *tp, tcp_seq ack_point);
int
tcp_req_is_entry_comp(struct tcpcb *tp, struct tcp_sendfile_track *ent, tcp_seq ack_point);
struct tcp_sendfile_track *
tcp_req_find_req_for_seq(struct tcpcb *tp, tcp_seq seq);
void
tcp_req_log_req_info(struct tcpcb *tp,
    struct tcp_sendfile_track *req, uint16_t slot,
    uint8_t val, uint64_t offset, uint64_t nbytes);

uint32_t
tcp_estimate_tls_overhead(struct socket *so, uint64_t tls_usr_bytes);
void
tcp_req_alloc_req(struct tcpcb *tp, union tcp_log_userdata *user,
    uint64_t ts);

struct tcp_sendfile_track *
tcp_req_alloc_req_full(struct tcpcb *tp, struct tcp_snd_req *req, uint64_t ts, int rec_dups);


#endif
#ifdef TCP_ACCOUNTING
int tcp_do_ack_accounting(struct tcpcb *tp, struct tcphdr *th, struct tcpopt *to, uint32_t tiwin, int mss);
#endif

static inline void
tcp_lro_features_off(struct tcpcb *tp)
{
	tp->t_flags2 &= ~(TF2_SUPPORTS_MBUFQ|
	    TF2_MBUF_QUEUE_READY|
	    TF2_DONT_SACK_QUEUE|
	    TF2_MBUF_ACKCMP|
	    TF2_MBUF_L_ACKS);
}

static inline void
tcp_fields_to_host(struct tcphdr *th)
{

	th->th_seq = ntohl(th->th_seq);
	th->th_ack = ntohl(th->th_ack);
	th->th_win = ntohs(th->th_win);
	th->th_urp = ntohs(th->th_urp);
}

static inline void
tcp_fields_to_net(struct tcphdr *th)
{

	th->th_seq = htonl(th->th_seq);
	th->th_ack = htonl(th->th_ack);
	th->th_win = htons(th->th_win);
	th->th_urp = htons(th->th_urp);
}

static inline uint16_t
tcp_get_flags(const struct tcphdr *th)
{
        return (((uint16_t)th->th_x2 << 8) | th->th_flags);
}

static inline void
tcp_set_flags(struct tcphdr *th, uint16_t flags)
{
        th->th_x2    = (flags >> 8) & 0x0f;
        th->th_flags = flags & 0xff;
}
#endif /* _KERNEL */

#endif /* _NETINET_TCP_VAR_H_ */