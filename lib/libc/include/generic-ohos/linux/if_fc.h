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
#ifndef _LINUX_IF_FC_H
#define _LINUX_IF_FC_H
#include <linux/types.h>
#define FC_ALEN 6
#define FC_HLEN (sizeof(struct fch_hdr) + sizeof(struct fcllc))
#define FC_ID_LEN 3
#define EXTENDED_SAP 0xAA
#define UI_CMD 0x03
struct fch_hdr {
  __u8 daddr[FC_ALEN];
  __u8 saddr[FC_ALEN];
};
struct fcllc {
  __u8 dsap;
  __u8 ssap;
  __u8 llc;
  __u8 protid[3];
  __be16 ethertype;
};
#endif