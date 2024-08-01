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
#ifndef _UAPI_LINUX_RPL_H
#define _UAPI_LINUX_RPL_H
#include <asm/byteorder.h>
#include <linux/types.h>
#include <linux/in6.h>
struct ipv6_rpl_sr_hdr {
  __u8 nexthdr;
  __u8 hdrlen;
  __u8 type;
  __u8 segments_left;
#ifdef __LITTLE_ENDIAN_BITFIELD
  __u32 cmpre : 4, cmpri : 4, reserved : 4, pad : 4, reserved1 : 16;
#elif defined(__BIG_ENDIAN_BITFIELD)
  __u32 reserved : 20, pad : 4, cmpri : 4, cmpre : 4;
#else
#error "Please fix <asm/byteorder.h>"
#endif
  union {
    struct in6_addr addr[0];
    __u8 data[0];
  } segments;
} __attribute__((packed));
#define rpl_segaddr segments.addr
#define rpl_segdata segments.data
#endif