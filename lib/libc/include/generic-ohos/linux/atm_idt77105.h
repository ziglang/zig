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
#ifndef LINUX_ATM_IDT77105_H
#define LINUX_ATM_IDT77105_H
#include <linux/types.h>
#include <linux/atmioc.h>
#include <linux/atmdev.h>
struct idt77105_stats {
  __u32 symbol_errors;
  __u32 tx_cells;
  __u32 rx_cells;
  __u32 rx_hec_errors;
};
#define IDT77105_GETSTAT _IOW('a', ATMIOC_PHYPRV + 2, struct atmif_sioc)
#define IDT77105_GETSTATZ _IOW('a', ATMIOC_PHYPRV + 3, struct atmif_sioc)
#endif