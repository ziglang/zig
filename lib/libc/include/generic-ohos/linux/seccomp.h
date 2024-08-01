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
#ifndef _UAPI_LINUX_SECCOMP_H
#define _UAPI_LINUX_SECCOMP_H
#include <linux/compiler.h>
#include <linux/types.h>
#define SECCOMP_MODE_DISABLED 0
#define SECCOMP_MODE_STRICT 1
#define SECCOMP_MODE_FILTER 2
#define SECCOMP_SET_MODE_STRICT 0
#define SECCOMP_SET_MODE_FILTER 1
#define SECCOMP_GET_ACTION_AVAIL 2
#define SECCOMP_GET_NOTIF_SIZES 3
#define SECCOMP_FILTER_FLAG_TSYNC (1UL << 0)
#define SECCOMP_FILTER_FLAG_LOG (1UL << 1)
#define SECCOMP_FILTER_FLAG_SPEC_ALLOW (1UL << 2)
#define SECCOMP_FILTER_FLAG_NEW_LISTENER (1UL << 3)
#define SECCOMP_FILTER_FLAG_TSYNC_ESRCH (1UL << 4)
#define SECCOMP_RET_KILL_PROCESS 0x80000000U
#define SECCOMP_RET_KILL_THREAD 0x00000000U
#define SECCOMP_RET_KILL SECCOMP_RET_KILL_THREAD
#define SECCOMP_RET_TRAP 0x00030000U
#define SECCOMP_RET_ERRNO 0x00050000U
#define SECCOMP_RET_USER_NOTIF 0x7fc00000U
#define SECCOMP_RET_TRACE 0x7ff00000U
#define SECCOMP_RET_LOG 0x7ffc0000U
#define SECCOMP_RET_ALLOW 0x7fff0000U
#define SECCOMP_RET_ACTION_FULL 0xffff0000U
#define SECCOMP_RET_ACTION 0x7fff0000U
#define SECCOMP_RET_DATA 0x0000ffffU
struct seccomp_data {
  int nr;
  __u32 arch;
  __u64 instruction_pointer;
  __u64 args[6];
};
struct seccomp_notif_sizes {
  __u16 seccomp_notif;
  __u16 seccomp_notif_resp;
  __u16 seccomp_data;
};
struct seccomp_notif {
  __u64 id;
  __u32 pid;
  __u32 flags;
  struct seccomp_data data;
};
#define SECCOMP_USER_NOTIF_FLAG_CONTINUE (1UL << 0)
struct seccomp_notif_resp {
  __u64 id;
  __s64 val;
  __s32 error;
  __u32 flags;
};
#define SECCOMP_ADDFD_FLAG_SETFD (1UL << 0)
struct seccomp_notif_addfd {
  __u64 id;
  __u32 flags;
  __u32 srcfd;
  __u32 newfd;
  __u32 newfd_flags;
};
#define SECCOMP_IOC_MAGIC '!'
#define SECCOMP_IO(nr) _IO(SECCOMP_IOC_MAGIC, nr)
#define SECCOMP_IOR(nr,type) _IOR(SECCOMP_IOC_MAGIC, nr, type)
#define SECCOMP_IOW(nr,type) _IOW(SECCOMP_IOC_MAGIC, nr, type)
#define SECCOMP_IOWR(nr,type) _IOWR(SECCOMP_IOC_MAGIC, nr, type)
#define SECCOMP_IOCTL_NOTIF_RECV SECCOMP_IOWR(0, struct seccomp_notif)
#define SECCOMP_IOCTL_NOTIF_SEND SECCOMP_IOWR(1, struct seccomp_notif_resp)
#define SECCOMP_IOCTL_NOTIF_ID_VALID SECCOMP_IOW(2, __u64)
#define SECCOMP_IOCTL_NOTIF_ADDFD SECCOMP_IOW(3, struct seccomp_notif_addfd)
#endif