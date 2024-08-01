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
#ifndef _LINUX_SELINUX_NETLINK_H
#define _LINUX_SELINUX_NETLINK_H
#include <linux/types.h>
#define SELNL_MSG_BASE 0x10
enum {
  SELNL_MSG_SETENFORCE = SELNL_MSG_BASE,
  SELNL_MSG_POLICYLOAD,
  SELNL_MSG_MAX
};
#define SELNL_GRP_NONE 0x00000000
#define SELNL_GRP_AVC 0x00000001
#define SELNL_GRP_ALL 0xffffffff
enum selinux_nlgroups {
  SELNLGRP_NONE,
#define SELNLGRP_NONE SELNLGRP_NONE
  SELNLGRP_AVC,
#define SELNLGRP_AVC SELNLGRP_AVC
  __SELNLGRP_MAX
};
#define SELNLGRP_MAX (__SELNLGRP_MAX - 1)
struct selnl_msg_setenforce {
  __s32 val;
};
struct selnl_msg_policyload {
  __u32 seqno;
};
#endif