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
#ifndef __LINUX_BRIDGE_EBT_IP6_H
#define __LINUX_BRIDGE_EBT_IP6_H
#include <linux/types.h>
#include <linux/in6.h>
#define EBT_IP6_SOURCE 0x01
#define EBT_IP6_DEST 0x02
#define EBT_IP6_TCLASS 0x04
#define EBT_IP6_PROTO 0x08
#define EBT_IP6_SPORT 0x10
#define EBT_IP6_DPORT 0x20
#define EBT_IP6_ICMP6 0x40
#define EBT_IP6_MASK (EBT_IP6_SOURCE | EBT_IP6_DEST | EBT_IP6_TCLASS | EBT_IP6_PROTO | EBT_IP6_SPORT | EBT_IP6_DPORT | EBT_IP6_ICMP6)
#define EBT_IP6_MATCH "ip6"
struct ebt_ip6_info {
  struct in6_addr saddr;
  struct in6_addr daddr;
  struct in6_addr smsk;
  struct in6_addr dmsk;
  __u8 tclass;
  __u8 protocol;
  __u8 bitmask;
  __u8 invflags;
  union {
    __u16 sport[2];
    __u8 icmpv6_type[2];
  };
  union {
    __u16 dport[2];
    __u8 icmpv6_code[2];
  };
};
#endif