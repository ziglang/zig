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
#ifndef _IP6T_RT_H
#define _IP6T_RT_H
#include <linux/types.h>
#include <linux/in6.h>
#define IP6T_RT_HOPS 16
struct ip6t_rt {
  __u32 rt_type;
  __u32 segsleft[2];
  __u32 hdrlen;
  __u8 flags;
  __u8 invflags;
  struct in6_addr addrs[IP6T_RT_HOPS];
  __u8 addrnr;
};
#define IP6T_RT_TYP 0x01
#define IP6T_RT_SGS 0x02
#define IP6T_RT_LEN 0x04
#define IP6T_RT_RES 0x08
#define IP6T_RT_FST_MASK 0x30
#define IP6T_RT_FST 0x10
#define IP6T_RT_FST_NSTRICT 0x20
#define IP6T_RT_INV_TYP 0x01
#define IP6T_RT_INV_SGS 0x02
#define IP6T_RT_INV_LEN 0x04
#define IP6T_RT_INV_MASK 0x07
#endif