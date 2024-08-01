/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _UAPI__LINUX_RTNETLINK_H
#define _UAPI__LINUX_RTNETLINK_H
#include <linux/types.h>
#include <linux/netlink.h>
#include <linux/if_link.h>
#include <linux/if_addr.h>
#include <linux/neighbour.h>
#define RTNL_FAMILY_IPMR 128
#define RTNL_FAMILY_IP6MR 129
#define RTNL_FAMILY_MAX 129
enum {
  RTM_BASE = 16,
#define RTM_BASE RTM_BASE
  RTM_NEWLINK = 16,
#define RTM_NEWLINK RTM_NEWLINK
  RTM_DELLINK,
#define RTM_DELLINK RTM_DELLINK
  RTM_GETLINK,
#define RTM_GETLINK RTM_GETLINK
  RTM_SETLINK,
#define RTM_SETLINK RTM_SETLINK
  RTM_NEWADDR = 20,
#define RTM_NEWADDR RTM_NEWADDR
  RTM_DELADDR,
#define RTM_DELADDR RTM_DELADDR
  RTM_GETADDR,
#define RTM_GETADDR RTM_GETADDR
  RTM_NEWROUTE = 24,
#define RTM_NEWROUTE RTM_NEWROUTE
  RTM_DELROUTE,
#define RTM_DELROUTE RTM_DELROUTE
  RTM_GETROUTE,
#define RTM_GETROUTE RTM_GETROUTE
  RTM_NEWNEIGH = 28,
#define RTM_NEWNEIGH RTM_NEWNEIGH
  RTM_DELNEIGH,
#define RTM_DELNEIGH RTM_DELNEIGH
  RTM_GETNEIGH,
#define RTM_GETNEIGH RTM_GETNEIGH
  RTM_NEWRULE = 32,
#define RTM_NEWRULE RTM_NEWRULE
  RTM_DELRULE,
#define RTM_DELRULE RTM_DELRULE
  RTM_GETRULE,
#define RTM_GETRULE RTM_GETRULE
  RTM_NEWQDISC = 36,
#define RTM_NEWQDISC RTM_NEWQDISC
  RTM_DELQDISC,
#define RTM_DELQDISC RTM_DELQDISC
  RTM_GETQDISC,
#define RTM_GETQDISC RTM_GETQDISC
  RTM_NEWTCLASS = 40,
#define RTM_NEWTCLASS RTM_NEWTCLASS
  RTM_DELTCLASS,
#define RTM_DELTCLASS RTM_DELTCLASS
  RTM_GETTCLASS,
#define RTM_GETTCLASS RTM_GETTCLASS
  RTM_NEWTFILTER = 44,
#define RTM_NEWTFILTER RTM_NEWTFILTER
  RTM_DELTFILTER,
#define RTM_DELTFILTER RTM_DELTFILTER
  RTM_GETTFILTER,
#define RTM_GETTFILTER RTM_GETTFILTER
  RTM_NEWACTION = 48,
#define RTM_NEWACTION RTM_NEWACTION
  RTM_DELACTION,
#define RTM_DELACTION RTM_DELACTION
  RTM_GETACTION,
#define RTM_GETACTION RTM_GETACTION
  RTM_NEWPREFIX = 52,
#define RTM_NEWPREFIX RTM_NEWPREFIX
  RTM_GETMULTICAST = 58,
#define RTM_GETMULTICAST RTM_GETMULTICAST
  RTM_GETANYCAST = 62,
#define RTM_GETANYCAST RTM_GETANYCAST
  RTM_NEWNEIGHTBL = 64,
#define RTM_NEWNEIGHTBL RTM_NEWNEIGHTBL
  RTM_GETNEIGHTBL = 66,
#define RTM_GETNEIGHTBL RTM_GETNEIGHTBL
  RTM_SETNEIGHTBL,
#define RTM_SETNEIGHTBL RTM_SETNEIGHTBL
  RTM_NEWNDUSEROPT = 68,
#define RTM_NEWNDUSEROPT RTM_NEWNDUSEROPT
  RTM_NEWADDRLABEL = 72,
#define RTM_NEWADDRLABEL RTM_NEWADDRLABEL
  RTM_DELADDRLABEL,
#define RTM_DELADDRLABEL RTM_DELADDRLABEL
  RTM_GETADDRLABEL,
#define RTM_GETADDRLABEL RTM_GETADDRLABEL
  RTM_GETDCB = 78,
#define RTM_GETDCB RTM_GETDCB
  RTM_SETDCB,
#define RTM_SETDCB RTM_SETDCB
  RTM_NEWNETCONF = 80,
#define RTM_NEWNETCONF RTM_NEWNETCONF
  RTM_DELNETCONF,
#define RTM_DELNETCONF RTM_DELNETCONF
  RTM_GETNETCONF = 82,
#define RTM_GETNETCONF RTM_GETNETCONF
  RTM_NEWMDB = 84,
#define RTM_NEWMDB RTM_NEWMDB
  RTM_DELMDB = 85,
#define RTM_DELMDB RTM_DELMDB
  RTM_GETMDB = 86,
#define RTM_GETMDB RTM_GETMDB
  RTM_NEWNSID = 88,
#define RTM_NEWNSID RTM_NEWNSID
  RTM_DELNSID = 89,
#define RTM_DELNSID RTM_DELNSID
  RTM_GETNSID = 90,
#define RTM_GETNSID RTM_GETNSID
  RTM_NEWSTATS = 92,
#define RTM_NEWSTATS RTM_NEWSTATS
  RTM_GETSTATS = 94,
#define RTM_GETSTATS RTM_GETSTATS
  RTM_NEWCACHEREPORT = 96,
#define RTM_NEWCACHEREPORT RTM_NEWCACHEREPORT
  RTM_NEWCHAIN = 100,
#define RTM_NEWCHAIN RTM_NEWCHAIN
  RTM_DELCHAIN,
#define RTM_DELCHAIN RTM_DELCHAIN
  RTM_GETCHAIN,
#define RTM_GETCHAIN RTM_GETCHAIN
  RTM_NEWNEXTHOP = 104,
#define RTM_NEWNEXTHOP RTM_NEWNEXTHOP
  RTM_DELNEXTHOP,
#define RTM_DELNEXTHOP RTM_DELNEXTHOP
  RTM_GETNEXTHOP,
#define RTM_GETNEXTHOP RTM_GETNEXTHOP
  RTM_NEWLINKPROP = 108,
#define RTM_NEWLINKPROP RTM_NEWLINKPROP
  RTM_DELLINKPROP,
#define RTM_DELLINKPROP RTM_DELLINKPROP
  RTM_GETLINKPROP,
#define RTM_GETLINKPROP RTM_GETLINKPROP
  RTM_NEWVLAN = 112,
#define RTM_NEWNVLAN RTM_NEWVLAN
  RTM_DELVLAN,
#define RTM_DELVLAN RTM_DELVLAN
  RTM_GETVLAN,
#define RTM_GETVLAN RTM_GETVLAN
  __RTM_MAX,
#define RTM_MAX (((__RTM_MAX + 3) & ~3) - 1)
};
#define RTM_NR_MSGTYPES (RTM_MAX + 1 - RTM_BASE)
#define RTM_NR_FAMILIES (RTM_NR_MSGTYPES >> 2)
#define RTM_FAM(cmd) (((cmd) - RTM_BASE) >> 2)
struct rtattr {
  unsigned short rta_len;
  unsigned short rta_type;
};
#define RTA_ALIGNTO 4U
#define RTA_ALIGN(len) (((len) + RTA_ALIGNTO - 1) & ~(RTA_ALIGNTO - 1))
#define RTA_OK(rta,len) ((len) >= (int) sizeof(struct rtattr) && (rta)->rta_len >= sizeof(struct rtattr) && (rta)->rta_len <= (len))
#define RTA_NEXT(rta,attrlen) ((attrlen) -= RTA_ALIGN((rta)->rta_len), (struct rtattr *) (((char *) (rta)) + RTA_ALIGN((rta)->rta_len)))
#define RTA_LENGTH(len) (RTA_ALIGN(sizeof(struct rtattr)) + (len))
#define RTA_SPACE(len) RTA_ALIGN(RTA_LENGTH(len))
#define RTA_DATA(rta) ((void *) (((char *) (rta)) + RTA_LENGTH(0)))
#define RTA_PAYLOAD(rta) ((int) ((rta)->rta_len) - RTA_LENGTH(0))
struct rtmsg {
  unsigned char rtm_family;
  unsigned char rtm_dst_len;
  unsigned char rtm_src_len;
  unsigned char rtm_tos;
  unsigned char rtm_table;
  unsigned char rtm_protocol;
  unsigned char rtm_scope;
  unsigned char rtm_type;
  unsigned rtm_flags;
};
enum {
  RTN_UNSPEC,
  RTN_UNICAST,
  RTN_LOCAL,
  RTN_BROADCAST,
  RTN_ANYCAST,
  RTN_MULTICAST,
  RTN_BLACKHOLE,
  RTN_UNREACHABLE,
  RTN_PROHIBIT,
  RTN_THROW,
  RTN_NAT,
  RTN_XRESOLVE,
  __RTN_MAX
};
#define RTN_MAX (__RTN_MAX - 1)
#define RTPROT_UNSPEC 0
#define RTPROT_REDIRECT 1
#define RTPROT_KERNEL 2
#define RTPROT_BOOT 3
#define RTPROT_STATIC 4
#define RTPROT_GATED 8
#define RTPROT_RA 9
#define RTPROT_MRT 10
#define RTPROT_ZEBRA 11
#define RTPROT_BIRD 12
#define RTPROT_DNROUTED 13
#define RTPROT_XORP 14
#define RTPROT_NTK 15
#define RTPROT_DHCP 16
#define RTPROT_MROUTED 17
#define RTPROT_KEEPALIVED 18
#define RTPROT_BABEL 42
#define RTPROT_BGP 186
#define RTPROT_ISIS 187
#define RTPROT_OSPF 188
#define RTPROT_RIP 189
#define RTPROT_EIGRP 192
enum rt_scope_t {
  RT_SCOPE_UNIVERSE = 0,
  RT_SCOPE_SITE = 200,
  RT_SCOPE_LINK = 253,
  RT_SCOPE_HOST = 254,
  RT_SCOPE_NOWHERE = 255
};
#define RTM_F_NOTIFY 0x100
#define RTM_F_CLONED 0x200
#define RTM_F_EQUALIZE 0x400
#define RTM_F_PREFIX 0x800
#define RTM_F_LOOKUP_TABLE 0x1000
#define RTM_F_FIB_MATCH 0x2000
#define RTM_F_OFFLOAD 0x4000
#define RTM_F_TRAP 0x8000
enum rt_class_t {
  RT_TABLE_UNSPEC = 0,
  RT_TABLE_COMPAT = 252,
  RT_TABLE_DEFAULT = 253,
  RT_TABLE_MAIN = 254,
  RT_TABLE_LOCAL = 255,
  RT_TABLE_MAX = 0xFFFFFFFF
};
enum rtattr_type_t {
  RTA_UNSPEC,
  RTA_DST,
  RTA_SRC,
  RTA_IIF,
  RTA_OIF,
  RTA_GATEWAY,
  RTA_PRIORITY,
  RTA_PREFSRC,
  RTA_METRICS,
  RTA_MULTIPATH,
  RTA_PROTOINFO,
  RTA_FLOW,
  RTA_CACHEINFO,
  RTA_SESSION,
  RTA_MP_ALGO,
  RTA_TABLE,
  RTA_MARK,
  RTA_MFC_STATS,
  RTA_VIA,
  RTA_NEWDST,
  RTA_PREF,
  RTA_ENCAP_TYPE,
  RTA_ENCAP,
  RTA_EXPIRES,
  RTA_PAD,
  RTA_UID,
  RTA_TTL_PROPAGATE,
  RTA_IP_PROTO,
  RTA_SPORT,
  RTA_DPORT,
  RTA_NH_ID,
  __RTA_MAX
};
#define RTA_MAX (__RTA_MAX - 1)
#define RTM_RTA(r) ((struct rtattr *) (((char *) (r)) + NLMSG_ALIGN(sizeof(struct rtmsg))))
#define RTM_PAYLOAD(n) NLMSG_PAYLOAD(n, sizeof(struct rtmsg))
struct rtnexthop {
  unsigned short rtnh_len;
  unsigned char rtnh_flags;
  unsigned char rtnh_hops;
  int rtnh_ifindex;
};
#define RTNH_F_DEAD 1
#define RTNH_F_PERVASIVE 2
#define RTNH_F_ONLINK 4
#define RTNH_F_OFFLOAD 8
#define RTNH_F_LINKDOWN 16
#define RTNH_F_UNRESOLVED 32
#define RTNH_COMPARE_MASK (RTNH_F_DEAD | RTNH_F_LINKDOWN | RTNH_F_OFFLOAD)
#define RTNH_ALIGNTO 4
#define RTNH_ALIGN(len) (((len) + RTNH_ALIGNTO - 1) & ~(RTNH_ALIGNTO - 1))
#define RTNH_OK(rtnh,len) ((rtnh)->rtnh_len >= sizeof(struct rtnexthop) && ((int) (rtnh)->rtnh_len) <= (len))
#define RTNH_NEXT(rtnh) ((struct rtnexthop *) (((char *) (rtnh)) + RTNH_ALIGN((rtnh)->rtnh_len)))
#define RTNH_LENGTH(len) (RTNH_ALIGN(sizeof(struct rtnexthop)) + (len))
#define RTNH_SPACE(len) RTNH_ALIGN(RTNH_LENGTH(len))
#define RTNH_DATA(rtnh) ((struct rtattr *) (((char *) (rtnh)) + RTNH_LENGTH(0)))
struct rtvia {
  __kernel_sa_family_t rtvia_family;
  __u8 rtvia_addr[0];
};
struct rta_cacheinfo {
  __u32 rta_clntref;
  __u32 rta_lastuse;
  __s32 rta_expires;
  __u32 rta_error;
  __u32 rta_used;
#define RTNETLINK_HAVE_PEERINFO 1
  __u32 rta_id;
  __u32 rta_ts;
  __u32 rta_tsage;
};
enum {
  RTAX_UNSPEC,
#define RTAX_UNSPEC RTAX_UNSPEC
  RTAX_LOCK,
#define RTAX_LOCK RTAX_LOCK
  RTAX_MTU,
#define RTAX_MTU RTAX_MTU
  RTAX_WINDOW,
#define RTAX_WINDOW RTAX_WINDOW
  RTAX_RTT,
#define RTAX_RTT RTAX_RTT
  RTAX_RTTVAR,
#define RTAX_RTTVAR RTAX_RTTVAR
  RTAX_SSTHRESH,
#define RTAX_SSTHRESH RTAX_SSTHRESH
  RTAX_CWND,
#define RTAX_CWND RTAX_CWND
  RTAX_ADVMSS,
#define RTAX_ADVMSS RTAX_ADVMSS
  RTAX_REORDERING,
#define RTAX_REORDERING RTAX_REORDERING
  RTAX_HOPLIMIT,
#define RTAX_HOPLIMIT RTAX_HOPLIMIT
  RTAX_INITCWND,
#define RTAX_INITCWND RTAX_INITCWND
  RTAX_FEATURES,
#define RTAX_FEATURES RTAX_FEATURES
  RTAX_RTO_MIN,
#define RTAX_RTO_MIN RTAX_RTO_MIN
  RTAX_INITRWND,
#define RTAX_INITRWND RTAX_INITRWND
  RTAX_QUICKACK,
#define RTAX_QUICKACK RTAX_QUICKACK
  RTAX_CC_ALGO,
#define RTAX_CC_ALGO RTAX_CC_ALGO
  RTAX_FASTOPEN_NO_COOKIE,
#define RTAX_FASTOPEN_NO_COOKIE RTAX_FASTOPEN_NO_COOKIE
  __RTAX_MAX
};
#define RTAX_MAX (__RTAX_MAX - 1)
#define RTAX_FEATURE_ECN (1 << 0)
#define RTAX_FEATURE_SACK (1 << 1)
#define RTAX_FEATURE_TIMESTAMP (1 << 2)
#define RTAX_FEATURE_ALLFRAG (1 << 3)
#define RTAX_FEATURE_MASK (RTAX_FEATURE_ECN | RTAX_FEATURE_SACK | RTAX_FEATURE_TIMESTAMP | RTAX_FEATURE_ALLFRAG)
struct rta_session {
  __u8 proto;
  __u8 pad1;
  __u16 pad2;
  union {
    struct {
      __u16 sport;
      __u16 dport;
    } ports;
    struct {
      __u8 type;
      __u8 code;
      __u16 ident;
    } icmpt;
    __u32 spi;
  } u;
};
struct rta_mfc_stats {
  __u64 mfcs_packets;
  __u64 mfcs_bytes;
  __u64 mfcs_wrong_if;
};
struct rtgenmsg {
  unsigned char rtgen_family;
};
struct ifinfomsg {
  unsigned char ifi_family;
  unsigned char __ifi_pad;
  unsigned short ifi_type;
  int ifi_index;
  unsigned ifi_flags;
  unsigned ifi_change;
};
struct prefixmsg {
  unsigned char prefix_family;
  unsigned char prefix_pad1;
  unsigned short prefix_pad2;
  int prefix_ifindex;
  unsigned char prefix_type;
  unsigned char prefix_len;
  unsigned char prefix_flags;
  unsigned char prefix_pad3;
};
enum {
  PREFIX_UNSPEC,
  PREFIX_ADDRESS,
  PREFIX_CACHEINFO,
  __PREFIX_MAX
};
#define PREFIX_MAX (__PREFIX_MAX - 1)
struct prefix_cacheinfo {
  __u32 preferred_time;
  __u32 valid_time;
};
struct tcmsg {
  unsigned char tcm_family;
  unsigned char tcm__pad1;
  unsigned short tcm__pad2;
  int tcm_ifindex;
  __u32 tcm_handle;
  __u32 tcm_parent;
#define tcm_block_index tcm_parent
  __u32 tcm_info;
};
#define TCM_IFINDEX_MAGIC_BLOCK (0xFFFFFFFFU)
enum {
  TCA_UNSPEC,
  TCA_KIND,
  TCA_OPTIONS,
  TCA_STATS,
  TCA_XSTATS,
  TCA_RATE,
  TCA_FCNT,
  TCA_STATS2,
  TCA_STAB,
  TCA_PAD,
  TCA_DUMP_INVISIBLE,
  TCA_CHAIN,
  TCA_HW_OFFLOAD,
  TCA_INGRESS_BLOCK,
  TCA_EGRESS_BLOCK,
  TCA_DUMP_FLAGS,
  __TCA_MAX
};
#define TCA_MAX (__TCA_MAX - 1)
#define TCA_DUMP_FLAGS_TERSE (1 << 0)
#define TCA_RTA(r) ((struct rtattr *) (((char *) (r)) + NLMSG_ALIGN(sizeof(struct tcmsg))))
#define TCA_PAYLOAD(n) NLMSG_PAYLOAD(n, sizeof(struct tcmsg))
struct nduseroptmsg {
  unsigned char nduseropt_family;
  unsigned char nduseropt_pad1;
  unsigned short nduseropt_opts_len;
  int nduseropt_ifindex;
  __u8 nduseropt_icmp_type;
  __u8 nduseropt_icmp_code;
  unsigned short nduseropt_pad2;
  unsigned int nduseropt_pad3;
};
enum {
  NDUSEROPT_UNSPEC,
  NDUSEROPT_SRCADDR,
  __NDUSEROPT_MAX
};
#define NDUSEROPT_MAX (__NDUSEROPT_MAX - 1)
#define RTMGRP_LINK 1
#define RTMGRP_NOTIFY 2
#define RTMGRP_NEIGH 4
#define RTMGRP_TC 8
#define RTMGRP_IPV4_IFADDR 0x10
#define RTMGRP_IPV4_MROUTE 0x20
#define RTMGRP_IPV4_ROUTE 0x40
#define RTMGRP_IPV4_RULE 0x80
#define RTMGRP_IPV6_IFADDR 0x100
#define RTMGRP_IPV6_MROUTE 0x200
#define RTMGRP_IPV6_ROUTE 0x400
#define RTMGRP_IPV6_IFINFO 0x800
#define RTMGRP_DECnet_IFADDR 0x1000
#define RTMGRP_DECnet_ROUTE 0x4000
#define RTMGRP_IPV6_PREFIX 0x20000
enum rtnetlink_groups {
  RTNLGRP_NONE,
#define RTNLGRP_NONE RTNLGRP_NONE
  RTNLGRP_LINK,
#define RTNLGRP_LINK RTNLGRP_LINK
  RTNLGRP_NOTIFY,
#define RTNLGRP_NOTIFY RTNLGRP_NOTIFY
  RTNLGRP_NEIGH,
#define RTNLGRP_NEIGH RTNLGRP_NEIGH
  RTNLGRP_TC,
#define RTNLGRP_TC RTNLGRP_TC
  RTNLGRP_IPV4_IFADDR,
#define RTNLGRP_IPV4_IFADDR RTNLGRP_IPV4_IFADDR
  RTNLGRP_IPV4_MROUTE,
#define RTNLGRP_IPV4_MROUTE RTNLGRP_IPV4_MROUTE
  RTNLGRP_IPV4_ROUTE,
#define RTNLGRP_IPV4_ROUTE RTNLGRP_IPV4_ROUTE
  RTNLGRP_IPV4_RULE,
#define RTNLGRP_IPV4_RULE RTNLGRP_IPV4_RULE
  RTNLGRP_IPV6_IFADDR,
#define RTNLGRP_IPV6_IFADDR RTNLGRP_IPV6_IFADDR
  RTNLGRP_IPV6_MROUTE,
#define RTNLGRP_IPV6_MROUTE RTNLGRP_IPV6_MROUTE
  RTNLGRP_IPV6_ROUTE,
#define RTNLGRP_IPV6_ROUTE RTNLGRP_IPV6_ROUTE
  RTNLGRP_IPV6_IFINFO,
#define RTNLGRP_IPV6_IFINFO RTNLGRP_IPV6_IFINFO
  RTNLGRP_DECnet_IFADDR,
#define RTNLGRP_DECnet_IFADDR RTNLGRP_DECnet_IFADDR
  RTNLGRP_NOP2,
  RTNLGRP_DECnet_ROUTE,
#define RTNLGRP_DECnet_ROUTE RTNLGRP_DECnet_ROUTE
  RTNLGRP_DECnet_RULE,
#define RTNLGRP_DECnet_RULE RTNLGRP_DECnet_RULE
  RTNLGRP_NOP4,
  RTNLGRP_IPV6_PREFIX,
#define RTNLGRP_IPV6_PREFIX RTNLGRP_IPV6_PREFIX
  RTNLGRP_IPV6_RULE,
#define RTNLGRP_IPV6_RULE RTNLGRP_IPV6_RULE
  RTNLGRP_ND_USEROPT,
#define RTNLGRP_ND_USEROPT RTNLGRP_ND_USEROPT
  RTNLGRP_PHONET_IFADDR,
#define RTNLGRP_PHONET_IFADDR RTNLGRP_PHONET_IFADDR
  RTNLGRP_PHONET_ROUTE,
#define RTNLGRP_PHONET_ROUTE RTNLGRP_PHONET_ROUTE
  RTNLGRP_DCB,
#define RTNLGRP_DCB RTNLGRP_DCB
  RTNLGRP_IPV4_NETCONF,
#define RTNLGRP_IPV4_NETCONF RTNLGRP_IPV4_NETCONF
  RTNLGRP_IPV6_NETCONF,
#define RTNLGRP_IPV6_NETCONF RTNLGRP_IPV6_NETCONF
  RTNLGRP_MDB,
#define RTNLGRP_MDB RTNLGRP_MDB
  RTNLGRP_MPLS_ROUTE,
#define RTNLGRP_MPLS_ROUTE RTNLGRP_MPLS_ROUTE
  RTNLGRP_NSID,
#define RTNLGRP_NSID RTNLGRP_NSID
  RTNLGRP_MPLS_NETCONF,
#define RTNLGRP_MPLS_NETCONF RTNLGRP_MPLS_NETCONF
  RTNLGRP_IPV4_MROUTE_R,
#define RTNLGRP_IPV4_MROUTE_R RTNLGRP_IPV4_MROUTE_R
  RTNLGRP_IPV6_MROUTE_R,
#define RTNLGRP_IPV6_MROUTE_R RTNLGRP_IPV6_MROUTE_R
  RTNLGRP_NEXTHOP,
#define RTNLGRP_NEXTHOP RTNLGRP_NEXTHOP
  RTNLGRP_BRVLAN,
#define RTNLGRP_BRVLAN RTNLGRP_BRVLAN
  __RTNLGRP_MAX
};
#define RTNLGRP_MAX (__RTNLGRP_MAX - 1)
struct tcamsg {
  unsigned char tca_family;
  unsigned char tca__pad1;
  unsigned short tca__pad2;
};
enum {
  TCA_ROOT_UNSPEC,
  TCA_ROOT_TAB,
#define TCA_ACT_TAB TCA_ROOT_TAB
#define TCAA_MAX TCA_ROOT_TAB
  TCA_ROOT_FLAGS,
  TCA_ROOT_COUNT,
  TCA_ROOT_TIME_DELTA,
  __TCA_ROOT_MAX,
#define TCA_ROOT_MAX (__TCA_ROOT_MAX - 1)
};
#define TA_RTA(r) ((struct rtattr *) (((char *) (r)) + NLMSG_ALIGN(sizeof(struct tcamsg))))
#define TA_PAYLOAD(n) NLMSG_PAYLOAD(n, sizeof(struct tcamsg))
#define TCA_FLAG_LARGE_DUMP_ON (1 << 0)
#define RTEXT_FILTER_VF (1 << 0)
#define RTEXT_FILTER_BRVLAN (1 << 1)
#define RTEXT_FILTER_BRVLAN_COMPRESSED (1 << 2)
#define RTEXT_FILTER_SKIP_STATS (1 << 3)
#define RTEXT_FILTER_MRP (1 << 4)
#endif