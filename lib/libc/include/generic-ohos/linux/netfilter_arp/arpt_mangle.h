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
#ifndef _ARPT_MANGLE_H
#define _ARPT_MANGLE_H
#include <linux/netfilter_arp/arp_tables.h>
#define ARPT_MANGLE_ADDR_LEN_MAX sizeof(struct in_addr)
struct arpt_mangle {
  char src_devaddr[ARPT_DEV_ADDR_LEN_MAX];
  char tgt_devaddr[ARPT_DEV_ADDR_LEN_MAX];
  union {
    struct in_addr src_ip;
  } u_s;
  union {
    struct in_addr tgt_ip;
  } u_t;
  __u8 flags;
  int target;
};
#define ARPT_MANGLE_SDEV 0x01
#define ARPT_MANGLE_TDEV 0x02
#define ARPT_MANGLE_SIP 0x04
#define ARPT_MANGLE_TIP 0x08
#define ARPT_MANGLE_MASK 0x0f
#endif