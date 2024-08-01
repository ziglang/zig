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
#ifndef _UAPI__RFKILL_H
#define _UAPI__RFKILL_H
#include <linux/types.h>
#define RFKILL_STATE_SOFT_BLOCKED 0
#define RFKILL_STATE_UNBLOCKED 1
#define RFKILL_STATE_HARD_BLOCKED 2
enum rfkill_type {
  RFKILL_TYPE_ALL = 0,
  RFKILL_TYPE_WLAN,
  RFKILL_TYPE_BLUETOOTH,
  RFKILL_TYPE_UWB,
  RFKILL_TYPE_WIMAX,
  RFKILL_TYPE_WWAN,
  RFKILL_TYPE_GPS,
  RFKILL_TYPE_FM,
  RFKILL_TYPE_NFC,
  NUM_RFKILL_TYPES,
};
enum rfkill_operation {
  RFKILL_OP_ADD = 0,
  RFKILL_OP_DEL,
  RFKILL_OP_CHANGE,
  RFKILL_OP_CHANGE_ALL,
};
struct rfkill_event {
  __u32 idx;
  __u8 type;
  __u8 op;
  __u8 soft, hard;
} __attribute__((packed));
#define RFKILL_EVENT_SIZE_V1 8
#define RFKILL_IOC_MAGIC 'R'
#define RFKILL_IOC_NOINPUT 1
#define RFKILL_IOCTL_NOINPUT _IO(RFKILL_IOC_MAGIC, RFKILL_IOC_NOINPUT)
#endif