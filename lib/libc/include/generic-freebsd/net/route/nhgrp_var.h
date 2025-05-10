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
 * This header file contains private definitions for the nexthop groups.
 *
 * Header is not intended to be included by the code external to the
 * routing subsystem.
 */

#ifndef _NET_ROUTE_NHGRP_VAR_H_
#define	_NET_ROUTE_NHGRP_VAR_H_

/* nhgrp hash definition */
/* produce hash value for an object */
#define	mpath_hash_obj(_obj)	(hash_nhgrp(_obj))
/* compare two objects */
#define	mpath_cmp(_one, _two)	(cmp_nhgrp(_one, _two))
/* next object accessor */
#define	mpath_next(_obj)	(_obj)->nhg_priv_next

struct nhgrp_priv {
	uint32_t		nhg_idx;
	uint32_t		nhg_uidx;
	uint8_t			nhg_nh_count;	/* number of items in nh_weights */
	uint8_t			nhg_origin;	/* protocol which created the group */
	uint8_t			nhg_spare[2];
	u_int			nhg_refcount;	/* use refcount */
	u_int			nhg_linked;	/* refcount(9), == 2 if linked to the list */
	struct nh_control	*nh_control;	/* parent control structure */
	struct nhgrp_priv	*nhg_priv_next;
	struct nhgrp_object	*nhg;
	struct epoch_context	nhg_epoch_ctx;	/* epoch data for nhop */
	struct weightened_nhop	nhg_nh_weights[0];
};

#define	_NHGRP_PRIV(_src)	 (&(_src)->nhops[(_src)->nhg_size])
#define	NHGRP_PRIV(_src)	 ((struct nhgrp_priv *)_NHGRP_PRIV(_src))
#define	NHGRP_PRIV_CONST(_src)	 ((const struct nhgrp_priv *)_NHGRP_PRIV(_src))

/* nhgrp.c */
bool nhgrp_ctl_alloc_default(struct nh_control *ctl, int malloc_flags);
struct nhgrp_priv *find_nhgrp(struct nh_control *ctl, const struct nhgrp_priv *key);
int link_nhgrp(struct nh_control *ctl, struct nhgrp_priv *grp_priv);
struct nhgrp_priv *unlink_nhgrp(struct nh_control *ctl, struct nhgrp_priv *key);

#endif