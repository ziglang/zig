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
#ifndef LINUX_MMC_IOCTL_H
#define LINUX_MMC_IOCTL_H
#include <linux/types.h>
#include <linux/major.h>
struct mmc_ioc_cmd {
  int write_flag;
  int is_acmd;
  __u32 opcode;
  __u32 arg;
  __u32 response[4];
  unsigned int flags;
  unsigned int blksz;
  unsigned int blocks;
  unsigned int postsleep_min_us;
  unsigned int postsleep_max_us;
  unsigned int data_timeout_ns;
  unsigned int cmd_timeout_ms;
  __u32 __pad;
  __u64 data_ptr;
};
#define mmc_ioc_cmd_set_data(ic,ptr) ic.data_ptr = (__u64) (unsigned long) ptr
struct mmc_ioc_multi_cmd {
  __u64 num_of_cmds;
  struct mmc_ioc_cmd cmds[0];
};
#define MMC_IOC_CMD _IOWR(MMC_BLOCK_MAJOR, 0, struct mmc_ioc_cmd)
#define MMC_IOC_MULTI_CMD _IOWR(MMC_BLOCK_MAJOR, 1, struct mmc_ioc_multi_cmd)
#define MMC_IOC_MAX_BYTES (512L * 1024)
#define MMC_IOC_MAX_CMDS 255
#endif