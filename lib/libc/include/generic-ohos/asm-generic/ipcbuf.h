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
#ifndef __ASM_GENERIC_IPCBUF_H
#define __ASM_GENERIC_IPCBUF_H
#include <linux/posix_types.h>
struct ipc64_perm {
  __kernel_key_t key;
  __kernel_uid32_t uid;
  __kernel_gid32_t gid;
  __kernel_uid32_t cuid;
  __kernel_gid32_t cgid;
  __kernel_mode_t mode;
  unsigned char __pad1[4 - sizeof(__kernel_mode_t)];
  unsigned short seq;
  unsigned short __pad2;
  __kernel_ulong_t __unused1;
  __kernel_ulong_t __unused2;
};
#endif