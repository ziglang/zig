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
#ifndef _IP6T_OPTS_H
#define _IP6T_OPTS_H
#include <linux/types.h>
#define IP6T_OPTS_OPTSNR 16
struct ip6t_opts {
  __u32 hdrlen;
  __u8 flags;
  __u8 invflags;
  __u16 opts[IP6T_OPTS_OPTSNR];
  __u8 optsnr;
};
#define IP6T_OPTS_LEN 0x01
#define IP6T_OPTS_OPTS 0x02
#define IP6T_OPTS_NSTRICT 0x04
#define IP6T_OPTS_INV_LEN 0x01
#define IP6T_OPTS_INV_MASK 0x01
#endif