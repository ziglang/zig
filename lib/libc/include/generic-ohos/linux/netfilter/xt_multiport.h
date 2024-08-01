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
#ifndef _XT_MULTIPORT_H
#define _XT_MULTIPORT_H
#include <linux/types.h>
enum xt_multiport_flags {
  XT_MULTIPORT_SOURCE,
  XT_MULTIPORT_DESTINATION,
  XT_MULTIPORT_EITHER
};
#define XT_MULTI_PORTS 15
struct xt_multiport {
  __u8 flags;
  __u8 count;
  __u16 ports[XT_MULTI_PORTS];
};
struct xt_multiport_v1 {
  __u8 flags;
  __u8 count;
  __u16 ports[XT_MULTI_PORTS];
  __u8 pflags[XT_MULTI_PORTS];
  __u8 invert;
};
#endif