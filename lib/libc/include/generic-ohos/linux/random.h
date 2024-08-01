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
#ifndef _UAPI_LINUX_RANDOM_H
#define _UAPI_LINUX_RANDOM_H
#include <linux/types.h>
#include <linux/ioctl.h>
#include <linux/irqnr.h>
#define RNDGETENTCNT _IOR('R', 0x00, int)
#define RNDADDTOENTCNT _IOW('R', 0x01, int)
#define RNDGETPOOL _IOR('R', 0x02, int[2])
#define RNDADDENTROPY _IOW('R', 0x03, int[2])
#define RNDZAPENTCNT _IO('R', 0x04)
#define RNDCLEARPOOL _IO('R', 0x06)
#define RNDRESEEDCRNG _IO('R', 0x07)
struct rand_pool_info {
  int entropy_count;
  int buf_size;
  __u32 buf[0];
};
#define GRND_NONBLOCK 0x0001
#define GRND_RANDOM 0x0002
#define GRND_INSECURE 0x0004
#endif