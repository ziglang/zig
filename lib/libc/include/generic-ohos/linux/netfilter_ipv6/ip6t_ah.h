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
#ifndef _IP6T_AH_H
#define _IP6T_AH_H
#include <linux/types.h>
struct ip6t_ah {
  __u32 spis[2];
  __u32 hdrlen;
  __u8 hdrres;
  __u8 invflags;
};
#define IP6T_AH_SPI 0x01
#define IP6T_AH_LEN 0x02
#define IP6T_AH_RES 0x04
#define IP6T_AH_INV_SPI 0x01
#define IP6T_AH_INV_LEN 0x02
#define IP6T_AH_INV_MASK 0x03
#endif