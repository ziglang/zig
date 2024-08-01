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
#ifndef _ASM_MSGBUF_H
#define _ASM_MSGBUF_H
#include <asm/ipcbuf.h>
#ifdef __mips64
struct msqid64_ds {
  struct ipc64_perm msg_perm;
  long msg_stime;
  long msg_rtime;
  long msg_ctime;
  unsigned long msg_cbytes;
  unsigned long msg_qnum;
  unsigned long msg_qbytes;
  __kernel_pid_t msg_lspid;
  __kernel_pid_t msg_lrpid;
  unsigned long __unused4;
  unsigned long __unused5;
};
#elif defined(__MIPSEB__)
struct msqid64_ds {
  struct ipc64_perm msg_perm;
  unsigned long msg_stime_high;
  unsigned long msg_stime;
  unsigned long msg_rtime_high;
  unsigned long msg_rtime;
  unsigned long msg_ctime_high;
  unsigned long msg_ctime;
  unsigned long msg_cbytes;
  unsigned long msg_qnum;
  unsigned long msg_qbytes;
  __kernel_pid_t msg_lspid;
  __kernel_pid_t msg_lrpid;
  unsigned long __unused4;
  unsigned long __unused5;
};
#elif defined(__MIPSEL__)
struct msqid64_ds {
  struct ipc64_perm msg_perm;
  unsigned long msg_stime;
  unsigned long msg_stime_high;
  unsigned long msg_rtime;
  unsigned long msg_rtime_high;
  unsigned long msg_ctime;
  unsigned long msg_ctime_high;
  unsigned long msg_cbytes;
  unsigned long msg_qnum;
  unsigned long msg_qbytes;
  __kernel_pid_t msg_lspid;
  __kernel_pid_t msg_lrpid;
  unsigned long __unused4;
  unsigned long __unused5;
};
#else
#warning noendianessset
#endif
#endif