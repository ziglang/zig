/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _IPV6_H
#define _IPV6_H

#include <linux/libc-compat.h>
#include <linux/types.h>
#include <linux/stddef.h>
#include <linux/in6.h>
#include <asm/byteorder.h>

/* The latest drafts declared increase in minimal mtu up to 1280. */

#define IPV6_MIN_MTU	1280

/*
 *	Advanced API
 *	source interface/address selection, source routing, etc...
 *	*under construction*
 */

#if __UAPI_DEF_IN6_PKTINFO
struct in6_pktinfo {
	struct in6_addr	ipi6_addr;
	int		ipi6_ifindex;
};
#endif

#if __UAPI_DEF_IP6_MTUINFO
struct ip6_mtuinfo {
	struct sockaddr_in6	ip6m_addr;
	__u32			ip6m_mtu;
};
#endif

struct in6_ifreq {
	struct in6_addr	ifr6_addr;
	__u32		ifr6_prefixlen;
	int		ifr6_ifindex; 
};

#define IPV6_SRCRT_STRICT	0x01	/* Deprecated; will be removed */
#define IPV6_SRCRT_TYPE_0	0	/* Deprecated; will be removed */
#define IPV6_SRCRT_TYPE_2	2	/* IPv6 type 2 Routing Header	*/
#define IPV6_SRCRT_TYPE_3	3	/* RPL Segment Routing with IPv6 */
#define IPV6_SRCRT_TYPE_4	4	/* Segment Routing with IPv6 */

/*
 *	routing header
 */
struct ipv6_rt_hdr {
	__u8		nexthdr;
	__u8		hdrlen;
	__u8		type;
	__u8		segments_left;

	/*
	 *	type specific data
	 *	variable length field
	 */
};


struct ipv6_opt_hdr {
	__u8 		nexthdr;
	__u8 		hdrlen;
	/* 
	 * TLV encoded option data follows.
	 */
} __attribute__((packed));	/* required for some archs */

#define ipv6_destopt_hdr ipv6_opt_hdr
#define ipv6_hopopt_hdr  ipv6_opt_hdr

/* Router Alert option values (RFC2711) */
#define IPV6_OPT_ROUTERALERT_MLD	0x0000	/* MLD(RFC2710) */

/*
 *	routing header type 0 (used in cmsghdr struct)
 */

struct rt0_hdr {
	struct ipv6_rt_hdr	rt_hdr;
	__u32			reserved;
	struct in6_addr		addr[0];

#define rt0_type		rt_hdr.type
};

/*
 *	routing header type 2
 */

struct rt2_hdr {
	struct ipv6_rt_hdr	rt_hdr;
	__u32			reserved;
	struct in6_addr		addr;

#define rt2_type		rt_hdr.type
};

/*
 *	home address option in destination options header
 */

struct ipv6_destopt_hao {
	__u8			type;
	__u8			length;
	struct in6_addr		addr;
} __attribute__((packed));

/*
 *	IPv6 fixed header
 *
 *	BEWARE, it is incorrect. The first 4 bits of flow_lbl
 *	are glued to priority now, forming "class".
 */

struct ipv6hdr {
#if defined(__LITTLE_ENDIAN_BITFIELD)
	__u8			priority:4,
				version:4;
#elif defined(__BIG_ENDIAN_BITFIELD)
	__u8			version:4,
				priority:4;
#else
#error	"Please fix <asm/byteorder.h>"
#endif
	__u8			flow_lbl[3];

	__be16			payload_len;
	__u8			nexthdr;
	__u8			hop_limit;

	__struct_group(/* no tag */, addrs, /* no attrs */,
		struct	in6_addr	saddr;
		struct	in6_addr	daddr;
	);
};


/* index values for the variables in ipv6_devconf */
enum {
	DEVCONF_FORWARDING = 0,
	DEVCONF_HOPLIMIT,
	DEVCONF_MTU6,
	DEVCONF_ACCEPT_RA,
	DEVCONF_ACCEPT_REDIRECTS,
	DEVCONF_AUTOCONF,
	DEVCONF_DAD_TRANSMITS,
	DEVCONF_RTR_SOLICITS,
	DEVCONF_RTR_SOLICIT_INTERVAL,
	DEVCONF_RTR_SOLICIT_DELAY,
	DEVCONF_USE_TEMPADDR,
	DEVCONF_TEMP_VALID_LFT,
	DEVCONF_TEMP_PREFERED_LFT,
	DEVCONF_REGEN_MAX_RETRY,
	DEVCONF_MAX_DESYNC_FACTOR,
	DEVCONF_MAX_ADDRESSES,
	DEVCONF_FORCE_MLD_VERSION,
	DEVCONF_ACCEPT_RA_DEFRTR,
	DEVCONF_ACCEPT_RA_PINFO,
	DEVCONF_ACCEPT_RA_RTR_PREF,
	DEVCONF_RTR_PROBE_INTERVAL,
	DEVCONF_ACCEPT_RA_RT_INFO_MAX_PLEN,
	DEVCONF_PROXY_NDP,
	DEVCONF_OPTIMISTIC_DAD,
	DEVCONF_ACCEPT_SOURCE_ROUTE,
	DEVCONF_MC_FORWARDING,
	DEVCONF_DISABLE_IPV6,
	DEVCONF_ACCEPT_DAD,
	DEVCONF_FORCE_TLLAO,
	DEVCONF_NDISC_NOTIFY,
	DEVCONF_MLDV1_UNSOLICITED_REPORT_INTERVAL,
	DEVCONF_MLDV2_UNSOLICITED_REPORT_INTERVAL,
	DEVCONF_SUPPRESS_FRAG_NDISC,
	DEVCONF_ACCEPT_RA_FROM_LOCAL,
	DEVCONF_USE_OPTIMISTIC,
	DEVCONF_ACCEPT_RA_MTU,
	DEVCONF_STABLE_SECRET,
	DEVCONF_USE_OIF_ADDRS_ONLY,
	DEVCONF_ACCEPT_RA_MIN_HOP_LIMIT,
	DEVCONF_IGNORE_ROUTES_WITH_LINKDOWN,
	DEVCONF_DROP_UNICAST_IN_L2_MULTICAST,
	DEVCONF_DROP_UNSOLICITED_NA,
	DEVCONF_KEEP_ADDR_ON_DOWN,
	DEVCONF_RTR_SOLICIT_MAX_INTERVAL,
	DEVCONF_SEG6_ENABLED,
	DEVCONF_SEG6_REQUIRE_HMAC,
	DEVCONF_ENHANCED_DAD,
	DEVCONF_ADDR_GEN_MODE,
	DEVCONF_DISABLE_POLICY,
	DEVCONF_ACCEPT_RA_RT_INFO_MIN_PLEN,
	DEVCONF_NDISC_TCLASS,
	DEVCONF_RPL_SEG_ENABLED,
	DEVCONF_RA_DEFRTR_METRIC,
	DEVCONF_IOAM6_ENABLED,
	DEVCONF_IOAM6_ID,
	DEVCONF_IOAM6_ID_WIDE,
	DEVCONF_NDISC_EVICT_NOCARRIER,
	DEVCONF_ACCEPT_UNTRACKED_NA,
	DEVCONF_MAX
};


#endif /* _IPV6_H */