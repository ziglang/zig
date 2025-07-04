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
 * Interface-related (RTM_<NEW|DEL|GET|SET>LINK) message header and attributes.
 */

#ifndef _NETLINK_ROUTE_INTERFACE_H_
#define _NETLINK_ROUTE_INTERFACE_H_

/* Base header for all of the relevant messages */
struct ifinfomsg {
	unsigned char	ifi_family;	/* not used */
	unsigned char	__ifi_pad;
	unsigned short	ifi_type;	/* ARPHRD_* */
	int		ifi_index;	/* Inteface index */
	unsigned	ifi_flags;	/* IFF_* flags */
	unsigned	ifi_change;	/* IFF_* change mask */
};

/* Linux-specific link-level state flag */
#define	IFF_LOWER_UP	IFF_NETLINK_1

#ifndef _KERNEL
/* Compatilbility helpers */
#define	_IFINFO_HDRLEN		((int)sizeof(struct ifinfomsg))
#define	IFLA_RTA(_ifi)		((struct rtattr *)NL_ITEM_DATA(_ifi, _IFINFO_HDRLEN))
#define	IFLA_PAYLOAD(_ifi)	NLMSG_PAYLOAD(_ifi, _IFINFO_HDRLEN)
#endif

enum {
	IFLA_UNSPEC	= 0,
	IFLA_ADDRESS	= 1,	/* binary: Link-level address (MAC) */
#define	IFLA_ADDRESS IFLA_ADDRESS
	IFLA_BROADCAST	= 2,	/* binary: link-level broadcast address */
#define	IFLA_BROADCAST IFLA_BROADCAST
	IFLA_IFNAME	= 3,	/* string: Interface name */
#define	IFLA_IFNAME IFLA_IFNAME
	IFLA_MTU	= 4,	/* u32: Current interface L3 mtu */
#define	IFLA_MTU IFLA_MTU
	IFLA_LINK	= 5,	/* u32: interface index */
#define	IFLA_LINK IFLA_LINK
	IFLA_QDISC	= 6,	/* string: Queing policy (not supported) */
#define	IFLA_QDISC IFLA_QDISC
	IFLA_STATS	= 7,	/* Interface counters */
#define	IFLA_STATS IFLA_STATS
	IFLA_COST	= 8,	/* not supported */
#define IFLA_COST IFLA_COST
	IFLA_PRIORITY	= 9,	/* not supported */
#define IFLA_PRIORITY IFLA_PRIORITY
	IFLA_MASTER	= 10,	/* u32: parent interface ifindex */
#define IFLA_MASTER IFLA_MASTER
	IFLA_WIRELESS	= 11,	/* not supported */
#define IFLA_WIRELESS IFLA_WIRELESS
	IFLA_PROTINFO	= 12,	/* protocol-specific data */
#define IFLA_PROTINFO IFLA_PROTINFO
	IFLA_TXQLEN	= 13,	/* u32: transmit queue length */
#define IFLA_TXQLEN IFLA_TXQLEN
	IFLA_MAP	= 14,	/* not supported */
#define IFLA_MAP IFLA_MAP
	IFLA_WEIGHT	= 15,	/* not supported */
#define IFLA_WEIGHT IFLA_WEIGHT
	IFLA_OPERSTATE	= 16,	/* u8: ifOperStatus per RFC 2863 */
#define	IFLA_OPERSTATE IFLA_OPERSTATE
	IFLA_LINKMODE	= 17,	/* u8: ifmedia (not supported) */
#define	IFLA_LINKMODE IFLA_LINKMODE
	IFLA_LINKINFO	= 18,	/* nested: IFLA_INFO_ */
#define IFLA_LINKINFO IFLA_LINKINFO
	IFLA_NET_NS_PID	= 19,	/* u32: vnet id (not supported) */
#define	IFLA_NET_NS_PID IFLA_NET_NS_PID
	IFLA_IFALIAS	= 20,	/* string: interface description */
#define	IFLA_IFALIAS IFLA_IFALIAS
	IFLA_NUM_VF	= 21,	/* not supported */
#define	IFLA_NUM_VF IFLA_NUM_VF
	IFLA_VFINFO_LIST= 22,	/* not supported */
#define	IFLA_VFINFO_LIST IFLA_VFINFO_LIST
	IFLA_STATS64	= 23,	/* rtnl_link_stats64: iface stats */
#define	IFLA_STATS64 IFLA_STATS64
	IFLA_VF_PORTS,
	IFLA_PORT_SELF,
	IFLA_AF_SPEC,
	IFLA_GROUP, /* Group the device belongs to */
	IFLA_NET_NS_FD,
	IFLA_EXT_MASK,	  /* Extended info mask, VFs, etc */
	IFLA_PROMISCUITY, /* Promiscuity count: > 0 means acts PROMISC */
#define IFLA_PROMISCUITY IFLA_PROMISCUITY
	IFLA_NUM_TX_QUEUES,
	IFLA_NUM_RX_QUEUES,
	IFLA_CARRIER,
	IFLA_PHYS_PORT_ID,
	IFLA_CARRIER_CHANGES,
	IFLA_PHYS_SWITCH_ID,
	IFLA_LINK_NETNSID,
	IFLA_PHYS_PORT_NAME,
	IFLA_PROTO_DOWN,
	IFLA_GSO_MAX_SEGS,
	IFLA_GSO_MAX_SIZE,
	IFLA_PAD,
	IFLA_XDP,
	IFLA_EVENT,
	IFLA_NEW_NETNSID,
	IFLA_IF_NETNSID,
	IFLA_TARGET_NETNSID = IFLA_IF_NETNSID, /* new alias */
	IFLA_CARRIER_UP_COUNT,
	IFLA_CARRIER_DOWN_COUNT,
	IFLA_NEW_IFINDEX,
	IFLA_MIN_MTU,
	IFLA_MAX_MTU,
	IFLA_PROP_LIST,
	IFLA_ALT_IFNAME, /* Alternative ifname */
	IFLA_PERM_ADDRESS,
	IFLA_PROTO_DOWN_REASON,
	IFLA_PARENT_DEV_NAME,
	IFLA_PARENT_DEV_BUS_NAME,
	IFLA_GRO_MAX_SIZE,
	IFLA_TSO_MAX_SEGS,
	IFLA_ALLMULTI,
	IFLA_DEVLINK_PORT,
	IFLA_GSO_IPV4_MAX_SIZE,
	IFLA_GRO_IPV4_MAX_SIZE,
	IFLA_FREEBSD,
	__IFLA_MAX
};
#define IFLA_MAX (__IFLA_MAX - 1)

enum {
	IFLAF_UNSPEC		= 0,
	IFLAF_ORIG_IFNAME	= 1,	/* string, original interface name at creation */
	IFLAF_ORIG_HWADDR	= 2,	/* binary, original hardware address */
	IFLAF_CAPS		= 3,	/* bitset, interface capabilities */
	__IFLAF_MAX
};
#define IFLAF_MAX (__IFLAF_MAX - 1)

/*
 * Attributes that can be used as filters:
 *  IFLA_IFNAME, IFLA_GROUP, IFLA_ALT_IFNAME
 * Headers that can be used as filters:
 *  ifi_index, ifi_type
 */

/*
 * IFLA_OPERSTATE.
 * The values below represent the possible
 * states of ifOperStatus defined by RFC 2863
 */
enum {
	IF_OPER_UNKNOWN		= 0, /* status can not be determined */
	IF_OPER_NOTPRESENT	= 1, /* some (hardware) component not present */
	IF_OPER_DOWN		= 2, /* down */
	IF_OPER_LOWERLAYERDOWN	= 3, /* some lower-level interface is down */
	IF_OPER_TESTING		= 4, /* in some test mode */
	IF_OPER_DORMANT		= 5, /* "up" but waiting for some condition (802.1X) */
	IF_OPER_UP		= 6, /* ready to pass packets */
};

/* IFLA_STATS */
struct rtnl_link_stats {
	uint32_t rx_packets;	/* total RX packets (IFCOUNTER_IPACKETS) */
	uint32_t tx_packets;	/* total TX packets (IFCOUNTER_OPACKETS) */
	uint32_t rx_bytes;	/* total RX bytes (IFCOUNTER_IBYTES) */
	uint32_t tx_bytes;	/* total TX bytes (IFCOUNTER_OBYTES) */
	uint32_t rx_errors;	/* RX errors (IFCOUNTER_IERRORS) */
	uint32_t tx_errors;	/* RX errors (IFCOUNTER_OERRORS) */
	uint32_t rx_dropped;	/* RX drop (no space in ring/no bufs) (IFCOUNTER_IQDROPS) */
	uint32_t tx_dropped;	/* TX drop (IFCOUNTER_OQDROPS) */
	uint32_t multicast;	/* RX multicast packets (IFCOUNTER_IMCASTS) */
	uint32_t collisions;	/* not supported */
	uint32_t rx_length_errors;	/* not supported */
	uint32_t rx_over_errors;	/* not supported */
	uint32_t rx_crc_errors;		/* not supported */
	uint32_t rx_frame_errors;	/* not supported */
	uint32_t rx_fifo_errors;	/* not supported */
	uint32_t rx_missed_errors;	/* not supported */
	uint32_t tx_aborted_errors;	/* not supported */
	uint32_t tx_carrier_errors;	/* not supported */
	uint32_t tx_fifo_errors;	/* not supported */
	uint32_t tx_heartbeat_errors;	/* not supported */
	uint32_t tx_window_errors;	/* not supported */
	uint32_t rx_compressed;		/* not supported */
	uint32_t tx_compressed;		/* not supported */
	uint32_t rx_nohandler;	/* dropped due to no proto handler (IFCOUNTER_NOPROTO) */
};

/* IFLA_STATS64 */
struct rtnl_link_stats64 {
	uint64_t rx_packets;	/* total RX packets (IFCOUNTER_IPACKETS) */
	uint64_t tx_packets;	/* total TX packets (IFCOUNTER_OPACKETS) */
	uint64_t rx_bytes;	/* total RX bytes (IFCOUNTER_IBYTES) */
	uint64_t tx_bytes;	/* total TX bytes (IFCOUNTER_OBYTES) */
	uint64_t rx_errors;	/* RX errors (IFCOUNTER_IERRORS) */
	uint64_t tx_errors;	/* RX errors (IFCOUNTER_OERRORS) */
	uint64_t rx_dropped;	/* RX drop (no space in ring/no bufs) (IFCOUNTER_IQDROPS) */
	uint64_t tx_dropped;	/* TX drop (IFCOUNTER_OQDROPS) */
	uint64_t multicast;	/* RX multicast packets (IFCOUNTER_IMCASTS) */
	uint64_t collisions;	/* not supported */
	uint64_t rx_length_errors;	/* not supported */
	uint64_t rx_over_errors;	/* not supported */
	uint64_t rx_crc_errors;		/* not supported */
	uint64_t rx_frame_errors;	/* not supported */
	uint64_t rx_fifo_errors;	/* not supported */
	uint64_t rx_missed_errors;	/* not supported */
	uint64_t tx_aborted_errors;	/* not supported */
	uint64_t tx_carrier_errors;	/* not supported */
	uint64_t tx_fifo_errors;	/* not supported */
	uint64_t tx_heartbeat_errors;	/* not supported */
	uint64_t tx_window_errors;	/* not supported */
	uint64_t rx_compressed;		/* not supported */
	uint64_t tx_compressed;		/* not supported */
	uint64_t rx_nohandler;	/* dropped due to no proto handler (IFCOUNTER_NOPROTO) */
};

/* IFLA_LINKINFO child nlattr types */
enum {
	IFLA_INFO_UNSPEC,
	IFLA_INFO_KIND		= 1, /* string, link type ("vlan") */
	IFLA_INFO_DATA		= 2, /* Per-link-type custom data */
	IFLA_INFO_XSTATS	= 3,
	IFLA_INFO_SLAVE_KIND	= 4,
	IFLA_INFO_SLAVE_DATA	= 5,
	__IFLA_INFO_MAX,
};
#define IFLA_INFO_MAX	(__IFLA_INFO_MAX - 1)

/* IFLA_INFO_DATA vlan attributes */
enum {
	IFLA_VLAN_UNSPEC,
	IFLA_VLAN_ID,
	IFLA_VLAN_FLAGS,
	IFLA_VLAN_EGRESS_QOS,
	IFLA_VLAN_INGRESS_QOS,
	IFLA_VLAN_PROTOCOL,
	__IFLA_VLAN_MAX,
};

#define IFLA_VLAN_MAX	(__IFLA_VLAN_MAX - 1)
struct ifla_vlan_flags {
	uint32_t flags;
	uint32_t mask;
};

#endif