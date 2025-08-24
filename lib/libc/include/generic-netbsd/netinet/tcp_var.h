/*	$NetBSD: tcp_var.h,v 1.198 2022/10/28 05:18:39 ozaki-r Exp $	*/

/*
 * Copyright (C) 1995, 1996, 1997, and 1998 WIDE Project.
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
 * 3. Neither the name of the project nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 *      @(#)COPYRIGHT   1.1 (NRL) 17 January 1995
 *
 * NRL grants permission for redistribution and use in source and binary
 * forms, with or without modification, of the software and documentation
 * created at NRL provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgements:
 *      This product includes software developed by the University of
 *      California, Berkeley and its contributors.
 *      This product includes software developed at the Information
 *      Technology Division, US Naval Research Laboratory.
 * 4. Neither the name of the NRL nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THE SOFTWARE PROVIDED BY NRL IS PROVIDED BY NRL AND CONTRIBUTORS ``AS
 * IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL NRL OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * The views and conclusions contained in the software and documentation
 * are those of the authors and should not be interpreted as representing
 * official policies, either expressed or implied, of the US Naval
 * Research Laboratory (NRL).
 */

/*-
 * Copyright (c) 1997, 1998, 1999, 2001, 2005 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe of the Numerical Aerospace Simulation Facility,
 * NASA Ames Research Center.
 * This code is derived from software contributed to The NetBSD Foundation
 * by Charles M. Hannum.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
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

#if defined(_KERNEL_OPT)
#include "opt_inet.h"
#include "opt_mbuftrace.h"

#endif

/*
 * TCP kernel structures and variables.
 */

#include <sys/callout.h>

#ifdef TCP_SIGNATURE
/*
 * Defines which are needed by the xform_tcp module and tcp_[in|out]put
 * for SADB verification and lookup.
 */
#define	TCP_SIGLEN	16	/* length of computed digest in bytes */
#define	TCP_KEYLEN_MIN	1	/* minimum length of TCP-MD5 key */
#define	TCP_KEYLEN_MAX	80	/* maximum length of TCP-MD5 key */
/*
 * Only a single SA per host may be specified at this time. An SPI is
 * needed in order for the KEY_LOOKUP_SA() lookup to work.
 */
#define	TCP_SIG_SPI	0x1000
#endif /* TCP_SIGNATURE */

/*
 * Tcp+ip header, after ip options removed.
 */
struct tcpiphdr {
	struct ipovly ti_i;		/* overlaid ip structure */
	struct tcphdr ti_t;		/* tcp header */
};
#ifdef CTASSERT
CTASSERT(sizeof(struct tcpiphdr) == 40);
#endif
#define	ti_x1		ti_i.ih_x1
#define	ti_pr		ti_i.ih_pr
#define	ti_len		ti_i.ih_len
#define	ti_src		ti_i.ih_src
#define	ti_dst		ti_i.ih_dst
#define	ti_sport	ti_t.th_sport
#define	ti_dport	ti_t.th_dport
#define	ti_seq		ti_t.th_seq
#define	ti_ack		ti_t.th_ack
#define	ti_x2		ti_t.th_x2
#define	ti_off		ti_t.th_off
#define	ti_flags	ti_t.th_flags
#define	ti_win		ti_t.th_win
#define	ti_sum		ti_t.th_sum
#define	ti_urp		ti_t.th_urp

/*
 * SACK option block.
 */
struct sackblk {
	tcp_seq left;		/* Left edge of sack block. */
	tcp_seq right;		/* Right edge of sack block. */
};

TAILQ_HEAD(sackhead, sackhole);
struct sackhole {
	tcp_seq start;
	tcp_seq end;
	tcp_seq rxmit;

	TAILQ_ENTRY(sackhole) sackhole_q;
};

struct syn_cache;

/*
 * Tcp control block, one per tcp; fields:
 */
struct tcpcb {
	int	t_family;		/* address family on the wire */
	struct ipqehead segq;		/* sequencing queue */
	int	t_segqlen;		/* length of the above */
	callout_t t_timer[TCPT_NTIMERS];/* tcp timers */
	short	t_state;		/* state of this connection */
	short	t_rxtshift;		/* log(2) of rexmt exp. backoff */
	uint32_t t_rxtcur;		/* current retransmit value */
	short	t_dupacks;		/* consecutive dup acks recd */
	/*
	 * t_partialacks:
	 *	<0	not in fast recovery.
	 *	==0	in fast recovery.  has not received partial acks
	 *	>0	in fast recovery.  has received partial acks
	 */
	short	t_partialacks;		/* partials acks during fast rexmit */
	u_short	t_peermss;		/* peer's maximum segment size */
	u_short	t_ourmss;		/* our's maximum segment size */
	u_short t_segsz;		/* current segment size in use */
	char	t_force;		/* 1 if forcing out a byte */
	u_int	t_flags;
#define	TF_ACKNOW	0x0001		/* ack peer immediately */
#define	TF_DELACK	0x0002		/* ack, but try to delay it */
#define	TF_NODELAY	0x0004		/* don't delay packets to coalesce */
#define	TF_NOOPT	0x0008		/* don't use tcp options */
#define	TF_REQ_SCALE	0x0020		/* have/will request window scaling */
#define	TF_RCVD_SCALE	0x0040		/* other side has requested scaling */
#define	TF_REQ_TSTMP	0x0080		/* have/will request timestamps */
#define	TF_RCVD_TSTMP	0x0100		/* a timestamp was received in SYN */
#define	TF_SACK_PERMIT	0x0200		/* other side said I could SACK */
#define	TF_SYN_REXMT	0x0400		/* rexmit timer fired on SYN */
#define	TF_WILL_SACK	0x0800		/* try to use SACK */
#define	TF_REASSEMBLING	0x1000		/* we're busy reassembling */
#define	TF_DEAD		0x2000		/* dead and to-be-released */
#define	TF_PMTUD_PEND	0x4000		/* Path MTU Discovery pending */
#define	TF_ECN_PERMIT	0x10000		/* other side said is ECN-ready */
#define	TF_ECN_SND_CWR	0x20000		/* ECN CWR in queue */
#define	TF_ECN_SND_ECE	0x40000		/* ECN ECE in queue */
#define	TF_SIGNATURE	0x400000	/* require MD5 digests (RFC2385) */


	struct	mbuf *t_template;	/* skeletal packet for transmit */
	struct	inpcb *t_inpcb;		/* back pointer to internet pcb */
	callout_t t_delack_ch;		/* delayed ACK callout */
/*
 * The following fields are used as in the protocol specification.
 * See RFC793, Dec. 1981, page 21.
 */
/* send sequence variables */
	tcp_seq	snd_una;		/* send unacknowledged */
	tcp_seq	snd_nxt;		/* send next */
	tcp_seq	snd_up;			/* send urgent pointer */
	tcp_seq	snd_wl1;		/* window update seg seq number */
	tcp_seq	snd_wl2;		/* window update seg ack number */
	tcp_seq	iss;			/* initial send sequence number */
	u_long	snd_wnd;		/* send window */
/*
 * snd_recover
 * 	it's basically same as the "recover" variable in RFC 2852 (NewReno).
 * 	when entering fast retransmit, it's set to snd_max.
 * 	newreno uses this to detect partial ack.
 * snd_high
 * 	it's basically same as the "send_high" variable in RFC 2852 (NewReno).
 * 	on each RTO, it's set to snd_max.
 * 	newreno uses this to avoid false fast retransmits.
 */
	tcp_seq snd_recover;
	tcp_seq	snd_high;
/* receive sequence variables */
	u_long	rcv_wnd;		/* receive window */
	tcp_seq	rcv_nxt;		/* receive next */
	tcp_seq	rcv_up;			/* receive urgent pointer */
	tcp_seq	irs;			/* initial receive sequence number */
/*
 * Additional variables for this implementation.
 */
/* receive variables */
	tcp_seq	rcv_adv;		/* advertised window */

/*
 * retransmit variables
 *
 * snd_max
 * 	the highest sequence number we've ever sent.
 *	used to recognize retransmits.
 */
	tcp_seq	snd_max;

/* congestion control (for slow start, source quench, retransmit after loss) */
	u_long	snd_cwnd;		/* congestion-controlled window */
	u_long	snd_ssthresh;		/* snd_cwnd size threshold for
					 * for slow start exponential to
					 * linear switch
					 */
/* auto-sizing variables */
	u_int rfbuf_cnt;		/* recv buffer autoscaling byte count */
	uint32_t rfbuf_ts;		/* recv buffer autoscaling timestamp */

/*
 * transmit timing stuff.  See below for scale of srtt and rttvar.
 * "Variance" is actually smoothed difference.
 */
	uint32_t t_rcvtime;		/* time last segment received */
	uint32_t t_rtttime;		/* time we started measuring rtt */
	tcp_seq	t_rtseq;		/* sequence number being timed */
	int32_t	t_srtt;			/* smoothed round-trip time */
	int32_t	t_rttvar;		/* variance in round-trip time */
	uint32_t t_rttmin;		/* minimum rtt allowed */
	u_long	max_sndwnd;		/* largest window peer has offered */

/* out-of-band data */
	char	t_oobflags;		/* have some */
	char	t_iobc;			/* input character */
#define	TCPOOB_HAVEDATA	0x01
#define	TCPOOB_HADDATA	0x02
	short	t_softerror;		/* possible error not yet reported */

/* RFC 1323 variables */
	u_char	snd_scale;		/* window scaling for send window */
	u_char	rcv_scale;		/* window scaling for recv window */
	u_char	request_r_scale;	/* pending window scaling */
	u_char	requested_s_scale;
	u_int32_t ts_recent;		/* timestamp echo data */
	u_int32_t ts_recent_age;	/* when last updated */
	u_int32_t ts_timebase;		/* our timebase */
	tcp_seq	last_ack_sent;

/* RFC 3465 variables */
	u_long	t_bytes_acked;		/* ABC "bytes_acked" parameter */

/* SACK stuff */
#define TCP_SACK_MAX 3
#define TCPSACK_NONE 0
#define TCPSACK_HAVED 1
	u_char rcv_sack_flags;		/* SACK flags. */
	struct sackblk rcv_dsack_block;	/* RX D-SACK block. */
	struct ipqehead timeq;		/* time sequenced queue. */
	struct sackhead snd_holes;	/* TX SACK holes. */
	int	snd_numholes;		/* Number of TX SACK holes. */
	tcp_seq rcv_lastsack;		/* last seq number(+1) sack'd by rcv'r*/
	tcp_seq sack_newdata;		/* New data xmitted in this recovery
					   episode starts at this seq number*/
	tcp_seq snd_fack;		/* FACK TCP.  Forward-most data held by
					   peer. */

/* CUBIC variables */
	ulong snd_cubic_wmax;		/* W_max */
	ulong snd_cubic_wmax_last;	/* Used for fast convergence */
	ulong snd_cubic_ctime;		/* Last congestion time */

/* pointer for syn cache entries*/
	LIST_HEAD(, syn_cache) t_sc;	/* list of entries by this tcb */

/* prediction of next mbuf when using large window sizes */
	struct	mbuf *t_lastm;		/* last mbuf that data was sent from */
	int	t_inoff;		/* data offset in previous mbuf */
	int	t_lastoff;		/* last data address in mbuf chain */
	int	t_lastlen;		/* last length read from mbuf chain */

/* Path-MTU discovery blackhole detection */
	int t_mtudisc;			/* perform mtudisc for this tcb */
/* Path-MTU Discovery Information */
	u_int	t_pmtud_mss_acked;	/* MSS acked, lower bound for MTU */
	u_int	t_pmtud_mtu_sent;	/* MTU used, upper bound for MTU */
	tcp_seq	t_pmtud_th_seq;		/* TCP SEQ from ICMP payload */
	u_int	t_pmtud_nextmtu;	/* Advertised Next-Hop MTU from ICMP */
	u_short	t_pmtud_ip_len;		/* IP length from ICMP payload */
	u_short	t_pmtud_ip_hl;		/* IP header length from ICMP payload */

	uint8_t t_ecn_retries;		/* # of ECN setup retries */
	
	const struct tcp_congctl *t_congctl;	/* per TCB congctl algorithm */

	/* Keepalive per socket */
	u_int	t_keepinit;
	u_int	t_keepidle;
	u_int	t_keepintvl;
	u_int	t_keepcnt;
	u_int	t_maxidle;		/* t_keepcnt * t_keepintvl */

	u_int	t_msl;			/* MSL to use for this connexion */

	/* maintain a few stats per connection: */
	uint32_t t_rcvoopack;	 	/* out-of-order packets received */
	uint32_t t_sndrexmitpack; 	/* retransmit packets sent */
	uint32_t t_sndzerowin;		/* zero-window updates sent */
};

/*
 * Macros to aid ECN TCP.
 */
#define TCP_ECN_ALLOWED(tp)	(tp->t_flags & TF_ECN_PERMIT)

/*
 * Macros to aid SACK/FACK TCP.
 */
#define TCP_SACK_ENABLED(tp)	(tp->t_flags & TF_WILL_SACK)
#define TCP_FACK_FASTRECOV(tp)	\
	(TCP_SACK_ENABLED(tp) && \
	(SEQ_GT(tp->snd_fack, tp->snd_una + tcprexmtthresh * tp->t_segsz)))

#ifdef _KERNEL
/*
 * TCP reassembly queue locks.
 */
static __inline int tcp_reass_lock_try (struct tcpcb *)
	__unused;
static __inline void tcp_reass_unlock (struct tcpcb *)
	__unused;

static __inline int
tcp_reass_lock_try(struct tcpcb *tp)
{
	int s;

	/*
	 * Use splvm() -- we're blocking things that would cause
	 * mbuf allocation.
	 */
	s = splvm();
	if (tp->t_flags & TF_REASSEMBLING) {
		splx(s);
		return (0);
	}
	tp->t_flags |= TF_REASSEMBLING;
	splx(s);
	return (1);
}

static __inline void
tcp_reass_unlock(struct tcpcb *tp)
{
	int s;

	s = splvm();
	KASSERT((tp->t_flags & TF_REASSEMBLING) != 0);
	tp->t_flags &= ~TF_REASSEMBLING;
	splx(s);
}

#ifdef DIAGNOSTIC
#define	TCP_REASS_LOCK(tp)						\
do {									\
	if (tcp_reass_lock_try(tp) == 0) {				\
		printf("%s:%d: tcpcb %p reass already locked\n",	\
		    __FILE__, __LINE__, tp);				\
		panic("tcp_reass_lock");				\
	}								\
} while (/*CONSTCOND*/ 0)
#define	TCP_REASS_LOCK_CHECK(tp)					\
do {									\
	if (((tp)->t_flags & TF_REASSEMBLING) == 0) {			\
		printf("%s:%d: tcpcb %p reass lock not held\n",		\
		    __FILE__, __LINE__, tp);				\
		panic("tcp reass lock check");				\
	}								\
} while (/*CONSTCOND*/ 0)
#else
#define	TCP_REASS_LOCK(tp)	(void) tcp_reass_lock_try((tp))
#define	TCP_REASS_LOCK_CHECK(tp) /* nothing */
#endif

#define	TCP_REASS_UNLOCK(tp)	tcp_reass_unlock((tp))
#endif /* _KERNEL */

/*
 * Queue for delayed ACK processing.
 */
#ifdef _KERNEL
extern int tcp_delack_ticks;
void	tcp_delack(void *);

#define TCP_RESTART_DELACK(tp)						\
	callout_reset(&(tp)->t_delack_ch, tcp_delack_ticks,		\
	    tcp_delack, tp)

#define	TCP_SET_DELACK(tp)						\
do {									\
	if (((tp)->t_flags & TF_DELACK) == 0) {				\
		(tp)->t_flags |= TF_DELACK;				\
		TCP_RESTART_DELACK(tp);					\
	}								\
} while (/*CONSTCOND*/0)

#define	TCP_CLEAR_DELACK(tp)						\
do {									\
	if ((tp)->t_flags & TF_DELACK) {				\
		(tp)->t_flags &= ~TF_DELACK;				\
		callout_stop(&(tp)->t_delack_ch);			\
	}								\
} while (/*CONSTCOND*/0)
#endif /* _KERNEL */

/*
 * Compute the current timestamp for a connection.
 */
#define	TCP_TIMESTAMP(tp)	(tcp_now - (tp)->ts_timebase)

/*
 * Handy way of passing around TCP option info.
 */
struct tcp_opt_info {
	int		ts_present;
	u_int32_t	ts_val;
	u_int32_t	ts_ecr;
	u_int16_t	maxseg;
};

#define	TOF_SIGNATURE	0x0040		/* signature option present */
#define	TOF_SIGLEN	0x0080		/* sigature length valid (RFC2385) */

#define	intotcpcb(ip)	((struct tcpcb *)(ip)->inp_ppcb)
#define	sototcpcb(so)	(intotcpcb(sotoinpcb(so)))

/*
 * See RFC2988 for a discussion of RTO calculation; comments assume
 * familiarity with that document.
 *
 * The smoothed round-trip time and estimated variance are stored as
 * fixed point numbers.  Historically, srtt was scaled by
 * TCP_RTT_SHIFT bits, and rttvar by TCP_RTTVAR_SHIFT bits.  Because
 * the values coincide with the alpha and beta parameters suggested
 * for RTO calculation (1/8 for srtt, 1/4 for rttvar), the combination
 * of computing 1/8 of the new value and transforming it to the
 * fixed-point representation required zero instructions.  However,
 * the storage representations no longer coincide with the alpha/beta
 * shifts; instead, more fractional bits are present.
 *
 * The storage representation of srtt is 1/32 slow ticks, or 1/64 s.
 * (The assumption that a slow tick is 500 ms should not be present in
 * the code.)
 *
 * The storage representation of rttvar is 1/16 slow ticks, or 1/32 s.
 * There may be some confusion about this in the code.
 *
 * For historical reasons, these scales are also used in smoothing the
 * average (smoothed = (1/scale)sample + ((scale-1)/scale)smoothed).
 * This results in alpha of 0.125 and beta of 0.25, following RFC2988
 * section 2.3
 *
 * XXX Change SHIFT values to LGWEIGHT and REP_SHIFT, and adjust
 * the code to use the correct ones.
 */
#define	TCP_RTT_SHIFT		3	/* shift for srtt; 3 bits frac. */
#define	TCP_RTTVAR_SHIFT	2	/* multiplier for rttvar; 2 bits */

/*
 * Compute TCP retransmission timer, following RFC2988.
 * This macro returns a value in slow timeout ticks.
 *
 * Section 2.2 requires that the RTO value be
 *  srtt + max(G, 4*RTTVAR)
 * where G is the clock granularity.
 *
 * This comment has not necessarily been updated for the new storage
 * representation:
 *
 * Because of the way we do the smoothing, srtt and rttvar
 * will each average +1/2 tick of bias.  When we compute
 * the retransmit timer, we want 1/2 tick of rounding and
 * 1 extra tick because of +-1/2 tick uncertainty in the
 * firing of the timer.  The bias will give us exactly the
 * 1.5 tick we need.  But, because the bias is
 * statistical, we have to test that we don't drop below
 * the minimum feasible timer (which is 2 ticks).
 * This macro assumes that the value of 1<<TCP_RTTVAR_SHIFT
 * is the same as the multiplier for rttvar.
 *
 * This macro appears to be wrong; it should be checking rttvar*4 in
 * ticks and making sure we use 1 instead if rttvar*4 rounds to 0.  It
 * appears to be treating srtt as being in the old storage
 * representation, resulting in a factor of 4 extra.
 */
#define	TCP_REXMTVAL(tp) \
	((((tp)->t_srtt >> TCP_RTT_SHIFT) + (tp)->t_rttvar) >> 2)

/*
 * Compute the initial window for slow start.
 */
#define	TCP_INITIAL_WINDOW(iw, segsz) \
	uimin((iw) * (segsz), uimax(2 * (segsz), tcp_init_win_max[(iw)]))

/*
 * TCP statistics.
 * Each counter is an unsigned 64-bit value.
 *
 * Many of these should be kept per connection, but that's inconvenient
 * at the moment.
 */
#define	TCP_STAT_CONNATTEMPT	0	/* connections initiated */
#define	TCP_STAT_ACCEPTS	1	/* connections accepted */
#define	TCP_STAT_CONNECTS	2	/* connections established */
#define	TCP_STAT_DROPS		3	/* connections dropped */
#define	TCP_STAT_CONNDROPS	4	/* embryonic connections dropped */
#define	TCP_STAT_CLOSED		5	/* conn. closed (includes drops) */
#define	TCP_STAT_SEGSTIMED	6	/* segs where we tried to get rtt */
#define	TCP_STAT_RTTUPDATED	7	/* times we succeeded */
#define	TCP_STAT_DELACK		8	/* delayed ACKs sent */
#define	TCP_STAT_TIMEOUTDROP	9	/* conn. dropped in rxmt timeout */
#define	TCP_STAT_REXMTTIMEO	10	/* retransmit timeouts */
#define	TCP_STAT_PERSISTTIMEO	11	/* persist timeouts */
#define	TCP_STAT_KEEPTIMEO	12	/* keepalive timeouts */
#define	TCP_STAT_KEEPPROBE	13	/* keepalive probes sent */
#define	TCP_STAT_KEEPDROPS	14	/* connections dropped in keepalive */
#define	TCP_STAT_PERSISTDROPS	15	/* connections dropped in persist */
#define	TCP_STAT_CONNSDRAINED	16	/* connections drained due to memory
					   shortage */
#define	TCP_STAT_PMTUBLACKHOLE	17	/* PMTUD blackhole detected */
#define	TCP_STAT_SNDTOTAL	18	/* total packets sent */
#define	TCP_STAT_SNDPACK	19	/* data packlets sent */
#define	TCP_STAT_SNDBYTE	20	/* data bytes sent */
#define	TCP_STAT_SNDREXMITPACK	21	/* data packets retransmitted */
#define	TCP_STAT_SNDREXMITBYTE	22	/* data bytes retransmitted */
#define	TCP_STAT_SNDACKS	23	/* ACK-only packets sent */
#define	TCP_STAT_SNDPROBE	24	/* window probes sent */
#define	TCP_STAT_SNDURG		25	/* packets sent with URG only */
#define	TCP_STAT_SNDWINUP	26	/* window update-only packets sent */
#define	TCP_STAT_SNDCTRL	27	/* control (SYN|FIN|RST) packets sent */
#define	TCP_STAT_RCVTOTAL	28	/* total packets received */
#define	TCP_STAT_RCVPACK	29	/* packets received in sequence */
#define	TCP_STAT_RCVBYTE	30	/* bytes received in sequence */
#define	TCP_STAT_RCVBADSUM	31	/* packets received with cksum errs */
#define	TCP_STAT_RCVBADOFF	32	/* packets received with bad offset */
#define	TCP_STAT_RCVMEMDROP	33	/* packets dropped for lack of memory */
#define	TCP_STAT_RCVSHORT	34	/* packets received too short */
#define	TCP_STAT_RCVDUPPACK	35	/* duplicate-only packets received */
#define	TCP_STAT_RCVDUPBYTE	36	/* duplicate-only bytes received */
#define	TCP_STAT_RCVPARTDUPPACK	37	/* packets with some duplicate data */
#define	TCP_STAT_RCVPARTDUPBYTE	38	/* dup. bytes in part-dup. packets */
#define	TCP_STAT_RCVOOPACK	39	/* out-of-order packets received */
#define	TCP_STAT_RCVOOBYTE	40	/* out-of-order bytes received */
#define	TCP_STAT_RCVPACKAFTERWIN 41	/* packets with data after window */
#define	TCP_STAT_RCVBYTEAFTERWIN 42	/* bytes received after window */
#define	TCP_STAT_RCVAFTERCLOSE	43	/* packets received after "close" */
#define	TCP_STAT_RCVWINPROBE	44	/* rcvd window probe packets */
#define	TCP_STAT_RCVDUPACK	45	/* rcvd duplicate ACKs */
#define	TCP_STAT_RCVACKTOOMUCH	46	/* rcvd ACKs for unsent data */
#define	TCP_STAT_RCVACKPACK	47	/* rcvd ACK packets */
#define	TCP_STAT_RCVACKBYTE	48	/* bytes ACKed by rcvd ACKs */
#define	TCP_STAT_RCVWINUPD	49	/* rcvd window update packets */
#define	TCP_STAT_PAWSDROP	50	/* segments dropped due to PAWS */
#define	TCP_STAT_PREDACK	51	/* times hdr predict OK for ACKs */
#define	TCP_STAT_PREDDAT	52	/* times hdr predict OK for data pkts */
#define	TCP_STAT_PCBHASHMISS	53	/* input packets missing PCB hash */
#define	TCP_STAT_NOPORT		54	/* no socket on port */
#define	TCP_STAT_BADSYN		55	/* received ACK for which we have
					   no SYN in compressed state */
#define	TCP_STAT_DELAYED_FREE	56	/* delayed pool_put() of tcpcb */
#define	TCP_STAT_SC_ADDED	57	/* # of sc entries added */
#define	TCP_STAT_SC_COMPLETED	58	/* # of sc connections completed */
#define	TCP_STAT_SC_TIMED_OUT	59	/* # of sc entries timed out */
#define	TCP_STAT_SC_OVERFLOWED	60	/* # of sc drops due to overflow */
#define	TCP_STAT_SC_RESET	61	/* # of sc drops due to RST */
#define	TCP_STAT_SC_UNREACH	62	/* # of sc drops due to ICMP unreach */
#define	TCP_STAT_SC_BUCKETOVERFLOW 63	/* # of sc drops due to bucket ovflow */
#define	TCP_STAT_SC_ABORTED	64	/* # of sc entries aborted (no mem) */
#define	TCP_STAT_SC_DUPESYN	65	/* # of duplicate SYNs received */
#define	TCP_STAT_SC_DROPPED	66	/* # of SYNs dropped (no route/mem) */
#define	TCP_STAT_SC_COLLISIONS	67	/* # of sc hash collisions */
#define	TCP_STAT_SC_RETRANSMITTED 68	/* # of sc retransmissions */
#define	TCP_STAT_SC_DELAYED_FREE 69	/* # of delayed pool_put()s */
#define	TCP_STAT_SELFQUENCH	70	/* # of ENOBUFS we get on output */
#define	TCP_STAT_BADSIG		71	/* # of drops due to bad signature */
#define	TCP_STAT_GOODSIG	72	/* # of packets with good signature */
#define	TCP_STAT_ECN_SHS	73	/* # of successful ECN handshakes */
#define	TCP_STAT_ECN_CE		74	/* # of packets with CE bit */
#define	TCP_STAT_ECN_ECT	75	/* # of packets with ECT(0) bit */

#define	TCP_NSTATS		76

/*
 * Names for TCP sysctl objects.
 */
#define	TCPCTL_RFC1323		1	/* RFC1323 timestamps/scaling */
#define	TCPCTL_SENDSPACE	2	/* default send buffer */
#define	TCPCTL_RECVSPACE	3	/* default recv buffer */
#define	TCPCTL_MSSDFLT		4	/* default seg size */
#define	TCPCTL_SYN_CACHE_LIMIT	5	/* max size of comp. state engine */
#define	TCPCTL_SYN_BUCKET_LIMIT	6	/* max size of hash bucket */
#if 0	/*obsoleted*/
#define	TCPCTL_SYN_CACHE_INTER	7	/* interval of comp. state timer */
#endif
#define	TCPCTL_INIT_WIN		8	/* initial window */
#define	TCPCTL_MSS_IFMTU	9	/* mss from interface, not in_maxmtu */
#define	TCPCTL_SACK		10	/* RFC2018 selective acknowledgement */
#define	TCPCTL_WSCALE		11	/* RFC1323 window scaling */
#define	TCPCTL_TSTAMP		12	/* RFC1323 timestamps */
#if 0	/*obsoleted*/
#define	TCPCTL_COMPAT_42	13	/* 4.2BSD TCP bug work-arounds */
#endif
#define	TCPCTL_CWM		14	/* Congestion Window Monitoring */
#define	TCPCTL_CWM_BURSTSIZE	15	/* burst size allowed by CWM */
#define	TCPCTL_ACK_ON_PUSH	16	/* ACK immediately on PUSH */
#define	TCPCTL_KEEPIDLE		17	/* keepalive idle time */
#define	TCPCTL_KEEPINTVL	18	/* keepalive probe interval */
#define	TCPCTL_KEEPCNT		19	/* keepalive count */
#define	TCPCTL_SLOWHZ		20	/* PR_SLOWHZ (read-only) */
#define	TCPCTL_NEWRENO		21	/* NewReno Congestion Control */
#define TCPCTL_LOG_REFUSED	22	/* Log refused connections */
#if 0	/*obsoleted*/
#define	TCPCTL_RSTRATELIMIT	23	/* RST rate limit */
#endif
#define	TCPCTL_RSTPPSLIMIT	24	/* RST pps limit */
#define	TCPCTL_DELACK_TICKS	25	/* # ticks to delay ACK */
#define	TCPCTL_INIT_WIN_LOCAL	26	/* initial window for local nets */
#define	TCPCTL_IDENT		27	/* rfc 931 identd */
#define	TCPCTL_ACKDROPRATELIMIT	28	/* SYN/RST -> ACK rate limit */
#define	TCPCTL_LOOPBACKCKSUM	29	/* do TCP checksum on loopback */
#define	TCPCTL_STATS		30	/* TCP statistics */
#define	TCPCTL_DEBUG		31	/* TCP debug sockets */
#define	TCPCTL_DEBX		32	/* # of tcp debug sockets */
#define	TCPCTL_DROP		33	/* drop tcp connection */
#define	TCPCTL_MSL		34	/* Max Segment Life */

#ifdef _KERNEL

extern	struct inpcbtable tcbtable;	/* head of queue of active tcpcb's */
extern	const struct pr_usrreqs tcp_usrreqs;

extern	u_int32_t tcp_now;	/* for RFC 1323 timestamps */
extern	int tcp_do_rfc1323;	/* enabled/disabled? */
extern	int tcp_do_sack;	/* SACK enabled/disabled? */
extern	int tcp_do_win_scale;	/* RFC1323 window scaling enabled/disabled? */
extern	int tcp_do_timestamps;	/* RFC1323 timestamps enabled/disabled? */
extern	int tcp_mssdflt;	/* default seg size */
extern	int tcp_minmss;		/* minimal seg size */
extern  int tcp_msl;		/* max segment life */
extern	int tcp_init_win;	/* initial window */
extern	int tcp_init_win_local;	/* initial window for local nets */
extern	int tcp_init_win_max[11];/* max sizes for values of tcp_init_win_* */
extern	int tcp_mss_ifmtu;	/* take MSS from interface, not in_maxmtu */
extern	int tcp_cwm;		/* enable Congestion Window Monitoring */
extern	int tcp_cwm_burstsize;	/* burst size allowed by CWM */
extern	int tcp_ack_on_push;	/* ACK immediately on PUSH */
extern	int tcp_log_refused;	/* log refused connections */
extern	int tcp_do_ecn;		/* TCP ECN enabled/disabled? */
extern	int tcp_ecn_maxretries;	/* Max ECN setup retries */
extern	int tcp_do_rfc1948;	/* ISS by cryptographic hash */
extern int tcp_sack_tp_maxholes;	/* Max holes per connection. */
extern int tcp_sack_globalmaxholes;	/* Max holes per system. */
extern int tcp_sack_globalholes;	/* Number of holes present. */
extern int tcp_do_abc;			/* RFC3465 ABC enabled/disabled? */
extern int tcp_abc_aggressive;		/* 1: L=2*SMSS  0: L=1*SMSS */

extern int tcp_msl_enable;		/* enable TIME_WAIT truncation	*/
extern int tcp_msl_loop;		/* MSL for loopback		*/
extern int tcp_msl_local;		/* MSL for 'local'		*/
extern int tcp_msl_remote;		/* MSL otherwise		*/
extern int tcp_msl_remote_threshold;	/* RTT threshold		*/
extern int tcp_rttlocal;		/* Use RTT to decide who's 'local' */
extern int tcp4_vtw_enable;
extern int tcp6_vtw_enable;
extern int tcp_vtw_was_enabled;
extern int tcp_vtw_entries;

extern	int tcp_rst_ppslim;
extern	int tcp_ackdrop_ppslim;

#ifdef MBUFTRACE
extern	struct mowner tcp_rx_mowner;
extern	struct mowner tcp_tx_mowner;
extern	struct mowner tcp_reass_mowner;
extern	struct mowner tcp_sock_mowner;
extern	struct mowner tcp_sock_rx_mowner;
extern	struct mowner tcp_sock_tx_mowner;
extern	struct mowner tcp_mowner;
#endif

extern int tcp_do_autorcvbuf;
extern int tcp_autorcvbuf_inc;
extern int tcp_autorcvbuf_max;
extern int tcp_do_autosndbuf;
extern int tcp_autosndbuf_inc;
extern int tcp_autosndbuf_max;

struct secasvar;

void	 tcp_canceltimers(struct tcpcb *);
struct tcpcb *
	 tcp_close(struct tcpcb *);
int	 tcp_isdead(struct tcpcb *);
#ifdef INET6
void	 *tcp6_ctlinput(int, const struct sockaddr *, void *);
#endif
void	 *tcp_ctlinput(int, const struct sockaddr *, void *);
int	 tcp_ctloutput(int, struct socket *, struct sockopt *);
struct tcpcb *
	 tcp_disconnect1(struct tcpcb *);
struct tcpcb *
	 tcp_drop(struct tcpcb *, int);
#ifdef TCP_SIGNATURE
int	 tcp_signature_apply(void *, void *, u_int);
struct secasvar *tcp_signature_getsav(struct mbuf *);
int	 tcp_signature(struct mbuf *, struct tcphdr *, int, struct secasvar *,
	    char *);
#endif
void	 tcp_drain(void);
void	 tcp_drainstub(void);
void	 tcp_established(struct tcpcb *);
void	 tcp_init(void);
void	 tcp_init_common(unsigned);
#ifdef INET6
int	 tcp6_input(struct mbuf **, int *, int);
#endif
void	 tcp_input(struct mbuf *, int, int);
u_int	 tcp_hdrsz(struct tcpcb *);
u_long	 tcp_mss_to_advertise(const struct ifnet *, int);
void	 tcp_mss_from_peer(struct tcpcb *, int);
void	 tcp_tcpcb_template(void);
struct tcpcb *
	 tcp_newtcpcb(int, struct inpcb *);
void	 tcp_notify(struct inpcb *, int);
u_int	 tcp_optlen(struct tcpcb *);
int	 tcp_output(struct tcpcb *);
void	 tcp_pulloutofband(struct socket *,
	    struct tcphdr *, struct mbuf *, int);
void	 tcp_quench(struct inpcb *);
void	 tcp_mtudisc(struct inpcb *, int);
#ifdef INET6
void	 tcp6_mtudisc_callback(struct in6_addr *);
#endif

void	tcpipqent_init(void);
struct ipqent *tcpipqent_alloc(void);
void	 tcpipqent_free(struct ipqent *);

int	 tcp_respond(struct tcpcb *, struct mbuf *, struct mbuf *,
	    struct tcphdr *, tcp_seq, tcp_seq, int);
void	 tcp_rmx_rtt(struct tcpcb *);
void	 tcp_setpersist(struct tcpcb *);
#ifdef TCP_SIGNATURE
int	 tcp_signature_compute(struct mbuf *, struct tcphdr *, int, int,
	    int, u_char *, u_int);
#endif
void	 tcp_fasttimo(void);
struct mbuf *
	 tcp_template(struct tcpcb *);
void	 tcp_trace(short, short, struct tcpcb *, struct mbuf *, int);
struct tcpcb *
	 tcp_usrclosed(struct tcpcb *);
void	 tcp_usrreq_init(void);
void	 tcp_xmit_timer(struct tcpcb *, uint32_t);
tcp_seq	 tcp_new_iss(struct tcpcb *);
tcp_seq  tcp_new_iss1(void *, void *, u_int16_t, u_int16_t, size_t);

void	 tcp_sack_init(void);
void	 tcp_new_dsack(struct tcpcb *, tcp_seq, u_int32_t);
void	 tcp_sack_option(struct tcpcb *, const struct tcphdr *,
	    const u_char *, int);
void	 tcp_del_sackholes(struct tcpcb *, const struct tcphdr *);
void	 tcp_free_sackholes(struct tcpcb *);
void	 tcp_sack_adjust(struct tcpcb *tp);
struct sackhole *tcp_sack_output(struct tcpcb *tp, int *sack_bytes_rexmt);
int	 tcp_sack_numblks(const struct tcpcb *);
#define	TCP_SACK_OPTLEN(nblks)	((nblks) * 8 + 2 + 2)

void	 tcp_statinc(u_int);
void	 tcp_statadd(u_int, uint64_t);

int	 tcp_input_checksum(int, struct mbuf *, const struct tcphdr *, int, int,
    int);

int	tcp_dooptions(struct tcpcb *, const u_char *, int,
	    struct tcphdr *, struct mbuf *, int, struct tcp_opt_info *);
#endif

#endif /* !_NETINET_TCP_VAR_H_ */