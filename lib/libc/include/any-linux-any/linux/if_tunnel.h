/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _IF_TUNNEL_H_
#define _IF_TUNNEL_H_

#include <linux/types.h>
#include <linux/if.h>
#include <linux/ip.h>
#include <linux/in6.h>
#include <asm/byteorder.h>


#define SIOCGETTUNNEL   (SIOCDEVPRIVATE + 0)
#define SIOCADDTUNNEL   (SIOCDEVPRIVATE + 1)
#define SIOCDELTUNNEL   (SIOCDEVPRIVATE + 2)
#define SIOCCHGTUNNEL   (SIOCDEVPRIVATE + 3)
#define SIOCGETPRL      (SIOCDEVPRIVATE + 4)
#define SIOCADDPRL      (SIOCDEVPRIVATE + 5)
#define SIOCDELPRL      (SIOCDEVPRIVATE + 6)
#define SIOCCHGPRL      (SIOCDEVPRIVATE + 7)
#define SIOCGET6RD      (SIOCDEVPRIVATE + 8)
#define SIOCADD6RD      (SIOCDEVPRIVATE + 9)
#define SIOCDEL6RD      (SIOCDEVPRIVATE + 10)
#define SIOCCHG6RD      (SIOCDEVPRIVATE + 11)

#define GRE_CSUM	__cpu_to_be16(0x8000)
#define GRE_ROUTING	__cpu_to_be16(0x4000)
#define GRE_KEY		__cpu_to_be16(0x2000)
#define GRE_SEQ		__cpu_to_be16(0x1000)
#define GRE_STRICT	__cpu_to_be16(0x0800)
#define GRE_REC		__cpu_to_be16(0x0700)
#define GRE_ACK		__cpu_to_be16(0x0080)
#define GRE_FLAGS	__cpu_to_be16(0x0078)
#define GRE_VERSION	__cpu_to_be16(0x0007)

#define GRE_IS_CSUM(f)		((f) & GRE_CSUM)
#define GRE_IS_ROUTING(f)	((f) & GRE_ROUTING)
#define GRE_IS_KEY(f)		((f) & GRE_KEY)
#define GRE_IS_SEQ(f)		((f) & GRE_SEQ)
#define GRE_IS_STRICT(f)	((f) & GRE_STRICT)
#define GRE_IS_REC(f)		((f) & GRE_REC)
#define GRE_IS_ACK(f)		((f) & GRE_ACK)

#define GRE_VERSION_0		__cpu_to_be16(0x0000)
#define GRE_VERSION_1		__cpu_to_be16(0x0001)
#define GRE_PROTO_PPP		__cpu_to_be16(0x880b)
#define GRE_PPTP_KEY_MASK	__cpu_to_be32(0xffff)

struct ip_tunnel_parm {
	char			name[IFNAMSIZ];
	int			link;
	__be16			i_flags;
	__be16			o_flags;
	__be32			i_key;
	__be32			o_key;
	struct iphdr		iph;
};

enum {
	IFLA_IPTUN_UNSPEC,
	IFLA_IPTUN_LINK,
	IFLA_IPTUN_LOCAL,
	IFLA_IPTUN_REMOTE,
	IFLA_IPTUN_TTL,
	IFLA_IPTUN_TOS,
	IFLA_IPTUN_ENCAP_LIMIT,
	IFLA_IPTUN_FLOWINFO,
	IFLA_IPTUN_FLAGS,
	IFLA_IPTUN_PROTO,
	IFLA_IPTUN_PMTUDISC,
	IFLA_IPTUN_6RD_PREFIX,
	IFLA_IPTUN_6RD_RELAY_PREFIX,
	IFLA_IPTUN_6RD_PREFIXLEN,
	IFLA_IPTUN_6RD_RELAY_PREFIXLEN,
	IFLA_IPTUN_ENCAP_TYPE,
	IFLA_IPTUN_ENCAP_FLAGS,
	IFLA_IPTUN_ENCAP_SPORT,
	IFLA_IPTUN_ENCAP_DPORT,
	IFLA_IPTUN_COLLECT_METADATA,
	IFLA_IPTUN_FWMARK,
	__IFLA_IPTUN_MAX,
};
#define IFLA_IPTUN_MAX	(__IFLA_IPTUN_MAX - 1)

enum tunnel_encap_types {
	TUNNEL_ENCAP_NONE,
	TUNNEL_ENCAP_FOU,
	TUNNEL_ENCAP_GUE,
	TUNNEL_ENCAP_MPLS,
};

#define TUNNEL_ENCAP_FLAG_CSUM		(1<<0)
#define TUNNEL_ENCAP_FLAG_CSUM6		(1<<1)
#define TUNNEL_ENCAP_FLAG_REMCSUM	(1<<2)

/* SIT-mode i_flags */
#define	SIT_ISATAP	0x0001

struct ip_tunnel_prl {
	__be32			addr;
	__u16			flags;
	__u16			__reserved;
	__u32			datalen;
	__u32			__reserved2;
	/* data follows */
};

/* PRL flags */
#define	PRL_DEFAULT		0x0001

struct ip_tunnel_6rd {
	struct in6_addr		prefix;
	__be32			relay_prefix;
	__u16			prefixlen;
	__u16			relay_prefixlen;
};

enum {
	IFLA_GRE_UNSPEC,
	IFLA_GRE_LINK,
	IFLA_GRE_IFLAGS,
	IFLA_GRE_OFLAGS,
	IFLA_GRE_IKEY,
	IFLA_GRE_OKEY,
	IFLA_GRE_LOCAL,
	IFLA_GRE_REMOTE,
	IFLA_GRE_TTL,
	IFLA_GRE_TOS,
	IFLA_GRE_PMTUDISC,
	IFLA_GRE_ENCAP_LIMIT,
	IFLA_GRE_FLOWINFO,
	IFLA_GRE_FLAGS,
	IFLA_GRE_ENCAP_TYPE,
	IFLA_GRE_ENCAP_FLAGS,
	IFLA_GRE_ENCAP_SPORT,
	IFLA_GRE_ENCAP_DPORT,
	IFLA_GRE_COLLECT_METADATA,
	IFLA_GRE_IGNORE_DF,
	IFLA_GRE_FWMARK,
	IFLA_GRE_ERSPAN_INDEX,
	IFLA_GRE_ERSPAN_VER,
	IFLA_GRE_ERSPAN_DIR,
	IFLA_GRE_ERSPAN_HWID,
	__IFLA_GRE_MAX,
};

#define IFLA_GRE_MAX	(__IFLA_GRE_MAX - 1)

/* VTI-mode i_flags */
#define VTI_ISVTI ((__be16)0x0001)

enum {
	IFLA_VTI_UNSPEC,
	IFLA_VTI_LINK,
	IFLA_VTI_IKEY,
	IFLA_VTI_OKEY,
	IFLA_VTI_LOCAL,
	IFLA_VTI_REMOTE,
	IFLA_VTI_FWMARK,
	__IFLA_VTI_MAX,
};

#define IFLA_VTI_MAX	(__IFLA_VTI_MAX - 1)

#define TUNNEL_CSUM		__cpu_to_be16(0x01)
#define TUNNEL_ROUTING		__cpu_to_be16(0x02)
#define TUNNEL_KEY		__cpu_to_be16(0x04)
#define TUNNEL_SEQ		__cpu_to_be16(0x08)
#define TUNNEL_STRICT		__cpu_to_be16(0x10)
#define TUNNEL_REC		__cpu_to_be16(0x20)
#define TUNNEL_VERSION		__cpu_to_be16(0x40)
#define TUNNEL_NO_KEY		__cpu_to_be16(0x80)
#define TUNNEL_DONT_FRAGMENT    __cpu_to_be16(0x0100)
#define TUNNEL_OAM		__cpu_to_be16(0x0200)
#define TUNNEL_CRIT_OPT		__cpu_to_be16(0x0400)
#define TUNNEL_GENEVE_OPT	__cpu_to_be16(0x0800)
#define TUNNEL_VXLAN_OPT	__cpu_to_be16(0x1000)
#define TUNNEL_NOCACHE		__cpu_to_be16(0x2000)
#define TUNNEL_ERSPAN_OPT	__cpu_to_be16(0x4000)
#define TUNNEL_GTP_OPT		__cpu_to_be16(0x8000)

#define TUNNEL_OPTIONS_PRESENT \
		(TUNNEL_GENEVE_OPT | TUNNEL_VXLAN_OPT | TUNNEL_ERSPAN_OPT | \
		TUNNEL_GTP_OPT)

#endif /* _IF_TUNNEL_H_ */