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
#ifndef _XT_U32_H
#define _XT_U32_H 1
#include <linux/types.h>
enum xt_u32_ops {
  XT_U32_AND,
  XT_U32_LEFTSH,
  XT_U32_RIGHTSH,
  XT_U32_AT,
};
struct xt_u32_location_element {
  __u32 number;
  __u8 nextop;
};
struct xt_u32_value_element {
  __u32 min;
  __u32 max;
};
#define XT_U32_MAXSIZE 10
struct xt_u32_test {
  struct xt_u32_location_element location[XT_U32_MAXSIZE + 1];
  struct xt_u32_value_element value[XT_U32_MAXSIZE + 1];
  __u8 nnums;
  __u8 nvalues;
};
struct xt_u32 {
  struct xt_u32_test tests[XT_U32_MAXSIZE + 1];
  __u8 ntests;
  __u8 invert;
};
#endif