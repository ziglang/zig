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
#ifndef _LINUX_SUSPEND_IOCTLS_H
#define _LINUX_SUSPEND_IOCTLS_H
#include <linux/types.h>
struct resume_swap_area {
  __kernel_loff_t offset;
  __u32 dev;
} __attribute__((packed));
#define SNAPSHOT_IOC_MAGIC '3'
#define SNAPSHOT_FREEZE _IO(SNAPSHOT_IOC_MAGIC, 1)
#define SNAPSHOT_UNFREEZE _IO(SNAPSHOT_IOC_MAGIC, 2)
#define SNAPSHOT_ATOMIC_RESTORE _IO(SNAPSHOT_IOC_MAGIC, 4)
#define SNAPSHOT_FREE _IO(SNAPSHOT_IOC_MAGIC, 5)
#define SNAPSHOT_FREE_SWAP_PAGES _IO(SNAPSHOT_IOC_MAGIC, 9)
#define SNAPSHOT_S2RAM _IO(SNAPSHOT_IOC_MAGIC, 11)
#define SNAPSHOT_SET_SWAP_AREA _IOW(SNAPSHOT_IOC_MAGIC, 13, struct resume_swap_area)
#define SNAPSHOT_GET_IMAGE_SIZE _IOR(SNAPSHOT_IOC_MAGIC, 14, __kernel_loff_t)
#define SNAPSHOT_PLATFORM_SUPPORT _IO(SNAPSHOT_IOC_MAGIC, 15)
#define SNAPSHOT_POWER_OFF _IO(SNAPSHOT_IOC_MAGIC, 16)
#define SNAPSHOT_CREATE_IMAGE _IOW(SNAPSHOT_IOC_MAGIC, 17, int)
#define SNAPSHOT_PREF_IMAGE_SIZE _IO(SNAPSHOT_IOC_MAGIC, 18)
#define SNAPSHOT_AVAIL_SWAP_SIZE _IOR(SNAPSHOT_IOC_MAGIC, 19, __kernel_loff_t)
#define SNAPSHOT_ALLOC_SWAP_PAGE _IOR(SNAPSHOT_IOC_MAGIC, 20, __kernel_loff_t)
#define SNAPSHOT_IOC_MAXNR 20
#endif