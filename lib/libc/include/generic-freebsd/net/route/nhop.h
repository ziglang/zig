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
 * This header file contains public definitions for the nexthop routing subsystem.
 */

#ifndef	_NET_ROUTE_NHOP_H_
#define	_NET_ROUTE_NHOP_H_

#include <netinet/in.h>			/* sockaddr_in && sockaddr_in6 */

#include <sys/counter.h>

enum nhop_type {
	NH_TYPE_IPV4_ETHER_RSLV = 1,	/* IPv4 ethernet without GW */
	NH_TYPE_IPV4_ETHER_NHOP = 2,	/* IPv4 with pre-calculated ethernet encap */
	NH_TYPE_IPV6_ETHER_RSLV = 3,	/* IPv6 ethernet, without GW */
	NH_TYPE_IPV6_ETHER_NHOP = 4	/* IPv6 with pre-calculated ethernet encap*/
};

#ifdef _KERNEL

/*
 * Define shorter version of AF_LINK sockaddr.
 *
 * Currently the only use case of AF_LINK gateway is storing
 * interface index of the interface of the source IPv6 address.
 * This is used by the IPv6 code for the connections over loopback
 * interface.
 *
 * The structure below copies 'struct sockaddr_dl', reducing the
 * size of sdl_data buffer, as it is not used. This change
 * allows to store the AF_LINK gateways in the nhop gateway itself,
 * simplifying control plane handling.
 */
struct sockaddr_dl_short {
	u_char	sdl_len;	/* Total length of sockaddr */
	u_char	sdl_family;	/* AF_LINK */
	u_short	sdl_index;	/* if != 0, system given index for interface */
	u_char	sdl_type;	/* interface type */
	u_char	sdl_nlen;	/* interface name length, no trailing 0 reqd. */
	u_char	sdl_alen;	/* link level address length */
	u_char	sdl_slen;	/* link layer selector length */
	char	sdl_data[8];	/* unused */
};

#define	NHOP_RELATED_FLAGS	\
	(RTF_GATEWAY | RTF_HOST | RTF_REJECT | RTF_BLACKHOLE | \
	 RTF_FIXEDMTU | RTF_LOCAL | RTF_BROADCAST | RTF_MULTICAST)

struct nh_control;
struct nhop_priv;

/*
 * Struct 'nhop_object' field description:
 *
 * nh_flags: NHF_ flags used in the dataplane code. NHF_GATEWAY or NHF_BLACKHOLE
 *   can be examples of such flags.
 * nh_mtu: ready-to-use nexthop mtu. Already accounts for the link-level header,
 *   interface MTU and protocol-specific limitations.
 * nh_prepend_len: link-level prepend length. Currently unused.
 * nh_ifp: logical transmit interface. The one from which if_transmit() will be
 *   called. Guaranteed to be non-NULL.
 * nh_aifp: ifnet of the source address. Same as nh_ifp except IPv6 loopback
 *   routes. See the example below.
 * nh_ifa: interface address to use. Guaranteed to be non-NULL. 
 * nh_pksent: counter(9) reflecting the number of packets transmitted.
 *
 * gw_: storage suitable to hold AF_INET, AF_INET6 or AF_LINK gateway. More
 *   details ara available in the examples below.
 *
 * Examples:
 *
 * Direct routes (routes w/o gateway):
 *  NHF_GATEWAY is NOT set.
 *  nh_ifp denotes the logical transmit interface ().
 *  nh_aifp is the same as nh_ifp
 *  gw_sa contains AF_LINK sa with nh_aifp ifindex (compat)
 * Loopback routes:
 *  NHF_GATEWAY is NOT set.
 *  nh_ifp points to the loopback interface (lo0).
 *  nh_aifp points to the interface where the destination address belongs to.
 *    This is useful in IPv6 link-local-over-loopback communications.
 *  gw_sa contains AF_LINK sa with nh_aifp ifindex (compat)
 * GW routes:
 *  NHF_GATEWAY is set.
 *  nh_ifp denotes the logical transmit interface.
 *  nh_aifp is the same as nh_ifp
 *  gw_sa contains L3 address (either AF_INET or AF_INET6).
 *
 *
 * Note: struct nhop_object fields are ordered in a way that
 *  supports memcmp-based comparisons.
 *
 */
#define	NHOP_END_CMP	(__offsetof(struct nhop_object, nh_pksent))

struct nhop_object {
	uint16_t		nh_flags;	/* nhop flags */
	uint16_t		nh_mtu;		/* nexthop mtu */
	union {
		struct sockaddr_in		gw4_sa;	/* GW accessor as IPv4 */
		struct sockaddr_in6		gw6_sa; /* GW accessor as IPv6 */
		struct sockaddr			gw_sa;
		struct sockaddr_dl_short	gwl_sa; /* AF_LINK gw (compat) */
		char				gw_buf[28];
	};
	struct ifnet		*nh_ifp;	/* Logical egress interface. Always != NULL */
	struct ifaddr		*nh_ifa;	/* interface address to use. Always != NULL */
	struct ifnet		*nh_aifp;	/* ifnet of the source address. Always != NULL */
	counter_u64_t		nh_pksent;	/* packets sent using this nhop */
	/* 32 bytes + 4xPTR == 64(amd64) / 48(i386)  */
	uint8_t			nh_prepend_len;	/* length of prepend data */
	uint8_t			spare[3];
	uint32_t		spare1;		/* alignment */
	char			nh_prepend[48];	/* L2 prepend */
	struct nhop_priv	*nh_priv;	/* control plane data */
	/* -- 128 bytes -- */
};

/*
 * Nhop validness.
 *
 * Currently we verify whether link is up or not on every packet, which can be
 *   quite costy.
 * TODO: subscribe for the interface notifications and update the nexthops
 *  with NHF_INVALID flag.
 */

#define	NH_IS_VALID(_nh)	RT_LINK_IS_UP((_nh)->nh_ifp)
#define	NH_IS_NHGRP(_nh)	((_nh)->nh_flags & NHF_MULTIPATH)

#define	NH_FREE(_nh) do {					\
	nhop_free(_nh);	\
	/* guard against invalid refs */			\
	_nh = NULL;						\
} while (0)

struct weightened_nhop {
	struct nhop_object	*nh;
	uint32_t		weight;
	uint32_t		storage;
};

void nhop_free(struct nhop_object *nh);

struct sysctl_req;
struct sockaddr_dl;
struct rib_head;

/* flags that can be set using nhop_set_rtflags() */
#define	RT_SET_RTFLAGS_MASK     (RTF_PROTO1 | RTF_PROTO2 | RTF_PROTO3 | RTF_STATIC)
#define	RT_CHANGE_RTFLAGS_MASK	RT_SET_RTFLAGS_MASK

struct nhop_object *nhop_alloc(uint32_t fibnum, int family);
void nhop_copy(struct nhop_object *nh, const struct nhop_object *nh_orig);
struct nhop_object *nhop_get_nhop(struct nhop_object *nh, int *perror);
int nhop_get_unlinked(struct nhop_object *nh);

void nhop_set_direct_gw(struct nhop_object *nh, struct ifnet *ifp);
bool nhop_set_gw(struct nhop_object *nh, const struct sockaddr *sa, bool is_gw);


void nhop_set_mtu(struct nhop_object *nh, uint32_t mtu, bool from_user);
void nhop_set_rtflags(struct nhop_object *nh, int rt_flags);
void nhop_set_pxtype_flag(struct nhop_object *nh, int nh_flag);
void nhop_set_broadcast(struct nhop_object *nh, bool is_broadcast);
void nhop_set_blackhole(struct nhop_object *nh, int blackhole_rt_flag);
void nhop_set_pinned(struct nhop_object *nh, bool is_pinned);
void nhop_set_redirect(struct nhop_object *nh, bool is_redirect);
void nhop_set_type(struct nhop_object *nh, enum nhop_type nh_type);
void nhop_set_src(struct nhop_object *nh, struct ifaddr *ifa);
void nhop_set_transmit_ifp(struct nhop_object *nh, struct ifnet *ifp);

#define	NH_ORIGIN_UNSPEC	0 /* not set */
#define	NH_ORIGIN_REDIRECT	1 /* kernel-originated redirect */
#define	NH_ORIGIN_KERNEL	2 /* kernel (interface) routes */
#define	NH_ORIGIN_BOOT		3 /* kernel-originated routes at boot */
#define	NH_ORIGIN_STATIC	4 /* route(8) routes */
void nhop_set_origin(struct nhop_object *nh, uint8_t origin);
uint8_t nhop_get_origin(const struct nhop_object *nh);

uint32_t nhop_get_idx(const struct nhop_object *nh);
uint32_t nhop_get_uidx(const struct nhop_object *nh);
void nhop_set_uidx(struct nhop_object *nh, uint32_t uidx);
enum nhop_type nhop_get_type(const struct nhop_object *nh);
int nhop_get_rtflags(const struct nhop_object *nh);
struct vnet *nhop_get_vnet(const struct nhop_object *nh);
struct nhop_object *nhop_select_func(struct nhop_object *nh, uint32_t flowid);
int nhop_get_upper_family(const struct nhop_object *nh);
bool nhop_set_upper_family(struct nhop_object *nh, int family);
int nhop_get_neigh_family(const struct nhop_object *nh);
uint32_t nhop_get_fibnum(const struct nhop_object *nh);
void nhop_set_fibnum(struct nhop_object *nh, uint32_t fibnum);
uint32_t nhop_get_expire(const struct nhop_object *nh);
void nhop_set_expire(struct nhop_object *nh, uint32_t expire);
struct rib_head *nhop_get_rh(const struct nhop_object *nh);

struct nhgrp_object;
struct nhgrp_object *nhgrp_alloc(uint32_t fibnum, int family,
    struct weightened_nhop *wn, int num_nhops, int *perror);
struct nhgrp_object *nhgrp_get_nhgrp(struct nhgrp_object *nhg, int *perror);
void nhgrp_set_uidx(struct nhgrp_object *nhg, uint32_t uidx);
uint32_t nhgrp_get_uidx(const struct nhgrp_object *nhg);
uint8_t nhgrp_get_origin(const struct nhgrp_object *nhg);
void nhgrp_set_origin(struct nhgrp_object *nhg, uint8_t origin);
#endif /* _KERNEL */

/* Kernel <> userland structures */

/* Structure usage and layout are described in dump_nhop_entry() */
struct nhop_external {
	uint32_t	nh_len;		/* length of the datastructure */
	uint32_t	nh_idx;		/* Nexthop index */
	uint32_t	nh_fib;		/* Fib nexhop is attached to */
	uint32_t	ifindex;	/* transmit interface ifindex */
	uint32_t	aifindex;	/* address ifindex */
	uint8_t		prepend_len;	/* length of the prepend */
	uint8_t		nh_family;	/* address family */
	uint16_t	nh_type;	/* nexthop type */
	uint16_t	nh_mtu;		/* nexthop mtu */

	uint16_t	nh_flags;	/* nhop flags */
	struct in_addr	nh_addr;	/* GW/DST IPv4 address */
	struct in_addr	nh_src;		/* default source IPv4 address */
	uint64_t	nh_pksent;
	/* control plane */
	/* lookup key: address, family, type */
	char		nh_prepend[64];	/* L2 prepend */
	uint64_t	nh_refcount;	/* number of references */
};

struct nhop_addrs {
	uint32_t	na_len;		/* length of the datastructure */
	uint16_t	gw_sa_off;	/* offset of gateway SA */
	uint16_t	src_sa_off;	/* offset of src address SA */
};

#define	NHG_C_TYPE_CNHOPS	0x1	/* Control plane nhops list */
#define	NHG_C_TYPE_DNHOPS	0x2	/* Dataplane nhops list */
struct nhgrp_container {
	uint32_t	nhgc_len;	/* container length */
	uint16_t	nhgc_count;	/* number of items */
	uint8_t		nhgc_type;	/* container type */
	uint8_t		nhgc_subtype;	/* container subtype */
};

struct nhgrp_nhop_external {
	uint32_t	nh_idx;
	uint32_t	nh_weight;
};

/*
 * Layout:
 * - nhgrp_external
 * - nhgrp_container (control plane nhops list)
 *   - nhgrp_nhop_external
 *   - nhgrp_nhop_external
 *   ..
 * - nhgrp_container (dataplane nhops list)
 *   - nhgrp_nhop_external
 *   - nhgrp_nhop_external
 */
struct nhgrp_external {
	uint32_t	nhg_idx;	/* Nexthop group index */
	uint32_t	nhg_refcount;	/* number of references */
};

#endif