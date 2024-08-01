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
#ifndef LINUX_ATM_ENI_H
#define LINUX_ATM_ENI_H
#include <linux/atmioc.h>
struct eni_multipliers {
  int tx, rx;
};
#define ENI_MEMDUMP _IOW('a', ATMIOC_SARPRV, struct atmif_sioc)
#define ENI_SETMULT _IOW('a', ATMIOC_SARPRV + 7, struct atmif_sioc)
#endif