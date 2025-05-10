/*-
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 2018-2020
 *	Netflix Inc.
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
 *
 */
/**
 * Author: Randall Stewart <rrs@netflix.com>
 */
#ifndef __tcp_ratelimit_h__
#define __tcp_ratelimit_h__

struct m_snd_tag;

#define RL_MIN_DIVISOR 50
#define RL_DEFAULT_DIVISOR 1000

/* Flags on an individual rate */
#define HDWRPACE_INITED 	0x0001
#define HDWRPACE_TAGPRESENT	0x0002
#define HDWRPACE_IFPDEPARTED	0x0004
struct tcp_hwrate_limit_table {
	const struct tcp_rate_set *ptbl;	/* Pointer to parent table */
	struct m_snd_tag *tag;	/* Send tag if needed (chelsio) */
	long	 rate;		/* Rate we get in Bytes per second (Bps) */
	long	 using;		/* How many flows are using this hdwr rate. */
	long	 rs_num_enobufs;
	uint32_t time_between;	/* Time-Gap between packets at this rate */
	uint32_t flags;
};

/* Rateset flags */
#define RS_IS_DEFF      0x0001	/* Its a lagg, do a double lookup */
#define RS_IS_INTF      0x0002	/* Its a plain interface */
#define RS_NO_PRE       0x0004	/* The interfacd has set rates */
#define RS_INT_TBL      0x0010	/*
				 * The table is the internal version
				 * which has special setup requirements.
				 */
#define RS_IS_DEAD      0x0020	/* The RS is dead list */
#define RS_FUNERAL_SCHD 0x0040  /* Is a epoch call scheduled to bury this guy?*/
#define RS_INTF_NO_SUP  0x0100 	/* The interface does not support the ratelimiting */

struct tcp_rate_set {
	struct sysctl_ctx_list sysctl_ctx;
	CK_LIST_ENTRY(tcp_rate_set) next;
	struct ifnet *rs_ifp;
	struct tcp_hwrate_limit_table *rs_rlt;
	uint64_t rs_flows_using;
	uint64_t rs_flow_limit;
	uint32_t rs_if_dunit;
	int rs_rate_cnt;
	int rs_min_seg;
	int rs_highest_valid;
	int rs_lowest_valid;
	int rs_disable;
	int rs_flags;
	struct epoch_context rs_epoch_ctx;
};

CK_LIST_HEAD(head_tcp_rate_set, tcp_rate_set);

/* Request flags */
#define RS_PACING_EXACT_MATCH	0x0001	/* Need an exact match for rate */
#define RS_PACING_GT		0x0002	/* Greater than requested */
#define RS_PACING_GEQ		0x0004	/* Greater than or equal too */
#define RS_PACING_LT		0x0008	/* Less than requested rate */
#define RS_PACING_SUB_OK	0x0010	/* If a rate can't be found get the
					 * next best rate (highest or lowest). */
#ifdef _KERNEL
#ifndef ETHERNET_SEGMENT_SIZE
#define ETHERNET_SEGMENT_SIZE 1514
#endif
#ifdef RATELIMIT
#define DETAILED_RATELIMIT_SYSCTL 1	/*
					 * Undefine this if you don't want
					 * detailed rates to appear in
					 * net.inet.tcp.rl.
					 * With the defintion each rate
					 * shows up in your sysctl tree
					 * this can be big.
					 */
uint64_t inline
tcp_hw_highest_rate(const struct tcp_hwrate_limit_table *rle)
{
	return (rle->ptbl->rs_rlt[rle->ptbl->rs_highest_valid].rate);
}

uint64_t
tcp_hw_highest_rate_ifp(struct ifnet *ifp, struct inpcb *inp);

const struct tcp_hwrate_limit_table *
tcp_set_pacing_rate(struct tcpcb *tp, struct ifnet *ifp,
    uint64_t bytes_per_sec, int flags, int *error, uint64_t *lower_rate);

const struct tcp_hwrate_limit_table *
tcp_chg_pacing_rate(const struct tcp_hwrate_limit_table *crte,
    struct tcpcb *tp, struct ifnet *ifp,
    uint64_t bytes_per_sec, int flags, int *error, uint64_t *lower_rate);
void
tcp_rel_pacing_rate(const struct tcp_hwrate_limit_table *crte,
    struct tcpcb *tp);

uint32_t
tcp_get_pacing_burst_size_w_divisor(struct tcpcb *tp, uint64_t bw, uint32_t segsiz, int can_use_1mss,
    const struct tcp_hwrate_limit_table *te, int *err, int divisor);

void
tcp_rl_log_enobuf(const struct tcp_hwrate_limit_table *rte);

#else
static inline const struct tcp_hwrate_limit_table *
tcp_set_pacing_rate(struct tcpcb *tp, struct ifnet *ifp,
    uint64_t bytes_per_sec, int flags, int *error, uint64_t *lower_rate)
{
	if (error)
		*error = EOPNOTSUPP;
	return (NULL);
}

static inline const struct tcp_hwrate_limit_table *
tcp_chg_pacing_rate(const struct tcp_hwrate_limit_table *crte,
    struct tcpcb *tp, struct ifnet *ifp,
    uint64_t bytes_per_sec, int flags, int *error, uint64_t *lower_rate)
{
	if (error)
		*error = EOPNOTSUPP;
	return (NULL);
}

static inline void
tcp_rel_pacing_rate(const struct tcp_hwrate_limit_table *crte,
    struct tcpcb *tp)
{
	return;
}

static uint64_t inline
tcp_hw_highest_rate(const struct tcp_hwrate_limit_table *rle)
{
	return (0);
}

static uint64_t inline
tcp_hw_highest_rate_ifp(struct ifnet *ifp, struct inpcb *inp)
{
	return (0);
}

static inline uint32_t
tcp_get_pacing_burst_size_w_divisor(struct tcpcb *tp, uint64_t bw, uint32_t segsiz, int can_use_1mss,
   const struct tcp_hwrate_limit_table *te, int *err, int divisor)
{
	/*
	 * We use the google formula to calculate the
	 * TSO size. I.E.
	 * bw < 24Meg
	 *   tso = 2mss
	 * else
	 *   tso = min(bw/(div=1000), 64k)
	 *
	 * Note for these calculations we ignore the
	 * packet overhead (enet hdr, ip hdr and tcp hdr).
	 * We only get the google formula when we have
	 * divisor = 1000, which is the default for now.
	 */
	uint64_t bytes;
	uint32_t new_tso, min_tso_segs;

	/* It can't be zero */
	if ((divisor == 0) ||
	    (divisor < RL_MIN_DIVISOR)) {
		bytes = bw / RL_DEFAULT_DIVISOR;
	} else
		bytes = bw / divisor;
	/* We can't ever send more than 65k in a TSO */
	if (bytes > 0xffff) {
		bytes = 0xffff;
	}
	/* Round up */
	new_tso = (bytes + segsiz - 1) / segsiz;
	if (can_use_1mss)
		min_tso_segs = 1;
	else
		min_tso_segs = 2;
	if (new_tso < min_tso_segs)
		new_tso = min_tso_segs;
	new_tso *= segsiz;
	return (new_tso);
}

/* Do nothing if RATELIMIT is not defined */
static inline void
tcp_rl_log_enobuf(const struct tcp_hwrate_limit_table *rte)
{
}

#endif

/*
 * Given a b/w and a segsiz, and optional hardware
 * rate limit, return the ideal size to burst
 * out at once. Note the parameter can_use_1mss
 * dictates if the transport will tolerate a 1mss
 * limit, if not it will bottom out at 2mss (think
 * delayed ack).
 */
static inline uint32_t
tcp_get_pacing_burst_size(struct tcpcb *tp, uint64_t bw, uint32_t segsiz, int can_use_1mss,
			  const struct tcp_hwrate_limit_table *te, int *err)
{

	return (tcp_get_pacing_burst_size_w_divisor(tp, bw, segsiz,
						    can_use_1mss,
						    te, err, 0));
}

#endif
#endif