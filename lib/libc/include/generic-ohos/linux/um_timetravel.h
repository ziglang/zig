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
#ifndef _UAPI_LINUX_UM_TIMETRAVEL_H
#define _UAPI_LINUX_UM_TIMETRAVEL_H
#include <linux/types.h>
struct um_timetravel_msg {
  __u32 op;
  __u32 seq;
  __u64 time;
};
enum um_timetravel_ops {
  UM_TIMETRAVEL_ACK = 0,
  UM_TIMETRAVEL_START = 1,
  UM_TIMETRAVEL_REQUEST = 2,
  UM_TIMETRAVEL_WAIT = 3,
  UM_TIMETRAVEL_GET = 4,
  UM_TIMETRAVEL_UPDATE = 5,
  UM_TIMETRAVEL_RUN = 6,
  UM_TIMETRAVEL_FREE_UNTIL = 7,
  UM_TIMETRAVEL_GET_TOD = 8,
};
#endif