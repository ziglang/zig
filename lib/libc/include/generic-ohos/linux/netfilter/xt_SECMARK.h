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
#ifndef _XT_SECMARK_H_target
#define _XT_SECMARK_H_target
#include <linux/types.h>
#define SECMARK_MODE_SEL 0x01
#define SECMARK_SECCTX_MAX 256
struct xt_secmark_target_info {
  __u8 mode;
  __u32 secid;
  char secctx[SECMARK_SECCTX_MAX];
};
#endif