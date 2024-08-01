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
#ifndef _XT_TCPUDP_H
#define _XT_TCPUDP_H
#include <linux/types.h>
struct xt_tcp {
  __u16 spts[2];
  __u16 dpts[2];
  __u8 option;
  __u8 flg_mask;
  __u8 flg_cmp;
  __u8 invflags;
};
#define XT_TCP_INV_SRCPT 0x01
#define XT_TCP_INV_DSTPT 0x02
#define XT_TCP_INV_FLAGS 0x04
#define XT_TCP_INV_OPTION 0x08
#define XT_TCP_INV_MASK 0x0F
struct xt_udp {
  __u16 spts[2];
  __u16 dpts[2];
  __u8 invflags;
};
#define XT_UDP_INV_SRCPT 0x01
#define XT_UDP_INV_DSTPT 0x02
#define XT_UDP_INV_MASK 0x03
#endif