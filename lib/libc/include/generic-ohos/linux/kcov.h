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
#ifndef _LINUX_KCOV_IOCTLS_H
#define _LINUX_KCOV_IOCTLS_H
#include <linux/types.h>
struct kcov_remote_arg {
  __u32 trace_mode;
  __u32 area_size;
  __u32 num_handles;
  __aligned_u64 common_handle;
  __aligned_u64 handles[0];
};
#define KCOV_REMOTE_MAX_HANDLES 0x100
#define KCOV_INIT_TRACE _IOR('c', 1, unsigned long)
#define KCOV_ENABLE _IO('c', 100)
#define KCOV_DISABLE _IO('c', 101)
#define KCOV_REMOTE_ENABLE _IOW('c', 102, struct kcov_remote_arg)
enum {
  KCOV_TRACE_PC = 0,
  KCOV_TRACE_CMP = 1,
};
#define KCOV_CMP_CONST (1 << 0)
#define KCOV_CMP_SIZE(n) ((n) << 1)
#define KCOV_CMP_MASK KCOV_CMP_SIZE(3)
#define KCOV_SUBSYSTEM_COMMON (0x00ull << 56)
#define KCOV_SUBSYSTEM_USB (0x01ull << 56)
#define KCOV_SUBSYSTEM_MASK (0xffull << 56)
#define KCOV_INSTANCE_MASK (0xffffffffull)
#endif