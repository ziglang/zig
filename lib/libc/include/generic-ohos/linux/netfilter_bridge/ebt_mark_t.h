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
#ifndef __LINUX_BRIDGE_EBT_MARK_T_H
#define __LINUX_BRIDGE_EBT_MARK_T_H
#define MARK_SET_VALUE (0xfffffff0)
#define MARK_OR_VALUE (0xffffffe0)
#define MARK_AND_VALUE (0xffffffd0)
#define MARK_XOR_VALUE (0xffffffc0)
struct ebt_mark_t_info {
  unsigned long mark;
  int target;
};
#define EBT_MARK_TARGET "mark"
#endif