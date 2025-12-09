/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2008-2010 Lawrence Stewart <lstewart@freebsd.org>
 * Copyright (c) 2010 The FreeBSD Foundation
 * All rights reserved.
 *
 * This software was developed by Lawrence Stewart while studying at the Centre
 * for Advanced Internet Architectures, Swinburne University of Technology, made
 * possible in part by a grant from the Cisco University Research Program Fund
 * at Community Foundation Silicon Valley.
 *
 * Portions of this software were developed at the Centre for Advanced
 * Internet Architectures, Swinburne University of Technology, Melbourne,
 * Australia by David Hayes under sponsorship from the FreeBSD Foundation.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _NETINET_CC_CUBIC_H_
#define _NETINET_CC_CUBIC_H_

#include <sys/limits.h>

/* Number of bits of precision for fixed point math calcs. */
#define	CUBIC_SHIFT		8

#define	CUBIC_SHIFT_4		32

/* 0.5 << CUBIC_SHIFT. */
#define	RENO_BETA		128

/* ~0.7 << CUBIC_SHIFT. */
#define	CUBIC_BETA		179

/* ~0.3 << CUBIC_SHIFT. */
#define	ONE_SUB_CUBIC_BETA	77

/* 3 * ONE_SUB_CUBIC_BETA. */
#define	THREE_X_PT3		231

/* (2 << CUBIC_SHIFT) - ONE_SUB_CUBIC_BETA. */
#define	TWO_SUB_PT3		435

/* ~0.4 << CUBIC_SHIFT. */
#define	CUBIC_C_FACTOR		102

/* CUBIC fast convergence factor: (1+beta_cubic)/2. */
#define	CUBIC_FC_FACTOR		217

/* Don't trust s_rtt until this many rtt samples have been taken. */
#define	CUBIC_MIN_RTT_SAMPLES	8

/*
 * (2^21)^3 is long max. Dividing (2^63) by Cubic_C_factor
 * and taking cube-root yields 448845 as the effective useful limit
 */
#define	CUBED_ROOT_MAX_ULONG	448845

/* Flags used in the cubic structure */
#define CUBICFLAG_CONG_EVENT		0x00000001	/* congestion experienced */
#define CUBICFLAG_IN_SLOWSTART		0x00000002	/* in slow start */
#define CUBICFLAG_IN_APPLIMIT		0x00000004	/* application limited */
#define CUBICFLAG_RTO_EVENT		0x00000008	/* RTO experienced */
#define CUBICFLAG_HYSTART_ENABLED	0x00000010	/* Hystart++ is enabled */
#define CUBICFLAG_HYSTART_IN_CSS	0x00000020	/* We are in Hystart++ CSS */
#define CUBICFLAG_IN_TF			0x00000040	/* We are in TCP friendly region */

/* Kernel only bits */
#ifdef _KERNEL
struct cubic {
	/*
	 * CUBIC K in fixed point form with CUBIC_SHIFT worth of precision.
	 * Also means the time period in seconds it takes to increase the
	 * congestion window size at the beginning of the current congestion
	 * avoidance stage to W_max.
	 */
	int64_t		K;
	/* Sum of RTT samples across an epoch in usecs. */
	int64_t		sum_rtt_usecs;
	/* Size of cwnd (in bytes) just before cwnd was reduced in the last congestion event. */
	uint32_t	W_max;
	/* An estimate (in bytes) for the congestion window in the Reno-friendly region */
	uint32_t	W_est;
	/* An estimate (in bytes) for the congestion window in the CUBIC region */
	uint32_t	W_cubic;
	/* The cwnd (in bytes) at the beginning of the current congestion avoidance stage. */
	uint32_t	cwnd_epoch;
	/* various flags */
	uint32_t	flags;
	/* Minimum observed rtt in usecs. */
	int		min_rtt_usecs;
	/* Mean observed rtt between congestion epochs. */
	int		mean_rtt_usecs;
	/* ACKs since last congestion event. */
	int		epoch_ack_count;
	/* Timestamp (in ticks) at which the current CA epoch started. */
	int		t_epoch;
	/* Timestamp (in ticks) at which the previous CA epoch started. */
	int		undo_t_epoch;
	/* Few variables to restore the state after RTO_ERR */
	int64_t		undo_K;
	uint32_t	undo_W_max;
	uint32_t	undo_cwnd_epoch;
	uint32_t css_baseline_minrtt;
	uint32_t css_current_round_minrtt;
	uint32_t css_lastround_minrtt;
	uint32_t css_rttsample_count;
	uint32_t css_entered_at_round;
	uint32_t css_current_round;
	uint32_t css_fas_at_css_entry;
	uint32_t css_lowrtt_fas;
	uint32_t css_last_fas;
};
#endif

/* Userland only bits. */
#ifndef _KERNEL

extern int hz;

/*
 * Implementation based on the formulas in RFC9438.
 *
 */


/*
 * Returns K, the time period in seconds it takes to increase the congestion
 * window size at the beginning of the current congestion avoidance stage to
 * W_max.
 */
static inline float
theoretical_cubic_k(uint32_t wmax_segs, uint32_t cwnd_epoch_segs)
{
	double C;

	C = 0.4;
	if (wmax_segs <= cwnd_epoch_segs)
		return 0.0;

	/*
	 * Figure 2: K = ((W_max - cwnd_epoch) / C)^(1/3)
	 */
	return (pow((wmax_segs - cwnd_epoch_segs) / C, (1.0 / 3.0)) * pow(2, CUBIC_SHIFT));
}

/*
 * Returns the congestion window in segments at time t in seconds based on the
 * cubic increase function, where t is the elapsed time in seconds from the
 * beginning of the current congestion avoidance stage, as described in RFC9438
 * Section 4.2.
 */
static inline unsigned long
theoretical_cubic_cwnd(int ticks_elapsed, uint32_t wmax_segs, uint32_t cwnd_epoch_segs)
{
	double C, t;
	float K;

	C = 0.4;
	t = ticks_elapsed / (double)hz;
	K = theoretical_cubic_k(wmax_segs, cwnd_epoch_segs);

	/*
	 * Figure 1: W_cubic(t) = C * (t - K)^3 + W_max
	 */
	return (C * pow(t - K / pow(2, CUBIC_SHIFT), 3.0) + wmax_segs);
}

/*
 * Returns estimated Reno congestion window in segments.
 */
static inline unsigned long
theoretical_reno_cwnd(int ticks_elapsed, int rtt_ticks, uint32_t wmax_segs)
{

	return (wmax_segs * 0.5 + ticks_elapsed / (float)rtt_ticks);
}

/*
 * Returns an estimate for the congestion window in segments in the
 * Reno-friendly region -- that is, an estimate for the congestion window of
 * Reno, as described in RFC9438 Section 4.3, where:
 * cwnd: Current congestion window in segments.
 * cwnd_prior: Size of cwnd in segments at the time of setting ssthresh most
 *             recently, either upon exiting the first slow start or just before
 *             cwnd was reduced in the last congestion event.
 * W_est: An estimate for the congestion window in segments in the Reno-friendly
 *        region -- that is, an estimate for the congestion window of Reno.
 */
static inline unsigned long
theoretical_tf_cwnd(unsigned long W_est, unsigned long segs_acked, unsigned long cwnd,
    unsigned long cwnd_prior)
{
	float cubic_alpha, cubic_beta;

	/* RFC9438 Section 4.6: The parameter β_cubic SHOULD be set to 0.7. */
	cubic_beta = 0.7;

	if (W_est >= cwnd_prior)
		cubic_alpha = 1.0;
	else
		cubic_alpha = (3.0 * (1.0 - cubic_beta)) / (1.0 + cubic_beta);

	/*
	 * Figure 4: W_est = W_est + α_cubic * segments_acked / cwnd
	 */
	return (W_est + cubic_alpha * segs_acked / cwnd);
}

#endif /* !_KERNEL */

/*
 * Compute the CUBIC K value used in the cwnd calculation, using an
 * implementation mentioned in Figure. 2 of RFC9438.
 * The method used here is adapted from Apple Computer Technical Report #KT-32.
 */
static inline int64_t
cubic_k(uint32_t wmax_segs, uint32_t cwnd_epoch_segs)
{
	int64_t s, K;
	uint16_t p;

	K = s = 0;
	p = 0;

	/* Handle the corner case where W_max <= cwnd_epoch */
	if (wmax_segs <= cwnd_epoch_segs) {
		return 0;
	}

	/* (wmax - cwnd_epoch) / C with CUBIC_SHIFT worth of precision. */
	s = ((wmax_segs - cwnd_epoch_segs) << (2 * CUBIC_SHIFT)) / CUBIC_C_FACTOR;

	/* Rebase s to be between 1 and 1/8 with a shift of CUBIC_SHIFT. */
	while (s >= 256) {
		s >>= 3;
		p++;
	}

	/*
	 * Some magic constants taken from the Apple TR with appropriate
	 * shifts: 275 == 1.072302 << CUBIC_SHIFT, 98 == 0.3812513 <<
	 * CUBIC_SHIFT, 120 == 0.46946116 << CUBIC_SHIFT.
	 */
	K = (((s * 275) >> CUBIC_SHIFT) + 98) -
	    (((s * s * 120) >> CUBIC_SHIFT) >> CUBIC_SHIFT);

	/* Multiply by 2^p to undo the rebasing of s from above. */
	return (K <<= p);
}

/*
 * Compute and return the new cwnd value in bytes using an implementation
 * mentioned in Figure. 1 of RFC9438.
 * Thanks to Kip Macy for help debugging this function.
 *
 * XXXLAS: Characterise bounds for overflow.
 */
static inline uint32_t
cubic_cwnd(int usecs_since_epoch, uint32_t wmax, uint32_t smss, int64_t K)
{
	int64_t cwnd;

	/* K is in fixed point form with CUBIC_SHIFT worth of precision. */

	/* t - K, with CUBIC_SHIFT worth of precision. */
	cwnd = (((int64_t)usecs_since_epoch << CUBIC_SHIFT) - (K * hz * tick)) /
	       (hz * tick);

	if (cwnd > CUBED_ROOT_MAX_ULONG)
		return INT_MAX;
	if (cwnd < -CUBED_ROOT_MAX_ULONG)
		return 0;

	/* (t - K)^3, with CUBIC_SHIFT^3 worth of precision. */
	cwnd *= (cwnd * cwnd);

	/*
	 * Figure 1: C * (t - K)^3 + wmax
	 * The down shift by CUBIC_SHIFT_4 is because cwnd has 4 lots of
	 * CUBIC_SHIFT included in the value. 3 from the cubing of cwnd above,
	 * and an extra from multiplying through by CUBIC_C_FACTOR.
	 */

	cwnd = ((cwnd * CUBIC_C_FACTOR) >> CUBIC_SHIFT_4) * smss + wmax;

	/*
	 * for negative cwnd, limiting to zero as lower bound
	 */
	return (lmax(0,cwnd));
}

/*
 * Compute the "TCP friendly" cwnd by newreno in congestion avoidance state.
 */
static inline uint32_t
tf_cwnd(struct cc_var *ccv)
{
	/* newreno is "TCP friendly" */
	return newreno_cc_cwnd_in_cong_avoid(ccv);
}

#endif /* _NETINET_CC_CUBIC_H_ */