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
#ifndef _UAPI_LINUX_IN6_H
#define _UAPI_LINUX_IN6_H
#include <linux/types.h>
#include <linux/libc-compat.h>
#if __UAPI_DEF_IN6_ADDR
struct in6_addr {
  union {
    __u8 u6_addr8[16];
#if __UAPI_DEF_IN6_ADDR_ALT
    __be16 u6_addr16[8];
    __be32 u6_addr32[4];
#endif
  } in6_u;
#define s6_addr in6_u.u6_addr8
#if __UAPI_DEF_IN6_ADDR_ALT
#define s6_addr16 in6_u.u6_addr16
#define s6_addr32 in6_u.u6_addr32
#endif
};
#endif
#if __UAPI_DEF_SOCKADDR_IN6
struct sockaddr_in6 {
  unsigned short int sin6_family;
  __be16 sin6_port;
  __be32 sin6_flowinfo;
  struct in6_addr sin6_addr;
  __u32 sin6_scope_id;
};
#endif
#if __UAPI_DEF_IPV6_MREQ
struct ipv6_mreq {
  struct in6_addr ipv6mr_multiaddr;
  int ipv6mr_ifindex;
};
#endif
#define ipv6mr_acaddr ipv6mr_multiaddr
struct in6_flowlabel_req {
  struct in6_addr flr_dst;
  __be32 flr_label;
  __u8 flr_action;
  __u8 flr_share;
  __u16 flr_flags;
  __u16 flr_expires;
  __u16 flr_linger;
  __u32 __flr_pad;
};
#define IPV6_FL_A_GET 0
#define IPV6_FL_A_PUT 1
#define IPV6_FL_A_RENEW 2
#define IPV6_FL_F_CREATE 1
#define IPV6_FL_F_EXCL 2
#define IPV6_FL_F_REFLECT 4
#define IPV6_FL_F_REMOTE 8
#define IPV6_FL_S_NONE 0
#define IPV6_FL_S_EXCL 1
#define IPV6_FL_S_PROCESS 2
#define IPV6_FL_S_USER 3
#define IPV6_FL_S_ANY 255
#define IPV6_FLOWINFO_FLOWLABEL 0x000fffff
#define IPV6_FLOWINFO_PRIORITY 0x0ff00000
#define IPV6_PRIORITY_UNCHARACTERIZED 0x0000
#define IPV6_PRIORITY_FILLER 0x0100
#define IPV6_PRIORITY_UNATTENDED 0x0200
#define IPV6_PRIORITY_RESERVED1 0x0300
#define IPV6_PRIORITY_BULK 0x0400
#define IPV6_PRIORITY_RESERVED2 0x0500
#define IPV6_PRIORITY_INTERACTIVE 0x0600
#define IPV6_PRIORITY_CONTROL 0x0700
#define IPV6_PRIORITY_8 0x0800
#define IPV6_PRIORITY_9 0x0900
#define IPV6_PRIORITY_10 0x0a00
#define IPV6_PRIORITY_11 0x0b00
#define IPV6_PRIORITY_12 0x0c00
#define IPV6_PRIORITY_13 0x0d00
#define IPV6_PRIORITY_14 0x0e00
#define IPV6_PRIORITY_15 0x0f00
#if __UAPI_DEF_IPPROTO_V6
#define IPPROTO_HOPOPTS 0
#define IPPROTO_ROUTING 43
#define IPPROTO_FRAGMENT 44
#define IPPROTO_ICMPV6 58
#define IPPROTO_NONE 59
#define IPPROTO_DSTOPTS 60
#define IPPROTO_MH 135
#endif
#define IPV6_TLV_PAD1 0
#define IPV6_TLV_PADN 1
#define IPV6_TLV_ROUTERALERT 5
#define IPV6_TLV_CALIPSO 7
#define IPV6_TLV_JUMBO 194
#define IPV6_TLV_HAO 201
#if __UAPI_DEF_IPV6_OPTIONS
#define IPV6_ADDRFORM 1
#define IPV6_2292PKTINFO 2
#define IPV6_2292HOPOPTS 3
#define IPV6_2292DSTOPTS 4
#define IPV6_2292RTHDR 5
#define IPV6_2292PKTOPTIONS 6
#define IPV6_CHECKSUM 7
#define IPV6_2292HOPLIMIT 8
#define IPV6_NEXTHOP 9
#define IPV6_AUTHHDR 10
#define IPV6_FLOWINFO 11
#define IPV6_UNICAST_HOPS 16
#define IPV6_MULTICAST_IF 17
#define IPV6_MULTICAST_HOPS 18
#define IPV6_MULTICAST_LOOP 19
#define IPV6_ADD_MEMBERSHIP 20
#define IPV6_DROP_MEMBERSHIP 21
#define IPV6_ROUTER_ALERT 22
#define IPV6_MTU_DISCOVER 23
#define IPV6_MTU 24
#define IPV6_RECVERR 25
#define IPV6_V6ONLY 26
#define IPV6_JOIN_ANYCAST 27
#define IPV6_LEAVE_ANYCAST 28
#define IPV6_MULTICAST_ALL 29
#define IPV6_ROUTER_ALERT_ISOLATE 30
#define IPV6_RECVERR_RFC4884 31
#define IPV6_PMTUDISC_DONT 0
#define IPV6_PMTUDISC_WANT 1
#define IPV6_PMTUDISC_DO 2
#define IPV6_PMTUDISC_PROBE 3
#define IPV6_PMTUDISC_INTERFACE 4
#define IPV6_PMTUDISC_OMIT 5
#define IPV6_FLOWLABEL_MGR 32
#define IPV6_FLOWINFO_SEND 33
#define IPV6_IPSEC_POLICY 34
#define IPV6_XFRM_POLICY 35
#define IPV6_HDRINCL 36
#endif
#define IPV6_RECVPKTINFO 49
#define IPV6_PKTINFO 50
#define IPV6_RECVHOPLIMIT 51
#define IPV6_HOPLIMIT 52
#define IPV6_RECVHOPOPTS 53
#define IPV6_HOPOPTS 54
#define IPV6_RTHDRDSTOPTS 55
#define IPV6_RECVRTHDR 56
#define IPV6_RTHDR 57
#define IPV6_RECVDSTOPTS 58
#define IPV6_DSTOPTS 59
#define IPV6_RECVPATHMTU 60
#define IPV6_PATHMTU 61
#define IPV6_DONTFRAG 62
#define IPV6_RECVTCLASS 66
#define IPV6_TCLASS 67
#define IPV6_AUTOFLOWLABEL 70
#define IPV6_ADDR_PREFERENCES 72
#define IPV6_PREFER_SRC_TMP 0x0001
#define IPV6_PREFER_SRC_PUBLIC 0x0002
#define IPV6_PREFER_SRC_PUBTMP_DEFAULT 0x0100
#define IPV6_PREFER_SRC_COA 0x0004
#define IPV6_PREFER_SRC_HOME 0x0400
#define IPV6_PREFER_SRC_CGA 0x0008
#define IPV6_PREFER_SRC_NONCGA 0x0800
#define IPV6_MINHOPCOUNT 73
#define IPV6_ORIGDSTADDR 74
#define IPV6_RECVORIGDSTADDR IPV6_ORIGDSTADDR
#define IPV6_TRANSPARENT 75
#define IPV6_UNICAST_IF 76
#define IPV6_RECVFRAGSIZE 77
#define IPV6_FREEBIND 78
#endif