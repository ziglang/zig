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
#ifndef _UAPI_LINUX_HW_BREAKPOINT_H
#define _UAPI_LINUX_HW_BREAKPOINT_H
enum {
  HW_BREAKPOINT_LEN_1 = 1,
  HW_BREAKPOINT_LEN_2 = 2,
  HW_BREAKPOINT_LEN_3 = 3,
  HW_BREAKPOINT_LEN_4 = 4,
  HW_BREAKPOINT_LEN_5 = 5,
  HW_BREAKPOINT_LEN_6 = 6,
  HW_BREAKPOINT_LEN_7 = 7,
  HW_BREAKPOINT_LEN_8 = 8,
};
enum {
  HW_BREAKPOINT_EMPTY = 0,
  HW_BREAKPOINT_R = 1,
  HW_BREAKPOINT_W = 2,
  HW_BREAKPOINT_RW = HW_BREAKPOINT_R | HW_BREAKPOINT_W,
  HW_BREAKPOINT_X = 4,
  HW_BREAKPOINT_INVALID = HW_BREAKPOINT_RW | HW_BREAKPOINT_X,
};
enum bp_type_idx {
  TYPE_INST = 0,
  TYPE_DATA = 1,
  TYPE_MAX
};
#endif