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
#ifndef _UAPI__CONNECTOR_H
#define _UAPI__CONNECTOR_H
#include <linux/types.h>
#define CN_IDX_PROC 0x1
#define CN_VAL_PROC 0x1
#define CN_IDX_CIFS 0x2
#define CN_VAL_CIFS 0x1
#define CN_W1_IDX 0x3
#define CN_W1_VAL 0x1
#define CN_IDX_V86D 0x4
#define CN_VAL_V86D_UVESAFB 0x1
#define CN_IDX_BB 0x5
#define CN_DST_IDX 0x6
#define CN_DST_VAL 0x1
#define CN_IDX_DM 0x7
#define CN_VAL_DM_USERSPACE_LOG 0x1
#define CN_IDX_DRBD 0x8
#define CN_VAL_DRBD 0x1
#define CN_KVP_IDX 0x9
#define CN_KVP_VAL 0x1
#define CN_VSS_IDX 0xA
#define CN_VSS_VAL 0x1
#define CN_NETLINK_USERS 11
#define CONNECTOR_MAX_MSG_SIZE 16384
struct cb_id {
  __u32 idx;
  __u32 val;
};
struct cn_msg {
  struct cb_id id;
  __u32 seq;
  __u32 ack;
  __u16 len;
  __u16 flags;
  __u8 data[0];
};
#endif