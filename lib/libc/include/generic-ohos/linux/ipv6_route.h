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
#ifndef _UAPI_LINUX_IPV6_ROUTE_H
#define _UAPI_LINUX_IPV6_ROUTE_H
#include <linux/types.h>
#include <linux/in6.h>
#define RTF_DEFAULT 0x00010000
#define RTF_ALLONLINK 0x00020000
#define RTF_ADDRCONF 0x00040000
#define RTF_PREFIX_RT 0x00080000
#define RTF_ANYCAST 0x00100000
#define RTF_NONEXTHOP 0x00200000
#define RTF_EXPIRES 0x00400000
#define RTF_ROUTEINFO 0x00800000
#define RTF_CACHE 0x01000000
#define RTF_FLOW 0x02000000
#define RTF_POLICY 0x04000000
#define RTF_PREF(pref) ((pref) << 27)
#define RTF_PREF_MASK 0x18000000
#define RTF_PCPU 0x40000000
#define RTF_LOCAL 0x80000000
struct in6_rtmsg {
  struct in6_addr rtmsg_dst;
  struct in6_addr rtmsg_src;
  struct in6_addr rtmsg_gateway;
  __u32 rtmsg_type;
  __u16 rtmsg_dst_len;
  __u16 rtmsg_src_len;
  __u32 rtmsg_metric;
  unsigned long rtmsg_info;
  __u32 rtmsg_flags;
  int rtmsg_ifindex;
};
#define RTMSG_NEWDEVICE 0x11
#define RTMSG_DELDEVICE 0x12
#define RTMSG_NEWROUTE 0x21
#define RTMSG_DELROUTE 0x22
#define IP6_RT_PRIO_USER 1024
#define IP6_RT_PRIO_ADDRCONF 256
#endif