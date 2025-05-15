/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2022 Alexander V. Chernikov <melifaro@FreeBSD.org>
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
 * NEXTHOP-related (RTM_<NEW|DEL|GET>NEXTHOP) message header and attributes.
 */

#ifndef _NETLINK_ROUTE_NEXTHOP_H_
#define _NETLINK_ROUTE_NEXTHOP_H_

/* Base header for all of the relevant messages */
struct nhmsg {
        unsigned char	nh_family;	/* transport family */
	unsigned char	nh_scope;	/* ignored on RX, filled by kernel */
	unsigned char	nh_protocol;	/* Routing protocol that installed nh */
	unsigned char	resvd;
	unsigned int	nh_flags;	/* RTNH_F_* flags from route.h */
};

enum {
	NHA_UNSPEC,
	NHA_ID,		/* u32: nexthop userland index, auto-assigned if 0 */
	NHA_GROUP,	/* binary: array of struct nexthop_grp */
	NHA_GROUP_TYPE,	/* u16: set to NEXTHOP_GRP_TYPE */
	NHA_BLACKHOLE,	/* flag: nexthop used to blackhole packets */
	NHA_OIF,	/* u32: transmit ifindex */
	NHA_GATEWAY,	/* network: IPv4/IPv6 gateway addr */
	NHA_ENCAP_TYPE, /* not supported */
	NHA_ENCAP,	/* not supported */
	NHA_GROUPS,	/* flag: match nexthop groups */
	NHA_MASTER,	/* not supported */
	NHA_FDB,	/* not supported */
	NHA_RES_GROUP,	/* not supported */
	NHA_RES_BUCKET,	/* not supported */
	NHA_FREEBSD,	/* nested: FreeBSD-specific attributes */
	__NHA_MAX,
};
#define NHA_MAX	(__NHA_MAX - 1)

enum {
	NHAF_UNSPEC,
	NHAF_KNHOPS,	/* flag: dump kernel nexthops */
	NHAF_KGOUPS,	/* flag: dump kernel nexthop groups */
	NHAF_TABLE,	/* u32: rtable id */
	NHAF_FAMILY,	/* u32: upper family */
	NHAF_KID,	/* u32: kernel nexthop index */
	NHAF_AIF,	/* u32: source interface address */
};

/*
 * Attributes that can be used as filters:
 * NHA_ID (nexhop or group), NHA_OIF, NHA_GROUPS,
 */

/*
 * NHA_GROUP: array of the following structures.
 * If attribute is set, the only other valid attributes are
 *  NHA_ID and NHA_GROUP_TYPE.
 *  NHA_RES_GROUP and NHA_RES_BUCKET are not supported yet
 */
struct nexthop_grp {
	uint32_t	id;		/* nexhop userland index */
	uint8_t		weight;         /* weight of this nexthop */
	uint8_t		resvd1;
	uint16_t	resvd2;
};

/* NHA_GROUP_TYPE: u16 */
enum {
	NEXTHOP_GRP_TYPE_MPATH,		/* default nexthop group */
	NEXTHOP_GRP_TYPE_RES,		/* resilient nexthop group */
	__NEXTHOP_GRP_TYPE_MAX,
};
#define NEXTHOP_GRP_TYPE_MAX (__NEXTHOP_GRP_TYPE_MAX - 1)


/* NHA_RES_GROUP */
enum {
	NHA_RES_GROUP_UNSPEC,
	NHA_RES_GROUP_PAD = NHA_RES_GROUP_UNSPEC,
	NHA_RES_GROUP_BUCKETS,
	NHA_RES_GROUP_IDLE_TIMER,
	NHA_RES_GROUP_UNBALANCED_TIMER,
	NHA_RES_GROUP_UNBALANCED_TIME,
	__NHA_RES_GROUP_MAX,
};
#define NHA_RES_GROUP_MAX	(__NHA_RES_GROUP_MAX - 1)

#endif