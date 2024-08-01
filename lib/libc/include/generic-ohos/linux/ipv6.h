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
#ifndef _UAPI_IPV6_H
#define _UAPI_IPV6_H
#include <linux/libc-compat.h>
#include <linux/types.h>
#include <linux/in6.h>
#include <asm/byteorder.h>
#define IPV6_MIN_MTU 1280
#if __UAPI_DEF_IN6_PKTINFO
struct in6_pktinfo {
  struct in6_addr ipi6_addr;
  int ipi6_ifindex;
};
#endif
#if __UAPI_DEF_IP6_MTUINFO
struct ip6_mtuinfo {
  struct sockaddr_in6 ip6m_addr;
  __u32 ip6m_mtu;
};
#endif
struct in6_ifreq {
  struct in6_addr ifr6_addr;
  __u32 ifr6_prefixlen;
  int ifr6_ifindex;
};
#define IPV6_SRCRT_STRICT 0x01
#define IPV6_SRCRT_TYPE_0 0
#define IPV6_SRCRT_TYPE_2 2
#define IPV6_SRCRT_TYPE_3 3
#define IPV6_SRCRT_TYPE_4 4
struct ipv6_rt_hdr {
  __u8 nexthdr;
  __u8 hdrlen;
  __u8 type;
  __u8 segments_left;
};
struct ipv6_opt_hdr {
  __u8 nexthdr;
  __u8 hdrlen;
} __attribute__((packed));
#define ipv6_destopt_hdr ipv6_opt_hdr
#define ipv6_hopopt_hdr ipv6_opt_hdr
#define IPV6_OPT_ROUTERALERT_MLD 0x0000
struct rt0_hdr {
  struct ipv6_rt_hdr rt_hdr;
  __u32 reserved;
  struct in6_addr addr[0];
#define rt0_type rt_hdr.type
};
struct rt2_hdr {
  struct ipv6_rt_hdr rt_hdr;
  __u32 reserved;
  struct in6_addr addr;
#define rt2_type rt_hdr.type
};
struct ipv6_destopt_hao {
  __u8 type;
  __u8 length;
  struct in6_addr addr;
} __attribute__((packed));
struct ipv6hdr {
#ifdef __LITTLE_ENDIAN_BITFIELD
  __u8 priority : 4, version : 4;
#elif defined(__BIG_ENDIAN_BITFIELD)
  __u8 version : 4, priority : 4;
#else
#error "Please fix <asm/byteorder.h>"
#endif
  __u8 flow_lbl[3];
  __be16 payload_len;
  __u8 nexthdr;
  __u8 hop_limit;
  struct in6_addr saddr;
  struct in6_addr daddr;
};
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
  DEVCONF_MAX
};
#endif