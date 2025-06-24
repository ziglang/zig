/*	$NetBSD: if_stats.h,v 1.3 2021/06/29 21:19:58 riastradh Exp $	*/

/*-
 * Copyright (c) 2020 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe.
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

#ifndef _NET_IF_STATS_H_
#define _NET_IF_STATS_H_

#include <net/net_stats.h>

/*
 * Interface statistics.  All values are unsigned 64-bit.
 */
typedef enum {
	if_ipackets		= 0,	/* packets received on interface */
	if_ierrors		= 1,	/* input errors on interface */
	if_opackets		= 2,	/* packets sent on interface */
	if_oerrors		= 3,	/* output errors on interface */
	if_collisions		= 4,	/* collisions on csma interfaces */
	if_ibytes		= 5,	/* total number of octets received */
	if_obytes		= 6,	/* total number of octets sent */
	if_imcasts		= 7,	/* packets received via multicast */
	if_omcasts		= 8,	/* packets sent via multicast */
	if_iqdrops		= 9,	/* dropped on input, this interface */
	if_noproto		= 10,	/* destined for unsupported protocol */

	IF_NSTATS		= 11
} if_stat_t;

#ifdef _KERNEL

#define	IF_STAT_GETREF(ifp)	_NET_STAT_GETREF((ifp)->if_stats)
#define	IF_STAT_PUTREF(ifp)	_NET_STAT_PUTREF((ifp)->if_stats)

static inline void
if_statinc(ifnet_t *ifp, if_stat_t x)
{
	_NET_STATINC((ifp)->if_stats, x);
}

static inline void
if_statinc_ref(net_stat_ref_t nsr, if_stat_t x)
{
	_NET_STATINC_REF(nsr, x);
}

static inline void
if_statdec(ifnet_t *ifp, if_stat_t x)
{
	_NET_STATDEC((ifp)->if_stats, x);
}

static inline void
if_statdec_ref(net_stat_ref_t nsr, if_stat_t x)
{
	_NET_STATDEC_REF(nsr, x);
}

static inline void
if_statadd(ifnet_t *ifp, if_stat_t x, uint64_t v)
{
	_NET_STATADD((ifp)->if_stats, x, v);
}

static inline void
if_statadd_ref(net_stat_ref_t nsr, if_stat_t x, uint64_t v)
{
	_NET_STATADD_REF(nsr, x, v);
}

static inline void
if_statadd2(ifnet_t *ifp, if_stat_t x1, uint64_t v1, if_stat_t x2, uint64_t v2)
{
	net_stat_ref_t _nsr_ = IF_STAT_GETREF(ifp);
	_NET_STATADD_REF(_nsr_, x1, v1);
	_NET_STATADD_REF(_nsr_, x2, v2);
	IF_STAT_PUTREF(ifp);
}

static inline void
if_statsub(ifnet_t *ifp, if_stat_t x, uint64_t v)
{
	_NET_STATSUB((ifp)->if_stats, x, v);
}

static inline void
if_statsub_ref(net_stat_ref_t nsr, if_stat_t x, uint64_t v)
{
	_NET_STATSUB_REF(nsr, x, v);
}

void	if_stats_init(ifnet_t *);
void	if_stats_fini(ifnet_t *);
void	if_stats_to_if_data(ifnet_t *, struct if_data *, bool);

#endif /* _KERNEL */

#endif /* !_NET_IF_STATS_H_ */