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
#ifndef _UAPIBLKTRACE_H
#define _UAPIBLKTRACE_H
#include <linux/types.h>
enum blktrace_cat {
  BLK_TC_READ = 1 << 0,
  BLK_TC_WRITE = 1 << 1,
  BLK_TC_FLUSH = 1 << 2,
  BLK_TC_SYNC = 1 << 3,
  BLK_TC_SYNCIO = BLK_TC_SYNC,
  BLK_TC_QUEUE = 1 << 4,
  BLK_TC_REQUEUE = 1 << 5,
  BLK_TC_ISSUE = 1 << 6,
  BLK_TC_COMPLETE = 1 << 7,
  BLK_TC_FS = 1 << 8,
  BLK_TC_PC = 1 << 9,
  BLK_TC_NOTIFY = 1 << 10,
  BLK_TC_AHEAD = 1 << 11,
  BLK_TC_META = 1 << 12,
  BLK_TC_DISCARD = 1 << 13,
  BLK_TC_DRV_DATA = 1 << 14,
  BLK_TC_FUA = 1 << 15,
  BLK_TC_END = 1 << 15,
};
#define BLK_TC_SHIFT (16)
#define BLK_TC_ACT(act) ((act) << BLK_TC_SHIFT)
enum blktrace_act {
  __BLK_TA_QUEUE = 1,
  __BLK_TA_BACKMERGE,
  __BLK_TA_FRONTMERGE,
  __BLK_TA_GETRQ,
  __BLK_TA_SLEEPRQ,
  __BLK_TA_REQUEUE,
  __BLK_TA_ISSUE,
  __BLK_TA_COMPLETE,
  __BLK_TA_PLUG,
  __BLK_TA_UNPLUG_IO,
  __BLK_TA_UNPLUG_TIMER,
  __BLK_TA_INSERT,
  __BLK_TA_SPLIT,
  __BLK_TA_BOUNCE,
  __BLK_TA_REMAP,
  __BLK_TA_ABORT,
  __BLK_TA_DRV_DATA,
  __BLK_TA_CGROUP = 1 << 8,
};
enum blktrace_notify {
  __BLK_TN_PROCESS = 0,
  __BLK_TN_TIMESTAMP,
  __BLK_TN_MESSAGE,
  __BLK_TN_CGROUP = __BLK_TA_CGROUP,
};
#define BLK_TA_QUEUE (__BLK_TA_QUEUE | BLK_TC_ACT(BLK_TC_QUEUE))
#define BLK_TA_BACKMERGE (__BLK_TA_BACKMERGE | BLK_TC_ACT(BLK_TC_QUEUE))
#define BLK_TA_FRONTMERGE (__BLK_TA_FRONTMERGE | BLK_TC_ACT(BLK_TC_QUEUE))
#define BLK_TA_GETRQ (__BLK_TA_GETRQ | BLK_TC_ACT(BLK_TC_QUEUE))
#define BLK_TA_SLEEPRQ (__BLK_TA_SLEEPRQ | BLK_TC_ACT(BLK_TC_QUEUE))
#define BLK_TA_REQUEUE (__BLK_TA_REQUEUE | BLK_TC_ACT(BLK_TC_REQUEUE))
#define BLK_TA_ISSUE (__BLK_TA_ISSUE | BLK_TC_ACT(BLK_TC_ISSUE))
#define BLK_TA_COMPLETE (__BLK_TA_COMPLETE | BLK_TC_ACT(BLK_TC_COMPLETE))
#define BLK_TA_PLUG (__BLK_TA_PLUG | BLK_TC_ACT(BLK_TC_QUEUE))
#define BLK_TA_UNPLUG_IO (__BLK_TA_UNPLUG_IO | BLK_TC_ACT(BLK_TC_QUEUE))
#define BLK_TA_UNPLUG_TIMER (__BLK_TA_UNPLUG_TIMER | BLK_TC_ACT(BLK_TC_QUEUE))
#define BLK_TA_INSERT (__BLK_TA_INSERT | BLK_TC_ACT(BLK_TC_QUEUE))
#define BLK_TA_SPLIT (__BLK_TA_SPLIT)
#define BLK_TA_BOUNCE (__BLK_TA_BOUNCE)
#define BLK_TA_REMAP (__BLK_TA_REMAP | BLK_TC_ACT(BLK_TC_QUEUE))
#define BLK_TA_ABORT (__BLK_TA_ABORT | BLK_TC_ACT(BLK_TC_QUEUE))
#define BLK_TA_DRV_DATA (__BLK_TA_DRV_DATA | BLK_TC_ACT(BLK_TC_DRV_DATA))
#define BLK_TN_PROCESS (__BLK_TN_PROCESS | BLK_TC_ACT(BLK_TC_NOTIFY))
#define BLK_TN_TIMESTAMP (__BLK_TN_TIMESTAMP | BLK_TC_ACT(BLK_TC_NOTIFY))
#define BLK_TN_MESSAGE (__BLK_TN_MESSAGE | BLK_TC_ACT(BLK_TC_NOTIFY))
#define BLK_IO_TRACE_MAGIC 0x65617400
#define BLK_IO_TRACE_VERSION 0x07
struct blk_io_trace {
  __u32 magic;
  __u32 sequence;
  __u64 time;
  __u64 sector;
  __u32 bytes;
  __u32 action;
  __u32 pid;
  __u32 device;
  __u32 cpu;
  __u16 error;
  __u16 pdu_len;
};
struct blk_io_trace_remap {
  __be32 device_from;
  __be32 device_to;
  __be64 sector_from;
};
enum {
  Blktrace_setup = 1,
  Blktrace_running,
  Blktrace_stopped,
};
#define BLKTRACE_BDEV_SIZE 32
struct blk_user_trace_setup {
  char name[BLKTRACE_BDEV_SIZE];
  __u16 act_mask;
  __u32 buf_size;
  __u32 buf_nr;
  __u64 start_lba;
  __u64 end_lba;
  __u32 pid;
};
#endif