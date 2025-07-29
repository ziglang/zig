#ifndef __rack_bbr_common_h__
#define __rack_bbr_common_h__
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

/* Common defines and such used by both RACK and BBR */
/* Special values for mss accounting array */
#define TCP_MSS_ACCT_JUSTRET 0
#define TCP_MSS_ACCT_SNDACK  1
#define TCP_MSS_ACCT_PERSIST 2
#define TCP_MSS_ACCT_ATIMER  60
#define TCP_MSS_ACCT_INPACE  61
#define TCP_MSS_ACCT_LATE    62
#define TCP_MSS_SMALL_SIZE_OFF 63	/* Point where small sizes enter */
#define TCP_MSS_ACCT_SIZE    70
#define TCP_MSS_SMALL_MAX_SIZE_DIV (TCP_MSS_ACCT_SIZE - TCP_MSS_SMALL_SIZE_OFF)

#define DUP_ACK_THRESHOLD 3

/* Magic flags for tracing progress events */
#define PROGRESS_DROP   1
#define PROGRESS_UPDATE 2
#define PROGRESS_CLEAR  3
#define PROGRESS_START  4

/* codes for just-return */
#define CTF_JR_SENT_DATA    0
#define CTF_JR_CWND_LIMITED 1
#define CTF_JR_RWND_LIMITED 2
#define CTF_JR_APP_LIMITED  3
#define CTF_JR_ASSESSING    4
#define CTF_JR_PERSISTS     5
#define CTF_JR_PRR	    6

/* Compat. */
#define BBR_JR_SENT_DATA CTF_JR_SENT_DATA
#define BBR_JR_CWND_LIMITED CTF_JR_CWND_LIMITED
#define BBR_JR_RWND_LIMITED CTF_JR_RWND_LIMITED
#define BBR_JR_APP_LIMITED CTF_JR_APP_LIMITED
#define BBR_JR_ASSESSING CTF_JR_ASSESSING
#define BBR_JR_PERSISTS CTF_JR_PERSISTS
#define BBR_JR_PRR CTF_JR_PRR

/* RTT sample methods */
#define USE_RTT_HIGH 0
#define USE_RTT_LOW  1
#define USE_RTT_AVG  2

#define PACE_MAX_IP_BYTES 65536
#define USECS_IN_SECOND 1000000
#define MSEC_IN_SECOND 1000
#define MS_IN_USEC 1000
#define USEC_TO_MSEC(x) (x / MS_IN_USEC)
#define TCP_TS_OVERHEAD 12		/* Overhead of having Timestamps on */

/* Bits per second in bytes per second */
#define FORTY_EIGHT_MBPS 6000000 /* 48 megabits in bytes */
#define THIRTY_MBPS 3750000 /* 30 megabits in bytes */
#define TWENTY_THREE_MBPS 2896000 /* 23 megabits in bytes */
#define FIVETWELVE_MBPS 64000000 /* 512 megabits in bytes */
#define ONE_POINT_TWO_MEG 150000 /* 1.2 megabits in bytes */

#ifdef _KERNEL
/* We have only 7 bits in rack so assert its true */
CTASSERT((PACE_TMR_MASK & 0x80) == 0);
int ctf_do_queued_segments(struct tcpcb *tp, int have_pkt);
uint32_t ctf_outstanding(struct tcpcb *tp);
uint32_t ctf_flight_size(struct tcpcb *tp, uint32_t rc_sacked);
int
_ctf_drop_checks(struct tcpopt *to, struct mbuf *m, struct tcphdr *th,
    struct tcpcb *tp, int32_t *tlenp,
    int32_t *thf, int32_t *drop_hdrlen, int32_t *ret_val,
    uint32_t *ts, uint32_t *cnt);
void ctf_ack_war_checks(struct tcpcb *tp, uint32_t *ts, uint32_t *cnt);
#define ctf_drop_checks(a, b, c, d, e, f, g, h) _ctf_drop_checks(a, b, c, d, e, f, g, h, NULL, NULL)

void
__ctf_do_dropafterack(struct mbuf *m, struct tcpcb *tp,
      struct tcphdr *th, int32_t thflags, int32_t tlen,
      int32_t *ret_val, uint32_t *ts, uint32_t *cnt);

#define ctf_do_dropafterack(a, b, c, d, e, f) __ctf_do_dropafterack(a, b, c, d, e, f, NULL, NULL)

void
ctf_do_dropwithreset(struct mbuf *m, struct tcpcb *tp,
	struct tcphdr *th, int32_t rstreason, int32_t tlen);
void
ctf_do_drop(struct mbuf *m, struct tcpcb *tp);

int
__ctf_process_rst(struct mbuf *m, struct tcphdr *th,
      struct socket *so, struct tcpcb *tp, uint32_t *ts, uint32_t *cnt);
#define ctf_process_rst(m, t, s, p) __ctf_process_rst(m, t, s, p, NULL, NULL)

void
ctf_challenge_ack(struct mbuf *m, struct tcphdr *th,
    struct tcpcb *tp, uint8_t iptos, int32_t * ret_val);

int
ctf_ts_check(struct mbuf *m, struct tcphdr *th,
    struct tcpcb *tp, int32_t tlen, int32_t thflags, int32_t * ret_val);

int
ctf_ts_check_ac(struct tcpcb *tp, int32_t thflags);

void
ctf_calc_rwin(struct socket *so, struct tcpcb *tp);

void
ctf_do_dropwithreset_conn(struct mbuf *m, struct tcpcb *tp, struct tcphdr *th,
    int32_t rstreason, int32_t tlen);

uint32_t
ctf_fixed_maxseg(struct tcpcb *tp);

void
ctf_log_sack_filter(struct tcpcb *tp, int num_sack_blks, struct sackblk *sack_blocks);

uint32_t
ctf_decay_count(uint32_t count, uint32_t decay_percentage);

int32_t
ctf_progress_timeout_check(struct tcpcb *tp, bool log);

#endif
#endif