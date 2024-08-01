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
#ifndef _UAPI_LINUX_STM_H
#define _UAPI_LINUX_STM_H
#include <linux/types.h>
#define STP_MASTER_MAX 0xffff
#define STP_CHANNEL_MAX 0xffff
struct stp_policy_id {
  __u32 size;
  __u16 master;
  __u16 channel;
  __u16 width;
  __u16 __reserved_0;
  __u32 __reserved_1;
  char id[0];
};
#define STP_POLICY_ID_SET _IOWR('%', 0, struct stp_policy_id)
#define STP_POLICY_ID_GET _IOR('%', 1, struct stp_policy_id)
#define STP_SET_OPTIONS _IOW('%', 2, __u64)
#endif