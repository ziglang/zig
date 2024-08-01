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
#ifndef _UAPI_LINUX_ASPEED_P2A_CTRL_H
#define _UAPI_LINUX_ASPEED_P2A_CTRL_H
#include <linux/ioctl.h>
#include <linux/types.h>
#define ASPEED_P2A_CTRL_READ_ONLY 0
#define ASPEED_P2A_CTRL_READWRITE 1
struct aspeed_p2a_ctrl_mapping {
  __u64 addr;
  __u32 length;
  __u32 flags;
};
#define __ASPEED_P2A_CTRL_IOCTL_MAGIC 0xb3
#define ASPEED_P2A_CTRL_IOCTL_SET_WINDOW _IOW(__ASPEED_P2A_CTRL_IOCTL_MAGIC, 0x00, struct aspeed_p2a_ctrl_mapping)
#define ASPEED_P2A_CTRL_IOCTL_GET_MEMORY_CONFIG _IOWR(__ASPEED_P2A_CTRL_IOCTL_MAGIC, 0x01, struct aspeed_p2a_ctrl_mapping)
#endif