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
#ifndef _XT_RATEEST_TARGET_H
#define _XT_RATEEST_TARGET_H
#include <linux/types.h>
#include <linux/if.h>
struct xt_rateest_target_info {
  char name[IFNAMSIZ];
  __s8 interval;
  __u8 ewma_log;
  struct xt_rateest * est __attribute__((aligned(8)));
};
#endif