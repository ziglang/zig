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
 * Route-related (RTM_<NEW|DEL|GET>ROUTE) message header and attributes.
 */

#ifndef _NETLINK_ROUTE_ROUTE_H_
#define _NETLINK_ROUTE_ROUTE_H_

/* Base header for all of the relevant messages */
struct rtmsg {
	unsigned char	rtm_family;	/* address family */
	unsigned char	rtm_dst_len;	/* Prefix length */
	unsigned char	rtm_src_len;	/* Source prefix length (not used) */
	unsigned char	rtm_tos;	/* Type of service (not used) */
	unsigned char	rtm_table;	/* rtable id */
	unsigned char	rtm_protocol;	/* Routing protocol id (RTPROT_) */
	unsigned char	rtm_scope;	/* Route distance (RT_SCOPE_) */
	unsigned char	rtm_type;	/* Route type (RTN_) */
	unsigned 	rtm_flags;	/* Route flags (RTM_F_) */
};

/*
 * RFC 3549, 3.1.1, route type (rtm_type field).
 */
enum {
	RTN_UNSPEC,
	RTN_UNICAST,		/* Unicast route */
	RTN_LOCAL,		/* Accept locally (not supported) */
	RTN_BROADCAST,		/* Accept locally as broadcast, send as broadcast */
	RTN_ANYCAST,		/* Accept locally as broadcast, but send as unicast */
	RTN_MULTICAST,		/* Multicast route */
	RTN_BLACKHOLE,		/* Drop traffic towards destination */
	RTN_UNREACHABLE,	/* Destination is unreachable */
	RTN_PROHIBIT,		/* Administratively prohibited */
	RTN_THROW,		/* Not in this table (not supported) */
	RTN_NAT,		/* Translate this address (not supported) */
	RTN_XRESOLVE,		/* Use external resolver (not supported) */
	__RTN_MAX,
};
#define RTN_MAX (__RTN_MAX - 1)

/*
 * RFC 3549, 3.1.1, protocol (Identifies what/who added the route).
 * Values larger than RTPROT_STATIC(4) are not interpreted by the
 * kernel, they are just for user information.
 */
#define	RTPROT_UNSPEC		0
#define RTPROT_REDIRECT		1 /* Route installed by ICMP redirect */
#define RTPROT_KERNEL		2 /* Route installed by kernel */
#define RTPROT_BOOT		3 /* Route installed during boot */
#define RTPROT_STATIC		4 /* Route installed by administrator */

#define	RTPROT_GATED		8
#define RTPROT_RA		9
#define RTPROT_MRT		1
#define RTPROT_ZEBRA		11
#define RTPROT_BIRD		12
#define RTPROT_DNROUTED		13
#define RTPROT_XORP		14
#define RTPROT_NTK		15
#define RTPROT_DHCP		16
#define RTPROT_MROUTED		17
#define RTPROT_KEEPALIVED	18
#define RTPROT_BABEL		42
#define RTPROT_OPENR		99
#define RTPROT_BGP		186
#define RTPROT_ISIS		187
#define RTPROT_OSPF		188
#define RTPROT_RIP		189
#define RTPROT_EIGRP		192

/*
 * RFC 3549 3.1.1 Route scope (valid distance to destination).
 *
 * The values between RT_SCOPE_UNIVERSE(0) and RT_SCOPE_SITE(200)
 *  are available to the user.
 */
enum rt_scope_t {
	RT_SCOPE_UNIVERSE = 0,
	/* User defined values  */
	RT_SCOPE_SITE = 200,
	RT_SCOPE_LINK = 253,
	RT_SCOPE_HOST = 254,
	RT_SCOPE_NOWHERE = 255
};

/*
 * RFC 3549 3.1.1 Route flags (rtm_flags).
 * Is a composition of RTNH_F flags (0x1..0x40 range), RTM_F flags (below)
 * and per-protocol (IPv4/IPv6) flags.
 */
#define RTM_F_NOTIFY		0x00000100 /* not supported */
#define RTM_F_CLONED		0x00000200 /* not supported */
#define RTM_F_EQUALIZE		0x00000400 /* not supported */
#define RTM_F_PREFIX		0x00000800 /* not supported */
#define RTM_F_LOOKUP_TABLE	0x00001000 /* not supported */
#define RTM_F_FIB_MATCH		0x00002000 /* not supported */
#define RTM_F_OFFLOAD		0x00004000 /* not supported */
#define RTM_F_TRAP		0x00008000 /* not supported */
#define RTM_F_OFFLOAD_FAILED	0x20000000 /* not supported */

/* Compatibility handling helpers */
#ifndef _KERNEL
#define	NL_RTM_HDRLEN		((int)sizeof(struct rtmsg))
#define	RTM_RTA(_rtm)		((struct rtattr *)((char *)(_rtm) + NL_RTM_HDRLEN))
#define	RTM_PAYLOAD(_hdr)	NLMSG_PAYLOAD((_hdr), NL_RTM_HDRLEN)
#endif

/*
 * Routing table identifiers.
 * FreeBSD route table numbering starts from 0, where 0 is a valid default routing table.
 * Indicating "all tables" via netlink can be done by not including RTA_TABLE attribute
 * and keeping rtm_table=0 (compatibility) or setting RTA_TABLE value to RT_TABLE_UNSPEC.
 */
#define	RT_TABLE_MAIN	0		/* RT_DEFAULT_FIB */
#define	RT_TABLE_UNSPEC	0xFFFFFFFF	/* RT_ALL_FIBS */

enum rtattr_type_t {
	NL_RTA_UNSPEC,
	NL_RTA_DST		= 1, /* binary, IPv4/IPv6 destination */
	NL_RTA_SRC		= 2, /* binary, preferred source address */
	NL_RTA_IIF		= 3, /* not supported */
	NL_RTA_OIF		= 4, /* u32, transmit ifindex */
	NL_RTA_GATEWAY		= 5, /* binary: IPv4/IPv6 gateway */
	NL_RTA_PRIORITY		= 6, /* not supported */
	NL_RTA_PREFSRC		= 7, /* not supported */
	NL_RTA_METRICS		= 8, /* nested, list of NL_RTAX* attrs */
	NL_RTA_MULTIPATH	= 9, /* binary, array of struct rtnexthop */
	NL_RTA_PROTOINFO	= 10, /* not supported / deprecated */
	NL_RTA_KNH_ID		= 10, /* u32, FreeBSD specific, kernel nexthop index */
	NL_RTA_FLOW		= 11, /* not supported */
	NL_RTA_CACHEINFO	= 12, /* not supported */
	NL_RTA_SESSION		= 13, /* not supported / deprecated */
	NL_RTA_WEIGHT		= 13, /* u32, FreeBSD specific, path weight */
	NL_RTA_MP_ALGO		= 14, /* not supported / deprecated */
	NL_RTA_RTFLAGS		= 14, /* u32, FreeBSD specific, path flags (RTF_)*/
	NL_RTA_TABLE		= 15, /* u32, fibnum */
	NL_RTA_MARK		= 16, /* not supported */
	NL_RTA_MFC_STATS	= 17, /* not supported */
	NL_RTA_VIA		= 18, /* binary, struct rtvia */
	NL_RTA_NEWDST		= 19, /* not supported */
	NL_RTA_PREF		= 20, /* not supported */
	NL_RTA_ENCAP_TYPE	= 21, /* not supported */
	NL_RTA_ENCAP		= 22, /* not supported */
	NL_RTA_EXPIRES		= 23, /* u32, seconds till expiration */
	NL_RTA_PAD		= 24, /* not supported */
	NL_RTA_UID		= 25, /* not supported */
	NL_RTA_TTL_PROPAGATE	= 26, /* not supported */
	NL_RTA_IP_PROTO		= 27, /* not supported */
	NL_RTA_SPORT		= 28, /* not supported */
	NL_RTA_DPORT		= 29, /* not supported */
	NL_RTA_NH_ID		= 30, /* u32, nexthop/nexthop group index */
	__RTA_MAX
};
#define NL_RTA_MAX (__RTA_MAX - 1)

/*
 * Attributes that can be used as filters:
 *
 */

#ifndef _KERNEL
/*
 * RTA_* space has clashes with rtsock namespace.
 * Use NL_RTA_ prefix in the kernel and map to
 * RTA_ for userland.
 */
#define RTA_UNSPEC		NL_RTA_UNSPEC
#define RTA_DST			NL_RTA_DST
#define RTA_SRC			NL_RTA_SRC
#define RTA_IIF			NL_RTA_IIF
#define RTA_OIF			NL_RTA_OIF
#define RTA_GATEWAY		NL_RTA_GATEWAY
#define RTA_PRIORITY		NL_RTA_PRIORITY
#define RTA_PREFSRC		NL_RTA_PREFSRC
#define RTA_METRICS		NL_RTA_METRICS
#define RTA_MULTIPATH		NL_RTA_MULTIPATH
#define	RTA_PROTOINFO		NL_RTA_PROTOINFO
#define	RTA_KNH_ID		NL_RTA_KNH_ID
#define RTA_FLOW		NL_RTA_FLOW
#define RTA_CACHEINFO		NL_RTA_CACHEINFO
#define	RTA_SESSION		NL_RTA_SESSION
#define	RTA_MP_ALGO		NL_RTA_MP_ALGO
#define RTA_TABLE		NL_RTA_TABLE
#define RTA_MARK		NL_RTA_MARK
#define RTA_MFC_STATS		NL_RTA_MFC_STATS
#define RTA_VIA			NL_RTA_VIA
#define RTA_NEWDST		NL_RTA_NEWDST
#define RTA_PREF		NL_RTA_PREF
#define RTA_ENCAP_TYPE		NL_RTA_ENCAP_TYPE
#define RTA_ENCAP		NL_RTA_ENCAP
#define RTA_EXPIRES		NL_RTA_EXPIRES
#define RTA_PAD			NL_RTA_PAD
#define RTA_UID			NL_RTA_UID
#define RTA_TTL_PROPAGATE	NL_RTA_TTL_PROPAGATE
#define RTA_IP_PROTO		NL_RTA_IP_PROTO
#define RTA_SPORT		NL_RTA_SPORT
#define RTA_DPORT		NL_RTA_DPORT
#define RTA_NH_ID		NL_RTA_NH_ID
#define	RTA_MAX			NL_RTA_MAX
#endif

/* route attribute header */
struct rtattr {
	unsigned short rta_len;
	unsigned short rta_type;
};

#define	NL_RTA_ALIGN_SIZE	NL_ITEM_ALIGN_SIZE
#define	NL_RTA_ALIGN		NL_ITEM_ALIGN
#define	NL_RTA_HDRLEN		((int)sizeof(struct rtattr))
#define	NL_RTA_DATA_LEN(_rta)	((int)((_rta)->rta_len - NL_RTA_HDRLEN))
#define	NL_RTA_DATA(_rta)	NL_ITEM_DATA(_rta, NL_RTA_HDRLEN)
#define	NL_RTA_DATA_CONST(_rta)	NL_ITEM_DATA_CONST(_rta, NL_RTA_HDRLEN)

/* Compatibility attribute handling helpers */
#ifndef _KERNEL
#define	RTA_ALIGNTO		NL_RTA_ALIGN_SIZE
#define	RTA_ALIGN(_len)		NL_RTA_ALIGN(_len)
#define	_RTA_LEN(_rta)		((int)(_rta)->rta_len)
#define	_RTA_ALIGNED_LEN(_rta)	RTA_ALIGN(_RTA_LEN(_rta))
#define	RTA_OK(_rta, _len)	NL_ITEM_OK(_rta, _len, NL_RTA_HDRLEN, _RTA_LEN)
#define	RTA_NEXT(_rta, _len)	NL_ITEM_ITER(_rta, _len, _RTA_ALIGNED_LEN)
#define	RTA_LENGTH(_len)	(NL_RTA_HDRLEN + (_len))
#define	RTA_SPACE(_len)		RTA_ALIGN(RTA_LENGTH(_len))
#define	RTA_DATA(_rta)		NL_RTA_DATA(_rta)
#define	RTA_PAYLOAD(_rta)	((int)(_RTA_LEN(_rta) - NL_RTA_HDRLEN))
#endif

/* RTA attribute headers */

/* RTA_VIA */
struct rtvia {
	sa_family_t	rtvia_family;
	uint8_t		rtvia_addr[0];
};

/*
 * RTA_METRICS is a nested attribute, consisting of a list of
 * TLVs with types defined below.
 */
 enum {
	NL_RTAX_UNSPEC,
	NL_RTAX_LOCK			= 1, /* not supported */
	NL_RTAX_MTU			= 2, /* desired path MTU */
	NL_RTAX_WINDOW			= 3, /* not supported */
	NL_RTAX_RTT			= 4, /* not supported */
	NL_RTAX_RTTVAR			= 5, /* not supported */
	NL_RTAX_SSTHRESH		= 6, /* not supported */
	NL_RTAX_CWND			= 7, /* not supported */
	NL_RTAX_ADVMSS			= 8, /* not supported  */
	NL_RTAX_REORDERING		= 9, /* not supported */
	NL_RTAX_HOPLIMIT		= 10, /* not supported */
	NL_RTAX_INITCWND		= 11, /* not supporrted */
	NL_RTAX_FEATURES		= 12, /* not supported */
	NL_RTAX_RTO_MIN			= 13, /* not supported */
	NL_RTAX_INITRWND		= 14, /* not supported */
	NL_RTAX_QUICKACK		= 15, /* not supported */
	NL_RTAX_CC_ALGO			= 16, /* not supported */
	NL_RTAX_FASTOPEN_NO_COOKIE	= 17, /* not supported */
	__NL_RTAX_MAX
};
#define NL_RTAX_MAX (__NL_RTAX_MAX - 1)

#define RTAX_FEATURE_ECN (1 << 0)
#define RTAX_FEATURE_SACK (1 << 1)
#define RTAX_FEATURE_TIMESTAMP (1 << 2)
#define RTAX_FEATURE_ALLFRAG (1 << 3)

#define RTAX_FEATURE_MASK                                                \
	(RTAX_FEATURE_ECN | RTAX_FEATURE_SACK | RTAX_FEATURE_TIMESTAMP | \
	    RTAX_FEATURE_ALLFRAG)

#ifndef _KERNEL

/*
 * RTAX_* space clashes with rtsock namespace.
 * Use NL_RTAX_ prefix in the kernel and map to
 * RTAX_ for userland.
 */
#define RTAX_UNSPEC		NL_RTAX_UNSPEC
#define RTAX_LOCK		NL_RTAX_LOCK
#define RTAX_MTU		NL_RTAX_MTU
#define RTAX_WINDOW		NL_RTAX_WINDOW
#define RTAX_RTT		NL_RTAX_RTT
#define RTAX_RTTVAR		NL_RTAX_RTTVAR
#define RTAX_SSTHRESH		NL_RTAX_SSTHRESH
#define RTAX_CWND		NL_RTAX_CWND
#define RTAX_ADVMSS		NL_RTAX_ADVMSS
#define RTAX_REORDERING		NL_RTAX_REORDERING
#define RTAX_HOPLIMIT		NL_RTAX_HOPLIMIT
#define RTAX_INITCWND		NL_RTAX_INITCWND
#define RTAX_FEATURES		NL_RTAX_FEATURES
#define RTAX_RTO_MIN		NL_RTAX_RTO_MIN
#define RTAX_INITRWND		NL_RTAX_INITRWND
#define RTAX_QUICKACK		NL_RTAX_QUICKACK
#define RTAX_CC_ALGO		NL_RTAX_CC_ALGO
#define RTAX_FASTOPEN_NO_COOKIE	NL_RTAX_FASTOPEN_NO_COOKIE
#endif

/*
 * RTA_MULTIPATH consists of an array of rtnexthop structures.
 * Each rtnexthop structure contains RTA_GATEWAY or RTA_VIA
 * attribute following the header.
 */
struct rtnexthop {
	unsigned short		rtnh_len;
	unsigned char		rtnh_flags;
	unsigned char		rtnh_hops;	/* nexthop weight */
	int			rtnh_ifindex;
};

/* rtnh_flags */
#define RTNH_F_DEAD		0x01	/* not supported */
#define RTNH_F_PERVASIVE	0x02	/* not supported */
#define RTNH_F_ONLINK		0x04	/* not supported */
#define RTNH_F_OFFLOAD		0x08	/* not supported */
#define RTNH_F_LINKDOWN		0x10	/* not supported */
#define RTNH_F_UNRESOLVED	0x20	/* not supported */
#define RTNH_F_TRAP		0x40	/* not supported */

#define RTNH_COMPARE_MASK	(RTNH_F_DEAD | RTNH_F_LINKDOWN | \
				 RTNH_F_OFFLOAD | RTNH_F_TRAP)

/* Macros to handle hexthops */
#define	RTNH_ALIGNTO		NL_ITEM_ALIGN_SIZE
#define	RTNH_ALIGN(_len)	NL_ITEM_ALIGN(_len)
#define	RTNH_HDRLEN		((int)sizeof(struct rtnexthop))
#define	_RTNH_LEN(_nh)		((int)(_nh)->rtnh_len)
#define	_RTNH_ALIGNED_LEN(_nh)	RTNH_ALIGN(_RTNH_LEN(_nh))
#define	RTNH_OK(_nh, _len)	NL_ITEM_OK(_nh, _len, RTNH_HDRLEN, _RTNH_LEN)
#define	RTNH_NEXT(_nh)		((struct rtnexthop *)((char *)(_nh) + _RTNH_ALIGNED_LEN(_nh)))
#define	RTNH_LENGTH(_len)	(RTNH_HDRLEN + (_len))
#define	RTNH_SPACE(_len)	RTNH_ALIGN(RTNH_LENGTH(_len))
#define	RTNH_DATA(_nh)		((struct rtattr *)NL_ITEM_DATA(_nh, RTNH_HDRLEN))

struct rtgenmsg {
	unsigned char rtgen_family;
};

#endif