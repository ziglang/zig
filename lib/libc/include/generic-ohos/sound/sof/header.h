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
#ifndef __INCLUDE_UAPI_SOUND_SOF_USER_HEADER_H__
#define __INCLUDE_UAPI_SOUND_SOF_USER_HEADER_H__
#include <linux/types.h>
struct sof_abi_hdr {
  __u32 magic;
  __u32 type;
  __u32 size;
  __u32 abi;
  __u32 reserved[4];
  __u32 data[0];
} __packed;
#endif