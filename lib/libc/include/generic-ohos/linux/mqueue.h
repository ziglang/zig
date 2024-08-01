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
#ifndef _LINUX_MQUEUE_H
#define _LINUX_MQUEUE_H
#include <linux/types.h>
#define MQ_PRIO_MAX 32768
#define MQ_BYTES_MAX 819200
struct mq_attr {
  __kernel_long_t mq_flags;
  __kernel_long_t mq_maxmsg;
  __kernel_long_t mq_msgsize;
  __kernel_long_t mq_curmsgs;
  __kernel_long_t __reserved[4];
};
#define NOTIFY_NONE 0
#define NOTIFY_WOKENUP 1
#define NOTIFY_REMOVED 2
#define NOTIFY_COOKIE_LEN 32
#endif