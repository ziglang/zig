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
#ifndef _ASM_STATFS_H
#define _ASM_STATFS_H
#include <linux/posix_types.h>
#include <asm/sgidefs.h>
struct statfs {
  long f_type;
#define f_fstyp f_type
  long f_bsize;
  long f_frsize;
  long f_blocks;
  long f_bfree;
  long f_files;
  long f_ffree;
  long f_bavail;
  __kernel_fsid_t f_fsid;
  long f_namelen;
  long f_flags;
  long f_spare[5];
};
#if _MIPS_SIM == _MIPS_SIM_ABI32 || _MIPS_SIM == _MIPS_SIM_NABI32
struct statfs64 {
  __u32 f_type;
  __u32 f_bsize;
  __u32 f_frsize;
  __u32 __pad;
  __u64 f_blocks;
  __u64 f_bfree;
  __u64 f_files;
  __u64 f_ffree;
  __u64 f_bavail;
  __kernel_fsid_t f_fsid;
  __u32 f_namelen;
  __u32 f_flags;
  __u32 f_spare[5];
};
#endif
#if _MIPS_SIM == _MIPS_SIM_ABI64
struct statfs64 {
  long f_type;
  long f_bsize;
  long f_frsize;
  long f_blocks;
  long f_bfree;
  long f_files;
  long f_ffree;
  long f_bavail;
  __kernel_fsid_t f_fsid;
  long f_namelen;
  long f_flags;
  long f_spare[5];
};
struct compat_statfs64 {
  __u32 f_type;
  __u32 f_bsize;
  __u32 f_frsize;
  __u32 __pad;
  __u64 f_blocks;
  __u64 f_bfree;
  __u64 f_files;
  __u64 f_ffree;
  __u64 f_bavail;
  __kernel_fsid_t f_fsid;
  __u32 f_namelen;
  __u32 f_flags;
  __u32 f_spare[5];
};
#endif
#endif