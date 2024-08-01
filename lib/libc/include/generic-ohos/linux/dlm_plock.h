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
#ifndef _UAPI__DLM_PLOCK_DOT_H__
#define _UAPI__DLM_PLOCK_DOT_H__
#include <linux/types.h>
#define DLM_PLOCK_MISC_NAME "dlm_plock"
#define DLM_PLOCK_VERSION_MAJOR 1
#define DLM_PLOCK_VERSION_MINOR 2
#define DLM_PLOCK_VERSION_PATCH 0
enum {
  DLM_PLOCK_OP_LOCK = 1,
  DLM_PLOCK_OP_UNLOCK,
  DLM_PLOCK_OP_GET,
};
#define DLM_PLOCK_FL_CLOSE 1
struct dlm_plock_info {
  __u32 version[3];
  __u8 optype;
  __u8 ex;
  __u8 wait;
  __u8 flags;
  __u32 pid;
  __s32 nodeid;
  __s32 rv;
  __u32 fsid;
  __u64 number;
  __u64 start;
  __u64 end;
  __u64 owner;
};
#endif