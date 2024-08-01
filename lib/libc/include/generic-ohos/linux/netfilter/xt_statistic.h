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
#ifndef _XT_STATISTIC_H
#define _XT_STATISTIC_H
#include <linux/types.h>
enum xt_statistic_mode {
  XT_STATISTIC_MODE_RANDOM,
  XT_STATISTIC_MODE_NTH,
  __XT_STATISTIC_MODE_MAX
};
#define XT_STATISTIC_MODE_MAX (__XT_STATISTIC_MODE_MAX - 1)
enum xt_statistic_flags {
  XT_STATISTIC_INVERT = 0x1,
};
#define XT_STATISTIC_MASK 0x1
struct xt_statistic_priv;
struct xt_statistic_info {
  __u16 mode;
  __u16 flags;
  union {
    struct {
      __u32 probability;
    } random;
    struct {
      __u32 every;
      __u32 packet;
      __u32 count;
    } nth;
  } u;
  struct xt_statistic_priv * master __attribute__((aligned(8)));
};
#endif