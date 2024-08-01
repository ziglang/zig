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
#ifndef __IPV6HEADER_H
#define __IPV6HEADER_H
#include <linux/types.h>
struct ip6t_ipv6header_info {
  __u8 matchflags;
  __u8 invflags;
  __u8 modeflag;
};
#define MASK_HOPOPTS 128
#define MASK_DSTOPTS 64
#define MASK_ROUTING 32
#define MASK_FRAGMENT 16
#define MASK_AH 8
#define MASK_ESP 4
#define MASK_NONE 2
#define MASK_PROTO 1
#endif