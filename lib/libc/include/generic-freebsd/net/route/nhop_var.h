/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2020 Alexander V. Chernikov
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

/*
 * This header file contains private definitions for nexthop routing.
 *
 * Header is not intended to be included by the code external to the
 * routing subsystem.
 */

#ifndef	_NET_ROUTE_NHOP_VAR_H_
#define	_NET_ROUTE_NHOP_VAR_H_

MALLOC_DECLARE(M_NHOP);

/* define nhop hash table */
struct nhop_priv;
CHT_SLIST_DEFINE(nhops, struct nhop_priv);
/* produce hash value for an object */
#define	nhops_hash_obj(_obj)	hash_priv(_obj)
/* compare two objects */
#define	nhops_cmp(_one, _two)	cmp_priv(_one, _two)
/* next object accessor */
#define	nhops_next(_obj)	(_obj)->nh_next

/* define multipath hash table */
struct nhgrp_priv;
CHT_SLIST_DEFINE(nhgroups, struct nhgrp_priv);

struct nh_control {
	struct nhops_head	nh_head;	/* hash table head */
	struct bitmask_head	nh_idx_head;	/* nhop index head */
	struct nhgroups_head	gr_head;	/* nhgrp hash table head */
	struct rwlock		ctl_lock;	/* overall ctl lock */
	struct rib_head		*ctl_rh;	/* pointer back to rnh */
	struct epoch_context	ctl_epoch_ctx;	/* epoch ctl helper */
};

#define	NHOPS_WLOCK(ctl)	rw_wlock(&(ctl)->ctl_lock)
#define	NHOPS_RLOCK(ctl)	rw_rlock(&(ctl)->ctl_lock)
#define	NHOPS_WUNLOCK(ctl)	rw_wunlock(&(ctl)->ctl_lock)
#define	NHOPS_RUNLOCK(ctl)	rw_runlock(&(ctl)->ctl_lock)
#define	NHOPS_LOCK_INIT(ctl)	rw_init(&(ctl)->ctl_lock, "nhop_ctl")
#define	NHOPS_LOCK_DESTROY(ctl)	rw_destroy(&(ctl)->ctl_lock)
#define	NHOPS_WLOCK_ASSERT(ctl)	rw_assert(&(ctl)->ctl_lock, RA_WLOCKED)

/* Control plane-only nhop data */
struct nhop_object;
struct nhop_priv {
	/* nhop lookup comparison start */
	uint8_t			nh_upper_family;/* address family of the lookup */
	uint8_t			nh_neigh_family;/* neighbor address family */
	uint16_t		nh_type;	/* nexthop type */
	uint32_t		rt_flags;	/* routing flags for the control plane */
	uint32_t		nh_expire;	/* path expiration time */
	uint32_t		nh_uidx;	/* userland-provided index */
	/* nhop lookup comparison end */
	uint32_t		nh_idx;		/* nexthop index */
	uint32_t		nh_fibnum;	/* nexthop fib */
	void			*cb_func;	/* function handling additional rewrite caps */
	u_int			nh_refcnt;	/* number of references, refcount(9)  */
	u_int			nh_linked;	/* refcount(9), == 2 if linked to the list */
	int			nh_finalized;	/* non-zero if finalized() was called */
	uint8_t			nh_origin;	/* protocol that originated the nexthop */
	struct nhop_object	*nh;		/* backreference to the dataplane nhop */
	struct nh_control	*nh_control;	/* backreference to the rnh */
	struct nhop_priv	*nh_next;	/* hash table membership */
	struct vnet		*nh_vnet;	/* vnet nhop belongs to */
	struct epoch_context	nh_epoch_ctx;	/* epoch data for nhop */
};

#define	NH_PRIV_END_CMP	(__offsetof(struct nhop_priv, nh_idx))

#define	NH_IS_PINNED(_nh)	((!NH_IS_NHGRP(_nh)) && \
				((_nh)->nh_priv->rt_flags & RTF_PINNED))
#define	NH_IS_LINKED(_nh)	((_nh)->nh_priv->nh_idx != 0)

/* nhop.c */
struct nhop_priv *find_nhop(struct nh_control *ctl,
    const struct nhop_priv *nh_priv);
int link_nhop(struct nh_control *ctl, struct nhop_priv *nh_priv);
struct nhop_priv *unlink_nhop(struct nh_control *ctl, struct nhop_priv *nh_priv);

/* nhop_ctl.c */
int cmp_priv(const struct nhop_priv *_one, const struct nhop_priv *_two);

#endif