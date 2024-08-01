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
#ifndef _UAPI_LINUX_FSVERITY_H
#define _UAPI_LINUX_FSVERITY_H
#include <linux/ioctl.h>
#include <linux/types.h>
#define FS_VERITY_HASH_ALG_SHA256 1
#define FS_VERITY_HASH_ALG_SHA512 2
struct fsverity_enable_arg {
  __u32 version;
  __u32 hash_algorithm;
  __u32 block_size;
  __u32 salt_size;
  __u64 salt_ptr;
  __u32 sig_size;
  __u32 __reserved1;
  __u64 sig_ptr;
  __u64 __reserved2[11];
};
struct fsverity_digest {
  __u16 digest_algorithm;
  __u16 digest_size;
  __u8 digest[];
};
#define FS_IOC_ENABLE_VERITY _IOW('f', 133, struct fsverity_enable_arg)
#define FS_IOC_MEASURE_VERITY _IOWR('f', 134, struct fsverity_digest)
struct code_sign_enable_arg {
  __u32 version;
  __u32 hash_algorithm;
  __u32 block_size;
  __u32 salt_size;
  __u64 salt_ptr;
  __u32 sig_size;
  __u32 __reserved1;
  __u64 sig_ptr;
  __u64 __reserved2[7];
  __u64 tree_offset;
  __u64 root_hash_ptr;
  __u64 data_size;
  __u32 flags;
  __u32 cs_version;
};
#define FS_IOC_ENABLE_CODE_SIGN _IOW('f', 200, struct code_sign_enable_arg)
#endif