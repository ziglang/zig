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
#ifndef __LINUX_BRIDGE_EBT_IP_H
#define __LINUX_BRIDGE_EBT_IP_H
#include <linux/types.h>
#define EBT_IP_SOURCE 0x01
#define EBT_IP_DEST 0x02
#define EBT_IP_TOS 0x04
#define EBT_IP_PROTO 0x08
#define EBT_IP_SPORT 0x10
#define EBT_IP_DPORT 0x20
#define EBT_IP_ICMP 0x40
#define EBT_IP_IGMP 0x80
#define EBT_IP_MASK (EBT_IP_SOURCE | EBT_IP_DEST | EBT_IP_TOS | EBT_IP_PROTO | EBT_IP_SPORT | EBT_IP_DPORT | EBT_IP_ICMP | EBT_IP_IGMP)
#define EBT_IP_MATCH "ip"
struct ebt_ip_info {
  __be32 saddr;
  __be32 daddr;
  __be32 smsk;
  __be32 dmsk;
  __u8 tos;
  __u8 protocol;
  __u8 bitmask;
  __u8 invflags;
  union {
    __u16 sport[2];
    __u8 icmp_type[2];
    __u8 igmp_type[2];
  };
  union {
    __u16 dport[2];
    __u8 icmp_code[2];
  };
};
#endif