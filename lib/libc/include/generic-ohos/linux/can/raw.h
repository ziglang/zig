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
#ifndef _UAPI_CAN_RAW_H
#define _UAPI_CAN_RAW_H
#include <linux/can.h>
#define SOL_CAN_RAW (SOL_CAN_BASE + CAN_RAW)
enum {
  SCM_CAN_RAW_ERRQUEUE = 1,
};
enum {
  CAN_RAW_FILTER = 1,
  CAN_RAW_ERR_FILTER,
  CAN_RAW_LOOPBACK,
  CAN_RAW_RECV_OWN_MSGS,
  CAN_RAW_FD_FRAMES,
  CAN_RAW_JOIN_FILTERS,
};
#endif