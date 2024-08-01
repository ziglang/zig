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
#ifndef LINUX_ATM_HE_H
#define LINUX_ATM_HE_H
#include <linux/atmioc.h>
#define HE_GET_REG _IOW('a', ATMIOC_SARPRV, struct atmif_sioc)
#define HE_REGTYPE_PCI 1
#define HE_REGTYPE_RCM 2
#define HE_REGTYPE_TCM 3
#define HE_REGTYPE_MBOX 4
struct he_ioctl_reg {
  unsigned addr, val;
  char type;
};
#endif