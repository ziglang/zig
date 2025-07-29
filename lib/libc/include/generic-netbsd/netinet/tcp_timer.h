/*	$NetBSD: tcp_timer.h,v 1.30 2019/08/06 15:48:18 riastradh Exp $	*/

/*-
 * Copyright (c) 2001, 2005 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe of Wasabi Systems, Inc.
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
 *	@(#)tcp_timer.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NETINET_TCP_TIMER_H_
#define _NETINET_TCP_TIMER_H_

/*
 * Definitions of the TCP timers.  These timers are counted
 * down PR_SLOWHZ times a second.
 */
#define	TCPT_NTIMERS	4

#define	TCPT_REXMT	0		/* retransmit */
#define	TCPT_PERSIST	1		/* retransmit persistance */
#define	TCPT_KEEP	2		/* keep alive */
#define	TCPT_2MSL	3		/* 2*msl quiet time timer */

/*
 * The TCPT_REXMT timer is used to force retransmissions.
 * The TCP has the TCPT_REXMT timer set whenever segments
 * have been sent for which ACKs are expected but not yet
 * received.  If an ACK is received which advances tp->snd_una,
 * then the retransmit timer is cleared (if there are no more
 * outstanding segments) or reset to the base value (if there
 * are more ACKs expected).  Whenever the retransmit timer goes off,
 * we retransmit one unacknowledged segment, and do a backoff
 * on the retransmit timer.
 *
 * The TCPT_PERSIST timer is used to keep window size information
 * flowing even if the window goes shut.  If all previous transmissions
 * have been acknowledged (so that there are no retransmissions in progress),
 * and the window is too small to bother sending anything, then we start
 * the TCPT_PERSIST timer.  When it expires, if the window is nonzero,
 * we go to transmit state.  Otherwise, at intervals send a single byte
 * into the peer's window to force him to update our window information.
 * We do this at most as often as TCPT_PERSMIN time intervals,
 * but no more frequently than the current estimate of round-trip
 * packet time.  The TCPT_PERSIST timer is cleared whenever we receive
 * a window update from the peer.
 *
 * The TCPT_KEEP timer is used to keep connections alive.  If an
 * connection is idle (no segments received) for TCPTV_KEEP_INIT amount of time,
 * but not yet established, then we drop the connection.  Once the connection
 * is established, if the connection is idle for TCPTV_KEEP_IDLE time
 * (and keepalives have been enabled on the socket), we begin to probe
 * the connection.  We force the peer to send us a segment by sending:
 *	<SEQ=SND.UNA-1><ACK=RCV.NXT><CTL=ACK>
 * This segment is (deliberately) outside the window, and should elicit
 * an ack segment in response from the peer.  If, despite the TCPT_KEEP
 * initiated segments we cannot elicit a response from a peer in TCPT_MAXIDLE
 * amount of time probing, then we drop the connection.
 */

/*
 * Time constants.
 * All TCPTV_* constants are in units of slow ticks (typically 500 ms).
 */
#define	TCPTV_MSL	( 30*PR_SLOWHZ)		/* max seg lifetime (hah!) */
#define	TCPTV_SRTTBASE	0			/* base roundtrip time;
						   if 0, no idea yet */
#define	TCPTV_SRTTDFLT	(  3*PR_SLOWHZ)		/* assumed RTT if no info */

#define	TCPTV_PERSMIN	(  5*PR_SLOWHZ)		/* retransmit persistance */
#define	TCPTV_PERSMAX	( 60*PR_SLOWHZ)		/* maximum persist interval */

#define	TCPTV_KEEP_INIT	( 75*PR_SLOWHZ)		/* initial connect keep alive */
#define	TCPTV_KEEP_IDLE	(120*60*PR_SLOWHZ)	/* dflt time before probing */
#define	TCPTV_KEEPINTVL	( 75*PR_SLOWHZ)		/* default probe interval */
#define	TCPTV_KEEPCNT	8			/* max probes before drop */

#define	TCPTV_MIN	(  1*PR_SLOWHZ)		/* minimum allowable value */
#define	TCPTV_REXMTMAX	( 64*PR_SLOWHZ)		/* max allowable REXMT value */

#define	TCP_LINGERTIME	120			/* linger at most 2 minutes */

#define	TCP_MAXRXTSHIFT	12			/* maximum retransmits */

/* Acks are delayed for 1 second; constant is in fast ticks. */
#define	TCP_DELACK_TICKS (hz / PR_FASTHZ)	/* time to delay ACK */

#ifdef	TCPTIMERS
const char *tcptimers[] =
    { "REXMT", "PERSIST", "KEEP", "2MSL" };
#endif

/*
 * Init, arm, disarm, and test TCP timers.
 */
#define	TCP_TIMER_INIT(tp, timer)					\
	callout_setfunc(&(tp)->t_timer[(timer)],			\
	    tcp_timer_funcs[(timer)], (tp))

/*
 * nticks is given in units of slow timeouts,
 * typically 500 ms (with PR_SLOWHZ at 2).
 */
#define	TCP_TIMER_ARM(tp, timer, nticks)				\
	callout_schedule(&(tp)->t_timer[(timer)],			\
	    (nticks) * (hz / PR_SLOWHZ))

#define	TCP_TIMER_DISARM(tp, timer)					\
	callout_stop(&(tp)->t_timer[(timer)])

#define	TCP_TIMER_ISARMED(tp, timer)					\
	callout_active(&(tp)->t_timer[(timer)])

#define	TCP_TIMER_MAXTICKS						      \
	(INT_MAX / (hz / PR_SLOWHZ))

#define	TCP_MAXMSL							      \
	(TCP_TIMER_MAXTICKS / 2)

/*
 * Force a time value to be in a certain range.
 */
#define	TCPT_RANGESET(tv, value, tvmin, tvmax) { \
	(tv) = (value); \
	if ((tv) < (tvmin)) \
		(tv) = (tvmin); \
	if ((tv) > (tvmax)) \
		(tv) = (tvmax); \
}

#ifdef _KERNEL
typedef void (*tcp_timer_func_t)(void *);

extern const tcp_timer_func_t tcp_timer_funcs[TCPT_NTIMERS];

extern u_int tcp_keepinit;		/* time before initial connection times out */
extern u_int tcp_keepidle;		/* time before keepalive probes begin */
extern u_int tcp_keepintvl;		/* time between keepalive probes */
extern u_int tcp_keepcnt;		/* number of keepalives, 0=infty */
extern int tcp_maxpersistidle;		/* max idle time in persist */
extern int tcp_ttl;			/* time to live for TCP segs */
extern const int tcp_backoff[];

void	tcp_timer_init(void);
void	tcp_slowtimo_init(void);
#endif

#endif /* !_NETINET_TCP_TIMER_H_ */