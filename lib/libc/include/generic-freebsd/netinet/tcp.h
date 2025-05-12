/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1986, 1993
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
 *	@(#)tcp.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NETINET_TCP_H_
#define _NETINET_TCP_H_

#include <sys/cdefs.h>
#include <sys/types.h>

#if __BSD_VISIBLE

typedef	u_int32_t tcp_seq;

#define tcp6_seq	tcp_seq	/* for KAME src sync over BSD*'s */
#define tcp6hdr		tcphdr	/* for KAME src sync over BSD*'s */

/*
 * TCP header.
 * Per RFC 793, September, 1981.
 */
struct tcphdr {
	u_short	th_sport;		/* source port */
	u_short	th_dport;		/* destination port */
	tcp_seq	th_seq;			/* sequence number */
	tcp_seq	th_ack;			/* acknowledgement number */
#if BYTE_ORDER == LITTLE_ENDIAN
	u_char	th_x2:4,		/* upper 4 (reserved) flags */
		th_off:4;		/* data offset */
#endif
#if BYTE_ORDER == BIG_ENDIAN
	u_char	th_off:4,		/* data offset */
		th_x2:4;		/* upper 4 (reserved) flags */
#endif
	u_char	th_flags;
#define	TH_FIN	0x01
#define	TH_SYN	0x02
#define	TH_RST	0x04
#define	TH_PUSH	0x08
#define	TH_ACK	0x10
#define	TH_URG	0x20
#define	TH_ECE	0x40
#define	TH_CWR	0x80
#define	TH_AE	0x100			/* maps into th_x2 */
#define	TH_RES3	0x200
#define	TH_RES2	0x400
#define	TH_RES1	0x800
#define	TH_FLAGS	(TH_FIN|TH_SYN|TH_RST|TH_PUSH|TH_ACK|TH_URG|TH_ECE|TH_CWR)
#define	PRINT_TH_FLAGS	"\20\1FIN\2SYN\3RST\4PUSH\5ACK\6URG\7ECE\10CWR\11AE"

	u_short	th_win;			/* window */
	u_short	th_sum;			/* checksum */
	u_short	th_urp;			/* urgent pointer */
};

#define	PADTCPOLEN(len)		((((len) / 4) + !!((len) % 4)) * 4)

#define	TCPOPT_EOL		0
#define	   TCPOLEN_EOL			1
#define	TCPOPT_PAD		0		/* padding after EOL */
#define	   TCPOLEN_PAD			1
#define	TCPOPT_NOP		1
#define	   TCPOLEN_NOP			1
#define	TCPOPT_MAXSEG		2
#define    TCPOLEN_MAXSEG		4
#define TCPOPT_WINDOW		3
#define    TCPOLEN_WINDOW		3
#define TCPOPT_SACK_PERMITTED	4
#define    TCPOLEN_SACK_PERMITTED	2
#define TCPOPT_SACK		5
#define	   TCPOLEN_SACKHDR		2
#define    TCPOLEN_SACK			8	/* 2*sizeof(tcp_seq) */
#define TCPOPT_TIMESTAMP	8
#define    TCPOLEN_TIMESTAMP		10
#define    TCPOLEN_TSTAMP_APPA		(TCPOLEN_TIMESTAMP+2) /* appendix A */
#define	TCPOPT_SIGNATURE	19		/* Keyed MD5: RFC 2385 */
#define	   TCPOLEN_SIGNATURE		18
#define	TCPOPT_FAST_OPEN	34
#define	   TCPOLEN_FAST_OPEN_EMPTY	2

#define	MAX_TCPOPTLEN		40	/* Absolute maximum TCP options len */

/* Miscellaneous constants */
#define	MAX_SACK_BLKS	6	/* Max # SACK blocks stored at receiver side */
#define	TCP_MAX_SACK	4	/* MAX # SACKs sent in any segment */

/*
 * The default maximum segment size (MSS) to be used for new TCP connections
 * when path MTU discovery is not enabled.
 *
 * RFC879 derives the default MSS from the largest datagram size hosts are
 * minimally required to handle directly or through IP reassembly minus the
 * size of the IP and TCP header.  With IPv6 the minimum MTU is specified
 * in RFC2460.
 *
 * For IPv4 the MSS is 576 - sizeof(struct tcpiphdr)
 * For IPv6 the MSS is IPV6_MMTU - sizeof(struct ip6_hdr) - sizeof(struct tcphdr)
 *
 * We use explicit numerical definition here to avoid header pollution.
 */
#define	TCP_MSS		536
#define	TCP6_MSS	1220

/*
 * Limit the lowest MSS we accept for path MTU discovery and the TCP SYN MSS
 * option.  Allowing low values of MSS can consume significant resources and
 * be used to mount a resource exhaustion attack.
 * Connections requesting lower MSS values will be rounded up to this value
 * and the IP_DF flag will be cleared to allow fragmentation along the path.
 *
 * See tcp_subr.c tcp_minmss SYSCTL declaration for more comments.  Setting
 * it to "0" disables the minmss check.
 *
 * The default value is fine for TCP across the Internet's smallest official
 * link MTU (256 bytes for AX.25 packet radio).  However, a connection is very
 * unlikely to come across such low MTU interfaces these days (anno domini 2003).
 */
#define	TCP_MINMSS 216

#define	TCP_MAXWIN	65535	/* largest value for (unscaled) window */
#define	TTCP_CLIENT_SND_WND	4096	/* dflt send window for T/TCP client */

#define TCP_MAX_WINSHIFT	14	/* maximum window shift */

#define TCP_MAXBURST		4	/* maximum segments in a burst */

#define TCP_MAXHLEN	(0xf<<2)	/* max length of header in bytes */
#define TCP_MAXOLEN	(TCP_MAXHLEN - sizeof(struct tcphdr))
					/* max space left for options */

#define TCP_FASTOPEN_MIN_COOKIE_LEN	4	/* Per RFC7413 */
#define TCP_FASTOPEN_MAX_COOKIE_LEN	16	/* Per RFC7413 */
#define TCP_FASTOPEN_PSK_LEN		16	/* Same as TCP_FASTOPEN_KEY_LEN */
#endif /* __BSD_VISIBLE */

/*
 * User-settable options (used with setsockopt).  These are discrete
 * values and are not masked together.  Some values appear to be
 * bitmasks for historical reasons.
 */
#define	TCP_NODELAY	1	/* don't delay send to coalesce packets */
#if __BSD_VISIBLE
#define	TCP_MAXSEG	2	/* set maximum segment size */
#define TCP_NOPUSH	4	/* don't push last block of write */
#define TCP_NOOPT	8	/* don't use TCP options */
#define TCP_MD5SIG	16	/* use MD5 digests (RFC2385) */
#define	TCP_INFO	32	/* retrieve tcp_info structure */
#define	TCP_STATS	33	/* retrieve stats blob structure */
#define	TCP_LOG		34	/* configure event logging for connection */
#define	TCP_LOGBUF	35	/* retrieve event log for connection */
#define	TCP_LOGID	36	/* configure log ID to correlate connections */
#define	TCP_LOGDUMP	37	/* dump connection log events to device */
#define	TCP_LOGDUMPID	38	/* dump events from connections with same ID to
				   device */
#define	TCP_TXTLS_ENABLE 39	/* TLS framing and encryption for transmit */
#define	TCP_TXTLS_MODE	40	/* Transmit TLS mode */
#define	TCP_RXTLS_ENABLE 41	/* TLS framing and encryption for receive */
#define	TCP_RXTLS_MODE	42	/* Receive TLS mode */
#define	TCP_IWND_NB	43	/* Override initial window (units: bytes) */
#define	TCP_IWND_NSEG	44	/* Override initial window (units: MSS segs) */
#ifdef _KERNEL
#define	TCP_USE_DDP	45	/* Use direct data placement for so_rcvbuf */
#endif
#define	TCP_LOGID_CNT	46	/* get number of connections with the same ID */
#define	TCP_LOG_TAG	47	/* configure tag for grouping logs */
#define	TCP_USER_LOG	48	/* userspace log event */
#define	TCP_CONGESTION	64	/* get/set congestion control algorithm */
#define	TCP_CCALGOOPT	65	/* get/set cc algorithm specific options */
#define	TCP_MAXUNACKTIME 68	/* maximum time without making progress (sec) */
#define	TCP_MAXPEAKRATE 69	/* maximum peak rate allowed (kbps) */
#define TCP_IDLE_REDUCE 70	/* Reduce cwnd on idle input */
#define TCP_REMOTE_UDP_ENCAPS_PORT 71	/* Enable TCP over UDP tunneling via the specified port */
#define TCP_DELACK  	72	/* socket option for delayed ack */
#define TCP_FIN_IS_RST 73	/* A fin from the peer is treated has a RST */
#define TCP_LOG_LIMIT  74	/* Limit to number of records in tcp-log */
#define TCP_SHARED_CWND_ALLOWED 75 	/* Use of a shared cwnd is allowed */
#define TCP_PROC_ACCOUNTING 76	/* Do accounting on tcp cpu usage and counts */
#define TCP_USE_CMP_ACKS 77 	/* The transport can handle the Compressed mbuf acks */
#define	TCP_PERF_INFO	78	/* retrieve accounting counters */
#define	TCP_LRD		79	/* toggle Lost Retransmission Detection for A/B testing */
#define	TCP_KEEPINIT	128	/* N, time to establish connection */
#define	TCP_KEEPIDLE	256	/* L,N,X start keeplives after this period */
#define	TCP_KEEPINTVL	512	/* L,N interval between keepalives */
#define	TCP_KEEPCNT	1024	/* L,N number of keepalives before close */
#define	TCP_FASTOPEN	1025	/* enable TFO / was created via TFO */
#define	TCP_PCAP_OUT	2048	/* number of output packets to keep */
#define	TCP_PCAP_IN	4096	/* number of input packets to keep */
#define TCP_FUNCTION_BLK 8192	/* Set the tcp function pointers to the specified stack */
#define TCP_FUNCTION_ALIAS 8193	/* Get the current tcp function pointer name alias */
/* Options for Rack and BBR */
#define	TCP_REUSPORT_LB_NUMA   1026	/* set listen socket numa domain */
#define TCP_RACK_MBUF_QUEUE   1050 /* Do we allow mbuf queuing if supported */
#define TCP_RACK_PROP	      1051 /* Not used */
#define TCP_RACK_TLP_REDUCE   1052 /* RACK TLP cwnd reduction (bool) */
#define TCP_RACK_PACE_REDUCE  1053 /* RACK Pacingv reduction factor (divisor) */
#define TCP_RACK_PACE_MAX_SEG 1054 /* Max TSO size we will send  */
#define TCP_RACK_PACE_ALWAYS  1055 /* Use the always pace method */
#define TCP_RACK_PROP_RATE    1056 /* Not used */
#define TCP_RACK_PRR_SENDALOT 1057 /* Allow PRR to send more than one seg */
#define TCP_RACK_MIN_TO       1058 /* Minimum time between rack t-o's in ms */
#define TCP_RACK_EARLY_RECOV  1059 /* Not used */
#define TCP_RACK_EARLY_SEG    1060 /* If early recovery max segments */
#define TCP_RACK_REORD_THRESH 1061 /* RACK reorder threshold (shift amount) */
#define TCP_RACK_REORD_FADE   1062 /* Does reordering fade after ms time */
#define TCP_RACK_TLP_THRESH   1063 /* RACK TLP theshold i.e. srtt+(srtt/N) */
#define TCP_RACK_PKT_DELAY    1064 /* RACK added ms i.e. rack-rtt + reord + N */
#define TCP_RACK_TLP_INC_VAR  1065 /* Does TLP include rtt variance in t-o */
#define TCP_BBR_IWINTSO	      1067 /* Initial TSO window for BBRs first sends */
#define TCP_BBR_RECFORCE      1068 /* Enter recovery force out a segment disregard pacer no longer valid */
#define TCP_BBR_STARTUP_PG    1069 /* Startup pacing gain */
#define TCP_BBR_DRAIN_PG      1070 /* Drain pacing gain */
#define TCP_BBR_RWND_IS_APP   1071 /* Rwnd limited is considered app limited */
#define TCP_BBR_PROBE_RTT_INT 1072 /* How long in useconds between probe-rtt */
#define TCP_BBR_ONE_RETRAN    1073 /* Is only one segment allowed out during retran */
#define TCP_BBR_STARTUP_LOSS_EXIT 1074	/* Do we exit a loss during startup if not 20% incr */
#define TCP_BBR_USE_LOWGAIN   1075 /* lower the gain in PROBE_BW enable */
#define TCP_BBR_LOWGAIN_THRESH 1076 /* Unused after 2.3 morphs to TSLIMITS >= 2.3 */
#define TCP_BBR_TSLIMITS 1076	   /* Do we use experimental Timestamp limiting for our algo */
#define TCP_BBR_LOWGAIN_HALF  1077 /* Unused after 2.3 */
#define TCP_BBR_PACE_OH        1077 /* Reused in 4.2 for pacing overhead setting */
#define TCP_BBR_LOWGAIN_FD    1078 /* Unused after 2.3 */
#define TCP_BBR_HOLD_TARGET 1078	/* For 4.3 on */
#define TCP_BBR_USEDEL_RATE   1079 /* Enable use of delivery rate for loss recovery */
#define TCP_BBR_MIN_RTO       1080 /* Min RTO in milliseconds */
#define TCP_BBR_MAX_RTO	      1081 /* Max RTO in milliseconds */
#define TCP_BBR_REC_OVER_HPTS 1082 /* Recovery override htps settings 0/1/3 */
#define TCP_BBR_UNLIMITED     1083 /* Not used before 2.3 and morphs to algorithm >= 2.3 */
#define TCP_BBR_ALGORITHM     1083 /* What measurement algo does BBR use netflix=0, google=1 */
#define TCP_BBR_DRAIN_INC_EXTRA 1084 /* Does the 3/4 drain target include the extra gain */
#define TCP_BBR_STARTUP_EXIT_EPOCH 1085 /* what epoch gets us out of startup */
#define TCP_BBR_PACE_PER_SEC   1086
#define TCP_BBR_PACE_DEL_TAR   1087
#define TCP_BBR_PACE_SEG_MAX   1088
#define TCP_BBR_PACE_SEG_MIN   1089
#define TCP_BBR_PACE_CROSS     1090
#define TCP_RACK_IDLE_REDUCE_HIGH 1092  /* Reduce the highest cwnd seen to IW on idle */
#define TCP_RACK_MIN_PACE      1093 	/* Do we enforce rack min pace time */
#define TCP_RACK_MIN_PACE_SEG  1094	/* If so what is the seg threshould */
#define TCP_RACK_GP_INCREASE   1094	/* After 4.1 its the GP increase in older rack */
#define TCP_RACK_TLP_USE       1095
#define TCP_BBR_ACK_COMP_ALG   1096 	/* Not used */
#define TCP_BBR_TMR_PACE_OH    1096	/* Recycled in 4.2 */
#define TCP_BBR_EXTRA_GAIN     1097
#define TCP_RACK_DO_DETECTION  1097	/* Recycle of extra gain for rack, attack detection */
#define TCP_BBR_RACK_RTT_USE   1098	/* what RTT should we use 0, 1, or 2? */
#define TCP_BBR_RETRAN_WTSO    1099
#define TCP_DATA_AFTER_CLOSE   1100
#define TCP_BBR_PROBE_RTT_GAIN 1101
#define TCP_BBR_PROBE_RTT_LEN  1102
#define TCP_BBR_SEND_IWND_IN_TSO 1103	/* Do we burst out whole iwin size chunks at start? */
#define TCP_BBR_USE_RACK_RR	 1104	/* Do we use the rack rapid recovery for pacing rxt's */
#define TCP_BBR_USE_RACK_CHEAT TCP_BBR_USE_RACK_RR /* Compat. */
#define TCP_BBR_HDWR_PACE      1105	/* Enable/disable hardware pacing */
#define TCP_BBR_UTTER_MAX_TSO  1106	/* Do we enforce an utter max TSO size */
#define TCP_BBR_EXTRA_STATE    1107	/* Special exit-persist catch up */
#define TCP_BBR_FLOOR_MIN_TSO  1108     /* The min tso size */
#define TCP_BBR_MIN_TOPACEOUT  1109	/* Do we suspend pacing until */
#define TCP_BBR_TSTMP_RAISES   1110	/* Can a timestamp measurement raise the b/w */
#define TCP_BBR_POLICER_DETECT 1111	/* Turn on/off google mode policer detection */
#define TCP_BBR_RACK_INIT_RATE 1112	/* Set an initial pacing rate for when we have no b/w in kbits per sec */
#define TCP_RACK_RR_CONF	1113 /* Rack rapid recovery configuration control*/
#define TCP_RACK_CHEAT_NOT_CONF_RATE TCP_RACK_RR_CONF
#define TCP_RACK_GP_INCREASE_CA   1114	/* GP increase for Congestion Avoidance */
#define TCP_RACK_GP_INCREASE_SS   1115	/* GP increase for Slow Start */
#define TCP_RACK_GP_INCREASE_REC  1116	/* GP increase for Recovery */
#define TCP_RACK_FORCE_MSEG	1117	/* Override to use the user set max-seg value */
#define TCP_RACK_PACE_RATE_CA  1118 /* Pacing rate for Congestion Avoidance */
#define TCP_RACK_PACE_RATE_SS  1119 /* Pacing rate for Slow Start */
#define TCP_RACK_PACE_RATE_REC  1120 /* Pacing rate for Recovery */
#define TCP_NO_PRR         	1122 /* If pacing, don't use prr  */
#define TCP_RACK_NONRXT_CFG_RATE 1123 /* In recovery does a non-rxt use the cfg rate */
#define TCP_SHARED_CWND_ENABLE   1124 	/* Use a shared cwnd if allowed */
#define TCP_TIMELY_DYN_ADJ       1125 /* Do we attempt dynamic multipler adjustment with timely. */
#define TCP_RACK_NO_PUSH_AT_MAX 1126 /* For timely do not push if we are over max rtt */
#define TCP_RACK_PACE_TO_FILL 1127 /* If we are not in recovery, always pace to fill the cwnd in 1 RTT */
#define TCP_SHARED_CWND_TIME_LIMIT 1128 /* we should limit to low time values the scwnd life */
#define TCP_RACK_PROFILE 1129	/* Select a profile that sets multiple options */
#define TCP_HDWR_RATE_CAP 1130 /* Allow hardware rates to cap pacing rate */
#define TCP_PACING_RATE_CAP 1131 /* Highest rate allowed in pacing in bytes per second (uint64_t) */
#define TCP_HDWR_UP_ONLY 1132	/* Allow the pacing rate to climb but not descend (with the exception of fill-cw */
#define TCP_RACK_ABC_VAL 1133	/* Set a local ABC value different then the system default */
#define TCP_REC_ABC_VAL 1134	/* Do we use the ABC value for recovery or the override one from sysctl  */
#define TCP_RACK_MEASURE_CNT 1135 /* How many measurements are required in GP pacing */
#define TCP_DEFER_OPTIONS 1136 /* Defer options until the proper number of measurements occur, does not defer TCP_RACK_MEASURE_CNT */
#define TCP_FAST_RSM_HACK 1137	/* Not used in modern stacks */
#define TCP_RACK_PACING_BETA 1138	/* Changing the beta for pacing */
#define TCP_RACK_PACING_BETA_ECN 1139	/* Changing the beta for ecn with pacing */
#define TCP_RACK_TIMER_SLOP 1140	/* Set or get the timer slop used */
#define TCP_RACK_DSACK_OPT 1141		/* How do we setup rack timer DSACK options bit 1/2 */
#define TCP_RACK_ENABLE_HYSTART 1142	/* Do we allow hystart in the CC modules */
#define TCP_RACK_SET_RXT_OPTIONS 1143	/* Set the bits in the retransmit options */
#define TCP_RACK_HI_BETA 1144 /* Turn on/off high beta */
#define TCP_RACK_SPLIT_LIMIT 1145	/* Set a split limit for split allocations */
#define TCP_RACK_PACING_DIVISOR 1146 /* Pacing divisor given to rate-limit code for burst sizing */
#define TCP_RACK_PACE_MIN_SEG 1147	/* Pacing min seg size rack will use */
#define TCP_RACK_DGP_IN_REC 1148	/* Do we use full DGP in recovery? */
#define TCP_RXT_CLAMP 1149 /* Do we apply a threshold to rack so if excess rxt clamp cwnd? */
#define TCP_HYBRID_PACING   1150	/* Hybrid pacing enablement */
#define TCP_PACING_DND	    1151	/* When pacing with rr_config=3 can sacks disturb us */

/* Start of reserved space for third-party user-settable options. */
#define	TCP_VENDOR	SO_VENDOR

#define	TCP_CA_NAME_MAX	16	/* max congestion control name length */

#define	TCPI_OPT_TIMESTAMPS	0x01
#define	TCPI_OPT_SACK		0x02
#define	TCPI_OPT_WSCALE		0x04
#define	TCPI_OPT_ECN		0x08
#define	TCPI_OPT_TOE		0x10
#define	TCPI_OPT_TFO		0x20
#define	TCPI_OPT_ACE		0x40

/* Maximum length of log ID. */
#define TCP_LOG_ID_LEN	64

/* TCP accounting counters */
#define TCP_NUM_PROC_COUNTERS 11
#define TCP_NUM_CNT_COUNTERS 13

/* Must match counter array sizes in tcpcb */
struct tcp_perf_info {
	uint64_t	tcp_cnt_counters[TCP_NUM_CNT_COUNTERS];
	uint64_t	tcp_proc_time[TCP_NUM_CNT_COUNTERS];
	uint64_t	timebase;	/* timebase for tcp_proc_time */
	uint8_t		tb_is_stable;	/* timebase is stable/invariant */
};

/*
 * The TCP_INFO socket option comes from the Linux 2.6 TCP API, and permits
 * the caller to query certain information about the state of a TCP
 * connection.  We provide an overlapping set of fields with the Linux
 * implementation, but since this is a fixed size structure, room has been
 * left for growth.  In order to maximize potential future compatibility with
 * the Linux API, the same variable names and order have been adopted, and
 * padding left to make room for omitted fields in case they are added later.
 *
 * XXX: This is currently an unstable ABI/API, in that it is expected to
 * change.
 */
struct tcp_info {
	u_int8_t	tcpi_state;		/* TCP FSM state. */
	u_int8_t	__tcpi_ca_state;
	u_int8_t	__tcpi_retransmits;
	u_int8_t	__tcpi_probes;
	u_int8_t	__tcpi_backoff;
	u_int8_t	tcpi_options;		/* Options enabled on conn. */
	u_int8_t	tcpi_snd_wscale:4,	/* RFC1323 send shift value. */
			tcpi_rcv_wscale:4;	/* RFC1323 recv shift value. */

	u_int32_t	tcpi_rto;		/* Retransmission timeout (usec). */
	u_int32_t	__tcpi_ato;
	u_int32_t	tcpi_snd_mss;		/* Max segment size for send. */
	u_int32_t	tcpi_rcv_mss;		/* Max segment size for receive. */

	u_int32_t	__tcpi_unacked;
	u_int32_t	__tcpi_sacked;
	u_int32_t	__tcpi_lost;
	u_int32_t	__tcpi_retrans;
	u_int32_t	__tcpi_fackets;

	/* Times; measurements in usecs. */
	u_int32_t	__tcpi_last_data_sent;
	u_int32_t	__tcpi_last_ack_sent;	/* Also unimpl. on Linux? */
	u_int32_t	tcpi_last_data_recv;	/* Time since last recv data. */
	u_int32_t	__tcpi_last_ack_recv;

	/* Metrics; variable units. */
	u_int32_t	__tcpi_pmtu;
	u_int32_t	__tcpi_rcv_ssthresh;
	u_int32_t	tcpi_rtt;		/* Smoothed RTT in usecs. */
	u_int32_t	tcpi_rttvar;		/* RTT variance in usecs. */
	u_int32_t	tcpi_snd_ssthresh;	/* Slow start threshold. */
	u_int32_t	tcpi_snd_cwnd;		/* Send congestion window. */
	u_int32_t	__tcpi_advmss;
	u_int32_t	__tcpi_reordering;

	u_int32_t	__tcpi_rcv_rtt;
	u_int32_t	tcpi_rcv_space;		/* Advertised recv window. */

	/* FreeBSD extensions to tcp_info. */
	u_int32_t	tcpi_snd_wnd;		/* Advertised send window. */
	u_int32_t	tcpi_snd_bwnd;		/* No longer used. */
	u_int32_t	tcpi_snd_nxt;		/* Next egress seqno */
	u_int32_t	tcpi_rcv_nxt;		/* Next ingress seqno */
	u_int32_t	tcpi_toe_tid;		/* HWTID for TOE endpoints */
	u_int32_t	tcpi_snd_rexmitpack;	/* Retransmitted packets */
	u_int32_t	tcpi_rcv_ooopack;	/* Out-of-order packets */
	u_int32_t	tcpi_snd_zerowin;	/* Zero-sized windows sent */

	/* Accurate ECN counters. */
	u_int32_t	tcpi_delivered_ce;
	u_int32_t	tcpi_received_ce;		/* # of CE marks received */
	u_int32_t	__tcpi_delivered_e1_bytes;
	u_int32_t	__tcpi_delivered_e0_bytes;
	u_int32_t	__tcpi_delivered_ce_bytes;
	u_int32_t	__tcpi_received_e1_bytes;
	u_int32_t	__tcpi_received_e0_bytes;
	u_int32_t	__tcpi_received_ce_bytes;

	u_int32_t	tcpi_total_tlp;		/* tail loss probes sent */
	u_int64_t	tcpi_total_tlp_bytes;	/* tail loss probe bytes sent */

	u_int32_t	tcpi_snd_una;		/* Unacked seqno sent */
	u_int32_t	tcpi_snd_max;		/* Highest seqno sent */
	u_int32_t	tcpi_rcv_numsacks;	/* Distinct SACK blks present */
	u_int32_t	tcpi_rcv_adv;		/* Peer advertised window */
	u_int32_t	tcpi_dupacks;		/* Consecutive dup ACKs recvd */

	/* Padding to grow without breaking ABI. */
	u_int32_t	__tcpi_pad[10];		/* Padding. */
};

/*
 * If this structure is provided when setting the TCP_FASTOPEN socket
 * option, and the enable member is non-zero, a subsequent connect will use
 * pre-shared key (PSK) mode using the provided key.
 */
struct tcp_fastopen {
	int enable;
	uint8_t psk[TCP_FASTOPEN_PSK_LEN];
};
#endif
#define TCP_FUNCTION_NAME_LEN_MAX 32

struct tcp_function_set {
	char function_set_name[TCP_FUNCTION_NAME_LEN_MAX];
	uint32_t pcbcnt;
};

/* TLS modes for TCP_TXTLS_MODE */
#define	TCP_TLS_MODE_NONE	0
#define	TCP_TLS_MODE_SW		1
#define	TCP_TLS_MODE_IFNET	2
#define	TCP_TLS_MODE_TOE	3

/*
 * TCP Control message types
 */
#define	TLS_SET_RECORD_TYPE	1
#define	TLS_GET_RECORD		2

/*
 * TCP log user opaque
 */
struct tcp_snd_req {
	uint64_t timestamp;
	uint64_t start;
	uint64_t end;
	uint32_t flags;
};

union tcp_log_userdata {
	struct tcp_snd_req tcp_req;
};

struct tcp_log_user {
	uint32_t type;
	uint32_t subtype;
	union tcp_log_userdata data;
};

/* user types, i.e. apps */
#define TCP_LOG_USER_HTTPD	1

/* user subtypes */
#define TCP_LOG_HTTPD_TS	1	/* client timestamp */
#define TCP_LOG_HTTPD_TS_REQ	2	/* client timestamp and request info */

/* HTTPD REQ flags */
#define TCP_LOG_HTTPD_RANGE_START	0x0001
#define TCP_LOG_HTTPD_RANGE_END		0x0002

/* Flags for hybrid pacing */
#define TCP_HYBRID_PACING_CU		0x0001		/* Enable catch-up mode */
#define TCP_HYBRID_PACING_DTL		0x0002		/* Enable Detailed logging */
#define TCP_HYBRID_PACING_CSPR		0x0004		/* A client suggested rate is present  */
#define TCP_HYBRID_PACING_H_MS		0x0008		/* A client hint for maxseg is present  */
#define TCP_HYBRID_PACING_ENABLE	0x0010		/* We are enabling hybrid pacing else disable */
#define TCP_HYBRID_PACING_S_MSS		0x0020		/* Clent wants us to set the mss overriding gp est in CU */
#define TCP_HYBRID_PACING_SETMSS	0x1000		/* Internal flag that tellsus we set the mss on this entry */
#define TCP_HYBRID_PACING_WASSET	0x2000		/* We init to this to know if a hybrid command was issued */


struct tcp_hybrid_req {
	struct tcp_snd_req req;
	uint64_t cspr;
	uint32_t hint_maxseg;
	uint32_t hybrid_flags;
};

/*
 * TCP specific variables of interest for tp->t_stats stats(9) accounting.
 */
#define	VOI_TCP_TXPB		0 /* Transmit payload bytes */
#define	VOI_TCP_RETXPB		1 /* Retransmit payload bytes */
#define	VOI_TCP_FRWIN		2 /* Foreign receive window */
#define	VOI_TCP_LCWIN		3 /* Local congesiton window */
#define	VOI_TCP_RTT		4 /* Round trip time */
#define	VOI_TCP_CSIG		5 /* Congestion signal */
#define	VOI_TCP_GPUT		6 /* Goodput */
#define	VOI_TCP_CALCFRWINDIFF	7 /* Congestion avoidance LCWIN - FRWIN */
#define	VOI_TCP_GPUT_ND		8 /* Goodput normalised delta */
#define	VOI_TCP_ACKLEN		9 /* Average ACKed bytes per ACK */
#define VOI_TCP_PATHRTT		10 /* The path RTT based on ACK arrival */

#define TCP_REUSPORT_LB_NUMA_NODOM	(-2) /* remove numa binding */
#define TCP_REUSPORT_LB_NUMA_CURDOM	(-1) /* bind to current domain */

#endif /* !_NETINET_TCP_H_ */