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
#ifndef _XT_DCCP_H_
#define _XT_DCCP_H_
#include <linux/types.h>
#define XT_DCCP_SRC_PORTS 0x01
#define XT_DCCP_DEST_PORTS 0x02
#define XT_DCCP_TYPE 0x04
#define XT_DCCP_OPTION 0x08
#define XT_DCCP_VALID_FLAGS 0x0f
struct xt_dccp_info {
  __u16 dpts[2];
  __u16 spts[2];
  __u16 flags;
  __u16 invflags;
  __u16 typemask;
  __u8 option;
};
#endif