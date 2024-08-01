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
#ifndef _LINUX_DM_USER_H
#define _LINUX_DM_USER_H
#include <linux/types.h>
#define DM_USER_REQ_MAP_READ 0
#define DM_USER_REQ_MAP_WRITE 1
#define DM_USER_REQ_MAP_FLUSH 2
#define DM_USER_REQ_MAP_DISCARD 3
#define DM_USER_REQ_MAP_SECURE_ERASE 4
#define DM_USER_REQ_MAP_WRITE_SAME 5
#define DM_USER_REQ_MAP_WRITE_ZEROES 6
#define DM_USER_REQ_MAP_ZONE_OPEN 7
#define DM_USER_REQ_MAP_ZONE_CLOSE 8
#define DM_USER_REQ_MAP_ZONE_FINISH 9
#define DM_USER_REQ_MAP_ZONE_APPEND 10
#define DM_USER_REQ_MAP_ZONE_RESET 11
#define DM_USER_REQ_MAP_ZONE_RESET_ALL 12
#define DM_USER_REQ_MAP_FLAG_FAILFAST_DEV 0x00001
#define DM_USER_REQ_MAP_FLAG_FAILFAST_TRANSPORT 0x00002
#define DM_USER_REQ_MAP_FLAG_FAILFAST_DRIVER 0x00004
#define DM_USER_REQ_MAP_FLAG_SYNC 0x00008
#define DM_USER_REQ_MAP_FLAG_META 0x00010
#define DM_USER_REQ_MAP_FLAG_PRIO 0x00020
#define DM_USER_REQ_MAP_FLAG_NOMERGE 0x00040
#define DM_USER_REQ_MAP_FLAG_IDLE 0x00080
#define DM_USER_REQ_MAP_FLAG_INTEGRITY 0x00100
#define DM_USER_REQ_MAP_FLAG_FUA 0x00200
#define DM_USER_REQ_MAP_FLAG_PREFLUSH 0x00400
#define DM_USER_REQ_MAP_FLAG_RAHEAD 0x00800
#define DM_USER_REQ_MAP_FLAG_BACKGROUND 0x01000
#define DM_USER_REQ_MAP_FLAG_NOWAIT 0x02000
#define DM_USER_REQ_MAP_FLAG_CGROUP_PUNT 0x04000
#define DM_USER_REQ_MAP_FLAG_NOUNMAP 0x08000
#define DM_USER_REQ_MAP_FLAG_HIPRI 0x10000
#define DM_USER_REQ_MAP_FLAG_DRV 0x20000
#define DM_USER_REQ_MAP_FLAG_SWAP 0x40000
#define DM_USER_RESP_SUCCESS 0
#define DM_USER_RESP_ERROR 1
#define DM_USER_RESP_UNSUPPORTED 2
struct dm_user_message {
  __u64 seq;
  __u64 type;
  __u64 flags;
  __u64 sector;
  __u64 len;
  __u8 buf[];
};
#endif