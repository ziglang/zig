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
#ifndef __ASM_X86_SHMBUF_H
#define __ASM_X86_SHMBUF_H
#if !defined(__x86_64__) || !defined(__ILP32__)
#include <asm-generic/shmbuf.h>
#else
struct shmid64_ds {
  struct ipc64_perm shm_perm;
  size_t shm_segsz;
  __kernel_long_t shm_atime;
  __kernel_long_t shm_dtime;
  __kernel_long_t shm_ctime;
  __kernel_pid_t shm_cpid;
  __kernel_pid_t shm_lpid;
  __kernel_ulong_t shm_nattch;
  __kernel_ulong_t __unused4;
  __kernel_ulong_t __unused5;
};
struct shminfo64 {
  __kernel_ulong_t shmmax;
  __kernel_ulong_t shmmin;
  __kernel_ulong_t shmmni;
  __kernel_ulong_t shmseg;
  __kernel_ulong_t shmall;
  __kernel_ulong_t __unused1;
  __kernel_ulong_t __unused2;
  __kernel_ulong_t __unused3;
  __kernel_ulong_t __unused4;
};
#endif
#endif
