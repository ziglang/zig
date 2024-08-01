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
#ifndef _UAPI_VMCORE_H
#define _UAPI_VMCORE_H
#include <linux/types.h>
#define VMCOREDD_NOTE_NAME "LINUX"
#define VMCOREDD_MAX_NAME_BYTES 44
struct vmcoredd_header {
  __u32 n_namesz;
  __u32 n_descsz;
  __u32 n_type;
  __u8 name[8];
  __u8 dump_name[VMCOREDD_MAX_NAME_BYTES];
};
#endif