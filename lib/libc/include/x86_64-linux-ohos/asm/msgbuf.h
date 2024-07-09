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
#ifndef __ASM_X64_MSGBUF_H
#define __ASM_X64_MSGBUF_H
#if !defined(__x86_64__) || !defined(__ILP32__)
#include <asm-generic/msgbuf.h>
#else
#include <asm/ipcbuf.h>
struct msqid64_ds {
  struct ipc64_perm msg_perm;
  __kernel_long_t msg_stime;
  __kernel_long_t msg_rtime;
  __kernel_long_t msg_ctime;
  __kernel_ulong_t msg_cbytes;
  __kernel_ulong_t msg_qnum;
  __kernel_ulong_t msg_qbytes;
  __kernel_pid_t msg_lspid;
  __kernel_pid_t msg_lrpid;
  __kernel_ulong_t __unused4;
  __kernel_ulong_t __unused5;
};
#endif
#endif
