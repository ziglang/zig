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
#ifndef __ASM_GENERIC_SEMBUF_H
#define __ASM_GENERIC_SEMBUF_H
#include <asm/bitsperlong.h>
#include <asm/ipcbuf.h>
struct semid64_ds {
  struct ipc64_perm sem_perm;
#if __BITS_PER_LONG == 64
  long sem_otime;
  long sem_ctime;
#else
  unsigned long sem_otime;
  unsigned long sem_otime_high;
  unsigned long sem_ctime;
  unsigned long sem_ctime_high;
#endif
  unsigned long sem_nsems;
  unsigned long __unused3;
  unsigned long __unused4;
};
#endif