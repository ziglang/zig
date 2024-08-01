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
#ifndef __LINUX_BRIDGE_EBT_NAT_H
#define __LINUX_BRIDGE_EBT_NAT_H
#include <linux/if_ether.h>
#define NAT_ARP_BIT (0x00000010)
struct ebt_nat_info {
  unsigned char mac[ETH_ALEN];
  int target;
};
#define EBT_SNAT_TARGET "snat"
#define EBT_DNAT_TARGET "dnat"
#endif