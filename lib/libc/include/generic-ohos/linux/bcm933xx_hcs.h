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
#ifndef __BCM933XX_HCS_H
#define __BCM933XX_HCS_H
#include <linux/types.h>
struct bcm_hcs {
  __u16 magic;
  __u16 control;
  __u16 rev_maj;
  __u16 rev_min;
  __u32 build_date;
  __u32 filelen;
  __u32 ldaddress;
  char filename[64];
  __u16 hcs;
  __u16 her_znaet_chto;
  __u32 crc;
};
#endif