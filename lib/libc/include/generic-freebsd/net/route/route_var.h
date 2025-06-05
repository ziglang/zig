/*-
 * Copyright (c) 2015-2016
 * 	Alexander V. Chernikov <melifaro@FreeBSD.org>
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
 */

#ifndef _NET_ROUTE_VAR_H_
#define _NET_ROUTE_VAR_H_

#ifndef RNF_NORMAL
#include <net/radix.h>
#endif
#include <sys/ck.h>
#include <sys/epoch.h>
#include <netinet/in.h>		/* struct sockaddr_in */
#include <sys/counter.h>
#include <net/route/nhop.h>

struct nh_control;
/* Sets prefix-specific nexthop flags (NHF_DEFAULT, RTF/NHF_HOST, RTF_BROADCAST,..) */
typedef int rnh_set_nh_pfxflags_f_t(u_int fibnum, const struct sockaddr *addr,
	const struct sockaddr *mask, struct nhop_object *nh);
/* Fills in family-specific details that are not yet set up (mtu, nhop type, ..) */
typedef int rnh_augment_nh_f_t(u_int fibnum, struct nhop_object *nh);

struct rib_head {
	struct radix_head	head;
	rn_matchaddr_f_t	*rnh_matchaddr;	/* longest match for sockaddr */
	rn_addaddr_f_t		*rnh_addaddr;	/* add based on sockaddr*/
	rn_deladdr_f_t		*rnh_deladdr;	/* remove based on sockaddr */
	rn_lookup_f_t		*rnh_lookup;	/* exact match for sockaddr */
	rn_walktree_t		*rnh_walktree;	/* traverse tree */
	rn_walktree_from_t	*rnh_walktree_from; /* traverse tree below a */
	rnh_set_nh_pfxflags_f_t	*rnh_set_nh_pfxflags;	/* hook to alter record prior to insertion */
	rt_gen_t		rnh_gen;	/* datapath generation counter */
	int			rnh_multipath;	/* multipath capable ? */
	struct radix_node	rnh_nodes[3];	/* empty tree for common case */
	struct rmlock		rib_lock;	/* config/data path lock */
	struct radix_mask_head	rmhead;		/* masks radix head */
	struct vnet		*rib_vnet;	/* vnet pointer */
	int			rib_family;	/* AF of the rtable */
	u_int			rib_fibnum;	/* fib number */
	struct callout		expire_callout;	/* Callout for expiring dynamic routes */
	time_t			next_expire;	/* Next expire run ts */
	uint32_t		rnh_prefixes;	/* Number of prefixes */
	rt_gen_t		rnh_gen_rib;	/* fib algo: rib generation counter */
	uint32_t		rib_dying:1;	/* rib is detaching */
	uint32_t		rib_algo_fixed:1;/* fixed algorithm */
	uint32_t		rib_algo_init:1;/* algo init done */
	struct nh_control	*nh_control;	/* nexthop subsystem data */
	rnh_augment_nh_f_t	*rnh_augment_nh;/* hook to alter nexthop prior to insertion */
	CK_STAILQ_HEAD(, rib_subscription)	rnh_subscribers;/* notification subscribers */
};

#define	RIB_RLOCK_TRACKER	struct rm_priotracker _rib_tracker
#define	RIB_LOCK_INIT(rh)	rm_init_flags(&(rh)->rib_lock, "rib head lock", RM_DUPOK)
#define	RIB_LOCK_DESTROY(rh)	rm_destroy(&(rh)->rib_lock)
#define	RIB_RLOCK(rh)		rm_rlock(&(rh)->rib_lock, &_rib_tracker)
#define	RIB_RUNLOCK(rh)		rm_runlock(&(rh)->rib_lock, &_rib_tracker)
#define	RIB_WLOCK(rh)		rm_wlock(&(rh)->rib_lock)
#define	RIB_WUNLOCK(rh)		rm_wunlock(&(rh)->rib_lock)
#define	RIB_LOCK_ASSERT(rh)	rm_assert(&(rh)->rib_lock, RA_LOCKED)
#define	RIB_WLOCK_ASSERT(rh)	rm_assert(&(rh)->rib_lock, RA_WLOCKED)

/* Constants */
#define	RIB_MAX_RETRIES	3
#define	RT_MAXFIBS	UINT16_MAX
#define	RIB_MAX_MPATH_WIDTH	64

/* Macro for verifying fields in af-specific 'struct route' structures */
#define CHK_STRUCT_FIELD_GENERIC(_s1, _f1, _s2, _f2)			\
_Static_assert(sizeof(((_s1 *)0)->_f1) == sizeof(((_s2 *)0)->_f2),	\
		"Fields " #_f1 " and " #_f2 " size differs");		\
_Static_assert(__offsetof(_s1, _f1) == __offsetof(_s2, _f2),		\
		"Fields " #_f1 " and " #_f2 " offset differs");

#define _CHK_ROUTE_FIELD(_route_new, _field) \
	CHK_STRUCT_FIELD_GENERIC(struct route, _field, _route_new, _field)

#define CHK_STRUCT_ROUTE_FIELDS(_route_new)	\
	_CHK_ROUTE_FIELD(_route_new, ro_nh)	\
	_CHK_ROUTE_FIELD(_route_new, ro_lle)	\
	_CHK_ROUTE_FIELD(_route_new, ro_prepend)\
	_CHK_ROUTE_FIELD(_route_new, ro_plen)	\
	_CHK_ROUTE_FIELD(_route_new, ro_flags)	\
	_CHK_ROUTE_FIELD(_route_new, ro_mtu)	\
	_CHK_ROUTE_FIELD(_route_new, spare)

#define CHK_STRUCT_ROUTE_COMPAT(_ro_new, _dst_new)				\
CHK_STRUCT_ROUTE_FIELDS(_ro_new);						\
_Static_assert(__offsetof(struct route, ro_dst) == __offsetof(_ro_new, _dst_new),\
		"ro_dst and " #_dst_new " are at different offset")

static inline void
rib_bump_gen(struct rib_head *rnh)
{
#ifdef FIB_ALGO
	rnh->rnh_gen_rib++;
#else
	rnh->rnh_gen++;
#endif
}

struct rib_head *rt_tables_get_rnh(uint32_t table, sa_family_t family);
int rt_getifa_fib(struct rt_addrinfo *info, u_int fibnum);
struct rib_cmd_info;

VNET_PCPUSTAT_DECLARE(struct rtstat, rtstat);
#define	RTSTAT_ADD(name, val)	\
	VNET_PCPUSTAT_ADD(struct rtstat, rtstat, name, (val))
#define	RTSTAT_INC(name)	RTSTAT_ADD(name, 1)

/*
 * Convert a 'struct radix_node *' to a 'struct rtentry *'.
 * The operation can be done safely (in this code) because a
 * 'struct rtentry' starts with two 'struct radix_node''s, the first
 * one representing leaf nodes in the routing tree, which is
 * what the code in radix.c passes us as a 'struct radix_node'.
 *
 * But because there are a lot of assumptions in this conversion,
 * do not cast explicitly, but always use the macro below.
 */
#define RNTORT(p)	((struct rtentry *)(p))

struct rtentry {
	struct	radix_node rt_nodes[2];	/* tree glue, and other values */
	/*
	 * XXX struct rtentry must begin with a struct radix_node (or two!)
	 * because the code does some casts of a 'struct radix_node *'
	 * to a 'struct rtentry *'
	 */
#define	rt_key(r)	(*((struct sockaddr **)(&(r)->rt_nodes->rn_key)))
#define	rt_mask(r)	(*((struct sockaddr **)(&(r)->rt_nodes->rn_mask)))
#define	rt_key_const(r)		(*((const struct sockaddr * const *)(&(r)->rt_nodes->rn_key)))
#define	rt_mask_const(r)	(*((const struct sockaddr * const *)(&(r)->rt_nodes->rn_mask)))

	/*
	 * 2 radix_node structurs above consists of 2x6 pointers, leaving
	 * 4 pointers (32 bytes) of the second cache line on amd64.
	 *
	 */
	struct nhop_object	*rt_nhop;	/* nexthop data */
	union {
		/*
		 * Destination address storage.
		 * sizeof(struct sockaddr_in6) == 28, however
		 * the dataplane-relevant part (e.g. address) lies
		 * at offset 8..24, making the address not crossing
		 * cacheline boundary.
		 */
		struct sockaddr_in	rt_dst4;
		struct sockaddr_in6	rt_dst6;
		struct sockaddr		rt_dst;
		char			rt_dstb[28];
	};

	int		rte_flags;	/* up/down?, host/net */
	u_long		rt_weight;	/* absolute weight */ 
	struct rtentry	*rt_chain;	/* pointer to next rtentry to delete */
	struct epoch_context	rt_epoch_ctx;	/* net epoch tracker */
};

/*
 * With the split between the routing entry and the nexthop,
 *  rt_flags has to be split between these 2 entries. As rtentry
 *  mostly contains prefix data and is thought to be generic enough
 *  so one can transparently change the nexthop pointer w/o requiring
 *  any other rtentry changes, most of rt_flags shifts to the particular nexthop.
 * /
 *
 * RTF_UP: rtentry, as an indication that it is linked.
 * RTF_HOST: rtentry, nhop. The latter indication is needed for the datapath
 * RTF_DYNAMIC: nhop, to make rtentry generic.
 * RTF_MODIFIED: nhop, to make rtentry generic. (legacy)
 * -- "native" path (nhop) properties:
 * RTF_GATEWAY, RTF_STATIC, RTF_PROTO1, RTF_PROTO2, RTF_PROTO3, RTF_FIXEDMTU,
 *  RTF_PINNED, RTF_REJECT, RTF_BLACKHOLE, RTF_BROADCAST
 */

/* rtentry rt flag mask */
#define	RTE_RT_FLAG_MASK	(RTF_UP | RTF_HOST)

/* route_temporal.c */
void tmproutes_update(struct rib_head *rnh, struct rtentry *rt, struct nhop_object *nh);
void tmproutes_init(struct rib_head *rh);
void tmproutes_destroy(struct rib_head *rh);

/* route_ctl.c */
struct route_nhop_data;
int change_route(struct rib_head *rnh, struct rtentry *rt,
    struct route_nhop_data *rnd, struct rib_cmd_info *rc);
int change_route_conditional(struct rib_head *rnh, struct rtentry *rt,
    struct route_nhop_data *nhd_orig, struct route_nhop_data *nhd_new,
    struct rib_cmd_info *rc);
struct rtentry *lookup_prefix(struct rib_head *rnh,
    const struct rt_addrinfo *info, struct route_nhop_data *rnd);
struct rtentry *lookup_prefix_rt(struct rib_head *rnh, const struct rtentry *rt,
    struct route_nhop_data *rnd);
int rib_copy_route(struct rtentry *rt, const struct route_nhop_data *rnd_src,
    struct rib_head *rh_dst, struct rib_cmd_info *rc);

bool nhop_can_multipath(const struct nhop_object *nh);
bool match_nhop_gw(const struct nhop_object *nh, const struct sockaddr *gw);
int check_info_match_nhop(const struct rt_addrinfo *info,
    const struct rtentry *rt, const struct nhop_object *nh);
bool rib_can_4o6_nhop(void);

/* route_rtentry.c */
void vnet_rtzone_init(void);
void vnet_rtzone_destroy(void);
void rt_free(struct rtentry *rt);
void rt_free_immediate(struct rtentry *rt);
struct rtentry *rt_alloc(struct rib_head *rnh, const struct sockaddr *dst,
    struct sockaddr *netmask);

/* subscriptions */
void rib_init_subscriptions(struct rib_head *rnh);
void rib_destroy_subscriptions(struct rib_head *rnh);

/* route_ifaddrs.c */
void rib_copy_kernel_routes(struct rib_head *rh_src, struct rib_head *rh_dst);

/* Nexhops */
void nhops_init(void);
int nhops_init_rib(struct rib_head *rh);
void nhops_destroy_rib(struct rib_head *rh);
void nhop_ref_object(struct nhop_object *nh);
int nhop_try_ref_object(struct nhop_object *nh);
void nhop_ref_any(struct nhop_object *nh);
void nhop_free_any(struct nhop_object *nh);
struct nhop_object *nhop_get_nhop_internal(struct rib_head *rnh,
    struct nhop_object *nh, int *perror);

bool nhop_check_gateway(int upper_family, int neigh_family);

int nhop_create_from_info(struct rib_head *rnh, struct rt_addrinfo *info,
    struct nhop_object **nh_ret);
int nhop_create_from_nhop(struct rib_head *rnh, const struct nhop_object *nh_orig,
    struct rt_addrinfo *info, struct nhop_object **pnh_priv);

void nhops_update_ifmtu(struct rib_head *rh, struct ifnet *ifp, uint32_t mtu);
int nhops_dump_sysctl(struct rib_head *rh, struct sysctl_req *w);

/* MULTIPATH */
#define	MPF_MULTIPATH	0x08	/* need to be consistent with NHF_MULTIPATH */

struct nhgrp_object {
	uint16_t		nhg_flags;	/* nexthop group flags */
	uint8_t			nhg_size;	/* dataplain group size */
	uint8_t			spare;
	struct nhop_object	*nhops[0];	/* nhops */
};

static inline struct nhop_object *
nhop_select(struct nhop_object *nh, uint32_t flowid)
{

#ifdef ROUTE_MPATH
	if (NH_IS_NHGRP(nh)) {
		struct nhgrp_object *nhg = (struct nhgrp_object *)nh;
		nh = nhg->nhops[flowid % nhg->nhg_size];
	}
#endif
	return (nh);
}


struct weightened_nhop;

/* mpath_ctl.c */
int add_route_mpath(struct rib_head *rnh, struct rt_addrinfo *info,
    struct rtentry *rt, struct route_nhop_data *rnd_add,
    struct route_nhop_data *rnd_orig, struct rib_cmd_info *rc);

/* nhgrp.c */
int nhgrp_ctl_init(struct nh_control *ctl);
void nhgrp_ctl_free(struct nh_control *ctl);
void nhgrp_ctl_unlink_all(struct nh_control *ctl);


/* nhgrp_ctl.c */
int nhgrp_dump_sysctl(struct rib_head *rh, struct sysctl_req *w);

int nhgrp_get_filtered_group(struct rib_head *rh, const struct rtentry *rt,
    const struct nhgrp_object *src, rib_filter_f_t flt_func, void *flt_data,
    struct route_nhop_data *rnd);
int nhgrp_get_addition_group(struct rib_head *rnh,
    struct route_nhop_data *rnd_orig, struct route_nhop_data *rnd_add,
    struct route_nhop_data *rnd_new);

void nhgrp_ref_object(struct nhgrp_object *nhg);
uint32_t nhgrp_get_idx(const struct nhgrp_object *nhg);
void nhgrp_free(struct nhgrp_object *nhg);

/* rtsock */
int rtsock_routemsg(int cmd, struct rtentry *rt, struct nhop_object *nh,
    int fibnum);
int rtsock_routemsg_info(int cmd, struct rt_addrinfo *info, int fibnum);
int rtsock_addrmsg(int cmd, struct ifaddr *ifa, int fibnum);


/* lookup_framework.c */
void fib_grow_rtables(uint32_t new_num_tables);
void fib_setup_family(int family, uint32_t num_tables);
void fib_destroy_rib(struct rib_head *rh);
void vnet_fib_init(void);
void vnet_fib_destroy(void);

/* Entropy data used for outbound hashing */
#define MPATH_ENTROPY_KEY_LEN	40
extern uint8_t mpath_entropy_key[MPATH_ENTROPY_KEY_LEN];

#endif