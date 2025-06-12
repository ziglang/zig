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
 * This header file contains public functions and structures used for
 * routing table manipulations.
 */

#ifndef	_NET_ROUTE_ROUTE_CTL_H_
#define	_NET_ROUTE_ROUTE_CTL_H_

struct rib_head *rt_tables_get_rnh_safe(uint32_t table, sa_family_t family);

struct rib_cmd_info {
	uint8_t			rc_cmd;		/* RTM_ADD|RTM_DEL|RTM_CHANGE */
	uint8_t			spare[3];
	uint32_t		rc_nh_weight;	/* new nhop weight */
	struct rtentry		*rc_rt;		/* Target entry */
	struct nhop_object	*rc_nh_old;	/* Target nhop OR mpath */
	struct nhop_object	*rc_nh_new;	/* Target nhop OR mpath */
};

struct route_nhop_data {
	union {
		struct nhop_object *rnd_nhop;
		struct nhgrp_object *rnd_nhgrp;
	};
	uint32_t rnd_weight;
};

int rib_add_route_px(uint32_t fibnum, struct sockaddr *dst, int plen,
    struct route_nhop_data *rnd, int op_flags, struct rib_cmd_info *rc);
int rib_del_route_px(uint32_t fibnum, struct sockaddr *dst, int plen,
    rib_filter_f_t *filter_func, void *filter_arg, int op_flags,
    struct rib_cmd_info *rc);
int rib_del_route_px_gw(uint32_t fibnum, struct sockaddr *dst, int plen,
    const struct sockaddr *gw, int op_flags, struct rib_cmd_info *rc);

/* operation flags */
#define	RTM_F_CREATE	0x01
#define	RTM_F_EXCL	0x02
#define	RTM_F_REPLACE	0x04
#define	RTM_F_APPEND	0x08
#define	RTM_F_FORCE	0x10

int rib_add_route(uint32_t fibnum, struct rt_addrinfo *info,
  struct rib_cmd_info *rc);
int rib_del_route(uint32_t fibnum, struct rt_addrinfo *info,
  struct rib_cmd_info *rc);
int rib_change_route(uint32_t fibnum, struct rt_addrinfo *info,
  struct rib_cmd_info *rc);
int rib_action(uint32_t fibnum, int action, struct rt_addrinfo *info,
  struct rib_cmd_info *rc);
int rib_match_gw(const struct rtentry *rt, const struct nhop_object *nh,
    void *_data);
int rib_handle_ifaddr_info(uint32_t fibnum, int cmd, struct rt_addrinfo *info);

int rib_add_default_route(uint32_t fibnum, int family, struct ifnet *ifp,
    struct sockaddr *gw, struct rib_cmd_info *rc);

typedef void route_notification_t(const struct rib_cmd_info *rc, void *);
void rib_decompose_notification(const struct rib_cmd_info *rc,
    route_notification_t *cb, void *cbdata);

int rib_add_redirect(u_int fibnum, struct sockaddr *dst,
  struct sockaddr *gateway, struct sockaddr *author, struct ifnet *ifp,
  int flags, int expire_sec);

/* common flags for the functions below */
#define	RIB_FLAG_WLOCK		0x01	/* Need exclusive rnh lock */
#define	RIB_FLAG_LOCKED		0x02	/* Do not explicitly acquire rnh lock */

enum rib_walk_hook {
	RIB_WALK_HOOK_PRE,	/* Hook is called before iteration */
	RIB_WALK_HOOK_POST,	/* Hook is called after iteration */
};
typedef int rib_walktree_f_t(struct rtentry *, void *);
typedef void rib_walk_hook_f_t(struct rib_head *rnh, enum rib_walk_hook stage,
    void *arg);
void rib_walk(uint32_t fibnum, int af, bool wlock, rib_walktree_f_t *wa_f,
    void *arg);
void rib_walk_ext(uint32_t fibnum, int af, bool wlock, rib_walktree_f_t *wa_f,
    rib_walk_hook_f_t *hook_f, void *arg);
void rib_walk_ext_internal(struct rib_head *rnh, bool wlock,
    rib_walktree_f_t *wa_f, rib_walk_hook_f_t *hook_f, void *arg);
void rib_walk_ext_locked(struct rib_head *rnh, rib_walktree_f_t *wa_f,
    rib_walk_hook_f_t *hook_f, void *arg);
void rib_walk_from(uint32_t fibnum, int family, uint32_t flags, struct sockaddr *prefix,
    struct sockaddr *mask, rib_walktree_f_t *wa_f, void *arg);

void rib_walk_del(u_int fibnum, int family, rib_filter_f_t *filter_f,
    void *filter_arg, bool report);

void rib_foreach_table_walk(int family, bool wlock, rib_walktree_f_t *wa_f,
    rib_walk_hook_f_t *hook_f, void *arg);
void rib_foreach_table_walk_del(int family, rib_filter_f_t *filter_f, void *arg);

struct nhop_object;
struct nhgrp_object;
struct ucred;

const struct rtentry *
rib_lookup_prefix_plen(struct rib_head *rnh, struct sockaddr *dst, int plen,
    struct route_nhop_data *rnd);

/* rtentry accessors */
bool rt_is_host(const struct rtentry *rt);
sa_family_t rt_get_family(const struct rtentry *);
struct nhop_object *rt_get_raw_nhop(const struct rtentry *rt);
void rt_get_rnd(const struct rtentry *rt, struct route_nhop_data *rnd);
bool rt_is_exportable(const struct rtentry *rt, struct ucred *cred);
#ifdef INET
struct in_addr;
void rt_get_inet_prefix_plen(const struct rtentry *rt, struct in_addr *paddr,
    int *plen, uint32_t *pscopeid);
void rt_get_inet_prefix_pmask(const struct rtentry *rt, struct in_addr *paddr,
    struct in_addr *pmask, uint32_t *pscopeid);
struct rtentry *rt_get_inet_parent(uint32_t fibnum, struct in_addr addr, int plen);
#endif
#ifdef INET6
struct in6_addr;
void rt_get_inet6_prefix_plen(const struct rtentry *rt, struct in6_addr *paddr,
    int *plen, uint32_t *pscopeid);
void rt_get_inet6_prefix_pmask(const struct rtentry *rt, struct in6_addr *paddr,
    struct in6_addr *pmask, uint32_t *pscopeid);
struct rtentry *rt_get_inet6_parent(uint32_t fibnum, const struct in6_addr *paddr,
    int plen);

struct in6_addr;
void ip6_writemask(struct in6_addr *addr6, uint8_t mask);
#endif

/* Nexthops */
uint32_t nhops_get_count(struct rib_head *rh);

struct nhop_priv;
struct nhop_iter {
	uint32_t		fibnum;
	uint8_t			family;
	struct rib_head		*rh;
	int			_i;
	struct nhop_priv	*_next;
};

struct nhop_object *nhops_iter_start(struct nhop_iter *iter);
struct nhop_object *nhops_iter_next(struct nhop_iter *iter);
void nhops_iter_stop(struct nhop_iter *iter);

/* Multipath */
struct weightened_nhop;

const struct weightened_nhop *nhgrp_get_nhops(const struct nhgrp_object *nhg,
    uint32_t *pnum_nhops);
uint32_t nhgrp_get_count(struct rib_head *rh);
int nhgrp_get_group(struct rib_head *rh, struct weightened_nhop *wn, int num_nhops,
    uint32_t uidx, struct nhgrp_object **pnhg);

/* Route subscriptions */
enum rib_subscription_type {
	RIB_NOTIFY_IMMEDIATE,
	RIB_NOTIFY_DELAYED
};

struct rib_subscription;
typedef void rib_subscription_cb_t(struct rib_head *rnh, struct rib_cmd_info *rc,
    void *arg);

struct rib_subscription *rib_subscribe(uint32_t fibnum, int family,
    rib_subscription_cb_t *f, void *arg, enum rib_subscription_type type,
    bool waitok);
struct rib_subscription *rib_subscribe_internal(struct rib_head *rnh,
    rib_subscription_cb_t *f, void *arg, enum rib_subscription_type type,
    bool waitok);
struct rib_subscription *rib_subscribe_locked(struct rib_head *rnh,
    rib_subscription_cb_t *f, void *arg, enum rib_subscription_type type);
void rib_unsubscribe(struct rib_subscription *rs);
void rib_unsubscribe_locked(struct rib_subscription *rs);
void rib_notify(struct rib_head *rnh, enum rib_subscription_type type,
    struct rib_cmd_info *rc);

/* Event bridge */
typedef void route_event_f(uint32_t fibnum, const struct rib_cmd_info *rc);
typedef void ifmsg_event_f(struct ifnet *ifp, int if_flags_mask);
struct rtbridge{
	route_event_f	*route_f;
	ifmsg_event_f	*ifmsg_f;
};
extern struct rtbridge *rtsock_callback_p;
extern struct rtbridge *netlink_callback_p;
#endif