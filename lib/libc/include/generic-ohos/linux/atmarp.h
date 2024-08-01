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
#ifndef _LINUX_ATMARP_H
#define _LINUX_ATMARP_H
#include <linux/types.h>
#include <linux/atmapi.h>
#include <linux/atmioc.h>
#define ATMARP_RETRY_DELAY 30
#define ATMARP_MAX_UNRES_PACKETS 5
#define ATMARPD_CTRL _IO('a', ATMIOC_CLIP + 1)
#define ATMARP_MKIP _IO('a', ATMIOC_CLIP + 2)
#define ATMARP_SETENTRY _IO('a', ATMIOC_CLIP + 3)
#define ATMARP_ENCAP _IO('a', ATMIOC_CLIP + 5)
enum atmarp_ctrl_type {
  act_invalid,
  act_need,
  act_up,
  act_down,
  act_change
};
struct atmarp_ctrl {
  enum atmarp_ctrl_type type;
  int itf_num;
  __be32 ip;
};
#endif