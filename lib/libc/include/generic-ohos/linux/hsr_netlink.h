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
#ifndef __UAPI_HSR_NETLINK_H
#define __UAPI_HSR_NETLINK_H
enum {
  HSR_A_UNSPEC,
  HSR_A_NODE_ADDR,
  HSR_A_IFINDEX,
  HSR_A_IF1_AGE,
  HSR_A_IF2_AGE,
  HSR_A_NODE_ADDR_B,
  HSR_A_IF1_SEQ,
  HSR_A_IF2_SEQ,
  HSR_A_IF1_IFINDEX,
  HSR_A_IF2_IFINDEX,
  HSR_A_ADDR_B_IFINDEX,
  __HSR_A_MAX,
};
#define HSR_A_MAX (__HSR_A_MAX - 1)
enum {
  HSR_C_UNSPEC,
  HSR_C_RING_ERROR,
  HSR_C_NODE_DOWN,
  HSR_C_GET_NODE_STATUS,
  HSR_C_SET_NODE_STATUS,
  HSR_C_GET_NODE_LIST,
  HSR_C_SET_NODE_LIST,
  __HSR_C_MAX,
};
#define HSR_C_MAX (__HSR_C_MAX - 1)
#endif