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
#ifndef _UAPI_LINUX_SIGNALFD_H
#define _UAPI_LINUX_SIGNALFD_H
#include <linux/types.h>
#include <linux/fcntl.h>
#define SFD_CLOEXEC O_CLOEXEC
#define SFD_NONBLOCK O_NONBLOCK
struct signalfd_siginfo {
  __u32 ssi_signo;
  __s32 ssi_errno;
  __s32 ssi_code;
  __u32 ssi_pid;
  __u32 ssi_uid;
  __s32 ssi_fd;
  __u32 ssi_tid;
  __u32 ssi_band;
  __u32 ssi_overrun;
  __u32 ssi_trapno;
  __s32 ssi_status;
  __s32 ssi_int;
  __u64 ssi_ptr;
  __u64 ssi_utime;
  __u64 ssi_stime;
  __u64 ssi_addr;
  __u16 ssi_addr_lsb;
  __u16 __pad2;
  __s32 ssi_syscall;
  __u64 ssi_call_addr;
  __u32 ssi_arch;
  __u8 __pad[28];
};
#endif