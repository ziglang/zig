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
#ifndef LINUX_ATM_NICSTAR_H
#define LINUX_ATM_NICSTAR_H
#include <linux/atmapi.h>
#include <linux/atmioc.h>
#define NS_GETPSTAT _IOWR('a', ATMIOC_SARPRV + 1, struct atmif_sioc)
#define NS_SETBUFLEV _IOW('a', ATMIOC_SARPRV + 2, struct atmif_sioc)
#define NS_ADJBUFLEV _IO('a', ATMIOC_SARPRV + 3)
typedef struct buf_nr {
  unsigned min;
  unsigned init;
  unsigned max;
} buf_nr;
typedef struct pool_levels {
  int buftype;
  int count;
  buf_nr level;
} pool_levels;
#define NS_BUFTYPE_SMALL 1
#define NS_BUFTYPE_LARGE 2
#define NS_BUFTYPE_HUGE 3
#define NS_BUFTYPE_IOVEC 4
#endif